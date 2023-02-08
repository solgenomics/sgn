package CXGN::Stock::ParseUpload::Plugin::TissueCultureInfoExcel;

use Moose::Role;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;
use CXGN::People::Person;

sub _validate_with_plugin {
    my $self = shift;
    my $filename = $self->get_filename();
    my $schema = $self->get_chado_schema();
    my $tissue_culture_properties = $self->get_editable_stock_props();


    my $dbh = $self->get_chado_schema()->storage()->dbh();

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
    if (($col_max - $col_min)  < 6 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of info
        push @error_messages, "Spreadsheet is missing header or no catalog info";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    #get column headers
    my $stock_name_header;
    my $tissue_culture_id_header;

    if ($worksheet->get_cell(0,0)) {
        $stock_name_header  = $worksheet->get_cell(0,0)->value();
        $stock_name_header =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,1)) {
        $tissue_culture_id_header  = $worksheet->get_cell(0,1)->value();
        $tissue_culture_id_header =~ s/^\s+|\s+$//g;
    }

    if (!$stock_name_header || $stock_name_header ne 'stock_name' ) {
        push @error_messages, "Cell A1: stock_name is missing from the header";
    }
    if (!$tissue_culture_id_header || $tissue_culture_id_header ne 'tissue_culture_id') {
        push @error_messages, "Cell B1: tissue_culture_id is missing from the header";
    }

    my %valid_properties;
    my @properties = @{$tissue_culture_properties};
    foreach my $property(@properties){
        $valid_properties{$property} = 1;
    }

    for my $column (2 .. $col_max){
        my $header_string = $worksheet->get_cell(0,$column)->value();
        $header_string =~ s/^\s+|\s+$//g;

        if (!$valid_properties{$header_string}){
            push @error_messages, "Invalid info type: $header_string";
        }
    }


    my %seen_stock_names;
    my %seen_tissue_culture_ids;

    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $stock_name;
        my $tissue_culture_id;

        if ($worksheet->get_cell($row,0)) {
            $item_name = $worksheet->get_cell($row,0)->value();
            $stock_name =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,1)) {
            $tissue_culture_id =  $worksheet->get_cell($row,1)->value();
            $tissue_culture_id =~ s/^\s+|\s+$//g;
        }

        if (!$stock_name || $stock_name eq '') {
            push @error_messages, "Cell A$row_name: item_name missing";
        }

        if (!$tissue_culture_id || $tissue_culture_id eq '') {
            push @error_messages, "Cell B$row_name: tissue_culture_id missing";
        }

        if ($stock_name){
            $seen_stock_names{$stock_name}++;
        }

        if ($tissue_culture_id){
            $seen_tissue_culture_ids{$tissue_culture_id}++;
        }

    }

    my @stock_names = keys %seen_stock_names;
    my $stock_validator = CXGN::List::Validate->new();

    my @stocks_missing = @{$stock_validator->validate($schema,'stocks',\@catalog_items)->{'missing'}};

    if (scalar(@stocks_missing) > 0){
        push @error_messages, "The following stock names are not in the database: ".join(',',@stocks_missing);
    }


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

    my $dbh = $self->get_chado_schema()->storage()->dbh();

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
    my %parsed_result;

    $excel_obj = $parser->parse($filename);
    if (!$excel_obj){
        return;
    }

    $worksheet = ($excel_obj->worksheets())[0];
    my ($row_min, $row_max) = $worksheet->row_range();
    my ($col_min, $col_max) = $worksheet->col_range();

    for my $row (1 .. $row_max){
        my $stock_name;
        my $tissue_culture_id;

        if ($worksheet->get_cell($row,0)){
            $stock_name = $worksheet->get_cell($row,0)->value();
            $stock_name =~ s/^\s+|\s+$//g;
        }

        if ($worksheet->get_cell($row,1)){
            $tissue_culture_id = $worksheet->get_cell($row,0)->value();
            $tissue_culture_id =~ s/^\s+|\s+$//g;
        }

        for my $column ( 2 .. $col_max ) {
            if ($worksheet->get_cell($row,$column)) {
                my $info_header =  $worksheet->get_cell(0,$column)->value();
                $info_header =~ s/^\s+|\s+$//g;
                $parsed_result{$stock_name}{$tissue_culture_id}{$info_header} = $worksheet->get_cell($row,$column)->value();
            }
        }
    }
    print STDERR "PARSED RESULT =".Dumper(\%parsed_result)."\n";

    $self->_set_parsed_data(\%parsed_result);

    return 1;
}

1;
