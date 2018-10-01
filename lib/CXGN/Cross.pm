
package CXGN::Cross;

use Moose;
use SGN::Model::Cvterm;
use CXGN::Stock;
use Data::Dumper;
use JSON;

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'cross_stock_id' => (isa => "Int",
    is => 'rw',
    required => 0,
);

has 'female_parent' => (isa => 'Str',
    is => 'rw',
    required => 0,
);

has 'male_parent' => (isa => 'Str',
    is => 'rw',
    required => 0,
);

has 'trial_id' => (isa => "Int",
    is => 'rw',
    required => 0,
);



sub BUILD {
    my $self = shift;
    my $args = shift;
}

sub get_cross_relationships {
    my $self = shift;

    my $crs = $self->bcs_schema->resultset("Stock::StockRelationship")->search( { object_id => $self->cross_stock_id } );

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
        if ($child->type->name() eq "member_of") {
          push @progeny, [ $child->subject->name, $child->subject->stock_id() ];
        }
    }
    return ($maternal_parent, $paternal_parent, \@progeny);
}

=head2 get_cross_info

 Usage:         CXGN::Cross->get_cross_info( $schema, $female_parent, $male_parent);
 Desc:          Class method
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_cross_info {
    my $class = shift;
    my $schema = shift;
    my $female_parent = shift;
    my $male_parent = shift;

    my $male_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "male_parent", "stock_relationship")->cvterm_id();
    my $female_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "female_parent", "stock_relationship")->cvterm_id();
    my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "cross", "stock_type")->cvterm_id();

    my $where_female = "";
    if ($female_parent){
        $where_female = " WHERE female_parent.uniquename = ?";
    };

    my $where_male ="";
    if ($male_parent){
        $where_male = " AND male_parent.uniquename = ?";
    }

   my $q = "SELECT female_parent.stock_id, male_parent.stock_id, cross_entry.stock_id, female_parent.uniquename, male_parent.uniquename, cross_entry.uniquename, stock_relationship1.value
        FROM stock as female_parent INNER JOIN stock_relationship AS stock_relationship1 ON (female_parent.stock_id=stock_relationship1.subject_id)
        AND stock_relationship1.type_id= ? INNER JOIN stock AS cross_entry ON (cross_entry.stock_id=stock_relationship1.object_id) AND cross_entry.type_id= ?
        LEFT JOIN stock_relationship AS stock_relationship2 ON (cross_entry.stock_id=stock_relationship2.object_id) AND stock_relationship2.type_id= ?
        LEFT JOIN stock AS male_parent ON (male_parent.stock_id=stock_relationship2.subject_id)
        $where_female $where_male ORDER BY stock_relationship1.value, male_parent.uniquename";

    my $h = $schema->storage->dbh()->prepare($q);

    if ($female_parent && $male_parent) {
        $h->execute($female_parent_type_id, $cross_type_id, $male_parent_type_id, $female_parent, $male_parent);
    }
    elsif ($female_parent) {
        $h->execute($female_parent_type_id, $cross_type_id, $male_parent_type_id, $female_parent);
    }
    elsif ($male_parent) {
        $h->execute($female_parent_type_id, $cross_type_id, $male_parent_type_id, $male_parent);
    }
    else {
        $h->execute($female_parent_type_id, $cross_type_id, $male_parent_type_id);
    }

    my @cross_info = ();
    while (my ($female_parent_id, $male_parent_id, $cross_entry_id, $female_parent_name, $male_parent_name, $cross_name, $cross_type) = $h->fetchrow_array()){
        push @cross_info, [$female_parent_id, $female_parent_name, $male_parent_id, $male_parent_name, $cross_entry_id, $cross_name, $cross_type]
    }
    #print STDERR Dumper(\@cross_info);
    return \@cross_info;
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

    my $male_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "male_parent", "stock_relationship")->cvterm_id();
    my $female_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "female_parent", "stock_relationship")->cvterm_id();
    my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "cross", "stock_type")->cvterm_id();
    my $member_type_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'member_of', 'stock_relationship')->cvterm_id();
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
    $h->execute($cross_type_id, $female_parent_type_id, $female_parent_id, $male_parent_type_id, $male_parent_id, $member_type_id, $progeny_id, $cross_experiment_type_cvterm_id, $project_year_cvterm_id);

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
        return undef;
    }
}


