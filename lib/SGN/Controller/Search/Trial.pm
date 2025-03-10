
package SGN::Controller::Search::Trial;

use Moose;
use URI::FromHash 'uri';

BEGIN { extends 'Catalyst::Controller'; }

sub trial_search_page : Path('/search/trials/') Args(0) {
    my $self = shift;
    my $c = shift;

    if (! $c->stash->{user_id}) { 
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
    }

    
    if (my $message = $c->stash->{access}->denied( $c->stash->{user_id}, "read", "trials" )) {
	$c->stash->{template} = '/access/access_denied.mas';
	$c->stash->{data_type} = 'trial';
	$c->stash->{message} = $message;
	return;
    }

    
    $c->stash->{location_id} = $c->req->param('location_id') || 'not_provided';
    $c->stash->{template} = '/search/trials.mas';

}

sub genotyping_trial_search_page : Path('/search/genotyping_trials/') Args(0) {
    my $self = shift;
    my $c = shift;

    if (! $c->stash->{user_id}) { 
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
    }

    
    if (my $message = $c->stash->{access}->denied( $c->stash->{user_id}, "read", "genotyping" )) {
	$c->stash->{template} = '/access/access_denied.mas';
	$c->stash->{data_type} = 'genotype';
	$c->stash->{message} = $message;
	return;
    }

    
    $c->stash->{template} = '/search/genotyping_trials.mas';
}

sub genotyping_data_project_search_page : Path('/search/genotyping_data_projects/') Args(0) {
    my $self = shift;
    my $c = shift;

    if (! $c->stash->{user_id}) { 
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
    }

    
    if (my $message = $c->stash->{access}->denied( $c->stash->{user_id}, "read", "genotyping" )) {
	$c->stash->{template} = '/access/access_denied.mas';
	$c->stash->{data_type} = 'genotype';
	$c->stash->{message} = $message;
	return;
    }

    $c->stash->{template} = '/search/genotyping_data_projects.mas';
}

1;
