

=head1 NAME

CXGN::Pedigree::AddPedigrees - a module to add pedigrees to accessions.

=head1 USAGE

 my $pedigree_add = CXGN::Stock::AddPedigrees->new({ schema => $schema, pedigrees => \@pedigrees} );
 my $validated = $pedigree_add->validate_pedigrees(); #is true when all of the pedigrees are valid and the accessions they point to exist in the database.
 $pedigree_add->add_pedigrees();

=head1 DESCRIPTION

Adds an array of pedigrees. The stock names used in the pedigree must already exist in the database, and the verify function does this check.   This module is intended to be used in independent loading scripts and interactive dialogs.

=head1 AUTHORS

 Jeremy D. Edwards (jde22@cornell.edu)

=cut

package CXGN::Pedigree::AddPedigrees;

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use Data::Dumper;
use Bio::GeneticRelationships::Pedigree;
use Bio::GeneticRelationships::Individual;
use Bio::GeneticRelationships::Population;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use CXGN::Pedigree::Parentage;

#class_type 'Pedigree', { class => 'Bio::GeneticRelationships::Pedigree' };
has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 predicate => 'has_schema',
		 required => 1,
		);

=head2 get/set_pedigrees()

 Usage:
 Desc:         provide a hash of accession_names as keys and pedigree objects as values
 Ret:
 Args:
 Side Effects:
 Example:

=cut

has 'pedigrees' => (isa =>'ArrayRef[Bio::GeneticRelationships::Pedigree]', is => 'rw', predicate => 'has_pedigrees');

# Optional physical input rows; legacy object callers use entry positions.
has 'source_rows' => (isa => 'ArrayRef', is => 'rw', default => sub { [] });


=head2 supported_cross_types()

Return the cross types supported by a single accession pedigree. Bulk and
multi-combination crossing operations have separate workflows.

=cut

sub supported_cross_types {
    return CXGN::Pedigree::Parentage->supported_cross_types;
}

=head2 add_pedigrees($overwrite)

Resolve and validate the complete batch, then store it under the common graph
lock. Without overwrite, only identical records or missing information may be
completed; conflicting roles never produce additional parents.

=cut

sub add_pedigrees {
    my ($self, $overwrite) = @_;
    return {error => 'No pedigrees to add'} unless $self->has_pedigrees && @{$self->get_pedigrees};
    my $schema = $self->get_schema;
    my ($result, $error);
    eval {
        $result = $schema->txn_do(sub {
            CXGN::Pedigree::Parentage->lock($schema);
            my $v = CXGN::Pedigree::Parentage->vocabulary($schema);
            my $plans = CXGN::Pedigree::Parentage->prepare($schema, $self->get_pedigrees, $self->get_source_rows, $v);
            return CXGN::Pedigree::Parentage->apply($schema, $plans, $overwrite, $v);
        });
    };
    $error = $@;
    return $error ? {error => "Transaction error creating pedigrees: $error"} : $result;
}

=head2 validate_pedigrees()

Validate names, resolved identities, row uniqueness and explicit parent rules.
Existing parents are returned as warnings requiring review/overwrite in the
upload flow. The writer independently repeats validation under its lock.

=cut

sub validate_pedigrees {
    my $self = shift;
    return {error => ['No pedigrees to add']} unless $self->has_pedigrees && @{$self->get_pedigrees};
    my $schema = $self->get_schema;
    my ($plans, $v);
    eval {
        $v = CXGN::Pedigree::Parentage->vocabulary($schema);
        $plans = CXGN::Pedigree::Parentage->prepare($schema, $self->get_pedigrees, $self->get_source_rows, $v);
    };
    return {error => ["$@"], fatal => 1} if $@;
    my %return;
    my @ids = map {$_->{child_id}} @$plans;
    my $rs = $schema->resultset('Stock::StockRelationship')->search({
        object_id => {-in => \@ids}, type_id => {-in => [values %{$v->{roles}}]},
    });
    while (my $row = $rs->next) {
        my $role = $row->type_id == $v->{roles}{female} ? 'female' : 'male';
        push @{$return{error}}, 'Stock '.$row->object_id.' already has '.$role.' parent stockID '.$row->subject_id;
    }
    return \%return;
}

# Private compatibility helper: resolve only the names needed by this operation.
sub _get_available_stocks {
    my ($self, $names) = @_;
    if (!$names) {
        my @requested;
        for my $p (@{$self->get_pedigrees || []}) {
            push @requested, $p->get_name;
            push @requested, $p->get_female_parent->get_name if $p->has_female_parent;
            push @requested, $p->get_male_parent->get_name if $p->has_male_parent;
        }
        $names = \@requested;
    }
    my $v = CXGN::Pedigree::Parentage->vocabulary($self->get_schema);
    my $matches = CXGN::Pedigree::Parentage->resolve_names($self->get_schema, $names, $v);
    my (%accessions, %all);
    for my $name (keys %$matches) {
        my @female = grep {($v->{stock_names}{$_->{type_id}} || '') =~ /^(accession|cross)$/} @{$matches->{$name}};
        die "Stock name $name is ambiguous.\n" if @female > 1 || @{$matches->{$name}} > 1;
        $accessions{$name} = [$female[0]{stock_id}, $female[0]{organism_id}] if @female;
        $all{$name} = [$matches->{$name}[0]{stock_id}, $matches->{$name}[0]{organism_id}];
    }
    return (\%accessions, \%all);
}

sub generate_pedigrees {
    my $self = shift;
    my $pedigree_data = shift;
    my $schema = $self->get_schema();

    my @generated_pedigrees;
    foreach my $pedigree (@$pedigree_data) {
        my $female_parent;
        my $male_parent;
        my $progeny = $pedigree->{'progeny name'};
        my $female = $pedigree->{'female parent accession'};
        my $male = $pedigree->{'male parent accession'};
        my $cross_type = $pedigree->{'type'};

        if ($cross_type ne "open") {
            $female_parent = Bio::GeneticRelationships::Individual->new( { name => $female });
            $male_parent = Bio::GeneticRelationships::Individual->new( { name => $male });
        } elsif($cross_type eq "open") {
            $female_parent = Bio::GeneticRelationships::Individual->new( { name => $female });
            $male_parent = undef;
            if (defined($male) && length($male)){
                $male_parent = Bio::GeneticRelationships::Individual->new( { name => $male });
            }
        }

        my $opts = {
            cross_type => $cross_type,
            female_parent => $female_parent,
            name => $progeny
        };

        if ($male_parent) {
            $opts->{male_parent} = $male_parent;
        }

        my $p = Bio::GeneticRelationships::Pedigree->new($opts);
        push @generated_pedigrees, $p;
    }

    return \@generated_pedigrees;

}


#######
1;
#######
