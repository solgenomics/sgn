
=head1 NAME

CXGN::Cross - an object representing a Cross in the database

=head1 DESCRIPTION

    my $cross = CXGN::Cross->new( { schema => $schema, cross_stock_id => 37347 });

    my $cross_name = $cross->cross_name(); # get cross name
    my $female_parent = $cross->female_parent(); #name of female parent
    my $female_parent_id = $cross->female_parent_id(); # id of female parent
    my $male_parent   = $cross->male_parent(); # etc.
    my $progenies = $cross->progenies();
    # more ...

=head1 AUTHORS

    Titima Tantikanjana
    Lukas Mueller
    Naama Menda
    Jeremy Edwards

=head1 METHODS

=cut

package CXGN::Cross;

use Moose;
use SGN::Model::Cvterm;
use Data::Dumper;
use JSON;

extends 'CXGN::Stock';

has 'cross_stock_id' => (isa => "Maybe[Int]",
    is => 'rw',
    required => 0,
);

has 'cross_name' => (isa => 'Maybe[Str]',
    is => 'rw',
);

has 'female_parent' => (isa => 'Str',
    is => 'rw',
    required => 0,
);

has 'female_parent_id' => (isa => 'Int',
    is => 'rw',
    );

has 'male_parent' => (isa => 'Str',
    is => 'rw',
    required => 0,
);

has 'male_parent_id' => (isa => 'Int',
    is => 'rw',
    );

has 'trial_id' => (isa => "Int",
    is => 'rw',
    required => 0,
);

has 'progenies' => (isa => 'Ref',
		    is => 'rw',
    );

has 'file_type' => (isa => 'Str',
    is => 'rw',
    required => 0,
);

has 'field_crossing_data_order' => (isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
    predicate => 'has_field_crossing_data_order',
    required => 0,
);

has 'parent_type' => (isa => 'Str',
    is => 'rw',
    required => 0,
);




sub BUILD {
    my $self = shift;
    my $args = shift;

    my $schema = $args->{schema};
    my $cross_id = $args->{cross_stock_id};

    $self->stock_id($cross_id);

    my $female_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $male_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();
    my $cross_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();

    my $row = $schema->resultset("Stock::Stock")->find( { stock_id => $cross_id, type_id => $cross_type_id });

    if ($row) {
	 my $name = $row->uniquename();

	 $self->cross_name($name);
	 $self->cross_stock_id($cross_id);

    }

    # to do: populate female_parent, male_parent etc.
    my ($female_parent, $male_parent, @progenies) = $self->get_cross_relationships();
    print STDERR Dumper($female_parent);

    if (ref($female_parent)) {
	$self->female_parent($female_parent->[0]);
	$self->female_parent_id($female_parent->[1]);
    }
    if (ref($male_parent)) {
	$self->male_parent($male_parent->[0]);
	$self->male_parent_id($male_parent->[1]);
    }
    if (@progenies) {
	$self->progenies(\@progenies);
    }
}

sub get_cross_relationships {
    my $self = shift;

    my $crs = $self->schema->resultset("Stock::StockRelationship")->search( { object_id => $self->cross_stock_id } );

    my $maternal_parent = "";
    my $paternal_parent = "";
    my @progeny = ();

    foreach my $child ($crs->all()) {
        if ($child->type->name() eq "female_parent") {
            $maternal_parent = [ $child->subject->name, $child->subject->stock_id() ];
        }
        if ($child->type->name() eq "male_parent") {
            $paternal_parent = [ $child->subject->name, $child->subject->stock_id() ];
        }
        if ($child->type->name() eq "offspring_of") {
            my $is_progeny_obsolete = $child->subject->is_obsolete();
            if ($is_progeny_obsolete == 0 ){
                push @progeny, [ $child->subject->name, $child->subject->stock_id() ]
            }
        }
    }

    return ($maternal_parent, $paternal_parent, \@progeny);
}


sub get_membership {
    my $self = shift;
    my $schema = $self->schema;
    my $cross_id = $self->cross_stock_id;

    my $cross_member_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "cross_member_of", "stock_relationship")->cvterm_id();
    my $cross_experiment_type_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'cross_experiment', 'experiment_type')->cvterm_id();
    my $family_name_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "family_name", "stock_type")->cvterm_id();

    my $q = "SELECT project.project_id, project.name, project.description, stock.stock_id, stock.uniquename
        FROM nd_experiment_stock
        JOIN nd_experiment ON (nd_experiment_stock.nd_experiment_id = nd_experiment.nd_experiment_id) AND nd_experiment.type_id = ?
        JOIN nd_experiment_project ON (nd_experiment_project.nd_experiment_id = nd_experiment.nd_experiment_id)
        JOIN project ON (nd_experiment_project.project_id = project.project_id)
        LEFT JOIN stock_relationship ON (nd_experiment_stock.stock_id = stock_relationship.subject_id) AND stock_relationship.type_id = ?
        LEFT JOIN stock ON (stock_relationship.object_id = stock.stock_id) AND stock.type_id = ?
        WHERE nd_experiment_stock.stock_id = ?";

     my $h = $schema->storage->dbh()->prepare($q);
     $h->execute($cross_experiment_type_id, $cross_member_of_type_id, $family_name_type_id, $cross_id);

     my @membership_info = ();
     while (my ($crossing_experiment_id, $crossing_experiment_name, $description, $family_id, $family_name) = $h->fetchrow_array()){
         push @membership_info, [$crossing_experiment_id, $crossing_experiment_name, $description, $family_id, $family_name]
     }

     return \@membership_info;
}


=head2 cross_parents

 Usage:         CXGN::Cross->cross_parents($schema, $cross_id);
 Desc:          Class method
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub cross_parents {
    my $self = shift;
    my $schema = $self->schema;
    my $cross_id = $self->cross_stock_id;

    my $female_accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $female_plot_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_plot_of', 'stock_relationship')->cvterm_id();
    my $male_accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();
    my $male_plot_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_plot_of', 'stock_relationship')->cvterm_id();
    my $female_plant_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_plant_of', 'stock_relationship')->cvterm_id();
    my $male_plant_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_plant_of', 'stock_relationship')->cvterm_id();
    my $cross_combination_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross_combination', 'stock_property')->cvterm_id();
    my $ploidy_level_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'ploidy_level', 'stock_property')->cvterm_id();

    my $q ="SELECT female_accession.stock_id, female_accession.uniquename, female_plot.stock_id, female_plot.uniquename, female_plant.stock_id, female_plant.uniquename,
        male_accession.stock_id, male_accession.uniquename, male_plot.stock_id, male_plot.uniquename, male_plant.stock_id, male_plant.uniquename,
        female_relationship.value, cross_combination.value, female_ploidy.value, male_ploidy.value
        FROM stock
        JOIN stock_relationship AS female_relationship ON (stock.stock_id = female_relationship.object_id) AND female_relationship.type_id = ?
        JOIN stock AS female_accession ON (female_relationship.subject_id = female_accession.stock_id)
        LEFT JOIN stockprop AS female_ploidy ON (female_accession.stock_id = female_ploidy.stock_id) AND female_ploidy.type_id = ?
        LEFT JOIN stock_relationship AS female_plot_relationship ON (stock.stock_id = female_plot_relationship.object_id) AND female_plot_relationship.type_id = ?
        LEFT JOIN stock AS female_plot on (female_plot_relationship.subject_id = female_plot.stock_id)
        LEFT JOIN stock_relationship AS female_plant_relationship ON (stock.stock_id = female_plant_relationship.object_id) AND female_plant_relationship.type_id = ?
        LEFT JOIN stock AS female_plant ON (female_plant_relationship.subject_id = female_plant.stock_id)
        LEFT JOIN stock_relationship AS male_relationship ON (stock.stock_id = male_relationship.object_id) AND male_relationship.type_id = ?
        LEFT JOIN stock AS male_accession ON (male_relationship.subject_id = male_accession.stock_id)
        LEFT JOIN stockprop AS male_ploidy ON (male_accession.stock_id = male_ploidy.stock_id) AND male_ploidy.type_id = ?
        LEFT JOIN stock_relationship AS male_plot_relationship ON (stock.stock_id = male_plot_relationship.object_id) AND male_plot_relationship.type_id = ?
        LEFT JOIN stock AS male_plot ON (male_plot_relationship.subject_id = male_plot.stock_id)
        LEFT JOIN stock_relationship AS male_plant_relationship ON (stock.stock_id = male_plant_relationship.object_id) AND male_plant_relationship.type_id = ?
        LEFT JOIN stock AS male_plant ON (male_plant_relationship.subject_id =male_plant.stock_id)
        LEFT JOIN stockprop AS cross_combination ON (stock.stock_id = cross_combination.stock_id) AND cross_combination.type_id =?
        WHERE stock.stock_id = ?";

        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute($female_accession_cvterm, $ploidy_level_cvterm, $female_plot_cvterm, $female_plant_cvterm, $male_accession_cvterm, $ploidy_level_cvterm, $male_plot_cvterm, $male_plant_cvterm, $cross_combination_cvterm, $cross_id);

        my @cross_parents = ();
        while(my ($female_accession_id, $female_accession_name, $female_plot_id, $female_plot_name, $female_plant_id, $female_plant_name, $male_accession_id, $male_accession_name, $male_plot_id, $male_plot_name, $male_plant_id, $male_plant_name, $cross_type, $cross_combination, $female_ploidy, $male_ploidy) = $h->fetchrow_array()){
            push @cross_parents, [$female_accession_id, $female_accession_name, $female_plot_id, $female_plot_name, $female_plant_id, $female_plant_name, $male_accession_id, $male_accession_name, $male_plot_id, $male_plot_name, $male_plant_id, $male_plant_name, $cross_type, $cross_combination, $female_ploidy, $male_ploidy]
        }

        return \@cross_parents;

}


