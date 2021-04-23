
=head1 NAME

SGN::Controller::AJAX::Markers::Genotyped

=head1 DESCRIPTION

The AJAX endpoints in this class can be used to get information about the 
genotyped markers, stored in the nd_protocolprop table and summarized by 
the materialized_markerview table.

=head1 AUTHOR

David Waring <djw64@cornell.edu>
Clay Birkett <clb343@cornell.edu>

=cut


use strict;

package SGN::Controller::AJAX::Markers::Genotyped;

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
# PATH: GET /ajax/markers/genotyped/reference_genomes
# RETURNS:
#   - reference_genomes: an array of reference genomes
#       - reference_genome_name: name of reference genome
#       - species_name: name of species associated with reference genome
#
sub get_variant_reference_genomes : Path('/ajax/markers/genotyped/reference_genomes') :Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    # Get the reference genomes
    my $msearch = CXGN::Marker::SearchMatView->new(bcs_schema => $schema);
    my $results = $msearch->reference_genomes();

    # Return the results
    $c->stash->{rest} = { reference_genomes => $results };
}


#
# Get a list of all chromosomes used by each reference genome / species
# PATH: GET /ajax/markers/genotyped/chromosomes
# RETURNS:
#   - chromosomes: an object with keys set to the species name
#       - {species}: an object with keys set to the reference genome name
#           - {reference_genome}: an array with chromosome names for that reference
#
sub get_variant_chromosomes : Path('/ajax/markers/genotyped/chromosomes') : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    # Get the chromosomes
    my $msearch = CXGN::Marker::SearchMatView->new(bcs_schema => $schema);
    my $results = $msearch->chromosomes();

    # Return the results
    $c->stash->{rest} = { chromosomes => $results };
}


#
# Get a list of all genotype protocols along with their species and reference genome info
# PATH: GET /ajax/markers/genotyped/protocols
# RETURNS:
#   - protocols: an array of protocol objects with the following keys:
#       - nd_protocol_id = id of genotype protocol
#       - nd_protocol_name = name of genotype protocol
#       - species_name = name of species
#       - reference_genome_name = name of reference genome
#
sub get_variant_protocols : Path('/ajax/markers/genotyped/protocols') : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    # Get the protocols
    my $msearch = CXGN::Marker::SearchMatView->new(bcs_schema => $schema);
    my $results = $msearch->protocols();

    # Return the results
    $c->stash->{rest} = { protocols => $results };
}


#
# Query the variants in the marker materialized view
#
# This endpoint can filter by name and/or position
# If filtering by name, just the name is required
# If filtering by position, at least the species, reference genome, and chrom are required
#
# PATH: GET /ajax/markers/genotyped/query
# PARAMS:
#   - name = (optional) name of marker or variant
#   - name_match = (optional, default=exact) type of marker name match (exact, contains, starts_with, ends_with)
#   - species = (required if chrom, start or end provided) name of the species
#   - reference_genome = (required if chrom, start or end provided) name of the reference genome
#   - chrom = (required if start or end provided) name of the chromosome
#   - start = (optional) start position of the query range
#   - end = (optional) end position of the query range
#   - nd_protocol_id = (optional) comma-separated list of genotype protocol id(s)
#   - limit = (required if page provided) limit the number of markers returned
#   - page = (optional) the offset of markers returned ((page-1)*limit)
# RETURNS:
#   - results: marker/variant search results
#       - counts: marker and variant result counts
#           - variants: number of variants with matching markers
#           - markers: number of matching markers
#       - variants: matching variants and their markers
#           - {variant_name}: an array of markers with the following keys:
#               - variant_name: name of variants
#               - species_name: name of species
#               - reference_genome_name: name of reference genome
#               - nd_protocol_id: id of genotype protocol
#               - nd_protocol_name: name of genotype protocol
#               - marker_name: name of marker
#               - chrom: name of chromosome
#               - pos: position of marker (bp)
#               - ref: reference allele
#               - alt: alternate allele
#
sub query_variants : Path('/ajax/markers/genotyped/query') : ActionClass('REST') { }
sub query_variants_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $name = $c->req->param('name');
    my $name_match = $c->req->param('name_match');
    my $species = $c->req->param('species');
    my $reference_genome = $c->req->param('reference_genome');
    my $chrom = $c->req->param('chrom');
    my $start = $c->req->param('start');
    my $end = $c->req->param('end');
    my $nd_protocol_id = $c->req->param('nd_protocol_id');
    my $limit = $c->req->param('limit');
    my $page = $c->req->param('page');

    # Check required parameters
    if ( (!defined $species || $species eq '') && (defined $chrom || defined $start || defined $end) ) {
        $c->stash->{rest} = {error => 'Species must be provided!'};
        $c->detach();
    }
    if ( (!defined $reference_genome || $reference_genome eq '') && (defined $chrom || defined $start || defined $end) ) {
        $c->stash->{rest} = {error => 'Reference genome must be provided!'};
        $c->detach();
    }
    if ( (!defined $chrom || $chrom eq '') && (defined $start || defined $end) ) {
        $c->stash->{rest} = {error => 'Chromosome name must be provided!'};
        $c->detach();
    }
    if ( defined $page && !defined $limit ) {
        $c->stash->{rest} = {error => 'limit must be provided with page!'};
        $c->detach();
    }

    # Perform marker search using materialized view
    my $msearch = CXGN::Marker::SearchMatView->new(bcs_schema => $schema);
    my %args = (
        name => $name,
        name_match => defined $name_match && $name_match ne '' ? $name_match : undef,
        species_name => $species,
        reference_genome_name => $reference_genome,
        chrom => $chrom,
        start => $start,
        end => $end,
        nd_protocol_ids => defined $nd_protocol_id && $nd_protocol_id ne '' ? [split(',', $nd_protocol_id)] : undef,
        limit => $limit,
        page => $page
    );
    my $results = $msearch->query(\%args);

    # Return the results as JSON
    $c->stash->{rest} = { results => $results };
}


