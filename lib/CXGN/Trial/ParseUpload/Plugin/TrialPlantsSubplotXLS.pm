package CXGN::Trial::ParseUpload::Plugin::TrialPlantsSubplotXLS;

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
    if (($col_max - $col_min)  < 1 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of plot data
        push @error_messages, "Spreadsheet is missing header or contains no rows";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    #get column headers
    my $subplot_name_head;
    my $plant_name_head;
    my $row_num_head;
    my $col_num_head;

    if ($worksheet->get_cell(0,0)) {
        $subplot_name_head  = $worksheet->get_cell(0,0)->value();
        $subplot_name_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,1)) {
        $plant_name_head  = $worksheet->get_cell(0,1)->value();
        $plant_name_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,2)) {
        $row_num_head  = $worksheet->get_cell(0,2)->value();
        $row_num_head =~ s/^\s+|\s+$//g;
    }
    if ($worksheet->get_cell(0,3)) {
        $col_num_head  = $worksheet->get_cell(0,3)->value();
        $col_num_head =~ s/^\s+|\s+$//g;
    }
    if (!$subplot_name_head || $subplot_name_head ne 'subplot_name' ) {
        push @error_messages, "Cell A1: subplot_name is missing from the header";
    }
    if (!$plant_name_head || $plant_name_head ne 'plant_name') {
        push @error_messages, "Cell B1: plant_name is missing from the header";
    }
    if (($row_num_head && $row_num_head ne "row_num")||($col_num_head && $col_num_head ne "col_num")) {
        push @error_messages, "If including row and column data, cells C1 and D1 must be row_num and col_num respectively.";
    }

    my %seen_subplot_names;
    my %seen_plant_names;
    my %seen_plant_coords;
    my $coords_given = 0;
    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $subplot_name;
        my $plant_name;
        my $row_num;
        my $col_num;
        my $coord_pair;

        if ($worksheet->get_cell($row,0)) {
            $subplot_name = $worksheet->get_cell($row,0)->value();
            $subplot_name =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,1)) {
            $plant_name = $worksheet->get_cell($row,1)->value();
            $plant_name =~ s/^\s+|\s+$//g;
        }

        if ($worksheet->get_cell($row,2) && $worksheet->get_cell($row,3)) {
            $row_num = $worksheet->get_cell($row,2)->value();
            $row_num =~ s/^\s+|\s+$//g;
            $col_num = $worksheet->get_cell($row,3)->value();
            $col_num =~ s/^\s+|\s+$//g;
            $coords_given = 1;
            $coord_pair = join(',', ($row_num, $col_num));
            if (exists($seen_plant_coords{$subplot_name}{$coord_pair})) {
                push @error_messages, "Multiple plants were assigned to the same coordinates ($coord_pair) in the same subplot ($subplot_name).";
            } 
            $seen_plant_coords{$plot_name}{$coord_pair} = 1;
        } elsif ($coords_given) {
            push @error_messages, "Coordinates were given for some plant entries, but not for $plant_name in $subplot_name.";
        }

        if (!$subplot_name || $subplot_name eq '' ) {
            push @error_messages, "Cell A$row_name: subplot_name missing.";
        }
        elsif ($subplot_name =~ /\s/ || $subplot_name =~ /\// || $subplot_name =~ /\\/ ) {
            push @error_messages, "Cell A$row_name: subplot_name must not contain spaces or slashes.";
        }
        else {
            $seen_subplot_names{$subplot_name}=$row_name;
        }

        if (!$plant_name || $plant_name eq '') {
            push @error_messages, "Cell B$row_name: plant_name missing";
        } elsif ($plant_name =~ /\s/ || $plant_name =~ /\// || $plant_name =~ /\\/ ) {
            push @error_messages, "Cell B$row_name: plant_name must not contain spaces or slashes.";
        } elsif (length($plant_name) <= 6) {
            push @error_messages, "Cell B$row_name: plant_name must be greater than 6 characters long.";
        } else {
            #file must not contain duplicate plant names
            if ($seen_plant_names{$plant_name}) {
                push @error_messages, "Cell B$row_name: duplicate plant_name at cell A".$seen_plant_names{$plant_name}.": $plant_name";
            }
            $seen_plant_names{$plant_name}++;
        }

    }

    my @subplots = keys %seen_subplot_names;
    my $subplots_validator = CXGN::List::Validate->new();
    my @subplots_missing = @{$subplots_validator->validate($schema,'subplots',\@subplots)->{'missing'}};

    if (scalar(@subplots_missing) > 0) {
        push @error_messages, "The following subplot_name are not in the database: ".join(',',@subplots_missing);
        $errors{'missing_subplots'} = \@subplots_missing;
    }

    my @plants = keys %seen_plant_names;
    my $plant_rs = $schema->resultset('Stock::Stock')->search({ 'uniquename' => {-in => \@plants} });
    while (my $r = $plant_rs->next){
        push @error_messages, "The following plant_name is already in the database and is not unique ".$r->uniquename;
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
    my %parsed_entries;

    $excel_obj = $parser->parse($filename);
    if ( !$excel_obj ) {
        return;
    }

    $worksheet = ( $excel_obj->worksheets() )[0];
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();

    my %seen_subplot_names;
    my %seen_plant_names;
    for my $row ( 1 .. $row_max ) {
        my $subplot_name;
        if ($worksheet->get_cell($row,0)) {
            $subplot_name = $worksheet->get_cell($row,0)->value();
            $subplot_name =~ s/^\s+|\s+$//g;
            $seen_subplot_names{$subplot_name}++;
        }
        my $plant_name;
        if ($worksheet->get_cell($row,1)) {
            $plant_name = $worksheet->get_cell($row,1)->value();
            $plant_name =~ s/^\s+|\s+$//g;
            $seen_plant_names{$plant_name}++;
        }
    }
    my @subplots = keys %seen_subplot_names;
    my $rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => \@subplots }
    });
    my %subplot_lookup;
    while (my $r=$rs->next){
        $subplot_lookup{$r->uniquename} = $r->stock_id;
    }

    for my $row ( 1 .. $row_max ) {
        my $subplot_name;
        my $plant_name;
        my $row_num;
        my $col_num;

        if ($worksheet->get_cell($row,0)) {
            $subplot_name = $worksheet->get_cell($row,0)->value();
            $subplot_name =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,1)) {
            $plant_name = $worksheet->get_cell($row,1)->value();
            $plant_name =~ s/^\s+|\s+$//g;
        }
        if ($worksheet->get_cell($row,2) && $worksheet->get_cell($row,3)) {
            $row_num = $worksheet->get_cell($row,2)->value();
            $row_num =~ s/^\s+|\s+$//g;
            $col_num = $worksheet->get_cell($row,3)->value();
            $col_num =~ s/^\s+|\s+$//g;
        }

        #skip blank lines
        if (!$subplot_name && !$plant_name) {
            next;
        }

        if ($row_num && $col_num) {
            push @{$parsed_entries{'data'}}, {
                subplot_name => $subplot_name,
                subplot_stock_id => $subplot_lookup{$subplot_name},
                plant_name => $plant_name,
                row_num => $row_num,
                col_num => $col_num
            };
        } else {
            push @{$parsed_entries{'data'}}, {
                subplot_name => $subplot_name,
                subplot_stock_id => $subplot_lookup{$subplot_name},
                plant_name => $plant_name,
            };
        }
    }

    $self->_set_parsed_data(\%parsed_entries);
    return 1;
}


1;
