
package CXGN::Cross;

use Moose;
use SGN::Model::Cvterm;
use Data::Dumper;

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

    my $male_parent_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "male_parent", "stock_relationship")->cvterm_id();
    my $female_parent_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "female_parent", "stock_relationship")->cvterm_id();
    my $cross_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "cross", "stock_type")->cvterm_id();

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
	$h->execute($female_parent_typeid, $cross_typeid, $male_parent_typeid, $female_parent, $male_parent);
    }
    elsif ($female_parent) {
	$h->execute($female_parent_typeid, $cross_typeid, $male_parent_typeid, $female_parent);
    }
    elsif ($male_parent) {
  $h->execute($female_parent_typeid, $cross_typeid, $male_parent_typeid, $male_parent);
    }
    else {
  $h->execute($female_parent_typeid, $cross_typeid, $male_parent_typeid);
    }

    my @cross_info = ();
    while (my ($female_parent_id, $male_parent_id, $cross_entry_id, $female_parent_name, $male_parent_name, $cross_name, $cross_type) = $h->fetchrow_array()){
      push @cross_info, [$female_parent_id, $female_parent_name, $male_parent_id, $male_parent_name, $cross_entry_id, $cross_name, $cross_type]
    }
    #print STDERR Dumper(\@cross_info);
    return \@cross_info;
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

    my $male_parent_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "male_parent", "stock_relationship")->cvterm_id();
    my $female_parent_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "female_parent", "stock_relationship")->cvterm_id();
    my $accession_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();
    my $member_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "member_of", "stock_relationship")->cvterm_id();

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
        $h->execute($female_parent_typeid, $accession_typeid, $male_parent_typeid, $member_typeid, $female_parent_typeid, $female_parent, $male_parent);
    }
    elsif ($female_parent) {
        $h->execute($female_parent_typeid, $accession_typeid, $male_parent_typeid, $member_typeid, $female_parent_typeid, $female_parent);
    }
    elsif ($male_parent) {
        $h->execute($female_parent_typeid, $accession_typeid, $male_parent_typeid, $member_typeid, $female_parent_typeid, $male_parent);
    }
    else {
        $h->execute($female_parent_typeid, $accession_typeid, $male_parent_typeid, $member_typeid, $female_parent_typeid);
    }

    my @progeny_info = ();
    while (my($female_parent_id, $female_parent_name, $male_parent_id, $male_parent_name, $progeny_id, $progeny_name, $cross_type) = $h->fetchrow_array()){

    push @progeny_info, [$female_parent_id, $female_parent_name, $male_parent_id, $male_parent_name, $progeny_id, $progeny_name, $cross_type]
    }
      #print STDERR Dumper(\@progeny_info);
      return \@progeny_info;
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

	my $cross_typeid = SGN::Model::Cvterm->get_cvterm_row($schema, "cross", "stock_type")->cvterm_id();
	# delete the project entries
	#
	print STDERR "Deleting project entry for cross...\n";
	my $q1 = "delete from project where project_id=(SELECT project_id FROM nd_experiment_project JOIN nd_experiment_stock USING (nd_experiment_id) JOIN stock USING(stock_id) where stock_id=? and type_id = ?)";
	my $h1 = $dbh->prepare($q1);
	$h1->execute($self->cross_stock_id(), $cross_typeid);

	# delete the nd_experiment entries
	#
	print STDERR "Deleting nd_experiment entry for cross...\n";
	my $q2= "delete from nd_experiment where nd_experiment.nd_experiment_id=(SELECT nd_experiment_id FROM nd_experiment_stock JOIN stock USING (stock_id) where stock.stock_id=? and stock.type_id =?)";
	my $h2 = $dbh->prepare($q2);
	$h2->execute($self->cross_stock_id(), $cross_typeid);

	# delete the stock entries
	#
	my $q3 = "delete from stock where stock.stock_id=523823 and stock.type_id = ?";
	my $h3 = $dbh->prepare($q3);
	$h3->execute($self->cross_stock_id(), $cross_typeid);
    };

    if ($@) {
	print STDERR "An error occurred while deleting cross id ".$self->cross_stock_id()."\n";
	$dbh->rollback();
	return $@;
    }
    else {
	$dbh->commit();
    }
}

1;
