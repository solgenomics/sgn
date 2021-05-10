
=head1 NAME

SGN::Controller::AJAX::Markers::Mapped

=head1 DESCRIPTION

The AJAX endpoints in this class can be used to get query information about 
the mapped markers (stored in the marker relational tables)

=head1 AUTHOR

David Waring <djw64@cornell.edu>

=cut


use strict;

package SGN::Controller::AJAX::Markers::Mapped;

use Moose;
use JSON;
use CXGN::Marker::Search;
use CXGN::Marker::SearchMatView;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
);


#
# Get the loaded maps
# PATH: GET /ajax/markers/mapped/maps
# RETURNS: 
#   - maps: an array of maps with the following keys
#       - map_id: id of the map
#       - map_name: name of the map
#       - map_type: type of map
#       - map_units: units used for map positions
#       - species_name: name of the species
#
sub get_maps : Path('/ajax/markers/mapped/maps') : ActionClass('REST') { }
sub get_maps_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $dbh = $schema->storage->dbh();

    # Perform query
    my $query = "SELECT map.map_id, map.short_name, map.map_type, map.units, 
                    CONCAT(organism.genus, ' ', REGEXP_REPLACE(organism.species, CONCAT('^', organism.genus, ' '), '')) AS species_name 
                FROM sgn.map
                LEFT JOIN public.stock ON (stock.stock_id = map.parent1_stock_id)
                LEFT JOIN public.organism ON (stock.organism_id = organism.organism_id)
                ORDER BY map.short_name";
    my $h = $dbh->prepare($query);
    $h->execute();
    
    # Parse results
    my @results = ();
    while (my ($map_id, $map_name, $map_type, $map_units, $species_name) = $h->fetchrow_array()) {
        my %map = (
            map_id => $map_id,
            map_name => $map_name,
            map_type => $map_type,
            map_units => $map_units,
            species_name => $species_name
        );
        push(@results, \%map);
    }

    # Return the results
    $c->stash->{rest} = { maps => \@results };
}

#
# Get chromosomes by map
# PATH: GET /ajax/markers/mapped/chromosomes
# RETURNS:
#   - chromosomes: an object with the keys set to the map name
#       - {map_name}: an array of chromosome names for that map
#
sub get_chromosomes : Path('/ajax/markers/mapped/chromosomes') : ActionClass('REST') { }
sub get_chromosomes_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $dbh = $schema->storage->dbh();

    # Perform query
    my $query = "SELECT m2m.map_id, map.short_name, m2m.lg_name
                FROM sgn.marker_to_map AS m2m
                LEFT JOIN sgn.map USING (map_id)
                GROUP BY m2m.map_id, map.short_name, m2m.lg_name
                ORDER BY map.short_name, m2m.lg_name;";
    my $h = $dbh->prepare($query);
    $h->execute();

    # Parse results
    my %results = ();
    while (my ($map_id, $map_name, $chrom) = $h->fetchrow_array()) {
        if ( !exists($results{$map_name}) ) {
            $results{$map_name} = ();
        }
        push(@{$results{$map_name}}, $chrom);
    }

    # Return the results
    $c->stash->{rest} = { chromosomes => \%results };
}


#
# Get protocols with map and species information
# PATH: GET /ajax/markers/mapped/protocols
# RETURNS:
#   - protocols: an array of protocols used by the mapped markers, with the following keys
#       - protocol: name of the protocol
#       - species: array of species names using protocol
#       - maps: array of map objects using protocol, with the following keys:
#           - map_id: id of map
#           - map_name: name of map
#
sub get_protocols : Path('/ajax/markers/mapped/protocols') : ActionClass('REST') { }
sub get_protocols_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $dbh = $schema->storage->dbh();

    # Perform query
    my $query = "SELECT m2m.map_id, map.short_name, m2m.protocol,
                    CONCAT(organism.genus, ' ', REGEXP_REPLACE(organism.species, CONCAT('^', organism.genus, ' '), '')) AS species_name 
                FROM sgn.marker_to_map AS m2m
                LEFT JOIN sgn.map USING (map_id)
                LEFT JOIN public.stock ON (stock.stock_id = map.parent1_stock_id)
                LEFT JOIN public.organism ON (stock.organism_id = organism.organism_id)
                GROUP BY m2m.map_id, map.short_name, m2m.protocol, organism.genus, organism.species
                ORDER BY map.short_name, m2m.protocol;";
    my $h = $dbh->prepare($query);
    $h->execute();

    # Parse results
    my %protocols = ();
    while (my ($map_id, $map_name, $protocol, $species) = $h->fetchrow_array()) {
        if ( !exists($protocols{$protocol}) ) {
            $protocols{$protocol} = {
                maps => {},
                species => {}
            };
        }
        $protocols{$protocol}{maps}{$map_name} = $map_id;
        $protocols{$protocol}{species}{$species} = 1;
    }

    # Build response
    my @response = ();
    foreach my $pn (keys %protocols) {
        my @species = ();
        my @maps = ();
        foreach my $sn (keys %{$protocols{$pn}{species}} ) {
            push(@species, $sn);
        }
        foreach my $mn (keys %{$protocols{$pn}{maps}} ) {
            my %m = (
                map_id => $protocols{$pn}{maps}{$mn},
                map_name => $mn
            );
            push(@maps, \%m);
        }
        my %p = (
            protocol => $pn,
            species => \@species,
            maps => \@maps
        );
        push(@response, \%p);
    }

    # Return the results
    $c->stash->{rest} = { protocols => \@response };
}


