package CXGN::Genotype::ParseUpload::Plugin::GridFileIntertekCSV;

use Moose::Role;
use SGN::Model::Cvterm;
use Data::Dumper;
use Text::CSV;

# Check that all sample IDs are in the database already
sub _validate_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $protocol_id = $self->get_nd_protocol_id();
    my $schema = $self->get_chado_schema();
    my %errors;
    my @error_messages;
    my %missing_accessions;

    my $csv = Text::CSV->new({ sep_char => ',' });

    my $F;
    # Open GRID FILE and parse
    open($F, "<", $filename) || die "Can't open file $filename\n";

        my $header_row = <$F>;
        my @header_info;

        # Get first row, which is the header
        if ($csv->parse($header_row)) {
            @header_info = $csv->fields();
        }

        # Remove the first column from the header
        my $unneeded_first_column = shift @header_info;
        my @fields = ($unneeded_first_column);
        my @markers = @header_info;

        my @observation_unit_names;
        # Iterate over all rows to get the sample ID and labID
        while (my $line = <$F>) {
            my @line_info;
            if ($csv->parse($line)) {
                @line_info = $csv->fields();
            }
            my $sample_name = $line_info[0];
            chomp $sample_name;
            $sample_name =~ s/^\s+|\s+$//g;
            push @observation_unit_names, $sample_name;
        }

    close($F);

    # Check that the first column in the header is equal to 'SampleName.LabID'
    if ($fields[0] ne 'SampleName.LabID'){
        push @error_messages, 'Column 1 header must be "SampleName.LabID" in the Grid File.';
    }

    my $number_observation_units = scalar(@observation_unit_names);
    print STDERR "Number observation units: $number_observation_units...\n";

    my @observation_units_names_trim;
    # Separates sample name from lab id
    foreach (@observation_unit_names) {
        my ($observation_unit_name_with_accession_name, $lab_id) = split(/\./, $_);
        $observation_unit_name_with_accession_name =~ s/^\s+|\s+$//g;
        my ($observation_unit_name, $accession_name) = split(/\|\|\|/, $observation_unit_name_with_accession_name);
        push @observation_units_names_trim, $observation_unit_name;
    }
    my $observation_unit_names = \@observation_units_names_trim;

    my $organism_id = $self->get_organism_id;
    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();

    # Validate that the sample names are in the database already
    my $stock_type = $self->get_observation_unit_type_name;
    my @missing_stocks;
    my $validator = CXGN::List::Validate->new();
    if ($stock_type eq 'tissue_sample'){
        @missing_stocks = @{$validator->validate($schema,'tissue_samples',$observation_unit_names)->{'missing'}};
    } elsif ($stock_type eq 'accession'){
        @missing_stocks = @{$validator->validate($schema,'accessions',$observation_unit_names)->{'missing'}};
    } else {
        push @error_messages, "You can only upload genotype data for a tissue_sample OR accession (including synonyms)!"
    }

    my %unique_stocks;
    foreach (@missing_stocks){
        $unique_stocks{$_}++;
    }

    @missing_stocks = sort keys %unique_stocks;
    my @missing_stocks_return;
    # Optionally the missing sample ids can be created in the database as new accessions, but that is not recommended 
    foreach (@missing_stocks){
        if (!$self->get_create_missing_observation_units_as_accessions){
            push @missing_stocks_return, $_;
            print STDERR "WARNING! Observation unit name $_ not found for stock type $stock_type. You can pass an option to automatically create accessions.\n";
        } else {
            my $stock = $schema->resultset("Stock::Stock")->create({
                organism_id => $organism_id,
                name       => $_,
                uniquename => $_,
                type_id     => $accession_cvterm_id,
            });
        }
    }

    my $protocol = CXGN::Genotype::Protocol->new({
        bcs_schema => $schema,
        nd_protocol_id => $protocol_id
    });
    my $markers_in_protocol = $protocol->marker_names;
    my %markers_in_protocol_hash;
    foreach (@$markers_in_protocol) {
        $markers_in_protocol_hash{$_}++;
    }

    my @markers_not_in_protocol;
    foreach (@markers) {
        if (!exists($markers_in_protocol_hash{$_})) {
            push @markers_not_in_protocol, $_;
        }
    }

    #If there are markers in the uploaded file that are not saved in the protocol, they will be returned along in the error message
    if (scalar(@markers_not_in_protocol)>0){
        $errors{'missing_markers'} = \@markers_not_in_protocol;
        push @error_messages, "The following markers are not in the database for the selected protocol: ".join(',',@markers_not_in_protocol);
    }

    # If there are missing sample names, they will be returned along with an error message
    if (scalar(@missing_stocks_return)>0){
        $errors{'missing_stocks'} = \@missing_stocks_return;
        push @error_messages, "The following stocks are not in the database: ".join(',',@missing_stocks_return);
    }

    #store any errors found in the parsed file to parse_errors accessor
    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    return 1; #returns true if validation is passed
}

