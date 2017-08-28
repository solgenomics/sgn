#!/usr/bin/perl

=head1

find_and_load_longitude_latitude.pl - find long/lat, altitude, country_name, country_code, and program for locations in cxgn databases. optionally can directly update or create the found props in the database

=head1 SYNOPSIS

    find_and_load_longitude_latitude.pl -H localhost -D cxgn -O outfile.tsv -s

=head1 COMMAND-LINE OPTIONS
  ARGUMENTS
  -H localhost
  -D database
  -O outfile.csv
  -s save found props that don't have exisiting values in the database

=head1 DESCRIPTION


=head1 AUTHOR

Nicolas Morales nm529@cornell.edu

=cut

use strict;

use Getopt::Std;
use Data::Dumper;
use Carp qw /croak/ ;
use Pod::Usage;
use Spreadsheet::ParseExcel;
use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;
use CXGN::BreedersToolbox::Projects;
use CXGN::Location;
use LWP::UserAgent;
use Encode       qw( encode );
use JSON;
use SGN::Model::Cvterm;

our ($opt_H, $opt_D, $opt_O, $opt_s);

getopts('H:D:O:s');

if (!$opt_H || !$opt_D || !$opt_O) {
    pod2usage(-verbose => 2, -message => "Must provide options -H, -D, and -O \n");
}

my $dbhost = $opt_H;
my $dbname = $opt_D;

my $dbh = CXGN::DB::InsertDBH->new({
	dbhost=>$dbhost,
	dbname=>$dbname,
	dbargs => {AutoCommit => 1, RaiseError => 1}
});

my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );
$dbh->do('SET search_path TO public,sgn');

open(my $F, ">", $opt_O) || die "Can't open file ".$opt_O;

# print STDERR "LocationName\tLongitudeInDB\tLatitudeInDB\tAltitudeInDB\tCountry\tCountryCode\tProgram\tFoundLongitude\tFoundLatitude\tFoundAltitude\tFoundCountry\tFoundCountryCode\tFoundProgram\n";

print $F "LocationName\tLongitudeInDB\tLatitudeInDB\tAltitudeInDB\tCountry\tCountryCode\tProgram\tFoundLongitude\tFoundLatitude\tFoundAltitude\tFoundCountry\tFoundCountryCode\tFoundProgram\n";

my $program_trial_relationship_id = SGN::Model::Cvterm->get_cvterm_row($schema, "breeding_program_trial_relationship", "project_relationship")->cvterm_id();
my $project_location_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "project location", "project_property")->cvterm_id();

my $project_object = CXGN::BreedersToolbox::Projects->new( { schema => $schema });
my $all_locations = decode_json $project_object->get_location_geojson();

