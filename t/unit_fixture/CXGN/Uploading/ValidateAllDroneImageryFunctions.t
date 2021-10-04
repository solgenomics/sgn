
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use LWP::Simple;
use LWP::UserAgent;
use CXGN::Genotype::Protocol;
use CXGN::Genotype::Search;
use File::Basename;

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

ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = decode_json $message;
print STDERR Dumper $message_hash;
is_deeply($message_hash, {'success' => 1});

my $field_trial_id = $schema->resultset("Project::Project")->search({name => 'test_trial'})->first->project_id();

$response = $ua->get('http://localhost:3010/api/drone_imagery/new_imaging_vehicle?sgn_session_id='.$sgn_session_id.'&vehicle_name=Drone1&vehicle_description=dronedesc&battery_names=blue,green');
ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = decode_json $message;
print STDERR Dumper $message_hash;
ok($message_hash->{success});
ok($message_hash->{new_vehicle_id});
my $new_vehicle_id = $message_hash->{new_vehicle_id};

if ($f->config->{enable_opendronemap}) {

#Testing upload of unstitched Micasense RedEdge 5 band raw captures.
my $file_micasense5channel_image_zip = "/home/production/public/static_content/imagebreed/AlfalfaExample35MeterMicasenseAerialDroneFlightRawCaptures.zip";
my $micasense5bandpanelzipfile = $f->config->{basepath}."/t/data/imagebreed/ExampleAerialDroneFlightMicasensePanel.zip";
$ua = LWP::UserAgent->new;
$ua->timeout(3600);
my $response_micasense_stitch = $ua->post(
        'http://localhost:3010/api/drone_imagery/upload_drone_imagery',
        Content_Type => 'form-data',
        Content => [
            "sgn_session_id"=>$sgn_session_id,
            upload_drone_images_zipfile => [ $file_micasense5channel_image_zip, 'upload_drone_images_zipfile' ],
            upload_drone_images_panel_zipfile => [ $micasense5bandpanelzipfile, 'upload_drone_images_panel_zipfile' ],
            "drone_run_field_trial_id"=>$field_trial_id,
            "drone_run_name"=>"NewMicasenseUnstitchedDroneRunProject",
            "drone_run_type"=>"Aerial Medium to High Res",
            "drone_run_date"=>"2019/01/03 12:12:12",
            "drone_run_description"=>"test new drone run",
            "drone_run_imaging_vehicle_id"=>$new_vehicle_id,
            "drone_run_imaging_vehicle_battery_name"=>"blue",
            "drone_image_upload_camera_info"=>"micasense_5",
            "drone_image_upload_drone_run_band_stitching"=>"yes_open_data_map_stitch"
        ]
    );

ok($response_micasense_stitch->is_success);
my $message_micasense_stitch = $response_micasense_stitch->decoded_content;
my $message_hash_micasense_stitch = decode_json $message_micasense_stitch;
print STDERR Dumper $message_hash_micasense_stitch;
is($message_hash_micasense_stitch->{success}, 1);
is(scalar(@{$message_hash_micasense_stitch->{drone_run_band_project_ids}}), 6);
is(scalar(@{$message_hash_micasense_stitch->{drone_run_band_image_ids}}), 6);

#Testing upload of RGB unstitched raw captures.
my $rgbrawimageszipfile = "/home/production/public/static_content/imagebreed/ExampleColorAerialDroneFlightRawCaptures.zip";
$ua = LWP::UserAgent->new;
$ua->timeout(3600);
my $response_rgb_stitch = $ua->post(
        'http://localhost:3010/api/drone_imagery/upload_drone_imagery',
        Content_Type => 'form-data',
        Content => [
            "sgn_session_id"=>$sgn_session_id,
            upload_drone_images_zipfile => [ $rgbrawimageszipfile, 'upload_drone_images_zipfile' ],
            "drone_run_field_trial_id"=>$field_trial_id,
            "drone_run_name"=>"NewRGBUnstitchedDroneRunProject",
            "drone_run_type"=>"Aerial Medium to High Res",
            "drone_run_date"=>"2019/01/02 12:12:12",
            "drone_run_description"=>"test new drone run",
            "drone_run_imaging_vehicle_id"=>$new_vehicle_id,
            "drone_run_imaging_vehicle_battery_name"=>"blue",
            "drone_image_upload_camera_info"=>"ccd_color",
            "drone_image_upload_drone_run_band_stitching"=>"yes_open_data_map_stitch"
        ]
    );

ok($response_rgb_stitch->is_success);
my $message_rgb_stitch = $response_rgb_stitch->decoded_content;
my $message_hash_rgb_stitch = decode_json $message_rgb_stitch;
print STDERR Dumper $message_hash_rgb_stitch;
is($message_hash_rgb_stitch->{success}, 1);
is(scalar(@{$message_hash_rgb_stitch->{drone_run_band_project_ids}}), 2);
is(scalar(@{$message_hash_rgb_stitch->{drone_run_band_image_ids}}), 2);

}

