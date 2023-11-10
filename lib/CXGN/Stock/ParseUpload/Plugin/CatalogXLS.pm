package CXGN::Stock::ParseUpload::Plugin::CatalogXLS;

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
    my %supported_types;
    my %supported_categories;
    my %supported_material_sources;
    my %supported_material_types;

    $supported_categories{'released variety'} = 1;
    $supported_categories{'pathogen assay'} = 1;
    $supported_categories{'control'} = 1;
    $supported_categories{'transgenic line'} = 1;


#    $supported_material_sources{'OrderingSystemTest'} = 1;
#    $supported_material_sources{'Sendusu'} = 1;

#    $supported_availability{'in stock'} = 1;
#    $supported_availability{'out of stock'} = 1;
#    $supported_availability{'available in 3 months'} = 1;

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
    if (($col_max - $col_min)  < 5 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of info
        push @error_messages, "Spreadsheet is missing header or no catalog info";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    #get column headers
    my $item_name_header;
    my $category_header;
    my $additional_info_header;
    my $material_source_header;
    my $breeding_program_header;
    my $contact_person_header;

    if ($worksheet->get_cell(0,0)) {
        $item_name_header  = $worksheet->get_cell(0,0)->value();
        $item_name_header =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,1)) {
        $category_header  = $worksheet->get_cell(0,1)->value();
        $category_header =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,2)) {
        $additional_info_header  = $worksheet->get_cell(0,2)->value();
        $additional_info_header =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,3)) {
        $material_source_header  = $worksheet->get_cell(0,3)->value();
        $material_source_header =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,4)) {
        $breeding_program_header  = $worksheet->get_cell(0,4)->value();
        $breeding_program_header =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,5)) {
        $contact_person_header  = $worksheet->get_cell(0,5)->value();
        $contact_person_header =~ s/^\s+|\s+$//g;
    }

    if (!$item_name_header || $item_name_header ne 'item_name' ) {
        push @error_messages, "Cell A1: item_name is missing from the header";
    }
    if (!$category_header || $category_header ne 'category') {
        push @error_messages, "Cell B1: category is missing from the header";
    }
    if (!$additional_info_header || $additional_info_header ne 'additional_info') {
        push @error_messages, "Cell C1: additional_info is missing from the header";
    }
    if (!$material_source_header || $material_source_header ne 'material_source') {
        push @error_messages, "Cell D1: material_source is missing from the header";
    }
    if (!$breeding_program_header || $breeding_program_header ne 'breeding_program') {
        push @error_messages, "Cell E1: breeding_program is missing from the header";
    }
    if (!$contact_person_header || $contact_person_header ne 'contact_person_username') {
        push @error_messages, "Cell F1: contact_person_username is missing from the header";
    }

    my %seen_stock_names;
    my %seen_program_names;

    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $item_name;
        my $category;
        my $additional_info;
        my $material_source;
        my $breeding_program;
        my $contact_person_username;

        if ($worksheet->get_cell($row,0)) {
            $item_name = $worksheet->get_cell($row,0)->value();
            $item_name =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,1)) {
            $category = $worksheet->get_cell($row,1)->value();
            $category =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,2)) {
            $additional_info =  $worksheet->get_cell($row,2)->value();
        }
        if ($worksheet->get_cell($row,3)) {
            $material_source =  $worksheet->get_cell($row,3)->value();
        }
        if ($worksheet->get_cell($row,4)) {
            $breeding_program =  $worksheet->get_cell($row,4)->value();
            $breeding_program =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,5)) {
            $contact_person_username =  $worksheet->get_cell($row,5)->value();
            $contact_person_username =~ s/^\s+|\s+$//g;
        }


        if (!$item_name || $item_name eq '') {
            push @error_messages, "Cell A$row_name: item_name missing";
        }

        if (!$category || $category eq '') {
            push @error_messages, "Cell B$row_name: category missing";
        } elsif (!$supported_categories{$category}) {
            push @error_messages, "Cell B$row_name: category is not supported: $category";
        }

        if (!$breeding_program || $breeding_program eq '') {
            push @error_messages, "Cell E$row_name: breeding_program missing";
        }

        if (!$contact_person_username || $contact_person_username eq '') {
            push @error_messages, "Cell F$row_name: contact person username missing";
        }

        my $sp_person_id = CXGN::People::Person->get_person_by_username($dbh, $contact_person_username);
        if (!$sp_person_id) {
            push @error_messages, "Cell H$row_name: contact person username is not in database";
        }

        if ($item_name){
            $seen_stock_names{$item_name}++;
        }

        if ($breeding_program){
            $seen_program_names{$breeding_program}++;
        }

    }

    my @catalog_items = keys %seen_stock_names;
    my $catalog_item_validator = CXGN::List::Validate->new();

    my @stocks_missing = @{$catalog_item_validator->validate($schema,'stocks',\@catalog_items)->{'missing'}};

    if (scalar(@stocks_missing) > 0){
        push @error_messages, "The following catalog items are not in the database: ".join(',',@stocks_missing);
    }

    my @breeding_programs = keys %seen_program_names;
    my $breeding_program_validator = CXGN::List::Validate->new();
    my @programs_missing = @{$breeding_program_validator->validate($schema,'breeding_programs',\@breeding_programs)->{'missing'}};

    if (scalar(@programs_missing) > 0){
        push @error_messages, "The following breeding programs are not in the database: ".join(',',@programs_missing);
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

    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $item_name;
        my $category;
        my $additional_info;
        my $material_source;
        my $breeding_program;
        my $contact_person_username;

        if ($worksheet->get_cell($row,0)) {
            $item_name = $worksheet->get_cell($row,0)->value();
            $item_name =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,1)) {
            $category = $worksheet->get_cell($row,1)->value();
            $category =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,2)) {
            $additional_info =  $worksheet->get_cell($row,2)->value();
            $additional_info =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,3)) {
            $material_source =  $worksheet->get_cell($row,3)->value();
            $material_source =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,4)) {
            $breeding_program =  $worksheet->get_cell($row,4)->value();
            $breeding_program =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,5)) {
            $contact_person_username =  $worksheet->get_cell($row,5)->value();
            $contact_person_username =~ s/^\s+|\s+$//g;
        }

        my $contact_person_id = CXGN::People::Person->get_person_by_username($dbh, $contact_person_username);

        my $program_rs = $schema->resultset('Project::Project')->find({name => $breeding_program});
        my $breeding_program_id = $program_rs->project_id();

        $parsed_result{$item_name} = {
            'category' => $category,
            'additional_info' => $additional_info,
            'material_source' => $material_source,
            'breeding_program' => $breeding_program_id,
            'contact_person_id' => $contact_person_id,
        }
    }

    $self->_set_parsed_data(\%parsed_result);

    return 1;
}

1;
