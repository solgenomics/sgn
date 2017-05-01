
package SGN::Controller::ExpressionTool;

use Moose;
use Data::Dumper;
use URI::FromHash 'uri';

#use CXGN::DB::Connection;
#use CXGN::BlastDB;
#use CXGN::Page::FormattingHelpers qw| page_title_html info_table_html hierarchical_selectboxes_html |;
#use CXGN::Page::UserPrefs;


BEGIN { extends 'Catalyst::Controller'; }


sub input :Path('/tools/expression/')  :Args(0) { 
    my ($self, $c) = @_;
    $c->stash->{template} = '/tools/expression/input.mas';
}


sub expression_atlas :Path('/tools/expression_atlas/')  :Args(0) {
    my ($self, $c) = @_;
    if (!$c->user()) {
        $c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) );
        $c->detach;
    }
    $c->stash->{user_name} = $c->user->get_object->get_username;
    $c->stash->{has_expression_atlas} = $c->config->{has_expression_atlas};
    $c->stash->{expression_atlas_url} = $c->config->{expression_atlas_url};
    $c->stash->{site_project_name} = $c->config->{project_name};
    $c->stash->{sgn_session_id} = $c->req->cookie('sgn_session_id');
    $c->stash->{template} = '/tools/expression/expression_atlas.mas';
}

1;
