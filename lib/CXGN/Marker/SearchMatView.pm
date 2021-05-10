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
    my $results = $msearch->query({
        species_name => 'Triticum aestivum',
        reference_genome_name => 'RefSeq_v1',
        chrom => '1A',
        start => '1000',
        end => '2000'
    });
example: filter markers based on name:
    my $results = $msearch->query({
        name => '1WA10'
    });
example: filter markers based on a substring of the name:
    my $results = $msearch->query({
        name => 'IWA',
        name_match => 'contains'
    });
example: filter markers based on name for a particular set of genotype protocols:
    my @genotype_protocols = (37, 38);
    my $results = $msearch->query({
        name => 'IWA10',
        nd_protocol_ids => \@genotype_protocols
    });
example: get markers for a specific variant:
    my $results = $msearch->query({
        variant => 'TaRefSeqv1_1A_1176337'
    });

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
# Get a list of chromosomes for each species / reference genome
# This cleans up some variations in the same chromosome name:
#   - removes prepended 'chr'
#   - removes Unxxx, where xxx is a number
#   - transformed to all uppercase to remove case-sensitive duplicates
#
# Returns: a hash with the species name as the key
#   - {species_name}: a hash with the reference genome name as the key
#       - {reference_genome_name}: an array with the chromosome names
#
sub chromosomes {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $dbh = $schema->storage->dbh();

    # Build the query to get the unique set of chromosomes for each reference genome and species
    my $q = "SELECT species_name, reference_genome_name, UPPER(chrom)
                FROM materialized_markerview
                GROUP BY species_name, reference_genome_name, chrom
                ORDER BY species_name, reference_genome_name, chrom;";
    
    # Perform the query
    my $h = $dbh->prepare($q);
    $h->execute();
    
    # Parse the response (remove chr prefix and unknown suffixes)
    my %keys = ();
    while (my ($species, $reference, $chrom) = $h->fetchrow_array()) {
        $chrom =~ s/^CHR//;
        $chrom =~ s/UN[0-9]*$/Un/;
        if ( $chrom ) {
            my $key = $species . $reference . $chrom;
            $keys{$key} = {
                species => $species,
                reference => $reference,
                chrom => $chrom
            };
        }
    }

    # Build the results
    my %results = ();
    foreach my $key (keys %keys) {
        my $species = $keys{$key}{'species'};
        my $reference = $keys{$key}{'reference'};
        my $chrom = $keys{$key}{'chrom'};
        if ( !exists($results{$species}) ) {
            $results{$species} = {};
        }
        if ( !exists($results{$species}{$reference}) ) {
            $results{$species}{$reference} = ();
        }
        push(@{$results{$species}{$reference}}, $chrom);
    }

    # Return sorted chromosomes
    foreach my $sp (keys %results) {
        foreach my $ref (keys %{$results{$sp}}) {
            my @chroms = @{$results{$sp}{$ref}};
            @chroms = sort(@chroms);
            $results{$sp}{$ref} = \@chroms;
        }
    }
    return(\%results);
}


#
# Get a list of genotype protocols along with their species and reference info
#
# Returns: an array of protocol hashes with the following keys:
#   - nd_protocol_id = id of genotype protocol
#   - nd_protocol_name = name of genotype protocol
#   - species_name = name of species
#   - reference_genome_name = name of reference genome
#
sub protocols {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $dbh = $schema->storage->dbh();

    # Build the query to get the unique set of genotype protocols
    my $q = "SELECT mm.nd_protocol_id, np.name AS nd_protocol_name, mm.species_name, mm.reference_genome_name
                FROM materialized_markerview AS mm
                LEFT JOIN nd_protocol AS np USING (nd_protocol_id)
                GROUP BY mm.nd_protocol_id, np.name, mm.species_name, mm.reference_genome_name
                ORDER BY mm.species_name, mm.reference_genome_name, np.name;";
    
    # Perform the query
    my $h = $dbh->prepare($q);
    $h->execute();

    # Parse the response
    my @results = ();
    while (my ($nd_protocol_id, $nd_protocol_name, $species, $reference) = $h->fetchrow_array()) {
        my %protocol = (
            nd_protocol_id => $nd_protocol_id,
            nd_protocol_name => $nd_protocol_name,
            species_name => $species,
            reference_genome_name => $reference
        );
        push(@results, \%protocol);
    }

    # Return the results
    return(\@results);
}