# After validation, the file data is actually parsed into the expected object
sub _parse_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $protocol_id = $self->get_nd_protocol_id();
    my $schema = $self->get_chado_schema();
    my $stock_type = $self->get_observation_unit_type_name;

    print STDERR "Reading VCF to parse\n";

    my $protocol = CXGN::Genotype::Protocol->new({
        bcs_schema => $schema,
        nd_protocol_id => $protocol_id
    });

    my %protocolprop_info;
    $protocolprop_info{'header_information_lines'} = $protocol->header_information_lines;
    $protocolprop_info{'sample_observation_unit_type_name'} = $protocol->sample_observation_unit_type_name;
    $protocolprop_info{'marker_names'} = $protocol->marker_names;
    #$protocolprop_info{'markers_array'} = $protocol->markers_array;
    my $marker_info = $protocol->markers;
    $protocolprop_info{'markers'} = $marker_info;

    my $csv = Text::CSV->new({ sep_char => ',' });

    my $F;
    # Open GRID FILE and parse
    open($F, "<", $filename) || die "Can't open file $filename\n";

        my $header_row = <$F>;
        my @header_info;

        # Get first row, which is the header
        if ($csv->parse($header_row)) {
            @header_info = $csv->fields();
        }

        # Remove the first column from the header
        my $unneeded_first_column = shift @header_info;
        my @fields = ($unneeded_first_column);
        my @markers = @header_info;

        my %genotype_info;
        my @observation_unit_names;
        # Iterate over all rows in file
        while (my $line = <$F>) {
            my @line_info;
            if ($csv->parse($line)) {
                @line_info = $csv->fields();
            }

            # Get sample id and collect then in an array
            my $sample_id_with_lab_id = shift @line_info;
            chomp $sample_id_with_lab_id;
            $sample_id_with_lab_id =~ s/^\s+|\s+$//g;
            push @observation_unit_names, $sample_id_with_lab_id;

            my $counter = 0;
            foreach my $customer_snp_id (@markers){
                my $genotype = $line_info[$counter];
                $counter++;
                my @alleles = split ":", $genotype;

                my $ref = $marker_info->{$customer_snp_id}->{ref};
                my $alt = $marker_info->{$customer_snp_id}->{alt};
                my $marker_name = $marker_info->{$customer_snp_id}->{name} || $customer_snp_id;

                my $genotype_obj;
                if ($ref && $alt) {

                    my @vcf_genotype; # should look like the vcf genotype call e.g. 0/1 or 0/0 or ./. or missing data
                    my @gt_vcf_genotype;
                    my $gt_dosage = 0;
                    foreach my $a (@alleles){
                        my $gt_val;
                        if ($a eq $ref) {
                            $gt_val = 0;
                            push @gt_vcf_genotype, $gt_val;
                        }
                        if ($a eq $alt) {
                            $gt_val = 1;
                            push @gt_vcf_genotype, $gt_val;
                        }
                        $gt_dosage = $gt_dosage + $gt_val;
                        push @vcf_genotype, $a;
                    }

                    my $vcf_genotype_string = join '/', @vcf_genotype;
                    my $vcf_gt_genotype_string = join '/', @gt_vcf_genotype;
                    $genotype_obj = { 'GT' => $vcf_gt_genotype_string };
                    $genotype_obj = { 'NT' => $vcf_genotype_string };
                    $genotype_obj = { 'DS' => $gt_dosage };
                } else {
                    die "There should always be a ref and alt according to validation above\n";
                }

                $genotype_info{$sample_id_with_lab_id}->{$marker_name} = $genotype_obj;
            }
        }

    close($F);

    my %parsed_data = (
        protocol_info => \%protocolprop_info,
        genotypes_info => \%genotype_info,
        observation_unit_uniquenames => \@observation_unit_names
    );

    $self->_set_parsed_data(\%parsed_data);

    return 1;
}

1;
