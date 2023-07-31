package CXGN::Genotype::ParseUpload::Plugin::KASP;

use Moose::Role;
use SGN::Model::Cvterm;
use Data::Dumper;
use Text::CSV;
use CXGN::Genotype::Protocol;
use CXGN::List::Validate;
use CXGN::Stock::TissueSample::FacilityIdentifiers;


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

    my %seen_marker_names;
    my %seen_facility_marker_names;
    open($MI_F, "<", $marker_info_filename) || die "Can't open file $marker_info_filename\n";

        my $marker_info_header_row = <$MI_F>;
        my @marker_header_info;

        if ($marker_info_csv->parse($marker_info_header_row)) {
            @marker_header_info = $marker_info_csv->fields();
        }

        my $customer_marker_name_header = $marker_header_info[0];
        $customer_marker_name_header =~ s/^\s+|\s+$//g;

        my $facility_marker_name_header = $marker_header_info[1];
        $facility_marker_name_header =~ s/^\s+|\s+$//g;

        my $Xallele_header = $marker_header_info[2];
        $Xallele_header =~ s/^\s+|\s+$//g;

        my $Yallele_header = $marker_header_info[3];
        $Yallele_header =~ s/^\s+|\s+$//g;

        my $chrom_header = $marker_header_info[4];
        $chrom_header =~ s/^\s+|\s+$//g;

        my $position_header = $marker_header_info[5];
        $position_header =~ s/^\s+|\s+$//g;

        if ($customer_marker_name_header ne 'CustomerMarkerName'){
            push @error_messages, 'Column 1 header must be "CustomerMarkerName" in the marker Info File.';
        }
        if ($facility_marker_name_header ne 'FacilityMarkerName'){
            push @error_messages, 'Column 2 header must be "FacilityMarkerName" in the marker Info File.';
        }
        if ($Xallele_header ne 'Xallele'){
            push @error_messages, 'Column 3 header must be "Xallele" in the marker Info File.';
        }
        if ($Yallele_header ne 'Yallele'){
            push @error_messages, 'Column 4 header must be "Yallele" in the marker Info File.';
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

            my $customer_marker_name = $marker_line_info[0];
            $customer_marker_name =~ s/^\s+|\s+$//g;
            my $facility_marker_name = $marker_line_info[1];
            $facility_marker_name =~ s/^\s+|\s+$//g;
            my $Xallele = $marker_line_info[2];
            $Xallele =~ s/^\s+|\s+$//g;
            my $Yallele = $marker_line_info[3];
            $Yallele =~ s/^\s+|\s+$//g;
            my $chrom = $marker_line_info[4];
            $chrom =~ s/^\s+|\s+$//g;
            my $position = $marker_line_info[5];
            $position =~ s/^\s+|\s+$//g;


            if (!defined $customer_marker_name){
                push @error_messages, 'Customer marker name is required for all markers.';
            }
            if (!defined $facility_marker_name){
                push @error_messages, 'Facility marker name is required for all markers.';
            }
            if (!defined $Xallele){
                push @error_messages, 'X allele info is required for all markers.';
            }
            if (!defined $Yallele){
                push @error_messages, 'Y allele info is required for all markers.';
            }
            if (!defined $chrom) {
                push @error_messages, 'Chromosome is required for all markers.';
            }
            if (!defined $position) {
                push @error_messages, 'Position is required for all markers.';
            }

            $seen_marker_names{$customer_marker_name} = 1;
            $seen_facility_marker_names{$facility_marker_name} = 1;
        }

    close($MI_F);
    print STDERR "SEEN MARKER NAMES =".Dumper(\%seen_marker_names)."\n";
    print STDERR "SEEN FACILITY MARKER NAMES =".Dumper(\%seen_facility_marker_names)."\n";

    my @file_marker_names = keys %seen_marker_names;

    if (defined $protocol_id) {
        foreach (@file_marker_names) {
            if (!exists($stored_marker_info{$_})) {
                push @error_messages, "Marker $_ in the marker info file is not found in the selected protocol.";
            }
        }
    }

    my $csv = Text::CSV->new({ sep_char => ',' });
    my $F;

    my %seen_sample_names;
    my %seen_facility_sample_names;
    open($F, "<", $filename) || die "Can't open file $filename\n";

        my $header_row = <$F>;
        my @header_info;

        if ($csv->parse($header_row)) {
            @header_info = $csv->fields();
        }

        my $marker_name_header = $header_info[0];
        $marker_name_header =~ s/^\s+|\s+$//g;
        print STDERR "MARKER NAME HEADER =".Dumper($marker_name_header)."\n";
        my $sample_name_header = $header_info[1];
        $sample_name_header =~ s/^\s+|\s+$//g;
        print STDERR "SAMPLE NAME HEADER =".Dumper($sample_name_header)."\n";
        my $snpcall_header = $header_info[2];
        $snpcall_header =~ s/^\s+|\s+$//g;

        my $Xvalue_header = $header_info[3];
        $Xvalue_header =~ s/^\s+|\s+$//g;

        my $Yvalue_header = $header_info[4];
        $Yvalue_header =~ s/^\s+|\s+$//g;

        if (($marker_name_header ne 'MarkerName') && ($marker_name_header ne 'FacilityMarkerName')){
            push @error_messages, 'Column 1 header must be "MarkerName" or "FacilityMarkerName" in the KASP result File.';
        }

        if (($sample_name_header ne 'SampleName') && ($sample_name_header ne 'FacilitySampleName')){
            push @error_messages, 'Column 2 header must be "SampleName" or "FacilitySampleName" in the KASP result File.';
        }

        if ($snpcall_header ne 'SNPcall'){
            push @error_messages, 'Column 3 header must be "SNPcall" in the KASP result File.';
        }

        if ($Xvalue_header ne 'Xvalue'){
            push @error_messages, 'Column 4 header must be "Xvalue" in the KASP result File.';
        }

        if ($Yvalue_header ne 'Yvalue'){
            push @error_messages, 'Column 5 header must be "Yvalue" in the KASP result File.';
        }

        while (my $line = <$F>) {
            my @line_info;
            if ($csv->parse($line)) {
                @line_info = $csv->fields();
            }

            my $marker_name = $line_info[0];
            $marker_name =~ s/^\s+|\s+$//g;
            my $sample_name = $line_info[1];
            $sample_name =~ s/^\s+|\s+$//g;
            my $snpcall = $line_info[2];
            $snpcall =~ s/^\s+|\s+$//g;
            my $xvalue = $line_info[3];
            $xvalue =~ s/^\s+|\s+$//g;
            my $yvalue = $line_info[4];
            $yvalue =~ s/^\s+|\s+$//g;

            if (!defined $marker_name){
                push @error_messages, 'Marker name or facility marker name is required for all rows.';
            } elsif (!exists($seen_marker_names{$marker_name}) && !exists($seen_facility_marker_names{$marker_name})) {
                push @error_messages, "Marker $marker_name in the result file is not found in the marker info file.";
            }

            if (!defined $sample_name){
                push @error_messages, 'Sample name or facility sample name is required for all rows.';
            } else {
                if ($sample_name_header eq 'SampleName') {
                    $seen_sample_names{$sample_name}++;
                } elsif ($sample_name_header eq 'FacilitySampleName') {
                    $seen_facility_sample_names{$sample_name}++
                }
            }

            if (!defined $snpcall){
                push @error_messages, 'SNP call is required for all rows.';
            }

            if (!defined $xvalue){
                push @error_messages, 'X value is required for all rows.';
            }

            if (!defined $yvalue){
                push @error_messages, 'Y value is required for all value.';
            }
        }

    close($F);

    my $stock_type = $self->get_observation_unit_type_name;
    my $validate_type = $stock_type.'s';
    print STDERR "VALIDATE TYPE =".Dumper($validate_type)."\n";

    if ($sample_name_header eq 'SampleName') {
        my @all_sample_names = keys %seen_sample_names;
        my $sample_validator = CXGN::List::Validate->new();
        my @sample_missing = @{$sample_validator->validate($schema,$validate_type,\@all_sample_names)->{'missing'}};

        if (scalar(@sample_missing) > 0) {
            push @error_messages, "The following sample names are not in the database, or are not in the database as uniquenames: ".join(',',@sample_missing);
        }
    } elsif ($sample_name_header eq 'FacilitySampleName') {
        my @all_facility_sample_names = keys %seen_facility_sample_names;
        my $facility_sample_validator = CXGN::List::Validate->new();
        my @facility_sample_missing = @{$facility_sample_validator->validate($schema,'facility_identifiers',\@all_facility_sample_names)->{'missing'}};

        if (scalar(@facility_sample_missing) > 0) {
            push @error_messages, "The following facility sample names are not in the database: ".join(',',@facility_sample_missing);
        }
    }

    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }



    return 1;
}