=head2 get_cross_details

 Usage:         CXGN::Cross->get_cross_details( $schema, $female_parent, $male_parent);
 Desc:          Class method
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_cross_details {
    my $class = shift;
    my $schema = shift;
    my $female_parent = shift;
    my $male_parent = shift;

    my $male_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "male_parent", "stock_relationship")->cvterm_id();
    my $female_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "female_parent", "stock_relationship")->cvterm_id();
    my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "cross", "stock_type")->cvterm_id();
    my $family_name_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "family_name", "stock_type")->cvterm_id();
    my $member_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "member_of", "stock_relationship")->cvterm_id();
    my $cross_experiment_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema, 'cross_experiment', 'experiment_type')->cvterm_id();

    my $where_clause = "";
    if ($female_parent && $male_parent) {
        $where_clause = "WHERE female_parent.uniquename = ? AND male_parent.uniquename = ? ORDER BY stock_relationship1.value";
    }
    elsif ($female_parent) {
        $where_clause = "WHERE female_parent.uniquename = ? ORDER BY male_parent.uniquename, stock_relationship1.value";
    }
    elsif ($male_parent) {
        $where_clause = "WHERE male_parent.uniquename = ? ORDER BY female_parent.uniquename, stock_relationship1.value";
    }

    my $q = "SELECT female_parent.stock_id, male_parent.stock_id, cross_entry.stock_id, female_parent.uniquename, male_parent.uniquename, cross_entry.uniquename, stock_relationship1.value, family.stock_id, family.uniquename, project.project_id, project.name
    FROM stock as female_parent INNER JOIN stock_relationship AS stock_relationship1 ON (female_parent.stock_id = stock_relationship1.subject_id) AND stock_relationship1.type_id = ?
    INNER JOIN stock AS cross_entry ON (cross_entry.stock_id = stock_relationship1.object_id) AND cross_entry.type_id= ?
    LEFT JOIN stock_relationship AS stock_relationship2 ON (cross_entry.stock_id = stock_relationship2.object_id) AND stock_relationship2.type_id = ?
    LEFT JOIN stock AS male_parent ON (male_parent.stock_id = stock_relationship2.subject_id)
    LEFT JOIN stock_relationship AS stock_relationship3 ON (stock_relationship3.subject_id = cross_entry.stock_id) AND stock_relationship3.type_id = ?
    LEFT JOIN stock AS family ON (stock_relationship3.object_id = family.stock_id) AND family.type_id = ?
    LEFT JOIN nd_experiment_stock ON (nd_experiment_stock.stock_id = cross_entry.stock_id)
    LEFT JOIN nd_experiment_project ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id) AND nd_experiment_stock.type_id = ?
    LEFT JOIN project ON (nd_experiment_project.project_id = project.project_id)
    $where_clause";

    my $h = $schema->storage->dbh()->prepare($q);

    if ($female_parent && $male_parent) {
        $h->execute($female_parent_type_id, $cross_type_id, $male_parent_type_id, $member_of_type_id, $family_name_type_id, $cross_experiment_cvterm, $female_parent, $male_parent);
    }
    elsif ($female_parent) {
        $h->execute($female_parent_type_id, $cross_type_id, $male_parent_type_id, $member_of_type_id, $family_name_type_id, $cross_experiment_cvterm, $female_parent);
    }
    elsif ($male_parent) {
        $h->execute($female_parent_type_id, $cross_type_id, $male_parent_type_id, $member_of_type_id, $family_name_type_id, $cross_experiment_cvterm, $male_parent);
    }
    else {
        $h->execute($female_parent_type_id, $cross_type_id, $male_parent_type_id, $member_of_type_id, $family_name_type_id, $cross_experiment_cvterm);
    }

    my @cross_details = ();
    while (my ($female_parent_id, $male_parent_id, $cross_entry_id, $female_parent_name, $male_parent_name, $cross_name, $cross_type, $family_id, $family_name, $project_id, $project_name) = $h->fetchrow_array()){
        push @cross_details, [$female_parent_id, $female_parent_name, $male_parent_id, $male_parent_name, $cross_entry_id, $cross_name, $cross_type, $family_id, $family_name, $project_id, $project_name]
    }
#    print STDERR Dumper(\@cross_details);
    return \@cross_details;
}


=head2 get_cross_info_for_progeny

 Usage:         CXGN::Cross->get_cross_info_for_progeny( $schema, $female_parent_id, $male_parent_id, $progeny_id);
 Desc:          Class method
 Ret:           cross info for the cross that created the progeny
 Args:
 Side Effects:
 Example:

=cut

sub get_cross_info_for_progeny {
    my $class = shift;
    my $schema = shift;
    my $female_parent_id = shift;
    my $male_parent_id = shift;
    my $progeny_id = shift;

    my $male_parent_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "male_parent", "stock_relationship")->cvterm_id();
    my $female_parent_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "female_parent", "stock_relationship")->cvterm_id();
    my $cross_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "cross", "stock_type")->cvterm_id();
    my $offspring_of_typeid =  SGN::Model::Cvterm->get_cvterm_row($schema, 'offspring_of', 'stock_relationship')->cvterm_id();

    my $cross_experiment_type_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'cross_experiment', 'experiment_type')->cvterm_id();
    my $project_year_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'project year', 'project_property')->cvterm_id();

   my $q = "SELECT cross_entry.stock_id, cross_entry.uniquename, female_stock_relationship.value, year.value
        FROM stock_relationship AS female_stock_relationship
        JOIN stock AS cross_entry ON (cross_entry.stock_id=female_stock_relationship.object_id)
        JOIN stock_relationship AS male_stock_relationship ON (cross_entry.stock_id=male_stock_relationship.object_id)
        JOIN stock_relationship AS cross_to_progeny_rel ON (cross_entry.stock_id=cross_to_progeny_rel.object_id)
        JOIN nd_experiment_stock ON (cross_entry.stock_id=nd_experiment_stock.stock_id)
        JOIN nd_experiment USING(nd_experiment_id)
        JOIN nd_experiment_project USING(nd_experiment_id)
        JOIN project USING (project_id)
        JOIN projectprop as year USING(project_id)
        WHERE cross_entry.type_id= ? AND female_stock_relationship.type_id= ? AND female_stock_relationship.subject_id = ? AND male_stock_relationship.type_id= ? AND male_stock_relationship.subject_id = ? AND cross_to_progeny_rel.type_id = ? AND cross_to_progeny_rel.subject_id = ? AND nd_experiment.type_id = ? AND year.type_id = ?
        ORDER BY female_stock_relationship.value, male_stock_relationship.subject_id";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($cross_typeid, $female_parent_typeid, $female_parent_id, $male_parent_typeid, $male_parent_id, $offspring_of_typeid, $progeny_id, $cross_experiment_type_cvterm_id, $project_year_cvterm_id);


    my @cross_info = ();
    while (my ($cross_entry_id, $cross_name, $cross_type, $year) = $h->fetchrow_array()){
        push @cross_info, [$cross_entry_id, $cross_name, $cross_type, $year];
    }
    #print STDERR Dumper(\@cross_info);
    if (scalar(@cross_info)>1){
        print STDERR "There is more than one (".scalar(@cross_info).") cross linked to this progeny\n";
    }
    if (scalar(@cross_info)>0){
        return $cross_info[0];
    } else {
        return;
    }
}


