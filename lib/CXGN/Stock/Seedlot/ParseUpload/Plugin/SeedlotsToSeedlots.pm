package CXGN::Stock::Seedlot::ParseUpload::Plugin::SeedlotsToSeedlots;

use Moose::Role;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;
use CXGN::Stock::Seedlot;

sub _validate_with_plugin {
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

    my @error_messages;
    my %errors;
    my %missing_accessions;

    #try to open the excel file and report any errors
    my $excel_obj = $parser->parse($filename);
    if (!$excel_obj) {
        push @error_messages, $parser->error();
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    my $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
    if (!$worksheet) {
        push @error_messages, "Spreadsheet must be on 1st tab in Excel (.xls) file";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();
    if (($col_max - $col_min)  < 2 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of plot data
        push @error_messages, "Spreadsheet is missing header or contains no rows";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    my $from_seedlot_name_head;
    my $to_seedlot_name_head;
    my $amount_head;
    my $weight_head;
    my $operator_name_head;
    my $transaction_description_head;

    if ($worksheet->get_cell(0,0)) {
        $from_seedlot_name_head  = $worksheet->get_cell(0,0)->value();
        $from_seedlot_name_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,1)) {
        $to_seedlot_name_head  = $worksheet->get_cell(0,1)->value();
        $to_seedlot_name_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,2)) {
        $amount_head  = $worksheet->get_cell(0,2)->value();
        $amount_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,3)) {
        $weight_head  = $worksheet->get_cell(0,3)->value();
        $weight_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,4)) {
        $transaction_description_head  = $worksheet->get_cell(0,4)->value();
        $transaction_description_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,5)) {
        $operator_name_head  = $worksheet->get_cell(0,5)->value();
        $operator_name_head =~ s/^\s+|\s+$//g;
    }


    if (!$from_seedlot_name_head || $from_seedlot_name_head ne 'from_seedlot_name' ) {
        push @error_messages, "Cell A1: from_seedlot_name is missing from the header";
    }
    if (!$to_seedlot_name_head || $to_seedlot_name_head ne 'to_seedlot_name') {
        push @error_messages, "Cell B1: to_seedlot_name is missing from the header";
    }
    if (!$amount_head || $amount_head ne 'amount') {
        push @error_messages, "Cell C1: amount is missing from the header";
    }
    if (!$weight_head || $weight_head ne 'weight(g)') {
        push @error_messages, "Cell D1: weight(g) is missing from the header";
    }
    if (!$transaction_description_head || $transaction_description_head ne 'transaction_description') {
        push @error_messages, "Cell E1: transaction_description is missing from the header";
    }
    if (!$operator_name_head || $operator_name_head ne 'operator_name') {
        push @error_messages, "Cell F1: operator_name is missing from the header";
    }

    my %seen_seedlot_names;
    my @from_seedlot_to_seedlot_pair;
    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $from_seedlot_name;
        my $to_seedlot_name;
        my $amount = 'NA';
        my $weight = 'NA';
        my $transaction_description;
        my $operator_name;

        if ($worksheet->get_cell($row,0)) {
            $from_seedlot_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $to_seedlot_name = $worksheet->get_cell($row,1)->value();
        }
        if ($worksheet->get_cell($row,2)) {
            $amount =  $worksheet->get_cell($row,2)->value();
        }
        if ($worksheet->get_cell($row,3)) {
            $weight =  $worksheet->get_cell($row,3)->value();
        }
        if ($worksheet->get_cell($row,4)) {
            $transaction_description =  $worksheet->get_cell($row,4)->value();
        }
        if ($worksheet->get_cell($row,5)) {
            $operator_name = $worksheet->get_cell($row,5)->value();
        }


        if (!$from_seedlot_name || $from_seedlot_name eq '' ) {
            push @error_messages, "Cell A$row_name: from_seedlot_name missing.";
        } else {
            $from_seedlot_name =~ s/^\s+|\s+$//g;
            $seen_seedlot_names{$from_seedlot_name}++;
        }

        if (!$to_seedlot_name || $to_seedlot_name eq '') {
            push @error_messages, "Cell B:$row_name: to_seedlot_name missing.";
        } else {
            $to_seedlot_name =~ s/^\s+|\s+$//g;
            $seen_seedlot_names{$to_seedlot_name}++;
        }

        if (!defined($amount) || $amount eq '') {
            push @error_messages, "Cell D$row_name: amount missing";
        }
        if (!defined($weight) || $weight eq '') {
            push @error_messages, "Cell E$row_name: weight(g) missing";
        }
        if ($amount eq 'NA' && $weight eq 'NA') {
            push @error_messages, "On row:$row_name you must provide either a weight in grams or a seed count amount.";
        }

        if (!defined($operator_name) || $operator_name eq '') {
            push @error_messages, "Cell C$row_name: operator_name missing";
        }

        push @from_seedlot_to_seedlot_pair, {
            from_seedlot_name => $from_seedlot_name,
            to_seedlot_name => $to_seedlot_name
        }
    }

    my @seedlots = keys %seen_seedlot_names;
    my $seedlot_validator = CXGN::List::Validate->new();
    my @seedlots_missing = @{$seedlot_validator->validate($schema,'seedlots',\@seedlots)->{'missing'}};

    if (scalar(@seedlots_missing) > 0) {
        push @error_messages, "The following seedlots are not in the database: ".join(',',@seedlots_missing);
    }

    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();
    foreach my $each_pair(@from_seedlot_to_seedlot_pair){
        my $from_content_id;
        my $to_content_id;
        my $from_seedlot_name = $each_pair->{from_seedlot_name};
        my $from_seedlot_rs = $schema->resultset("Stock::Stock")->find({'uniquename' => $from_seedlot_name,'type_id' => $seedlot_cvterm_id});
        if ($from_seedlot_rs) {
            my $from_seedlot_id = $from_seedlot_rs->stock_id();
            my $from_seedlot_obj = CXGN::Stock::Seedlot->new(schema => $schema,seedlot_id => $from_seedlot_id);
            my $accessions = $from_seedlot_obj->accession();
            my $crosses = $from_seedlot_obj->cross();

            if ($accessions) {
                $from_content_id = $accessions->[0];
            }
            if ($crosses) {
                $from_content_id = $crosses->[0];
            }
        }

        my $to_seedlot_name = $each_pair->{to_seedlot_name};
        my $to_seedlot_rs = $schema->resultset("Stock::Stock")->find({'uniquename' => $to_seedlot_name,'type_id' => $seedlot_cvterm_id});
        if ($to_seedlot_rs) {
            my $to_seedlot_id = $to_seedlot_rs->stock_id();
            my $to_seedlot_obj = CXGN::Stock::Seedlot->new(schema => $schema,seedlot_id => $to_seedlot_id);
            my $accessions = $to_seedlot_obj->accession();
            my $crosses = $to_seedlot_obj->cross();

            if ($accessions) {
                $to_content_id = $accessions->[0];
            }
            if ($crosses) {
                $to_content_id = $crosses->[0];
            }
        }

        if ($from_content_id ne $to_content_id) {
            push @error_messages, "Error: from seedlot $from_seedlot_name and to seedlot $to_seedlot_name have different content.";
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
    my $schema = $self->get_chado_schema();
    my %parsed_data;

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
    my %parsed_seedlots;

    $excel_obj = $parser->parse($filename);
    if ( !$excel_obj ) {
        return;
    }

    $worksheet = ( $excel_obj->worksheets() )[0];
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();


    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();

    my @transactions;
    for my $row ( 1 .. $row_max ) {
        my $from_seedlot_name;
        my $to_seedlot_name;
        my $amount = 'NA';
        my $weight = 'NA';
        my $transaction_description;
        my $operator_name;

        if ($worksheet->get_cell($row,0)) {
            $from_seedlot_name = $worksheet->get_cell($row,0)->value();
            $from_seedlot_name =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,1)) {
            $to_seedlot_name = $worksheet->get_cell($row,1)->value();
            $to_seedlot_name =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,2)) {
            $amount =  $worksheet->get_cell($row,2)->value();
            $amount =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,3)) {
            $weight =  $worksheet->get_cell($row,3)->value();
            $weight =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,4)) {
            $transaction_description =  $worksheet->get_cell($row,4)->value();
        }
        if ($worksheet->get_cell($row,5)) {
            $operator_name =  $worksheet->get_cell($row,5)->value();
            $operator_name =~ s/^\s+|\s+$//g;
        }

        #skip blank lines
        if (!$to_seedlot_name && !$from_seedlot_name) {
            next;
        }

        my $from_seedlot_rs = $schema->resultset("Stock::Stock")->find({
            'uniquename' => $from_seedlot_name,
            'type_id' => $seedlot_cvterm_id,
        });
        my $from_seedlot_id = $from_seedlot_rs->stock_id();

        my $to_seedlot_rs = $schema->resultset("Stock::Stock")->find({
            'uniquename' => $to_seedlot_name,
            'type_id' => $seedlot_cvterm_id,
        });
        my $to_seedlot_id = $to_seedlot_rs->stock_id();

        push @transactions, {
            from_seedlot_name => $from_seedlot_name,
            from_seedlot_id => $from_seedlot_id,
            to_seedlot_name => $to_seedlot_name,
            to_seedlot_id => $to_seedlot_id,
            amount => $amount,
            weight => $weight,
            transaction_description => $transaction_description,
            operator => $operator_name
        }
    }
    #print STDERR Dumper \%parsed_seedlots;
    $parsed_data{transactions} = \@transactions;

    $self->_set_parsed_data(\%parsed_data);
    return 1;
}


1;
