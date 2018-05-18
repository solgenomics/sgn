package CXGN::Trial::ParseUpload::Plugin::TrialUsedSeedlotsXLS;

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
    my $parser = Spreadsheet::ParseExcel->new();
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
    my $plot_name_head;
    my $amount_head;
    my $weight_head;
    my $description_head;

    if ($worksheet->get_cell(0,0)) {
        $seedlot_name_head  = $worksheet->get_cell(0,0)->value();
    }
    if ($worksheet->get_cell(0,1)) {
        $plot_name_head  = $worksheet->get_cell(0,1)->value();
    }
    if ($worksheet->get_cell(0,2)) {
        $amount_head  = $worksheet->get_cell(0,2)->value();
    }
    if ($worksheet->get_cell(0,3)) {
        $weight_head  = $worksheet->get_cell(0,3)->value();
    }
    if ($worksheet->get_cell(0,4)) {
        $description_head  = $worksheet->get_cell(0,4)->value();
    }

    if (!$seedlot_name_head || $seedlot_name_head ne 'seedlot_name' ) {
        push @error_messages, "Cell A1: seedlot_name is missing from the header";
    }
    if (!$plot_name_head || $plot_name_head ne 'plot_name') {
        push @error_messages, "Cell B1: plot_name is missing from the header";
    }
    if (!$amount_head || $amount_head ne 'num_seed_per_plot') {
        push @error_messages, "Cell C1: num_seed_per_plot is missing from the header";
    }
    if (!$weight_head || $weight_head ne 'weight_gram_seed_per_plot') {
        push @error_messages, "Cell D1: weight_gram_seed_per_plot is missing from the header";
    }
    if (!$description_head || $description_head ne 'description') {
        push @error_messages, "Cell E1: description is missing from the header (header must be present even if value is optional)";
    }

    my %seen_seedlot_names;
    my %seen_plot_names;
    my @pairs;
    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $seedlot_name;
        my $plot_name;
        my $amount = 'NA';
        my $weight = 'NA';
        my $description;

        if ($worksheet->get_cell($row,0)) {
            $seedlot_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $plot_name = $worksheet->get_cell($row,1)->value();
        }
        if ($worksheet->get_cell($row,2)) {
            $amount =  $worksheet->get_cell($row,2)->value();
        }
        if ($worksheet->get_cell($row,3)) {
            $weight =  $worksheet->get_cell($row,3)->value();
        }
        if ($worksheet->get_cell($row,4)) {
            $description =  $worksheet->get_cell($row,4)->value();
        }

        if (!$seedlot_name || $seedlot_name eq '' ) {
            push @error_messages, "Cell A$row_name: seedlot_name missing.";
        }
        elsif ($seedlot_name =~ /\s/ || $seedlot_name =~ /\// || $seedlot_name =~ /\\/ ) {
            push @error_messages, "Cell A$row_name: seedlot_name must not contain spaces or slashes.";
        }
        else {
            $seen_seedlot_names{$seedlot_name}=$row_name;
        }

        if (!$plot_name || $plot_name eq '') {
            push @error_messages, "Cell B$row_name: plot_name missing";
        } else {
            #file must not contain duplicate plot names
            if ($seen_plot_names{$plot_name}) {
                push @error_messages, "Cell B$row_name: duplicate plot_name at cell A".$seen_plot_names{$plot_name}.": $plot_name";
            }
            $seen_plot_names{$plot_name}++;
        }

        if ($amount eq 'NA' && $weight eq 'NA') {
            push @error_messages, "On row:$row_name you must provide either a weight in grams or a seed count amount.";
        }

        push @pairs, [$seedlot_name, $plot_name];
    }

    my @plots = keys %seen_plot_names;
    my $plots_validator = CXGN::List::Validate->new();
    my @plots_missing = @{$plots_validator->validate($schema,'plots',\@plots)->{'missing'}};

    if (scalar(@plots_missing) > 0) {
        push @error_messages, "The following plot_name are not in the database: ".join(',',@plots_missing);
        $errors{'missing_plots'} = \@plots_missing;
    }

    my @seedlots = keys %seen_seedlot_names;
    my $seedlots_validator = CXGN::List::Validate->new();
    my @seedlots_missing = @{$seedlots_validator->validate($schema,'seedlots',\@seedlots)->{'missing'}};

    if (scalar(@seedlots_missing) > 0) {
        push @error_messages, "The following seedlot_name are not in the database: ".join(',',@seedlots_missing);
        $errors{'missing_seedlots'} = \@seedlots_missing;
    }

    my $return = CXGN::Stock::Seedlot->verify_seedlot_plot_compatibility($schema, \@pairs);
    if (exists($return->{error})){
        push @error_messages, $return->{error};
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
    my %parsed_entries;

    $excel_obj = $parser->parse($filename);
    if ( !$excel_obj ) {
        return;
    }

    $worksheet = ( $excel_obj->worksheets() )[0];
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();

    my %seen_plot_names;
    my %seen_seedlot_names;
    for my $row ( 1 .. $row_max ) {
        my $seedlot_name;
        if ($worksheet->get_cell($row,0)) {
            $seedlot_name = $worksheet->get_cell($row,0)->value();
            $seen_seedlot_names{$seedlot_name}++;
        }
        my $plot_name;
        if ($worksheet->get_cell($row,1)) {
            $plot_name = $worksheet->get_cell($row,1)->value();
            $seen_plot_names{$plot_name}++;
        }
    }
    my @seedlots = keys %seen_seedlot_names;
    my $rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => \@seedlots }
    });
    my %seedlot_lookup;
    while (my $r=$rs->next){
        $seedlot_lookup{$r->uniquename} = $r->stock_id;
    }
    my @plots = keys %seen_plot_names;
    my $p_rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => \@plots }
    });
    my %plot_lookup;
    while (my $r=$p_rs->next){
        $plot_lookup{$r->uniquename} = $r->stock_id;
    }

    for my $row ( 1 .. $row_max ) {
        my $seedlot_name;
        my $plot_name;
        my $amount = 'NA';
        my $weight = 'NA';
        my $description;

        if ($worksheet->get_cell($row,0)) {
            $seedlot_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $plot_name = $worksheet->get_cell($row,1)->value();
        }
        if ($worksheet->get_cell($row,2)) {
            $amount =  $worksheet->get_cell($row,2)->value();
        }
        if ($worksheet->get_cell($row,3)) {
            $weight =  $worksheet->get_cell($row,3)->value();
        }
        if ($worksheet->get_cell($row,4)) {
            $description =  $worksheet->get_cell($row,4)->value();
        }

        #skip blank lines
        if (!$seedlot_name && !$plot_name) {
            next;
        }

        $parsed_entries{$row} = {
            seedlot_name => $seedlot_name,
            seedlot_stock_id => $seedlot_lookup{$seedlot_name},
            plot_stock_id => $plot_lookup{$plot_name},
            plot_name => $plot_name,
            plot_stock_id => $plot_lookup{$plot_name},
            amount => $amount,
            weight_gram => $weight,
            description => $description
        };
    }

    $self->_set_parsed_data(\%parsed_entries);
    return 1;
}


1;
