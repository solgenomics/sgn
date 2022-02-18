package SGN::Controller::List;

use Moose;
use URI::FromHash 'uri';
use Data::Dumper;


BEGIN { extends 'Catalyst::Controller'; }


sub list_seedlot_details :Path('/list/seedlot/details') :Args(0) {
    my $self = shift;
    my $c = shift;
    my $list_id = $c->req->param('list_id');
    print STDERR "LIST ID =".Dumper($list_id)."\n";

    if (! $c->user()) {
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    $c->stash->{list_id} = $list_id;

    $c->stash->{template} = '/list/list_details.mas';

}



1;
