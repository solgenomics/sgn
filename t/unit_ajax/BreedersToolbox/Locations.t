
# Tests functions in SGN::Controller::AJAX::Locations. These are the functions called when retrieving, uploading, storing, or deleting accessions.

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use Data::Dumper;
use JSON;
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
#print STDERR Dumper $response;
my $expected_response = {'data' => '[{"geometry":{"coordinates":[-115.864,32.6136],"type":"Point"},"properties":{"Abbreviation":null,"Altitude":109,"Code":"USA","Country":"United States","Id":"23","Latitude":32.6136,"Longitude":-115.864,"Name":"test_location","Program":"test","Trials":"<a href=\"/search/trials?location_id=23\">5 trials</a>","Type":null},"type":"Feature"},{"geometry":{"coordinates":[-76.4735,42.4534],"type":"Point"},"properties":{"Abbreviation":null,"Altitude":274,"Code":"USA","Country":"United States","Id":"24","Latitude":42.4534,"Longitude":-76.4735,"Name":"Cornell Biotech","Program":"test","Trials":"<a href=\"/search/trials?location_id=24\">0 trials</a>","Type":null},"type":"Feature"},{"geometry":{"coordinates":[null,null],"type":"Point"},"properties":{"Abbreviation":null,"Altitude":null,"Code":null,"Country":null,"Id":"25","Latitude":null,"Longitude":null,"Name":"NA","Program":null,"Trials":"<a href=\"/search/trials?location_id=25\">0 trials</a>","Type":null},"type":"Feature"}]'};
is_deeply($response, $expected_response, 'retrieve all locations');

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
$mech->post_ok('http://localhost:3010/breeders/program/new', [
    "name"=> 'test2',
    "desc"=> "added for Locations.t",
]);
$response = decode_json $mech->content;
#print STDERR Dumper $response;
$expected_response = "The new breeding program test2 was created.";
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
$expected_response = "Location test_location cannot be deleted because there are 3514 measurements associated with it from at least one trial.\n";
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
