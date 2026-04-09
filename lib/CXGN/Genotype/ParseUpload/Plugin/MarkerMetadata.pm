package CXGN::Genotype::ParseUpload::Plugin::MarkerMetadata;

use Moose::Role;
use CXGN::File::Parse;
use CXGN::Onto;
use Data::Dumper;

has 'parsed_allele_data' => (is => 'rw', isa => 'HashRef');
has 'parsed_ontology_terms' => (is => 'rw', isa => 'HashRef');
has 'parsed_dbs' => (is => 'rw', isa => 'HashRef');

sub _validate_with_plugin {
    my $self = shift;
    my $protocol_id = $self->get_nd_protocol_id();
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $dbh = $schema->storage->dbh();
    my $onto = CXGN::Onto->new({ schema => $schema });
    my %errors;
    my %warnings;
    my @error_messages;
    my @warning_messages;

    ## Parse the upload file
    my $parser = CXGN::File::Parse->new(
        file => $filename,
        required_columns => [ 'Marker', 'Allele' ],
        optional_columns => [ 'Alias', 'Description', 'Category', 'Reference' ],
        column_aliases => {
            'Marker' => [ 'Major Locus', 'Gene' ],
            'Alias' => [ 'Locus' ],
            'Allele' => [ 'Alleles' ],
            'Category' => [ 'Categories' ],
            'Reference' => [ 'References' ]
        },
        column_arrays => [ 'Allele', 'Category', 'Reference' ]
    );
    my $parsed = $parser->parse();
    my $parsed_errors = $parsed->{errors};
    my $parsed_data = $parsed->{data};
    my @markers = @{$parsed->{values}->{'Marker'}};
    my @aliases = @{$parsed->{values}->{'Alias'}};
    my @alleles = @{$parsed->{values}->{'Allele'}};
    my @categories = @{$parsed->{values}->{'Category'} || []};
    my @references = @{$parsed->{values}->{'Reference'} || []};

    # Return if parsing errors
    if ( $parsed_errors && scalar(@$parsed_errors) > 0 ) {
        $errors{'error_messages'} = $parsed_errors;
        $self->_set_parse_errors(\%errors);
        return;
    }

    # Get the markers from the requested protocol
    my $protocol = CXGN::Genotype::Protocol->new({
        bcs_schema => $schema,
        nd_protocol_id => $protocol_id
    });
    my $valid_markers = $protocol->markers();

    # Make sure marker names are valid
    foreach my $marker (@markers) {
        if ( !exists $valid_markers->{$marker} ) {
            push @error_messages, "The marker '$marker' in your file does not match any of the markers in the selected protocol.";
        }
    }

    # Get names of markers and aliases from the upload file
    my @file_locus_names = (@markers, @aliases);
    my $phs = join ',', map { "?" } @file_locus_names;

    # Return a warning for locus names that already exist and are associated with this protocol
    my $q = "SELECT locus_name, locus_id FROM phenome.locus WHERE locus_name IN ($phs) AND locus_id IN (SELECT locus_id FROM phenome.locus_geno_marker WHERE nd_protocol_id = ?)";
    my $h = $dbh->prepare($q);
    $h->execute(@file_locus_names, $protocol_id);
    my @existing_protocol_locus_names;
    my @existing_protocol_locus_ids;
    while (my ($locus_name, $locus_id) = $h->fetchrow_array()) {
        push @existing_protocol_locus_names, $locus_name;
        push @existing_protocol_locus_ids, $locus_id;
    }
    if ( scalar @existing_protocol_locus_names > 0 ) {
        push @warning_messages, "The following markers already exist in the Locus table and are associated with this protocol: " . join(', ', sort @existing_protocol_locus_names) . ".  You can replace the existing metadata with the information in your file by selecting the 'ignore warnings' option.";
    }
    $parsed->{existing_locus_names} = \@existing_protocol_locus_names;
    $parsed->{existing_locus_ids} = \@existing_protocol_locus_ids;

    # Make sure the markers don't already exist in the phenome.locus table
    $q = "SELECT locus_name FROM phenome.locus WHERE locus_name IN ($phs)";
    if ( scalar @existing_protocol_locus_names > 0 ) {
        $phs = join ',', map { "?" } @existing_protocol_locus_names;
        $q .= " AND locus_name NOT IN ($phs)";
    }
    $h = $dbh->prepare($q);
    if ( scalar @existing_protocol_locus_names > 0 ) {
        $h->execute(@file_locus_names, @existing_protocol_locus_names);
    }
    else {
        $h->execute(@file_locus_names);
    }
    my @existing_global_locus_names;
    while (my ($locus_name) = $h->fetchrow_array()) {
        push @existing_global_locus_names, $locus_name;
    }
    if ( scalar @existing_global_locus_names > 0 ) {
        push @error_messages, "The following markers already exist in the Locus table outside of this protocol: " . join(', ', sort @existing_global_locus_names) . ". These locus names cannot be used.";
    }

    # Return a warning for allele names that already exist and are associated with this protocol
    $phs = join ',', map { "?" } @alleles;
    $q = "SELECT allele_symbol, allele_id FROM phenome.allele WHERE allele_symbol IN ($phs) AND locus_id IN (SELECT locus_id FROM phenome.locus_geno_marker WHERE nd_protocol_id = ?)";
    $h = $dbh->prepare($q);
    $h->execute(@alleles, $protocol_id);
    my @existing_protocol_allele_names;
    my @existing_protocol_allele_ids;
    while (my ($allele_name, $allele_id) = $h->fetchrow_array()) {
        push @existing_protocol_allele_names, $allele_name;
        push @existing_protocol_allele_ids, $allele_id;
    }
    if ( scalar @existing_protocol_allele_names > 0 ) {
        push @warning_messages, "The following alleles already exist in the Allele table and are associated with this protocol: " . join(', ', sort @existing_protocol_allele_names) . ".  You can replace the existing metadata with the information in your file by selecting the 'ignore warnings' option.";
    }
    $parsed->{existing_allele_names} = \@existing_protocol_allele_names;
    $parsed->{existing_allele_ids} = \@existing_protocol_allele_ids;

    # Make sure the allele values don't already exist in the phenome.allele table
    $q = "SELECT allele_symbol FROM phenome.allele WHERE allele_symbol in ($phs)";
    if ( scalar @existing_protocol_allele_names > 0 ) {
            $phs = join ',', map { "?" } @existing_protocol_allele_names;
            $q .= " AND allele_symbol NOT IN ($phs)";
    }
    $h = $dbh->prepare($q);
    if ( scalar @existing_protocol_allele_names > 0 ) {
        $h->execute(@alleles, @existing_protocol_allele_names);
    }
    else {
        $h->execute(@alleles);
    }
    my @existing_global_allele_names;
    while ( my ($allele_name) = $h->fetchrow_array()) {
        push @existing_global_allele_names, $allele_name;
    }
    if ( scalar @existing_global_allele_names > 0 ) {
        push @error_messages, "The following alleles already exist in the Allele table outside of this protocol: " . join(', ', sort @existing_global_allele_names) . ". These names cannot be used.";
    }

    # Parse each row to get unique marker and allele counts
    my %marker_count;
    my %allele_count;
    foreach my $row (@$parsed_data) {
        my $marker = $row->{'Marker'};
        my $alias = $row->{'Alias'};
        my $alleles = $row->{'Allele'};
        $marker_count{$marker}++;
        $marker_count{$alias}++ if $alias;
        foreach (@$alleles) {
            $allele_count{$_}++;
        }
    }

    # Make sure there are no duplicated markers or alleles in the file
    my @duplicated_markers;
    my @duplicated_alleles;
    foreach my $m (keys %marker_count) {
        if ( $marker_count{$m} > 1 ) {
            push @duplicated_markers, $m;
        }
    }
    foreach my $a (keys %allele_count) {
        if ( $allele_count{$a} > 1 ) {
            push @duplicated_alleles, $a;
        }
    }
    if ( scalar @duplicated_markers > 0 ) {
        push @error_messages, "The following markers were included in your file more than once: " . join(', ', sort @duplicated_markers);
    }
    if ( scalar @duplicated_alleles > 0 ) {
        push @error_messages, "The following alleles were included in your file more than once: " . join(', ', sort @duplicated_alleles);
    }

    # Ensure that the marker trait ontology root is set in the config
    if ( ! $self->{marker_metadata_trait_ontology_root} ) {
        push @error_messages, "The marker metadata trait ontology is not set in the server config.";
    }

    # Check the trait categories against the ontology terms
    else {
        my $ontology_root = $self->{marker_metadata_trait_ontology_root};

        # Get cvterm of root term
        my ($db_name, $accession) = split ":", $self->{marker_metadata_trait_ontology_root};
        my $db = $schema->resultset('General::Db')->search({ name => $db_name })->first();
        my $dbxref;
        $dbxref = $db->find_related('dbxrefs', { accession => $accession }) if $db;
        my $root_cvterm;
        $root_cvterm = $dbxref->cvterm if $dbxref;
        my $root_cvterm_id;
        $root_cvterm_id = $root_cvterm->cvterm_id if $root_cvterm;

        # Get children (recursively) of root cvterm
        my $ontology = [];
        $ontology = $onto->get_children($root_cvterm_id) if $root_cvterm_id;

        # Build hash of names => cvertm ids
        my $ontology_terms = _parse_ontology_term($ontology);

        # Ensure the trait categories are valid ontology terms
        my @missing_categories;
        foreach my $category (@categories) {
            if ( ! exists $ontology_terms->{lc $category} ) {
                push @missing_categories, $category;
            }
        }

        # Return an error if there are missing categories
        if ( scalar(@missing_categories) > 0 ) {
            push @error_messages, "The following trait categories are not in the marker metadata trait ontology: " . join(', ', @missing_categories);
        }

        # Cache the parsed ontology terms
        $self->parsed_ontology_terms($ontology_terms);
    }

    # Extract the db names from the references
    my %db_names;
    foreach my $reference (@references) {
        my ($db_name, $entity_name) = split(':', $reference);
        $db_name =~ s/^\s+|\s+$//g;
        $db_names{lc $db_name} = $db_name;
    }

    # Lookup the existing dbs
    my %existing_dbs;
    if ( scalar(keys %db_names) > 0 ) {
        $phs = join ',', map { "?" } keys %db_names;
        $q = "SELECT db_id, lower(name) FROM public.db WHERE lower(name) IN ($phs)";
        $h = $dbh->prepare($q);
        $h->execute(keys %db_names);
        while ( my ($db_id, $db_name) = $h->fetchrow_array()) {
            $existing_dbs{$db_name} = $db_id;
        }
        $self->parsed_dbs(\%existing_dbs);
    }

    # Find any missing dbs
    my @missing_dbs;
    foreach my $db_name (keys %db_names) {
        if ( ! exists $existing_dbs{$db_name} ) {
            push @missing_dbs, $db_names{$db_name};
        }
    }
    if ( scalar @missing_dbs > 0 ) {
        push @error_messages, "The following external reference databases do not exist: " . join(', ', @missing_dbs);
    }

    # return any error messages
    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    # set warning messages
    if (scalar(@warning_messages) >= 1) {
        $warnings{'warning_messages'} = \@warning_messages;
        $self->_set_parse_warnings(\%warnings);
    }

    # Cache parsed allele data
    $self->parsed_allele_data($parsed);

    return 1;
}