#
# Find variants (and their markers) that are related to those of the specified variant
#
# This query will get all of the marker names of the specified variant 
# and lookup markers that have the same name but are on a different variant
# (example: a marker that uses the same name but is on a different reference/species) 
# AND get variants (and their markers) that are at the same position but have 
# different allele values.
#
# Arguments:
#   - variant_name = name of the variant of which to find related markers
#
# Returns a hash of variants containing the related/matching markers
#
sub related_variants {
    my $self = shift;
    my $variant_name = shift;
    my $schema = $self->bcs_schema;
    my $dbh = $schema->storage->dbh();

    # Get variant properties
    my $q_props = "SELECT species_name, reference_genome_name, REGEXP_REPLACE(chrom, '^chr', '', 'i') AS chrom, pos
                    FROM materialized_markerview 
                    WHERE UPPER(variant_name) = UPPER(?)
                    GROUP BY species_name, reference_genome_name, chrom, pos;";
    my $h_props = $dbh->prepare($q_props);
    $h_props->execute($variant_name);
    my ($species_name, $reference_genome_name, $chrom, $pos) = $h_props->fetchrow_array();

    # Build marker name query
    my $q_name = "SELECT materialized_markerview.nd_protocol_id, nd_protocol.name AS nd_protocol_name, species_name, reference_genome_name, marker_name, variant_name, chrom, pos, ref, alt 
                    FROM materialized_markerview
                    LEFT JOIN nd_protocol USING (nd_protocol_id)
                    WHERE marker_name IN (
                        SELECT DISTINCT(marker_name)
                        FROM materialized_markerview
                        WHERE UPPER(variant_name) = UPPER(?)
                            AND marker_name <> '.'
                    )
                    AND UPPER(variant_name) <> UPPER(?)";

    # Build marker position query
    my $q_pos = "SELECT materialized_markerview.nd_protocol_id, nd_protocol.name AS nd_protocol_name, species_name, reference_genome_name, marker_name, variant_name, chrom, pos, ref, alt 
                    FROM materialized_markerview
                    LEFT JOIN nd_protocol USING (nd_protocol_id)
                    WHERE species_name = ?
                    AND reference_genome_name = ?
                    AND chrom ~* ?
                    AND pos = ?
                    AND UPPER(variant_name) <> UPPER(?)";
    
    # Build full query
    my $q = $q_name . " UNION " . $q_pos . " ORDER BY marker_name;";
    
    # Execute Query
    my $h = $dbh->prepare($q);
    $h->execute($variant_name, $variant_name, $species_name, $reference_genome_name, '^(chr)?'.$chrom, $pos, $variant_name);

    # Parse Results
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

    # Return the Results
    return(\%variants);
}


#
# Find mapped markers that are related to those of the specified variant
#
# This query will get all of the markers (id, name, map_id and map_name) of markers 
# that share the same name as a marker in the specified variant
#
# Arguments:
#   - variant_name = name of the variant of which to find related markers
#
# Returns an array of marker hashes with the following keys:
#   - marker_id = id of mapped marker
#   - marker_name = name of mapped marker
#   - lg_name = marker linkage group / chromosome
#   - position = marker position
#   - map_id = id of map
#   - map_name = name of map
#   - map_units = units of map positions
#   - species_name = name of species
#   - protocol = name of protocol
#
sub related_mapped_markers {
    my $self = shift;
    my $variant_name = shift;
    my $schema = $self->bcs_schema;
    my $dbh = $schema->storage->dbh();

    # Build query
    my $q = "SELECT m.marker_name, m.species_name AS ori_species_name, marker_alias.marker_id, marker_alias.alias, map.map_id, map.short_name, 
                CONCAT(organism.genus, ' ', REGEXP_REPLACE(organism.species, CONCAT('^', organism.genus, ' '), '')) AS species_name, 
                m2m.protocol, m2m.lg_name, m2m.position, map.units
                FROM (
                    SELECT marker_name, species_name 
                    FROM materialized_markerview 
                    WHERE variant_name = ?
                    GROUP BY marker_name, species_name
                ) AS m
                LEFT JOIN sgn.marker_alias ON (UPPER(m.marker_name) = UPPER(marker_alias.alias))
                LEFT JOIN sgn.marker_to_map AS m2m ON (marker_alias.marker_id = m2m.marker_id)
                LEFT JOIN sgn.map ON (m2m.map_id = map.map_id)
                LEFT JOIN public.stock ON (stock.stock_id = map.parent1_stock_id)
                LEFT JOIN public.organism ON (stock.organism_id = organism.organism_id)
                WHERE marker_alias.alias <> '';";
    
    # Execute Query
    my $h = $dbh->prepare($q);
    $h->execute($variant_name);

    # Parse Results
    my @markers;
    while (my ($ori_marker_name, $ori_species_name, $marker_id, $marker_name, $map_id, $map_name, $species_name, $protocol, $lg_name, $position, $map_units) = $h->fetchrow_array()) {
        if ( $ori_species_name eq $species_name ) {
            my %marker = (
                marker_id => $marker_id,
                marker_name => $marker_name,
                lg_name => $lg_name,
                position => $position,
                map_id => $map_id,
                map_name => $map_name,
                map_units => $map_units,
                species_name => $species_name,
                protocol => $protocol
            );
            push(@markers, \%marker);
        }
    }

    # Return the Results
    return(\@markers);
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
    my $select_count = "SELECT COUNT(*) AS marker_count";
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
        my $pw = "chrom ~* ?";
        $chrom =~ s/^chr//i;
        push(@args, '^(chr)?'.$chrom.'_?[0-9]*$');
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
    if ( defined $name && $name ne '' ) {
        if ( $name_match eq 'contains' ) {
            push(@where, "(marker_name ILIKE ? OR variant_name ILIKE ?)");
            push(@args, '%'.$name.'%', '%'.$name.'%');
        }
        elsif ( $name_match eq 'starts_with' ) {
            push(@where, "(marker_name ILIKE ? OR variant_name ILIKE ?)");
            push(@args, $name.'%', $name.'%');
        }
        elsif ( $name_match eq 'ends_with' ) {
            push(@where, "(marker_name ILIKE ? OR variant_name ILIKE ?)");
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
    # push(@where, "marker_name <> '.'");
    if ( @where ) {
        $q .= " WHERE " . join(' AND ', @where);
    }

    # Get the total count of markers
    # my $subq_count = $select_count . $q . " GROUP BY variant_name";
    # my $query_count = "SELECT SUM(c.marker_count)::int AS marker_count, COUNT(*) AS variant_count FROM ($subq_count) AS c;";
    # ^getting variant counts adds too much time to the query
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

    # print STDERR "QUERY:\n";
    # print STDERR "$query\n";
    # use Data::Dumper;
    # print STDERR "ARGS:\n";
    # print STDERR Dumper \@args;
    # print STDERR "TOTAL MARKERS:\n";
    # print STDERR "$marker_count\n";

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
        counts => {
            markers => $marker_count
        }
    });
}


1;