=head1 NAME

CXGN::FamilyName - an object representing a family name in the database

=head1 DESCRIPTION

    my $family_name = CXGN::FamilyName->new( { schema => $schema, family_id => xxxxx });


=head1 AUTHORS

    Titima Tantikanjana <tt15@cornell.edu>

=head1 METHODS

=cut

package CXGN::FamilyName;

use Moose;
use SGN::Model::Cvterm;
use Data::Dumper;
use JSON;

extends 'CXGN::Stock';

has 'family_stock_id' => (isa => "Int",
    is => 'rw',
    required => 1,
);

has 'family_name' => (isa => 'Maybe[Str]',
    is => 'rw',
);

sub BUILD {
    my $self = shift;
    my $args = shift;

    my $schema = $args->{schema};
    my $family_id = $args->{family_stock_id};

    $self->stock_id($family_id);

    my $family_rs = $schema->resultset("Stock::Stock")->find( { stock_id => $family_id });

    if ($family_rs) {
        my $family_uniquename = $family_rs->uniquename();
        $self->family_name($family_uniquename);
        $self->family_stock_id($family_id);
    }
}


sub get_family_parents {
    my $self = shift;
    my $schema = $self->schema();
    my $family_stock_id = $self->family_stock_id();
    my $family_name_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "family_name", "stock_type")->cvterm_id();
    my $family_female_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "family_female_parent_of", "stock_relationship")->cvterm_id();
    my $family_male_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "family_male_parent_of", "stock_relationship")->cvterm_id();
    my $ploidy_level_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'ploidy_level', 'stock_property')->cvterm_id();

    my $q = "SELECT female_parent.stock_id, female_parent.uniquename, cvterm1.name, female_ploidy.value, male_parent.stock_id, male_parent.uniquename, cvterm2.name, male_ploidy.value
        FROM stock AS female_parent
        JOIN cvterm AS cvterm1 ON (female_parent.type_id = cvterm1.cvterm_id)
        JOIN stock_relationship AS stock_relationship1 ON (female_parent.stock_id = stock_relationship1.subject_id) and stock_relationship1.type_id = ?
        LEFT JOIN stockprop AS female_ploidy ON (female_parent.stock_id = female_ploidy.stock_id) AND female_ploidy.type_id = ?
        LEFT JOIN stock_relationship AS stock_relationship2 ON (stock_relationship1.object_id = stock_relationship2.object_id) and stock_relationship2.type_id = ?
        LEFT JOIN stock as male_parent ON (male_parent.stock_id = stock_relationship2.subject_id)
        LEFT JOIN stockprop AS male_ploidy ON (male_parent.stock_id = male_ploidy.stock_id) AND male_ploidy.type_id = ?
        LEFT JOIN cvterm AS cvterm2 ON (male_parent.type_id = cvterm2.cvterm_id)
        WHERE stock_relationship1.object_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($family_female_type_id, $ploidy_level_type_id, $family_male_type_id, $ploidy_level_type_id, $family_stock_id);

    my @family_parents = ();
    while (my ($female_parent_id,  $female_parent_name, $female_stock_type, $female_ploidy, $male_parent_id, $male_parent_name, $male_stock_type, $male_ploidy) = $h->fetchrow_array()){
        push @family_parents, [$female_parent_id,  $female_parent_name, $female_stock_type, $female_ploidy, $male_parent_id, $male_parent_name, $male_stock_type, $male_ploidy]
    }
#    print STDERR Dumper(\@family_parents);
    return \@family_parents;
}