#
# Get related variants: variants that have a marker with the same name as one 
# of the markers in the specified variant
#
# PATH: GET /ajax/markers/genotyped/related_variants
# PARAMS:
#   - variant_name = name of the variant
# RETURNS:
#   - related_variants: an array of objects containing the variants and their related/matching markers
# 
sub get_related_variants : Path('/ajax/markers/genotyped/related_variants') : ActionClass('REST') { }
sub get_related_variants_GET : Args(0) {
    my ($self, $c) = @_;
    my $variant_name = $c->req->param('variant_name');
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $msearch = CXGN::Marker::SearchMatView->new(bcs_schema => $schema);
    my $related_variants = $msearch->related_variants($variant_name);

    $c->stash->{rest} = { related_variants => $related_variants };
}

#
# Get related mapped markers: mapped markers that share the name of one of the 
# markers in the specified variant
#
# PATH: GET /ajax/markers/genotyped/related_variants
# PARAMS:
#   - variant_name = name of the variant
# RETURNS:
#   - related_mapped_markers: an array of related mapped markers, with the following keys:
#       - marker_id = id of mapped marker
#       - marker_name = name of mapped marker
#       - map_id = id of map
#       - map_name = name of map
# 
sub get_related_mapped_markers : Path('/ajax/markers/genotyped/related_mapped_markers') : ActionClass('REST') { }
sub get_related_mapped_markers_GET : Args(0) {
    my ($self, $c) = @_;
    my $variant_name = $c->req->param('variant_name');
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $msearch = CXGN::Marker::SearchMatView->new(bcs_schema => $schema);
    my $related_mapped_markers = $msearch->related_mapped_markers($variant_name);

    $c->stash->{rest} = { related_mapped_markers => $related_mapped_markers };
}


#
# Get the markerprops of the specified marker(s)
# PATH: GET /ajax/markers/genotyped/props
# PARAMS:
#   - marker_names = a comma separated list of marker names
# RETURNS: An array of external link objects with the following keys:
#   - type_name
#   - xref_name
#   - url
#   - marker_name
#
sub get_markerprops : Path('/ajax/markers/genotyped/props') : ActionClass('REST') { }
sub get_markerprops_GET {
    my ($self, $c) = @_;
    my @marker_names = split(/, ?/, $c->req->param("marker_names"));
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $dbh = $schema->storage->dbh();
    
    my @row;
    my @propinfo = ();
    my $data;

    my $q = "select cvterm_id from public.cvterm where name = 'vcf_snp_dbxref'";
    my $h = $dbh->prepare($q);
    $h->execute();
    my ($type_id) = $h->fetchrow_array(); 

    $q = "select value from nd_protocolprop where type_id = ?";
    $h = $dbh->prepare($q);
    $h->execute($type_id);
    while (@row = $h->fetchrow_array()) {
        $data = decode_json($row[0]);
	    foreach (@{$data->{markers}}) {
            my $n = $_->{marker_name};
	        if ( grep( /^$n$/, @marker_names) ) {
	            push @propinfo, { url => $data->{url}, type_name => $data->{dbxref}, marker_name => "$_->{marker_name}", xref_name => "$_->{xref_name}"};
            }
        }
    }

    $c->stash->{rest} = \@propinfo;
}

1;