#Testing upload of RGB unstitched raw captures.
my $rasterblue = $f->config->{basepath}."/t/data/imagebreed/RasterBlue.png";
my $rastergreen = $f->config->{basepath}."/t/data/imagebreed/RasterGreen.png";
my $rasterred= $f->config->{basepath}."/t/data/imagebreed/RasterRed.png";
my $rasternir = $f->config->{basepath}."/t/data/imagebreed/RasterNIR.png";
my $rasterrededge = $f->config->{basepath}."/t/data/imagebreed/RasterRedEdge.png";
$ua = LWP::UserAgent->new;
my $response_raster = $ua->post(
        'http://localhost:3010/api/drone_imagery/upload_drone_imagery',
        Content_Type => 'form-data',
        Content => [
            "sgn_session_id"=>$sgn_session_id,
            "drone_run_field_trial_id"=>$field_trial_id,
            "drone_run_name"=>"NewStitchedMicasense5BandDroneRunProject",
            "drone_run_type"=>"Aerial Medium to High Res",
            "drone_run_date"=>"2019/01/01 12:12:12",
            "drone_run_description"=>"test new drone run",
            "drone_image_upload_camera_info"=>"micasense_5",
            "drone_run_imaging_vehicle_id"=>$new_vehicle_id,
            "drone_run_imaging_vehicle_battery_name"=>"blue",
            "drone_image_upload_drone_run_band_stitching"=>"no",
            "drone_run_band_number"=>5,
            "drone_run_band_name_0"=>"NewStitchedMicasense5BandDroneRunProject_Blue",
            "drone_run_band_description_0"=>"raster blue",
            "drone_run_band_type_0"=>"Blue (450-520nm)",
            drone_run_band_stitched_ortho_image_0 => [ $rasterblue, basename($rasterblue) ],
            "drone_run_band_name_1"=>"NewStitchedMicasense5BandDroneRunProject_Green",
            "drone_run_band_description_1"=>"raster green",
            "drone_run_band_type_1"=>"Green (515-600nm)",
            drone_run_band_stitched_ortho_image_1 => [ $rastergreen, basename($rastergreen) ],
            "drone_run_band_name_2"=>"NewStitchedMicasense5BandDroneRunProject_Red",
            "drone_run_band_description_2"=>"raster red",
            "drone_run_band_type_2"=>"Red (600-690nm)",
            drone_run_band_stitched_ortho_image_2 => [ $rasterred, basename($rasterred) ],
            "drone_run_band_name_3"=>"NewStitchedMicasense5BandDroneRunProject_NIR",
            "drone_run_band_description_3"=>"raster NIR",
            "drone_run_band_type_3"=>"NIR (780-3000nm)",
            drone_run_band_stitched_ortho_image_3 => [ $rasternir, basename($rasternir) ],
            "drone_run_band_name_4"=>"NewStitchedMicasense5BandDroneRunProject_RedEdge",
            "drone_run_band_description_4"=>"raster rededge",
            "drone_run_band_type_4"=>"Red Edge (690-750nm)",
            drone_run_band_stitched_ortho_image_4 => [ $rasterrededge, basename($rasterrededge) ],
        ]
    );

ok($response_raster->is_success);
my $message_raster = $response_raster->decoded_content;
my $message_hash_raster = decode_json $message_raster;
print STDERR Dumper $message_hash_raster;
is($message_hash_raster->{success}, 1);
is(scalar(@{$message_hash_raster->{drone_run_band_project_ids}}), 5);
is(scalar(@{$message_hash_raster->{drone_run_band_image_ids}}), 5);
my $a_drone_run_project_id = $message_hash_raster->{drone_run_project_id};
ok($a_drone_run_project_id);

$ua = LWP::UserAgent->new;
my $response_get_image = $ua->get('http://localhost:3010/api/drone_imagery/get_image?sgn_session_id='.$sgn_session_id.'&image_id='.$message_hash_raster->{drone_run_band_image_ids}->[0]);
ok($response_get_image->is_success);
my $message_get_image = $response_get_image->decoded_content;
my $message_hash_get_image = decode_json $message_get_image;
print STDERR Dumper $message_hash_get_image;
ok($message_hash_get_image->{image_url});
ok($message_hash_get_image->{image_fullpath});
is($message_hash_get_image->{image_width}, 1280);
is($message_hash_get_image->{image_height}, 960);


