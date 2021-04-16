
=head1 NAME

SGN::Controller::AJAX::Variants

=head1 DESCRIPTION

The AJAX endpoints in this class can be used to get query results from the 
unified marker materialized view (containing marker info combined from all
genotype protocols) and info related to the markers and genotype protocols.

=head1 AUTHOR

David Waring <djw64@cornell.edu>

=cut


use strict;

package SGN::Controller::AJAX::Variants;

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



#
# Query the variants in the marker materialized view
# PATH: GET /ajax/variants/query
# PARAMS:
#   - species = name of the species
#   - reference_genome = name of the reference genome
#   - chrom = name of the chromosome
#   - start = start position of the query range
#   - end = end position of the query range
#   - limit = (optional, required if page provided) limit the number of markers returned
#   - page = (optional) the offset of markers returned, when more than limit markers found
#
sub query_markers : Path('/ajax/variants/query') : ActionClass('REST') { }
sub query_markers_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $dbh = $schema->storage->dbh();

    my $species = $c->req->param('species');
    my $reference_genome = $c->req->param('reference_genome');
    my $chrom = $c->req->param('chrom');
    my $start = $c->req->param('start');
    my $end = $c->req->param('end');
    my $limit = $c->req->param('limit');
    my $page = $c->req->param('page');


    # Check required parameters
    if ( !defined $species || $species eq '' ) {
        $c->stash->{rest} = {error => 'Species must be provided!'};
        $c->detach();
    }
    if ( !defined $reference_genome || $reference_genome eq '' ) {
        $c->stash->{rest} = {error => 'Reference genome must be provided!'};
        $c->detach();
    }
    if ( !defined $chrom || $chrom eq '' ) {
        $c->stash->{rest} = {error => 'Chromosome name must be provided!'};
        $c->detach();
    }
    if ( !defined $start || $start eq '' ) {
        $c->stash->{rest} = {error => 'start location must be provided!'};
        $c->detach();
    }
    if ( !defined $end || $end eq '' ) {
        $c->stash->{rest} = {error => 'end location must be provided!'};
        $c->detach();
    }
    if ( defined $page && !defined $limit ) {
        $c->stash->{rest} = {error => 'limit must be provided with page!'};
        $c->detach();
    }

    # Perform marker search using materialized view
    my $msearch = CXGN::Marker::SearchMatView->new(bcs_schema => $schema);
    my %args = (
        species_name => $species,
        reference_genome_name => $reference_genome,
        chrom => $chrom,
        start => $start,
        end => $end,
        limit => $limit,
        page => $page
    );
    my $results = $msearch->query(\%args);

    # Return the results as JSON
    $c->stash->{rest} = {
        results => $results
    };

}}

1;