=head2 get_progeny_info

 Usage:         CXGN::Cross->get_progeny_info($schema, $female_parent, $male_parent);
 Desc:          Class method. Used for the cross search for searching with either female or male parents.
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_progeny_info {
    my $class = shift;

    my $schema = shift;
    my $female_parent = shift;
    my $male_parent = shift;

    my $male_parent_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "male_parent", "stock_relationship")->cvterm_id();
    my $female_parent_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "female_parent", "stock_relationship")->cvterm_id();
    my $accession_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();

    my $where_clause = "";
    if ($female_parent && $male_parent) {
        $where_clause = "WHERE female_parent.uniquename = ? AND male_parent.uniquename = ?";
    }
    elsif ($female_parent) {
        $where_clause = "WHERE female_parent.uniquename = ? ORDER BY male_parent.uniquename";
    }
    elsif ($male_parent) {
        $where_clause = "WHERE male_parent.uniquename = ? ORDER BY female_parent.uniquename";
    }

    my $q = "SELECT DISTINCT female_parent.stock_id, female_parent.uniquename, male_parent.stock_id, male_parent.uniquename, progeny.stock_id, progeny.uniquename, stock_relationship1.value
        FROM stock_relationship as stock_relationship1
        INNER JOIN stock AS female_parent ON (stock_relationship1.subject_id = female_parent.stock_id) AND stock_relationship1.type_id = ?
        INNER JOIN stock AS progeny ON (stock_relationship1.object_id = progeny.stock_id) AND progeny.type_id = ? AND progeny.is_obsolete <> 't'
        LEFT JOIN stock_relationship AS stock_relationship2 ON (progeny.stock_id = stock_relationship2.object_id) AND stock_relationship2.type_id = ?
        LEFT JOIN stock AS male_parent ON (stock_relationship2.subject_id = male_parent.stock_id)
        $where_clause ";

    my $h = $schema->storage->dbh()->prepare($q);

    if($female_parent && $male_parent){
        $h->execute($female_parent_typeid, $accession_typeid, $male_parent_typeid, $female_parent, $male_parent);
    }
    elsif ($female_parent) {
        $h->execute($female_parent_typeid, $accession_typeid, $male_parent_typeid, $female_parent);
    }
    elsif ($male_parent) {
        $h->execute($female_parent_typeid, $accession_typeid, $male_parent_typeid, $male_parent);
    }
    else {
        $h->execute($female_parent_typeid, $accession_typeid, $male_parent_typeid);
    }

    my @progeny_info = ();
    while (my($female_parent_id, $female_parent_name, $male_parent_id, $male_parent_name, $progeny_id, $progeny_name, $cross_type) = $h->fetchrow_array()){

        push @progeny_info, [$female_parent_id, $female_parent_name, $male_parent_id, $male_parent_name, $progeny_id, $progeny_name, $cross_type]
    }
      #print STDERR Dumper(\@progeny_info);
    return \@progeny_info;
}


=head2 get_crosses_in_crossing_experiment

    Class method.
    Returns all cross names and ids in a specific crossing_experiment.
    Example: my @crosses = CXGN::Cross->get_crosses_in_crossing_experiment($schema, $trial_id)

=cut

sub get_crosses_in_crossing_experiment {
    my $self = shift;
    my $schema = $self->schema;
    my $trial_id = $self->trial_id;

    my $cross_stock_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id;

    my $q = "SELECT stock.stock_id, stock.uniquename FROM nd_experiment_project
        JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN stock on (nd_experiment_stock.stock_id = stock.stock_id)
        WHERE stock.type_id = ? AND nd_experiment_project.project_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($cross_stock_type_id, $trial_id);

    my @data = ();
    while(my($cross_id, $cross_name) = $h->fetchrow_array()){
        push @data, [$cross_id, $cross_name]
    }

    return \@data;
}


=head2 get_female_accessions_in_crossing_experiment

    Class method.
    Returns all female accession names and ids in a specific crossing_experiment.
    Example: my @female_accessions = CXGN::Cross->get_female_accessions_in_crossing_experiment($schema, $trial_id)

=cut

sub get_female_accessions_in_crossing_experiment {
    my $self = shift;
    my $schema = $self->schema;
    my $trial_id = $self->trial_id;

    my $female_parent_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "female_parent", "stock_relationship")->cvterm_id();

    my $q = "SELECT DISTINCT stock.stock_id, stock.uniquename FROM nd_experiment_project
        JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN stock_relationship ON (nd_experiment_stock.stock_id = stock_relationship.object_id) AND stock_relationship.type_id = ?
        JOIN stock on (stock_relationship.subject_id = stock.stock_id)
        WHERE nd_experiment_project.project_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($female_parent_typeid, $trial_id);

    my @data = ();
    while(my($female_accession_id, $female_accession_name) = $h->fetchrow_array()){
        push @data, [$female_accession_id, $female_accession_name]
    }

    return \@data;
}


=head2 get_male_accessions_in_crossing_experiment

    Class method.
    Returns all male accession names and ids in a specific crossing_experiment.
    Example: my @male_accessions = CXGN::Cross->get_male_accessions_in_crossing_experiment($schema, $trial_id)

=cut

sub get_male_accessions_in_crossing_experiment {
    my $self = shift;
    my $schema = $self->schema;
    my $trial_id = $self->trial_id;

    my $male_parent_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "male_parent", "stock_relationship")->cvterm_id();

    my $q = "SELECT DISTINCT stock.stock_id, stock.uniquename FROM nd_experiment_project
        JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN stock_relationship ON (nd_experiment_stock.stock_id = stock_relationship.object_id) AND stock_relationship.type_id = ?
        JOIN stock on (stock_relationship.subject_id = stock.stock_id)
        WHERE nd_experiment_project.project_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($male_parent_typeid, $trial_id);

    my @data = ();
    while(my($male_accession_id, $male_accession_name) = $h->fetchrow_array()){
        push @data, [$male_accession_id, $male_accession_name]
    }

    return \@data;
}


=head2 get_female_plots_in_crossing_experiment

    Class method.
    Returns all female plot names and ids in a specific crossing_experiment.
    Example: my @female_plots = CXGN::Cross->get_female_plots_in_crossing_experiment($schema, $trial_id)

=cut

sub get_female_plots_in_crossing_experiment {
    my $self = shift;
    my $schema = $self->schema;
    my $trial_id = $self->trial_id;

    my $female_plot_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "female_plot_of", "stock_relationship")->cvterm_id();

    my $q = "SELECT DISTINCT stock.stock_id, stock.uniquename FROM nd_experiment_project
        JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN stock_relationship ON (nd_experiment_stock.stock_id = stock_relationship.object_id) AND stock_relationship.type_id = ?
        JOIN stock on (stock_relationship.subject_id = stock.stock_id)
        WHERE nd_experiment_project.project_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($female_plot_typeid, $trial_id);

    my @data = ();
    while(my($female_plot_id, $female_plot_name) = $h->fetchrow_array()){
        push @data, [$female_plot_id, $female_plot_name]
    }

    return \@data;
}


=head2 get_male_plots_in_crossing_experiment

    Class method.
    Returns all male plot names and ids in a specific crossing_experiment.
    Example: my @male_plots = CXGN::Cross->get_female_plots_in_crossing_experiment($schema, $trial_id)

=cut

sub get_male_plots_in_crossing_experiment {
    my $self = shift;
    my $schema = $self->schema;
    my $trial_id = $self->trial_id;

    my $male_plot_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "male_plot_of", "stock_relationship")->cvterm_id();

    my $q = "SELECT DISTINCT stock.stock_id, stock.uniquename FROM nd_experiment_project
        JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN stock_relationship ON (nd_experiment_stock.stock_id = stock_relationship.object_id) AND stock_relationship.type_id = ?
        JOIN stock on (stock_relationship.subject_id = stock.stock_id)
        WHERE nd_experiment_project.project_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($male_plot_typeid, $trial_id);

    my @data = ();
    while(my($male_plot_id, $male_plot_name) = $h->fetchrow_array()){
        push @data, [$male_plot_id, $male_plot_name]
    }

    return \@data;
}


=head2 get_female_plants_in_crossing_experiment

    Class method.
    Returns all female plant names and ids in a specific crossing_experiment.
    Example: my @female_plants = CXGN::Cross->get_female_plants_in_crossing_experiment($schema, $trial_id)

=cut

sub get_female_plants_in_crossing_experiment {
    my $self = shift;
    my $schema = $self->schema;
    my $trial_id = $self->trial_id;

    my $female_plant_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "female_plant_of", "stock_relationship")->cvterm_id();

    my $q = "SELECT DISTINCT stock.stock_id, stock.uniquename FROM nd_experiment_project
        JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN stock_relationship ON (nd_experiment_stock.stock_id = stock_relationship.object_id) AND stock_relationship.type_id = ?
        JOIN stock on (stock_relationship.subject_id = stock.stock_id)
        WHERE nd_experiment_project.project_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($female_plant_typeid, $trial_id);

    my @data = ();
    while(my($female_plant_id, $female_plant_name) = $h->fetchrow_array()){
        push @data, [$female_plant_id, $female_plant_name]
    }

    return \@data;
}


=head2 get_male_plants_in_crossing_experiment

    Class method.
    Returns all male plant names and ids in a specific crossing_experiment.
    Example: my @male_plants = CXGN::Cross->get_male_plants_in_crossing_experiment($schema, $trial_id)

=cut

sub get_male_plants_in_crossing_experiment {
    my $self = shift;
    my $schema = $self->schema;
    my $trial_id = $self->trial_id;

    my $male_plant_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "male_plant_of", "stock_relationship")->cvterm_id();

    my $q = "SELECT DISTINCT stock.stock_id, stock.uniquename FROM nd_experiment_project
        JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN stock_relationship ON (nd_experiment_stock.stock_id = stock_relationship.object_id) AND stock_relationship.type_id = ?
        JOIN stock on (stock_relationship.subject_id = stock.stock_id)
        WHERE nd_experiment_project.project_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($male_plant_typeid, $trial_id);

    my @data = ();
    while(my($male_plant_id, $male_plant_name) = $h->fetchrow_array()){
        push @data, [$male_plant_id, $male_plant_name]
    }

    return \@data;
}


=head2 get_crosses_and_details_in_crossingtrial

    Class method.
    Returns all cross names, ids, cross_combinations, cross types and parent info in a specific crossing_experiment.
    Example: my @crosses_details = CXGN::Cross->get_crosses_and_details_in_crossingtrial($schema, $trial_id)