$ua = LWP::UserAgent->new;
my $response_denoised = $ua->get('http://localhost:3010/api/drone_imagery/denoise?sgn_session_id='.$sgn_session_id.'&image_id='.$message_hash_raster->{drone_run_band_image_ids}->[0].'&drone_run_band_project_id='.$message_hash_raster->{drone_run_band_project_ids}->[0]);
ok($response_denoised->is_success);
my $message_denoised = $response_denoised->decoded_content;
my $message_hash_denoised = decode_json $message_denoised;
print STDERR Dumper $message_hash_denoised;
ok($message_hash_denoised->{denoised_image_id});
ok($message_hash_denoised->{denoised_image_url});

my $sp_rotate_angle = "2.1";
my $sp_rotate_angle_rad = $sp_rotate_angle*0.0174533;

$ua = LWP::UserAgent->new;
my $response_rotate = $ua->get('http://localhost:3010/api/drone_imagery/rotate_image?sgn_session_id='.$sgn_session_id.'&image_id='.$message_hash_denoised->{denoised_image_id}.'&drone_run_band_project_id='.$message_hash_raster->{drone_run_band_project_ids}->[0].'&angle='.$sp_rotate_angle.'&view_only=0');
ok($response_rotate->is_success);
my $message_rotate = $response_rotate->decoded_content;
my $message_hash_rotate = decode_json $message_rotate;
print STDERR Dumper $message_hash_rotate;
ok($message_hash_rotate->{rotated_image_id});
ok($message_hash_rotate->{rotated_image_url});

my $crop_polygon = [{'x'=>100, 'y'=>100}, {'x'=>120, 'y'=>100}, {'x'=>120, 'y'=>80}, {'x'=>100, 'y'=>70}];
my $polygon_crop = encode_json $crop_polygon;
$ua = LWP::UserAgent->new;
my $response_crop = $ua->get('http://localhost:3010/api/drone_imagery/crop_image?sgn_session_id='.$sgn_session_id.'&image_id='.$message_hash_rotate->{rotated_image_id}.'&drone_run_band_project_id='.$message_hash_raster->{drone_run_band_project_ids}->[0].'&polygon='.$polygon_crop);
ok($response_crop->is_success);
my $message_crop = $response_crop->decoded_content;
my $message_hash_crop = decode_json $message_crop;
print STDERR Dumper $message_hash_crop;
ok($message_hash_crop->{cropped_image_id});
ok($message_hash_crop->{cropped_image_url});

$ua = LWP::UserAgent->new;
my $response_background_removed = $ua->post('http://localhost:3010/api/drone_imagery/remove_background_save?sgn_session_id='.$sgn_session_id.'&image_id='.$message_hash_crop->{cropped_image_id}.'&image_type=threshold_background_removed_stitched_drone_imagery_blue&lower_threshold=20&upper_threshold=180&drone_run_band_project_id='.$message_hash_raster->{drone_run_band_project_ids}->[0]);
ok($response_background_removed->is_success);
my $message_background_removed = $response_background_removed->decoded_content;
my $message_hash_background_removed = decode_json $message_background_removed;
print STDERR Dumper $message_hash_background_removed;
ok($message_hash_background_removed->{removed_background_image_id});
ok($message_hash_background_removed->{removed_background_image_url});

$ua = LWP::UserAgent->new;
my $response_background_removed_percentage = $ua->post('http://localhost:3010/api/drone_imagery/remove_background_percentage_save?sgn_session_id='.$sgn_session_id.'&image_id='.$message_hash_crop->{cropped_image_id}.'&image_type_list=threshold_background_removed_stitched_drone_imagery_blue&lower_threshold_percentage=20&upper_threshold_percentage=20&drone_run_band_project_id='.$message_hash_raster->{drone_run_band_project_ids}->[0]);
ok($response_background_removed_percentage->is_success);
my $message_background_removed_percentage = $response_background_removed_percentage->decoded_content;
my $message_hash_background_removed_percentage = decode_json $message_background_removed_percentage;
print STDERR Dumper $message_hash_background_removed_percentage;
ok($message_hash_background_removed_percentage->[0]->{removed_background_image_id});
ok($message_hash_background_removed_percentage->[0]->{removed_background_image_url});

$ua = LWP::UserAgent->new;
my $response_contours = $ua->get('http://localhost:3010/api/drone_imagery/get_contours?sgn_session_id='.$sgn_session_id.'&image_id='.$message_hash_raster->{drone_run_band_image_ids}->[0].'&drone_run_band_project_id='.$message_hash_raster->{drone_run_band_project_ids}->[0]);
ok($response_contours->is_success);
my $message_contours = $response_contours->decoded_content;
my $message_hash_contours = decode_json $message_contours;
print STDERR Dumper $message_hash_contours;
ok($message_hash_contours->{contours_image_id});
ok($message_hash_contours->{contours_image_url});

