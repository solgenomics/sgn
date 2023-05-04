package CXGN::Genotype::ParseUpload::Plugin::SSRProtocolExcel;

use Moose::Role;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
use Data::Dumper;

sub _validate_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my @error_messages;
    my %errors;

    # Match a dot, extension .xls / .xlsx
    my ($extension) = $filename =~ /(\.[^.]+)$/;
    my $parser;

    if ($extension eq '.xlsx') {
        $parser = Spreadsheet::ParseXLSX->new();
    }
    else {
        $parser = Spreadsheet::ParseExcel->new();
    }

    my $excel_obj;
    my $worksheet;

    #try to open the excel file and report any errors
    $excel_obj = $parser->parse($filename);
    if (!$excel_obj){
        push @error_messages, $parser->error();
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    $worksheet = ($excel_obj->worksheets())[0]; #support only one worksheet
    if (!$worksheet){
        push @error_messages, "Spreadsheet must be on 1st tab in Excel (.xls) file";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    my ($row_min, $row_max) = $worksheet->row_range();
    my ($col_min, $col_max) = $worksheet->col_range();
    if (($col_max - $col_min)  < 7 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of marker info
        push @error_messages, "Spreadsheet is missing header or no marker info";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    #get column headers
    my $marker_name_header;
    my $forward_primer_header;
    my $reverse_primer_header;
    my $annealing_temperature_header;
    my $product_sizes_header;
    my $sequence_motif_header;
    my $sequence_source_header;
    my $linkage_group_header;

    if ($worksheet->get_cell(0,0)) {
        $marker_name_header  = $worksheet->get_cell(0,0)->value();
        $marker_name_header =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,1)) {
        $forward_primer_header  = $worksheet->get_cell(0,1)->value();
        $forward_primer_header =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,2)) {
        $reverse_primer_header  = $worksheet->get_cell(0,2)->value();
        $reverse_primer_header =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,3)) {
        $annealing_temperature_header  = $worksheet->get_cell(0,3)->value();
        $annealing_temperature_header =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,4)) {
        $product_sizes_header  = $worksheet->get_cell(0,4)->value();
        $product_sizes_header =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,5)) {
        $sequence_motif_header  = $worksheet->get_cell(0,5)->value();
        $sequence_motif_header =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,6)) {
        $sequence_source_header  = $worksheet->get_cell(0,6)->value();
        $sequence_source_header =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,7)) {
        $linkage_group_header  = $worksheet->get_cell(0,7)->value();
        $linkage_group_header =~ s/^\s+|\s+$//g;
    }


    if (!$marker_name_header || $marker_name_header ne 'marker_name' ) {
        push @error_messages, "Cell A1: marker_name is missing from the header";
    }
    if (!$forward_primer_header || $forward_primer_header ne 'forward_primer') {
        push @error_messages, "Cell B1: forward_primer is missing from the header";
    }
    if (!$reverse_primer_header || $reverse_primer_header ne 'reverse_primer') {
        push @error_messages, "Cell C1: reverse_primer is missing from the header";
    }
    if (!$annealing_temperature_header || $annealing_temperature_header ne 'annealing_temperature') {
        push @error_messages, "Cell D1: annealing_temperature is missing from the header";
    }
    if (!$product_sizes_header || $product_sizes_header ne 'product_sizes') {
        push @error_messages, "Cell E1: product_sizes is missing from the header";
    }
    if (!$sequence_motif_header || $sequence_motif_header ne 'sequence_motif') {
        push @error_messages, "Cell F1: sequence_motif is missing from the header";
    }
    if (!$sequence_source_header || $sequence_source_header ne 'sequence_source') {
        push @error_messages, "Cell G1: sequence_source is missing from the header";
    }
    if (!$linkage_group_header || $linkage_group_header ne 'linkage_group') {
        push @error_messages, "Cell H1: linkage_group is missing from the header";
    }

    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $marker_name;
        my $forward_primer;
        my $reverse_primer;
        my $annealing_temperature;
        my $product_sizes;
        my $sequence_motif;
        my $sequence_source;
        my $linkage_group;

        if ($worksheet->get_cell($row,0)) {
            $marker_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $forward_primer =  $worksheet->get_cell($row,1)->value();
        }
        if ($worksheet->get_cell($row,2)) {
            $reverse_primer = $worksheet->get_cell($row,2)->value();
        }
        if ($worksheet->get_cell($row,3)) {
            $annealing_temperature =  $worksheet->get_cell($row,3)->value();
        }
        if ($worksheet->get_cell($row,4)) {
            $product_sizes =  $worksheet->get_cell($row,4)->value();
        }
        if ($worksheet->get_cell($row,5)) {
            $sequence_motif =  $worksheet->get_cell($row,5)->value();
        }
        if ($worksheet->get_cell($row,6)) {
            $sequence_source =  $worksheet->get_cell($row,6)->value();
        }
        if ($worksheet->get_cell($row,7)) {
            $linkage_group =  $worksheet->get_cell($row,7)->value();
        }

        if (!$marker_name || $marker_name eq '') {
            push @error_messages, "Cell A$row_name: marker_name missing";
        }
        if (!$forward_primer || $forward_primer eq '') {
            push @error_messages, "Cell B$row_name: forward_primer missing";
        }
        if (!$reverse_primer || $reverse_primer eq '') {
            push @error_messages, "Cell C$row_name: reverse_primer missing";
        }
        if (!$annealing_temperature || $annealing_temperature eq '') {
            push @error_messages, "Cell D$row_name: annealing_temperature missing";
        }
        if (!$product_sizes || $product_sizes eq '') {
            push @error_messages, "Cell E$row_name: product_sizes missing";
        }