sub _parse_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $marker_info_filename = $self->get_filename_marker_info();
    my $schema = $self->get_chado_schema();
    my $stock_type = $self->get_observation_unit_type_name;
    my @error_messages;
    my %errors;

    my %protocolprop_info;
    $protocolprop_info{'header_information_lines'} = [];
    $protocolprop_info{'sample_observation_unit_type_name'} = $stock_type;

    my $marker_info_csv = Text::CSV->new({ sep_char => ',' });
    my $MF;
    my %marker_info;
    my %marker_info_details;
    my @marker_info_keys = qw(name facility_name chrom pos alt ref);

    open($MF, "<", $marker_info_filename) || die "Can't open file $marker_info_filename\n";

        my $marker_header_row = <$MF>;
        my @marker_header_info;

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
        print STDERR "MARKER INFO KEYS =".Dumper(\@marker_info_keys)."\n";
        my %marker_facility_link;
        while (my $marker_line = <$MF>) {
            my @marker_line_info;
            if ($marker_info_csv->parse($marker_line)) {
                @marker_line_info = $marker_info_csv->fields();
            }

            my $customer_marker_name = $marker_line_info[0];
            my $facility_marker_name = $marker_line_info[1];
            $marker_facility_link{$facility_marker_name} = $customer_marker_name;
            my $ref = $marker_line_info[2];
            my $alt = $marker_line_info[3];
            my $chromosome = $marker_line_info[4];
            my $position = $marker_line_info[5];
            my %marker = (
                ref => $ref,
                alt => $alt,
                facility_name => $facility_marker_name,
                chrom => $chromosome,
                pos => $position,
                name => $customer_marker_name,
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

            push @{$protocolprop_info{'marker_names'}}, $customer_marker_name;
            $marker_info_details{$customer_marker_name} = \%marker;

            push @{$protocolprop_info{'markers_array'}->{$chromosome}}, \%marker;
            $marker_info{$chromosome}->{$customer_marker_name} = \%marker;
        }

    close($MF);
        #print STDERR Dumper \%marker_info_lookup;
    $protocolprop_info{'markers'} = \%marker_info;
    print STDERR "MARKER INFO =".Dumper(\%marker_info)."\n";


    my %kasp_result;

    my $csv = Text::CSV->new({ sep_char => ',' });
    my $F;

    my %seen_samples;
    open($F, "<", $filename) || die "Can't open file $filename\n";

        my $header_row = <$F>;
        my @header_info;

        if ($csv->parse($header_row)) {
            @header_info = $csv->fields();
        }

        my $marker_name_type = $header_info[0];
        $marker_name_type =~ s/^\s+|\s+$//g;

        my $sample_name_type = $header_info[1];
        $sample_name_type =~ s/^\s+|\s+$//g;

        while (my $line = <$F>) {
            my @line_info;
            my $marker_name;
            if ($csv->parse($line)) {
                @line_info = $csv->fields();
            }

            if ($marker_name_type eq 'FacilityMarkerName') {
                my $facility_name = $line_info[0];
                $facility_name =~ s/^\s+|\s+$//g;
                $marker_name = $marker_facility_link{$facility_name};
            } else {
                $marker_name = $line_info[0];
                $marker_name =~ s/^\s+|\s+$//g;
            }
            my $sample_name = $line_info[1];
            $sample_name =~ s/^\s+|\s+$//g;
            my $snpcall = $line_info[2];
            $snpcall =~ s/^\s+|\s+$//g;
            my $xvalue = $line_info[3];
            $xvalue =~ s/^\s+|\s+$//g;
            my $yvalue = $line_info[4];
            $yvalue =~ s/^\s+|\s+$//g;

           $kasp_result{$marker_name}{$sample_name}{'call'} = $snpcall;
           $kasp_result{$marker_name}{$sample_name}{'XV'} = $xvalue;
           $kasp_result{$marker_name}{$sample_name}{'YV'} = $yvalue;
           $seen_samples{$sample_name}++;
        }

    close($F);

    my @observation_unit_names;
    my %facility_sample_name_link;
    if ($sample_name_type eq 'FacilitySampleName') {
        my @facility_sample_list = keys %seen_samples;
        my $facility_identifiers_obj = CXGN::Stock::TissueSample::FacilityIdentifiers->new(bcs_schema => $schema, facility_identifier_list => \@facility_sample_list);
        my $db_sample_name_info = $facility_identifiers_obj->get_tissue_samples();
        %facility_sample_name_link = %{$db_sample_name_info};
        @observation_unit_names = values %facility_sample_name_link
    } else {
        @observation_unit_names = keys %seen_samples;
    }

    print STDERR "FACILITY NAME LINK =".Dumper(\%facility_sample_name_link)."\n";
    print STDERR "OBSERVATION UNIT NAMES =".Dumper(\@observation_unit_names)."\n";

    my %genotype_info;

    foreach my $marker_name_key (keys %kasp_result) {
        my %sample_kasp_result = ();
        my $ref = $marker_info_details{$marker_name_key}{'ref'};
        my $alt = $marker_info_details{$marker_name_key}{'alt'};
        my $chrom = $marker_info_details{$marker_name_key}{'chrom'};
        my $sample_result = $kasp_result{$marker_name_key};
        %sample_kasp_result = %{$sample_result};
        foreach my $sample (keys %sample_kasp_result) {
            my $sample_data = $sample_kasp_result{$sample};
            my $snp_call = $sample_data->{call};
            my $XV = $sample_data->{XV};
            my $YV = $sample_data->{YV};
            my @snp_alleles = split ":", $snp_call;

            my $genotype_obj;
            if ($ref && $alt) {
                my @gt_vcf_genotype;
                my @ref_calls;
                my @alt_calls;
                my $gt_dosage_alt = 0;
                foreach my $a (@snp_alleles){
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
                        push @error_messages, "SNP Call Does Not Match X allele or Y allele for Sample: $sample Marker: $marker_name_key X allele: $ref Y allele: $alt Allele: $a";
                    }
                }

                my @vcf_genotype = (@ref_calls, @alt_calls);
                my $vcf_genotype_string = join ',', @vcf_genotype;
                my $vcf_gt_genotype_string = join '/', @gt_vcf_genotype;
                $genotype_obj = {
                    'GT' => $vcf_gt_genotype_string,
                    'NT' => $vcf_genotype_string,
                    'DS' => "$gt_dosage_alt",
                    'XV' => $XV,
                    'YV' => $YV,
                };
            } else {
                die "There should always be an X allele and a Y allele according to validation above\n";
            }

            if ($sample_name_type eq 'FacilitySampleName') {
                my $store_sample_name = $facility_sample_name_link{$sample};
                $genotype_info{$store_sample_name}->{$chrom}->{$marker_name_key} = $genotype_obj;
            } else {
                $genotype_info{$sample}->{$chrom}->{$marker_name_key} = $genotype_obj;
            }
        }

    }

    print STDERR "KASP PLUGIN PROTOCOLPROP INFO =".Dumper(\%protocolprop_info)."\n";
    print STDERR "KASP PLUGIN GENOTYPE INFO =".Dumper(\%genotype_info)."\n";
    print STDERR "KASP PLUGIN OBSERVATION UNIT NAME =".Dumper(\@observation_unit_names)."\n";
    print STDERR "KASP PLUGIN MARKER INFO KEYS =".Dumper(\@marker_info_keys)."\n";

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
