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
  my $trial_id = $c->request->param('trial_id');

  $c->stash->{trial_id} = $trial_id;
  $c->stash->{template} = '/tools/fieldmap.mas';
}
1;