my %stock_polygons = ('test_trial1' => [{'x'=>1, 'y'=>1}, {'x'=>12, 'y'=>1}, {'x'=>12, 'y'=>8}, {'x'=>1, 'y'=>7}, {'x'=>1, 'y'=>1}]);
my $stock_polygon_json = encode_json \%stock_polygons;

$ua = LWP::UserAgent->new;
my $response_save_template = $ua->post('http://localhost:3010/api/drone_imagery/save_plot_polygons_template?sgn_session_id='.$sgn_session_id.'&drone_run_band_project_id='.$message_hash_raster->{drone_run_band_project_ids}->[0].'&stock_polygons='.$stock_polygon_json);
ok($response_save_template->is_success);
my $message_save_template = $response_save_template->decoded_content;
my $message_hash_save_template = decode_json $message_save_template;
print STDERR Dumper $message_hash_save_template;
ok($message_hash_save_template->{success});
ok($message_hash_save_template->{drone_run_band_template_id});

$ua = LWP::UserAgent->new;
my $response_assign_plot_polygons = $ua->post('http://localhost:3010/api/drone_imagery/assign_plot_polygons?sgn_session_id='.$sgn_session_id.'&image_id='.$message_hash_crop->{cropped_image_id}.'&drone_run_band_project_id='.$message_hash_raster->{drone_run_band_project_ids}->[0].'&stock_polygons='.$stock_polygon_json.'&assign_plot_polygons_type=observation_unit_polygon_blue_imagery');
ok($response_assign_plot_polygons->is_success);
my $message_assign_plot_polygons = $response_assign_plot_polygons->decoded_content;
my $message_hash_assign_plot_polygons = decode_json $message_assign_plot_polygons;
print STDERR Dumper $message_hash_assign_plot_polygons;
ok($message_hash_assign_plot_polygons->{success});
ok($message_hash_assign_plot_polygons->{drone_run_band_template_id});

$ua = LWP::UserAgent->new;
my $response_get_template = $ua->get('http://localhost:3010/api/drone_imagery/retrieve_parameter_template?plot_polygons_template_projectprop_id='.$message_hash_assign_plot_polygons->{drone_run_band_template_id});
ok($response_get_template->is_success);
my $message_get_template = $response_get_template->decoded_content;
my $message_hash_get_template = decode_json $message_get_template;
print STDERR Dumper $message_hash_get_template;
ok($message_hash_get_template->{success});
ok($message_hash_get_template->{parameter});

$ua = LWP::UserAgent->new;
my $response_drone_runs = $ua->get('http://localhost:3010/api/drone_imagery/drone_runs?select_checkbox_name=drone_test_checkbox&field_trial_id='.$field_trial_id);
ok($response_drone_runs->is_success);
my $message_drone_runs = $response_drone_runs->decoded_content;
my $message_hash_drone_runs = decode_json $message_drone_runs;
print STDERR Dumper $message_hash_drone_runs;
if ($f->config->{enable_opendronemap}) {
is(scalar(@{$message_hash_drone_runs->{data}}), 3);
}
else {
is(scalar(@{$message_hash_drone_runs->{data}}), 1);
}

$ua = LWP::UserAgent->new;
my $response_image_types = $ua->get('http://localhost:3010/api/drone_imagery/plot_polygon_types?select_checkbox_name=drone_test_checkbox&field_trial_id='.$field_trial_id);
ok($response_image_types->is_success);
my $message_image_types = $response_image_types->decoded_content;
my $message_hash_image_types = decode_json $message_image_types;
print STDERR Dumper $message_hash_image_types;
is(scalar(@{$message_hash_image_types->{data}}), 1);

$ua = LWP::UserAgent->new;
my $response_drone_run_bands = $ua->get('http://localhost:3010/api/drone_imagery/drone_run_bands?select_checkbox_name=drone_test_checkbox&field_trial_id='.$field_trial_id.'&drone_run_project_id='.$message_hash_raster->{drone_run_project_id});
ok($response_drone_run_bands->is_success);
my $message_drone_run_bands = $response_drone_run_bands->decoded_content;
my $message_hash_drone_run_bands = decode_json $message_drone_run_bands;
print STDERR Dumper $message_hash_drone_run_bands;
is(scalar(@{$message_hash_drone_run_bands->{data}}), 5);

$ua = LWP::UserAgent->new;
my $response_weeks_after_planting = $ua->get('http://localhost:3010/api/drone_imagery/get_weeks_after_planting_date?select_checkbox_name=drone_test_checkbox&field_trial_id='.$field_trial_id.'&drone_run_project_id='.$message_hash_raster->{drone_run_project_id});
ok($response_weeks_after_planting->is_success);
my $message_weeks_after_planting = $response_weeks_after_planting->decoded_content;
my $message_hash_weeks_after_planting = decode_json $message_weeks_after_planting;
my $message_hash_days_time_cvterm_id = $message_hash_weeks_after_planting->{time_ontology_day_cvterm_id};
ok($message_hash_days_time_cvterm_id);
print STDERR Dumper $message_hash_weeks_after_planting;
ok($message_hash_weeks_after_planting->{drone_run_date});
is($message_hash_weeks_after_planting->{rounded_time_difference_weeks}, 78);

