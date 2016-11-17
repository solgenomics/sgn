

package SGN::Controller::AJAX::Search::Crosses;

use Moose;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub search_male_parents :Path('/ajax/search/crosses/male_parents') :Args(0) {
    my $self = shift;
    my $c = shift;
    my $female_parent_uniquename = $c->req->param("female_parent_name");

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
  #  my $male_parent_reltype = $c->model("Cvterm")->get_cvterm_row($schema, "male_parent", "stock_relationship");
  #  my $female_parent_reltype = $c->model("Cvterm")->get_cvterm_row($schema, "female_parent", "stock_relationship");

    my $female_parent_rs = $schema->resultset("Stock::Stock")->search( { uniquename => $female_parent_uniquename });

    if ($female_parent_rs->count == 0) {
  	$c->stash->{rest} = { error => "Female parent does not exist" };
	return;
    }

    my $female_parent_id = $female_parent_rs->first()->stock_id();

    my $q = "SELECT DISTINCT (male_parent.stock_id), male_parent.uniquename FROM stock AS female_parent JOIN stock_relationship AS mother_children ON(female_parent.stock_id=mother_children.subject_id) JOIN stock AS children on(mother_children.object_id = children.stock_id) join stock_relationship as father_children on (father_children.object_id = children.stock_id) join stock as male_parent  on (male_parent.stock_id=father_children.subject_id) WHERE mother_children.type_id=76437 and father_children.type_id=76438 AND female_parent.uniquename = 'UG120001';

   #my $q = "SELECT DISTINCT paternal_parent.uniquename FROM stock AS maternal_parent INNER JOIN stock_relationship AS stock_relationship1 ON (maternal_parent.stock_id=stock_relationship1.subject_id) AND stock_relationship1.type_id=76437 INNER JOIN stock_relationship AS stock_relationship2 ON (stock_relationship1.object_id=stock_relationship2.object_id) INNER JOIN stock AS paternal_parent ON (paternal_parent.stock_id=stock_relationship2.subject_id) AND stock_relationship2.type_id=76438";

  # print STDERR $q." ".$female_parent_reltype->cvterm_id().", ".$male_parent_reltype->cvterm_id().", ".$female_parent_uniquename."\n";

    my $h = $c->dbc->dbh()->prepare($q);
    $h->execute();

  $h->execute($female_parent_reltype->cvterm_id(), $male_parent_reltype->cvterm_id(), $female_parent_uniquename);

    my @male_parent=();
      while (my ($paternal_parent_uniquename) = $h->fetchrow_array()) {

      push @male_parent, [$paternal_parent_uniquename];

}

$c->stash->{rest}={data=> \@male_parent};

}

    my @male_parents=();
    while (my ($id, $uniquename) = $h->fetchrow_array()) {
	push @male_parents, [ $id, $uniquename ];
    }

    $c->stash->{rest} = {
	female_parent => [ $female_parent_id, $female_parent_uniquename ],
	male_parents => \@male_parents,
    };

}

sub search :Path('/ajax/search/crosses') Args(0) {
    my $self = shift;
    my $c = shift;

  #  my $female_parent_id = $c->req->param("female_parent_id");
  # my $male_parent_id = $c->req->param("male_parent_id");
  #  my $breeding_program = $c->req->param("breeding_program");
  #  my $year = $c->req->param("year");

    #my $params = $c->req->param();

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
  #  my $male_parent_reltype = $c->model("Cvterm")
#	->get_cvterm_row($schema, "male_parent", "stock_relationship")->cvterm_id();
#    my $female_parent_reltype = $c->model("Cvterm")
#	->get_cvterm_row($schema, "female_parent", "stock_relationship")->cvterm_id();
  # my $cross_name_type_id = $c->model("Cvterm")
	#->get_cvterm_row($schema, "cross_name", "stock_relationship")->cvterm_id();

    my $dbh = $schema->storage->dbh();

    #my $q = "SELECT stock_id, name, uniquename, nd_experimentprop.nd_experiment_id, nd_experimentprop.value FROM stock JOIN nd_experiment_stock USING (stock_id) JOIN nd_experimentprop USING(nd_experiment_id) JOIN stock_relationship AS female_parent_rel ON (stock.stock_id=female_parent_rel.subject_id) LEFT JOIN stock_relationship AS male_parent_rel ON (stock.stock_id=male_parent_rel.subject_id) WHERE female_parent_rel.type_id=? AND male_parent_rel.type_id=? AND female_parent_rel.object_id=? and male_parent_rel.object_id=? AND nd_experimentprop.type_id=?";
    my $q = "SELECT maternal_parent.name,paternal_parent.name,cross_entry.name FROM stock as maternal_parent INNER JOIN stock_relationship AS stock_relationship1 ON (maternal_parent.stock_id=stock_relationship1.subject_id) AND stock_relationship1.type_id=76437 INNER JOIN stock_relationship AS stock_relationship2 ON (stock_relationship1.object_id=stock_relationship2.object_id) INNER JOIN stock AS paternal_parent ON (paternal_parent.stock_id=stock_relationship2.subject_id) AND stock_relationship2.type_id=76438 INNER JOIN stock AS cross_entry ON (cross_entry.stock_id=stock_relationship2.object_id) AND cross_entry.type_id=76446";

    my $h = $dbh->prepare($q);
    $h->execute();

    #$h->execute($female_parent_reltype, $male_parent_reltype, $female_parent_id, $male_parent_id, $cross_name_type_id);

    my @cross_info = ();
    while (my ($maternal_parent_name, $paternal_parent_name, $cross_name) = $h->fetchrow_array()) {

    #while (my ($stock_id, $name, $uniquename, $cross_nd_experiment_id, $cross_name) = $h->fetchrow_array()) {
	push @cross_info, [ $maternal_parent_name, $paternal_parent_name, $cross_name ];

  }

  $c->stash->{rest}={ data=> \@cross_info};
}




1;
