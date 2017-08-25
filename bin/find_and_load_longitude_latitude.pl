#!/usr/bin/perl

=head1

find_and_load_longitude_latitude.pl - find long/lat, country_name, country_code, and address for locations in cxgn databases. optionally can directly update or create the found lat/long, country_name, country_code, and address into database

=head1 SYNOPSIS

    find_and_load_longitude_latitude.pl -H localhost -D cxgn -O outfile.tsv -s

=head1 COMMAND-LINE OPTIONS
  ARGUMENTS
  -H localhost
  -D database
  -O outfile.csv
  -s save found lat/long, country_name, country_code, and address into database

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

my $country_name_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "country_name", "geolocation_property")->cvterm_id();
my $country_code_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "country_code", "geolocation_property")->cvterm_id();
my $breeding_program_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "breeding_program", "project_property")->cvterm_id();
my $program_trial_relationship_id = SGN::Model::Cvterm->get_cvterm_row($schema, "breeding_program_trial_relationship", "project_relationship")->cvterm_id();
my $project_location_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "project location", "project_property")->cvterm_id();

my $geolocation_rs = $schema->resultset('NaturalDiversity::NdGeolocation')->search();

open(my $F, ">", $opt_O) || die "Can't open file ".$opt_O;

print STDERR "LocationName\tLongitudeInDB\tLatitudeInDB\tAltitudeInDB\tFoundLongitude\tFoundLatitude\tFoundAltitude\tFoundCountry\tFoundCountryCode\tFoundProgram\n";

print $F "LocationName\tLongitudeInDB\tLatitudeInDB\tAltitudeInDB\tFoundLongitude\tFoundLatitude\tFoundAltitude\tFoundCountry\tFoundCountryCode\tFoundProgram\n";

