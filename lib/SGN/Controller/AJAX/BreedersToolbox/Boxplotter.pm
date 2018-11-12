package SGN::Controller::AJAX::BreedersToolbox::Boxplotter;

use Moose;
use Data::Dumper;
use CXGN::Dataset;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
  default   => 'application/json',
  stash_key => 'rest',
  map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
 );

sub get_obs_unit_ids :Path('/ajax/tools/boxplotter/get_obs_unit_ids') {
  my $self = shift;
  my $c = shift;
  my $sp_dataset_id = $c->req->param('dataset');
  my $unit = $c->req->param('unit');
  my $ds = CXGN::Dataset->new( 
    people_schema => $c->dbic_schema("CXGN::People::Schema"), 
    schema => $c->dbic_schema("Bio::Chado::Schema"), 
    sp_dataset_id => $sp_dataset_id
  );
  if (!$c->user || $c->user->get_sp_person_id()!=$ds->sp_person_id()){
    $c->stash->{rest} = [];
    $c->response->status(403);
    print STDERR Dumper ["NOKAY"];
    return;
  }
  else {
    if ($unit eq "plots"){
      $c->stash->{rest} = $ds->retrieve_plots();
      print STDERR Dumper $ds->retrieve_plots();
    } 
    elsif ($unit eq "plants"){
      $c->stash->{rest} = $ds->retrieve_plants();
    }
    print STDERR Dumper "EITHER";
  }
}
