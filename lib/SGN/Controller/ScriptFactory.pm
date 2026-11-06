
=head1 NAME

SGN::Controller::ScriptFactory - page for the Script Factory analysis builder

=head1 DESCRIPTION

The Script Factory lets users build a phenotypic analysis pipeline step by
step (outlier removal, single or two stage models, selection index and
environmental zoning), run it on a dataset, store the results as an analysis
and save the pipeline as a reusable script.

=head1 AUTHOR

Chris Simoes <ccs263@cornell.edu>

=cut

package SGN::Controller::ScriptFactory;

use Moose;
use URI::FromHash qw | uri |;

BEGIN { extends 'Catalyst::Controller' };

sub script_factory_index :Path('/tools/script_factory') Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        $c->detach();
    }

    $c->stash->{recipe_id} = $c->req->param('recipe_id');
    $c->stash->{dataset_id} = $c->req->param('dataset_id');
    $c->stash->{template} = '/tools/script_factory/index.mas';
}

1;
