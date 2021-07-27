package CXGN::Pedigree::ParseUpload::Plugin::WishlistExcel;

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
    my $parser   = Spreadsheet::ParseExcel->new();
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
    if (($col_max - $col_min)  < 1 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of cross combination
        push @error_messages, "Spreadsheet is missing header or no cross combination data";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    #get column headers
    my $female_accession_head;
    my $male_accession_head;
    my $priority_head;

    if ($worksheet->get_cell(0,0)) {
        $female_accession_head  = $worksheet->get_cell(0,0)->value();
    }
    if ($worksheet->get_cell(0,1)) {
        $male_accession_head  = $worksheet->get_cell(0,1)->value();
    }
    if ($worksheet->get_cell(0,2)) {
        $priority_head  = $worksheet->get_cell(0,2)->value();
    }

    if (!$female_accession_head || $female_accession_head ne 'female_accession' ) {
        push @error_messages, "Cell A1: female_accession is missing from the header";
    }
    if (!$male_accession_head || $male_accession_head ne 'male_accession') {
        push @error_messages, "Cell B1: male_accession is missing from the header";
    }
    if (!$priority_head || $priority_head ne 'priority') {
        push @error_messages, "Cell C1: priority is missing from the header";
    }

    my %seen_accessions;
    for my $row (1 .. $row_max){
        my $row_name = $row+1;
        my $female_accession;
        my $male_accession;
        my $priority;

        if ($worksheet->get_cell($row,0)) {
            $female_accession = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $male_accession = $worksheet->get_cell($row,1)->value();
        }
        if ($worksheet->get_cell($row,2)) {
            $priority = $worksheet->get_cell($row,2)->value();
        }

        if (!$female_accession || $female_accession eq '') {
            push @error_messages, "Cell A$row_name: female accession missing";
        } else {
            $female_accession =~ s/^\s+|\s+$//g;
            $seen_accessions{$female_accession}++;
        }

        if (!$male_accession || $male_accession eq '') {
            push @error_messages, "Cell B$row_name: male accession missing";
        } else {
            $male_accession =~ s/^\s+|\s+$//g;
            $seen_accessions{$male_accession}++;
        }
    }

    my @accessions = keys %seen_accessions;
    my $accession_validator = CXGN::List::Validate->new();
    my @accessions_missing = @{$accession_validator->validate($schema,'uniquenames',\@accessions)->{'missing'}};

    if (scalar(@accessions_missing) > 0){
        push @error_messages, "The following accessions are not in the database or are not in the database as uniquenames: ".join(',',@accessions_missing);
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

    my @cross_combination_list;

    for my $row (1 .. $row_max){
        my $female_accession;
        my $male_accession;
        my $priority;
        my %cross_combination_hash = ();

        if ($worksheet->get_cell($row,0)){
            $female_accession = $worksheet->get_cell($row,0)->value();
            $female_accession =~ s/^\s+|\s+$//g;
            $cross_combination_hash{'female_id'} = $female_accession;

        }
        if ($worksheet->get_cell($row,1)){
            $male_accession = $worksheet->get_cell($row,1)->value();
            $male_accession =~ s/^\s+|\s+$//g;
            $cross_combination_hash{'male_id'} = $male_accession;
        }
        if ($worksheet->get_cell($row,2)){
            $priority = $worksheet->get_cell($row,2)->value();
            if (!$priority || $priority eq '') {
                $priority = '1';
            }
            $cross_combination_hash{'priority'} = $priority;
        }

        push @cross_combination_list, \%cross_combination_hash;
    }
#    print STDERR "CROSS COMBINATION LIST =".Dumper(\@cross_combination_list)."\n";
    my %parsed_result;
    $parsed_result{'wishlist'} = \@cross_combination_list;

    $self->_set_parsed_data(\%parsed_result);
    return 1;

}

1;
