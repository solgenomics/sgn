package CXGN::Pedigree::ParseUpload::Plugin::CIPcross;

use Moose::Role;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
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
    my %supported_cross_types;

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
    if ( !$excel_obj ) {
        push @error_messages,  $parser->error();
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
    if (!$worksheet) {
        push @error_messages, "Spreadsheet must be on 1st tab in Excel (.xls) file";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();
    if (($col_max - $col_min)  < 4 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of crosses
        push @error_messages, "Spreadsheet is missing header or contains no row";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    my $inventory_id_head;
    my $female_accession_number_head;
    my $male_accession_number_head;

    if ($worksheet->get_cell(0,0)) {
        $inventory_id_head  = $worksheet->get_cell(0,0)->value();
        $inventory_id_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,6)) {
        $female_accession_number_head  = $worksheet->get_cell(0,6)->value();
        $female_accession_number_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,10)) {
        $male_accession_number_head  = $worksheet->get_cell(0,10)->value();
        $male_accession_number_head =~ s/^\s+|\s+$//g;
    }

    if (!$inventory_id_head || $inventory_id_head ne 'Inventory ID' ) {
        push @error_messages, "Cell A1: Inventory ID is missing from the header";
    }
    if (!$female_accession_number_head || $female_accession_number_head ne 'Female Accession Number') {
        push @error_messages, "Cell G1: Female Accession Number is missing from the header";
    }
    if (!$male_accession_number_head || $male_accession_number_head ne 'Male Accession Number') {
        push @error_messages, "Cell K1: Male Accession Number is missing from the header";
    }

    my %seen_inventory_ids;
    my %seen_accession_names;

    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $inventory_id;
        my $female_accession_number;
        my $male_accession_number;

        if ($worksheet->get_cell($row,0)) {
            $inventory_id = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,6)) {
            $female_accession_number =  $worksheet->get_cell($row,6)->value();
            $female_accession_number =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,10)) {
            $male_accession_number = $worksheet->get_cell($row,10)->value();
            $male_accession_number =~ s/^\s+|\s+$//g;
        }

        if (!$inventory_id || $inventory_id eq '') {
            push @error_messages, "Cell A$row_name: Inventory ID missing";
        } else {
            $inventory_id =~ s/^\s+|\s+$//g;
        }

        if ($seen_inventory_id{$inventory_id}) {
            push @error_messages, "Cell A$row_name: duplicate Inventory ID: $inventory_id";
        }

        if (!$female_accession_number || $female_accession_number eq '') {
            push @error_messages, "Cell G$row_name: Female Accession Number missing";
        } else {
            $female_accession_number =~ s/^\s+|\s+$//g;
            $seen_accession_names{$female_accession_number}++;
        }

        if (!$male_accession_number || $male_accession_number eq '') {
            push @error_messages, "Cell K$row_name: Male Accession Number missing";
        } else {
            $male_accession_number =~ s/^\s+|\s+$//g;
            $seen_accession_names{$male_accession_number}++;
        }

    }

    my @accessions = keys %seen_accession_names;
    my $accession_validator = CXGN::List::Validate->new();
    my @accessions_missing = @{$accession_validator->validate($schema,'uniquenames',\@accessions)->{'missing'}};

    if (scalar(@accessions_missing) > 0) {
        push @error_messages, "The following parents are not in the database, or are not in the database as uniquenames: ".join(',',@accessions_missing);
    }

    my @all_inventory_ids = keys %seen_inventory_ids;
    my $inventory_rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => \@all_inventory_ids }
    });
    while (my $r=$inventory_rs->next){
        push @error_messages, "Inventory ID already exists in database: ".$r->uniquename;
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
    my @pedigrees;
    my %parsed_result;

    $excel_obj = $parser->parse($filename);
    if ( !$excel_obj ) {
        return;
    }

    $worksheet = ( $excel_obj->worksheets() )[0];
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();

    for my $row ( 1 .. $row_max ) {
        my $inventory_id;
        my $female_accession_number;
        my $male_accession_number;

        if ($worksheet->get_cell($row,0)) {
            $inventory_id = $worksheet->get_cell($row,0)->value();
            $inventory_id =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,6)) {
            $female_accession_number =  $worksheet->get_cell($row,6)->value();
            $female_accession_number =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,10)) {
            $male_accession_number = $worksheet->get_cell($row,10)->value();
            $male_accession_number =~ s/^\s+|\s+$//g;
        }

        my $pedigree =  Bio::GeneticRelationships::Pedigree->new(name=>$inventory_id, cross_type=>'biparental');
        if ($female_accession_number) {
            my $female_parent = Bio::GeneticRelationships::Individual->new(name => $female_accession_number);
            $pedigree->set_female_parent($female_parent);
        }
        if ($male_accession_number) {
            my $male_parent = Bio::GeneticRelationships::Individual->new(name => $male_accession_number);
            $pedigree->set_male_parent($male_parent);
        }

        push @pedigrees, $pedigree;

    }

    $parsed_result{'crosses'} = \@pedigrees;

    $self->_set_parsed_data(\%parsed_result);

    return 1;

}




1;
