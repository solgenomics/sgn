package CXGN::Phenotypes::ParseUpload::Plugin::PhenotypeSpreadsheet;

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
    my $zipfile = shift; #not relevant for this plugin
    my $nd_protocol_id = shift; #not relevant for this plugin
    my $nd_protocol_filename = shift; #not relevant for this plugin
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
        $parse_result{'error'} = "No design type in header. Make sure you are using the correct spreadsheet format. It may help to recreate your spreadsheet from the website.";
        print STDERR "No design type in header\n";
        return \%parse_result;
    }
    if (!$name_head || ($name_head ne 'plot_name' && $name_head ne 'plant_name' && $name_head ne 'subplot_name' && $name_head ne 'tissue_sample_name')) {
        $parse_result{'error'} = "No plot_name or plant_name or subplot_name or tissue_sample_name in header. Make sure you are using the correct spreadsheet format. It may help to recreate your spreadsheet from the website.";
        print STDERR "No plot_name or plant_name or subplot_name or tissue_sample_name in header\n";
        return \%parse_result;
    }
    if ($data_level eq 'plots' && ( $worksheet->get_cell(6,0)->value() ne 'plot_name' ||
                                    (($worksheet->get_cell(6,1)->value() ne 'accession_name') && ($worksheet->get_cell(6,1)->value() ne 'family_name') && ($worksheet->get_cell(6,1)->value() ne 'cross_unique_id')) ||
                                    $worksheet->get_cell(6,2)->value() ne 'plot_number' ||
                                    $worksheet->get_cell(6,3)->value() ne 'block_number' ||
                                    $worksheet->get_cell(6,4)->value() ne 'is_a_control' ||
                                    $worksheet->get_cell(6,5)->value() ne 'rep_number' ||
                                    $worksheet->get_cell(6,6)->value() ne 'planting_date' ||
                                    $worksheet->get_cell(6,7)->value() ne 'harvest_date' ||
                                    $worksheet->get_cell(6,8)->value() ne 'trial_name' ) ) {
        $parse_result{'error'} = "Data columns must be in this order for uploading Plot phenotypes: 'plot_name', 'accession_name' or 'family_name' or 'cross_unique_id', 'plot_number', 'block_number', 'is_a_control',  'rep_number', 'planting_date', 'harvest_date', 'trial_name'. Make sure to select the correct data level. It may help to recreate your spreadsheet from the website.";
        print STDERR "Columns not correct and data_level is plots\n";
        return \%parse_result;
    }
    if ($data_level eq 'plants' && ($worksheet->get_cell(6,0)->value() ne 'plant_name' ||
                                    $worksheet->get_cell(6,1)->value() ne 'plot_name' ||
                                    (($worksheet->get_cell(6,2)->value() ne 'accession_name') && ($worksheet->get_cell(6,2)->value() ne 'family_name') && ($worksheet->get_cell(6,2)->value() ne 'cross_unique_id')) ||
                                    $worksheet->get_cell(6,3)->value() ne 'plot_number' ||
                                    $worksheet->get_cell(6,4)->value() ne 'block_number' ||
                                    $worksheet->get_cell(6,5)->value() ne 'is_a_control' ||
                                    $worksheet->get_cell(6,6)->value() ne 'rep_number' ||
                                    $worksheet->get_cell(6,7)->value() ne 'planting_date' ||
                                    $worksheet->get_cell(6,8)->value() ne 'harvest_date' ||
                                    $worksheet->get_cell(6,9)->value() ne 'trial_name') ) {
        $parse_result{'error'} = "Data columns must be in this order for uploading Plant phenotypes: 'plant_name', 'plot_name', 'accession_name' or 'family_name' or 'cross_unique_id', 'plot_number', 'block_number', 'is_a_control', 'rep_number', 'planting_date', 'harvest_date', 'trial_name'. Make sure to select the correct data level. It may help to recreate your spreadsheet from the website.";
        print STDERR "Columns not correct and data_level is plants\n";
        return \%parse_result;
    }
    if ($data_level eq 'tissue_samples' && ($worksheet->get_cell(6,0)->value() ne 'tissue_sample_name' ||
                                    $worksheet->get_cell(6,1)->value() ne 'plant_name' ||
                                    $worksheet->get_cell(6,2)->value() ne 'plot_name' ||
                                    (($worksheet->get_cell(6,3)->value() ne 'accession_name') && ($worksheet->get_cell(6,3)->value() ne 'family_name') && ($worksheet->get_cell(6,3)->value() ne 'cross_unique_id')) ||
                                    $worksheet->get_cell(6,4)->value() ne 'plot_number' ||
                                    $worksheet->get_cell(6,5)->value() ne 'block_number' ||
                                    $worksheet->get_cell(6,6)->value() ne 'is_a_control' ||
                                    $worksheet->get_cell(6,7)->value() ne 'rep_number' ||
                                    $worksheet->get_cell(6,8)->value() ne 'planting_date' ||
                                    $worksheet->get_cell(6,9)->value() ne 'harvest_date' ||
                                    $worksheet->get_cell(6,10)->value() ne 'trial_name') ) {
        $parse_result{'error'} = "Data columns must be in this order for uploading Tissue Sample phenotypes: 'tissue_sample_name', 'plant_name', 'plot_name', 'accession_name' or 'family_name' or 'cross_unique_id', 'plot_number', 'block_number', 'is_a_control', 'rep_number', 'planting_date', 'harvest_date', 'trial_name'. Make sure to select the correct data level. It may help to recreate your spreadsheet from the website.";
        print STDERR "Columns not correct and data_level is tissue_samples\n";
        return \%parse_result;
    }
    if ($data_level eq 'subplots' && ( ($worksheet->get_cell(6,0)->value() ne 'subplot_name' ||
                                    $worksheet->get_cell(6,1)->value() ne 'plot_name' ||
                                    (($worksheet->get_cell(6,2)->value() ne 'accession_name') && ($worksheet->get_cell(6,2)->value() ne 'family_name') && ($worksheet->get_cell(6,2)->value() ne 'cross_unique_id')) ||
                                    $worksheet->get_cell(6,3)->value() ne 'plot_number' ||
                                    $worksheet->get_cell(6,4)->value() ne 'block_number' ||
                                    $worksheet->get_cell(6,5)->value() ne 'is_a_control' ||
                                    $worksheet->get_cell(6,6)->value() ne 'rep_number' ||
                                    $worksheet->get_cell(6,7)->value() ne 'planting_date' ||
                                    $worksheet->get_cell(6,8)->value() ne 'harvest_date' ||
                                    $worksheet->get_cell(6,9)->value() ne 'trial_name') && ($worksheet->get_cell(6,0)->value() ne 'plant_name' ||
                                                                    $worksheet->get_cell(6,1)->value() ne 'subplot_name' ||
                                                                    $worksheet->get_cell(6,2)->value() ne 'plot_name' ||
                                                                    (($worksheet->get_cell(6,3)->value() ne 'accession_name') && ($worksheet->get_cell(6,3)->value() ne 'family_name') && ($worksheet->get_cell(6,3)->value() ne 'cross_unique_id')) ||
                                                                    $worksheet->get_cell(6,4)->value() ne 'plot_number' ||
                                                                    $worksheet->get_cell(6,5)->value() ne 'block_number' ||
                                                                    $worksheet->get_cell(6,6)->value() ne 'is_a_control' ||
                                                                    $worksheet->get_cell(6,7)->value() ne 'rep_number' ||
                                                                    $worksheet->get_cell(6,8)->value() ne 'planting_date' ||
                                                                    $worksheet->get_cell(6,9)->value() ne 'harvest_date' ||
                                                                    $worksheet->get_cell(6,10)->value() ne 'trial_name') ) ) {
        $parse_result{'error'} = "Data columns must be in one of these two orders for uploading Subplot phenotypes: 1) 'subplot_name', 'plot_name', 'accession_name' or 'family_name' or 'cross_unique_id', 'plot_number', 'block_number', 'is_a_control', 'rep_number', 'planting_date', 'harvest_date', 'trial_name' OR 2) 'plant_name', 'subplot_name', 'plot_name', 'accession_name' or 'family_name' or 'cross_unique_id', 'plot_number', 'block_number', 'is_a_control', 'rep_number', 'planting_date', 'harvest_date', 'trial_name'. Make sure to select the correct data level. It may help to recreate your spreadsheet from the website.";
        print STDERR "Columns not correct and data_level is subplots\n";
        return \%parse_result;
    }

    my @fixed_columns;
    if ($data_level eq 'subplots'){
        if ($name_head eq 'plant_name'){
            @fixed_columns = qw | plant_name subplot_name plot_name accession_name plot_number block_number is_a_control rep_number planting_date harvest_date trial_name |;
        } elsif ($name_head eq 'subplot_name'){
            @fixed_columns = qw | subplot_name plot_name accession_name plot_number block_number is_a_control rep_number planting_date harvest_date trial_name |;
        }
    } else {
        if ($name_head eq 'plot_name') {
            @fixed_columns = qw | plot_name accession_name plot_number block_number is_a_control rep_number planting_date harvest_date trial_name |;
        } elsif ($name_head eq 'plant_name') {
            @fixed_columns = qw | plant_name plot_name accession_name plot_number block_number is_a_control rep_number planting_date harvest_date trial_name |;
        } elsif ($name_head eq 'tissue_sample_name') {
            @fixed_columns = qw | tissue_sample_name plant_name plot_name accession_name plot_number block_number is_a_control rep_number planting_date harvest_date trial_name |;
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
            my $timestamp = '';
            if ($worksheet->get_cell($row,$col)) {
                $value_string = $worksheet->get_cell($row,$col)->value();
                #print STDERR $value_string."\n";
                if ($timestamp_included) {
                    ($value, $timestamp) = split /,/, $value_string;
                    if (!$timestamp =~ m/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})(\S)(\d{4})/) {
                        $parse_result{'error'} = "Timestamp needs to be of form YYYY-MM-DD HH:MM:SS-0000 or YYYY-MM-DD HH:MM:SS+0000";
                        print STDERR "value: $timestamp\n";
                        return \%parse_result;
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
    my $zipfile = shift; #not relevant for this plugin
    my $user_id = shift; #not relevant for this plugin
    my $c = shift; #not relevant for this plugin
    my $nd_protocol_id = shift; #not relevant for this plugin
    my $nd_protocol_filename = shift; #not relevant for this plugin

    my $composable_cvterm_format = $c ? $c->config->{composable_cvterm_format} : 'extended';
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
            @fixed_columns = qw | plant_name subplot_name plot_name accession_name plot_number block_number is_a_control rep_number planting_date harvest_date trial_name |;
        } elsif ($name_head eq 'subplot_name'){
            @fixed_columns = qw | subplot_name plot_name accession_name plot_number block_number is_a_control rep_number planting_date harvest_date trial_name |;
        }
    } else {
        if ($name_head eq 'plot_name') {
            @fixed_columns = qw | plot_name accession_name plot_number block_number is_a_control rep_number planting_date harvest_date trial_name |;
        } elsif ($name_head eq 'plant_name') {
            @fixed_columns = qw | plant_name plot_name accession_name plot_number block_number is_a_control rep_number planting_date harvest_date trial_name |;
        } elsif ($name_head eq 'tissue_sample_name') {
            @fixed_columns = qw | tissue_sample_name plant_name plot_name accession_name plot_number block_number is_a_control rep_number planting_date harvest_date trial_name |;
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
    print STDERR Dumper $num_col_before_traits;
    my %composed_trait_name_map;

    for my $row ( 7 .. $row_max ) {
        my $plot_name;

        if ($worksheet->get_cell($row,0)) {
            $plot_name = $worksheet->get_cell($row,0)->value();
            if (defined($plot_name)){
                if ($plot_name ne ''){
                    $plots_seen{$plot_name} = 1;

                    for my $col ($num_col_before_traits .. $col_max) {
                        my $trait_name;
                        if ($worksheet->get_cell(6,$col)) {
                            $trait_name = $worksheet->get_cell(6,$col)->value();
                            if (defined($trait_name)) {
                                if ($trait_name ne ''){
				    if ($num_predef_col > 0) {
					my @component_cvterm_names = ($trait_name);
					for my $predef_col ($num_fixed_col .. $num_col_before_traits-1) {
					    if ($worksheet->get_cell($row,$predef_col)){
						my $component_term = $worksheet->get_cell($row, $predef_col)->value();
						push @component_cvterm_names, $component_term;
					    }
				        }
					my $trait_name_composed = join "\|\|", @component_cvterm_names;
					if (exists($composed_trait_name_map{$trait_name_composed})) {
					    $trait_name = $composed_trait_name_map{$trait_name_composed};
					}
					else {
					    my @component_cvterm_ids;
					    foreach my $component_term (@component_cvterm_names) {
						my $component_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, $component_term)->cvterm_id();
						push @component_cvterm_ids, $component_cvterm_id;
					    }
					    my $trait_name_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, \@component_cvterm_ids);
					    $trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $trait_name_cvterm_id, $composable_cvterm_format);
					    print STDERR Dumper $trait_name_composed;
					    if (!$trait_name) {
						my $term_check = SGN::Model::Cvterm->get_cvterm_row($schema, $trait_name_composed, 'postcomposed_terms');
						$trait_name = $term_check ? $term_check->name() : undef;
					    }
					    if (!$trait_name) {
						my $term_check = SGN::Model::Cvterm->get_cvterm_row($schema, $trait_name_composed, 'composed_trait');
						$trait_name = $term_check ? $term_check->name() : undef;
					    }
					    $composed_trait_name_map{$trait_name_composed} = $trait_name;
					}
				    }

				    print STDERR Dumper $trait_name;
				    if (!$trait_name){ die; }
                                    $traits_seen{$trait_name} = 1;
                                    my $value_string = '';

                                    if ($worksheet->get_cell($row, $col)){
                                        $value_string = $worksheet->get_cell($row, $col)->value();
                                    }
                                    my $timestamp = '';
                                    my $trait_value = '';
                                    if ($timestamp_included){
                                        ($trait_value, $timestamp) = split /,/, $value_string;
                                    } else {
                                        $trait_value = $value_string;
                                    }
                                    if (!defined($timestamp)){
                                        $timestamp = '';
                                    }
                                    #print STDERR $trait_value." : ".$timestamp."\n";

                                    if ( defined($trait_value) && defined($timestamp) ) {
                                        if ($trait_value ne '.'){
                                            $data{$plot_name}->{$trait_name} = [$trait_value, $timestamp];
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
    $parse_result{'units'} = \@plots;
    $parse_result{'variables'} = \@traits;
    #print STDERR Dumper \%parse_result;

    return \%parse_result;
}

1;
