package CXGN::Phenotypes::ParseUpload::Plugin::DataCollectorSpreadsheet;

# Validate Returns %validate_result = (
#   error => 'error message'
#)

# Parse Returns %parsed_result = (
#   data => {
#       plotname1 => {
#           varname1 => [12, '2015-06-16T00:53:26Z']
#           varname2 => [120, '']
#       }
#   },
#   units => [plotname1],
#   variables => [varname1, varname2]
#)

use Moose;
#use File::Slurp;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;

sub name {
    return "datacollector spreadsheet";
}

sub validate {
    my $self = shift;
    my $filename = shift;
    my $timestamp_included = shift;
    my $data_level = shift;
    my $schema = shift;
    my $zipfile = shift; #not relevant for this plugin
    my $nd_protocol_id = shift; #not relevant for this plugin
    my $nd_protocol_filename = shift; #not relevant for this plugin
    my @file_lines;
    my $delimiter = ',';
    my $header;
    my @header_row;

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
    my %parse_result;

    #try to open the excel file and report any errors
    $excel_obj = $parser->parse($filename);
    if ( !$excel_obj ) {
        $parse_result{'error'} = $parser->error();
        print STDERR "validate error: ".$parser->error()."\n";
        return \%parse_result;
    }

    $worksheet = ($excel_obj->worksheets())[7]; #support only one worksheet
    if (!$worksheet) {
        $parse_result{'error'} = "No 7th tab found in your Excel file.";
        print STDERR "No 7th tab found in your Excel file.\n";
        return \%parse_result;
    }

   my  ( $row_min, $row_max ) = $worksheet->row_range();
   my  ( $col_min, $col_max ) = $worksheet->col_range();

    if (($col_max - $col_min)  < 1 || ($row_max - $row_min) < 1 ) { #must have header with at least plot_name and one trait, as well as one row of phenotypes
        $parse_result{'error'} = "Spreadsheet is missing plot_name and atleast one trait in header.";
        print STDERR "Spreadsheet is missing header\n";
        return \%parse_result;
    }

    my $plot_name_head;
    if ($worksheet->get_cell(0,0)) {
      $plot_name_head  = $worksheet->get_cell(0,0)->value();
      $plot_name_head =~ s/^\s+|\s+$//g;
    }

    if (!$plot_name_head || $plot_name_head ne 'plot_name') {
        $parse_result{'error'} = "No plot_name in header.";
        print STDERR "No plot_name in header\n";
        return \%parse_result;
    }

    my $trial_stock_name_head;
    if ($worksheet->get_cell(0,1)) {
      $trial_stock_name_head  = $worksheet->get_cell(0,1)->value();
      $trial_stock_name_head =~ s/^\s+|\s+$//g;
    }

    if (!$trial_stock_name_head || (($trial_stock_name_head ne 'accession_name') && ($trial_stock_name_head ne 'family_name') && ($trial_stock_name_head ne 'cross_unique_id'))) {
        $parse_result{'error'} = "No accession_name or family_name or cross_unique_id in header.";
        print STDERR "No accession_name or family_name or cross_unique_id in header\n";
        return \%parse_result;
    }

    my $plot_num_head;
    if ($worksheet->get_cell(0,2)) {
      $plot_num_head  = $worksheet->get_cell(0,2)->value();
      $plot_num_head =~ s/^\s+|\s+$//g;
    }

    if (!$plot_num_head || $plot_num_head ne 'plot_number') {
        $parse_result{'error'} = "No plot_number in header.";
        print STDERR "No plot_number in header\n";
        return \%parse_result;
    }

    my $block_head;
    if ($worksheet->get_cell(0,3)) {
      $block_head  = $worksheet->get_cell(0,3)->value();
      $block_head =~ s/^\s+|\s+$//g;
    }

    if (!$block_head || $block_head ne 'block_number') {
        $parse_result{'error'} = "No block_number in header.";
        print STDERR "No block_number in header\n";
        return \%parse_result;
    }

    my $is_control_head;
    if ($worksheet->get_cell(0,4)) {
      $is_control_head  = $worksheet->get_cell(0,4)->value();
      $is_control_head =~ s/^\s+|\s+$//g;
    }

    if (!$is_control_head || $is_control_head ne 'is_a_control') {
        $parse_result{'error'} = "No is_a_control in header.";
        print STDERR "No is_a_control in header\n";
        return \%parse_result;
    }

    my $rep_head;
    if ($worksheet->get_cell(0,5)) {
      $rep_head  = $worksheet->get_cell(0,5)->value();
      $rep_head =~ s/^\s+|\s+$//g;
    }

    if (!$rep_head || $rep_head ne 'rep_number') {
        $parse_result{'error'} = "No rep_number in header.";
        print STDERR "No rep_number in header\n";
        return \%parse_result;
    }

    #if the rest of the header rows are not two caps followed by colon followed by text then return

    return 1;
}

