package SGN::Controller::TrialAllocation;

use Moose;
use URI::FromHash qw | uri |;

BEGIN { extends 'Catalyst::Controller' };


sub trial_field_index :Path('/tools/trialallocation') Args(0) { 

    my $self = shift;
    my $c = shift;

    if (!$c->user()) { 
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
    }
    
    $c->stash->{template} = '/tools/trialallocation.mas';
}

1;