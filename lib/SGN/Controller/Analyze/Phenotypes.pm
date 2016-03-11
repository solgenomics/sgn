
package SGN::Controller::Analyze::Phenotypes;

use strict;
use warnings;
use Moose;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller'; }

sub breeder_download : Path('/analyze/phenotypes/') Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {
	# redirect to login page
	$c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) );
	return;
    }

    $c->stash->{template} = '/analyze/phenotypes.mas';
}

1;


