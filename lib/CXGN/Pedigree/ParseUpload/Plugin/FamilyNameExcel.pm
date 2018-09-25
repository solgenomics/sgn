package CXGN::Pedigree::ParseUpload::Plugin::FamilyNameExcel;

use Moose::Role;
use Spreadsheet::ParseExcel;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;

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
    if (($col_max - $col_min)  < 1 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of family name
        push @error_messages, "Spreadsheet is missing header or no family name data";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    #get column headers
    my $cross_name_head;

    if ($worksheet->get_cell(0,0)) {
        $cross_name_head  = $worksheet->get_cell(0,0)->value();
    }

    if (!$cross_name_head || $cross_name_head ne 'cross_name' ) {
        push @error_messages, "Cell A1: cross_name is missing from the header";
    }

    my %seen_cross_names;

    for my $row (1 .. $row_max){
        my $row_name = $row+1;
        my $cross_name;
        my $family_name;

        if ($worksheet->get_cell($row,0)) {
            $cross_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $family_name = $worksheet->get_cell($row,1)->value();
        }

        if (!$cross_name || $cross_name eq '') {
            push @error_messages, "Cell A$row_name: cross name missing";
        } else {
            $seen_cross_names{$cross_name}++;
        }

        if (!$family_name || $family_name eq '') {
            push @error_messages, "Cell B$row_name: family name missing";
        }
    }


    my @crosses = keys %seen_cross_names;
    my $cross_validator = CXGN::List::Validate->new();
    my @crosses_missing = @{$cross_validator->validate($schema,'crosses',\@crosses)->{'missing'}};

    if (scalar(@crosses_missing) > 0){
        push @error_messages, "The following crosses are not in the database as uniquenames or synonyms: ".join(',',@crosses_missing);
        $errors{'missing_crosses'} = \@crosses_missing;
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

    my %cross_family_name;

    for my $row (1 .. $row_max){
        my $cross_name;
        my $family_name;

        if ($worksheet->get_cell($row,0)){
            $cross_name = $worksheet->get_cell($row,0)->value();
        }

        if ($worksheet->get_cell($row,1)){
            $family_name = $worksheet->get_cell($row,1)->value();
        }

        #skip blank lines or lines with no cross name
        if (!$cross_name) {
            next;
        }

        $cross_family_name{$cross_name} = $family_name;

    }

    $self->_set_parsed_data(\%cross_family_name);

    return 1;
}

1;
