
package SGN::Controller::Search::StocksUsingGenotypes;

use Moose;

BEGIN { extends 'Catalyst::Controller' };

sub search_stocks_using_genotypes : Path('/search/stocks_using_genotypes') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/search/stocks_using_genotypes.mas';

}

1;
