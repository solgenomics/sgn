package CXGN::Location::ParseUpload::Plugin::LocationsExcelFormat;

use Moose;
#use File::Slurp;
use Spreadsheet::ParseExcel;
use JSON;
use Data::Dumper;

sub name {
    return "location excel";
}
# 
# sub validate {
#     my $self = shift;
#     my $filename = shift;
#     my $schema = shift;
#     my $parser   = Spreadsheet::ParseExcel->new();
#     my (@errors, %validate_result);
#
#     #try to open the excel file and report any errors
#     my $excel_obj = $parser->parse($filename);
#     if ( !$excel_obj ) {
#         print STDERR "validate error: ".$parser->error()."\n";
#         push @errors, $parser->error();
#         $validate_result{'error'} = \@errors;
#         return \%validate_result;
#     }
#
#     my $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
#     my ( $row_min, $row_max ) = $worksheet->row_range();
#     my ( $col_min, $col_max ) = $worksheet->col_range();
#     if (($col_max - $col_min)  < 1 || ($row_max - $row_min) < 1 ) { #must have header with at least plot_name and one trait, as well as one row of phenotypes
#         print STDERR "Location file is missing header and/or location data";
#         push @errors, "Location file is missing header and/or location data";
#         $validate_result{'error'} = \@errors;
#         return \%validate_result;
#     }
#     for my $row ( 1 .. $row_max ) {
#         my $row_num = $row+1;
#         our($name,$abbreviation,$country_code,$country_name,$program,$type,$latitude,$longitude,$altitude) = undef;
#         if ($worksheet->get_cell($row,0)) {
#           $name = $worksheet->get_cell($row,0)->value();
#         }
#         if (!$name) { # check is defined and isn't already in database
#             push @errors, "Name $name is undefined at row $row_num, column A.\n";
#             # print STDERR $validate_result{'error'};
#             # return \%validate_result;
#         }
#         if ($worksheet->get_cell($row,1)) {
#           $abbreviation = $worksheet->get_cell($row,1)->value();
#         }
#         if (!$abbreviation) { # check is defined and isn't already in database
#             push @errors, "Abbreviation $abbreviation is undefined at row $row_num, column B.\n";
#             # print STDERR $validate_result{'error'};
#             # return \%validate_result;
#         }
#         if ($worksheet->get_cell($row,2)) {
#           $country_code = $worksheet->get_cell($row,2)->value();
#         }
#         if (!$country_code) { # check is defined and is valid ISO code
#             push @errors, "Country code $country_code is undefined at row $row_num, column C.\n";
#             # print STDERR $validate_result{'error'};
#             # return \%validate_result;
#         }
#         if ($worksheet->get_cell($row,3)) {
#           $country_name = $worksheet->get_cell($row,3)->value();
#         }
#         if (!$country_name) { # check is defined and is valid country name
#             push @errors, "Country name $country_name is undefined at row $row_num, column D.\n";
#             # print STDERR $validate_result{'error'};
#             # return \%validate_result;
#         }
#         if ($worksheet->get_cell($row,4)) {
#           $program = $worksheet->get_cell($row,4)->value();
#         }
#         if (!$program) { # check is defined, is in database
#             push @errors, "Program $program is undefined at row $row_num, column E.\n";
#             # print STDERR $validate_result{'error'};
#             # return \%validate_result;
#         }
#         if ($worksheet->get_cell($row,5)) {
#           $type = $worksheet->get_cell($row,5)->value();
#         }
#         if (!$type) { # check is defined, is one of approved types
#             push @errors, "Type $type is undefined at row $row_num, column F.\n";
#             # print STDERR $validate_result{'error'};
#             # return \%validate_result;
#         }
#         if ($worksheet->get_cell($row,6)) {
#           $latitude = $worksheet->get_cell($row,6)->value();
#         }
#         if (!$latitude) { # check is defined, is number between 90 and -90
#             push @errors, "Latitude $latitude is undefined at row $row_num, column G.\n";
#             # print STDERR $validate_result{'error'};
#             # return \%validate_result;
#         }
#         if ($worksheet->get_cell($row,7)) {
#           $longitude = $worksheet->get_cell($row,7)->value();
#         }
#         if (!$longitude) { # check is defined, is number between 180 and -180
#             push @errors, "Longitude $longitude is undefined at row $row_num, column H.\n";
#             # print STDERR $validate_result{'error'};
#             # return \%validate_result;
#         }
#         if ($worksheet->get_cell($row,8)) {
#           $altitude = $worksheet->get_cell($row,8)->value();
#         }
#         if (!$altitude) { # check is defined, is number between -418 and 8,848
#             push @errors, "Altitude $altitude is undefined at row $row_num, column I.\n";
#             # print STDERR $validate_result{'error'};
#             # return \%validate_result;
#         }
#         # print STDERR "Validated row is $name, $abbreviation, $country_code, $country_name, $program, $type, $latitude, $longitude, $altitude\n";
#     }
#     if (scalar @errors > 0) {
#         $validate_result{'error'} = \@errors;
#     }
#     else {
#         print STDERR "Validation passed with no errors.\n";
#         $validate_result{'success'} = 1;
#     }
#     return \%validate_result;
# }