=head2 get_progeny_info

 Usage:         CXGN::Cross->get_progeny_info( $schema, $female_parent, $male_parent);
 Desc:          Class method
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

    my $male_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "male_parent", "stock_relationship")->cvterm_id();
    my $female_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "female_parent", "stock_relationship")->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();
    my $member_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "member_of", "stock_relationship")->cvterm_id();

    my $where_female = "";
    if ($female_parent){
        $where_female = " WHERE female_parent.uniquename = ?";
    };

    my $where_male ="";
    if ($male_parent){
        $where_male = " AND male_parent.uniquename = ?";
    }

    my $q = "SELECT DISTINCT female_parent.stock_id, female_parent.uniquename, male_parent.stock_id, male_parent.uniquename, progeny.stock_id, progeny.uniquename, CONCAT(stock_relationship1.value, stock_relationship4.value) AS type
        FROM stock_relationship as stock_relationship1
        INNER JOIN stock AS female_parent ON (stock_relationship1.subject_id = female_parent.stock_id) AND stock_relationship1.type_id = ?
        INNER JOIN stock AS progeny ON (stock_relationship1.object_id = progeny.stock_id) AND progeny.type_id = ?
        LEFT JOIN stock_relationship AS stock_relationship2 ON (progeny.stock_id = stock_relationship2.object_id) AND stock_relationship2.type_id = ?
        LEFT JOIN stock AS male_parent ON (stock_relationship2.subject_id = male_parent.stock_id)
        LEFT JOIN stock_relationship AS stock_relationship3 ON (progeny.stock_id = stock_relationship3.subject_id) AND stock_relationship3.type_id = ?
        LEFT JOIN stock_relationship AS stock_relationship4 ON (stock_relationship3.object_id = stock_relationship4.object_id) AND stock_relationship4.type_id = ?
        $where_female $where_male ORDER BY male_parent.uniquename";

    my $h = $schema->storage->dbh()->prepare($q);

    if($female_parent && $male_parent){
        $h->execute($female_parent_type_id, $accession_type_id, $male_parent_type_id, $member_type_id, $female_parent_type_id, $female_parent, $male_parent);
    }
    elsif ($female_parent) {
        $h->execute($female_parent_type_id, $accession_type_id, $male_parent_type_id, $member_type_id, $female_parent_type_id, $female_parent);
    }
    elsif ($male_parent) {
        $h->execute($female_parent_type_id, $accession_type_id, $male_parent_type_id, $member_type_id, $female_parent_type_id, $male_parent);
    }
    else {
        $h->execute($female_parent_type_id, $accession_type_id, $male_parent_type_id, $member_type_id, $female_parent_type_id);
    }

    my @progeny_info = ();
    while (my($female_parent_id, $female_parent_name, $male_parent_id, $male_parent_name, $progeny_id, $progeny_name, $cross_type) = $h->fetchrow_array()){

        push @progeny_info, [$female_parent_id, $female_parent_name, $male_parent_id, $male_parent_name, $progeny_id, $progeny_name, $cross_type]
    }
      #print STDERR Dumper(\@progeny_info);
    return \@progeny_info;
}

=head2 get_crosses_in_trial


=cut