sub parse {
    my $self = shift;
    my $filename = shift;
    my $timestamp_included = shift;
    my $data_level = shift;
    my $schema = shift;
    my $zipfile = shift; #not relevant for this plugin
    my $user_id = shift; #not relevant for this plugin
    my $c = shift; #not relevant for this plugin
    my $nd_protocol_id = shift; #not relevant for this plugin
    my $nd_protocol_filename = shift; #not relevant for this plugin
    my %parse_result;
    my @file_lines;
    my $delimiter = ',';
    my $header;
    my @header_row;
    my $header_column_number = 0;
    my %header_column_info; #column numbers of key info indexed from 0;
    my %plots_seen;
    my %traits_seen;
    my @plots;
    my @traits;
    my %data;

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
    if ( !$excel_obj ) {
        $parse_result{'error'} = $parser->error();
        print STDERR "Could not open excel file";
        return \%parse_result;
    }

    $worksheet = ( $excel_obj->worksheets() )[7];
    if (!$worksheet) {
        $parse_result{'error'} = "No 7th tab found in your Excel file.";
        print STDERR "No 7th tab found in your Excel file.\n";
        return \%parse_result;
    }

    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();

    #get trait names and column numbers;
    for my $col (6 .. $col_max) {
        my $cell_val;
        if ($worksheet->get_cell(0,$col)) {
            $cell_val = $worksheet->get_cell(0,$col)->value();
            $cell_val =~ s/^\s+|\s+$//g;
        }
        if ($cell_val || $cell_val == 0) {
            $header_column_info{$cell_val} = $col;
            $traits_seen{$cell_val} = 1;
        }
    }

    for my $row ( 1 .. $row_max ) {
        my $plot_name;

        if ($worksheet->get_cell($row,0)) {
            $plot_name = $worksheet->get_cell($row,0)->value();
            $plot_name =~ s/^\s+|\s+$//g;
            $plots_seen{$plot_name} = 1;
        }

        foreach my $trait_key (sort keys %header_column_info) {
            my $value_string = '';

            if ($worksheet->get_cell($row,$header_column_info{$trait_key})){
                $value_string = $worksheet->get_cell($row,$header_column_info{$trait_key})->value();
            }
            my ($trait_value, $timestamp) = split /,/, $value_string;
            if (!$timestamp) {
                $timestamp = '';
            }
            if (!defined($trait_value) ) {
                $trait_value = '';
            }
            #print STDERR $trait_value." : ".$timestamp."\n";

            if ($timestamp_included) {
                if (!$timestamp =~ m/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})(\S)(\d{4})/) {
                    $parse_result{'error'} = "Timestamp needs to be of form YYYY-MM-DD HH:MM:SS-0000 or YYYY-MM-DD HH:MM:SS+0000";
                    print STDERR "value: $timestamp\n";
                    return \%parse_result;
                }
            }

            if ( defined($trait_value) && defined($timestamp) ) {
                if ($trait_value ne '.'){
                    $data{$plot_name}->{$trait_key} = [$trait_value, $timestamp];
                }
            } else {
                $parse_result{'error'} = "Value or timestamp missing.";
                return \%parse_result;
            }
        }
    }

    foreach my $plot (sort keys %plots_seen) {
        push @plots, $plot;
    }
    foreach my $trait (sort keys %traits_seen) {
        push @traits, $trait;
    }

    $parse_result{'data'} = \%data;
    $parse_result{'units'} = \@plots;
    $parse_result{'variables'} = \@traits;

    return \%parse_result;
}

1;
