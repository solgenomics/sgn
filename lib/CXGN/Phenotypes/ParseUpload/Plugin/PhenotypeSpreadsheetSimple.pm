package CXGN::Phenotypes::ParseUpload::Plugin::PhenotypeSpreadsheetSimple;

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
use JSON;
use Data::Dumper;


#
# DEPRECATED: This plugin has been replaced by the PhenotypeSpreadsheetSimpleGeneric plugin
#


my @oun_columns = ("observationunit_name", "plot_name", "subplot_name", "plant_name", "observationUnitName", "plotName", "subplotName", "plantName");
my %oun_columns_map = map { $_ => 1 } @oun_columns;

sub name {
    return "phenotype spreadsheet simple";
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

    $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();
    if (($col_max - $col_min)  < 1 || ($row_max - $row_min) < 1 ) { #must have header with at least observationunit_name and one trait, as well as one row of phenotypes
        $parse_result{'error'} = "Spreadsheet is missing observationunit_name and at least one trait in header.";
        print STDERR "Spreadsheet is missing header\n";
        return \%parse_result;
    }

    # check if the first column is one of the supported variations of observationunit_name
    if ( !exists($oun_columns_map{$worksheet->get_cell(0,0)->value()}) ) {
        $parse_result{'error'} = "First column must be one of: '" . join("', '", @oun_columns) . "'. It may help to recreate your spreadsheet from the website.";
        print STDERR "Columns not correct\n";
        return \%parse_result;
    }
    my @fixed_columns = ( $worksheet->get_cell(0,0)->value() );
    my $num_fixed_col = scalar(@fixed_columns);

    for (my $row=1; $row<$row_max; $row++) {
        for (my $col=$num_fixed_col; $col<=$col_max; $col++) {
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
    my %parse_result;
    my @file_lines;
    my $delimiter = ',';
    my $header;
    my @header_row;
    my $header_column_number = 0;
    my %header_column_info; #column numbers of key info indexed from 0;
    my %observationunits_seen;
    my %traits_seen;
    my @observation_units;
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
        print STDERR "validate error: ".$parser->error()."\n";
        return \%parse_result;
    }

    $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();

    my @fixed_columns = ( $worksheet->get_cell(0,0)->value() );
    my $num_fixed_col = scalar(@fixed_columns);

    for my $row ( 1 .. $row_max ) {
        my $observationunit_name;

        if ($worksheet->get_cell($row,0)) {
            $observationunit_name = $worksheet->get_cell($row,0)->value();
            if (defined($observationunit_name)){
                if ($observationunit_name ne ''){
                    $observationunits_seen{$observationunit_name} = 1;

                    for my $col ($num_fixed_col .. $col_max) {
                        my $trait_name;
                        if ($worksheet->get_cell(0,$col)) {
                            $trait_name = $worksheet->get_cell(0,$col)->value();
                            if (defined($trait_name)) {
                                if ($trait_name ne ''){

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
                                            ### for multiple values or time series, need to store all the values
                                            push @{$data{$observationunit_name}->{$trait_name} }, [$trait_value, $timestamp];
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

    foreach my $obs (sort keys %observationunits_seen) {
        push @observation_units, $obs;
    }
    foreach my $trait (sort keys %traits_seen) {
        push @traits, $trait;
    }

    $parse_result{'data'} = \%data;
    $parse_result{'units'} = \@observation_units;
    $parse_result{'variables'} = \@traits;
    #print STDERR Dumper \%parse_result;

    return \%parse_result;
}

1;
