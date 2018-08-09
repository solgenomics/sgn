
package SGN::Controller::Search::Trial;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

sub trial_search_page : Path('/search/trials/') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{nd_geolocation} = $c->req->param('nd_geolocation') || 'not_provided';
    $c->stash->{template} = '/search/trials.mas';

}

sub genotyping_trial_search_page : Path('/search/genotyping_trials/') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/search/genotyping_trials.mas';
}

sub genotyping_data_project_search_page : Path('/search/genotyping_data_projects/') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/search/genotyping_data_projects.mas';
}

1;
