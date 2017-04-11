
package SGN::Controller::ExpressionTool;

use Moose;

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
	$c->stash->{has_expression_atlas} = $c->config->{has_expression_atlas};
	$c->stash->{expression_atlas_url} = $c->config->{expression_atlas_url};
	$c->stash->{site_project_name} = $c->config->{project_name};
	$c->stash->{template} = '/tools/expression/expression_atlas.mas';
}

1;
