package CXGN::Pedigree::ParseUpload::Plugin::TargetNumbersExcel;

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
    if (($col_max - $col_min)  < 1 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of target number info
        push @error_messages, "Spreadsheet is missing header or no target number data";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    #get column headers
    my $female_accession_head;
    my $male_accession_head;
    my $seed_target_number_head;
    my $progeny_target_number_head;
    my $note_head;

    if ($worksheet->get_cell(0,0)) {
        $female_accession_head  = $worksheet->get_cell(0,0)->value();
    }

    if ($worksheet->get_cell(0,1)) {
        $male_accession_head  = $worksheet->get_cell(0,1)->value();
    }

    if ($worksheet->get_cell(0,2)) {
        $seed_target_number_head  = $worksheet->get_cell(0,2)->value();
    }

    if ($worksheet->get_cell(0,3)) {
        $progeny_target_number_head  = $worksheet->get_cell(0,3)->value();
    }

    if ($worksheet->get_cell(0,4)) {
        $note_head  = $worksheet->get_cell(0,4)->value();
    }


    if (!$female_accession_head || $female_accession_head ne 'female_accession' ) {
        push @error_messages, "Cell A1: female_accession is missing from the header";
    }

    if (!$male_accession_head || $male_accession_head ne 'male_accession' ) {
        push @error_messages, "Cell A2: male_accession is missing from the header";
    }

    if (!$seed_target_number_head || $seed_target_number_head ne 'seed_target_number' ) {
        push @error_messages, "Cell A3: seed_target_number is missing from the header";
    }

    if (!$progeny_target_number_head || $progeny_target_number_head ne 'progeny_target_number' ) {
        push @error_messages, "Cell A4: progeny_target_number is missing from the header";
    }

    if (!$note_head || $note_head ne 'notes' ) {
        push @error_messages, "Cell A5: notes is missing from the header";
    }


    my %seen_female_accessions;
    my %seen_male_accessions;

    for my $row (1 .. $row_max){
        my $row_name = $row+1;
        my $female_accession;
        my $male_accession;
        my $seed_target_number;
        my $progeny_target_number;

        if ($worksheet->get_cell($row,0)) {
            $female_accession = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $male_accession = $worksheet->get_cell($row,1)->value();
        }
        if ($worksheet->get_cell($row,2)) {
            $seed_target_number = $worksheet->get_cell($row,2)->value();
        }
        if ($worksheet->get_cell($row,3)) {
            $progeny_target_number = $worksheet->get_cell($row,3)->value();
        }

        if (!$female_accession || $female_accession eq '') {
            push @error_messages, "Cell A$row_name: female accession missing";
        } else {
            $female_accession =~ s/^\s+|\s+$//g;
            $seen_female_accessions{$female_accession}++;
        }

        if (!$male_accession || $male_accession eq '') {
            push @error_messages, "Cell B$row_name: male accession missing";
        } else {
            $male_accession =~ s/^\s+|\s+$//g;
            $seen_male_accessions{$male_accession}++;
        }

        if ((!$seed_target_number || $seed_target_number eq '') && (!$progeny_target_number || $progeny_target_number eq '')) {
            push @error_messages, "Cell C/D$row_name: should have seed target number and/or progeny target number";
        }
    }


#    my @female_accessions = keys %seen_female_accessions;
#    my $female_accession_validator = CXGN::List::Validate->new();
#    my @female_accession_missing = @{$female_accession_validator->validate($schema,'uniquename',\@female_accessions)->{'missing'}};

#    if (scalar(@female_accession_missing) > 0){
#        push @error_messages, "The following female accessions are not in the database as uniquenames : ".join(',',@female_accession_missing);
#    }

#    my @male_accessions = keys %seen_male_accessions;
#    my $male_accession_validator = CXGN::List::Validate->new();
#    my @male_accession_missing = @{$male_accession_validator->validate($schema,'uniquename',\@male_accessions)->{'missing'}};

#    if (scalar(@male_accession_missing) > 0){
#        push @error_messages, "The following male accessions are not in the database as uniquenames : ".join(',',@male_accession_missing);
#    }


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

    my %target_number_info;

    for my $row (1 .. $row_max){
        my $female_accession;
        my $male_accession;
        my $seed_target_number;
        my $progeny_target_number;
        my $notes;

        if ($worksheet->get_cell($row,0)){
            $female_accession = $worksheet->get_cell($row,0)->value();
            $female_accession =~ s/^\s+|\s+$//g;
        }

        if ($worksheet->get_cell($row,1)){
            $male_accession = $worksheet->get_cell($row,1)->value();
            $male_accession =~ s/^\s+|\s+$//g;
        }

        if ($worksheet->get_cell($row,2)){
            $seed_target_number = $worksheet->get_cell($row,2)->value();
            $seed_target_number =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,3)){
            $progeny_target_number = $worksheet->get_cell($row,3)->value();
            $progeny_target_number =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,4)){
            $notes = $worksheet->get_cell($row,4)->value();
        }


        $target_number_info{$female_accession}{$male_accession}{'target_number_of_seeds'} = $seed_target_number;
        $target_number_info{$female_accession}{$male_accession}{'target_number_of_progenies'} = $progeny_target_number;
        $target_number_info{$female_accession}{$male_accession}{'notes'} = $notes;

    }

    $self->_set_parsed_data(\%target_number_info);

    return 1;
}

1;
