package CXGN::Trial::ParseUpload::Plugin::TrialPlantsSubplotWithNumberOfPlantsXLS;

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
    if (($col_max - $col_min)  < 1 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of plot data
        push @error_messages, "Spreadsheet is missing header or contains no rows";
        $errors{'error_messages'} = \@error_messages;
        $self->_set_parse_errors(\%errors);
        return;
    }

    #get column headers
    my $subplot_name_head;
    my $num_plants_per_subplot_head;

    if ($worksheet->get_cell(0,0)) {
        $subplot_name_head  = $worksheet->get_cell(0,0)->value();
    }
    if ($worksheet->get_cell(0,1)) {
        $num_plants_per_subplot_head  = $worksheet->get_cell(0,1)->value();
    }
    if (!$subplot_name_head || $subplot_name_head ne 'subplot_name' ) {
        push @error_messages, "Cell A1: subplot_name is missing from the header";
    }
    if (!$num_plants_per_subplot_head || $num_plants_per_subplot_head ne 'num_plants_per_subplot') {
        push @error_messages, "Cell B1: num_plants_per_subplot is missing from the header";
    }

    my %seen_subplot_names;
    my %seen_plant_names;
    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $subplot_name;
        my $num_plants_per_subplot;

        if ($worksheet->get_cell($row,0)) {
            $subplot_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $num_plants_per_subplot = $worksheet->get_cell($row,1)->value();
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

        if (!$num_plants_per_subplot || $num_plants_per_subplot eq '') {
            push @error_messages, "Cell B$row_name: num_plants_per_subplot missing";
        } if (!($num_plants_per_subplot =~ /^\d+?$/)) {
            push @error_messages, "Cell B$row_name: num_plants_per_subplot must be a number";
        } else {
            #file must not contain duplicate plant names
            for my $i (1 .. $num_plants_per_subplot) {
                my $plant_name = $subplot_name."_plant_".$i;
                if ($seen_plant_names{$plant_name}) {
                    push @error_messages, "Cell B$row_name: duplicate plant_name at cell A".$seen_plant_names{$plant_name}.": $plant_name";
                }
                if (!$plant_name){
                    push @error_messages, "CellB$row_name: No plant name could be made!";
                }
                $seen_plant_names{$plant_name}++;
            }
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

    my %seen_subplot_names;
    for my $row ( 1 .. $row_max ) {
        my $subplot_name;
        if ($worksheet->get_cell($row,0)) {
            $subplot_name = $worksheet->get_cell($row,0)->value();
            $seen_subplot_names{$subplot_name}++;
        }
    }
    my @subplots = keys %seen_subplot_names;
    my $subplot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'subplot', 'stock_type')->cvterm_id;
    my $rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => \@subplots },
        'type_id' => $subplot_cvterm_id
    });
    my %subplot_lookup;
    while (my $r=$rs->next){
        $subplot_lookup{$r->uniquename} = $r->stock_id;
    }

    for my $row ( 1 .. $row_max ) {
        my $subplot_name;
        my $num_plants_per_subplot;

        if ($worksheet->get_cell($row,0)) {
            $subplot_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $num_plants_per_subplot = $worksheet->get_cell($row,1)->value();
        }

        for my $i (1 .. $num_plants_per_subplot) {
            my $plant_name = $subplot_name."_plant_".$i;

            #skip blank lines
            if (!$subplot_name && !$plant_name) {
                next;
            }

            push @{$parsed_entries{'data'}}, {
                subplot_name => $subplot_name,
                subplot_stock_id => $subplot_lookup{$subplot_name},
                plant_name => $plant_name,
                plant_index_number => $i
            };
        }
    }

    $self->_set_parsed_data(\%parsed_entries);
    return 1;
}


1;
