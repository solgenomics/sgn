package CXGN::Pedigree::AddPopulations;

=head1 NAME

CXGN::Pedigree::AddPopulations - a module to add populations.

=head1 USAGE

 my $population_add = CXGN::Pedigree::AddPopulations->new({ schema => $schema, name => $name, members =>  \@members} );
 $population_add->add_population();

=head1 DESCRIPTION

=head1 AUTHORS

Bryan Ellerbrock (bje24@cornell.edu)

=cut

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use SGN::Model::Cvterm;
use Data::Dumper;

has 'schema' => (
    is => 'rw',
    isa => 'DBIx::Class::Schema',
    predicate => 'has_schema',
    required => 1,
);

has 'phenome_schema' => (
    is => 'rw',
    isa => 'DBIx::Class::Schema',
    predicate => 'has_phenome_schema',
    required => 1,
);

has 'user_id' => (
    isa => 'Int',
    is => 'rw',
    predicate => 'has_user_id',
    required => 1,
);

has 'name' => (
    isa => 'Str',
    is => 'rw',
    predicate => 'has_name',
    required => 1,
);

has 'members' => (
    isa =>'ArrayRef[Str]',
    is => 'rw',
    predicate => 'has_members',
    required => 1,
);

has 'member_type' => (
    isa =>'Str',
    is => 'rw',
    predicate => 'has_member_type',
    default => 'accessions'
);


sub add_population {
    my $self = shift;
    my $schema = $self->get_schema();
    my $population_name = $self->get_name();
    my $phenome_schema = $self->get_phenome_schema();
    my $user_id = $self->get_user_id();
    my @members = @{$self->get_members()};
    my $member_type = $self->get_member_type();
    my $error;

    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
    my $population_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'population', 'stock_type')->cvterm_id();
    my $synonym_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();
    my $member_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'member_of', 'stock_relationship')->cvterm_id();
    my $member_type_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'member_type', 'stock_property');
    my @stock_types = ($accession_cvterm_id, $plot_cvterm_id, $plant_cvterm_id);
    my $population_id;

    my $previous_pop_rs = $schema->resultset("Stock::Stock")->search({
        uniquename => $population_name,
        type_id => $population_cvterm_id,
    });
    if ($previous_pop_rs->count() > 0){
        return { error => "$population_name already used in the database! Use another name or use the existing population entry." };
    }

    my $acc_synonym_rs = $schema->resultset("Stock::Stock")->search({
        'me.is_obsolete' => { '!=' => 't' },
        'stockprops.value' => { -in => \@members},
        'me.type_id' => { -in => \@stock_types},
        'stockprops.type_id' => $synonym_cvterm_id
    },{join => 'stockprops', '+select'=>['stockprops.value'], '+as'=>['synonym']});
    my %acc_synonyms_lookup;
    while (my $r=$acc_synonym_rs->next){
        $acc_synonyms_lookup{$r->get_column('synonym')}->{$r->uniquename} = $r->stock_id;
    }

    # create population stock entry
    my $coderef = sub {
        my $pop_rs = $schema->resultset("Stock::Stock")->create({
            name => $population_name,
            uniquename => $population_name,
            type_id => $population_cvterm_id,
        });
        $population_id = $pop_rs->stock_id();

        $pop_rs->create_stockprops({$member_type_cvterm->name() => $member_type});

        # generate population connections to the members
        foreach my $m (@members) {
            if (exists($acc_synonyms_lookup{$m})) {
                my @accession_names = keys %{$acc_synonyms_lookup{$m}};
                if (scalar(@accession_names)>1){
                    print STDERR "There is more than one uniquename for this synonym $m. this should not happen!\n";
                }
                $m = $accession_names[0];
            }
            my $m_row = $schema->resultset("Stock::Stock")->find({ uniquename => $m });
            my $connection = $schema->resultset("Stock::StockRelationship")->find_or_create({
                subject_id => $m_row->stock_id,
                object_id => $pop_rs->stock_id,
                type_id => $member_of_cvterm_id,
            });
        }
    };

    try {
        $schema->txn_do($coderef);
    }
    catch {
        $error =  $_;
    };
    if ($error) {
        print STDERR "Error creating population $population_name: $error\n";
        return { error => "Error creating population $population_name: $error" };
    } else {
        print STDERR "population $population_name added successfully\n";
        $phenome_schema->resultset("StockOwner")->find_or_create ({
            stock_id => $population_id,
            sp_person_id => $user_id,
        });
    }

    return { success => "Success! Population $population_name created", population_id=>$population_id };
}

sub add_members {
    my $self = shift;
    my $schema = $self->get_schema();
    my $population_name = $self->get_name();
    my @members = @{$self->get_members()};
    my $error;

    my $population_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'population', 'stock_type')->cvterm_id();
    my $member_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'member_of', 'stock_relationship')->cvterm_id();

    try {
        my $population = $schema->resultset("Stock::Stock")->find({
            uniquename => $population_name,
            type_id => $population_cvterm_id,
        });

        foreach my $m (@members) {
            my $m_row = $schema->resultset("Stock::Stock")->find({ uniquename => $m });
            my $connection = $schema->resultset("Stock::StockRelationship")->find_or_create({
                subject_id => $m_row->stock_id,
                object_id => $population->stock_id,
                type_id => $member_of_cvterm_id,
            });
        }
    }
    catch {
        $error =  $_;
    };
    if ($error) {
        print STDERR "Error adding members to population $population_name: $error\n";
        return { error => "Error adding members to population $population_name: $error" };
    } else {
        print STDERR "Member added to population $population_name successfully\n";
        return { success => "Member added to population $population_name successfully!" };
    }
}


#######
1;
#######
