
package SGN::Controller::Search::Cross;

use Moose;

BEGIN { extends 'Catalyst::Controller' };

sub search_page : Path('/search/cross') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/search/cross.mas';

}


sub search_progenies_using_female : Path('/search/progenies_using_female') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/search/cross/progeny_search_using_female.mas';

}


sub search_progenies_using_male : Path('/search/progenies_using_male') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/search/cross/progeny_search_using_male.mas';

}


sub search_crosses_using_female : Path('/search/crosses_using_female') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/search/cross/cross_search_using_female.mas';

}


sub search_crosses_using_male : Path('/search/crosses_using_male') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/search/cross/cross_search_using_male.mas';

}


1;
