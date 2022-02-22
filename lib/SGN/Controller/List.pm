package SGN::Controller::List;

use Moose;
use URI::FromHash 'uri';
use Data::Dumper;


BEGIN { extends 'Catalyst::Controller'; }


sub list_details :Path('/list/details') :Args(0) {
    my $self = shift;
    my $c = shift;
    my $list_id = $c->req->param('list_id');

    if (! $c->user()) {
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    my $list = CXGN::List->new( { dbh => $c->dbc->dbh, list_id=>$list_id });

    $c->stash->{list_id} = $list_id;
    $c->stash->{list_name} = $list->name;
    $c->stash->{list_description} = $list->description;
    $c->stash->{list_type} = $list->type;
    $c->stash->{list_size} = $list->list_size;
    $c->stash->{template} = '/list/list_details.mas';

}



1;
