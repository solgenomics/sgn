
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
use SGN::Controller::AJAX::ScriptFactory;

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
    # open the pipeline of a stored analysis or of a run
    $c->stash->{analysis_id} = $c->req->param('analysis_id');
    $c->stash->{run_id} = $c->req->param('run_id');
    $c->stash->{blupf90_available} = SGN::Controller::AJAX::ScriptFactory::blupf90_dir($c) ? 1 : 0;
    $c->stash->{template} = '/tools/script_factory/index.mas';
}

# decision dashboard of one analysis run; the data come from
# /ajax/script_factory/results, which checks the owner of the run
sub script_factory_results :Path('/tools/script_factory/results') Args(1) {
    my $self = shift;
    my $c = shift;
    my $run_id = shift;

    if (!$c->user()) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        $c->detach();
    }

    $c->stash->{run_id} = ($run_id // '') =~ /^sf_run_[A-Za-z0-9_]+$/ ? $run_id : '';
    $c->stash->{template} = '/tools/script_factory/results.mas';
}

# results dashboard of a stored analysis; the run is restored from the files
# archived with the analysis when its temporary files are gone
sub script_factory_analysis_results :Path('/tools/script_factory/analysis') Args(1) {
    my $self = shift;
    my $c = shift;
    my $analysis_id = shift;

    if (!$c->user()) {
        $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        $c->detach();
    }

    my $r = SGN::Controller::AJAX::ScriptFactory::analysis_run_id($c, $analysis_id);
    if ($r->{run_id}) {
        $c->res->redirect('/tools/script_factory/results/' . $r->{run_id});
        $c->detach();
    }
    $c->stash->{message} = $r->{error};
    $c->stash->{template} = '/generic_message.mas';
}

1;
