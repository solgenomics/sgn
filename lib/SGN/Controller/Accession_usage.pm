package SGN::Controller::Accession_usage;

use Moose;
use URI::FromHash 'uri';

BEGIN { extends 'Catalyst::Controller' };

sub accession_usage : Path('/accession_usage') Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {
        # redirect to login page
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    $c->stash->{template} = '/stock/accession_usage.mas';
}

1;
