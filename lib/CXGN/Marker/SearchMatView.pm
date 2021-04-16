package CXGN::Marker::SearchMatView;

=head1 NAME

CXGN::Marker::SearchMatView - class to search for markers based on name, position, or other filter 
criteria using the unified marker materialized view (public.materialized_markerview)

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
        name => 'IWA',
        name_match => 'contains'
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
# Get the unique pairs of reference genome and species from the 
# genotype protocol props (type=vcf_map_details)
#
# Returns an array of hashes with the following keys:
#   - species_name = name of species
#   - reference_genome_name = name of reference genome
#
sub reference_genomes {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $dbh = $schema->storage->dbh();

    # Build query to get unique pairs of reference and species
    my $q = "SELECT value->>'species_name' AS species, value->>'reference_genome_name' AS reference_genome
                FROM nd_protocolprop
                WHERE type_id = (SELECT cvterm_id FROM public.cvterm WHERE name = 'vcf_map_details')
                GROUP BY species, reference_genome
                ORDER BY species;";

    # Perform query
    my $h = $dbh->prepare($q);
    $h->execute();

    # Parse results
    my @results = ();
    while ( my ($species, $reference_genome) = $h->fetchrow_array() ) {
        my %result = (
            species_name => $species,
            reference_genome_name => $reference_genome
        );
        push(@results, \%result);
    }

    # Return the results
    return(\@results);
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
#   - variant = (optional) variant name (exact, case-insensitive match)
#   - name = (optional) marker name or variant name
#   - name_match = (optional, default=exact) how to match (case-insensitively) the marker name (exact, contains, starts_with, ends_with)
#   - nd_protocol_ids = (optional) array ref of genotype protocol ids
#   - limit = (optional, default=500) max number of markers to return
#   - page = (optional, default=1) return a different set of $limit number of results, if more than $limit are found
#
# Returns a hash with the following keys:
#   - variants = a hash with the key as the variant name and the value an array of hashes for each marker with the following keys:
#       - nd_protocol_id = genotype protocol id
#       - nd_protocol_name = genotype protocol name
#       - species_name = species name
#       - reference_genome_name = reference genome name
#       - marker_name = marker name (from genotype protocol)
#       - variant_name = variant name (uniformly generated marker name)
#       - chrom = chromosome name
#       - pos = chromosome position
#       - ref = reference allele
#       - alt = alternate allele
#   - variant_count = total number of variants found
#   - marker_count = total number of markers found
#
sub query {
    my $self = shift;
    my $args = shift;
    my $chrom = $args->{chrom};
    my $start = $args->{start};
    my $end = $args->{end};
    my $species = $args->{species_name};
    my $reference_genome = $args->{reference_genome_name};
    my $variant = $args->{variant};
    my $name = $args->{name};
    my $name_match = $args->{name_match} ? $args->{name_match} : 'exact';
    my $nd_protocol_ids = $args->{nd_protocol_ids};
    my $limit = $args->{limit} ? $args->{limit} : 500;
    my $page = $args->{page} ? $args->{page} : 1;

    my $schema = $self->bcs_schema;
    my $dbh = $schema->storage->dbh();

    # Build query
    my $select_info = "SELECT materialized_markerview.nd_protocol_id, nd_protocol.name AS nd_protocol_name, species_name, reference_genome_name, marker_name, variant_name, chrom, pos, ref, alt";
    my $select_count = "SELECT COUNT(*) AS count";
    my $q = " FROM public.materialized_markerview";
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
    if ( defined $variant ) {
        push(@where, "UPPER(variant_name) = UPPER(?)");
        push(@args, $variant);
    }
    if ( defined $name ) {
        if ( $name_match eq 'contains' ) {
            push(@where, "(UPPER(marker_name) LIKE UPPER(?) OR UPPER(variant_name) LIKE UPPER(?))");
            push(@args, '%'.$name.'%', '%'.$name.'%');
        }
        elsif ( $name_match eq 'starts_with' ) {
            push(@where, "(UPPER(marker_name) LIKE UPPER(?) OR UPPER(variant_name) LIKE UPPER(?))");
            push(@args, $name.'%', $name.'%');
        }
        elsif ( $name_match eq 'ends_with' ) {
            push(@where, "(UPPER(marker_name) LIKE UPPER(?) OR UPPER(variant_name) LIKE UPPER(?))");
            push(@args, '%'.$name, '%'.$name);
        }
        else {
            push(@where, "(UPPER(marker_name) = UPPER(?) OR UPPER(variant_name) = UPPER(?))");
            push(@args, $name, $name);
        }
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
    my $query_count = $select_count . $q;
    my $h_count = $dbh->prepare($query_count);
    $h_count->execute(@args);
    my ($marker_count) = $h_count->fetchrow_array();

    # Get the marker info
    my $query = $select_info . $q;
    $query .= " ORDER BY marker_name";
    if ( defined $limit ) {
        $query .= " LIMIT ?";
        push(@args, $limit);
    }
    if ( defined $page && defined $limit ) {
        my $offset = ($page-1)*$limit;
        $query .= " OFFSET ?";
        push(@args, $offset);
    }

    print STDERR "QUERY:\n";
    print STDERR "$query\n";
    use Data::Dumper;
    print STDERR "ARGS:\n";
    print STDERR Dumper \@args;
    print STDERR "TOTAL MARKERS:\n";
    print STDERR "$marker_count\n";

    # Perform the Query
    my $h = $dbh->prepare($query);
    $h->execute(@args);

    # Parse the results
    my %variants;
    while (my ($nd_protocol_id, $nd_protocol_name, $species_name, $reference_genome_name, $marker_name, $variant_name, $chrom, $pos, $ref, $alt) = $h->fetchrow_array()) {
        my %marker = (
            nd_protocol_id => $nd_protocol_id,
            nd_protocol_name => $nd_protocol_name, 
            species_name => $species_name,
            reference_genome_name => $reference_genome_name,
            marker_name => $marker_name,
            variant_name => $variant_name,
            chrom => $chrom,
            pos => $pos,
            ref => $ref,
            alt => $alt
        );
        if ( !exists $variants{$variant_name} ) {
            $variants{$variant_name} = ();
        }
        push(@{$variants{$variant_name}}, \%marker);
    }

    # Return the results
    return({
        variants => \%variants,
        variant_count => scalar(keys(%variants)),
        marker_count => $marker_count
    });
}


1;