$ua = LWP::UserAgent->new;
$ua->timeout(1200);
my $apply_drone_run_band_project_ids = encode_json $message_hash_raster->{drone_run_band_project_ids};
my $vegetative_indices = encode_json ['TGI','VARI','NDVI','NDRE'];
my $response_standard_process = $ua->post('http://localhost:3010/api/drone_imagery/standard_process_apply?sgn_session_id='.$sgn_session_id.'&apply_drone_run_band_project_ids='.$apply_drone_run_band_project_ids.'&drone_run_band_project_id='.$message_hash_raster->{drone_run_band_project_ids}->[0].'&drone_run_project_id='.$message_hash_raster->{drone_run_project_id}.'&vegetative_indices='.$vegetative_indices.'&field_trial_id='.$field_trial_id);
ok($response_standard_process->is_success);
my $message_standard_process = $response_standard_process->decoded_content;
my $message_hash_standard_process = decode_json $message_standard_process;
print STDERR Dumper $message_hash_standard_process;
ok($message_hash_standard_process->{success});

# my $response_extended = $ua->get('http://localhost:3010/api/drone_imagery/standard_process_extended_apply?sgn_session_id='.$sgn_session_id.'&drone_run_project_id='.$message_hash_raster->{drone_run_project_id});
# ok($response_extended->is_success);
# my $message_extended = $response_extended->decoded_content;
# my $message_hash_extended = decode_json $message_extended;
# print STDERR Dumper $message_hash_extended;
# ok($message_hash_extended->{success});

$ua = LWP::UserAgent->new;
my $saving_gcp_template_1 = $ua->post(
        'http://localhost:3010/api/drone_imagery/saving_gcp',
        Content_Type => 'form-data',
        Content => [
            "sgn_session_id"=>$sgn_session_id,
            "drone_run_project_id"=>$a_drone_run_project_id,
            "name"=>"GCP1",
            "x_pos"=>"101",
            "y_pos"=>"101",
            "latitude"=>"62.21",
            "longitude"=>"-79.11"
        ]
    );
ok($saving_gcp_template_1->is_success);

my $saving_gcp_template_2 = $ua->post(
        'http://localhost:3010/api/drone_imagery/saving_gcp',
        Content_Type => 'form-data',
        Content => [
            "sgn_session_id"=>$sgn_session_id,
            "drone_run_project_id"=>$a_drone_run_project_id,
            "name"=>"GCP2",
            "x_pos"=>"105",
            "y_pos"=>"105",
            "latitude"=>"63.21",
            "longitude"=>"-78.11"
        ]
    );
ok($saving_gcp_template_2->is_success);

my $saving_gcp_template_3 = $ua->post(
        'http://localhost:3010/api/drone_imagery/saving_gcp',
        Content_Type => 'form-data',
        Content => [
            "sgn_session_id"=>$sgn_session_id,
            "drone_run_project_id"=>$a_drone_run_project_id,
            "name"=>"GCP3",
            "x_pos"=>"101",
            "y_pos"=>"105",
            "latitude"=>"",
            "longitude"=>""
        ]
    );
ok($saving_gcp_template_3->is_success);

my $saving_gcp_template_4 = $ua->post(
        'http://localhost:3010/api/drone_imagery/saving_gcp',
        Content_Type => 'form-data',
        Content => [
            "sgn_session_id"=>$sgn_session_id,
            "drone_run_project_id"=>$a_drone_run_project_id,
            "name"=>"GCP4",
            "x_pos"=>"102",
            "y_pos"=>"105",
            "latitude"=>"",
            "longitude"=>""
        ]
    );
ok($saving_gcp_template_4->is_success);

my $message_save_gcp_template = $saving_gcp_template_4->decoded_content;
my $message_hash_gcp_template = decode_json $message_save_gcp_template;
print STDERR Dumper $message_hash_gcp_template;
is_deeply($message_hash_gcp_template->{saved_gcps_full}, {'GCP4' => {'x_pos' => '102','longitude' => '','name' => 'GCP4','latitude' => '','y_pos' => '105'},'GCP3' => {'longitude' => '','x_pos' => '101','y_pos' => '105','latitude' => '','name' => 'GCP3'},'GCP2' => {'x_pos' => '105','longitude' => '-78.11','name' => 'GCP2','latitude' => '63.21','y_pos' => '105'},'GCP1' => {'name' => 'GCP1','latitude' => '62.21','y_pos' => '101','x_pos' => '101','longitude' => '-79.11'}} );


