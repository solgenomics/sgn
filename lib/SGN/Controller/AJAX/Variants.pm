
=head1 NAME

SGN::Controller::AJAX::Search::Variants

=head1 DESCRIPTION

The AJAX endpoints in this class can be used to get query results from the 
unified marker materialized view (containing marker info combined from all
genotype protocols) and info related to the markers and genotype protocols.

=head1 AUTHOR

David Waring <djw64@cornell.edu>

=cut


use strict;

package SGN::Controller::AJAX::Search::Variants;

use Moose;
use JSON;
use CXGN::Marker::SearchMatView;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
);


#
# Get a list of reference genomes from loaded genotype protocols
# PATH: GET /ajax/sequence_metadata/reference_genomes
# RETURNS:
#   - reference_genomes: an array of reference genomes
#       - reference_genome_name: name of reference genome
#       - species_name: name of species associated with reference genome
#
sub get_reference_genomes : Path('/ajax/variants/reference_genomes') :Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    # Get the reference genomes
    my $msearch = CXGN::Marker::SearchMatView->new(bcs_schema => $schema);
    my $results = $msearch->reference_genomes();

    # Return the results
    $c->stash->{rest} = {
        reference_genomes => $results
    };
}