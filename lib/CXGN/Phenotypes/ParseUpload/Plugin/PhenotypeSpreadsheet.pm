package CXGN::Phenotypes::ParseUpload::Plugin::PhenotypeSpreadsheet;

use Moose;
#use File::Slurp;
use Spreadsheet::ParseExcel;
use JSON;
use Data::Dumper;

sub name {
    return "phenotype spreadsheet";
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
    my $design_type;
    if ($worksheet->get_cell(3,3)) {
      $design_type  = $worksheet->get_cell(3,3)->value();
    }
    if (!$design_type ) {
        $parse_result{'error'} = "No design type in header. Make sure you are using the correct spreadsheet format.";
        print STDERR "No design type in header\n";
        return \%parse_result;
    }
    if (!$name_head || ($name_head ne 'plot_name' && $name_head ne 'plant_name' && $name_head ne 'subplot_name')) {
        $parse_result{'error'} = "No plot_name or plant_name or subplot_name in header. Make sure you are using the correct spreadsheet format. It may help to recreate your spreadsheet from the website.";
        print STDERR "No plot_name or plant_name or subplot_name in header\n";
        return \%parse_result;
    }
    if ($data_level eq 'plots' && ( $worksheet->get_cell(6,0)->value() ne 'plot_name' ||
                                    $worksheet->get_cell(6,1)->value() ne 'accession_name' ||
                                    $worksheet->get_cell(6,2)->value() ne 'plot_number' ||
                                    $worksheet->get_cell(6,3)->value() ne 'block_number' ||
                                    $worksheet->get_cell(6,4)->value() ne 'is_a_control' ||
                                    $worksheet->get_cell(6,5)->value() ne 'rep_number' ||
                                    $worksheet->get_cell(6,6)->value() ne 'treatment_name' ) ) {
        $parse_result{'error'} = "Data columns must be in this order for uploading Plot phenotypes: plot_name, accession_name, plot_number, block_number, is_a_control,  rep_number, 'treatment_name'. Make sure to select the correct data level. It may help to recreate your spreadsheet from the website.";
        print STDERR "Columns not correct and data_level is plots\n";
        return \%parse_result;
    }
    if ($data_level eq 'plants' && ($worksheet->get_cell(6,0)->value() ne 'plant_name' ||
                                    $worksheet->get_cell(6,1)->value() ne 'plot_name' ||
                                    $worksheet->get_cell(6,2)->value() ne 'accession_name' ||
                                    $worksheet->get_cell(6,3)->value() ne 'plot_number' ||
                                    $worksheet->get_cell(6,4)->value() ne 'block_number' ||
                                    $worksheet->get_cell(6,5)->value() ne 'is_a_control' ||
                                    $worksheet->get_cell(6,6)->value() ne 'rep_number' ||
                                    $worksheet->get_cell(6,7)->value() ne 'treatment_name' ) ) {
        $parse_result{'error'} = "Data columns must be in this order for uploading Plant phenotypes: plant_name, plot_name, accession_name, plot_number, block_number, is_a_control, rep_number, treatment_name. Make sure to select the correct data level. It may help to recreate your spreadsheet from the website.";
        print STDERR "Columns not correct and data_level is plants\n";
        return \%parse_result;
    }
    if ($data_level eq 'subplots' && ( ($worksheet->get_cell(6,0)->value() ne 'subplot_name' ||
                                    $worksheet->get_cell(6,1)->value() ne 'plot_name' ||
                                    $worksheet->get_cell(6,2)->value() ne 'accession_name' ||
                                    $worksheet->get_cell(6,3)->value() ne 'plot_number' ||
                                    $worksheet->get_cell(6,4)->value() ne 'block_number' ||
                                    $worksheet->get_cell(6,5)->value() ne 'is_a_control' ||
                                    $worksheet->get_cell(6,6)->value() ne 'rep_number' ||
                                    $worksheet->get_cell(6,7)->value() ne 'treatment_name' ) && ($worksheet->get_cell(6,0)->value() ne 'plant_name' ||
                                                                    $worksheet->get_cell(6,1)->value() ne 'subplot_name' ||
                                                                    $worksheet->get_cell(6,2)->value() ne 'plot_name' ||
                                                                    $worksheet->get_cell(6,3)->value() ne 'accession_name' ||
                                                                    $worksheet->get_cell(6,4)->value() ne 'plot_number' ||
                                                                    $worksheet->get_cell(6,5)->value() ne 'block_number' ||
                                                                    $worksheet->get_cell(6,6)->value() ne 'is_a_control' ||
                                                                    $worksheet->get_cell(6,7)->value() ne 'rep_number' ||
                                                                    $worksheet->get_cell(6,8)->value() ne 'treatment_name') ) ) {
        $parse_result{'error'} = "Data columns must be in one of these two orders for uploading Subplot phenotypes: 1) subplot_name, plot_name, accession_name, plot_number, block_number, is_a_control, rep_number, treatment_name OR 2) plant_name, subplot_name, plot_name, accession_name, plot_number, block_number, is_a_control, rep_number, treatment_name. Make sure to select the correct data level. It may help to recreate your spreadsheet from the website.";
        print STDERR "Columns not correct and data_level is subplots\n";
        return \%parse_result;
    }

    my @fixed_columns;
    if ($data_level eq 'subplots'){
        if ($name_head eq 'plant_name'){
            @fixed_columns = qw | plant_name subplot_name plot_name accession_name plot_number block_number is_a_control rep_number treatment_name|;
        } elsif ($name_head eq 'subplot_name'){
            @fixed_columns = qw | subplot_name plot_name accession_name plot_number block_number is_a_control rep_number treatment_name|;
        }
    } else {
        if ($name_head eq 'plot_name') {
            @fixed_columns = qw | plot_name accession_name plot_number block_number is_a_control rep_number treatment_name|;
        } elsif ($name_head eq 'plant_name') {
            @fixed_columns = qw | plant_name plot_name accession_name plot_number block_number is_a_control rep_number treatment_name|;
        }
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
    my $timestamp_included = shift;
    my $data_level = shift;
    my $schema = shift;
    my $composable_cvterm_format = shift // 'extended';
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
    my $design_type = $worksheet->get_cell(3,3)->value();

    my @fixed_columns;
    if ($data_level eq 'subplots'){
        if ($name_head eq 'plant_name'){
            @fixed_columns = qw | plant_name subplot_name plot_name accession_name plot_number block_number is_a_control rep_number treatment_name|;
        } elsif ($name_head eq 'subplot_name'){
            @fixed_columns = qw | subplot_name plot_name accession_name plot_number block_number is_a_control rep_number treatment_name|;
        }
    } else {
        if ($name_head eq 'plot_name') {
            @fixed_columns = qw | plot_name accession_name plot_number block_number is_a_control rep_number treatment_name|;
        } elsif ($name_head eq 'plant_name') {
            @fixed_columns = qw | plant_name plot_name accession_name plot_number block_number is_a_control rep_number treatment_name|;
        }
    }
    my $num_fixed_col = scalar(@fixed_columns);
    my $treatment_col = $num_fixed_col - 1;

    my $predefined_columns;
    my $num_predef_col = 0;
    my $json = JSON->new();
    if ($worksheet->get_cell(4,1)) {
      $predefined_columns  = $json->decode($worksheet->get_cell(4,1)->value());
      $num_predef_col = scalar(@$predefined_columns);
    }

    my $num_col_before_traits = $num_fixed_col + $num_predef_col;

    for my $row ( 7 .. $row_max ) {
        my $plot_name;

        if ($worksheet->get_cell($row,0)) {
            $plot_name = $worksheet->get_cell($row,0)->value();
            if (defined($plot_name)){
                if ($plot_name ne ''){
                    $plots_seen{$plot_name} = 1;

                    my @treatments;
                    if($worksheet->get_cell($row,$treatment_col)){
                        if($worksheet->get_cell($row,$treatment_col)->value()){
                            my $val = $worksheet->get_cell($row,$treatment_col)->value();
                            if ($val){
                                push @treatments, $val;
                            }
                        }
                    }

                    for my $col ($num_col_before_traits .. $col_max) {
                        my $trait_name;
                        if ($worksheet->get_cell(6,$col)) {
                            $trait_name = $worksheet->get_cell(6,$col)->value();
                            if (defined($trait_name)) {
                                if ($trait_name ne ''){

                                    if ($num_predef_col > 0) {
                                        my @component_cvterm_ids;
                                        for my $predef_col ($num_fixed_col .. $num_col_before_traits-1) {
                                            if ($worksheet->get_cell($row,$predef_col)){
                                                my $component_term = $worksheet->get_cell($row, $predef_col)->value();
                                                #print STDERR $component_term."\n";
                                                my $component_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $component_term)->cvterm_id();
                                                push @component_cvterm_ids, $component_cvterm_id;
                                            }
                                        }
                                        my $trait_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $trait_name)->cvterm_id();
                                        push @component_cvterm_ids, $trait_cvterm_id;
                                        my $trait_name_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, \@component_cvterm_ids);
                                        $trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $trait_name_cvterm_id, $composable_cvterm_format);
                                    }

                                    $traits_seen{$trait_name} = 1;
                                    my $value_string = '';

                                    if ($worksheet->get_cell($row, $col)){
                                        $value_string = $worksheet->get_cell($row, $col)->value();
                                    }
                                    my ($trait_value, $timestamp) = split /,/, $value_string;
                                    if (!$timestamp) {
                                        $timestamp = '';
                                    }
                                    #print STDERR $trait_value." : ".$timestamp."\n";

                                    if ( defined($trait_value) && defined($timestamp) ) {
                                        if ($trait_value ne '.'){
                                            $data{$plot_name}->{$trait_name} = [$trait_value, $timestamp, \@treatments];
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
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
    #print STDERR Dumper \%parse_result;

    return \%parse_result;
}

1;
