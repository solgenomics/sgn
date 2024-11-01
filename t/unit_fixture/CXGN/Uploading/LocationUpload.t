use strict;
use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use SimulateC;
use CXGN::UploadFile;
use CXGN::Location;
use CXGN::Location::ParseUpload;
use SGN::Model::Cvterm;
use Data::Dumper;
use DateTime;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();

for my $extension ("xls", "xlsx") {

    my $c = SimulateC->new({ dbh => $f->dbh(),
        bcs_schema               => $schema,
        metadata_schema          => $f->metadata_schema(),
        phenome_schema           => $f->phenome_schema(),
        sp_person_id             => 41 });

    #######################################
    #Find out prop counts before adding anything, so that changes can be compared
    my $pre_locationprop_count = $c->bcs_schema->resultset('NaturalDiversity::NdGeolocationprop')->search({})->count();

    #First Upload Excel Location File

    my $file_name = "t/data/location_upload/location_test_file.$extension";
    my $time = DateTime->now();
    my $timestamp = $time->ymd() . "_" . $time->hms();

    #Test archive upload file
    my $uploader = CXGN::UploadFile->new({
        tempfile         => $file_name,
        subdirectory     => 'temp_location_upload',
        archive_path     => '/tmp',
        archive_filename => "location_test_file.$extension",
        timestamp        => $timestamp,
        user_id          => 41, #janedoe in fixture
        user_role        => 'curator'
    });

    ## Store uploaded temporary file in archive
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    ok($archived_filename_with_path);
    ok($md5);


    #parse uploaded file with appropriate plugin
    my $type = 'location generic';
    my $parser = CXGN::Location::ParseUpload->new();
    my $parse_result = $parser->parse($type, $archived_filename_with_path, $schema);

    ok($parse_result, "Check if parse excel file works");
    ok(!$parse_result->{'error'}, "Check that parse returns no errors");

    print STDERR "Dump of parsed result:\t" . Dumper($parse_result->{'success'}) . "\n";

    my $parsed_data_check = [
        [
            'Cortland',
            'COR',
            'USA',
            'United States',
            'test',
            'Field',
            42,
            -76,
            123,
            'GHCND:USC00300331'
        ]
    ];
    is_deeply($parse_result->{'success'}, $parsed_data_check, 'check location generic parse data');

    foreach my $row (@{$parse_result->{'success'}}) {
        #get data from rows one at a time
        my @data = @$row;
        my $location = CXGN::Location->new({
            bcs_schema        => $schema,
            nd_geolocation_id => undef,
            name              => $data[0],
            abbreviation      => $data[1],
            country_code      => $data[2],
            country_name      => $data[3],
            location_type     => $data[5],
            latitude          => $data[6],
            longitude         => $data[7],
            altitude          => $data[8]
        });

        my $store = $location->store_location();
    }

    my $location_name = $c->bcs_schema()->resultset('NaturalDiversity::NdGeolocation')->search({}, { order_by => { -desc => 'nd_geolocation_id' } })->first()->description();
    ok($location_name == "Cortland", "check that location name upload really worked");

    my $location_latitude = $c->bcs_schema()->resultset('NaturalDiversity::NdGeolocation')->search({}, { order_by => { -desc => 'nd_geolocation_id' } })->first()->latitude();
    ok($location_latitude == 42, "check that location latitude upload really worked");

    my $location_longitude = $c->bcs_schema()->resultset('NaturalDiversity::NdGeolocation')->search({}, { order_by => { -desc => 'nd_geolocation_id' } })->first()->longitude();
    ok($location_longitude == -76, "check that location longitude upload really worked");

    my $location_altitude = $c->bcs_schema()->resultset('NaturalDiversity::NdGeolocation')->search({}, { order_by => { -desc => 'nd_geolocation_id' } })->first()->altitude();
    ok($location_altitude == 123, "check that location altitude upload really worked");

    my $post_locationprop_count = $c->bcs_schema->resultset('NaturalDiversity::NdGeolocationprop')->search({})->count();
    my $post1_locationprop_diff = $post_locationprop_count - $pre_locationprop_count;
    print STDERR "Locationprop: " . $post1_locationprop_diff . "\n";
    ok($post1_locationprop_diff == 4, "check locationprop table after upload excel location");

    $f->clean_up_db();
}
done_testing();