#        if (!$sequence_motif || $sequence_motif eq '') {
#            push @error_messages, "Cell F$row_name: sequence_motif missing";
#        }
#        if (!$sequence_source || $sequence_source eq '') {
#            push @error_messages, "Cell G$row_name: sequence_source missing";
#        }
#        if (!$linkage_group || $linkage_group eq '') {
#            push @error_messages, "Cell H$row_name: linkage_group missing";
#        }

    }

    #store any errors found in the parsed file to parse_errors accessor
    if (scalar(@error_messages) >= 1) {
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    return 1; #returns true if validation is passed

}

sub _parse_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();

    # Match a dot, extension .xls / .xlsx
    my ($extension) = $filename =~ /(\.[^.]+)$/;
    my $parser;

    if ($extension eq '.xlsx') {
        $parser = Spreadsheet::ParseXLSX->new();
    }
    else {
        $parser = Spreadsheet::ParseExcel->new();
    }

    my $excel_obj;
    my $worksheet;

    $excel_obj = $parser->parse($filename);
    if (!$excel_obj){
        return;
    }

    $worksheet = ($excel_obj->worksheets())[0];
    my ($row_min, $row_max) = $worksheet->row_range();
    my ($col_min, $col_max) = $worksheet->col_range();

    my %marker_info_hash;
    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $marker_name;
        my $forward_primer;
        my $reverse_primer;
        my $annealing_temperature;
        my $product_sizes;
        my $sequence_motif;
        my $sequence_source;
        my $linkage_group;

        if ($worksheet->get_cell($row,0)) {
            $marker_name = $worksheet->get_cell($row,0)->value();
            $marker_name =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,1)) {
            $forward_primer =  $worksheet->get_cell($row,1)->value();
            $forward_primer =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,2)) {
            $reverse_primer = $worksheet->get_cell($row,2)->value();
            $reverse_primer =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,3)) {
            $annealing_temperature =  $worksheet->get_cell($row,3)->value();
            $annealing_temperature =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,4)) {
            $product_sizes =  $worksheet->get_cell($row,4)->value();
            $product_sizes =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,5)) {
            $sequence_motif =  $worksheet->get_cell($row,5)->value();
            $sequence_motif =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,6)) {
            $sequence_source =  $worksheet->get_cell($row,6)->value();
            $sequence_source =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,7)) {
            $linkage_group =  $worksheet->get_cell($row,7)->value();
            $linkage_group =~ s/^\s+|\s+$//g;
        }


        $marker_info_hash{$marker_name}{'forward_primer'} = $forward_primer;
        $marker_info_hash{$marker_name}{'reverse_primer'} = $reverse_primer;
        $marker_info_hash{$marker_name}{'annealing_temperature'} = $annealing_temperature;
        $marker_info_hash{$marker_name}{'product_sizes'} = $product_sizes;
        $marker_info_hash{$marker_name}{'sequence_motif'} = $sequence_motif;
        $marker_info_hash{$marker_name}{'sequence_source'} = $sequence_source;
        $marker_info_hash{$marker_name}{'linkage_group'} = $linkage_group;

    }

    my $parsed_result = \%marker_info_hash;
#    print STDERR "DATA =".Dumper($parsed_result)."\n";

    $self->_set_parsed_data($parsed_result);

    return 1;

}

1;
