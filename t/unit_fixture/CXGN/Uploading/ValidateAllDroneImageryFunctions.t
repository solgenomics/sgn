
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use LWP::UserAgent;
use CXGN::Genotype::Protocol;
use CXGN::Genotype::Search;

#Needed to update IO::Socket::SSL
use Data::Dumper;
use JSON;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $mech = Test::WWW::Mechanize->new;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};
print STDERR $sgn_session_id."\n";

my $ua = LWP::UserAgent->new;
$response = $ua->get('http://localhost:3010/api/drone_imagery/upload_drone_imagery_check_drone_name?sgn_session_id='.$sgn_session_id.'&drone_run_name=NewDroneRunProject');

#print STDERR Dumper $response;
ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = decode_json $message;
print STDERR Dumper $message_hash;
is_deeply($message_hash, {'success' => 1});

my $field_trial_id = $schema->resultset("Project::Project")->search({name => 'test_trial'})->first->project_id();

#Testing upload of unstitched Micasense RedEdge 5 band raw captures.
my $micasense5bandimageszipfile = $f->config->{basepath}."/t/data/imagebreed/Micasense5BandRaw3Captures.zip";
my $micasense5bandpanelzipfile = $f->config->{basepath}."/t/data/imagebreed/ExampleAerialDroneFlightMicasensePanel.zip";
my $ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/api/drone_imagery/upload_drone_imagery',
        Content_Type => 'form-data',
        Content => [
            "sgn_session_id"=>$sgn_session_id,
            upload_drone_images_zipfile => [ $micasense5bandimageszipfile, 'upload_drone_images_zipfile' ],
            upload_drone_images_panel_zipfile => [ $micasense5bandpanelzipfile, 'upload_drone_images_panel_zipfile' ],
            "drone_run_field_trial_id"=>$field_trial_id,
            "drone_run_name"=>"NewMicasenseUnstitchedDroneRunProject",
            "drone_run_type"=>"Aerial Medium to High Res",
            "drone_run_date"=>"2019/01/01 12:12:12",
            "drone_run_description"=>"test new drone run",
            "drone_image_upload_camera_info"=>"micasense_5",
            "drone_image_upload_drone_run_band_stitching"=>"yes"
        ]
    );

#print STDERR Dumper $response;
ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = decode_json $message;
print STDERR Dumper $message_hash;
is($message_hash->{success}, 1);
is(scalar(@{$message_hash->{drone_run_band_project_ids}}), 5);

#Testing upload of RGB unstitched raw captures.
my $rgbrawimageszipfile = $f->config->{basepath}."/t/data/imagebreed/ExampleRGBRawImages.zip";
my $ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/api/drone_imagery/upload_drone_imagery',
        Content_Type => 'form-data',
        Content => [
            "sgn_session_id"=>$sgn_session_id,
            upload_drone_images_zipfile => [ $rgbrawimageszipfile, 'upload_drone_images_zipfile' ],
            "drone_run_field_trial_id"=>$field_trial_id,
            "drone_run_name"=>"NewRGBUnstitchedDroneRunProject",
            "drone_run_type"=>"Aerial Medium to High Res",
            "drone_run_date"=>"2019/01/01 12:12:12",
            "drone_run_description"=>"test new drone run",
            "drone_image_upload_camera_info"=>"ccd_color",
            "drone_image_upload_drone_run_band_stitching"=>"yes"
        ]
    );

#print STDERR Dumper $response;
ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = decode_json $message;
print STDERR Dumper $message_hash;
is($message_hash->{success}, 1);
is(scalar(@{$message_hash->{drone_run_band_project_ids}}), 1);

#Testing upload of RGB unstitched raw captures.
my $rasterblue = $f->config->{basepath}."/t/data/imagebreed/RasterBlue.png";
my $rastergreen = $f->config->{basepath}."/t/data/imagebreed/RasterGreen.png";
my $rasterred= $f->config->{basepath}."/t/data/imagebreed/RasterRed.png";
my $rasternir = $f->config->{basepath}."/t/data/imagebreed/RasterNIR.png";
my $rasterrededge = $f->config->{basepath}."/t/data/imagebreed/RasterRedEdge.png";
my $ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/api/drone_imagery/upload_drone_imagery',
        Content_Type => 'form-data',
        Content => [
            "sgn_session_id"=>$sgn_session_id,
            "drone_run_field_trial_id"=>$field_trial_id,
            "drone_run_name"=>"NewStitchedMicasense5BandDroneRunProject",
            "drone_run_type"=>"Aerial Medium to High Res",
            "drone_run_date"=>"2019/01/01 12:12:12",
            "drone_run_description"=>"test new drone run",
            "drone_image_upload_camera_info"=>"ccd_color",
            "drone_image_upload_drone_run_band_stitching"=>"no",
            "drone_run_band_number"=>5,
            "drone_run_band_name_1"=>"NewStitchedMicasense5BandDroneRunProject_Blue",
            "drone_run_band_description_1"=>"raster blue",
            "drone_run_band_type_1"=>"Blue (450-520nm)",
            drone_run_band_stitched_ortho_image_1 => [ $rasterblue, 'drone_run_band_stitched_ortho_image_1' ],
            "drone_run_band_name_2"=>"NewStitchedMicasense5BandDroneRunProject_Green",
            "drone_run_band_description_2"=>"raster green",
            "drone_run_band_type_2"=>"Green (515-600nm)",
            drone_run_band_stitched_ortho_image_2 => [ $rastergreen, 'drone_run_band_stitched_ortho_image_2' ],
            "drone_run_band_name_3"=>"NewStitchedMicasense5BandDroneRunProject_Red",
            "drone_run_band_description_3"=>"raster red",
            "drone_run_band_type_3"=>"Red (600-690nm)",
            drone_run_band_stitched_ortho_image_3 => [ $rasterred, 'drone_run_band_stitched_ortho_image_3' ],
            "drone_run_band_name_4"=>"NewStitchedMicasense5BandDroneRunProject_NIR",
            "drone_run_band_description_4"=>"raster NIR",
            "drone_run_band_type_4"=>"NIR (780-3000nm)",
            drone_run_band_stitched_ortho_image_4 => [ $rasternir, 'drone_run_band_stitched_ortho_image_4' ],
            "drone_run_band_name_5"=>"NewStitchedMicasense5BandDroneRunProject_RedEdge",
            "drone_run_band_description_5"=>"raster rededge",
            "drone_run_band_type_5"=>"Red Edge (690-750nm)",
            drone_run_band_stitched_ortho_image_5 => [ $rasterrededge, 'drone_run_band_stitched_ortho_image_5' ],
        ]
    );

#print STDERR Dumper $response;
ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = decode_json $message;
print STDERR Dumper $message_hash;
is($message_hash->{success}, 1);
is(scalar(@{$message_hash->{drone_run_band_project_ids}}), 5);

done_testing();
