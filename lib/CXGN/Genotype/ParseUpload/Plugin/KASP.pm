package CXGN::Genotype::ParseUpload::Plugin::KASP;

use Moose::Role;
use SGN::Model::Cvterm;
use Data::Dumper;
use Text::CSV;
use CXGN::Genotype::Protocol;
use CXGN::List::Validate;

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

    my %marker_names
    open($MI_F, "<", $marker_info_filename) || die "Can't open file $marker_info_filename\n";

        my $marker_info_header_row = <$MI_F>;
        my @marker_header_info;

        if ($marker_info_csv->parse($marker_info_header_row)) {
            @marker_header_info = $marker_info_csv->fields();
        }

        my $facility_snp_id_header = $marker_header_info[0];
        $facility_snp_id_header =~ s/^\s+|\s+$//g;

        my $customer_snp_id_header = $marker_header_info[1];
        $customer_snp_id_header =~ s/^\s+|\s+$//g;

        my $Xallele_header = $marker_header_info[2];
        $Xallele_header =~ s/^\s+|\s+$//g;

        my $Yallele_header = $marker_header_info[3];
        $Yallele_header =~ s/^\s+|\s+$//g;

        my $chrom_header = $marker_header_info[4];
        $chrom_header =~ s/^\s+|\s+$//g;

        my $position_header = $marker_header_info[5];
        $position_header =~ s/^\s+|\s+$//g;

        if ($facility_snp_id_header ne 'FacilitySNPID'){
            push @error_messages, 'Column 1 header must be "FacilitySNPID" in the marker Info File.';
        }
        if ($customer_snp_id_header ne 'CustomerSNPID'){
            push @error_messages, 'Column 2 header must be "CustomerSNPID" in the marker Info File.';
        }
        if ($ref_header ne 'Xallele'){
            push @error_messages, 'Column 3 header must be "Xallele" in the marker Info File.';
        }
        if ($alt_header ne 'Yallele'){
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
            my $facility_snp_id = $marker_line_info[0];
            $facility_snp_id =~ s/^\s+|\s+$//g;
            my $customer_snp_id = $marker_line_info[1];
            $customer_snp_id =~ s/^\s+|\s+$//g;
            my $Xallele = $marker_line_info[2];
            $Xallele =~ s/^\s+|\s+$//g;
            my $Yallele = $marker_line_info[3];
            $Yallele =~ s/^\s+|\s+$//g;
            my $chrom = $marker_line_info[4];
            $chrom =~ s/^\s+|\s+$//g;

            if (!defined $facility_snp_id){
                push @error_messages, 'Facility snp id is required for all markers.';
            }
            if (!defined $customer_snp_id){
                push @error_messages, 'Customer snp id is required for all markers.';
            }
            if (!defined $Xallele){
                push @error_messages, 'X allele info is required for all markers.';
            }
            if (!defined $Yallele){
                push @error_messages, 'Y allele info is required for all markers.';
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

    my $csv = Text::CSV->new({ sep_char => ',' });
    my $F;

    my %seen_sample_ids;
    open($F, "<", $filename) || die "Can't open file $filename\n";

        my $header_row = <$F>;
        my @header_info;

        if ($csv->parse($header_row)) {
            @header_info = $csv->fields();
        }

        my $sample_id_header = $header_info[0];
        $sample_id_header =~ s/^\s+|\s+$//g;

        my $snp_id_header = $header_info[1];
        $snp_id_header =~ s/^\s+|\s+$//g;

        my $snpcall_header = $header_info[2];
        $SNPCall_header =~ s/^\s+|\s+$//g;

        my $Xvalue_header = $header_info[2];
        $SNPCall_header =~ s/^\s+|\s+$//g;

        my $Yvalue_header = $header_info[2];
        $SNPCall_header =~ s/^\s+|\s+$//g;

        if ($sample_id_header ne 'SampleID'){
            push @error_messages, 'Column 1 header must be "SampleID" in the KASP result File.';
        }

        if ($snp_id_header ne 'SNPID'){
            push @error_messages, 'Column 2 header must be "SNPID" in the KASP result File.';
        }

        if ($snpcall_header ne 'SNPCall'){
            push @error_messages, 'Column 3 header must be "SNPCall" in the KASP result File.';
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

            my $sample_id = $line_info[0];
            $sample_id =~ s/^\s+|\s+$//g;
            my $snp_id = $line_info[1];
            $snp_id =~ s/^\s+|\s+$//g;
            my $snpcall = $line_info[2];
            $snpcall =~ s/^\s+|\s+$//g;
            my $xvalue = $line_info[3];
            $xvalue =~ s/^\s+|\s+$//g;
            my $yvalue = $line_info[4];
            $yvalue =~ s/^\s+|\s+$//g;

            if (!defined $sample_id){
                push @error_messages, 'Sample id is required for all rows.';
            } else {
                $seen_sample_ids{$sample_id}++;
            }

            if (!defined $snp_id){
                push @error_messages, 'SNP id is required for all rows.';
            } elsif (!exists($marker_names{$snp_id})) {
                push @error_messages, "Marker $snp_id in the result file is not found in the marker info file.";
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

    my @all_sample_ids = keys %seen_sample_ids;
    my $sample_validator = CXGN::List::Validate->new();
    my @sample_missing = @{$sample_validator->validate($schema,$validate_type,\@all_sample_ids)->{'missing'}};

    if (scalar(@sample_missing) > 0) {
        push @error_messages, "The following sample ids are not in the database, or are not in the database as uniquenames: ".join(',',@sample_missing);
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
    my %marker_info_nonseparated;
    my @marker_info_keys = qw(name intertek_name chrom pos alt ref);

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

        while (my $marker_line = <$MF>) {
            my @marker_line_info;
            if ($marker_info_csv->parse($marker_line)) {
                @marker_line_info = $marker_info_csv->fields();
            }
            my $facility_snp_id = $marker_line_info[0];
            my $customer_snp_id = $marker_line_info[1];
            my $ref = $marker_line_info[2];
            my $alt = $marker_line_info[3];
            my $chromosome = $marker_line_info[4];
            my $position = $marker_line_info[5];
            my %marker = (
                ref => $ref,
                alt => $alt,
                intertek_name => $facility_snp_id,
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
    print STDERR "MARKER INFO =".Dumper(\%marker_info)."\n";








    return 1;
}

1;
