
package SGN::Controller::Search::GenotypingProtocol;

use Moose;
use URI::FromHash 'uri';

BEGIN { extends 'Catalyst::Controller'; }

sub genotyping_protocol_search_page : Path('/search/genotyping_protocols/') Args(0) {
    my $self = shift;
    my $c = shift;

    if (! $c->stash->{user_id}) { 
	$c->res->redirect(
	    uri(
		path => '/user/login',
		query => { goto_url => $c->req->uri->path_query }
	    )
        );
    }
    
    if (my $message = $c->stash->{access}->denied( $c->stash->{user_id}, "read", "genotyping" )) {
	$c->stash->{template} = '/access/access_denied.mas';
	$c->stash->{data_type} = 'genotype';
	$c->stash->{message} = $message;
	return;
    }

    $c->stash->{template} = '/search/genotyping_protocols.mas';
}

1;
