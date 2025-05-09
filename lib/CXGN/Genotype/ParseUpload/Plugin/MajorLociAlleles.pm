package CXGN::Genotype::ParseUpload::Plugin::MajorLociAlleles;

use Moose::Role;
use CXGN::File::Parse;
use Data::Dumper;

has 'parsed_allele_data' => (is => 'rw', isa => 'HashRef');

sub _validate_with_plugin {
    my $self = shift;
    my $protocol_id = $self->get_nd_protocol_id();
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $dbh = $schema->storage->dbh();
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

sub _parse_with_plugin {
    my $self = shift;
    my $parsed = $self->parsed_allele_data();
    my $parsed_data = $parsed->{data};

    # Aggregate allele values by locus name
    my %major_loci;
    foreach my $row (@$parsed_data) {
        my $locus = $row->{'Locus'};
        my $description = $row->{'Description'};
        my $alleles = $row->{'Allele'};
        my $categories = $row->{'Cateogry'};

        $major_loci{$locus} = {
            locus => $locus,
            description => $description,
            alleles => $alleles,
            categories => $categories
        };
    }

    # Set parsed data
    $self->_set_parsed_data(\%major_loci);
}

1;