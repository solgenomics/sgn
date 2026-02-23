
package SGN::Controller::Wiki;

use Moose;
use URI::FromHash 'uri';

BEGIN { extends 'Catalyst::Controller'; }




sub view_page :Path('/wiki/') Args(1) {
    my $self = shift;
    my $c = shift;

    my $page_name = shift;

    if (! $c->user()) {
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
    }

    $c->stash->{page_name} = $page_name;
    $c->stash->{template} = '/wiki/view.mas';

}


sub view_home :Path('/wiki/') Args(0) {
    my $self = shift;
    my $c = shift;

    print STDERR "WIKI HOME\n";

    if (! $c->user()) {
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
    }

    $c->stash->{template} = '/wiki/view.mas';
}

sub all_pages :Path('/wiki/all_pages') Args(0) {
    my $self = shift;
    my $c = shift;

    if (! $c->user()) {
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
    }

    my $wiki = CXGN::People::Wiki->new( { people_schema => $c->dbic_schema("CXGN::People::Schema") } );

    my @all_pages = $wiki->all_pages();

    $c->stash->{all_pages} = \@all_pages;
    $c->stash->{template} = '/wiki/all_pages.mas';
}


1;
