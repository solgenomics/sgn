package SGN::Controller::Report;

use Moose;
use URI::FromHash qw | uri |;

BEGIN { extends 'Catalyst::Controller' };


sub quality_control_index :Path('/tools/report') Args(0) { 

    my $self = shift;
    my $c = shift;

    if (!$c->user()) { 
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
    }
    
    $c->stash->{template} = '/tools/report.mas';
}

1;
