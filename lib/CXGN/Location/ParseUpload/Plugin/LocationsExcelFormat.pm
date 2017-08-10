package CXGN::Location::ParseUpload::Plugin::LocationsExcelFormat;

use Moose;
#use File::Slurp;
use Spreadsheet::ParseExcel;
use JSON;
use Data::Dumper;

sub name {
    return "location excel";
}

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

        # check that name is defined and isn't already in database
        if ($worksheet->get_cell($row,0)) {
          $name = $worksheet->get_cell($row,0)->value();
        }
        if (!$name) {
            push @errors, "Name $name is undefined at row $row_num, column A.\n";
        }
        elsif (!_is_valid_name($name)) {
            push @errors, "Name $name at row $row_num, column A already exists in the database. Please delete this location or choose a different name.\n";
        }

        # check that abbreviation is defined and isn't already in database
        if ($worksheet->get_cell($row,1)) {
          $abbreviation = $worksheet->get_cell($row,1)->value();
        }
        if (!$abbreviation) {
            push @errors, "Abbreviation $abbreviation is undefined at row $row_num, column B.\n";
        }
        elsif (!_is_valid_abbreviation($abbreviation)) {
            push @errors, "Abbreviation $abbreviation at row $row_num, column B already exists in the database. Please delete this location or choose a different abbreviation.\n";
        }

        # check is defined and is valid ISO code
        if ($worksheet->get_cell($row,2)) {
          $country_code = $worksheet->get_cell($row,2)->value();
        }
        if (!$country_code) {
            push @errors, "Country code $country_code is undefined at row $row_num, column C.\n";
        }
        elsif (!_is_valid_country_code($country_code)) {
            push @errors, "Country code $country_code is not a valid ISO Alpha-3 code at row $row_num, column C. Please fix and try again.\n";
        }

        # check is defined and is valid country name
        if ($worksheet->get_cell($row,3)) {
          $country_name = $worksheet->get_cell($row,3)->value();
        }
        if (!$country_name) {
            push @errors, "Country name $country_name is undefined at row $row_num, column D.\n";
        }
        elsif (!_is_valid_country_name($country_name)) {
            push @errors, "Country name $country_name is not a valid ISO standard country name at row $row_num, column C. Please fix and try again.\n";
        }

        # check is defined, is in database
        if ($worksheet->get_cell($row,4)) {
          $program = $worksheet->get_cell($row,4)->value();
        }
        if (!$program) {
            push @errors, "Program $program is undefined at row $row_num, column E.\n";
        }
        elsif (!_is_valid_program($program)) {
            push @errors, "Program $program at row $row_num, column D does not exist in the database. Please use an existing breeding program and try again.\n";
        }

        # check is defined, is one of approved types
        if ($worksheet->get_cell($row,5)) {
          $type = $worksheet->get_cell($row,5)->value();
        }
        if (!$type) {
            push @errors, "Type $type is undefined at row $row_num, column F.\n";
        }
        elsif(!is_valid_type($type)) {
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

sub _is_valid_name {
    my $self = shift;
    my $name = shift;
    my $existing_name_count = $schema->resultset('NaturalDiversity::NdGeolocation')->search( { description => $name } )->count()
    if ($existing_name_count > 0) {
        return 0;
    }
    else {
        return 1;
    }
}

sub _is_valid_abbreviation {
    my $self = shift;
    my $abbreviation = shift;
    my $existing_abbreviation_count = $schema->resultset('NaturalDiversity::NdGeolocationprop')->search( { value => $abbreviation } )->count()
    if ($existing_abbreviation_count > 0) {
        return 0;
    }
    else {
        return 1;
    }
}

sub _is_valid_country_code {
    my $self = shift;
    my $country_code = shift;
    
    if ($existing_name_count > 0) {
        return 0;
    }
    else {
        return 1;
    }
}

sub _is_valid_country_name {
    my $self = shift;
    my $country_name = shift;
    my $existing_name_count = $schema->resultset('NaturalDiversity::NdGeolocation')->search( { description => $name } )->count()
    if ($existing_name_count > 0) {
        return 0;
    }
    else {
        return 1;
    }
}

sub _is_valid_program {
    my $self = shift;
    my $program = shift;
    my $existing_program_count = $schema->resultset('Project::Project')->search(
        {
            'type.name'=> 'breeding_program',
            'me.name' => $program
        },
        # {
            join => {
                'projectprops' =>
                'type'
            }
        # }
    )->count();
    if ($existing_program_count < 1) {
        return 0;
    }
    else {
        return 1;
    }
}

1;
