use strict;

package SGN::Controller::BreedersToolbox::GraphicalFiltering;

use Moose;
use URI::FromHash 'uri';


BEGIN { extends 'Catalyst::Controller'; }

sub graphical_filtering :Path('/tools/graphicalfiltering') {
  my $self =shift;
  my $c = shift;
  if (! $c->user) {
  	$c->res->redirect(uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) );
  	return;
  }
  $c->assets->include('/static/css/tools/GraphicalFiltering.css');
  $c->stash->{template} = '/tools/graphicalfiltering/index.mas';
}
1;