=cut

sub get_crosses_and_details_in_crossingtrial {
    my $self = shift;
    my $schema = $self->schema;
    my $trial_id = $self->trial_id;

    my $cross_combination_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "cross_combination", "stock_property")->cvterm_id();
    my $male_parent_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "male_parent", "stock_relationship")->cvterm_id();
    my $female_parent_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "female_parent", "stock_relationship")->cvterm_id();
    my $female_plot_of_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "female_plot_of", "stock_relationship")->cvterm_id();
    my $male_plot_of_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "male_plot_of", "stock_relationship")->cvterm_id();
    my $female_plant_of_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "female_plant_of", "stock_relationship")->cvterm_id();
    my $male_plant_of_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "male_plant_of", "stock_relationship")->cvterm_id();
    my $ploidy_level_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "ploidy_level", "stock_property")->cvterm_id();

    my $q = "SELECT stock1.stock_id AS cross_id, stock1.uniquename AS cross_name, stockprop.value AS cross_combination, stock_relationship1.value AS cross_type, stock2.stock_id AS female_id,
        stock2.uniquename AS female_name, stockprop2.value AS female_ploidy, stock3.stock_id AS male_id, stock3.uniquename AS male_name, stockprop3.value AS male_ploidy, stock4.stock_id AS female_plot_id, stock4.uniquename AS female_plot_name,
        stock5.stock_id AS male_plot_id, stock5.uniquename AS male_plot_name, stock6.stock_id AS female_plant_id, stock6.uniquename AS female_plant_name, stock7.stock_id AS male_plant_id, stock7.uniquename AS male_plant_name
        FROM nd_experiment_project JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN stock AS stock1 ON (nd_experiment_stock.stock_id = stock1.stock_id)
        LEFT JOIN stockprop ON (stock1.stock_id = stockprop.stock_id) AND stockprop.type_id =?
        JOIN stock_relationship AS stock_relationship1 ON (stock1.stock_id = stock_relationship1.object_id) AND stock_relationship1.type_id = ?
        JOIN stock AS stock2 ON (stock_relationship1.subject_id = stock2.stock_id)
        LEFT JOIN stockprop AS stockprop2 ON (stock2.stock_id = stockprop2.stock_id) AND stockprop2.type_id = ?
        LEFT JOIN stock_relationship AS stock_relationship2 ON (stock1.stock_id = stock_relationship2.object_id) AND stock_relationship2.type_id = ?
        LEFT JOIN stock AS stock3 ON (stock_relationship2.subject_id = stock3.stock_id)
        LEFT JOIN stockprop AS stockprop3 ON (stock3.stock_id = stockprop3.stock_id) AND stockprop3.type_id = ?
        LEFT JOIN stock_relationship AS stock_relationship3 ON (stock1.stock_id = stock_relationship3.object_id) AND stock_relationship3.type_id = ?
        LEFT JOIN stock AS stock4 ON (stock_relationship3.subject_id = stock4.stock_id)
        LEFT JOIN stock_relationship AS stock_relationship4 ON (stock1.stock_id = stock_relationship4.object_id) AND stock_relationship4.type_id = ?
        LEFT JOIN stock AS stock5 ON (stock_relationship4.subject_id = stock5.stock_id)
        LEFT JOIN stock_relationship AS stock_relationship5 ON (stock1.stock_id = stock_relationship5.object_id) AND stock_relationship5.type_id = ?
        LEFT JOIN stock AS stock6 ON (stock_relationship5.subject_id = stock6.stock_id)
        LEFT JOIN stock_relationship AS stock_relationship6 ON (stock1.stock_id = stock_relationship6.object_id) AND stock_relationship6.type_id = ?
        LEFT JOIN stock AS stock7 ON (stock_relationship6.subject_id = stock7.stock_id)
        WHERE nd_experiment_project.project_id = ? ORDER BY cross_id ASC";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($cross_combination_type_id, $female_parent_typeid, $ploidy_level_type_id, $male_parent_typeid, $ploidy_level_type_id, $female_plot_of_typeid, $male_plot_of_typeid, $female_plant_of_typeid, $male_plant_of_typeid, $trial_id);

    my @data =();
    while(my($cross_id, $cross_name, $cross_combination, $cross_type, $female_parent_id, $female_parent_name, $female_ploidy, $male_parent_id, $male_parent_name, $male_ploidy, $female_plot_id, $female_plot_name, $male_plot_id, $male_plot_name, $female_plant_id, $female_plant_name, $male_plant_id, $male_plant_name) = $h->fetchrow_array()){
        push @data, [$cross_id, $cross_name, $cross_combination, $cross_type, $female_parent_id, $female_parent_name, $female_ploidy, $male_parent_id, $male_parent_name, $male_ploidy, $female_plot_id, $female_plot_name, $male_plot_id, $male_plot_name, $female_plant_id, $female_plant_name, $male_plant_id, $male_plant_name]
    }
    return \@data;
}

=head2 get_cross_properties_trial

    Class method.
    Returns all cross_info in a specific trial.
    Example: my @cross_info = CXGN::Cross->get_cross_properties_trial($schema, $trial_id);

=cut

sub get_cross_properties_trial {
    my $self = shift;
    my $schema = $self->schema;
    my $trial_id = $self->trial_id;

    my $cross_combination_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "cross_combination", "stock_property")->cvterm_id();
    my $cross_props_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "crossing_metadata_json", "stock_property")->cvterm_id();

    my $q = "SELECT stock.stock_id, stock.uniquename, stockprop1.value, stockprop2.value FROM nd_experiment_project
        JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN stock ON (nd_experiment_stock.stock_id = stock.stock_id)
        LEFT JOIN stockprop AS stockprop1 ON (stock.stock_id = stockprop1.stock_id) AND stockprop1.type_id = ?
        LEFT JOIN stockprop AS stockprop2 ON (stock.stock_id = stockprop2.stock_id) AND stockprop2.type_id = ?
        WHERE nd_experiment_project.project_id = ? ORDER BY stock.stock_id ASC";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($cross_combination_typeid, $cross_props_typeid, $trial_id);


    my @data = ();
    while(my($cross_id, $cross_name, $cross_combination, $cross_props) = $h->fetchrow_array()){
      #print STDERR Dumper $cross_props;
        if ($cross_props){
            my $cross_props_hash = decode_json$cross_props;
            push @data, [$cross_id, $cross_name, $cross_combination, $cross_props_hash]
        } else {
            push @data, [$cross_id, $cross_name, $cross_combination, $cross_props]
        }
    }

    return \@data;

}


=head2 get_seedlots_from_crossingtrial

    Class method.
    Returns all seedlots derived from crosses in a specific crossing_experiment.
    Example: my @crosses_seedlots = CXGN::Cross->get_seedlots_from_crossingtrial($schema, $trial_id)

=cut

sub get_seedlots_from_crossingtrial {
    my $self = shift;
    my $schema = $self->schema;
    my $trial_id = $self->trial_id;

    my $collection_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "collection_of", "stock_relationship")->cvterm_id();

    my $q = "SELECT stock1.stock_id, stock1.uniquename, stock2.stock_id, stock2.uniquename FROM nd_experiment_project
        JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN stock as stock1 on (nd_experiment_stock.stock_id = stock1.stock_id)
        LEFT JOIN stock_relationship ON (stock1.stock_id = stock_relationship.subject_id) and stock_relationship.type_id = ?
        LEFT JOIN stock as stock2 ON (stock_relationship.object_id = stock2.stock_id)
        WHERE nd_experiment_project.project_id = ? ORDER BY stock1.stock_id ASC";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($collection_of_type_id, $trial_id);

    my @data = ();
    while(my($cross_id, $cross_name, $seedlot_id, $seedlot_uniquename) = $h->fetchrow_array()){
        push @data, [$cross_id, $cross_name, $seedlot_id, $seedlot_uniquename]
    }

    return \@data;

}

=head2 get_cross_progenies_trial

    Class method.
    Get numbers of progenies and family names of all the crosses in a crossing_experiment.
    Example: my @progenies_info = CXGN::Cross->get_cross_progenies_trial($schema, $trial_id)

=cut

