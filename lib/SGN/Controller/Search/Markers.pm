=head1 NAME

SGN::Controller::Search::Markers

=head1 DESCRIPTION

Controller for unified marker / variant search page

=cut

package SGN::Controller::Search::Markers;

use strict;
use Moose;

BEGIN { extends 'Catalyst::Controller' }

#
# UNIFIED MARKER SEARCH PAGE
# PATH: /search/variants
#
sub search_variants : Path('/search/variants') Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{template} = '/search/markers/search.mas';
}


#
# VARIANT SEARCH RESULTS
# PATH: /search/variants/results
#
sub results_variants : Path('/search/variants/results') Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{template} = '/search/markers/results.mas';
}


1;
