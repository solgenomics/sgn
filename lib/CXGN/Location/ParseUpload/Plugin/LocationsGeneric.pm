package CXGN::Location::ParseUpload::Plugin::LocationsGeneric;

use Moose;
use SGN::I18N ();
use CatalystX::GlobalContext '$c';
use CXGN::Location;
use CXGN::File::Parse;
use JSON;
use Data::Dumper;

sub name {
    return "location generic";
}

sub parse {
    my SGN::I18N $ui_locationsgeneric_parse_i18n = $c && $c->can('i18n') ? $c->i18n : undef;
    my $self = shift;
    my $filename = shift;
    my $schema = shift;

    my $check = CXGN::Location->new({ bcs_schema => $schema });
    my (@errors, @rows, %parse_result);

    my $parser = CXGN::File::Parse->new(
      file => $filename,
      required_columns => [ 'Name', 'Abbreviation', 'Country Code', 'Country Name', 'Program', 'Type', 'Latitude', 'Longitude', 'Elevation' ],
      optional_columns => [ 'NOAA Station ID' ],
      column_aliases => {
        'Elevation' => [ 'Altitude' ],
        'Latitude' => [ 'Lat' ],
        'Longitude' => [ 'Lon', 'Long' ]
      },
      column_arrays => {
        'Program' => '&'
      },
      unique_only_columns => [ 'Name', 'Abbreviation' ]
    );
    my $parsed = $parser->parse();
    my $parsed_errors = $parsed->{errors};
    my $parsed_columns = $parsed->{columns};
    my $parsed_data = $parsed->{data};
    my $parsed_values = $parsed->{values};

    if ( $parsed_errors && scalar(@$parsed_errors) > 0 ) {
      $parse_result{'error'} = $parsed_errors;
      return \%parse_result;
    }


    for my $row (@$parsed_data) {
        my $row_num = $row->{_row};
        our($name,$abbreviation,$country_code,$country_name,$programs,$type,$latitude,$longitude,$altitude,$noaa_station_id) = undef;

        # check that name is defined and isn't already in database
        $name = $row->{'Name'};
        if (!$check->_is_valid_name($name)) {
            push @errors, (SGN::I18N::translate($ui_locationsgeneric_parse_i18n, "program.location.parse.row.exists", "Row %{row}: %{field} %{value} already exists in the database.\n", {row => "$row_num", field => "Name", value => "$name"}));
        }

        # check that abbreviation is defined and isn't already in database
        $abbreviation = $row->{'Abbreviation'};
        if (!$check->_is_valid_abbreviation($abbreviation)) {
            push @errors, (SGN::I18N::translate($ui_locationsgeneric_parse_i18n, "program.location.parse.row.exists", "Row %{row}: %{field} %{value} already exists in the database.\n", {row => "$row_num", field => "Abbreviation", value => "$abbreviation"}));
        }

        # check that country code is defined, is all uppercase letters, and is 3 chars long
        $country_code = $row->{'Country Code'};
        if (($country_code !~ m/^[^a-z]*$/) || (length($country_code) != 3 )) {
            push @errors, (SGN::I18N::translate($ui_locationsgeneric_parse_i18n, "program.location.parse.row.country_code", "Row %{row}: Country code %{value} is not a valid ISO Alpha-3 code.\n", {row => "$row_num", value => "$country_code"}));
        }

        # check that country name is defined and is not numeric
        $country_name = $row->{'Country Name'};
        if ($country_name =~ m/[0-9]/) {
            push @errors, (SGN::I18N::translate($ui_locationsgeneric_parse_i18n, "program.location.parse.row.country_name", "Row %{row}: Country name %{value} is not a valid ISO standard country name.\n", {row => "$row_num", value => "$country_name"}));
        }

        # check that program is defined, is in database
        $programs = $row->{'Program'};
        foreach my $bp (@$programs) {
            if (!$check->_is_valid_program($bp)) {
                push @errors, (SGN::I18N::translate($ui_locationsgeneric_parse_i18n, "program.location.parse.row.program", "Row %{row}: Program %{value} does not exist in the database.\n", {row => "$row_num", value => "$bp"}));
            }
        }
        my $program_string = join("&", @$programs);

        # check that type is defined, is one of approved types
        $type = $row->{'Type'};
        if(!$check->_is_valid_type($type)) {
            push @errors, (SGN::I18N::translate($ui_locationsgeneric_parse_i18n, "program.location.parse.row.type", "Row %{row}: Type %{value} is is not a valid location type.\n", {row => "$row_num", value => "$type"}));
        }

        # check lat has length, is number between 90 and -90
        $latitude = $row->{'Latitude'};
        if( ($latitude !~ /^-?[0-9.]+$/) || ($latitude < -90) || ($latitude > 90) ) {
            push @errors, (SGN::I18N::translate($ui_locationsgeneric_parse_i18n, "program.location.parse.row.latitude", "Row %{row}: Latitude %{value} is not a number between 90 and -90.\n", {row => "$row_num", value => "$latitude"}));
        }

        # check lon has length, is number between 180 and -180
        $longitude = $row->{'Longitude'};
        if( ($longitude !~ /^-?[0-9.]+$/) || ($longitude < -180) || ($longitude > 180) ) {
            push @errors, (SGN::I18N::translate($ui_locationsgeneric_parse_i18n, "program.location.parse.row.longitude_original", "Row %{row}: Latitude %{value} is not a number between 180 and -180.\n", {row => "$row_num", value => "$latitude"}));
        }

        # check has length, is number between -418 and 8,848
        $altitude = $row->{'Elevation'};
        if( ($altitude !~ /^-?[0-9.]+$/) || ($altitude < -418) || ($altitude > 8848) ) {
            push @errors, (SGN::I18N::translate($ui_locationsgeneric_parse_i18n, "program.location.parse.row.elevation", "Row %{row}: %{field} %{value} is not a number between -418 (Dead Sea) and 8,848 (Mt. Everest).\n", {row => "$row_num", field => "Elevation", value => "$altitude"}));
        }

        $noaa_station_id = $row->{'NOAA Station ID'};

        print STDERR "Row is $name, $abbreviation, $country_code, $country_name, $program_string, $type, $latitude, $longitude, $altitude, $noaa_station_id\n";
        push @rows, [$name,$abbreviation,$country_code,$country_name,$program_string,$type,$latitude,$longitude,$altitude,$noaa_station_id];
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