sub get_crosses_in_trial {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $trial_id = $self->trial_id;

    my $male_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "male_parent", "stock_relationship")->cvterm_id();
    my $female_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "female_parent", "stock_relationship")->cvterm_id();
    my $female_plot_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "female_plot_of", "stock_relationship")->cvterm_id();
    my $male_plot_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "male_plot_of", "stock_relationship")->cvterm_id();
    my $female_plant_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "female_plant_of", "stock_relationship")->cvterm_id();
    my $male_plant_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "male_plant_of", "stock_relationship")->cvterm_id();

    my $q = "SELECT stock1.stock_id, stock1.uniquename, stock_relationship1.value, stock2.stock_id, stock2.uniquename, stock3.stock_id, stock3.uniquename, stock4.stock_id, stock4.uniquename, stock5.stock_id, stock5.uniquename, stock6.stock_id, stock6.uniquename, stock7.stock_id, stock7.uniquename
        FROM nd_experiment_project JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN stock AS stock1 ON (nd_experiment_stock.stock_id = stock1.stock_id)
        LEFT JOIN stock_relationship AS stock_relationship1 ON (stock1.stock_id = stock_relationship1.object_id) AND stock_relationship1.type_id = ?
        LEFT JOIN stock AS stock2 ON (stock_relationship1.subject_id = stock2.stock_id)
        LEFT JOIN stock_relationship AS stock_relationship2 ON (stock1.stock_id = stock_relationship2.object_id) AND stock_relationship2.type_id = ?
        LEFT JOIN stock AS stock3 ON (stock_relationship2.subject_id = stock3.stock_id)
        LEFT JOIN stock_relationship AS stock_relationship3 ON (stock1.stock_id = stock_relationship3.object_id) AND stock_relationship3.type_id = ?
        LEFT JOIN stock AS stock4 ON (stock_relationship3.subject_id = stock4.stock_id)
        LEFT JOIN stock_relationship AS stock_relationship4 ON (stock1.stock_id = stock_relationship4.object_id) AND stock_relationship4.type_id = ?
        LEFT JOIN stock AS stock5 ON (stock_relationship4.subject_id = stock5.stock_id)
        LEFT JOIN stock_relationship AS stock_relationship5 ON (stock1.stock_id = stock_relationship5.object_id) AND stock_relationship5.type_id = ?
        LEFT JOIN stock AS stock6 ON (stock_relationship5.subject_id = stock6.stock_id)
        LEFT JOIN stock_relationship AS stock_relationship6 ON (stock1.stock_id = stock_relationship6.object_id) AND stock_relationship6.type_id = ?
        LEFT JOIN stock AS stock7 ON (stock_relationship6.subject_id = stock7.stock_id)
        WHERE nd_experiment_project.project_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($female_parent_type_id, $male_parent_type_id, $female_plot_of_type_id, $male_plot_of_type_id, $female_plant_of_type_id, $male_plant_of_type_id, $trial_id);

    my @data =();
    while(my($cross_id, $cross_name, $cross_type, $female_parent_id, $female_parent_name, $male_parent_id, $male_parent_name, $female_plot_id, $female_plot_name, $male_plot_id, $male_plot_name, $female_plant_id, $female_plant_name, $male_plant_id, $male_plant_name) = $h->fetchrow_array()){
        push @data, [$cross_id, $cross_name, $cross_type, $female_parent_id, $female_parent_name, $male_parent_id, $male_parent_name, $female_plot_id, $female_plot_name, $male_plot_id, $male_plot_name, $female_plant_id, $female_plant_name, $male_plant_id, $male_plant_name]
    }
    return \@data;
}

=head2 get_cross_properties_trial


=cut

sub get_cross_properties_trial {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $trial_id = $self->trial_id;

    my $cross_props_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "crossing_metadata_json", "stock_property")->cvterm_id();

    my $q = "SELECT stock.stock_id, stock.uniquename, stockprop.value FROM nd_experiment_project
        JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        LEFT JOIN stockprop ON (nd_experiment_stock.stock_id = stockprop.stock_id)
        LEFT JOIN stock ON (stockprop.stock_id = stock.stock_id)
        WHERE stockprop.type_id = ? AND nd_experiment_project.project_id = ?";

    my $h = $schema->storage->dbh()->prepare ($q);

    $h->execute($cross_props_type_id, $trial_id);

    my @data = ();
    while(my($cross_id, $cross_name, $cross_props) = $h->fetchrow_array()){
      #print STDERR Dumper $cross_props;
        my $cross_props_hash = decode_json$cross_props;
        push @data, [$cross_id, $cross_name, $cross_props_hash]
    }

    return \@data;

}

=head2 get_cross_progenies_trial


=cut

