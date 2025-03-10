
package SGN::Controller::Search::StocksUsingGenotypes;

use Moose;
use URI::FromHash 'uri';

BEGIN { extends 'Catalyst::Controller' };

sub search_stocks_using_genotypes : Path('/search/stocks_using_genotypes') Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {
        # redirect to login page
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    if (my $message = $c->stash->{access}->denied( $c->stash->{user_id}, "read", "genotyping" )) {
	$c->stash->{template} = '/access/access_denied.mas';
	$c->stash->{data_type} = 'genotype';
	$c->stash->{message} = $message;
	return;
    }

    $c->stash->{template} = '/search/stocks_using_genotypes.mas';
}

1;