$ua = LWP::UserAgent->new;
my $response_raster_gcp_run = $ua->post(
        'http://localhost:3010/api/drone_imagery/upload_drone_imagery',
        Content_Type => 'form-data',
        Content => [
            "sgn_session_id"=>$sgn_session_id,
            "drone_run_field_trial_id"=>$field_trial_id,
            "drone_run_name"=>"NewStitchedMicasense5BandDroneRunProjectForGCPStandardProcess",
            "drone_run_type"=>"Aerial Medium to High Res",
            "drone_run_date"=>"2019/01/01 18:12:12",
            "drone_run_description"=>"test new drone run",
            "drone_image_upload_camera_info"=>"micasense_5",
            "drone_image_upload_drone_run_band_stitching"=>"no",
            "drone_run_imaging_vehicle_id"=>$new_vehicle_id,
            "drone_run_imaging_vehicle_battery_name"=>"blue",
            "drone_run_band_number"=>5,
            "drone_run_band_name_0"=>"NewStitchedMicasense5BandDroneRunProjectForGCPStandardProcess_Blue",
            "drone_run_band_description_0"=>"raster blue",
            "drone_run_band_type_0"=>"Blue (450-520nm)",
            drone_run_band_stitched_ortho_image_0 => [ $rasterblue, basename($rasterblue) ],
            "drone_run_band_name_1"=>"NewStitchedMicasense5BandDroneRunProjectForGCPStandardProcess_Green",
            "drone_run_band_description_1"=>"raster green",
            "drone_run_band_type_1"=>"Green (515-600nm)",
            drone_run_band_stitched_ortho_image_1 => [ $rastergreen, basename($rastergreen) ],
            "drone_run_band_name_2"=>"NewStitchedMicasense5BandDroneRunProjectForGCPStandardProcess_Red",
            "drone_run_band_description_2"=>"raster red",
            "drone_run_band_type_2"=>"Red (600-690nm)",
            drone_run_band_stitched_ortho_image_2 => [ $rasterred, basename($rasterred) ],
            "drone_run_band_name_3"=>"NewStitchedMicasense5BandDroneRunProjectForGCPStandardProcess_NIR",
            "drone_run_band_description_3"=>"raster NIR",
            "drone_run_band_type_3"=>"NIR (780-3000nm)",
            drone_run_band_stitched_ortho_image_3 => [ $rasternir, basename($rasternir) ],
            "drone_run_band_name_4"=>"NewStitchedMicasense5BandDroneRunProjectForGCPStandardProcess_RedEdge",
            "drone_run_band_description_4"=>"raster rededge",
            "drone_run_band_type_4"=>"Red Edge (690-750nm)",
            drone_run_band_stitched_ortho_image_4 => [ $rasterrededge, basename($rasterrededge) ],
        ]
    );

ok($response_raster_gcp_run->is_success);
my $message_raster_gcp_run = $response_raster_gcp_run->decoded_content;
my $message_hash_raster_gcp_run = decode_json $message_raster_gcp_run;
print STDERR Dumper $message_hash_raster_gcp_run;
is($message_hash_raster_gcp_run->{success}, 1);
is(scalar(@{$message_hash_raster_gcp_run->{drone_run_band_project_ids}}), 5);
is(scalar(@{$message_hash_raster_gcp_run->{drone_run_band_image_ids}}), 5);
my $gcp_apply_drone_run_project_id = $message_hash_raster_gcp_run->{drone_run_project_id};
ok($gcp_apply_drone_run_project_id);

my $saving_gcp_target_1 = $ua->post(
        'http://localhost:3010/api/drone_imagery/saving_gcp',
        Content_Type => 'form-data',
        Content => [
            "sgn_session_id"=>$sgn_session_id,
            "drone_run_project_id"=>$gcp_apply_drone_run_project_id,
            "name"=>"GCP1",
            "x_pos"=>"202",
            "y_pos"=>"202",
            "latitude"=>"62.21",
            "longitude"=>"-79.11"
        ]
    );
ok($saving_gcp_target_1->is_success);

my $saving_gcp_target_2 = $ua->post(
        'http://localhost:3010/api/drone_imagery/saving_gcp',
        Content_Type => 'form-data',
        Content => [
            "sgn_session_id"=>$sgn_session_id,
            "drone_run_project_id"=>$gcp_apply_drone_run_project_id,
            "name"=>"GCP2",
            "x_pos"=>"206",
            "y_pos"=>"206",
            "latitude"=>"63.21",
            "longitude"=>"-78.11"
        ]
    );
ok($saving_gcp_target_2->is_success);