sub get_cross_progenies_trial {
    my $self = shift;
    my $schema = $self->schema;
    my $trial_id = $self->trial_id;

    my $cross_combination_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "cross_combination", "stock_property")->cvterm_id();
    my $offspring_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "offspring_of", "stock_relationship")->cvterm_id();
    my $family_name_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "family_name", "stock_type")->cvterm_id();
    my $cross_member_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "cross_member_of", "stock_relationship")->cvterm_id();

    my $q = "SELECT cross_table.cross_id, cross_table.cross_name, cross_table.cross_combination, cross_table.family_id, cross_table.family_name, progeny_count_table.progeny_number
        FROM
        (SELECT stock.stock_id AS cross_id, stock.uniquename AS cross_name, stockprop.value AS cross_combination, stock2.stock_id AS family_id, stock2.uniquename AS family_name
        FROM nd_experiment_project JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN stock ON (nd_experiment_stock.stock_id = stock.stock_id)
        LEFT JOIN stockprop ON (stock.stock_id = stockprop.stock_id) AND stockprop.type_id = ?
        LEFT JOIN stock_relationship ON (stock.stock_id = stock_relationship.subject_id) AND stock_relationship.type_id = ?
        LEFT JOIN stock AS stock2 ON (stock_relationship.object_id = stock2.stock_id) AND stock2.type_id = ?
        WHERE nd_experiment_project.project_id = ?) AS cross_table
        LEFT JOIN
        (SELECT DISTINCT stock.stock_id AS cross_id, COUNT (stock_relationship.subject_id) AS progeny_number
        FROM nd_experiment_project JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN stock ON (nd_experiment_stock.stock_id = stock.stock_id)
        LEFT JOIN stock_relationship ON (stock.stock_id = stock_relationship.object_id) AND stock_relationship.type_id = ?
        WHERE nd_experiment_project.project_id = ? GROUP BY cross_id) AS progeny_count_table
        ON (cross_table.cross_id = progeny_count_table.cross_id) ORDER BY cross_id ASC";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($cross_combination_type_id, $cross_member_of_type_id, $family_name_type_id, $trial_id, $offspring_of_type_id, $trial_id);

    my @data =();
    while(my($cross_id, $cross_name, $cross_combination, $family_id, $family_name, $progeny_number) = $h->fetchrow_array()){
        push @data, [$cross_id, $cross_name, $cross_combination, $family_id, $family_name, $progeny_number]
    }

    return \@data;

}



=head2 delete

 Usage:        $cross->delete();
 Desc:         Deletes a cross
 Ret:          error string if error, undef otherwise
 Args:         none
 Side Effects: deletes project entry, nd_experiment entry, and stock entry.
               does not check if
 Example:

=cut


sub delete {
    my $self = shift;

    print STDERR "Delete cross ".$self->cross_name()."\n";
    my $dbh = $self->schema()->storage()->dbh();
    my $schema = $self->schema();
    my $cross_id = $self->cross_stock_id();

    eval {
	$dbh->begin_work();

    my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "cross", "stock_type")->cvterm_id();
    my $cross_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "cross_experiment", "experiment_type")->cvterm_id();
    my $collection_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "collection_of", "stock_relationship")->cvterm_id();
    my $field_layout_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'field_layout', 'experiment_type')->cvterm_id();
    my $plot_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_of', 'stock_relationship')->cvterm_id();

    # checking if cross has associated seedlot
    my $q = "SELECT stock_relationship.type_id, stock.uniquename FROM stock_relationship JOIN stock ON (stock_relationship.object_id = stock.stock_id) WHERE stock_relationship.subject_id = ?";

    my $h = $self->schema->storage->dbh()->prepare($q);

    $h->execute($cross_id);

    while (my($type_id, $seedlot_name) = $h->fetchrow_array()) {
	    if ($type_id == $collection_of_type_id) {
            print STDERR "Cross has associated seedlot. Cannot delete.\n";
	        die "Cross has associated seedlot: $seedlot_name. Cannot delete.\n";
	    }
    }

    #checking if cross has associated trial
    my $q2 = "SELECT nd_experiment_stock.type_id, project.name FROM stock_relationship JOIN nd_experiment_stock ON (stock_relationship.subject_id = nd_experiment_stock.stock_id) AND stock_relationship.type_id = ?
        JOIN nd_experiment_project ON (nd_experiment_stock.nd_experiment_id = nd_experiment_project.nd_experiment_id)
        JOIN project ON (nd_experiment_project.project_id = project.project_id) WHERE stock_relationship.object_id = ? ";

    my $h2 = $self->schema->storage->dbh()->prepare($q2);

    $h2->execute($plot_of_type_id, $cross_id);

    while (my($type_id, $project_name) = $h2->fetchrow_array()) {
        if ($type_id == $field_layout_type_id) {
            print STDERR "Cross has associated trial. Cannot delete.\n";
            die "Cross has associated trial: $project_name. Cannot delete.\n";
        }
    }

    #checking if any progeny has associated data
	my $properties = $self->progeny_properties();

	my $can_delete =
	    ($properties->{trials} == 0) &&
	    ($properties->{traits} == 0) &&
	    ($properties->{genotypes} == 0) &&
	    ($properties->{images} == 0);

	if (! $can_delete) {
	    print STDERR "Cross has associated data. Cannot delete.\n";
	    die "Cross has associated data. ($properties->{trials} trials, $properties->{traits} traits and $properties->{genoytpes} genotypes. Cannot delete...\n";
	}
	else {
	    print STDERR "This cross has no associated data that would prevent deletion.";
	}

    #checking if the stock id has cross stock type
    my $cross_rs = $schema->resultset("Stock::Stock")->find ({stock_id => $cross_id, type_id => $cross_type_id});
    if (!$cross_rs) {
        print STDERR "This stock id is not a cross. Cannot delete.\n";
	    die "This stock id is not a cross. Cannot delete.\n";
    }

    #get nd_experiment_id with cross_experiment_type
    my $experiment_id;
    my $nd_q = "SELECT nd_experiment.nd_experiment_id FROM nd_experiment_stock
        JOIN nd_experiment ON (nd_experiment_stock.nd_experiment_id = nd_experiment.nd_experiment_id)
        WHERE nd_experiment.type_id = ? AND nd_experiment_stock.stock_id = ?";

    my $nd_h = $schema->storage->dbh()->prepare($nd_q);
    $nd_h->execute($cross_experiment_type_id, $cross_id);
    my @nd_experiment_ids= $nd_h->fetchrow_array();
    if (scalar @nd_experiment_ids == 1) {
        $experiment_id = $nd_experiment_ids[0];
    } else {
        print STDERR "Error retrieving experiment id"."\n";
        die "Error retrieving experiment id";
    }
#    print STDERR "ND EXPERIMENT ID =".Dumper($experiment_id)."\n";

    #delete the nd_experiment_md_files entries
    my $md_files_q = "DELETE FROM phenome.nd_experiment_md_files WHERE nd_experiment_id = ?";
    my $md_files_h = $schema->storage->dbh()->prepare($md_files_q);
    $md_files_h->execute($experiment_id);

	# delete the nd_experiment entries
	print STDERR "Deleting nd_experiment entry for cross...\n";
	my $q2= "delete from nd_experiment where nd_experiment.nd_experiment_id = ? AND nd_experiment.type_id = ?";
	my $h2 = $dbh->prepare($q2);
	$h2->execute($experiment_id, $cross_experiment_type_id);

	# delete stock owner entries
	#
	print STDERR "Deleting associated stock_owners...\n";
	my $q3 = "delete from phenome.stock_owner where stock_id=?";
	my $h3 = $dbh->prepare($q3);
	$h3->execute($self->cross_stock_id());

	# delete the stock entries
	#
	print STDERR "Deleting the stock entry...\n";
	my $q4 = "delete from stock where stock.stock_id=? and stock.type_id = ?";
	my $h4 = $dbh->prepare($q4);
	$h4->execute($self->cross_stock_id(), $cross_type_id);

	print STDERR Dumper($properties);
	# delete the progeny...
	#
	print STDERR "Deleting the progeny...\n";
	my $q5 = "delete from stock where stock_id =?";
	my $h5 = $dbh->prepare($q5);
	foreach my $progeny (@{$properties->{subjects}}) {

	    if ($progeny->[2] eq "offspring_of") {
		my $s = CXGN::Stock->new( { schema => $schema, stock_id => $progeny->[0]});
		$s->hard_delete();
	    }
	}

    };

    if ($@) {
	print STDERR "An error occurred while deleting cross id ".$self->cross_stock_id()."$@\n";
	$dbh->rollback();
	return $@;
    }
    else {
	$dbh->commit();
	return 0;
    }
}

sub progeny_properties {
    my $self = shift;

    my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), "cross", "stock_type")->cvterm_id();

    print STDERR "sub cross_deletion_possible...\n";
    my $q = "SELECT subject.stock_id, subject.uniquename, cvterm.name from stock join stock_relationship on (stock.stock_id=stock_relationship.object_id) join stock as subject on(stock_relationship.subject_id=subject.stock_id) join cvterm on (stock_relationship.type_id=cvterm.cvterm_id) where stock.stock_id = ? and stock.type_id=?";

    my $h = $self->schema->storage->dbh()->prepare($q);

    $h->execute($self->cross_stock_id(), $cross_type_id);

    my @subjects = ();
    my $has_trials = 0;
    my $has_traits = 0;
    my $has_genotypes = 0;
    my $has_images;

    while (my($stock_id, $name, $type) = $h->fetchrow_array()) {
	print STDERR "ID $stock_id NAME $name TYPE $type\n";
	push @subjects, [$stock_id, $name, $type];

	if ($type eq "offspring_of") { # child
	    my $s = CXGN::Stock->new( { schema => $self->schema(),  stock_id => $stock_id });
	    if (my @traits = $s->get_trait_list()) {
		print STDERR "Associated traits: ".Dumper(\@traits);
		$has_traits += scalar(@traits);
	    }
	    if (my @trials = $s->get_trials()) {
		print STDERR "Associated trials: ".Dumper(\@trials);
		$has_trials += scalar(@trials);
	    }
	    if (my $genotypeprop_ids = $s->get_genotypeprop_ids()) {
		print STDERR "Associated genotypes: ".Dumper($genotypeprop_ids);
		$has_genotypes += scalar(@$genotypeprop_ids);
	    }
	    if (my @image_ids = $s->get_image_ids()) {
		print STDERR "Associated images: ".Dumper(\@image_ids);
		$has_images += scalar(@image_ids);
	    }
	}
    }
    my $data = {
	traits => $has_traits,
	trials => $has_trials,
	genotypes => $has_genotypes,
	images => $has_images,
	subjects => \@subjects,
    };

    print STDERR Dumper($data);
    return $data;
}


