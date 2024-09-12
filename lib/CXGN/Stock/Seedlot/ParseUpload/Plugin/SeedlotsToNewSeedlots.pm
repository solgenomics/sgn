package CXGN::Stock::Seedlot::ParseUpload::Plugin::SeedlotsToNewSeedlots;

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
    if (($col_max - $col_min)  < 2 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of transaction data
        push @error_messages, "Spreadsheet is missing header or contains no rows";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    my $from_seedlot_name_head;
    my $amount_head;
    my $weight_head;
    my $operator_name_head;
    my $transaction_description_head;
    my $to_new_seedlot_name_head;
    my $new_seedlot_box_name_head;
    my $new_seedlot_description_head;
    my $new_seedlot_quality_head;


    if ($worksheet->get_cell(0,0)) {
        $from_seedlot_name_head  = $worksheet->get_cell(0,0)->value();
        $from_seedlot_name_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,1)) {
        $amount_head  = $worksheet->get_cell(0,1)->value();
        $amount_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,2)) {
        $weight_head  = $worksheet->get_cell(0,2)->value();
        $weight_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,3)) {
        $operator_name_head  = $worksheet->get_cell(0,3)->value();
        $operator_name_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,4)) {
        $transaction_description_head  = $worksheet->get_cell(0,4)->value();
        $transaction_description_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,5)) {
        $to_new_seedlot_name_head  = $worksheet->get_cell(0,5)->value();
        $to_new_seedlot_name_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,6)) {
        $new_seedlot_box_name_head  = $worksheet->get_cell(0,6)->value();
        $new_seedlot_box_name_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,7)) {
        $new_seedlot_description_head  = $worksheet->get_cell(0,7)->value();
        $new_seedlot_description_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,8)) {
        $new_seedlot_quality_head  = $worksheet->get_cell(0,8)->value();
        $new_seedlot_quality_head =~ s/^\s+|\s+$//g;
    }


    if (!$from_seedlot_name_head || $from_seedlot_name_head ne 'from_seedlot_name' ) {
        push @error_messages, "Cell A1: from_seedlot_name is missing from the header";
    }
    if (!$amount_head || $amount_head ne 'amount') {
        push @error_messages, "Cell B1: amount is missing from the header";
    }
    if (!$weight_head || $weight_head ne 'weight(g)') {
        push @error_messages, "Cell C1: weight(g) is missing from the header";
    }
    if (!$operator_name_head || $operator_name_head ne 'operator_name') {
        push @error_messages, "Cell D1: operator_name is missing from the header";
    }
    if (!$transaction_description_head || $transaction_description_head ne 'transaction_description') {
        push @error_messages, "Cell E1: transaction_description is missing from the header";
    }
    if (!$to_new_seedlot_name_head || $to_new_seedlot_name_head ne 'to_new_seedlot_name') {
        push @error_messages, "Cell F1: to_new_seedlot_name is missing from the header";
    }
    if (!$new_seedlot_box_name_head || $new_seedlot_box_name_head ne 'new_seedlot_box_name') {
        push @error_messages, "Cell G1: new_seedlot_box_name is missing from the header";
    }
    if (!$new_seedlot_description_head || $new_seedlot_description_head ne 'new_seedlot_description') {
        push @error_messages, "Cell H1: new_seedlot_description is missing from the header";
    }
    if (!$new_seedlot_quality_head || $new_seedlot_quality_head ne 'new_seedlot_quality') {
        push @error_messages, "Cell I1: new_seedlot_quality is missing from the header";
    }

    my %seen_seedlot_names;
    my %seen_new_seedlot_names;
    my %check_new_seedlot_content;
    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $from_seedlot_name;
        my $amount = 'NA';
        my $weight = 'NA';
        my $operator_name;
        my $transaction_description;
        my $to_new_seedlot_name;
        my $new_seedlot_box_name;
        my $new_seedlot_description;

        if ($worksheet->get_cell($row,0)) {
            $from_seedlot_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $amount =  $worksheet->get_cell($row,1)->value();
        }
        if ($worksheet->get_cell($row,2)) {
            $weight =  $worksheet->get_cell($row,2)->value();
        }
        if ($worksheet->get_cell($row,3)) {
            $operator_name = $worksheet->get_cell($row,3)->value();
        }
        if ($worksheet->get_cell($row,5)) {
            $to_new_seedlot_name = $worksheet->get_cell($row,5)->value();
        }
        if ($worksheet->get_cell($row,6)) {
            $new_seedlot_box_name = $worksheet->get_cell($row,6)->value();
        }

        if (!defined $from_seedlot_name && !defined $to_new_seedlot_name) {
            last;
        }

        if (!$from_seedlot_name || $from_seedlot_name eq '' ) {
            push @error_messages, "Cell A$row_name: from_seedlot_name missing.";
        } else {
            $from_seedlot_name =~ s/^\s+|\s+$//g;
            $seen_seedlot_names{$from_seedlot_name}++;
        }

        if (!defined($amount) || $amount eq '') {
            push @error_messages, "Cell B$row_name: amount missing";
        }

        if (!defined($weight) || $weight eq '') {
            push @error_messages, "Cell C$row_name: weight(g) missing";
        }
        if ($amount eq 'NA' && $weight eq 'NA') {
            push @error_messages, "On row:$row_name you must provide either a weight in grams or a seed count amount.";
        }

        if (!defined($operator_name) || $operator_name eq '') {
            push @error_messages, "Cell D$row_name: operator_name missing";
        }

        if (!$to_new_seedlot_name || $to_new_seedlot_name eq '') {
            push @error_messages, "Cell F:$row_name: to_new_seedlot_name missing.";
        } else {
            $to_new_seedlot_name =~ s/^\s+|\s+$//g;
            $seen_new_seedlot_names{$to_new_seedlot_name}++;
        }

        if (!defined($new_seedlot_box_name) || $new_seedlot_box_name eq '') {
            push @error_messages, "Cell G$row_name: new_seedlot_box_name missing";
        }

        if (defined $from_seedlot_name && defined $to_new_seedlot_name) {
            $check_new_seedlot_content{$to_new_seedlot_name}{$from_seedlot_name}++;
        }
    }

    my @existing_seedlots = keys %seen_seedlot_names;
    my $existing_seedlot_validator = CXGN::List::Validate->new();
    my $validation = $existing_seedlot_validator->validate($schema,'seedlots',\@existing_seedlots);
    my @all_seedlots_missing = @{$validation->{missing}};
    my @seedlots_discarded = @{$validation->{discarded}};
    my @seedlots_missing;
    foreach my $seedlot (@all_seedlots_missing) {
        if ($seedlot ~~ @seedlots_discarded) {
            next;
        } else {
            push @seedlots_missing, $seedlot;
        }
    }

    if (scalar(@seedlots_missing) > 0) {
        push @error_messages, "The following seedlots are not in the database: ".join(',',@seedlots_missing);
    }

    if (scalar(@seedlots_discarded) > 0) {
        push @error_messages, "The following seedlots are marked as DISCARDED: ".join(',',@seedlots_discarded);
    }

    my @new_seedlots = keys %seen_new_seedlot_names;
    my $seedlot_rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => \@new_seedlots }
    });

    while (my $seedlot_r=$seedlot_rs->next){
        push @error_messages, "New seedlot name already exists in database: ".$seedlot_r->uniquename;
    }

    foreach my $new_sl (keys %check_new_seedlot_content){
        my @check_info = ();
        my $stored_seedlots = $check_new_seedlot_content{$new_sl};
        my $number_of_associated_seedlots = keys %{$stored_seedlots};
        if ($number_of_associated_seedlots > 1) {
            my $content_error = CXGN::Stock::Seedlot->verify_all_seedlots_compatibility($schema, [$new_sl, $check_new_seedlot_content{$new_sl}]);
            if (exists($content_error->{error})){
                push @error_messages, $content_error->{error};
            }
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
    my @new_seedlots;
    for my $row ( 1 .. $row_max ) {
        my $from_seedlot_name;
        my $amount = 'NA';
        my $weight = 'NA';
        my $operator_name;
        my $transaction_description;
        my $to_new_seedlot_name;
        my $new_seedlot_box_name;
        my $new_seedlot_description;
        my $new_seedlot_quality;

        if ($worksheet->get_cell($row,0)) {
            $from_seedlot_name = $worksheet->get_cell($row,0)->value();
            $from_seedlot_name =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,1)) {
            $amount =  $worksheet->get_cell($row,1)->value();
            $amount =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,2)) {
            $weight =  $worksheet->get_cell($row,2)->value();
            $weight =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,3)) {
            $operator_name =  $worksheet->get_cell($row,3)->value();
            $operator_name =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,4)) {
            $transaction_description =  $worksheet->get_cell($row,4)->value();
        }
        if ($worksheet->get_cell($row,5)) {
            $to_new_seedlot_name = $worksheet->get_cell($row,5)->value();
            $to_new_seedlot_name =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,6)) {
            $new_seedlot_box_name = $worksheet->get_cell($row,6)->value();
        }
        if ($worksheet->get_cell($row,7)) {
            $new_seedlot_description = $worksheet->get_cell($row,7)->value();
        }
        if ($worksheet->get_cell($row,8)) {
            $new_seedlot_quality = $worksheet->get_cell($row,8)->value();
        }

        if (!defined $to_new_seedlot_name && !defined $from_seedlot_name) {
            last;
        }

        my $from_seedlot_rs = $schema->resultset("Stock::Stock")->find({
            'uniquename' => $from_seedlot_name,
            'type_id' => $seedlot_cvterm_id,
        });
        my $from_seedlot_id = $from_seedlot_rs->stock_id();
        my $content_id = CXGN::Stock::Seedlot->get_content_id($schema, $from_seedlot_id);

        push @transactions, {
            from_seedlot_name => $from_seedlot_name,
            from_seedlot_id => $from_seedlot_id,
            to_new_seedlot_name => $to_new_seedlot_name,
            amount => $amount,
            weight => $weight,
            transaction_description => $transaction_description,
            operator => $operator_name,
            new_seedlot_info => [$to_new_seedlot_name, $content_id, $new_seedlot_description, $new_seedlot_box_name, $new_seedlot_quality]
        }
    }
    #print STDERR Dumper \%parsed_seedlots;
    $parsed_data{transactions} = \@transactions;

    $self->_set_parsed_data(\%parsed_data);
    return 1;
}


1;