#
# Get genotyped markers that are related to the specified mapped marker
# PATH: GET /ajax/markers/mapped/related_variants
# PARAMS:
#   - marker_id = id of mapped marker
# RETURNS:
#   - related_variants: genotyped variants and their matching markers, grouped by variant name
#
sub get_related_variants_of_mapped_marker : Path('/ajax/markers/mapped/related_variants') : ActionClass('REST') { }
sub get_related_variants_of_mapped_marker_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $marker_id = $c->req->param('marker_id');
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $dbh = $schema->storage->dbh();

    # Check for required parameters
    if ( !defined $marker_id || $marker_id eq '' ) {
        $c->stash->{rest} = {error => 'marker_id must be provided!'};
        $c->detach();
    }

    # Get marker names and species
    my $query = "SELECT marker_alias.alias, CONCAT(organism.genus, ' ', REGEXP_REPLACE(organism.species, CONCAT('^', organism.genus, ' '), '')) AS species_name
                FROM sgn.marker_alias
                LEFT JOIN sgn.marker_to_map AS m2m ON (marker_alias.marker_id = m2m.marker_id)
                LEFT JOIN sgn.map ON (m2m.map_id = map.map_id)
                LEFT JOIN public.stock ON (map.parent1_stock_id = stock.stock_id)
                LEFT JOIN public.organism ON (stock.organism_id = organism.organism_id)
                WHERE marker_alias.marker_id = ?;";
    my $h = $dbh->prepare($query);
    $h->execute($marker_id);
    
    # Parse each name / species
    my %variants = ();
    my $msearch = CXGN::Marker::SearchMatView->new(bcs_schema => $schema);
    while (my ($marker_name, $species_name) = $h->fetchrow_array()) {
        
        # Perform genotype marker search on mapped marker name / species
        my %args = (
            species_name => $species_name,
            name => $marker_name
        );
        my $results = $msearch->query(\%args);
        my $variants = $results->{variants};

        # Parse the matching variants / markers
        foreach my $variant (keys %$variants) {
            my $markers = $variants->{$variant};
            if ( !exists $variants{$variant} ) {
                $variants{$variant} = ();
            }
            foreach my $marker (@$markers) {
                push(@{$variants{$variant}}, $marker);
            }
        }
    }

    # Return the results as JSON
    $c->stash->{rest} = {
        related_variants => \%variants
    };
}


