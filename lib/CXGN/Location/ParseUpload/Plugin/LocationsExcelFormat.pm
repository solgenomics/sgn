package CXGN::Location::ParseUpload::Plugin::LocationsExcelFormat;

use Moose;
#use File::Slurp;
use Spreadsheet::ParseExcel;
use JSON;
use Data::Dumper;

sub name {
    return "location excel";
}

sub validate {
    my $self = shift;
    my $filename = shift;
    my $schema = shift;
    my $parser   = Spreadsheet::ParseExcel->new();
    my %validate_result;

    #try to open the excel file and report any errors
    my $excel_obj = $parser->parse($filename);
    if ( !$excel_obj ) {
        $validate_result{'error'} = $parser->error();
        print STDERR "validate error: ".$parser->error()."\n";
        return \%validate_result;
    }

    my $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();
    if (($col_max - $col_min)  < 1 || ($row_max - $row_min) < 1 ) { #must have header with at least plot_name and one trait, as well as one row of phenotypes
        $validate_result{'error'} = "Location file is missing header and/or location data";
        print STDERR $validate_result{'error'};
        return \%validate_result;
    }

    for my $row ( 1 .. $row_max ) {
        my $name = $worksheet->get_cell($row,0)->value();
        if (!$name) { # check is defined and isn't already in database
            $validate_result{'error'} = "Name $name is undefined at row $row, column 1.\n";
            print STDERR $validate_result{'error'};
            return \%validate_result;
        }
        my $abbreviation = $worksheet->get_cell($row,1)->value();
        if (!$abbreviation) { # check is defined and isn't already in database
            $validate_result{'error'} = "Abbreviation $abbreviation is undefined at row $row, column 2.\n";
            print STDERR $validate_result{'error'};
            return \%validate_result;
        }
        my $country = $worksheet->get_cell($row,2)->value();
        if (!$country) { # check is defined and is valid ISO code, use to retrieve country name
            $validate_result{'error'} = "Country $country is undefined at row $row, column 3.\n";
            print STDERR $validate_result{'error'};
            return \%validate_result;
        }
        my $program = $worksheet->get_cell($row,3)->value();
        if (!$program) { # check is defined, is in database
            $validate_result{'error'} = "Program $program is undefined at row $row, column 4.\n";
            print STDERR $validate_result{'error'};
            return \%validate_result;
        }
        my $type = $worksheet->get_cell($row,4)->value();
        if (!$type) { # check is defined, is one of approved types
            $validate_result{'error'} = "Type $type is undefined at row $row, column 5.\n";
            print STDERR $validate_result{'error'};
            return \%validate_result;
        }
        my $latitude = $worksheet->get_cell($row,5)->value();
        if (!$latitude) { # check is defined, is number between 90 and -90
            $validate_result{'error'} = "Latitude $latitude is undefined at row $row, column 6.\n";
            print STDERR $validate_result{'error'};
            return \%validate_result;
        }
        my $longitude= $worksheet->get_cell($row,6)->value();
        if (!$longitude) { # check is defined, is number between 180 and -180
            $validate_result{'error'} = "Longitude $longitude is undefined at row $row, column 7.\n";
            print STDERR $validate_result{'error'};
            return \%validate_result;
        }
        my $altitude = $worksheet->get_cell($row,7)->value();
        if (!$altitude) { # check is defined, is number between -418 and 8,848
            $validate_result{'error'} = "Altitude $altitude is undefined at row $row, column 8.\n";
            print STDERR $validate_result{'error'};
            return \%validate_result;
        }
        print STDERR "Validated row is $name, $abbreviation, $country, $program, $type, $latitude, $longitude, $altitude\n";
    }
    $validate_result{'success'} = 1;
    return \%validate_result;
}

sub parse {
    my $self = shift;
    my $filename = shift;
    my $schema = shift;
    my $parser   = Spreadsheet::ParseExcel->new();
    my %parse_result;

    #try to open the excel file and report any errors
    my $excel_obj = $parser->parse($filename);
    if ( !$excel_obj ) {
        $parse_result{'error'} = $parser->error();
        print STDERR "validate error: ".$parser->error()."\n";
        return \%parse_result;
    }

    my $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
    my ( $row_min, $row_max ) = $worksheet->row_range();

    my @rows;
    for my $row ( 1 .. $row_max ) {
        my $name = $worksheet->get_cell($row,0)->value();
        my $abbreviation = $worksheet->get_cell($row,1)->value();
        my $country = $worksheet->get_cell($row,2)->value();
        my $program = $worksheet->get_cell($row,3)->value();
        my $type = $worksheet->get_cell($row,4)->value();
        my $latitude = $worksheet->get_cell($row,5)->value();
        my $longitude= $worksheet->get_cell($row,6)->value();
        my $altitude = $worksheet->get_cell($row,7)->value();
        print STDERR "Row is $name, $abbreviation, $country, $program, $type, $latitude, $longitude, $altitude\n";
        push @rows, [$name,$abbreviation,$country,$program,$type,$latitude,$longitude,$altitude];
    }
    $parse_result{'success'} = \@rows;

    return \%parse_result;
}

1;