foreach my $location_hash (@$all_locations) {

    my $location = $location_hash->{'properties'};
    my $name = $location->{'Name'};
    my $id = $location->{'Id'};
    my ($longitude, $latitude, $altitude, $country_name, $country_code, $program);
    my ($found_latitude, $found_longitude, $found_altitude, $found_country_name, $found_country_code, $found_program);

    #retrieve coordinates from name
    $name =~ s/\s/+/g;
    my $server_endpoint1 = "http://maps.googleapis.com/maps/api/geocode/json?address=$name";
    my $req = HTTP::Request->new(GET => $server_endpoint1);
    $req->header('content-type' => 'application/json');
    my $ua = LWP::UserAgent->new;
    my $resp = $ua->request($req);
    if ($resp->is_success) {
        my $message = $resp->decoded_content;
        my $json_utf8 = encode('UTF-8', $message);
        my $message_hash = decode_json $json_utf8;
        my $location = $message_hash->{'results'}->[0]->{'geometry'}->{'location'};
        $found_latitude = $location->{'lat'};
        $found_longitude = $location->{'lng'};
        $latitude = $location_hash->{'properties'}->{'Latitude'} || $found_latitude;
        $longitude = $location_hash->{'properties'}->{'Longitude'} || $found_longitude;
    }

    #retrieve altitude from coordinates
    my $server_endpoint2 = "http://www.datasciencetoolkit.org/coordinates2statistics/$latitude%2c$longitude?statistics=elevation";
    $req = HTTP::Request->new(GET => $server_endpoint2);
    $req->header('content-type' => 'application/json');
    $ua = LWP::UserAgent->new;
    $resp = $ua->request($req);
    if ($resp->is_success) {
        my $message = $resp->decoded_content;
        my $json_utf8 = encode('UTF-8', $message);
        my $message_hash = decode_json $json_utf8;
        $found_altitude = $message_hash->[0]->{'statistics'}->{'elevation'}->{'value'};
        $altitude = $location->{'Altitude'} || $found_altitude;
    }

    #retrieve country code and name from coordinates
    my $server_endpoint3 = "http://www.datasciencetoolkit.org/coordinates2politics/$latitude%2c$longitude?";
    $req = HTTP::Request->new(GET => $server_endpoint3);
    $req->header('content-type' => 'application/json');
    $ua = LWP::UserAgent->new;
    $resp = $ua->request($req);
    if ($resp->is_success) {
        my $message = $resp->decoded_content;
        my $json_utf8 = encode('UTF-8', $message);
        my $message_hash = decode_json $json_utf8;
        $found_country_name = $message_hash->[0]->{'politics'}->[0]->{'name'};
        $found_country_code = uc($message_hash->[0]->{'politics'}->[0]->{'code'});
        $country_name = $location->{'Country'} || $found_country_name;
        $country_code = $location->{'Code'} || $found_country_code;

    }

    #retrieve breeding program from associated trials
    my $program_query = "SELECT geo.nd_geolocation_id,
    	breeding_program.name,
        count(distinct(projectprop.project_id))
        FROM nd_geolocation AS geo
        LEFT JOIN projectprop ON (projectprop.value::INT = geo.nd_geolocation_id AND projectprop.type_id=?)
        LEFT JOIN project AS trial ON (trial.project_id=projectprop.project_id)
        LEFT JOIN project_relationship ON (subject_project_id=trial.project_id AND project_relationship.type_id =?)
        LEFT JOIN project breeding_program ON (breeding_program.project_id=object_project_id)
        WHERE nd_geolocation_id =?
        GROUP BY 1,2
        ORDER BY 3
        LIMIT 1";
    my $prepared_query=$dbh->prepare($program_query);
    $prepared_query->execute($project_location_cvterm_id, $program_trial_relationship_id, $id);
    my ($geo_id, $found_program, $count) = $prepared_query->fetchrow_array();
    $program = $location->{'Program'} || $found_program;


    # print STDERR "$name saved props:\t".$location->{'Longitude'}."\t".$location->{'Latitude'}."\t".$location->{'Altitude'}."\t".$location->{'Country'}."\t".$location->{'Code'}."\t".$location->{'Program'}."\n$name found props:\t".$found_longitude."\t".$found_latitude."\t".$found_altitude."\t".$found_country_name."\t".$found_country_code."\t".$found_program."\n";

    print $F $name."\t".$location->{'Longitude'}."\t".$location->{'Latitude'}."\t".$location->{'Altitude'}."\t".$location->{'Country'}."\t".$location->{'Code'}."\t".$location->{'Program'}."\t".$found_longitude."\t".$found_latitude."\t".$found_altitude."\t".$found_country_name."\t".$found_country_code."\t".$found_program."\n";

    if ($opt_s){

        print STDERR "Updating $name with properties:
        country_name => $country_name,
        country_code => $country_code,
        breeding_program => $program,
        latitude => $latitude,
        longitude => $longitude,
        altitude => $altitude \n";

        my $updated_location = CXGN::Location->new( {
            bcs_schema => $schema,
            nd_geolocation_id => $id,
            country_name => $country_name,
            country_code => $country_code,
            breeding_program => $program,
            latitude => $latitude,
            longitude => $longitude,
            altitude => $altitude,
        });

        my $store = $updated_location->store_location();

        if ($store->{'error'}) {
            print STDERR $store->{'error'}."\n";
        }

    }
}

close($F);
