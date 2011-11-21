package SGN::Controller::Search::Expression;
use Moose;

BEGIN{ extends 'Catalyst::Controller' }

sub auto : Private {
    $_[1]->stash->{template} = '/search/expression/stub.mas';
}

sub template_search : Path('/search/expression/template') Path('/search/expression') Args(0) {
    $_[1]->stash->{content} = CXGN::Search::CannedForms->expr_template_search_form();
}

sub experiment_search : Path('/search/expression/experiment') Args(0) {
    $_[1]->stash->{content} = CXGN::Search::CannedForms->expr_experiment_search_form();
}

sub platform_search : Path('/search/expression/platform') Args(0) {
    $_[1]->stash->{content} = CXGN::Search::CannedForms->expr_platform_search_form();
}

1;