# recursively get the name and id of the term and its children
# return a hash of (lowercase) name => cvterm id
sub _parse_ontology_term {
    my $term = shift;
    my $map = shift || {};

    if (ref $term eq 'ARRAY') {
        foreach (@$term) {
            $map = _parse_ontology_term($_, $map);
        }
    }
    elsif (ref $term eq 'HASH' ) {
        my $name = lc $term->{name};
        my $id = $term->{cvterm_id};
        my $children = $term->{children};

        $map->{$name} = $id;

        $map = _parse_ontology_term($children, $map) if $children;
    }

    return $map;
}

sub _parse_with_plugin {
    my $self = shift;
    my $parsed = $self->parsed_allele_data();
    my $parsed_data = $parsed->{data};
    my $ontology_terms = $self->parsed_ontology_terms();
    my $existing_dbs = $self->parsed_dbs();

    # Aggregate allele values by marker name
    my %marker_metadata;
    foreach my $row (@$parsed_data) {
        my $marker = $row->{'Marker'};
        my $alias = $row->{'Alias'};
        my $description = $row->{'Description'};
        my $alleles = $row->{'Allele'};
        my $category_names = $row->{'Category'};
        my $reference_values = $row->{'Reference'};

        # add category cvterm ids
        my @categories;
        foreach (@$category_names) {
            my $name = lc $_;
            $name =~ s/^\s+|\s+$//g;
            my $id = $ontology_terms->{$name};
            if ( defined $id ) {
                push @categories, $id;
            }
        }

        # add references (hash of db id and entity name)
        my @references;
        foreach my $ref (@$reference_values) {
            my ($db_name, $entity_name) = split('=', $ref);
            $db_name =~ s/^\s+|\s+$//g;
            $entity_name =~ s/^\s+|\s+$//g;
            my $db_id = $existing_dbs->{lc $db_name};
            if ( $db_id && $entity_name ) {
                push @references, { db => $db_id, entity => $entity_name };
            }
        }

        $marker_metadata{$marker} = {
            marker => $marker,
            alias => $alias,
            description => $description,
            alleles => $alleles,
            categories => \@categories,
            references => \@references
        };
    }

    # Set parsed data
    $self->_set_parsed_data({
        markers => \%marker_metadata,
        existing_locus_names => $parsed->{existing_locus_names},
        existing_locus_ids => $parsed->{existing_locus_ids},
        existing_allele_names => $parsed->{existing_allele_names},
        existing_allele_ids => $parsed->{existing_allele_ids}
    });
}

1;