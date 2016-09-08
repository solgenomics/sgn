
package SGN::Controller::AJAX::BreedersToolbox::Population;

use Moose;
use Bio::GeneticRelationships::Population;
use List::MoreUtils qw | any |;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

   has 'schema' => (
   		 is       => 'rw',
   		 isa      => 'DBIx::Class::Schema',
   		 lazy_build => 1,
   		);

sub create_population :Path('/ajax/population/new') Args(0) {
    my $self = shift;
    my $c = shift;

    my $population_name = $c->req->param('population_name');
    my @members = $c->req->param('accessions[]');
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $population = Bio::GeneticRelationships::Population->new( { name => $population_name});
    $population->set_members(\@members);


    my $population_cvterm_id = $c->model("Cvterm")->get_cvterm_row($schema, "population", "stock_type");
    my $member_of_cvterm_id = $c->model("Cvterm")->get_cvterm_row($schema, "member_of", "stock_relationship");

    # create population stock entry
    #
    my $pop_rs = $schema->resultset("Stock::Stock")->create(
  {
      name => $population_name,
      uniquename => $population_name,
      type_id => $population_cvterm_id->cvterm_id(),
  });

     # generate population connections to the members
    foreach my $m (@members) {
  my $m_row = $schema->resultset("Stock::Stock")->find({ uniquename => $m });
  my $connection = $schema->resultset("Stock::StockRelationship")->create(
      {
    subject_id => $m_row->stock_id,
    object_id => $pop_rs->stock_id,
    type_id => $member_of_cvterm_id->cvterm_id(),
      });
    }
    $c->stash->{rest} = { message => "Success! Population created" };
    return;
}

1;