sub get_cross_tissue_culture_samples {
    my $self = shift;
    my $cross_samples_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'tissue_culture_data_json', 'stock_property')->cvterm_id();
    my $cross_samples = $self->schema->resultset("Stock::Stockprop")->find({stock_id => $self->cross_stock_id, type_id => $cross_samples_cvterm});

    my $samples_json_string;
    if($cross_samples){
        $samples_json_string = $cross_samples->value();
    }

    my $samples_hash_ref ={};
    if($samples_json_string){
        $samples_hash_ref = decode_json $samples_json_string;
    }

    return $samples_hash_ref;
}


=head2 get_pedigree_male_parents

    Class method.
    Returns all male parents that were crossed with a spefified female parent.
    Example: my @male_parents = CXGN::Cross->get_pedigree_male_parents($schema, $pedigree_female_parent)

=cut

sub get_pedigree_male_parents {
    my $class = shift;
    my $schema = shift;
    my $pedigree_female_parent = shift;

    my $male_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();
    my $female_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();

    my $dbh = $schema->storage->dbh();

    my $q = "SELECT DISTINCT male_parent.stock_id, male_parent.uniquename FROM stock as female_parent
    INNER JOIN stock_relationship AS stock_relationship1 ON (female_parent.stock_id=stock_relationship1.subject_id) AND stock_relationship1.type_id= ?
    INNER JOIN stock AS check_type ON (stock_relationship1.object_id=check_type.stock_id) AND check_type.type_id = ?
    INNER JOIN stock_relationship AS stock_relationship2 ON (stock_relationship1.object_id=stock_relationship2.object_id) AND stock_relationship2.type_id = ?
    INNER JOIN stock AS male_parent ON (male_parent.stock_id=stock_relationship2.subject_id)
    WHERE female_parent.uniquename= ? ORDER BY male_parent.uniquename ASC";

    my $h = $dbh->prepare($q);
    $h->execute($female_parent_type_id, $accession_type_id, $male_parent_type_id, $pedigree_female_parent);

    my @male_parents=();
    while(my ($male_parent_id, $male_parent_name) = $h->fetchrow_array()){
      push @male_parents, [$male_parent_name];
    }

    return \@male_parents;

}


=head2 get_pedigree_female_parents

    Class method.
    Returns all female parents that were crossed with a spefified male parent.
    Example: my @female_parents = CXGN::Cross->get_pedigree_female_parents($schema, $pedigree_male_parent)

=cut

sub get_pedigree_female_parents {
    my $class = shift;
    my $schema = shift;
    my $pedigree_male_parent = shift;

    my $male_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();
    my $female_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();

    my $dbh = $schema->storage->dbh();

    my $q = "SELECT DISTINCT female_parent.stock_id, female_parent.uniquename FROM stock as male_parent
    INNER JOIN stock_relationship AS stock_relationship1 ON (male_parent.stock_id=stock_relationship1.subject_id) AND stock_relationship1.type_id= ?
    INNER JOIN stock AS check_type ON (stock_relationship1.object_id=check_type.stock_id) AND check_type.type_id = ?
    INNER JOIN stock_relationship AS stock_relationship2 ON (stock_relationship1.object_id=stock_relationship2.object_id) AND stock_relationship2.type_id = ?
    INNER JOIN stock AS female_parent ON (female_parent.stock_id=stock_relationship2.subject_id)
    WHERE male_parent.uniquename= ? ORDER BY female_parent.uniquename ASC";


    my $h = $dbh->prepare($q);
    $h->execute($male_parent_type_id, $accession_type_id, $female_parent_type_id, $pedigree_male_parent);

    my @female_parents=();
    while(my ($female_parent_id, $female_parent_name) = $h->fetchrow_array()){
      push @female_parents, [$female_parent_name];
    }

    return \@female_parents;

}


=head2 get_cross_male_parents

    Class method.
    Returns all male parents that were crossed with a spefified male parent.
    Example: my @male_parents = CXGN::Cross->get_cross_male_parents($schema, $cross_female_parent)

=cut

sub get_cross_male_parents {
    my $class = shift;
    my $schema = shift;
    my $cross_female_parent = shift;

    my $male_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();
    my $female_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();

    my $dbh = $schema->storage->dbh();

    my $q = "SELECT DISTINCT male_parent.stock_id, male_parent.uniquename FROM stock as female_parent
    INNER JOIN stock_relationship AS stock_relationship1 ON (female_parent.stock_id=stock_relationship1.subject_id)
    INNER JOIN stock AS check_type ON (stock_relationship1.object_id=check_type.stock_id)
    LEFT JOIN stock_relationship AS stock_relationship2 ON (stock_relationship1.object_id = stock_relationship2.object_id)
    LEFT JOIN stock AS male_parent ON (male_parent.stock_id=stock_relationship2.subject_id)
    WHERE female_parent.uniquename = ? AND stock_relationship1.type_id = ? AND check_type.type_id = ? AND stock_relationship2.type_id = ?
    ORDER BY male_parent.uniquename ASC";

    my $h = $dbh->prepare($q);
    $h->execute($cross_female_parent, $female_parent_type_id, $cross_type_id, $male_parent_type_id );

    my @male_parents=();
    while(my ($male_parent_id, $male_parent_name) = $h->fetchrow_array()){
        push @male_parents, [$male_parent_name];
    }

    return \@male_parents;

}


=head2 get_cross_female_parents

    Class method.
    Returns all female parents that were crossed with a spefified male parent.
    Example: my @male_parents = CXGN::Cross->get_cross_male_parents($schema, $cross_female_parent)

=cut

sub get_cross_female_parents {
    my $class = shift;
    my $schema = shift;
    my $cross_male_parent = shift;

    my $male_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();
    my $female_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();

    my $dbh = $schema->storage->dbh();

    my $q = "SELECT DISTINCT female_parent.stock_id, female_parent.uniquename FROM stock as male_parent
    INNER JOIN stock_relationship AS stock_relationship1 ON (male_parent.stock_id=stock_relationship1.subject_id)
    INNER JOIN stock AS check_type ON (stock_relationship1.object_id=check_type.stock_id)
    LEFT JOIN stock_relationship AS stock_relationship2 ON (stock_relationship1.object_id = stock_relationship2.object_id)
    LEFT JOIN stock AS female_parent ON (female_parent.stock_id=stock_relationship2.subject_id)
    WHERE male_parent.uniquename = ? AND stock_relationship1.type_id = ? AND check_type.type_id = ? AND stock_relationship2.type_id = ?
    ORDER BY female_parent.uniquename ASC";

    my $h = $dbh->prepare($q);
    $h->execute($cross_male_parent, $male_parent_type_id, $cross_type_id, $female_parent_type_id );

    my @female_parents=();
    while(my ($female_parent_id, $female_parent_name) = $h->fetchrow_array()){
      push @female_parents, [$female_parent_name];
    }

    return \@female_parents;

}


=head2 get_cross_identifiers_in_crossing_experiment

    Class method.
    Returns all cross identifiers in a specific crossing_experiment together with the corresponding cross unique ids.
    Example: my $crosses = CXGN::Cross->new({schema => $schema, trial_id => $crossing_experiment_id});
             my $identifiers = $crosses->get_cross_identifiers_in_crossing_experiment();

=cut

sub get_cross_identifiers_in_crossing_experiment {
    my $self = shift;
    my $schema = $self->schema;
    my $trial_id = $self->trial_id;

    my $cross_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id;
    my $cross_identifier_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'cross_identifier', 'stock_property')->cvterm_id;

    my $q = "SELECT stock.uniquename, stockprop.value FROM nd_experiment_project
        JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN stock ON (nd_experiment_stock.stock_id = stock.stock_id) AND stock.type_id = ?
        JOIN stockprop ON (stock.stock_id = stockprop.stock_id)
        WHERE stockprop.type_id = ? AND nd_experiment_project.project_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($cross_type_id, $cross_identifier_type_id, $trial_id);

    my %cross_identifier_hash;
    while(my($cross_unique_id, $cross_identifier) = $h->fetchrow_array()){
        $cross_identifier_hash{$cross_identifier} = $cross_unique_id;
    }

    return \%cross_identifier_hash;
}


=head2 get_cross_additional_info_trial

    Class method.
    Returns all cross_additional_info in a specific trial.
    Example: my @cross_additional_info = CXGN::Cross->get_cross_additional_trial($schema, $trial_id);

=cut