while(my$r = $geolocation_rs->next){
    my ($name, $id, $longitude, $latitude, $altitude, $country, $country_code);
    $name = $r->description;
    $id = $r->nd_geolocation_id;
    $name =~ s/\s/+/g;
    # $id =~ s/\s/+/g;
    # #print STDERR "Name: $name ";
    # if ($id < 20) {
    #     next;
    # }
    #retrieve program
    # my $program_query = "
    #     SELECT
    #     geo.nd_geolocation_id,
    #     breeding_program.name
    #     FROM nd_geolocation AS geo
    #     LEFT JOIN projectprop ON (projectprop.value::INT = geo.nd_geolocation_id AND projectprop.type_id=(
    #         SELECT cvterm_id FROM cvterm JOIN cv USING(cv_id) WHERE cvterm.name = 'breeding_program' AND cv.name = 'project_property'
    #     ))
    #     LEFT JOIN project AS trial ON (trial.project_id=projectprop.project_id)
    #     LEFT JOIN project_relationship ON (subject_project_id=trial.project_id)
    #     LEFT JOIN project breeding_program ON (breeding_program.project_id=object_project_id)
    #     WHERE nd_geolocation_id = ?
    #     LIMIT 1
    # ";

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

    print STDERR "Location cvterm id is $project_location_cvterm_id and program trial cvterm is is $program_trial_relationship_id and geolocation id is $id\n";
    my $prepared_query=$dbh->prepare($program_query);
    $prepared_query->execute($project_location_cvterm_id, $program_trial_relationship_id, $id);
    my ($geo_id, $program, $count) = $prepared_query->fetchrow_array();
    print STDERR "Program is $program\n";

    #retrieve coordinates
    my $server_endpoint1 = "http://maps.googleapis.com/maps/api/geocode/json?address=$name";
    my $req = HTTP::Request->new(GET => $server_endpoint1);
    $req->header('content-type' => 'application/json');
    my $ua = LWP::UserAgent->new;
    my $resp = $ua->request($req);
    if ($resp->is_success) {
        my $message = $resp->decoded_content;
        my $json_utf8 = encode('UTF-8', $message);
        my $message_hash = decode_json $json_utf8;
        #print STDERR Dumper $message_hash;

        my $location = $message_hash->{'results'}->[0]->{'geometry'}->{'location'};
        $latitude = $location->{'lat'};
        $longitude = $location->{'lng'};
        #print STDERR "Lat: $latitude Long: $longitude ";
        #print STDERR "Formatted address: $formatted_address ";
    }

    #retrieve altitude
    my $server_endpoint2 = "http://www.datasciencetoolkit.org/coordinates2statistics/$latitude%2c$longitude?statistics=elevation";
    $req = HTTP::Request->new(GET => $server_endpoint2);
    $req->header('content-type' => 'application/json');
    $ua = LWP::UserAgent->new;
    $resp = $ua->request($req);
    if ($resp->is_success) {
        my $message = $resp->decoded_content;
        my $json_utf8 = encode('UTF-8', $message);
        my $message_hash = decode_json $json_utf8;
        #print STDERR "altitude response: ".Dumper $message_hash;
        $altitude = $message_hash->[0]->{'statistics'}->{'elevation'}->{'value'};
        #print STDERR "Altitude: $altitude ";
    }

    #retrieve country code and name
    my $server_endpoint3 = "http://www.datasciencetoolkit.org/coordinates2politics/$latitude%2c$longitude?";
    $req = HTTP::Request->new(GET => $server_endpoint3);
    $req->header('content-type' => 'application/json');
    $ua = LWP::UserAgent->new;
    $resp = $ua->request($req);
    if ($resp->is_success) {
        my $message = $resp->decoded_content;
        my $json_utf8 = encode('UTF-8', $message);
        my $message_hash = decode_json $json_utf8;
        # print STDERR "politics response: ".Dumper $message_hash;
        $country = $message_hash->[0]->{'politics'}->[0]->{'name'};
        $country_code = uc($message_hash->[0]->{'politics'}->[0]->{'code'});
        #print STDERR "Country name: $country Country code: $country_code \n";
    }




        print STDERR $r->description()."\t".$r->longitude()."\t".$r->latitude()."\t".$longitude."\t".$latitude."\t".$altitude."\t".$country."\t".$country_code."\t".$program."\n";

        print $F $r->description()."\t".$r->longitude()."\t".$r->latitude()."\t".$longitude."\t".$latitude."\t".$altitude."\t".$country."\t".$country_code."\t".$program."\n";

        if ($opt_s){

            my $updated_location = CXGN::Location->new( {
                bcs_schema => $schema,
                nd_geolocation_id => $id,
                name => $r->description(),
                country_name => $country,
                country_code => $country_code,
                breeding_program => $program,
                latitude => $r->latitude() || $latitude,
                longitude => $r->longitude() || $longitude,
                altitude => $r->altitude() || $altitude,
            });

            my $store = $updated_location->store_location();
            # if($longitude && $latitude){
            #     my %update = (longitude=>$longitude, latitude=>$latitude);
            #     $r->update(\%update);
            # }
            # if($altitude){
            #     my %update = (altitude=>$altitude);
            #     $r->update(\%update);
            # }
            # if($country){
            #     my $country_name_prop = $schema->resultset('NaturalDiversity::NdGeolocationprop')->find({
            #         nd_geolocation_id=>$r->nd_geolocation_id(),
            #         type_id=>$country_name_cvterm_id,
            #     });
            #     if ($country_name_prop){
            #         $country_name_prop->update({value=>$country})
            #     } else {
            #         $country_name_prop = $schema->resultset('NaturalDiversity::NdGeolocationprop')->create({
            #             nd_geolocation_id=>$r->nd_geolocation_id(),
            #             type_id=>$country_name_cvterm_id,
            #             value=>$country
            #         });
            #     }
            # }
            # if($country_code){
            #     my $country_code_prop = $schema->resultset('NaturalDiversity::NdGeolocationprop')->find({
            #         nd_geolocation_id=>$r->nd_geolocation_id(),
            #         type_id=>$country_code_cvterm_id,
            #     });
            #     if ($country_code_prop){
            #         $country_code_prop->update({value=>$country_code})
            #     } else {
            #         $country_code_prop = $schema->resultset('NaturalDiversity::NdGeolocationprop')->create({
            #             nd_geolocation_id=>$r->nd_geolocation_id(),
            #             type_id=>$country_code_cvterm_id,
            #             value=>$country_code
            #         });
            #     }
            # }

    }
}

close($F);