#
# Query the mapped markers
# PATH: GET /ajax/markers/mapped/query
# PARAMS:
#   - name = (optional) name of marker or variant
#   - name_match = (optional, default=exact) type of marker name match (exact, contains, starts_with, ends_with)
#   - species = (optional) name of the species
#   - map_id = (optional) id of map marker must be on
#   - chrom = (optional) chromosome name
#   - start = (optional, required with end) start position
#   - end = (optional, required with start) end position
#   - limit = (required if page provided) limit the number of markers returned
#   - page = (optional) the offset of markers returned ((page-1)*limit)
# RETURNS: 
#   - results: results of the marker search
#       - marker_count: total number of markers that match the filter criteria
#       - markers: array of matching markers with the following keys:
#           - marker_id: marker id
#           - marker_name: name of marker
#           - protocol: name of protocol used to create the markers
#           - map_id: map_id
#           - map_version_id: version of the map
#           - map_name: name of the map used to position the markers
#           - map_type: map type
#           - map_units: units used for map positions
#           - lg_name: chromosome name
#           - position: position of the marker (in map_units)
#           - species_name: name of species
#
sub query_mapped_markers : Path('/ajax/markers/mapped/query') : ActionClass('REST') { }
sub query_mapped_markers_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $dbh = $schema->storage->dbh();

    my $name = $c->req->param('name');
    my $name_match = $c->req->param('name_match');
    my $species = $c->req->param('species');
    my $map_id = $c->req->param('map_id');
    my $chrom = $c->req->param('chrom');
    my $start = $c->req->param('start');
    my $end = $c->req->param('end');
    my $limit = $c->req->param('limit');
    my $page = $c->req->param('page');

    # Check required parameters
    if ( defined $page && !defined $limit ) {
        $c->stash->{rest} = {error => 'limit must be provided with page!'};
        $c->detach();
    }
    if ( (defined $start && !defined $end) || (defined $end && !defined $start) ) {
        $c->stash->{rest} = {error => 'start and end positions are required when filtering by position!'};
        $c->detach();
    }

    # Setup marker search
    my $msearch = CXGN::Marker::Search->new($dbh);
   
    # Add name filter
    if ( defined $name && $name ne '' ) {
        if ( $name_match eq 'contains' ) {
            $msearch->name_like('*'.$name.'*');
        }
        elsif ( $name_match eq 'starts_with' ) {
            $msearch->name_like($name.'*');
        }
        elsif ( $name_match eq 'ends_with' ) {
            $msearch->name_like('*'.$name);
        }
        else {
            $msearch->name_exactly($name);
        }
    }

    # Add species filter, lookup maps associated with the species
    if ( defined $species && $species ne '' && !defined $map_id ) {
        my $sq = "SELECT map_id
                    FROM sgn.map
                    WHERE parent1_stock_id IN (
                        SELECT stock_id 
                        FROM public.stock WHERE organism_id IN (
                            SELECT organism_id 
                            FROM public.organism 
                            WHERE CONCAT(organism.genus, ' ', REGEXP_REPLACE(organism.species, CONCAT('^', organism.genus, ' '), '')) = ?
                        )
                    );";
        my $sh = $dbh->prepare($sq);
        $sh->execute($species);

        # Add maps as filter
        my @map_ids = ();
        while (my ($map_id) = $sh->fetchrow_array()) {
            push(@map_ids, $map_id);
        }
        # add a bogus map id, if there are no matching maps for the specified species
        if ( scalar(@map_ids) == 0 ) {
            push(@map_ids, 999999);
        }
        $msearch->on_map(@map_ids);
    }

    # Add map filter
    if ( defined $map_id && $map_id ne '' ) {
        $msearch->on_map(($map_id));
    }

    # Add position filter
    if ( defined $chrom && $chrom ne '' ) {
        $msearch->on_chr(($chrom));
    }
    if ( defined $start && $start ne '' && defined $end && $end ne '' ) {
        $msearch->position_between($start, $end);
    }


    # Build marker search query, using subquery as base
    my ($subq, $places) = $msearch->return_subquery_and_placeholders();
    my $query = "SELECT subq.marker_id, marker_alias.alias, 
                    m2m.protocol, m2m.map_id, m2m.map_version_id, map.short_name, map.map_type, map.units, subq.lg_name, subq.position, 
                    CONCAT(organism.genus, ' ', REGEXP_REPLACE(organism.species, CONCAT('^', organism.genus, ' '), '')) AS species_name, organism.common_name 
                FROM ($subq) AS subq
                LEFT JOIN sgn.marker_alias USING (marker_id) 
                LEFT JOIN sgn.marker_to_map AS m2m ON (subq.marker_id = m2m.marker_id) AND (subq.map_id = m2m.map_id)
                LEFT JOIN sgn.map ON (subq.map_id = map.map_id)
                LEFT JOIN public.stock ON (map.parent1_stock_id = stock.stock_id)
                LEFT JOIN public.organism ON (stock.organism_id = organism.organism_id)
                WHERE preferred = true";

    # Build count query
    my $count_query = "SELECT COUNT(*) FROM ($query) AS subq";
    my $count_h = $dbh->prepare($count_query);
    $count_h->execute(@$places);
    my ($marker_count) = $count_h->fetchrow_array();

    # Add limit and offset to full query
    $query .= " ORDER BY marker_alias.alias, map.short_name";
    if ( defined $limit ) {
        $query .= " LIMIT ?";
        push(@$places, $limit);
    }
    if ( defined $page && defined $limit ) {
        my $offset = ($page-1)*$limit;
        $query .= " OFFSET ?";
        push(@$places, $offset);
    }

    # print STDERR "MAPPED MARKER QUERY:\n";
    # print STDERR "$query\n";
    # use Data::Dumper;
    # print STDERR Dumper $places;

    # Perform query
    my $h = $dbh->prepare($query);
    $h->execute(@$places);

    # Parse the results
    my @markers = ();
    while (my ($marker_id, $marker_name, $protocol, $map_id, $map_version_id, $map_name, $map_type, $map_units, $lg_name, $position, $species_name) = $h->fetchrow_array()) {
        my %marker = (
            marker_id => $marker_id,
            marker_name => $marker_name,
            protocol => $protocol,
            map_id => $map_id,
            map_version_id => $map_version_id, 
            map_name => $map_name,
            map_type => $map_type,
            map_units => $map_units,
            lg_name => $lg_name,
            position => $position,
            species_name => $species_name
        );
        push(@markers, \%marker);
    }

    # Return the results as JSON
    $c->stash->{rest} = {
        results => {
            markers => \@markers,
            marker_count => $marker_count
        }
    };
}


1;
