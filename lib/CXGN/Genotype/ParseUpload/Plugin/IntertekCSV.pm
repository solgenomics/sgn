package CXGN::Genotype::ParseUpload::Plugin::IntertekCSV;

use Moose::Role;
use SGN::Model::Cvterm;
use Data::Dumper;
use Text::CSV;
use CXGN::Genotype::Protocol;

# Check that all sample IDs are in the database already
sub _validate_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $marker_info_filename = $self->get_filename_marker_info();
    my $protocol_id = $self->get_nd_protocol_id();
    my $schema = $self->get_chado_schema();
    my %errors;
    my @error_messages;
    my %missing_accessions;
    my %stored_marker_info;
    my %supported_marker_info;

    if (defined $protocol_id) {
        my $stored_protocol = CXGN::Genotype::Protocol->new({
            bcs_schema => $schema,
            nd_protocol_id => $protocol_id
        });

        my $stored_markers = $stored_protocol->markers();
        print STDERR "STORED MARKERS =".Dumper($stored_markers)."\n";
        %stored_marker_info = %$stored_markers;
    }

    #supported marker info
    $supported_marker_info{'Quality'} = 1;
    $supported_marker_info{'Filter'} = 1;
    $supported_marker_info{'Info'} = 1;
    $supported_marker_info{'Format'} = 1;
    $supported_marker_info{'Sequence'} = 1;

    my $marker_info_csv = Text::CSV->new({ sep_char => ',' });
    my $MI_F;

    my %marker_names;
    # Open Marker Info File and get headers
    open($MI_F, "<", $marker_info_filename) || die "Can't open file $marker_info_filename\n";

        my $marker_info_header_row = <$MI_F>;
        my @marker_header_info;

        # Get first row, which is the header
        if ($marker_info_csv->parse($marker_info_header_row)) {
            @marker_header_info = $marker_info_csv->fields();
        }

        my $intertek_snp_id_header = $marker_header_info[0];
        $intertek_snp_id_header =~ s/^\s+|\s+$//g;

        my $customer_snp_id_header = $marker_header_info[1];
        $customer_snp_id_header =~ s/^\s+|\s+$//g;

        my $ref_header = $marker_header_info[2];
        $ref_header =~ s/^\s+|\s+$//g;

        my $alt_header = $marker_header_info[3];
        $alt_header =~ s/^\s+|\s+$//g;

        my $chrom_header = $marker_header_info[4];
        $chrom_header =~ s/^\s+|\s+$//g;

        my $position_header = $marker_header_info[5];
        $position_header =~ s/^\s+|\s+$//g;

        # Check that the columns in the marker info file are what we expect
        if ($intertek_snp_id_header ne 'IntertekSNPID'){
            push @error_messages, 'Column 1 header must be "IntertekSNPID" in the SNP Info File.';
        }
        if ($customer_snp_id_header ne 'CustomerSNPID'){
            push @error_messages, 'Column 2 header must be "CustomerSNPID" in the SNP Info File.';
        }
        if ($ref_header ne 'Reference'){
            push @error_messages, 'Column 3 header must be "Reference" in the SNP Info File.';
        }
        if ($alt_header ne 'Alternate'){
            push @error_messages, 'Column 4 header must be "Alternate" in the SNP Info File.';
        }
        if ($chrom_header ne 'Chromosome'){
            push @error_messages, 'Column 5 header must be "Chromosome" in the SNP Info File.';
        }
        if ($position_header ne 'Position'){
            push @error_messages, 'Column 6 header must be "Position" in the SNP Info File.';
        }

        for my $i (6 .. $#marker_header_info){
            my $each_header = $marker_header_info[$i];
            $each_header =~ s/^\s+|\s+$//g;

            if (!$supported_marker_info{$each_header}){
                push @error_messages, "Invalid  marker info type: $each_header";
            }
        }

        while (my $marker_line = <$MI_F>) {
            my @marker_line_info;
            if ($marker_info_csv->parse($marker_line)) {
                @marker_line_info = $marker_info_csv->fields();
            }
            my $intertek_snp_id = $marker_line_info[0];
            $intertek_snp_id =~ s/^\s+|\s+$//g;
            my $customer_snp_id = $marker_line_info[1];
            $customer_snp_id =~ s/^\s+|\s+$//g;
            my $ref = $marker_line_info[2];
            $ref =~ s/^\s+|\s+$//g;
            my $alt = $marker_line_info[3];
            $alt =~ s/^\s+|\s+$//g;
            my $chrom = $marker_line_info[4];
            $chrom =~ s/^\s+|\s+$//g;

            if (!$intertek_snp_id){
                push @error_messages, 'Intertek snp id is required for all markers.';
            }
            if (!$customer_snp_id){
                push @error_messages, 'Customer snp id is required for all markers.';
            }
            if (!$ref){
                push @error_messages, 'Reference is required for all markers.';
            }
            if (!$alt){
                push @error_messages, 'Alternate is required for all markers.';
            }
            if ($chrom eq '' || !defined($chrom)) {
                push @error_messages, 'Chromosome is required for all markers.';
            }
            $marker_names{$customer_snp_id} = 1;
        }

    close($MI_F);

    my @file_marker_names = keys %marker_names;

    if (defined $protocol_id) {
        foreach (@file_marker_names) {
            if (!exists($stored_marker_info{$_})) {
                push @error_messages, "Marker $_ in the marker info file is not found in the selected protocol.";
            }
        }
    }

    # Open GRID FILE and parse
    my $csv = Text::CSV->new({ sep_char => ',' });
    my $F;
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

        foreach (@markers) {
            if (!exists($marker_names{$_})) {
                push @error_messages, "Marker $_ in the SNP grid file is not found in the marker info file.";
            }
        }

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

    my $stock_type = $self->get_observation_unit_type_name;
    my @observation_units_names_trim;
    # Separates sample name from lab id
    foreach (@observation_unit_names) {
        if ($stock_type eq 'accession'){
            my ($observation_unit_name_with_accession_name, $lab_number) = split(/\./, $_, 2);
            $observation_unit_name_with_accession_name =~ s/^\s+|\s+$//g;
            my ($observation_unit_name, $accession_name) = split(/\|\|\|/, $observation_unit_name_with_accession_name);
            push @observation_units_names_trim, $observation_unit_name;
        }
        else {
            my ($observation_unit_name, $accession_name) = split(/\|\|\|/, $_);
            push @observation_units_names_trim, $observation_unit_name;
        }
    }
    my $observation_unit_names = \@observation_units_names_trim;

    my $organism_id = $self->get_organism_id;
    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();

    # Validate that the sample names are in the database already
    my @missing_stocks;
    my $validator = CXGN::List::Validate->new();
    if ($stock_type eq 'tissue_sample'){
        @missing_stocks = @{$validator->validate($schema,'tissue_samples',$observation_unit_names)->{'missing'}};
    } elsif ($stock_type eq 'accession'){
        @missing_stocks = @{$validator->validate($schema,'accessions',$observation_unit_names)->{'missing'}};
    } elsif ($stock_type eq 'stocks'){
        @missing_stocks = @{$validator->validate($schema,'stocks',$observation_unit_names)->{'missing'}};
    } else {
        push @error_messages, "You can only upload genotype data for a tissue_sample OR accession (including synonyms) OR stocks!"
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
    my $marker_info_filename = $self->get_filename_marker_info();
    my $schema = $self->get_chado_schema();
    my $stock_type = $self->get_observation_unit_type_name;
    my @error_messages;
    my %errors;

    print STDERR "Reading Intertek files to parse\n";

    my %protocolprop_info;
    $protocolprop_info{'header_information_lines'} = [];
    $protocolprop_info{'sample_observation_unit_type_name'} = $stock_type;

    my $marker_info_csv = Text::CSV->new({ sep_char => ',' });
    my $MF;
    my %marker_info;
    my %marker_info_nonseparated;
    my @marker_info_keys = qw(name intertek_name chrom pos ref alt);


    # Open Marker Info File and parse into the %marker_info for later use
    open($MF, "<", $marker_info_filename) || die "Can't open file $marker_info_filename\n";

        my $marker_header_row = <$MF>;
        my @marker_header_info;

        # Get first row, which is the header
        if ($marker_info_csv->parse($marker_header_row)) {
            @marker_header_info = $marker_info_csv->fields();
        }

        for my $i (6 .. $#marker_header_info){
            my $header = $marker_header_info[$i];
            $header =~ s/^\s+|\s+$//g;
            if ($header eq 'Quality') {
                push @marker_info_keys, 'qual';
            } elsif ($header eq 'Filter') {
                push @marker_info_keys, 'filter';
            } elsif ($header eq 'Info') {
                push @marker_info_keys, 'info';
            } elsif ($header eq 'Format') {
                push @marker_info_keys, 'format';
            } elsif ($header eq 'Sequence') {
                push @marker_info_keys, 'sequence';
            }
        }

        # Iterate over all rows to get all the marker's info
        while (my $marker_line = <$MF>) {
            my @marker_line_info;
            if ($marker_info_csv->parse($marker_line)) {
                @marker_line_info = $marker_info_csv->fields();
            }
            my $intertek_snp_id = $marker_line_info[0];
            my $customer_snp_id = $marker_line_info[1];
            my $ref = $marker_line_info[2];
            my $alt = $marker_line_info[3];
            my $chromosome = $marker_line_info[4];
            my $position = $marker_line_info[5];
            my %marker = (
                ref => $ref,
                alt => $alt,
                intertek_name => $intertek_snp_id,
                chrom => $chromosome,
                pos => $position,
                name => $customer_snp_id,
            );

            for my $i (6 .. $#marker_header_info){
                my $header = $marker_header_info[$i];
                $header =~ s/^\s+|\s+$//g;
                if ($header eq 'Quality') {
                    $marker{'qual'} = $marker_line_info[$i];
                } elsif ($header eq 'Filter') {
                    $marker{'filter'} = $marker_line_info[$i];
                } elsif ($header eq 'Info') {
                    $marker{'info'} = $marker_line_info[$i];
                } elsif ($header eq 'Format') {
                    $marker{'format'} = $marker_line_info[$i];
                } elsif ($header eq 'Sequence') {
                    $marker{'sequence'} = $marker_line_info[$i];
                }
            }

            push @{$protocolprop_info{'marker_names'}}, $customer_snp_id;
            $marker_info_nonseparated{$customer_snp_id} = \%marker;

            push @{$protocolprop_info{'markers_array'}->{$chromosome}}, \%marker;
            $marker_info{$chromosome}->{$customer_snp_id} = \%marker;
        }

    close($MF);
        #print STDERR Dumper \%marker_info_lookup;
    $protocolprop_info{'markers'} = \%marker_info;

    # Open GRID FILE and parse
    my $csv = Text::CSV->new({ sep_char => ',' });
    my $F;
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

                my $ref = $marker_info_nonseparated{$customer_snp_id}->{ref};
                my $alt = $marker_info_nonseparated{$customer_snp_id}->{alt};
                my $chrom = $marker_info_nonseparated{$customer_snp_id}->{chrom};
                my $marker_name = $marker_info_nonseparated{$customer_snp_id}->{name} || $customer_snp_id;

                my $genotype_obj;
                if ($ref && $alt) {

                    my @gt_vcf_genotype;
                    my @ref_calls;
                    my @alt_calls;
                    my $gt_dosage_alt = 0;
                    foreach my $a (@alleles){
                        if ($a eq $ref) {
                            push @gt_vcf_genotype, 0;
                            push @ref_calls, $a;
                        }
                        elsif ($a eq $alt) {
                            push @gt_vcf_genotype, 1;
                            push @alt_calls, $a;
                            $gt_dosage_alt++;
                        }
                        elsif ($a eq '?' || $a eq 'Uncallable') {
                            $gt_dosage_alt = 'NA';
                            push @gt_vcf_genotype, './.';
                            push @alt_calls, './.';
                        } else {
                            push @error_messages, "Allele Call Does Not Match Ref or Alt for Sample: $sample_id_with_lab_id Marker: $marker_name Alt: $alt Ref: $ref Allele: $a";
                        }
                    }

                    my @vcf_genotype = (@ref_calls, @alt_calls);
                    my $vcf_genotype_string = join ',', @vcf_genotype;
                    my $vcf_gt_genotype_string = join '/', @gt_vcf_genotype;
                    $genotype_obj = {
                        'GT' => $vcf_gt_genotype_string,
                        'NT' => $vcf_genotype_string,
                        'DS' => "$gt_dosage_alt"
                    };
                } else {
                    die "There should always be a ref and alt according to validation above\n";
                }

                $genotype_info{$sample_id_with_lab_id}->{$chrom}->{$marker_name} = $genotype_obj;
            }
        }

    close($F);

    if (scalar(@error_messages)>0) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    my %parsed_data = (
        protocol_info => \%protocolprop_info,
        genotypes_info => \%genotype_info,
        observation_unit_uniquenames => \@observation_unit_names,
        marker_info_keys => \@marker_info_keys
    );

    $self->_set_parsed_data(\%parsed_data);

    return 1;
}

1;
