package CXGN::Phenotypes::ParseUpload::Plugin::DataCollectorSpreadsheet;

use Moose;
#use File::Slurp;
use Spreadsheet::ParseExcel;

sub name {
    return "datacollector spreadsheet";
}

sub validate {
    my $self = shift;
    my $filename = shift;
    my $timestamp_included = shift;
    my $data_level = shift;
    my $schema = shift;
    my @file_lines;
    my $delimiter = ',';
    my $header;
    my @header_row;
    my $parser   = Spreadsheet::ParseExcel->new();
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
    }

    if (!$plot_name_head || $plot_name_head ne 'plot_name') {
        $parse_result{'error'} = "No plot_name in header.";
        print STDERR "No plot_name in header\n";
        return \%parse_result;
    }

    my $accession_name_head;
    if ($worksheet->get_cell(0,1)) {
      $accession_name_head  = $worksheet->get_cell(0,1)->value();
    }

    if (!$accession_name_head || $accession_name_head ne 'accession_name') {
        $parse_result{'error'} = "No accession_name in header.";
        print STDERR "No accession_name in header\n";
        return \%parse_result;
    }
    
    my $plot_num_head;
    if ($worksheet->get_cell(0,2)) {
      $plot_num_head  = $worksheet->get_cell(0,2)->value();
    }

    if (!$plot_num_head || $plot_num_head ne 'plot_number') {
        $parse_result{'error'} = "No plot_number in header.";
        print STDERR "No plot_number in header\n";
        return \%parse_result;
    }
    
    my $block_head;
    if ($worksheet->get_cell(0,3)) {
      $block_head  = $worksheet->get_cell(0,3)->value();
    }

    if (!$block_head || $block_head ne 'block_number') {
        $parse_result{'error'} = "No block_number in header.";
        print STDERR "No block_number in header\n";
        return \%parse_result;
    }
    
    my $is_control_head;
    if ($worksheet->get_cell(0,4)) {
      $is_control_head  = $worksheet->get_cell(0,4)->value();
    }

    if (!$is_control_head || $is_control_head ne 'is_a_control') {
        $parse_result{'error'} = "No is_a_control in header.";
        print STDERR "No is_a_control in header\n";
        return \%parse_result;
    }
    
    my $rep_head;
    if ($worksheet->get_cell(0,5)) {
      $rep_head  = $worksheet->get_cell(0,5)->value();
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
    my $parser   = Spreadsheet::ParseExcel->new();
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
        }
        if ($cell_val) {
            $header_column_info{$cell_val} = $col;
            $traits_seen{$cell_val} = 1;
        }
    }

    for my $row ( 1 .. $row_max ) {
        my $plot_name;

        if ($worksheet->get_cell($row,0)) {
            $plot_name = $worksheet->get_cell($row,0)->value();
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

            my @treatments;
            if ( defined($trait_value) && defined($timestamp) ) {
                if ($trait_value ne '.'){
                    $data{$plot_name}->{$trait_key} = [$trait_value, $timestamp, \@treatments];
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
    $parse_result{'plots'} = \@plots;
    $parse_result{'traits'} = \@traits;

    return \%parse_result;
}

1;
