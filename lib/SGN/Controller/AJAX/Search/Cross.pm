

package SGN::Controller::AJAX::Search::Cross;

use Moose;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub search_male_parents :Path('/ajax/search/male_parents') :Args(0){
    my $self = shift;
    my $c = shift;
    my $female_parent= $c->req->param("female_parent");
     print STDERR "Female parent =" . Dumper($female_parent) . "\n";


    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $male_parent_typeid = $c->model("Cvterm")->get_cvterm_row($schema, "male_parent", "stock_relationship")->cvterm_id();
    my $female_parent_typeid = $c->model("Cvterm")->get_cvterm_row($schema, "female_parent", "stock_relationship")->cvterm_id();

    my $dbh = $schema->storage->dbh();

    my $q = "SELECT DISTINCT female_parent.stock_id, male_parent.stock_id, male_parent.uniquename FROM stock as female_parent
    INNER JOIN stock_relationship AS stock_relationship1 ON (female_parent.stock_id=stock_relationship1.subject_id)
    AND stock_relationship1.type_id= '$female_parent_typeid' INNER JOIN stock_relationship AS stock_relationship2
    ON (stock_relationship1.object_id=stock_relationship2.object_id) INNER JOIN stock AS male_parent
    ON (male_parent.stock_id=stock_relationship2.subject_id) AND stock_relationship2.type_id= '$male_parent_typeid'
    WHERE female_parent.uniquename= '$female_parent' ORDER BY male_parent.uniquename ASC";


    my $h = $dbh->prepare($q);
    $h->execute();

    my @male_parents=();
    while(my ($female_parent_id, $male_parent_id, $male_parent_name) = $h->fetchrow_array()){

      push @male_parents, [$male_parent_name];
    }

    $c->stash->{rest} = {data=>\@male_parents};

}

sub search : Path('/ajax/search/cross_info') Args(0) {
    my $self = shift;
    my $c = shift;

    my $female_parent = $c->req->param("female_parent");
    my $male_parent = $c->req->param("male_parent");

    print STDERR "Female parent =" . Dumper($female_parent) . "\n";
    print STDERR "Male parent =" . Dumper($male_parent) . "\n";



    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $male_parent_typeid = $c->model("Cvterm")->get_cvterm_row($schema, "male_parent", "stock_relationship")->cvterm_id();
    my $female_parent_typeid = $c->model("Cvterm")->get_cvterm_row($schema, "female_parent", "stock_relationship")->cvterm_id();
    my $cross_typeid = $c->model("Cvterm")->get_cvterm_row($schema, "cross", "stock_type")->cvterm_id();

    my $dbh = $schema->storage->dbh();



    my $q = "SELECT female_parent.stock_id, male_parent.stock_id, cross_entry.stock_id, female_parent.uniquename,male_parent.uniquename,cross_entry.uniquename FROM stock as female_parent
    INNER JOIN stock_relationship AS stock_relationship1 ON (female_parent.stock_id=stock_relationship1.subject_id)
    AND stock_relationship1.type_id='$female_parent_typeid' INNER JOIN stock_relationship AS stock_relationship2
    ON (stock_relationship1.object_id=stock_relationship2.object_id) INNER JOIN stock AS male_parent
    ON (male_parent.stock_id=stock_relationship2.subject_id) AND stock_relationship2.type_id='$male_parent_typeid'
    INNER JOIN stock AS cross_entry ON (cross_entry.stock_id=stock_relationship2.object_id) AND cross_entry.type_id='$cross_typeid'
    WHERE female_parent.uniquename = '$female_parent' AND male_parent.uniquename = '$male_parent'";

    my $h = $dbh->prepare($q);
    $h->execute();

    my @cross_info = ();
    while (my ($female_parent_id, $male_parent_id, $cross_entry_id, $female_parent_name, $male_parent_name, $cross_name) = $h->fetchrow_array()) {

	push @cross_info, [ qq{<a href="/stock/$female_parent_id/view">$female_parent_name</a}, qq{<a href="/stock/$male_parent_id/view">$male_parent_name</a}, qq{<a href="/stock/$cross_entry_id/view">$cross_name</a}];
  print STDERR "Cross info =" . Dumper(@cross_info) . "\n";
  }

  $c->stash->{rest}={ data=> \@cross_info};

}




1;
