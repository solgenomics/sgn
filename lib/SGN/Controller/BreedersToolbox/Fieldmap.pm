use strict;

package SGN::Controller::BreedersToolbox::Fieldmap;

use Moose;
use CXGN::Dataset;
use URI::FromHash 'uri';
use Data::Dumper;
BEGIN { extends 'Catalyst::Controller'; }

sub fieldmap :Path('/tools/fieldmap') {
  my $self =shift;
  my $c = shift;
  if (! $c->user) {
  	$c->res->redirect(uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
  	return;
  }
  $c->stash->{datasets} = CXGN::Dataset->get_datasets_by_user(
    $c->dbic_schema("CXGN::People::Schema"),
    $c->user->get_sp_person_id());
  $c->stash->{template} = '/tools/fieldmap.mas';
}
1;
