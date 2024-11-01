package CXGN::Stock::Seedlot::ParseUpload::Plugin::SeedlotHarvestedXLS;

use Moose::Role;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;

#
# DEPRECATED: This plugin has been replaced by the SeedlotFromCrossGeneric plugin
#

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

    #get column headers
    my $seedlot_name_head;
    my $cross_name_head;
    my $operator_name_head;
    my $amount_head;
    my $weight_head;
    my $description_head;
    my $box_name_head;

    if ($worksheet->get_cell(0,0)) {
        $seedlot_name_head  = $worksheet->get_cell(0,0)->value();
        $seedlot_name_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,1)) {
        $cross_name_head  = $worksheet->get_cell(0,1)->value();
        $cross_name_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,2)) {
        $operator_name_head  = $worksheet->get_cell(0,2)->value();
        $operator_name_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,3)) {
        $amount_head  = $worksheet->get_cell(0,3)->value();
        $amount_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,4)) {
        $weight_head  = $worksheet->get_cell(0,4)->value();
        $weight_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,5)) {
        $description_head  = $worksheet->get_cell(0,5)->value();
        $description_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,6)) {
        $box_name_head  = $worksheet->get_cell(0,6)->value();
        $box_name_head =~ s/^\s+|\s+$//g;
    }

    if (!$seedlot_name_head || $seedlot_name_head ne 'seedlot_name' ) {
        push @error_messages, "Cell A1: seedlot_name is missing from the header";
    }
    if (!$cross_name_head || $cross_name_head ne 'cross_unique_id') {
        push @error_messages, "Cell B1: cross_unique_id is missing from the header";
    }
    if (!$operator_name_head || $operator_name_head ne 'operator_name') {
        push @error_messages, "Cell C1: operator_name is missing from the header";
    }
    if (!$amount_head || $amount_head ne 'amount') {
        push @error_messages, "Cell D1: amount is missing from the header";
    }
    if (!$weight_head || $weight_head ne 'weight(g)') {
        push @error_messages, "Cell E1: weight(g) is missing from the header";
    }
    if (!$description_head || $description_head ne 'description') {
        push @error_messages, "Cell F1: description is missing from the header";
    }
    if (!$box_name_head || $box_name_head ne 'box_name') {
        push @error_messages, "Cell G1: box_name is missing from the header";
    }

    my %seen_seedlot_names;
    my %seen_cross_names;
    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $seedlot_name;
        my $cross_name;
        my $operator_name;
        my $amount = 'NA';
        my $weight = 'NA';
        my $description;
        my $box_name;

        if ($worksheet->get_cell($row,0)) {
            $seedlot_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $cross_name = $worksheet->get_cell($row,1)->value();
        }
        if ($worksheet->get_cell($row,2)) {
            $operator_name = $worksheet->get_cell($row,2)->value();
        }
        if ($worksheet->get_cell($row,3)) {
            $amount =  $worksheet->get_cell($row,3)->value();
        }
        if ($worksheet->get_cell($row,4)) {
            $weight =  $worksheet->get_cell($row,4)->value();
        }
        if ($worksheet->get_cell($row,5)) {
            $description =  $worksheet->get_cell($row,5)->value();
        }
        if ($worksheet->get_cell($row,6)) {
            $box_name =  $worksheet->get_cell($row,6)->value();
        }

        if (!defined $seedlot_name && !defined $cross_name) {
            last;
        }

        if (!$seedlot_name || $seedlot_name eq '' ) {
            push @error_messages, "Cell A$row_name: seedlot_name missing.";
        }
        elsif ($seedlot_name =~ /\s/ || $seedlot_name =~ /\// || $seedlot_name =~ /\\/ ) {
            push @error_messages, "Cell A$row_name: seedlot_name must not contain spaces or slashes.";
        }
        else {
            $seedlot_name =~ s/^\s+|\s+$//g;
            #file must not contain duplicate plot names
            if ($seen_seedlot_names{$seedlot_name}) {
                push @error_messages, "Cell A$row_name: duplicate seedlot_name at cell A".$seen_seedlot_names{$seedlot_name}.": $seedlot_name";
            }
            $seen_seedlot_names{$seedlot_name}=$row_name;
        }

        if (!$cross_name || $cross_name eq '') {
            push @error_messages, "Cell B:$row_name: you must provide a cross_unique_id for the contents of the seedlot.";
        } else {
            $cross_name =~ s/^\s+|\s+$//g;
            $seen_cross_names{$cross_name}++;
        }

        if (!defined($operator_name) || $operator_name eq '') {
            push @error_messages, "Cell C$row_name: operator_name missing";
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
        if (!defined($box_name) || $box_name eq '') {
            push @error_messages, "Cell G$row_name: box_name missing";
        }
    }

    my @crosses = keys %seen_cross_names;
    my $cross_validator = CXGN::List::Validate->new();
    my @crosses_missing = @{$cross_validator->validate($schema,'crosses',\@crosses)->{'missing'}};

    if (scalar(@crosses_missing) > 0) {
        push @error_messages, "The following crosses are not in the database: ".join(',',@crosses_missing);
        $errors{'missing_crosses'} = \@crosses_missing;
    }

    # Check if Seedlot names already exist as other stock names
    my @seedlots = keys %seen_seedlot_names;
    my $rs = $schema->resultset("Stock::Stock")->search({
        'uniquename' => { -in => \@seedlots }
    });
    while (my $r=$rs->next) {
        if ( $r->type->name ne 'seedlot' ) {
            push @error_messages, "Cell A".$seen_seedlot_names{$r->uniquename}.": stock name already exists in database: ".$r->uniquename.".  The seedlot name must be unique.";
        }
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
    my %parsed_seedlots;

    $excel_obj = $parser->parse($filename);
    if ( !$excel_obj ) {
        return;
    }

    $worksheet = ( $excel_obj->worksheets() )[0];
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();

    my %seen_cross_names;
    my %seen_seedlot_names;
    for my $row ( 1 .. $row_max ) {
        my $seedlot_name;
        my $cross_name;
        if ($worksheet->get_cell($row,0)) {
            $seedlot_name = $worksheet->get_cell($row,0)->value();
            $seedlot_name =~ s/^\s+|\s+$//g;
            $seen_seedlot_names{$seedlot_name}++;
        }
        if ($worksheet->get_cell($row,1)) {
            $cross_name = $worksheet->get_cell($row,1)->value();
            $cross_name =~ s/^\s+|\s+$//g;
            $seen_cross_names{$cross_name}++;
        }

        if (!defined $seedlot_name && !defined $cross_name) {
            last;
        }

    }
    my $cross_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();
    my $seedlot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();

    my @crosses = keys %seen_cross_names;
    my $cross_rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => \@crosses },
        'type_id' => $cross_cvterm_id
    });
    my %cross_lookup;
    while (my $r=$cross_rs->next){
        $cross_lookup{$r->uniquename} = $r->stock_id;
    }
    my @seedlots = keys %seen_seedlot_names;
    my $seedlot_rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => \@seedlots },
        'type_id' => $seedlot_cvterm_id
    });
    my %seedlot_lookup;
    while (my $r=$seedlot_rs->next){
        $seedlot_lookup{$r->uniquename} = $r->stock_id;
    }

    for my $row ( 1 .. $row_max ) {
        my $seedlot_name;
        my $cross_name;
        my $operator_name;
        my $amount = 'NA';
        my $weight = 'NA';
        my $description;
        my $box_name;

        if ($worksheet->get_cell($row,0)) {
            $seedlot_name = $worksheet->get_cell($row,0)->value();
            $seedlot_name =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,1)) {
            $cross_name = $worksheet->get_cell($row,1)->value();
            $cross_name =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,2)) {
            $operator_name =  $worksheet->get_cell($row,2)->value();
            $operator_name =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,3)) {
            $amount =  $worksheet->get_cell($row,3)->value();
            $amount =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,4)) {
            $weight =  $worksheet->get_cell($row,4)->value();
            $weight =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,5)) {
            $description =  $worksheet->get_cell($row,5)->value();
        }
        if ($worksheet->get_cell($row,6)) {
            $box_name =  $worksheet->get_cell($row,6)->value();
            $box_name =~ s/^\s+|\s+$//g;
        }

        if (!defined $seedlot_name && !defined $cross_name) {
            last;
        }


        $parsed_seedlots{$seedlot_name} = {
            seedlot_id => $seedlot_lookup{$seedlot_name}, #If seedlot name already exists, this will allow us to update information for the seedlot
            accession => undef,
            accession_stock_id => undef,
            cross_name => $cross_name,
            cross_stock_id => $cross_lookup{$cross_name},
            amount => $amount,
            weight_gram => $weight,
            description => $description,
            box_name => $box_name,
            operator_name => $operator_name
        };
    }
    #print STDERR Dumper \%parsed_seedlots;

    $self->_set_parsed_data(\%parsed_seedlots);
    return 1;
}


1;
