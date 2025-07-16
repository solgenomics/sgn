package CXGN::Location::ParseUpload::Plugin::LocationsExcelFormat;

use Moose;
use CXGN::Location;
use Spreadsheet::ParseExcel;
use Spreadsheet::ParseXLSX;
use JSON;
use Data::Dumper;

#
# DEPRECATED
# This plugin has been replaced by the LocationsGeneric plugin
#

sub name {
    return "location excel";
}

sub parse {
    my $self = shift;
    my $filename = shift;
    my $schema = shift;

    # Match a dot, extension .xls / .xlsx
    my ($extension) = $filename =~ /(\.[^.]+)$/;
    my $parser;

    if ($extension eq '.xlsx') {
        $parser = Spreadsheet::ParseXLSX->new();
    }
    else {
        $parser = Spreadsheet::ParseExcel->new();
    }

    my $check = CXGN::Location->new({ bcs_schema => $schema });
    my (@errors, @rows, %parse_result);

    #try to open the excel file and report any errors
    my $excel_obj = $parser->parse($filename);
    if ( !$excel_obj ) {
        print STDERR "parse error: ".$parser->error()."\n";
        push @errors, $parser->error();
        $parse_result{'error'} = \@errors;
        return \%parse_result;
    }

    my $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();
    if (($col_max - $col_min)  < 1 || ($row_max - $row_min) < 1 ) { #must have header with at least plot_name and one trait, as well as one row of phenotypes
        print STDERR "Location file is missing header and/or location data";
        push @errors, "Location file is missing header and/or location data";
        $parse_result{'error'} = \@errors;
        return \%parse_result;
    }

    for my $row ( 1 .. $row_max ) {
        my $row_num = $row+1;
        our($name,$abbreviation,$country_code,$country_name,$program,$type,$latitude,$longitude,$altitude,$noaa_station_id) = undef;

        # check that name is defined and isn't already in database
        if ($worksheet->get_cell($row,0)) {
          $name = $worksheet->get_cell($row,0)->value();
          $name =~ s/^\s+|\s+$//g;
        }
        if (!$name) {
            push @errors, "Row $row_num, column A: Name is undefined.\n";
        }
        elsif (!$check->_is_valid_name($name)) {
            push @errors, "Row $row_num, column A: Name $name already exists in the database.\n";
        }

        # check that abbreviation is defined and isn't already in database
        if ($worksheet->get_cell($row,1)) {
          $abbreviation = $worksheet->get_cell($row,1)->value();
          $abbreviation =~ s/^\s+|\s+$//g;
        }
        if (!$abbreviation) {
            push @errors, "Row $row_num, column B: Abbreviation is undefined.\n";
        }
        elsif (!$check->_is_valid_abbreviation($abbreviation)) {
            push @errors, "Row $row_num, column B: Abbreviation $abbreviation already exists in the database.\n";
        }

        # check is defined, is all uppercase letters, and is 3 chars long
        if ($worksheet->get_cell($row,2)) {
          $country_code = $worksheet->get_cell($row,2)->value();
        }
        if (!$country_code) {
            push @errors, "Row $row_num, column C: Country code is undefined.\n";
        }
        elsif (($country_code !~ m/^[^a-z]*$/) || (length($country_code) != 3 )) {
            push @errors, "Row $row_num, column C: Country code $country_code is not a valid ISO Alpha-3 code.\n";
        }

        # check is defined and is not numeric
        if ($worksheet->get_cell($row,3)) {
          $country_name = $worksheet->get_cell($row,3)->value();
        }
        if (!$country_name) {
            push @errors, "Row $row_num, column D: Country name is undefined.\n";
        }
        elsif ($country_name =~ m/[0-9]/) {
            push @errors, "Row $row_num, column D: Country name $country_name is not a valid ISO standard country name.\n";
        }

        # check is defined, is in database
        if ($worksheet->get_cell($row,4)) {
          $program = $worksheet->get_cell($row,4)->value();
        }
        if (!$program) {
            push @errors, "Row $row_num, column E: Program is undefined.\n";
        }

        #split on comma and test each individual program
        my @programs = split ("&", $program);
        foreach my $bp (@programs) {
            $bp =~ s/^\s+|\s+$//g; #trim whitespace
            if (!$check->_is_valid_program($bp)) {
                push @errors, "Row $row_num, column E: Program $bp does not exist in the database.\n";
            }
        }

        # check is defined, is one of approved types
        if ($worksheet->get_cell($row,5)) {
          $type = $worksheet->get_cell($row,5)->value();
          $type =~ s/^\s+|\s+$//g;
        }
        if (!$type) {
            push @errors, "Row $row_num, column F: Type is undefined.\n";
        }
        elsif(!$check->_is_valid_type($type)) {
            push @errors, "Row $row_num, column F: Type $type is is not a valid location type.\n";
        }

        # check has length, is number between 90 and -90
        if ($worksheet->get_cell($row,6)) {
          $latitude = $worksheet->get_cell($row,6)->value();
        }
        if (! length $latitude) { # check is defined, is number between 90 and -90
            push @errors, "Row $row_num, column G: Latitude is undefined.\n";
        }
        elsif( ($latitude !~ /^-?[0-9.]+$/) || ($latitude < -90) || ($latitude > 90) ) {
            push @errors, "Row $row_num, column G: Latitude $latitude is not a number between 90 and -90.\n";
        }

        # check has length, is number between 180 and -180
        if ($worksheet->get_cell($row,7)) {
          $longitude = $worksheet->get_cell($row,7)->value();
        }
        if (! length $longitude) {
            push @errors, "Row $row_num, column H: Longitude is undefined.\n";
        }
        elsif( ($longitude !~ /^-?[0-9.]+$/) || ($longitude < -180) || ($longitude > 180) ) {
            push @errors, "Row $row_num, column H: Latitude $latitude is not a number between 180 and -180.\n";
        }

        # check has length, is number between -418 and 8,848
        if ($worksheet->get_cell($row,8)) {
          $altitude = $worksheet->get_cell($row,8)->value();
        }
        if (! length $altitude) {
            push @errors, "Row $row_num, column I: Altitude is undefined.\n";
        }
        elsif( ($altitude !~ /^-?[0-9.]+$/) || ($altitude < -418) || ($altitude > 8848) ) {
            push @errors, "Row $row_num, column I: Altitude $altitude is not a number between -418 (Dead Sea) and 8,848 (Mt. Everest).\n";
        }

        if ($worksheet->get_cell($row,9)) {
            $noaa_station_id = $worksheet->get_cell($row,9)->value();
        }
        # if (!$noaa_station_id) {
        #     push @errors, "Row $row_num, column J: NOAA Station ID is undefined.\n";
        # }

        print STDERR "Row is $name, $abbreviation, $country_code, $country_name, $program, $type, $latitude, $longitude, $altitude, $noaa_station_id\n";
        push @rows, [$name,$abbreviation,$country_code,$country_name,$program,$type,$latitude,$longitude,$altitude,$noaa_station_id];
    }

    if (scalar @errors > 0) {
        $parse_result{'error'} = \@errors;
    }
    else {
        print STDERR "Parsed file with no errors, returning with valid new location data.\n";
        $parse_result{'success'} = \@rows;
    }
    return \%parse_result;
}
#
# sub _is_valid_name {
#     # my $self = shift;
#     my $name = shift;
#     my $schema = shift;
#     my $existing_name_count = $schema->resultset('NaturalDiversity::NdGeolocation')->search( { description => $name } )->count();
#     if ($existing_name_count > 0) {
#         return 0;
#     }
#     else {
#         return 1;
#     }
# }
#
# sub _is_valid_abbreviation {
#     # my $self = shift;
#     my $abbreviation = shift;
#     my $schema = shift;
#     my $existing_abbreviation_count = $schema->resultset('NaturalDiversity::NdGeolocationprop')->search( { value => $abbreviation } )->count();
#     if ($existing_abbreviation_count > 0) {
#         return 0;
#     }
#     else {
#         return 1;
#     }
# }
#
# sub _is_valid_program {
#     # my $self = shift;
#     my $program = shift;
#     my $schema = shift;
#     my $existing_program_count = $schema->resultset('Project::Project')->search(
#         {
#             'type.name'=> 'breeding_program',
#             'me.name' => $program
#         },
#         {
#             join => {
#                 'projectprops' =>
#                 'type'
#             }
#         }
#     )->count();
#     if ($existing_program_count < 1) {
#         return 0;
#     }
#     else {
#         return 1;
#     }
# }
#
# sub _is_valid_type {
#     # my $self = shift;
#     my $type = shift;
#     my %valid_types = (
#         Farm => 1,
#         Field => 1,
#         Greenhouse => 1,
#         Screenhouse => 1,
#         Lab => 1,
#         Storage => 1,
#         Other => 1
#     );
#     if (!$valid_types{$type}) {
#         return 0;
#     }
#     else {
#         return 1;
#     }
# }

1;
