package CXGN::Phenotypes::ParseUpload::Plugin::PhenotypeSpreadsheet;

use Moose;
#use File::Slurp;
use Spreadsheet::ParseExcel;
use JSON;

sub name {
    return "phenotype spreadsheet";
}

sub validate {
    my $self = shift;
    my $filename = shift;
    my $timestamp_included = shift;
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

    $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();
    if (($col_max - $col_min)  < 1 || ($row_max - $row_min) < 1 ) { #must have header with at least plot_name and one trait, as well as one row of phenotypes
        $parse_result{'error'} = "Spreadsheet is missing plot_name and atleast one trait in header.";
        print STDERR "Spreadsheet is missing header\n";
        return \%parse_result;
    }

    my $name_head;
    if ($worksheet->get_cell(6,0)) {
      $name_head  = $worksheet->get_cell(6,0)->value();
    }

    if (!$name_head || ($name_head ne 'plot_name' && $name_head ne 'plant_name')) {
        $parse_result{'error'} = "No plot_name or plant_name in header.";
        print STDERR "No plot name in header\n";
        return \%parse_result;
    }

    my @fixed_columns;
    if ($name_head eq 'plot_name') {
        @fixed_columns = qw | plot_name accession_name plot_number block_number is_a_control rep_number |;
    } elsif ($name_head eq 'plant_name') {
        @fixed_columns = qw | plant_name plot_name accession_name plot_number block_number is_a_control rep_number |;
    }
    my $num_fixed_col = scalar(@fixed_columns);

    my $predefined_columns;
    my $num_predef_col = 0;
    my $json = JSON->new();
    if ($worksheet->get_cell(4,1)) {
      $predefined_columns  = $json->decode($worksheet->get_cell(4,1)->value());
      $num_predef_col = scalar(@$predefined_columns);
    }

    my $num_col_before_traits = $num_fixed_col + $num_predef_col;

    for (my $row=7; $row<$row_max; $row++) {
        for (my $col=$num_col_before_traits; $col<=$col_max; $col++) {
            my $value_string = '';
            my $value = '';
            if ($worksheet->get_cell($row,$col)) {
                $value_string = $worksheet->get_cell($row,$col)->value();
                #print STDERR $value_string."\n";
                my ($value, $timestamp) = split /,/, $value_string;
                if (!$timestamp_included) {
                    if ($timestamp) {
                        $parse_result{'error'} = "Timestamp found in value, but 'Timestamps Included' is not selected.";
                        print STDERR "Timestamp wrongly found in value.\n";
                        return \%parse_result;
                    }
                }
                if ($timestamp_included) {
                    if (!$timestamp) {
                        $parse_result{'error'} = "No timestamp found in value, but 'Timestamps Included' is selected.";
                        print STDERR "Timestamp not found in value.\n";
                        return \%parse_result;
                    } else {
                        if (!$timestamp =~ m/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})(\S)(\d{4})/) {
                            $parse_result{'error'} = "Timestamp needs to be of form YYYY-MM-DD HH:MM:SS-0000 or YYYY-MM-DD HH:MM:SS+0000";
                            print STDERR "value: $timestamp\n";
                            return \%parse_result;
                        }
                    }
                }
            }
        }
    }

    #if the rest of the header rows are not two caps followed by colon followed by text then return

    return 1;
}

sub parse {
    my $self = shift;
    my $filename = shift;
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
        print STDERR "validate error: ".$parser->error()."\n";
        return \%parse_result;
    }

    $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();

    my $name_head  = $worksheet->get_cell(6,0)->value();

    my @fixed_columns;
    if ($name_head eq 'plot_name') {
        @fixed_columns = qw | plot_name accession_name plot_number block_number is_a_control rep_number |;
    } elsif ($name_head eq 'plant_name') {
        @fixed_columns = qw | plant_name plot_name accession_name plot_number block_number is_a_control rep_number |;
    }
    my $num_fixed_col = scalar(@fixed_columns);

    my $predefined_columns;
    my $num_predef_col = 0;
    my $json = JSON->new();
    if ($worksheet->get_cell(4,1)) {
      $predefined_columns  = $json->decode($worksheet->get_cell(4,1)->value());
      $num_predef_col = scalar(@$predefined_columns);
    }

    my $num_col_before_traits = $num_fixed_col + $num_predef_col;

    #get trait names and column numbers;
    for my $col ($num_col_before_traits .. $col_max) {
        my $cell_val;
        if ($worksheet->get_cell(6,$col)) {
            $cell_val = $worksheet->get_cell(6,$col)->value();
        }
        if ($cell_val) {
            $header_column_info{$cell_val} = $col;
            $traits_seen{$cell_val} = 1;
        }
    }

    for my $row ( 7 .. $row_max ) {
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
            if (!defined($trait_value)) {
                $trait_value = '';
            }
            #print STDERR $trait_value." : ".$timestamp."\n";

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
    $parse_result{'plots'} = \@plots;
    $parse_result{'traits'} = \@traits;

    return \%parse_result;
}

1;
