
# Tests functions in SGN::Controller::AJAX::Locations. These are the functions called when retrieving, uploading, storing, or deleting locations.

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use Data::Dumper;
use JSON::XS;
use URI::Encode qw(uri_encode uri_decode);

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $mech = Test::WWW::Mechanize->new;

#test login
$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = decode_json $mech->content;
#print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');

#test location retrieval
$mech->post_ok('http://localhost:3010/ajax/location/all');
$response = decode_json $mech->content;

my $expected_response = "";

#{'data' =>'[{"geometry":{"coordinates":[-115.86428,32.61359],"type":"Point"},"properties":{"Abbreviation":null,"Altitude":109,"Code":"USA","Country":"United States","Id":"23","Latitude":32.61359,"Longitude":-115.86428,"NOAAStationID":null,"Name":"test_location","Program":"test","Trials":"<a href=\"/search/trials?location_id=23\">9 trials</a>","Type":null},"type":"Feature"},{"geometry":{"coordinates":[-76.4735,42.45345],"type":"Point"},"properties":{"Abbreviation":null,"Altitude":274,"Code":"USA","Country":"United States","Id":"24","Latitude":42.45345,"Longitude":-76.4735,"NOAAStationID":null,"Name":"Cornell Biotech","Program":"test","Trials":"<a href=\"/search/trials?location_id=24\">0 trials</a>","Type":null},"type":"Feature"},{"geometry":{"coordinates":[42.417374,-76.50604],"type":"Point"},"properties":{"Abbreviation":"L2","Altitude":123,"Code":"PER","Country":"Peru","Id":"25","Latitude":-76.50604,"Longitude":42.417374,"NOAAStationID":"PALMIRA","Name":"Location 2","Program":"test","Trials":"<a href=\"/search/trials?location_id=25\">0 trials</a>","Type":"Field"},"type":"Feature"},{"geometry":{"coordinates":[null,null],"type":"Point"},"properties":{"Abbreviation":null,"Altitude":null,"Code":null,"Country":null,"Id":"26","Latitude":null,"Longitude":null,"NOAAStationID":null,"Name":"[Computation]","Program":null,"Trials":"<a href=\"/search/trials?location_id=26\">0 trials</a>","Type":null},"type":"Feature"},{"geometry":{"coordinates":[42.417374,-76.50604],"type":"Point"},"properties":{"Abbreviation":"L1","Altitude":123,"Code":"PER","Country":"Peru","Id":"27","Latitude":-76.50604,"Longitude":42.417374,"NOAAStationID":"PALMIRA","Name":"Location 1","Program":"test","Trials":"<a href=\"/search/trials?location_id=27\">0 trials</a>","Type":"Field"},"type":"Feature"}]'};

# check specific response keys - response can have more entries from other tests
#
like($response->{data}->[0]->{properties}->{Name}, qr/test_location/, "location name test");
like($response->{data}->[0]->{properties}->{Program}, qr/test/,  "location program test");
like($response->{data}->[0]->{properties}->{Trials}, qr/trials/, "Trials returned test");
like($response->{data}->[1]->{properties}->{Name}, qr/Cornell Biotech/, "location name test 2");
like($response->{data}->[1]->{properties}->{Program}, qr/test/, "location program test 2");

#is_deeply($response, $expected_response, 'retrieve all locations');

#test location store
$mech->post_ok('http://localhost:3010/ajax/location/store', [
    "name"=> "Boyce Thompson Institute",
    "abbreviation"=> "BTI",
    "country_code"=> "USA",
    "country_name"=> "United States",
    "programs"=> "test",
    "type"=> "Lab",
    "latitude"=> 42.5,
    "longitude"=> -76,
    "altitude"=> 123,
    ]);
$response = decode_json $mech->content;
#print STDERR Dumper $response->{'success'};
$expected_response = "Location Boyce Thompson Institute added successfully\n";
is_deeply($response->{'success'}, $expected_response, 'store a new location');
ok($response->{'nd_geolocation_id'});
my $new_geolocation_id = $response->{'nd_geolocation_id'};

# add new breeding program
$mech->post_ok('http://localhost:3010/breeders/program/store', [
    "name"=> 'test2',
    "desc"=> "added for Locations.t",
]);
$response = decode_json $mech->content;
#print STDERR Dumper $response;
$expected_response = "Breeding program test2 was added successfully with description added for Locations.t\n";
is_deeply($response->{'success'}, $expected_response, 'adding a breeding program');
my $new_program_id = $response->{'id'};

#test location edit, including associating multiple programs
$mech->post_ok('http://localhost:3010/ajax/location/store', [
    "id"=> $new_geolocation_id,
    "name"=> "Boyce Thompson Institute",
    "abbreviation"=> "BOY",
    "country_code"=> "USA",
    "country_name"=> "United States",
    "programs"=> "test&test2",
    "type"=> "Storage",
    "latitude"=> 42.5,
    "longitude"=> -76,
    "altitude"=> 223,
    ]);
$response = decode_json $mech->content;
#print STDERR Dumper $response->{'success'};
$expected_response = "Location Boyce Thompson Institute was successfully updated\n";
is_deeply($response->{'success'}, $expected_response, 'edit an existing location');

#test delete on location with data
my $location_id = 23;
$mech->post_ok('http://localhost:3010/ajax/location/delete/'.$location_id);
$response = decode_json $mech->content;
#print STDERR Dumper $response->{'error'};

# figure out how many measurements are associated with this location
#
my $rs = $schema->resultset('NaturalDiversity::NdGeolocation')->search( { 'me.nd_geolocation_id'=>$location_id }, { join => 'nd_experiments' });
my $count = $rs->count();

print STDERR "COUNT: $count\n\n";

$expected_response = "Location test_location cannot be deleted because there are $count measurements associated with it from at least one trial.\n";
is_deeply($response->{'error'}, $expected_response, 'test error message on delete on location with data');

# test delete on unused location
$location_id = $new_geolocation_id;
$mech->post_ok('http://localhost:3010/ajax/location/delete/'.$location_id);
$response = decode_json $mech->content;
#print STDERR Dumper $response->{'success'};
$expected_response = "Location Boyce Thompson Institute was successfully deleted.\n";
is_deeply($response->{'success'}, $expected_response, 'test delete of unused location');

# delete added breeding program
$mech->post_ok('http://localhost:3010/breeders/program/delete/'.$new_program_id);
$response = decode_json $mech->content;
#print STDERR Dumper $response;
$expected_response = [ 1 ];
is_deeply($response, $expected_response, 'delete added breeding program');


done_testing();