sub get_cross_progenies_trial {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $trial_id = $self->trial_id;

    my $member_of_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "member_of", "stock_relationship")->cvterm_id();
    my $family_name_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "family_name", "stock_property")->cvterm_id();

    my $q = "SELECT progeny_count_table.cross_id, progeny_count_table.cross_name, progeny_count_table.progeny_number, stockprop.value
        FROM
        (SELECT DISTINCT stock.stock_id AS cross_id, stock.uniquename AS cross_name, COUNT (stock_relationship.subject_id) AS progeny_number
        FROM nd_experiment_project JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN stock ON (nd_experiment_stock.stock_id = stock.stock_id)
        LEFT JOIN stock_relationship ON (stock.stock_id = stock_relationship.object_id) AND stock_relationship.type_id = ?
        WHERE nd_experiment_project.project_id = ? GROUP BY cross_id)
        AS progeny_count_table
        LEFT JOIN stockprop ON (progeny_count_table.cross_id = stockprop.stock_id) AND stockprop.type_id = ?";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($member_of_type_id, $trial_id, $family_name_type_id);

    my @data =();
    while(my($cross_id, $cross_name, $progeny_number, $family_name) = $h->fetchrow_array()){
        push @data, [$cross_id, $cross_name, $progeny_number, $family_name]
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

    my $dbh = $self->bcs_schema()->storage()->dbh();
    my $schema = $self->bcs_schema();

    eval {
	$dbh->begin_work();

	my $properties = $self->cross_properties();

	my $can_delete = 
	    ($properties->{trials} == 0) && 
	    ($properties->{traits} == 0) && 
	    ($properties->{genotypes} == 0) && 
	    ($properties->{images} == 0);

	if (! $can_delete) {
	    return "Cross has associated data. ($properties->{trials} trials, $properties->{traits} traits and $properties->{genoytpes} genotypes. Cannot delete...\n";
	}
	else { 
	    print STDERR "This cross has no associated data that would prevent deletion.";
	}
	my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "cross", "stock_type")->cvterm_id();

	# delete the nd_experiment entries
	#
	print STDERR "Deleting nd_experiment entry for cross...\n";
	my $q2= "delete from nd_experiment where nd_experiment.nd_experiment_id=(SELECT nd_experiment_id FROM nd_experiment_stock JOIN stock USING (stock_id) where stock.stock_id=? and stock.type_id =?)";
	my $h2 = $dbh->prepare($q2);
	$h2->execute($self->cross_stock_id(), $cross_type_id);

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

	# delete the progeny...
	#
	print STDERR "Deleting the progeny...\n";
	my $q5 = "delete from stock where stock_id =?";
	my $h5 = $dbh->prepare();
	foreach my $progeny (@{$properties->{subjects}}) { 
	    print STDERR "...Deleting progeny with stock_id $progeny->[0], name $progeny->[1], type $progeny->[2]...\n";
	    $h5->execute($progeny->[0]);
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

sub cross_properties { 
    my $self = shift;

    my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema(), "cross", "stock_type")->cvterm_id();
    
    print STDERR "sub cross_deletion_possible...\n";
    my $q = "SELECT subject.stock_id, subject.uniquename, cvterm.name from stock join stock_relationship on (stock.stock_id=stock_relationship.object_id) join stock as subject on(stock_relationship.subject_id=subject.stock_id) join cvterm on (stock_relationship.type_id=cvterm.cvterm_id) where stock.stock_id = ? and stock.type_id=?";

    my $h = $self->bcs_schema->storage->dbh()->prepare($q);
    
    $h->execute($self->cross_stock_id(), $cross_type_id);

    my @subjects = ();
    my $has_trials = 0;
    my $has_traits = 0;
    my $has_genotypes = 0;
    my $has_images;

    while (my($stock_id, $name, $type) = $h->fetchrow_array()) { 
	print STDERR "ID $stock_id NAME $name TYPE $type\n";
	push @subjects, [$stock_id, $name, $type];
	
	if ($type eq "member_of") { # child
	    my $s = CXGN::Stock->new( { schema => $self->bcs_schema(),  stock_id => $stock_id });
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
		$has_images += scalar(\@image_ids);
	    }
	}
    }
    return { 
	traits => $has_traits,
	trials => $has_trials,
	genotypes => $has_genotypes,
	images => $has_images,
	subjects => @subjects,
    };
}

1;