sub get_cross_additional_info_trial {
    my $self = shift;
    my $schema = $self->schema;
    my $trial_id = $self->trial_id;

    my $cross_combination_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "cross_combination", "stock_property")->cvterm_id();
    my $cross_additional_info_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "cross_additional_info", "stock_property")->cvterm_id();

    my $q = "SELECT stock.stock_id, stock.uniquename, stockprop1.value, stockprop2.value FROM nd_experiment_project
        JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN stock ON (nd_experiment_stock.stock_id = stock.stock_id)
        LEFT JOIN stockprop AS stockprop1 ON (stock.stock_id = stockprop1.stock_id) AND stockprop1.type_id = ?
        LEFT JOIN stockprop AS stockprop2 ON (stock.stock_id = stockprop2.stock_id) AND stockprop2.type_id = ?
        WHERE nd_experiment_project.project_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($cross_combination_typeid, $cross_additional_info_typeid, $trial_id);

    my @data = ();
    while(my($cross_id, $cross_name, $cross_combination, $cross_additional_info_json) = $h->fetchrow_array()){
      #print STDERR Dumper $cross_props;
        if ($cross_additional_info_json){
            my $cross_additional_info_hash = decode_json$cross_additional_info_json;
            push @data, [$cross_id, $cross_name, $cross_combination, $cross_additional_info_hash]
        } else {
            push @data, [$cross_id, $cross_name, $cross_combination, $cross_additional_info_json]
        }
    }

    return \@data;
}


=head2 get_nd_experiment_id_with_type_cross_experiment


=cut

sub get_nd_experiment_id_with_type_cross_experiment {
    my $self = shift;
    my $schema = $self->schema;
    my $cross_name = $self->cross_name();
    my $cross_id;
    my $experiment_id;
#    print STDERR "CROSS NAME =".Dumper($cross_name)."\n";
    my $cross_experiment_type_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'cross_experiment', 'experiment_type')->cvterm_id;
    my $cross_type_id  =  SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();

    my $cross_rs = $schema->resultset("Stock::Stock")->find( { uniquename => $cross_name, type_id => $cross_type_id});

    if ($cross_rs) {
        $cross_id = $cross_rs->stock_id();
    } else {
        print STDERR "Error retrieving cross ID"."\n";
        return;
    }

    my $q = "SELECT nd_experiment.nd_experiment_id FROM nd_experiment_stock
        JOIN nd_experiment ON (nd_experiment_stock.nd_experiment_id = nd_experiment.nd_experiment_id)
        WHERE nd_experiment.type_id = ? AND nd_experiment_stock.stock_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($cross_experiment_type_id, $cross_id);
    my @nd_experiment_ids= $h->fetchrow_array();
    if (scalar @nd_experiment_ids == 1) {
        $experiment_id = $nd_experiment_ids[0];
    } else {
        print STDERR "Error retrieving experiment ID"."\n";
        return;
    }

    return $experiment_id;
}


=head2 get_intercross_file_metadata


=cut

sub get_intercross_file_metadata {
    my $self = shift;
    my $schema = $self->schema;
    my $crossing_experiment_id = $self->trial_id();
    my $file_type = $self->file_type();
    my $project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'crossing_trial', 'project_type')->cvterm_id();
    my $file_metadata_json_type_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'file_metadata_json', 'project_property')->cvterm_id;

    my $projectprop_rs = $schema->resultset("Project::Projectprop")->find({ project_id => $crossing_experiment_id, type_id => $file_metadata_json_type_id });

    my @file_ids;
    my @file_info = ();
    my $dbh = $schema->storage->dbh();
    if ($projectprop_rs){
        my $intercross_files;
        my $file_metadata_json = $projectprop_rs->value();
        my $file_metadata = decode_json$file_metadata_json;

        if ($file_type eq 'intercross_download') {
            $intercross_files = $file_metadata->{'intercross_download'};
        } elsif ($file_type eq 'intercross_upload') {
            $intercross_files = $file_metadata->{'intercross_upload'};
        }

        if ($intercross_files) {
            my %intercross_hash = %{$intercross_files};
            @file_ids = keys %intercross_hash;
            if (scalar @file_ids > 0) {
                foreach my $id (@file_ids){
                    my @each_row = ();
                    my $q = "SELECT f.file_id, m.create_date, p.sp_person_id, p.username, f.basename, f.dirname, f.filetype
                        FROM metadata.md_files AS f
                        JOIN metadata.md_metadata as m ON (f.metadata_id = m.metadata_id)
                        JOIN sgn_people.sp_person as p ON (p.sp_person_id = m.create_person_id) WHERE f.file_id = ?
                        ORDER BY f.file_id ASC";

                    my $h = $dbh->prepare($q);
                    $h->execute($id);
                    @each_row = $h->fetchrow_array();
                    push @file_info, [@each_row];
                }
            }
        }
    }

    return \@file_info;

}


=head2 get_all_cross_entries

    Class method.
    Returns all cross entries and basic info.
    Example: my @all_cross_entries = CXGN::Cross->get_all_cross_entries($schema);

=cut

sub get_all_cross_entries {
    my $self = shift;
    my $schema = $self->schema;
    my $cross_properties_ref = $self->field_crossing_data_order();

    my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "cross", "stock_type")->cvterm_id();
    my $female_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
    my $male_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();
    my $ploidy_level_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'ploidy_level', 'stock_property')->cvterm_id();
    my $genome_structure_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'genome_structure', 'stock_property')->cvterm_id();
    my $member_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "member_of", "stock_relationship")->cvterm_id();
    my $cross_experiment_type_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'cross_experiment', 'experiment_type')->cvterm_id();
    my $offspring_of_type_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'offspring_of', 'stock_relationship')->cvterm_id();
    my $cross_props_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "crossing_metadata_json", "stock_property")->cvterm_id();
    my $geolocation_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project location', 'project_property')->cvterm_id();

    my $pollination_date_key;
    my $number_of_seeds_key;

    if ($cross_properties_ref) {
        my @cross_properties = @$cross_properties_ref;

        if ('First Pollination Date' ~~ @cross_properties) {
            $pollination_date_key = 'First Pollination Date';
        } else {
            $pollination_date_key = 'Pollination Date';
        }

        if ('Number of Seeds Extracted' ~~ @cross_properties) {
            $number_of_seeds_key = 'Number of Seeds Extracted';
        } else {
            $number_of_seeds_key = 'Number of Seeds'
        }
    } else {
        $pollination_date_key = 'Pollination Date';
        $number_of_seeds_key = 'Number of Seeds';
    }

    my $q = "SELECT cross_table.cross_id, cross_table.cross_name, cross_table.cross_type, cross_table.female_id, cross_table.female_name, cross_table.female_ploidy, cross_table.female_genome_structure,
        cross_table.male_id, cross_table.male_name, cross_table.male_ploidy, cross_table.male_genome_structure, cross_table.crossing_experiment_id, cross_table.crossing_experiment_name, cross_table.crossing_experiment_description,
        cross_table.location_name, progeny_table.progeny_number, cross_table.field_info
        FROM
        (SELECT cross_stock.stock_id AS cross_id, cross_stock.uniquename AS cross_name, female_relationship.value AS cross_type, female_stock.stock_id AS female_id,
        female_stock.uniquename AS female_name, ploidy1.value AS female_ploidy, genome_structure1.value AS female_genome_structure, male_stock.stock_id AS male_id,
        male_stock.uniquename AS male_name, ploidy2.value AS male_ploidy, genome_structure2.value AS male_genome_structure,
        project.project_id AS crossing_experiment_id, project.name AS crossing_experiment_name, project.description AS crossing_experiment_description, nd_geolocation.description AS location_name,
        cross_info.value AS field_info
        FROM project JOIN nd_experiment_project ON (project.project_id = nd_experiment_project.project_id)
        JOIN projectprop ON (project.project_id = projectprop.project_id) AND projectprop.type_id = ?
        JOIN nd_geolocation ON (CAST(projectprop.value AS INT) = nd_geolocation.nd_geolocation_id)
        JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id) AND nd_experiment_stock.type_id = ?
        JOIN stock AS cross_stock ON (nd_experiment_stock.stock_id = cross_stock.stock_id) AND cross_stock.type_id = ?
        JOIN stock_relationship AS female_relationship ON (cross_stock.stock_id = female_relationship.object_id) AND female_relationship.type_id = ?
        JOIN stock AS female_stock ON (female_relationship.subject_id = female_stock.stock_id)
        LEFT JOIN stockprop AS ploidy1 ON (female_stock.stock_id = ploidy1.stock_id) AND ploidy1.type_id = ?
        LEFT JOIN stockprop AS genome_structure1 ON (female_stock.stock_id = genome_structure1.stock_id) AND genome_structure1.type_id = ?
        LEFT JOIN stock_relationship AS male_relationship ON (cross_stock.stock_id = male_relationship.object_id) AND male_relationship.type_id = ?
        LEFT JOIN stock AS male_stock ON (male_relationship.subject_id = male_stock.stock_id)
        LEFT JOIN stockprop AS ploidy2 ON (male_stock.stock_id = ploidy2.stock_id) AND ploidy2.type_id = ?
        LEFT JOIN stockprop AS genome_structure2 ON (male_stock.stock_id = genome_structure2.stock_id) AND genome_structure2.type_id = ?
        LEFT JOIN stockprop AS cross_info ON (cross_stock.stock_id = cross_info.stock_id) AND cross_info.type_id = ?) AS cross_table
        LEFT JOIN
        (SELECT DISTINCT stock.stock_id AS cross_id, COUNT (stock_relationship.subject_id) AS progeny_number
        FROM stock
        LEFT JOIN stock_relationship ON (stock.stock_id = stock_relationship.object_id) AND stock_relationship.type_id = ? WHERE stock.type_id = ?
        GROUP BY cross_id) AS progeny_table
        ON (cross_table.cross_id = progeny_table.cross_id) ORDER BY cross_table.cross_id ASC";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($geolocation_type_id, $cross_experiment_type_id, $cross_type_id, $female_parent_type_id, $ploidy_level_type_id, $genome_structure_type_id, $male_parent_type_id, $ploidy_level_type_id, $genome_structure_type_id, $cross_props_type_id, $offspring_of_type_id, $cross_type_id);

    my @cross_data = ();
    while(my ($cross_id, $cross_name, $cross_type, $female_id, $female_name, $female_ploidy, $female_genome_structure, $male_id, $male_name, $male_ploidy, $male_genome_structure, $project_id, $project_name, $project_description, $project_location, $progeny_count, $field_info) = $h->fetchrow_array()){
        my $pollination_date;
        my $number_of_seeds;
        if ($field_info){
            my $field_info_hash = decode_json $field_info;
            $pollination_date = $field_info_hash->{$pollination_date_key};

            $number_of_seeds = $field_info_hash->{$number_of_seeds_key};
        }
        push @cross_data, [$cross_id, $cross_name, $cross_type, $female_id, $female_name, $female_ploidy, $female_genome_structure, $male_id, $male_name, $male_ploidy, $male_genome_structure, $pollination_date, $number_of_seeds, $progeny_count, $project_id, $project_name, $project_description, $project_location];
    }

    return \@cross_data;
}