my $saving_gcp_target_3 = $ua->post(
        'http://localhost:3010/api/drone_imagery/saving_gcp',
        Content_Type => 'form-data',
        Content => [
            "sgn_session_id"=>$sgn_session_id,
            "drone_run_project_id"=>$gcp_apply_drone_run_project_id,
            "name"=>"GCP3",
            "x_pos"=>"202",
            "y_pos"=>"206",
            "latitude"=>"",
            "longitude"=>""
        ]
    );
ok($saving_gcp_target_3->is_success);

my $saving_gcp_target_4 = $ua->post(
        'http://localhost:3010/api/drone_imagery/saving_gcp',
        Content_Type => 'form-data',
        Content => [
            "sgn_session_id"=>$sgn_session_id,
            "drone_run_project_id"=>$gcp_apply_drone_run_project_id,
            "name"=>"GCP4",
            "x_pos"=>"203",
            "y_pos"=>"206",
            "latitude"=>"",
            "longitude"=>""
        ]
    );
ok($saving_gcp_target_4->is_success);

$ua = LWP::UserAgent->new;
$ua->timeout(1200);
my $response_raster_gcp_apply = $ua->post('http://localhost:3010/api/drone_imagery/standard_process_apply_ground_control_points?sgn_session_id='.$sgn_session_id.'&gcp_drone_run_project_id='.$a_drone_run_project_id.'&field_trial_id='.$field_trial_id.'&drone_run_project_id='.$gcp_apply_drone_run_project_id.'&drone_run_band_project_id='.$message_hash_raster_gcp_run->{drone_run_band_project_ids}->[3].'&time_cvterm_id='.$message_hash_days_time_cvterm_id.'&is_test=1&test_run=No');
ok($response_raster_gcp_apply->is_success);
my $message_raster_gcp_apply = $response_raster_gcp_apply->decoded_content;
my $message_hash_raster_gcp_apply = decode_json $message_raster_gcp_apply;
print STDERR Dumper $message_hash_raster_gcp_apply;
is($message_hash_raster_gcp_apply->{success}, 1);



my $response_project_md_image = $ua->get('http://localhost:3010/api/drone_imagery/get_project_md_image?sgn_session_id='.$sgn_session_id.'&drone_run_band_project_id='.$message_hash_raster->{drone_run_band_project_ids}->[0].'&project_image_type_name=observation_unit_polygon_blue_imagery');
ok($response_project_md_image->is_success);
my $message_project_md_image = $response_project_md_image->decoded_content;
my $message_hash_project_md_image = decode_json $message_project_md_image;
print STDERR Dumper $message_hash_project_md_image;
ok($message_hash_project_md_image->{data});

my $response_remove_image = $ua->get('http://localhost:3010/api/drone_imagery/remove_image?sgn_session_id='.$sgn_session_id.'&image_id='.$message_hash_raster->{drone_run_band_image_ids}->[0]);
ok($response_remove_image->is_success);
my $message_remove_image = $response_remove_image->decoded_content;
my $message_hash_remove_image = decode_json $message_remove_image;
print STDERR Dumper $message_hash_remove_image;
ok($message_hash_remove_image->{status});

#Testing upload of bulk imaging events

my $file_previous_geotiff_image_zip = "/home/production/public/static_content/imagebreed/RiceExampleRGBandDSMOrthophotosGeoTIFFs.zip";
my $file_previous_geojson_zip = "/home/production/public/static_content/imagebreed/RiceExampleGeoJSONs.zip";
my $file_previous_imaging_events = "/home/production/public/static_content/imagebreed/RiceExampleRGBandDSMGeoJSONImagingEvent.xls";

