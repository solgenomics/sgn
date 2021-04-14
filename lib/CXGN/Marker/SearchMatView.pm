package CXGN::Marker::SearchMatView;

=head1 NAME

CXGN::Marker::SearchMatView - class to search for markers based on name or 
position using the unified marker materialized view

=head1 USAGE

To perform a marker search, first create a marker search object with a bio chado schema:
    use CXGN::Marker::SearchMatView;
    my $msearch = CXGN::Marker::SearchMatView->new(bcs_schema => $schema);

Then call the query function with the desired filter parameters
example: filter markers based on position:
    my $results = $msearch->query(
        species_name => 'Triticum aestivum',
        reference_genome_name => 'RefSeq_v1',
        chrom => '1A',
        start => '1000',
        end => '2000'
    );
example: filter markers based on name:
    my $results = $msearch->query(
        name => '1WA10'
    );
example: filter markers based on a substring of the name:
    my $results = $msearch->query(
        name_substring => 'IWA'
    );
example: filter markers based on name for a particular set of genotype protocols:
    my @genotype_protocols = (37, 38);
    my $results = $msearch->query(
        name => 'IWA10',
        nd_protocol_ids => \@genotype_protocols
    );

=head1 AUTHORS

David Waring <djw64@cornell.edu>

=cut


use strict;
use warnings;
use Moose;


has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1
);


sub BUILD {
    my $self = shift;
}


#
# Search the unified marker materialized view for markers matching the provided search criteria
#
# Arguments (as a hash with the following keys):
#   - species_name = (required if chrom, start, or end are provided) species name
#   - reference_genome_name (required if chrom, start, or end are provided) reference genome name
#   - chrom = (required if start or end are provided) chromosome name
#   - start = (optional) start position of query range
#   - end = (optional) end position of query range
#   - name = (optional) marker name or alias
#   - name_substring = (optional) part of marker name or alias
#   - nd_protocol_ids = (optional) array ref of genotype protocol ids
#   - limit = (optional) max number of markers to return
#
# Returns a hash with the following keys:
#   - markers = an array of hashes containing the marker info with the following keys:
#       - nd_protocol_id = genotype protocol id
#       - species_name = species name
#       - reference_genome_name = reference genome name
#       - marker_name = marker name (from genotype protocol)
#       - alias = marker alias (uniformly generated marker name)
#       - chrom = chromosome name
#       - pos = chromosome position
#       - ref = reference allele
#       - alt = alternate allele
#   - count = total number of markers found
#
sub query {
    my $self = shift;
    my $args = shift;
    my $chrom = $args->{chrom};
    my $start = $args->{start};
    my $end = $args->{end};
    my $species = $args->{species_name};
    my $reference_genome = $args->{reference_genome_name};
    my $name = $args->{name};
    my $name_substring = $args->{name_substring};
    my $nd_protocol_ids = $args->{nd_protocol_ids};
    my $limit = $args->{limit};

    my $schema = $self->bcs_schema;
    my $dbh = $schema->storage->dbh();

    # Build query
    my $q_select = "SELECT markers_all.nd_protocol_id, nd_protocol.name AS nd_protocol_name, species_name, reference_genome_name, marker_name, alias, chrom, pos, ref, alt";
    my $q_count = "SELECT COUNT(*) AS count";
    my $q = " FROM sgn.markers_all";
    $q .= " LEFT JOIN nd_protocol USING (nd_protocol_id)";

    # Add filter parameters
    my @where = ();
    my @args = ();
    if ( defined $species ) {
        push(@where, "species_name = ?");
        push(@args, $species);
    }
    if ( defined $reference_genome ) {
        push(@where, "reference_genome_name = ?");
        push(@args, $reference_genome);
    }
    if ( defined $chrom && defined $species && defined $reference_genome ) {
        my $pw = "chrom = ?";
        push(@args, $chrom);
        if ( defined $start ) {
            $pw .= " AND pos >= ?";
            push(@args, $start);
        }
        if ( defined $end ) {
            $pw .= " AND pos <= ?";
            push(@args, $end);
        }
        push(@where, $pw);
    }
    if ( defined $name ) {
        push(@where, "(marker_name = ? OR alias = ?)");
        push(@args, $name, $name);
    }
    if ( defined $name_substring ) {
        push(@where, "(marker_name LIKE ? OR alias LIKE ?)");
        push(@args, '%' . $name_substring . '%', '%' . $name_substring . '%');
    }
    if ( defined $nd_protocol_ids && @$nd_protocol_ids ) {
        my $pw = "nd_protocol_id IN (@{[join',', ('?') x @$nd_protocol_ids]})";
        push(@where, $pw);
        push(@args, @$nd_protocol_ids);
    }
    push(@where, "marker_name <> '.'");
    if ( @where ) {
        $q .= " WHERE " . join(' AND ', @where);
    }

    # Get the total count of markers
    my $query_count = $q_count . $q;
    my $h_count = $dbh->prepare($query_count);
    $h_count->execute(@args);
    my ($count) = $h_count->fetchrow_array();

    # Get the marker info
    my $query = $q_select . $q;
    $query .= " ORDER BY marker_name";
    if ( defined $limit ) {
        $query .= " LIMIT ?";
        push(@args, $limit);
    }

    # print STDERR "QUERY:\n";
    # print STDERR "$query\n";
    # use Data::Dumper;
    # print STDERR "ARGS:\n";
    # print STDERR Dumper \@args;
    # print STDERR "TOTAL MARKERS:\n";
    # print STDERR "$count\n";

    # Perform the Query
    my $h = $dbh->prepare($query);
    $h->execute(@args);

    # Parse the results
    my @markers = ();
    while (my ($nd_protocol_id, $nd_protocol_name, $species_name, $reference_genome_name, $marker_name, $alias, $chrom, $pos, $ref, $alt) = $h->fetchrow_array()) {
        my %marker = (
            nd_protocol_id => $nd_protocol_id,
            nd_protocol_name => $nd_protocol_name, 
            species_name => $species_name,
            reference_genome_name => $reference_genome_name,
            marker_name => $marker_name,
            alias => $alias,
            chrom => $chrom,
            pos => $pos,
            ref => $ref,
            alt => $alt
        );
        push(@markers, \%marker);
    }

    # Return the results
    return({
        markers => \@markers,
        count => $count
    });
}


1;