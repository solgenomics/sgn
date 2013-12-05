
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


1;
