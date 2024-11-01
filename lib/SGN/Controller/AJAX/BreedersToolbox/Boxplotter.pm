package SGN::Controller::AJAX::BreedersToolbox::Boxplotter;

use Moose;
use Data::Dumper;
use CXGN::Dataset;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
  default   => 'application/json',
  stash_key => 'rest',
  map       => { 'application/json' => 'JSON' },
 );

sub get_constraints :Path('/ajax/tools/boxplotter/get_constraints') {
  my $self = shift;
  my $c = shift;
  my $sp_dataset_id = $c->req->param('dataset');
  my $unit = $c->req->param('unit');
  my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
  my $ds = CXGN::Dataset->new( 
    people_schema => $c->dbic_schema("CXGN::People::Schema", undef, $sp_person_id), 
    schema => $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id), 
    sp_dataset_id => $sp_dataset_id
  );
  if (!$c->user || $c->user->get_sp_person_id()!=$ds->sp_person_id()){
    $c->stash->{rest} = [];
    $c->response->status(403);
    print STDERR Dumper ["NOKAY"];
    return;
  }
  else {
    $c->stash->{rest} = $ds->get_dataset_data();
  }
}
