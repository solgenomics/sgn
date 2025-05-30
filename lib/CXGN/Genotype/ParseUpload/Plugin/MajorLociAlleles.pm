package CXGN::Genotype::ParseUpload::Plugin::MajorLociAlleles;

use Moose::Role;
use CXGN::File::Parse;
use CXGN::Onto;
use Data::Dumper;

has 'parsed_allele_data' => (is => 'rw', isa => 'HashRef');
has 'parsed_ontology_terms' => (is => 'rw', isa => 'HashRef');

sub _validate_with_plugin {
    my $self = shift;
    my $protocol_id = $self->get_nd_protocol_id();
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $dbh = $schema->storage->dbh();
    my $onto = CXGN::Onto->new({ schema => $schema });
    my %errors;
    my @error_messages;

    ## Parse the upload file
    my $parser = CXGN::File::Parse->new(
        file => $filename,
        required_columns => [ 'Locus', 'Allele' ],
        optional_columns => [ 'Description', 'Category' ],
        column_arrays => [ 'Allele', 'Category' ]
    );
    my $parsed = $parser->parse();
    my $parsed_errors = $parsed->{errors};
    my $parsed_data = $parsed->{data};
    my @markers = @{$parsed->{values}->{'Locus'}};
    my @categories = @{$parsed->{values}->{'Category'}};

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
            push @error_messages, "The Locus '$marker' in your file does not match any of the markers in the selected protocol.";
        }
    }

    # Make sure the major loci don't already exist in the phenome table
    my $phs = join ',', map { "?" } @markers;
    my $q = "SELECT locus_name FROM phenome.locus WHERE locus_name IN ($phs)";
    my $h = $dbh->prepare($q);
    $h->execute(@markers);
    while (my ($locus_name) = $h->fetchrow_array()){
        push @error_messages, "The Locus '$locus_name' already exists in the Locus table.";
    }

    # Ensure that the major locus trait ontology root is set in the config
    if ( ! $self->{major_locus_trait_ontology_root} ) {
        push @error_messages, "The major locus trait ontology is not set in the server config.";
    }

    # Check the trait categories against the ontology terms
    else {
        my $ontology_root = $self->{major_locus_trait_ontology_root};

        # Get cvterm of root term
        my ($db_name, $accession) = split ":", $self->{major_locus_trait_ontology_root};
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
        foreach (@categories) {
            my $category = lc $_;
            if ( ! exists $ontology_terms->{$category} ) {
                push @missing_categories, $category;
            }
        }

        # Return an error if there are missing categories
        if ( scalar(@missing_categories) > 0 ) {
            push @error_messages, "The following trait categories are not in the major locus trait ontology: " . join(', ', @missing_categories);
        }

        # Cache the parsed ontology terms
        $self->parsed_ontology_terms($ontology_terms);
    }

    # return any error messages
    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
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

    # Aggregate allele values by locus name
    my %major_loci;
    foreach my $row (@$parsed_data) {
        my $locus = $row->{'Locus'};
        my $description = $row->{'Description'};
        my $alleles = $row->{'Allele'};
        my $category_names = $row->{'Category'};
        my @categories;

        # add category cvterm ids
        foreach (@$category_names) {
            my $name = lc $_;
            my $id = $ontology_terms->{$name};
            if ( defined $id ) {
                push @categories, $id;
            }
        }

        $major_loci{$locus} = {
            locus => $locus,
            description => $description,
            alleles => $alleles,
            categories => \@categories
        };
    }

    # Set parsed data
    $self->_set_parsed_data(\%major_loci);
}

1;