package CXGN::Trial::ParseUpload::Plugin::SoilDataXLS;

use Moose::Role;
use Spreadsheet::ParseExcel;
use Data::Dumper;

sub _validate_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my @error_messages;
    my %errors;
    my $parser = Spreadsheet::ParseExcel->new();
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
    if (($col_max - $col_min)  < 1 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of soil data
        push @error_messages, "Spreadsheet is missing header or no soil data";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    #get column headers
    my $soil_data_type_header;
    my $soil_data_value_header;

    if ($worksheet->get_cell(0,0)) {
        $soil_data_type_header  = $worksheet->get_cell(0,0)->value();
    }

    if ($worksheet->get_cell(0,1)) {
        $soil_data_value_header  = $worksheet->get_cell(0,1)->value();
    }

    if (!$soil_data_type_header || $soil_data_type_header ne 'soil_data_type' ) {
        push @error_messages, "Cell A1: soil_data_type is missing from the header";
    }

    if (!$soil_data_value_header || $soil_data_value_header ne 'soil_data_value' ) {
        push @error_messages, "Cell A2: soil_data_value is missing from the header";
    }

    for my $row (1 .. $row_max){
        my $row_name = $row+1;
        my $data_type;
        my $data_value;

        if ($worksheet->get_cell($row,0)) {
            $data_type = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $data_value = $worksheet->get_cell($row,1)->value();
        }

        if (!$data_type || $data_type eq '') {
            push @error_messages, "Cell A$row_name: soil data type missing";
        }

#        if (!$data_value || $data_value eq '') {
#            push @error_messages, "Cell B$row_name: soil data value missing";
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
    my $parser   = Spreadsheet::ParseExcel->new();
    my $excel_obj;
    my $worksheet;

    $excel_obj = $parser->parse($filename);
    if (!$excel_obj){
        return;
    }

    $worksheet = ($excel_obj->worksheets())[0];
    my ($row_min, $row_max) = $worksheet->row_range();
    my ($col_min, $col_max) = $worksheet->col_range();

    my %soil_data_hash;
    my @data_type_order;

    for my $row (1 .. $row_max){
        my $soil_data_type;
        my $soil_data_value;

        if ($worksheet->get_cell($row,0)){
            $soil_data_type = $worksheet->get_cell($row,0)->value();
            $soil_data_type =~ s/^\s+|\s+$//g;
        }

        if ($worksheet->get_cell($row,1)){
            $soil_data_value = $worksheet->get_cell($row,1)->value();
            $soil_data_value =~ s/^\s+|\s+$//g;
        }

        $soil_data_hash{'soil_data_details'}{$soil_data_type} = $soil_data_value;
        push @data_type_order, $soil_data_type;
    }

    $soil_data_hash{'data_type_order'} = \@data_type_order;

    $self->_set_parsed_data(\%soil_data_hash);

    return 1;
}

1;