=head2 get_cross_transaction_ids_in_experiment

    Class method.
    Returns all cross transaction ids in a specific crossing experiment.
    Example: my @cross_transaction_ids = CXGN::Cross->get_cross_transaction_ids_in_experiment($schema, $trial_id);

=cut

sub get_cross_transaction_ids_in_experiment {
    my $self = shift;
    my $schema = $self->schema;
    my $trial_id = $self->trial_id;

    my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "cross", "stock_type")->cvterm_id();
    my $cross_transaction_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross_transaction_json', 'stock_property')->cvterm_id();

    my $q = "SELECT stock.stock_id, stock.uniquename, stockprop.value
        FROM nd_experiment_project
        JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN stock ON (nd_experiment_stock.stock_id = stock.stock_id) AND stock.type_id = ?
        LEFT JOIN stockprop ON (stock.stock_id = stockprop.stock_id) AND stockprop.type_id = ?
        WHERE nd_experiment_project.project_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($cross_type_id, $cross_transaction_type_id, $trial_id);

    my @info = ();
    while(my($cross_id, $cross_name, $cross_transaction_json) = $h->fetchrow_array()){
        if ($cross_transaction_json){
            my $cross_transaction_info = decode_json $cross_transaction_json;
            my %transaction_hash = %{$cross_transaction_info};
            my @transaction_ids = keys %transaction_hash;
            push @info, [$cross_id, $cross_name, [@transaction_ids]];
        } else {
            push @info, [$cross_id, $cross_name, [$cross_transaction_json]];
        }
    }

    return \@info;
}


=head2 get_accessions_missing_pedigree

    Class method.
    Returns all accessions missing pedigree.
    Example: my @accessions = CXGN::Cross->get_accessions_missing_pedigree ($schema);

=cut

sub get_accessions_missing_pedigree {
    my $self = shift;
    my $schema = shift;

    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();
    my $female_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();

    my $q = "SELECT table_1.stock_id, table_1.stock_name
        FROM
        (SELECT stock.stock_id AS stock_id, stock.uniquename AS stock_name
        FROM stock WHERE stock.type_id = ? and stock.is_obsolete <> 't') AS table_1
        LEFT JOIN
        (SELECT DISTINCT stock.stock_id AS stock_id, stock.uniquename AS stock_name
        FROM stock
        JOIN stock_relationship ON (stock.stock_id = stock_relationship.object_id) WHERE stock.type_id = ? AND stock_relationship.type_id = ?) AS table_2
        ON (table_1.stock_id = table_2.stock_id) WHERE table_2.stock_id IS NULL ORDER BY table_1.stock_id ASC";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($accession_type_id, $accession_type_id, $female_parent_type_id);

    my @accessions_missing_pedigree =();
    while(my($stock_id, $stock_name) = $h->fetchrow_array()){
        push @accessions_missing_pedigree, [$stock_id, $stock_name],
    }

    return \@accessions_missing_pedigree;

}


=head2 get_parents_and_numbers_of_progenies

    Class method.
    Returns all parent stock_ids, names and numbers of progenies in the database
    Example:
    my $cross_obj = CXGN::Cross(schema => schema, parent_type => 'female_parent');
    my @parent_info = $cross_obj->get_parents_and_numbers_of_progenies();

=cut

sub get_parents_and_numbers_of_progenies {
    my $self = shift;
    my $schema = $self->schema;
    my $parent_type = $self->parent_type();
    my $parent_type_id;
    if ($parent_type eq 'female_parent') {
        $parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "female_parent", "stock_relationship")->cvterm_id();
    } elsif ($parent_type eq 'male_parent') {
        $parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "male_parent", "stock_relationship")->cvterm_id();
    }
    my $female_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "female_parent", "stock_relationship")->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();

    my $dbh = $schema->storage->dbh();

    my $q = "SELECT DISTINCT stock.stock_id, stock.uniquename, COUNT (DISTINCT stock_relationship.object_id) AS num_of_progenies
        FROM stock_relationship INNER JOIN stock AS check_type ON (stock_relationship.object_id = check_type.stock_id)
        INNER JOIN stock ON (stock_relationship.subject_id = stock.stock_id)
        WHERE stock_relationship.type_id = ? AND check_type.type_id = ?
        GROUP BY stock.stock_id ORDER BY num_of_progenies DESC";

    my $h = $dbh->prepare($q);
    $h->execute($parent_type_id, $accession_type_id);

    my @data =();
    while (my ($parent_id, $parent_name, $num_of_progenies) = $h->fetchrow_array()){
        push @data, [$parent_id, $parent_name,$num_of_progenies];
    }

    return \@data;
}


=head2 get_plots_used_in_crossing_experiment

    Class method.
    Returns all plot names and ids used in a specific crossing_experiment.
    Example: my @plots = CXGN::Cross->get_plots_used_in_crossing_experiment($schema, $crossing_experiment_id)

=cut

sub get_plots_used_in_crossing_experiment {
    my $self = shift;
    my $schema = $self->schema;
    my $crossing_experiment_id = $self->trial_id;

    my $female_plot_of_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "female_plot_of", "stock_relationship")->cvterm_id();
    my $male_plot_of_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "male_plot_of", "stock_relationship")->cvterm_id();

    my $q = "SELECT DISTINCT stock.stock_id, stock.uniquename
        FROM nd_experiment_project
        JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN stock_relationship ON (nd_experiment_stock.stock_id = stock_relationship.object_id) AND stock_relationship.type_id IN (?,?)
        JOIN stock on (stock_relationship.subject_id = stock.stock_id)
        WHERE nd_experiment_project.project_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($female_plot_of_typeid, $male_plot_of_typeid, $crossing_experiment_id);

    my @all_plots = ();
    while(my($plot_id, $plot_name) = $h->fetchrow_array()){
        push @all_plots, [$plot_id, $plot_name]
    }

    return \@all_plots;
}


=head2 get_plots_of_plants_used_in_crossing_experiment

    Class method.
    Returns all plot names and ids of plants used in a specific crossing_experiment.
    Example: my @plots = CXGN::Cross->get_plots_of_plants_used_in_crossing_experiment($schema, $crossing_experiment_id)

=cut

sub get_plots_of_plants_used_in_crossing_experiment {
    my $self = shift;
    my $schema = $self->schema;
    my $crossing_experiment_id = $self->trial_id;

    my $female_plant_of_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "female_plant_of", "stock_relationship")->cvterm_id();
    my $male_plant_of_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "male_plant_of", "stock_relationship")->cvterm_id();
    my $plant_of_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "plant_of", "stock_relationship")->cvterm_id();

    my $q = "SELECT DISTINCT stock.stock_id, stock.uniquename
        FROM nd_experiment_project
        JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN stock_relationship AS parent_plant_relationship ON (nd_experiment_stock.stock_id = parent_plant_relationship.object_id) AND parent_plant_relationship.type_id IN (?,?)
        JOIN stock_relationship AS plant_plot_relationship ON (plant_plot_relationship.object_id = parent_plant_relationship.subject_id) AND plant_plot_relationship.type_id = ?
        JOIN stock on (plant_plot_relationship.subject_id = stock.stock_id)
        WHERE nd_experiment_project.project_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($female_plant_of_typeid, $male_plant_of_typeid, $plant_of_typeid, $crossing_experiment_id);

    my @all_plots = ();
    while(my($plot_id, $plot_name) = $h->fetchrow_array()){
        push @all_plots, [$plot_id, $plot_name]
    }

    return \@all_plots;
}



1;
