package CXGN::Pedigree::AddProgeniesExistingAccessions;

=head1 NAME

CXGN::Pedigree::AddProgeniesExistingAccessions - a module to create relationship between progenies and cross, as well as to create pedigree by using accessions already stored in database.

=head1 USAGE

 my $progeny_add = CXGN::Pedigree::AddProgeniesExistingAccessions->new({ chado_schema => $schema, cross_name => $cross_name, progeny_names => \@progeny_names} );
 $progeny_add->add_progenies_existing_accessions();

=head1 DESCRIPTION

Adds progenies to a cross by using existing accessions in the database. The cross must already exist in the database, and the verify function does this check.   This module is intended to be used in independent loading scripts and interactive dialogs.

=head1 AUTHORS

=cut

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use CXGN::Pedigree::Parentage;

has 'chado_schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 predicate => 'has_chado_schema',
		 required => 1,
		);
has 'cross_name' => (isa =>'Str', is => 'rw', predicate => 'has_cross_name', required => 1,);
has 'progeny_names' => (isa =>'ArrayRef[Str]', is => 'rw', predicate => 'has_progeny_names', required => 1,);

sub add_progenies_existing_accessions {
    my ($self, $overwrite) = @_;
    return __PACKAGE__->add_batch($self->get_chado_schema,
        {$self->get_cross_name => $self->get_progeny_names}, $overwrite);
}

=head2 add_batch($schema, $cross_progenies, $overwrite)

Resolve all requested cross/progeny identities together. The complete parentage
batch commits or rolls back as one operation, and duplicate target IDs cannot
be hidden by aliases or different cross groups. The upload controller can use returned canonical cross IDs to journal the same
transaction without resolving aliases again.

=cut

sub add_batch {
    my ($class, $schema, $groups, $overwrite) = @_;
    my ($error, @canonical_crosses);
    eval {
        $schema->txn_do(sub {
            CXGN::Pedigree::Parentage->lock($schema);
            my $v = CXGN::Pedigree::Parentage->vocabulary($schema);
            my @cross_names = sort keys %$groups;
            die "No cross/progeny rows were supplied.\n" unless @cross_names;
            my @names = (@cross_names, map {@{$groups->{$_}}} @cross_names);
            my $matches = CXGN::Pedigree::Parentage->resolve_names($schema, \@names, $v);
            my %crosses = map {$_ => CXGN::Pedigree::Parentage->choose($matches, $_, ['cross'], $v)} @cross_names;
            my %cross_seen;
            @canonical_crosses = map {{id => $crosses{$_}{stock_id}, name => $crosses{$_}{uniquename}}}
                grep {!$cross_seen{$crosses{$_}{stock_id}}++} @cross_names;
            my %role_for = reverse %{$v->{roles}};
            my %source;
            my $rs = $schema->resultset('Stock::StockRelationship')->search({
                object_id => {-in => [map {$crosses{$_}{stock_id}} @cross_names]},
                type_id => {-in => [values %{$v->{roles}}]},
            });
            while (my $row = $rs->next) {
                my ($cross_id, $role) = ($row->object_id, $role_for{$row->type_id});
                die "Cross has more than one $role parent. Review its pedigree first.\n" if $source{$cross_id}{$role};
                $source{$cross_id}{$role} = $row;
            }
            my (@plans, %seen);
            for my $cross_name (@cross_names) {
                my $cross_id = $crosses{$cross_name}{stock_id};
                my $parents = $source{$cross_id} || {};
                die "Cross $cross_name has no female parent.\n" unless $parents->{female};
                for my $name (@{$groups->{$cross_name}}) {
                    my $child = CXGN::Pedigree::Parentage->choose($matches, $name, ['accession'], $v);
                    die "Progeny $name occurs more than once, including cross $cross_name.\n" if $seen{$child->{stock_id}}++;
                    push @plans, {child_id => $child->{stock_id}, female => $parents->{female}->subject_id,
                        male => $parents->{male} ? $parents->{male}->subject_id : undef,
                        type => $parents->{female}->value, cross_id => $cross_id};
                }
            }
            my $offspring = SGN::Model::Cvterm->get_cvterm_row($schema, 'offspring_of', 'stock_relationship')->cvterm_id;
            my %links;
            if (@plans) {
                my $links = $schema->resultset('Stock::StockRelationship')->search({
                    'me.subject_id' => {-in => [map {$_->{child_id}} @plans]}, 'me.type_id' => $offspring,
                    'object.type_id' => $v->{stock_type}{cross},
                }, {join => 'object'});
                while (my $link = $links->next) {$links{$link->subject_id}{$link->object_id} = 1}
            }
            for my $plan (@plans) {
                die "Progeny is already associated with another cross. Review its provenance first.\n"
                    if grep {$_ != $plan->{cross_id}} keys %{$links{$plan->{child_id}} || {}};
            }
            CXGN::Pedigree::Parentage->apply($schema, \@plans, $overwrite, $v);
            for my $plan (@plans) {
                next if $links{$plan->{child_id}}{$plan->{cross_id}};
                $schema->resultset('Stock::StockRelationship')->create({
                    type_id => $offspring, object_id => $plan->{cross_id}, subject_id => $plan->{child_id},
                });
            }
        });
    };
    $error = $@;
    return $error ? {error => "Transaction error adding progenies: $error"} : {crosses => \@canonical_crosses};
}

sub _get_cross {
    my $self = shift;
    my $cross_name = shift;
    my $chado_schema = $self->get_chado_schema();
    my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $chado_schema);
    my $stock;

    $stock_lookup->set_stock_name($cross_name);
    $stock = $stock_lookup->get_cross_exact();

    if (!$stock) {
        print STDERR "Cross name does not exist\n";
        return;
    }

    return $stock;
}


sub _get_progeny_name {
    my $self = shift;
    my $progeny_name = shift;
    my $chado_schema = $self->get_chado_schema();
    my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $chado_schema);
    my $stock;

    $stock_lookup->set_stock_name($progeny_name);
    $stock = $stock_lookup->get_accession_exact();

    if (!$stock) {
        print STDERR "Progeny name does not exist\n";
        return;
    }

    return $stock;
}


#######
1;
#######
