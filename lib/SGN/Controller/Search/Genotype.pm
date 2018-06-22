
package SGN::Controller::Search::Genotype;

use Moose;

BEGIN { extends 'Catalyst::Controller' };

sub genotype_search_page : Path('/search/genotype') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/search/genotype.mas';

}

1;