my $bulk_loading_csv = $f->config->{basepath}."/t/data/imagebreed/bulk_loading/BTI_rig_images.xls";
my $bulk_loading_image_zip = $f->config->{basepath}."/t/data/imagebreed/bulk_loading/BTI_rig_images.zip";


 SKIP: {
     skip 'Some required files not available for these tests', 6, unless ( (-e $file_previous_geotiff_image_zip) && (-e $file_previous_geojson_zip) && (-e $file_previous_imaging_events) && (-e $bulk_loading_csv) && (-e $bulk_loading_image_zip)); 


     $ua = LWP::UserAgent->new;
     $ua->timeout(3600);
     my $response_raster = $ua->post(
	 'http://localhost:3010/drone_imagery/upload_drone_imagery_bulk',
	 Content_Type => 'form-data',
	 Content => [
	     "sgn_session_id"=>$sgn_session_id,
	     upload_drone_imagery_bulk_images_zipfile => [ $bulk_loading_image_zip, basename($bulk_loading_image_zip) ],
            upload_drone_imagery_bulk_imaging_events => [ $bulk_loading_csv, basename($bulk_loading_csv) ],
	 ]
	 );
     
     ok($response_raster->is_success);
     my $message_raster = $response_raster->decoded_content;
     print STDERR Dumper $message_raster;
     ok($message_raster =~ /Successfully uploaded!/);
     
     
     $ua = LWP::UserAgent->new;
     $ua->timeout(3600);
     my $response_raster = $ua->post(
	 'http://localhost:3010/drone_imagery/upload_drone_imagery_bulk_previous',
	 Content_Type => 'form-data',
	 Content => [
	     "sgn_session_id"=>$sgn_session_id,
	     upload_drone_imagery_bulk_images_zipfile_previous => [ $file_previous_geotiff_image_zip, basename($file_previous_geotiff_image_zip) ],
	     upload_drone_imagery_bulk_geojson_zipfile_previous => [ $file_previous_geojson_zip, basename($file_previous_geojson_zip) ],
	     upload_drone_imagery_bulk_imaging_events_previous => [ $file_previous_imaging_events, basename($file_previous_imaging_events) ],
	 ]
	 );
     
     ok($response_raster->is_success);
     my $message_raster = $response_raster->decoded_content;
     print STDERR Dumper $message_raster;
     ok($message_raster =~ /Successfully uploaded!/);
     
     my $rasterblue = $f->config->{basepath}."/t/data/imagebreed/RasterBlue.png";
     my $rastergreen = $f->config->{basepath}."/t/data/imagebreed/RasterGreen.png";
     my $rasterred= $f->config->{basepath}."/t/data/imagebreed/RasterRed.png";
     my $rasternir = $f->config->{basepath}."/t/data/imagebreed/RasterNIR.png";
     my $rasterrededge = $f->config->{basepath}."/t/data/imagebreed/RasterRedEdge.png";
     $ua = LWP::UserAgent->new;
     $ua->timeout(3600);
     my $response_raster = $ua->post(
	 'http://localhost:3010/drone_imagery/upload_drone_imagery',
	 Content_Type => 'form-data',
	 Content => [
	     "sgn_session_id"=>$sgn_session_id,
	     "drone_run_field_trial_id"=>$field_trial_id,
	     "drone_run_name"=>"NewStitchedMicasense5BandDroneRunProjectTESTING",
	     "drone_run_type"=>"Aerial Medium to High Res",
	     "drone_run_date"=>"2019/02/01 13:14:15",
	     "drone_run_description"=>"test new drone run",
	     "drone_image_upload_camera_info"=>"micasense_5",
	     "drone_run_imaging_vehicle_id"=>$new_vehicle_id,
	     "drone_run_imaging_vehicle_battery_name"=>"blue",
	     "drone_image_upload_drone_run_band_stitching"=>"no",
	     "drone_run_band_number"=>5,
	     "drone_run_band_name_1"=>"NewStitchedMicasense5BandDroneRunProjectTESTING_Blue",
	     "drone_run_band_description_1"=>"raster blue",
	     "drone_run_band_type_1"=>"Blue (450-520nm)",
	     drone_run_band_stitched_ortho_image_1 => [ $rasterblue, basename($rasterblue) ],
	     "drone_run_band_name_2"=>"NewStitchedMicasense5BandDroneRunProjectTESTING_Green",
	     "drone_run_band_description_2"=>"raster green",
	     "drone_run_band_type_2"=>"Green (515-600nm)",
	     drone_run_band_stitched_ortho_image_2 => [ $rastergreen, basename($rastergreen) ],
	     "drone_run_band_name_3"=>"NewStitchedMicasense5BandDroneRunProjectTESTING_Red",
	     "drone_run_band_description_3"=>"raster red",
	     "drone_run_band_type_3"=>"Red (600-690nm)",
	     drone_run_band_stitched_ortho_image_3 => [ $rasterred, basename($rasterred) ],
	     "drone_run_band_name_4"=>"NewStitchedMicasense5BandDroneRunProjectTESTING_NIR",
	     "drone_run_band_description_4"=>"raster NIR",
	     "drone_run_band_type_4"=>"NIR (780-3000nm)",
	     drone_run_band_stitched_ortho_image_4 => [ $rasternir, basename($rasternir) ],
	     "drone_run_band_name_5"=>"NewStitchedMicasense5BandDroneRunProjectTESTING_RedEdge",
	     "drone_run_band_description_5"=>"raster rededge",
	     "drone_run_band_type_5"=>"Red Edge (690-750nm)",
	     drone_run_band_stitched_ortho_image_5 => [ $rasterrededge, basename($rasterrededge) ],
	 ]
	 );
     
     ok($response_raster->is_success);
     my $message_raster = $response_raster->decoded_content;
     print STDERR Dumper $message_raster;
     ok($message_raster =~ /Successfully uploaded!/);
};
     
done_testing();
