package CXGN::Trial::ParseUpload::Plugin::TrialPlotGPSCoordinatesXLS;

use Moose::Role;
use Spreadsheet::ParseExcel;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::List::Validate;
use Scalar::Util qw(looks_like_number);

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
    my $plot_name_head;
    my $UTM31N_bottom_left_x_head;
    my $UTM31N_bottom_left_y_head;
    my $UTM31N_bottom_right_x_head;
    my $UTM31N_bottom_right_y_head;
    my $UTM31N_top_right_x_head;
    my $UTM31N_top_right_y_head;
    my $UTM31N_top_left_x_head;
    my $UTM31N_top_left_y_head;
    my $WGS84_bottom_left_x_head;
    my $WGS84_bottom_left_y_head;
    my $WGS84_bottom_right_x_head;
    my $WGS84_bottom_right_y_head;
    my $WGS84_top_right_x_head;
    my $WGS84_top_right_y_head;
    my $WGS84_top_left_x_head;
    my $WGS84_top_left_y_head;

    if ($worksheet->get_cell(0,0)) {
        $plot_name_head  = $worksheet->get_cell(0,0)->value();
    }
    if ($worksheet->get_cell(0,1)) {
        $UTM31N_bottom_left_x_head  = $worksheet->get_cell(0,1)->value();
    }
    if ($worksheet->get_cell(0,2)) {
        $UTM31N_bottom_left_y_head  = $worksheet->get_cell(0,2)->value();
    }
    if ($worksheet->get_cell(0,3)) {
        $UTM31N_bottom_right_x_head  = $worksheet->get_cell(0,3)->value();
    }
    if ($worksheet->get_cell(0,4)) {
        $UTM31N_bottom_right_y_head  = $worksheet->get_cell(0,4)->value();
    }
    if ($worksheet->get_cell(0,5)) {
        $UTM31N_top_right_x_head  = $worksheet->get_cell(0,5)->value();
    }
    if ($worksheet->get_cell(0,6)) {
        $UTM31N_top_right_y_head  = $worksheet->get_cell(0,6)->value();
    }
    if ($worksheet->get_cell(0,7)) {
        $UTM31N_top_left_x_head  = $worksheet->get_cell(0,7)->value();
    }
    if ($worksheet->get_cell(0,8)) {
        $UTM31N_top_left_y_head  = $worksheet->get_cell(0,8)->value();
    }

    if ($worksheet->get_cell(0,9)) {
        $WGS84_bottom_left_x_head  = $worksheet->get_cell(0,9)->value();
    }
    if ($worksheet->get_cell(0,10)) {
        $WGS84_bottom_left_y_head  = $worksheet->get_cell(0,10)->value();
    }
    if ($worksheet->get_cell(0,11)) {
        $WGS84_bottom_right_x_head  = $worksheet->get_cell(0,11)->value();
    }
    if ($worksheet->get_cell(0,12)) {
        $WGS84_bottom_right_y_head  = $worksheet->get_cell(0,12)->value();
    }
    if ($worksheet->get_cell(0,13)) {
        $WGS84_top_right_x_head  = $worksheet->get_cell(0,13)->value();
    }
    if ($worksheet->get_cell(0,14)) {
        $WGS84_top_right_y_head  = $worksheet->get_cell(0,14)->value();
    }
    if ($worksheet->get_cell(0,15)) {
        $WGS84_top_left_x_head  = $worksheet->get_cell(0,15)->value();
    }
    if ($worksheet->get_cell(0,16)) {
        $WGS84_top_left_y_head  = $worksheet->get_cell(0,16)->value();
    }

    if (!$plot_name_head || $plot_name_head ne 'plot_name' ) {
        push @error_messages, "Cell A1: plot_name is missing from the header";
    }
    if (!$UTM31N_bottom_left_x_head || $UTM31N_bottom_left_x_head ne 'UTM31N_bottom_left_x') {
        push @error_messages, "Cell B1: UTM31N_bottom_left_x is missing from the header";
    }
    if (!$UTM31N_bottom_left_y_head || $UTM31N_bottom_left_y_head ne 'UTM31N_bottom_left_y') {
        push @error_messages, "Cell C1: UTM31N_bottom_left_y is missing from the header";
    }
    if (!$UTM31N_bottom_right_x_head || $UTM31N_bottom_right_x_head ne 'UTM31N_bottom_right_x') {
        push @error_messages, "Cell D1: UTM31N_bottom_right_x is missing from the header";
    }
    if (!$UTM31N_bottom_right_y_head || $UTM31N_bottom_right_y_head ne 'UTM31N_bottom_right_y') {
        push @error_messages, "Cell E1: UTM31N_bottom_right_y is missing from the header";
    }
    if (!$UTM31N_top_right_x_head || $UTM31N_top_right_x_head ne 'UTM31N_top_right_x') {
        push @error_messages, "Cell F1: UTM31N_top_right_x is missing from the header";
    }
    if (!$UTM31N_top_right_y_head || $UTM31N_top_right_y_head ne 'UTM31N_top_right_y') {
        push @error_messages, "Cell G1: UTM31N_top_right_y is missing from the header";
    }
    if (!$UTM31N_top_left_x_head || $UTM31N_top_left_x_head ne 'UTM31N_top_left_x') {
        push @error_messages, "Cell H1: UTM31N_top_left_x is missing from the header";
    }
    if (!$UTM31N_top_left_y_head || $UTM31N_top_left_y_head ne 'UTM31N_top_left_y') {
        push @error_messages, "Cell I1: UTM31N_top_left_y is missing from the header";
    }

    if (!$WGS84_bottom_left_x_head || $WGS84_bottom_left_x_head ne 'WGS84_bottom_left_x') {
        push @error_messages, "Cell J1: WGS84_bottom_left_x is missing from the header";
    }
    if (!$WGS84_bottom_left_y_head || $WGS84_bottom_left_y_head ne 'WGS84_bottom_left_y') {
        push @error_messages, "Cell K1: WGS84_bottom_left_y is missing from the header";
    }
    if (!$WGS84_bottom_right_x_head || $WGS84_bottom_right_x_head ne 'WGS84_bottom_right_x') {
        push @error_messages, "Cell L1: WGS84_bottom_right_x is missing from the header";
    }
    if (!$WGS84_bottom_right_y_head || $WGS84_bottom_right_y_head ne 'WGS84_bottom_right_y') {
        push @error_messages, "Cell M1: WGS84_bottom_right_y is missing from the header";
    }
    if (!$WGS84_top_right_x_head || $WGS84_top_right_x_head ne 'WGS84_top_right_x') {
        push @error_messages, "Cell N1: WGS84_top_right_x is missing from the header";
    }
    if (!$WGS84_top_right_y_head || $WGS84_top_right_y_head ne 'WGS84_top_right_y') {
        push @error_messages, "Cell O1: WGS84_top_right_y is missing from the header";
    }
    if (!$WGS84_top_left_x_head || $WGS84_top_left_x_head ne 'WGS84_top_left_x') {
        push @error_messages, "Cell P1: WGS84_top_left_x is missing from the header";
    }
    if (!$WGS84_top_left_y_head || $WGS84_top_left_y_head ne 'WGS84_top_left_y') {
        push @error_messages, "Cell Q1: WGS84_top_left_y is missing from the header";
    }

    my %seen_plot_names;
    for my $row ( 1 .. $row_max ) {
        my $row_name = $row+1;
        my $plot_name;
        my $UTM31N_bottom_left_x;
        my $UTM31N_bottom_left_y;
        my $UTM31N_bottom_right_x;
        my $UTM31N_bottom_right_y;
        my $UTM31N_top_right_x;
        my $UTM31N_top_right_y;
        my $UTM31N_top_left_x;
        my $UTM31N_top_left_y;
        my $WGS84_bottom_left_x;
        my $WGS84_bottom_left_y;
        my $WGS84_bottom_right_x;
        my $WGS84_bottom_right_y;
        my $WGS84_top_right_x;
        my $WGS84_top_right_y;
        my $WGS84_top_left_x;
        my $WGS84_top_left_y;

        if ($worksheet->get_cell($row,0)) {
            $plot_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $UTM31N_bottom_left_x = $worksheet->get_cell($row,1)->value();
        }
        if ($worksheet->get_cell($row,2)) {
            $UTM31N_bottom_left_y = $worksheet->get_cell($row,2)->value();
        }
        if ($worksheet->get_cell($row,3)) {
            $UTM31N_bottom_right_x = $worksheet->get_cell($row,3)->value();
        }
        if ($worksheet->get_cell($row,4)) {
            $UTM31N_bottom_right_y = $worksheet->get_cell($row,4)->value();
        }
        if ($worksheet->get_cell($row,5)) {
            $UTM31N_top_right_x = $worksheet->get_cell($row,5)->value();
        }
        if ($worksheet->get_cell($row,6)) {
            $UTM31N_top_right_y = $worksheet->get_cell($row,6)->value();
        }
        if ($worksheet->get_cell($row,7)) {
            $UTM31N_top_left_x = $worksheet->get_cell($row,7)->value();
        }
        if ($worksheet->get_cell($row,8)) {
            $UTM31N_top_left_y = $worksheet->get_cell($row,8)->value();
        }

        if ($worksheet->get_cell($row,9)) {
            $WGS84_bottom_left_x = $worksheet->get_cell($row,9)->value();
        }
        if ($worksheet->get_cell($row,10)) {
            $WGS84_bottom_left_y = $worksheet->get_cell($row,10)->value();
        }
        if ($worksheet->get_cell($row,11)) {
            $WGS84_bottom_right_x = $worksheet->get_cell($row,11)->value();
        }
        if ($worksheet->get_cell($row,12)) {
            $WGS84_bottom_right_y = $worksheet->get_cell($row,12)->value();
        }
        if ($worksheet->get_cell($row,13)) {
            $WGS84_top_right_x = $worksheet->get_cell($row,13)->value();
        }
        if ($worksheet->get_cell($row,14)) {
            $WGS84_top_right_y = $worksheet->get_cell($row,14)->value();
        }
        if ($worksheet->get_cell($row,15)) {
            $WGS84_top_left_x = $worksheet->get_cell($row,15)->value();
        }
        if ($worksheet->get_cell($row,16)) {
            $WGS84_top_left_y = $worksheet->get_cell($row,16)->value();
        }

        if (!$plot_name || $plot_name eq '' ) {
            push @error_messages, "Cell A$row_name: plot_name missing.";
        }
        elsif ($plot_name =~ /\s/ || $plot_name =~ /\// || $plot_name =~ /\\/ ) {
            push @error_messages, "Cell A$row_name: plot_name must not contain spaces or slashes.";
        }
        else {
            $seen_plot_names{$plot_name}=$row_name;
        }

        if ($UTM31N_bottom_left_x && !looks_like_number($UTM31N_bottom_left_x)){
            push @error_messages, "Cell B$row_name: UTM31N_bottom_left_x must be a number.";
        }
        if ($UTM31N_bottom_left_y && !looks_like_number($UTM31N_bottom_left_y)){
            push @error_messages, "Cell C$row_name: UTM31N_bottom_left_y must be a number.";
        }
        if ($UTM31N_bottom_right_x && !looks_like_number($UTM31N_bottom_right_x)){
            push @error_messages, "Cell D$row_name: UTM31N_bottom_right_x must be a number.";
        }
        if ($UTM31N_bottom_right_y && !looks_like_number($UTM31N_bottom_right_y)){
            push @error_messages, "Cell E$row_name: UTM31N_bottom_right_y must be a number.";
        }
        if ($UTM31N_top_right_x && !looks_like_number($UTM31N_top_right_x)){
            push @error_messages, "Cell F$row_name: UTM31N_top_right_x must be a number.";
        }
        if ($UTM31N_top_right_y && !looks_like_number($UTM31N_top_right_y)){
            push @error_messages, "Cell G$row_name: UTM31N_top_right_y must be a number.";
        }
        if ($UTM31N_top_left_x && !looks_like_number($UTM31N_top_left_x)){
            push @error_messages, "Cell H$row_name: UTM31N_top_left_x must be a number.";
        }
        if ($UTM31N_top_left_y && !looks_like_number($UTM31N_top_left_y)){
            push @error_messages, "Cell I$row_name: UTM31N_top_left_y must be a number.";
        }

        if ($WGS84_bottom_left_x && !looks_like_number($WGS84_bottom_left_x)){
            push @error_messages, "Cell J$row_name: WGS84_bottom_left_x must be a number.";
        }
        if ($WGS84_bottom_left_y && !looks_like_number($WGS84_bottom_left_y)){
            push @error_messages, "Cell K$row_name: WGS84_bottom_left_y must be a number.";
        }
        if ($WGS84_bottom_right_x && !looks_like_number($WGS84_bottom_right_x)){
            push @error_messages, "Cell L$row_name: WGS84_bottom_right_x must be a number.";
        }
        if ($WGS84_bottom_right_y && !looks_like_number($WGS84_bottom_right_y)){
            push @error_messages, "Cell M$row_name: WGS84_bottom_right_y must be a number.";
        }
        if ($WGS84_top_right_x && !looks_like_number($WGS84_top_right_x)){
            push @error_messages, "Cell N$row_name: WGS84_top_right_x must be a number.";
        }
        if ($WGS84_top_right_y && !looks_like_number($WGS84_top_right_y)){
            push @error_messages, "Cell O$row_name: WGS84_top_right_y must be a number.";
        }
        if ($WGS84_top_left_x && !looks_like_number($WGS84_top_left_x)){
            push @error_messages, "Cell P$row_name: WGS84_top_left_x must be a number.";
        }
        if ($WGS84_top_left_y && !looks_like_number($WGS84_top_left_y)){
            push @error_messages, "Cell Q$row_name: WGS84_top_left_y must be a number.";
        }

    }

    my @plots = keys %seen_plot_names;
    my $plots_validator = CXGN::List::Validate->new();
    my @plots_missing = @{$plots_validator->validate($schema,'plots',\@plots)->{'missing'}};

    if (scalar(@plots_missing) > 0) {
        push @error_messages, "The following plot_name are not in the database: ".join(',',@plots_missing);
        $errors{'missing_plots'} = \@plots_missing;
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
    for my $row ( 1 .. $row_max ) {
        my $plot_name;
        if ($worksheet->get_cell($row,0)) {
            $plot_name = $worksheet->get_cell($row,0)->value();
            $seen_plot_names{$plot_name}++;
        }
    }
    my @plots = keys %seen_plot_names;
    my $rs = $schema->resultset("Stock::Stock")->search({
        'is_obsolete' => { '!=' => 't' },
        'uniquename' => { -in => \@plots }
    });
    my %plot_lookup;
    while (my $r=$rs->next){
        $plot_lookup{$r->uniquename} = $r->stock_id;
    }

    for my $row ( 1 .. $row_max ) {
        my $plot_name;
        my $UTM31N_bottom_left_x;
        my $UTM31N_bottom_left_y;
        my $UTM31N_bottom_right_x;
        my $UTM31N_bottom_right_y;
        my $UTM31N_top_right_x;
        my $UTM31N_top_right_y;
        my $UTM31N_top_left_x;
        my $UTM31N_top_left_y;
        my $WGS84_bottom_left_x;
        my $WGS84_bottom_left_y;
        my $WGS84_bottom_right_x;
        my $WGS84_bottom_right_y;
        my $WGS84_top_right_x;
        my $WGS84_top_right_y;
        my $WGS84_top_left_x;
        my $WGS84_top_left_y;
        if ($worksheet->get_cell($row,0)) {
            $plot_name = $worksheet->get_cell($row,0)->value();
        }
        if ($worksheet->get_cell($row,1)) {
            $UTM31N_bottom_left_x = $worksheet->get_cell($row,1)->value();
        }
        if ($worksheet->get_cell($row,2)) {
            $UTM31N_bottom_left_y = $worksheet->get_cell($row,2)->value();
        }
        if ($worksheet->get_cell($row,3)) {
            $UTM31N_bottom_right_x = $worksheet->get_cell($row,3)->value();
        }
        if ($worksheet->get_cell($row,4)) {
            $UTM31N_bottom_right_y = $worksheet->get_cell($row,4)->value();
        }
        if ($worksheet->get_cell($row,5)) {
            $UTM31N_top_right_x = $worksheet->get_cell($row,5)->value();
        }
        if ($worksheet->get_cell($row,6)) {
            $UTM31N_top_right_y = $worksheet->get_cell($row,6)->value();
        }
        if ($worksheet->get_cell($row,7)) {
            $UTM31N_top_left_x = $worksheet->get_cell($row,7)->value();
        }
        if ($worksheet->get_cell($row,8)) {
            $UTM31N_top_left_y = $worksheet->get_cell($row,8)->value();
        }

        if ($worksheet->get_cell($row,9)) {
            $WGS84_bottom_left_x = $worksheet->get_cell($row,9)->value();
        }
        if ($worksheet->get_cell($row,10)) {
            $WGS84_bottom_left_y = $worksheet->get_cell($row,10)->value();
        }
        if ($worksheet->get_cell($row,11)) {
            $WGS84_bottom_right_x = $worksheet->get_cell($row,11)->value();
        }
        if ($worksheet->get_cell($row,12)) {
            $WGS84_bottom_right_y = $worksheet->get_cell($row,12)->value();
        }
        if ($worksheet->get_cell($row,13)) {
            $WGS84_top_right_x = $worksheet->get_cell($row,13)->value();
        }
        if ($worksheet->get_cell($row,14)) {
            $WGS84_top_right_y = $worksheet->get_cell($row,14)->value();
        }
        if ($worksheet->get_cell($row,15)) {
            $WGS84_top_left_x = $worksheet->get_cell($row,15)->value();
        }
        if ($worksheet->get_cell($row,16)) {
            $WGS84_top_left_y = $worksheet->get_cell($row,16)->value();
        }

        #skip blank lines
        if (!$plot_name && !$UTM31N_bottom_left_x && !$UTM31N_bottom_left_y && !$UTM31N_bottom_right_x && !$UTM31N_bottom_right_y && !$UTM31N_top_right_x && !$UTM31N_top_right_y && !$UTM31N_top_left_x && !$UTM31N_top_left_y && !$WGS84_bottom_left_x && !$WGS84_bottom_left_y && !$WGS84_bottom_right_x && !$WGS84_bottom_right_y && !$WGS84_top_right_x && !$WGS84_top_right_y && !$WGS84_top_left_x && !$WGS84_top_left_y) {
            next;
        }

        $parsed_entries{$row} = {
            plot_name => $plot_name,
            plot_stock_id => $plot_lookup{$plot_name},
            UTM31N_bottom_left_x => $UTM31N_bottom_left_x,
            UTM31N_bottom_left_y => $UTM31N_bottom_left_y,
            UTM31N_bottom_right_x => $UTM31N_bottom_right_x,
            UTM31N_bottom_right_y => $UTM31N_bottom_right_y,
            UTM31N_top_right_x => $UTM31N_top_right_x,
            UTM31N_top_right_y => $UTM31N_top_right_y,
            UTM31N_top_left_x => $UTM31N_top_left_x,
            UTM31N_top_left_y => $UTM31N_top_left_y,
            WGS84_bottom_left_x => $WGS84_bottom_left_x,
            WGS84_bottom_left_y => $WGS84_bottom_left_y,
            WGS84_bottom_right_x => $WGS84_bottom_right_x,
            WGS84_bottom_right_y => $WGS84_bottom_right_y,
            WGS84_top_right_x => $WGS84_top_right_x,
            WGS84_top_right_y => $WGS84_top_right_y,
            WGS84_top_left_x => $WGS84_top_left_x,
            WGS84_top_left_y => $WGS84_top_left_y
        };
    }

    $self->_set_parsed_data(\%parsed_entries);
    return 1;
}


1;