sub get_family_members {
    my $self = shift;
    my $schema = $self->schema();
    my $family_stock_id = $self->family_stock_id();
    my $cross_member_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "cross_member_of", "stock_relationship")->cvterm_id();
    my $offspring_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "offspring_of", "stock_relationship")->cvterm_id();
    my $female_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "female_parent", "stock_relationship")->cvterm_id();
    my $cross_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "cross_experiment", "experiment_type")->cvterm_id();

    my $q = "SELECT cross_table.cross_id, cross_table.cross_name, cross_table.cross_type, cross_table.crossing_experiment_id, cross_table.crossing_experiment_name, progeny_count_table.progeny_number
        FROM
        (SELECT stock.stock_id AS cross_id, stock.uniquename AS cross_name, stock_relationship1.value AS cross_type, project.project_id AS crossing_experiment_id, project.name AS crossing_experiment_name
        FROM stock JOIN stock_relationship on (stock.stock_id = stock_relationship.subject_id) AND stock_relationship.type_id = ?
        JOIN stock_relationship AS stock_relationship1 ON (stock_relationship.subject_id = stock_relationship1.object_id) AND stock_relationship1.type_id = ?
        JOIN nd_experiment_stock ON (nd_experiment_stock.stock_id = stock_relationship1.object_id)
        JOIN nd_experiment ON (nd_experiment_stock.nd_experiment_id = nd_experiment.nd_experiment_id) AND nd_experiment.type_id = ?
        JOIN nd_experiment_project ON (nd_experiment_stock.nd_experiment_id = nd_experiment_project.nd_experiment_id)
        JOIN project ON (nd_experiment_project.project_id = project.project_id) WHERE stock_relationship.object_id = ?) AS cross_table
        LEFT JOIN
        (SELECT DISTINCT stock.stock_id AS cross_id, COUNT (stock_relationship1.subject_id) AS progeny_number
        FROM stock JOIN stock_relationship on (stock.stock_id = stock_relationship.subject_id) AND stock_relationship.type_id = ?
        LEFT JOIN stock_relationship AS stock_relationship1 ON (stock_relationship.subject_id = stock_relationship1.object_id) AND stock_relationship1.type_id = ?
        WHERE stock_relationship.object_id = ? GROUP BY cross_id) AS progeny_count_table
        ON (cross_table.cross_id = progeny_count_table.cross_id)";

        my $h = $schema->storage->dbh()->prepare($q);

        $h->execute($cross_member_of_type_id, $female_parent_type_id, $cross_experiment_type_id, $family_stock_id, $cross_member_of_type_id, $offspring_of_type_id, $family_stock_id);

        my @data =();
        while(my($cross_id, $cross_name, $cross_type, $crossing_experiment_id, $crossing_experiment_name, $progeny_number) = $h->fetchrow_array()){
            push @data, [$cross_id, $cross_name, $cross_type, $crossing_experiment_id, $crossing_experiment_name, $progeny_number]
        }

#        print STDERR "CROSS MEMBERS =".Dumper(\@data);
        return \@data;
}


sub get_all_progenies {
    my $self = shift;
    my $schema = $self->schema();
    my $family_stock_id = $self->family_stock_id();

    my $cross_member_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "cross_member_of", "stock_relationship")->cvterm_id();
    my $offspring_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "offspring_of", "stock_relationship")->cvterm_id();
    my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "cross", "stock_type")->cvterm_id();

    my $q = "SELECT progeny.stock_id, progeny.uniquename, stock.stock_id, stock.uniquename
        FROM stock_relationship JOIN stock_relationship AS stock_relationship1 ON (stock_relationship.subject_id = stock_relationship1.object_id) AND stock_relationship.type_id = ?
        JOIN stock AS progeny ON (stock_relationship1.subject_id = progeny.stock_id) AND stock_relationship1.type_id = ?
        JOIN stock ON (stock_relationship1.object_id = stock.stock_id) AND stock.type_id = ?
        WHERE stock_relationship.object_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($cross_member_of_type_id, $offspring_of_type_id, $cross_type_id, $family_stock_id);

    my @progenies = ();
    while (my ($progeny_id,  $progeny_name, $cross_id, $cross_name) = $h->fetchrow_array()){
        push @progenies, [$progeny_id, $progeny_name, $cross_id, $cross_name]
    }
    print STDERR Dumper(\@progenies);
    return \@progenies;
}


###
1;
###
