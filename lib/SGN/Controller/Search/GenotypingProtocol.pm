
package SGN::Controller::Search::GenotypingProtocol;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

sub genotyping_protocol_search_page : Path('/search/genotyping_protocols/') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/search/genotyping_protocols.mas';
}

1;