sub parse {
    my $self = shift;
    my $filename = shift;
    my $schema = shift;
    my $parser   = Spreadsheet::ParseExcel->new();
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
        our($name,$abbreviation,$country_code,$country_name,$program,$type,$latitude,$longitude,$altitude) = undef;
        if ($worksheet->get_cell($row,0)) {
          $name = $worksheet->get_cell($row,0)->value();
        }
        if (!$name) { # check is defined and isn't already in database
            push @errors, "Name $name is undefined at row $row_num, column A.\n";
        }
        if ($worksheet->get_cell($row,1)) {
          $abbreviation = $worksheet->get_cell($row,1)->value();
        }
        if (!$abbreviation) { # check is defined and isn't already in database
            push @errors, "Abbreviation $abbreviation is undefined at row $row_num, column B.\n";
        }
        if ($worksheet->get_cell($row,2)) {
          $country_code = $worksheet->get_cell($row,2)->value();
        }
        if (!$country_code) { # check is defined and is valid ISO code
            push @errors, "Country code $country_code is undefined at row $row_num, column C.\n";
        }
        if ($worksheet->get_cell($row,3)) {
          $country_name = $worksheet->get_cell($row,3)->value();
        }
        if (!$country_name) { # check is defined and is valid country name
            push @errors, "Country name $country_name is undefined at row $row_num, column D.\n";
        }
        if ($worksheet->get_cell($row,4)) {
          $program = $worksheet->get_cell($row,4)->value();
        }
        if (!$program) { # check is defined, is in database
            push @errors, "Program $program is undefined at row $row_num, column E.\n";
        }
        if ($worksheet->get_cell($row,5)) {
          $type = $worksheet->get_cell($row,5)->value();
        }
        if (!$type) { # check is defined, is one of approved types
            push @errors, "Type $type is undefined at row $row_num, column F.\n";
        }
        if ($worksheet->get_cell($row,6)) {
          $latitude = $worksheet->get_cell($row,6)->value();
        }
        if (!$latitude) { # check is defined, is number between 90 and -90
            push @errors, "Latitude $latitude is undefined at row $row_num, column G.\n";
        }
        if ($worksheet->get_cell($row,7)) {
          $longitude = $worksheet->get_cell($row,7)->value();
        }
        if (!$longitude) { # check is defined, is number between 180 and -180
            push @errors, "Longitude $longitude is undefined at row $row_num, column H.\n";
        }
        if ($worksheet->get_cell($row,8)) {
          $altitude = $worksheet->get_cell($row,8)->value();
        }
        if (!$altitude) { # check is defined, is number between -418 and 8,848
            push @errors, "Altitude $altitude is undefined at row $row_num, column I.\n";
        }
        print STDERR "Row is $name, $abbreviation, $country_code, $country_name, $program, $type, $latitude, $longitude, $altitude\n";
        push @rows, [$name,$abbreviation,$country_code,$country_name,$program,$type,$latitude,$longitude,$altitude];
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

1;
