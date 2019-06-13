package CXGN::Phenotypes::ParseUpload::Plugin::ScioSpreadsheetNIRS;

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
    return "scio spreadsheet nirs";
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

    #modify to reflect scio format

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
        $parse_result{'error'} = "No data found in spreadsheet.";
        print STDERR "No data found in spreadsheet\n";
        return \%parse_result;
    }

    if ($worksheet->get_cell(0,0)->value() ne 'name' ) {
        $parse_result{'error'} = "First cell must be 'name'. Is this a NIRS spreadhseet formatted by SCiO?";
        print STDERR "First cell must be 'name'\n";
        return \%parse_result;
    }
    # my @fixed_columns = qw | observationunit_name |;
    # my $num_fixed_col = scalar(@fixed_columns);
    #
    # for (my $row=1; $row<$row_max; $row++) {
    #     for (my $col=$num_fixed_col; $col<=$col_max; $col++) {
    #         my $value_string = '';
    #         my $value = '';
    #         my $timestamp = '';
    #         if ($worksheet->get_cell($row,$col)) {
    #             $value_string = $worksheet->get_cell($row,$col)->value();
    #             #print STDERR $value_string."\n";
    #             if ($timestamp_included) {
    #                 ($value, $timestamp) = split /,/, $value_string;
    #                 if (!$timestamp =~ m/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})(\S)(\d{4})/) {
    #                     $parse_result{'error'} = "Timestamp needs to be of form YYYY-MM-DD HH:MM:SS-0000 or YYYY-MM-DD HH:MM:SS+0000";
    #                     print STDERR "value: $timestamp\n";
    #                     return \%parse_result;
    #                 }
    #             }
    #         }
    #     }
    # }

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
    my %observationunits_seen;
    my %traits_seen;
    my @observation_units;
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
    }

    $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();

    #my @fixed_columns = qw | observationunit_name |;
    #my $num_fixed_col = scalar(@fixed_columns);
    my %metadata_hash;
    my $observation_column_index;

    for my $row ( 0 .. 9 ) { #get metadata
        my $key = $worksheet->get_cell($row,0)->value();
        my $value = $worksheet->get_cell($row,1)->value();
        $metadata_hash{$key} = {$value};
    }
    for my $col (0 .. $col_max) {
        my $field = $worksheet->get_cell(10,$col)->value();
        if ($field eq 'User_input_id') {
            $observation_column_index = $col;
            last;
        }
    }

    for my $row ( 12 .. $row_max ) {# get data
        #if ($worksheet->get_cell($row,0)) {
            my $observationunit_name = $worksheet->get_cell($row,$observation_column_index)->value();
            if (defined($observationunit_name)){
                if ($observationunit_name ne ''){
                    $observationunits_seen{$observationunit_name} = 1;
                    #add metadata to nirs not nested

                    #$data{$observationunit_name}->{'nirs'} = (%metadata_hash);
                    #print STDERR "Hash so far is ".Dumper($data{$observationunit_name}->{'nirs'});

                    for my $col (0 .. $col_max) {
                        my $column_name;
                        my $seen_spectra;
                        if ($worksheet->get_cell(10,$col)) {
                            $column_name = $worksheet->get_cell(10,$col)->value();
                            if (defined($column_name)) {
                                print STDERR "Column name is $column_name\n";
                                if ($column_name ne '' && $column_name !~ /spectrum/){ #check if not spectra, if not spectra add to {'nirs'} not nested. if have already seen spectra, last
                                    if ($seen_spectra) {
                                        last;
                                    }

                                    my $metadata_value = '';
                                    if ($worksheet->get_cell($row, $col)){
                                        $metadata_value = $worksheet->get_cell($row, $col)->value();
                                    }
                                    $data{$observationunit_name}->{'nirs'}->{$column_name} = $metadata_value;
                                }
                                elsif ($column_name ne '' && $column_name =~ /spectrum/){
                                    #if spectra, strip tex, do sum, and add to {'nirs'} nested, and set flag that have seen spectra
                                    print STDERR "Processing $column_name\n";
                                    my @parts = split /[_+]+/, $column_name;
                                    my $wavelength = $parts[2] + $parts[1];
                                    my $nir_value = '';

                                    if ($worksheet->get_cell($row, $col)){
                                        $nir_value = $worksheet->get_cell($row, $col)->value();
                                    }

                                    if ( defined($nir_value) && $nir_value ne '.') {
                                        $data{$observationunit_name}->{'nirs'}->{'spectra'}->{$wavelength} = $nir_value;
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
