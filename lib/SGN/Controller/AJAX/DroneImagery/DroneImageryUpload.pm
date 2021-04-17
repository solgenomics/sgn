
=head1 NAME

SGN::Controller::AJAX::DroneImagery::DroneImageryUpload - a REST controller class to provide the
functions for uploading drone imagery into the database. All other functions are
controlled by SGN::Controller::AJAX::DroneImagery

=head1 DESCRIPTION

=head1 AUTHOR

=cut

package SGN::Controller::AJAX::DroneImagery::DroneImageryUpload;

use Moose;
use Data::Dumper;
use JSON;
use SGN::Model::Cvterm;
use DateTime;
use Math::Round;
use Time::Piece;
use Time::Seconds;
use SGN::Image;
use CXGN::DroneImagery::ImagesSearch;
use File::Basename qw | basename dirname|;
use URI::Encode qw(uri_encode uri_decode);
use CXGN::Calendar;
use Image::Size;
use CXGN::DroneImagery::ImageTypes;
use LWP::UserAgent;
use CXGN::ZipFile;
use Text::CSV;
use SGN::Controller::AJAX::DroneImagery::DroneImagery;
#use Inline::Python;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
);

sub upload_drone_imagery_check_drone_name : Path('/api/drone_imagery/upload_drone_imagery_check_drone_name') : ActionClass('REST') { }
sub upload_drone_imagery_check_drone_name_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    $c->response->headers->header( "Access-Control-Allow-Origin" => '*' );
    my $drone_name = $c->req->param('drone_run_name');
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    my $project_rs = $schema->resultset("Project::Project")->search({name=>$drone_name});
    if ($project_rs->count > 0) {
        $c->stash->{rest} = { error => "Please use a globally unique drone run name! The name you specified has already ben used." };
        $c->detach();
    }
    else {
        $c->stash->{rest} = { success => 1 };
        $c->detach();
    }
}

sub upload_drone_imagery : Path('/api/drone_imagery/upload_drone_imagery') : ActionClass('REST') { }
sub upload_drone_imagery_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    $c->response->headers->header( "Access-Control-Allow-Origin" => '*' );
    $c->response->headers->header( "Access-Control-Allow-Methods" => "POST, GET, PUT, DELETE" );
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    print STDERR Dumper $c->req->params();

    my $selected_trial_id = $c->req->param('drone_run_field_trial_id');
    if (!$selected_trial_id) {
        $c->stash->{rest} = { error => "Please select a field trial!" };
        $c->detach();
    }
    my $selected_drone_run_id = $c->req->param('drone_run_id');
    my $new_drone_run_name = $c->req->param('drone_run_name');
    my $new_drone_run_type = $c->req->param('drone_run_type');
    my $new_drone_run_date = $c->req->param('drone_run_date');
    my $new_drone_base_date = $c->req->param('drone_run_base_date');
    my $new_drone_run_desc = $c->req->param('drone_run_description');
    my $new_drone_rig_desc = $c->req->param('drone_run_camera_rig_description');
    my $new_drone_run_vehicle_id = $c->req->param('drone_run_imaging_vehicle_id');
    my $new_drone_run_battery_name = $c->req->param('drone_run_imaging_vehicle_battery_name');

    if (!$new_drone_run_vehicle_id) {
        $c->stash->{rest} = { error => "Please give an imaging event vehicle id!" };
        $c->detach();
    }

    if (!$selected_drone_run_id && !$new_drone_run_name) {
        $c->stash->{rest} = { error => "Please select an imaging event or create a new imaging event!" };
        $c->detach();
    }
    # if ($selected_drone_run_id && $new_drone_run_name){
    #     $c->stash->{rest} = { error => "Please select a drone run OR create a new drone run, not both!" };
    #     $c->detach();
    # }
    if ($new_drone_run_name && !$new_drone_run_type){
        $c->stash->{rest} = { error => "Please give a new imaging event type!" };
        $c->detach();
    }
    if ($new_drone_run_name && !$new_drone_run_date){
        $c->stash->{rest} = { error => "Please give a new imaging event date!" };
        $c->detach();
    }
    if ($new_drone_run_name && $new_drone_run_date !~ /^\d{4}\/\d{2}\/\d{2}\s\d\d:\d\d:\d\d$/){
        $c->stash->{rest} = { error => "Please give a new imaging event date in the format YYYY/MM/DD HH:mm:ss!" };
        $c->detach();
    }
    if ($new_drone_run_name && $new_drone_base_date && $new_drone_run_date !~ /^\d{4}\/\d{2}\/\d{2}\s\d\d:\d\d:\d\d$/){
        $c->stash->{rest} = { error => "Please give a new imaging event base date in the format YYYY/MM/DD HH:mm:ss!" };
        $c->detach();
    }

    if ($new_drone_run_name && !$new_drone_run_desc){
        $c->stash->{rest} = { error => "Please give a new imaging event description!" };
        $c->detach();
    }

    my $new_drone_run_camera_info = $c->req->param('drone_image_upload_camera_info');
    my $new_drone_run_band_numbers = $c->req->param('drone_run_band_number');
    my $new_drone_run_band_stitching = $c->req->param('drone_image_upload_drone_run_band_stitching');
    my $new_drone_run_band_stitching_odm_more_images = $c->req->param('drone_image_upload_drone_run_band_stitching_odm_more_images') || 'No';
    my $new_drone_run_band_stitching_odm_current_image_count = $c->req->param('drone_image_upload_drone_run_band_stitching_odm_image_count') || 0;
    my $new_drone_run_band_stitching_odm_radiocalibration = $c->req->param('drone_image_upload_drone_run_band_stitching_odm_radiocalibration') eq "Yes" ? 1 : 0;

    if (!$new_drone_run_camera_info) {
        $c->stash->{rest} = { error => "Please indicate the type of camera!" };
        $c->detach();
    }

    if ($new_drone_run_band_stitching eq 'no' && !$new_drone_run_band_numbers) {
        $c->stash->{rest} = { error => "Please give the number of new imaging event bands!" };
        $c->detach();
    }
    if (!$new_drone_run_band_stitching) {
        $c->stash->{rest} = { error => "Please indicate if the images are stitched!" };
        $c->detach();
    }

    my $odm_process_running_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_opendronemap_process_running', 'project_property')->cvterm_id();
    if ($new_drone_run_band_stitching eq 'yes_open_data_map_stitch') {
        my $upload_file = $c->req->upload('upload_drone_images_zipfile');
        my $upload_panel_file = $c->req->upload('upload_drone_images_panel_zipfile');
        if (!$upload_file) {
            $c->stash->{rest} = { error => "Please provide a zipfile of raw images!" };
            $c->detach();
        }
        if (!$upload_panel_file && $new_drone_run_camera_info eq 'micasense_5') {
            $c->stash->{rest} = { error => "Please provide a zipfile of images of the Micasense radiometric calibration panels!" };
            $c->detach();
        }

        my $q = "SELECT count(*) FROM projectprop WHERE type_id=$odm_process_running_cvterm_id AND value='1';";
        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute();
        my ($odm_running_count) = $h->fetchrow_array();
        if ($odm_running_count >= $c->config->{opendronemap_max_processes}) {
            $c->stash->{rest} = { error => "There are already the maximum number of OpenDroneMap processes running on this machine! Please check back later when those processes are complete." };
            $c->detach();
        }
    }

    # if ($selected_drone_run_id && ($new_drone_run_band_stitching eq 'yes' || $new_drone_run_band_stitching eq 'yes_raw' || $new_drone_run_band_stitching eq 'yes_automated')) {
    #     $c->stash->{rest} = { error => "Please create a new drone run if you are uploading a zipfile of raw images!" };
    #     $c->detach();
    # }

    my $log_file_path = '';
    if ($c->config->{error_log}){
        $log_file_path = "--log_file_path '".$c->config->{error_log}."'";
    }

    my $drone_run_nd_experiment_id;
    if (!$selected_drone_run_id) {
        my $drone_run_field_trial_project_relationship_type_id_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
        my $drone_run_band_drone_run_project_relationship_type_id_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
        my $project_start_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_start_date', 'project_property')->cvterm_id();

        my $calendar_funcs = CXGN::Calendar->new({});

        my %seen_field_trial_drone_run_dates;
        my $drone_run_date_q = "SELECT drone_run_date.value
            FROM project AS drone_run_band_project
            JOIN project_relationship AS drone_run_band_rel ON (drone_run_band_rel.subject_project_id = drone_run_band_project.project_id AND drone_run_band_rel.type_id = $drone_run_band_drone_run_project_relationship_type_id_cvterm_id)
            JOIN project AS drone_run_project ON (drone_run_band_rel.object_project_id = drone_run_project.project_id)
            JOIN projectprop AS drone_run_date ON(drone_run_project.project_id=drone_run_date.project_id AND drone_run_date.type_id=$project_start_date_type_id)
            JOIN project_relationship AS field_trial_rel ON (drone_run_project.project_id = field_trial_rel.subject_project_id AND field_trial_rel.type_id=$drone_run_field_trial_project_relationship_type_id_cvterm_id)
            JOIN project AS field_trial ON (field_trial_rel.object_project_id = field_trial.project_id)
            WHERE field_trial.project_id = ?;";
        my $drone_run_date_h = $schema->storage->dbh()->prepare($drone_run_date_q);
        $drone_run_date_h->execute($selected_trial_id);
        while( my ($drone_run_date) = $drone_run_date_h->fetchrow_array()) {
            my $drone_run_date_formatted = $drone_run_date ? $calendar_funcs->display_start_date($drone_run_date) : '';
            if ($drone_run_date_formatted) {
                my $date_obj = Time::Piece->strptime($drone_run_date_formatted, "%Y-%B-%d %H:%M:%S");
                my $epoch_seconds = $date_obj->epoch;
                $seen_field_trial_drone_run_dates{$epoch_seconds}++;
            }
        }
        my $drone_run_date_obj = Time::Piece->strptime($new_drone_run_date, "%Y/%m/%d %H:%M:%S");
        if (exists($seen_field_trial_drone_run_dates{$drone_run_date_obj->epoch})) {
            $c->stash->{rest} = { error => "An imaging event has already occured on this field trial at the same date and time! Please give a unique date/time for each imaging event!" };
            $c->detach();
        }

        my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $selected_trial_id });
        my $trial_location_id = $trial->get_location()->[0];
        my $planting_date = $trial->get_planting_date();
        my $planting_date_time_object = Time::Piece->strptime($planting_date, "%Y-%B-%d");
        my $drone_run_date_time_object = Time::Piece->strptime($new_drone_run_date, "%Y/%m/%d %H:%M:%S");
        my $time_diff;
        my $base_date_event;
        if ($new_drone_base_date) {
            my $imaging_event_base_date_time_object = Time::Piece->strptime($new_drone_base_date, "%Y/%m/%d %H:%M:%S");
            $time_diff = $drone_run_date_time_object - $imaging_event_base_date_time_object;
            $base_date_event = $calendar_funcs->check_value_format($new_drone_base_date);
        }
        else {
            $time_diff = $drone_run_date_time_object - $planting_date_time_object;
        }
        my $time_diff_weeks = $time_diff->weeks;
        my $time_diff_days = $time_diff->days;
        my $time_diff_hours = $time_diff->hours;
        my $rounded_time_diff_weeks = round($time_diff_weeks);
        if ($rounded_time_diff_weeks == 0) {
            $rounded_time_diff_weeks = 1;
        }

        my $week_term_string = "week $rounded_time_diff_weeks";
        my $q = "SELECT t.cvterm_id FROM cvterm as t JOIN cv ON(t.cv_id=cv.cv_id) WHERE t.name=? and cv.name=?;";
        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute($week_term_string, 'cxgn_time_ontology');
        my ($week_cvterm_id) = $h->fetchrow_array();

        if (!$week_cvterm_id) {
            my $new_week_term = $schema->resultset("Cv::Cvterm")->create_with({
               name => $week_term_string,
               cv => 'cxgn_time_ontology'
            });
            $week_cvterm_id = $new_week_term->cvterm_id();
        }

        my $day_term_string = "day $time_diff_days";
        $h->execute($day_term_string, 'cxgn_time_ontology');
        my ($day_cvterm_id) = $h->fetchrow_array();

        if (!$day_cvterm_id) {
            my $new_day_term = $schema->resultset("Cv::Cvterm")->create_with({
               name => $day_term_string,
               cv => 'cxgn_time_ontology'
            });
            $day_cvterm_id = $new_day_term->cvterm_id();
        }

        my $week_term = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $week_cvterm_id, 'extended');
        my $day_term = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $day_cvterm_id, 'extended');

        my %related_cvterms = (
            week => $week_term,
            day => $day_term
        );

        my $drone_run_event = $calendar_funcs->check_value_format($new_drone_run_date);
        my $drone_run_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_experiment', 'experiment_type')->cvterm_id();
        my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property')->cvterm_id();
        my $drone_run_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_project_type', 'project_property')->cvterm_id();
        my $drone_run_is_raw_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_is_raw_images', 'project_property')->cvterm_id();
        my $drone_run_camera_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_camera_type', 'project_property')->cvterm_id();
        my $drone_run_base_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_base_date', 'project_property')->cvterm_id();
        my $drone_run_rig_desc_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_camera_rig_description', 'project_property')->cvterm_id();
        my $drone_run_related_cvterms_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_related_time_cvterms_json', 'project_property')->cvterm_id();
        my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
        my $imaging_vehicle_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'imaging_event_vehicle', 'stock_type')->cvterm_id();
        my $imaging_vehicle_properties_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'imaging_event_vehicle_json', 'stock_property')->cvterm_id();

        my $drone_run_projectprops = [
            {type_id => $drone_run_type_cvterm_id, value => $new_drone_run_type},
            {type_id => $project_start_date_type_id, value => $drone_run_event},
            {type_id => $design_cvterm_id, value => 'drone_run'},
            {type_id => $drone_run_camera_type_cvterm_id, value => $new_drone_run_camera_info},
            {type_id => $drone_run_related_cvterms_cvterm_id, value => encode_json \%related_cvterms}
        ];

        if ($new_drone_run_band_stitching ne 'no') {
            push @$drone_run_projectprops, {type_id => $drone_run_is_raw_cvterm_id, value => 1};
        }
        if ($new_drone_base_date) {
            push @$drone_run_projectprops, {type_id => $drone_run_base_date_type_id, value => $base_date_event};
        }
        if ($new_drone_rig_desc) {
            push @$drone_run_projectprops, {type_id => $drone_run_rig_desc_type_id, value => $new_drone_rig_desc};
        }

        my $nd_experiment_rs = $schema->resultset("NaturalDiversity::NdExperiment")->create({
            nd_geolocation_id => $trial_location_id,
            type_id => $drone_run_experiment_type_id,
            nd_experiment_stocks => [{stock_id => $new_drone_run_vehicle_id, type_id => $drone_run_experiment_type_id}]
        });
        $drone_run_nd_experiment_id = $nd_experiment_rs->nd_experiment_id();

        my $project_rs = $schema->resultset("Project::Project")->create({
            name => $new_drone_run_name,
            description => $new_drone_run_desc,
            projectprops => $drone_run_projectprops,
            project_relationship_subject_projects => [{type_id => $project_relationship_type_id, object_project_id => $selected_trial_id}],
            nd_experiment_projects => [{nd_experiment_id => $drone_run_nd_experiment_id}]
        });
        $selected_drone_run_id = $project_rs->project_id();

        my $vehicle_prop = decode_json $schema->resultset("Stock::Stockprop")->search({stock_id => $new_drone_run_vehicle_id, type_id=>$imaging_vehicle_properties_cvterm_id})->first()->value();
        $vehicle_prop->{batteries}->{$new_drone_run_battery_name}->{usage}++;
        my $vehicle_prop_update = $schema->resultset('Stock::Stockprop')->update_or_create({
            type_id=>$imaging_vehicle_properties_cvterm_id,
            stock_id=>$new_drone_run_vehicle_id,
            rank=>0,
            value=>encode_json $vehicle_prop
        },
        {
            key=>'stockprop_c1'
        });
    }

    my $drone_run_band_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property')->cvterm_id();
    my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();

    my @return_drone_run_band_project_ids;
    my @return_drone_run_band_image_ids;
    my @return_drone_run_band_image_urls;
    my @raw_image_boundaries_temp_images;
    my %saved_image_stacks;
    my $output_path;
    my $alignment_output_path;
    my $cmd;

    my $image_types_allowed = CXGN::DroneImagery::ImageTypes::get_all_drone_run_band_image_types()->{hash_ref};
    my %seen_image_types_upload;

    if ($new_drone_run_band_stitching eq 'no') {
        my @new_drone_run_bands;
        if ($new_drone_run_band_numbers eq 'one_bw' || $new_drone_run_band_numbers eq 'one_rgb') {
            my $new_drone_run_band_name = $c->req->param('drone_run_band_name_1');
            my $new_drone_run_band_desc = $c->req->param('drone_run_band_description_1');
            my $new_drone_run_band_type = $c->req->param('drone_run_band_type_1');
            if (!$new_drone_run_band_name) {
                $c->stash->{rest} = { error => "Please give a new imaging event band name!" };
                $c->detach();
            }
            if (!$new_drone_run_band_desc){
                $c->stash->{rest} = { error => "Please give a new imaging event band description!" };
                $c->detach();
            }
            if (!$new_drone_run_band_type){
                $c->stash->{rest} = { error => "Please give a new imaging event band type!" };
                $c->detach();
            }
            if (!exists($image_types_allowed->{$new_drone_run_band_type})) {
                $c->stash->{rest} = { error => "Imaging event band type not supported: $new_drone_run_band_type!" };
                $c->detach();
            }
            if (exists($seen_image_types_upload{$new_drone_run_band_type})) {
                $c->stash->{rest} = { error => "Imaging event band type is repeated: $new_drone_run_band_type! Each imaging event band in an imaging event should have a unique type!" };
                $c->detach();
            }
            $seen_image_types_upload{$new_drone_run_band_type}++;

            my $upload_file = $c->req->upload('drone_run_band_stitched_ortho_image_1');
            if (!$upload_file) {
                $c->stash->{rest} = { error => "Please provide a zipfile OR a stitched ortho image!" };
                $c->detach();
            }

            push @new_drone_run_bands, {
                name => $new_drone_run_band_name,
                description => $new_drone_run_band_desc,
                type => $new_drone_run_band_type,
                upload_file => $upload_file
            };
        } else {
            foreach (0..$new_drone_run_band_numbers-1) {
                my $new_drone_run_band_name = $c->req->param('drone_run_band_name_'.$_);
                my $new_drone_run_band_desc = $c->req->param('drone_run_band_description_'.$_);
                my $new_drone_run_band_type = $c->req->param('drone_run_band_type_'.$_);
                if (!$new_drone_run_band_name) {
                    $c->stash->{rest} = { error => "Please give a new imaging event band name!".$_ };
                    $c->detach();
                }
                if (!$new_drone_run_band_desc){
                    $c->stash->{rest} = { error => "Please give a new imaging event band description!" };
                    $c->detach();
                }
                if (!$new_drone_run_band_type){
                    $c->stash->{rest} = { error => "Please give a new imaging event band type!" };
                    $c->detach();
                }
                if (!exists($image_types_allowed->{$new_drone_run_band_type})) {
                    $c->stash->{rest} = { error => "Imaging event band type not supported: $new_drone_run_band_type!" };
                    $c->detach();
                }
                if (exists($seen_image_types_upload{$new_drone_run_band_type})) {
                    $c->stash->{rest} = { error => "Imaging event band type is repeated: $new_drone_run_band_type! Each imaging event band in an imaging event should have a unique type!" };
                    $c->detach();
                }
                $seen_image_types_upload{$new_drone_run_band_type}++;

                my $upload_file = $c->req->upload('drone_run_band_stitched_ortho_image_'.$_);
                if (!$upload_file) {
                    $c->stash->{rest} = { error => "Please provide a zipfile OR a stitched ortho image!" };
                    $c->detach();
                }

                push @new_drone_run_bands, {
                    name => $new_drone_run_band_name,
                    description => $new_drone_run_band_desc,
                    type => $new_drone_run_band_type,
                    upload_file => $upload_file
                };
            }
        }
        foreach (@new_drone_run_bands) {
            my $project_rs = $schema->resultset("Project::Project")->create({
                name => $_->{name},
                description => $_->{description},
                projectprops => [{type_id => $drone_run_band_type_cvterm_id, value => $_->{type}}, {type_id => $design_cvterm_id, value => 'drone_run_band'}],
                project_relationship_subject_projects => [{type_id => $project_relationship_type_id, object_project_id => $selected_drone_run_id}]
            });
            my $selected_drone_run_band_id = $project_rs->project_id();

            my $upload_file = $_->{upload_file};
            my $upload_original_name = $upload_file->filename();
            my $upload_tempfile = $upload_file->tempname;
            my $time = DateTime->now();
            my $timestamp = $time->ymd()."_".$time->hms();

            my $uploader = CXGN::UploadFile->new({
                tempfile => $upload_tempfile,
                subdirectory => "drone_imagery_upload",
                archive_path => $c->config->{archive_path},
                archive_filename => $upload_original_name,
                timestamp => $timestamp,
                user_id => $user_id,
                user_role => $user_role
            });
            my $archived_filename_with_path = $uploader->archive();
            my $md5 = $uploader->get_md5($archived_filename_with_path);
            if (!$archived_filename_with_path) {
                $c->stash->{rest} = { error => "Could not save file $upload_original_name in archive." };
                $c->detach();
            }
            unlink $upload_tempfile;
            print STDERR "Archived Drone Image File: $archived_filename_with_path\n";

            my ($check_image_width, $check_image_height) = imgsize($archived_filename_with_path);
            if ($check_image_width > 16384) {
                my $cmd_resize = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/Resize.py --image_path \''.$archived_filename_with_path.'\' --outfile_path \''.$archived_filename_with_path.'\' --width 16384';
                print STDERR Dumper $cmd_resize;
                my $status_resize = system($cmd_resize);
            }
            elsif ($check_image_height > 16384) {
                my $cmd_resize = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/Resize.py --image_path \''.$archived_filename_with_path.'\' --outfile_path \''.$archived_filename_with_path.'\' --height 16384';
                print STDERR Dumper $cmd_resize;
                my $status_resize = system($cmd_resize);
            }

            my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
            $image->set_sp_person_id($user_id);
            my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
            my $ret = $image->process_image($archived_filename_with_path, 'project', $selected_drone_run_band_id, $linking_table_type_id);
            push @return_drone_run_band_image_urls, $image->get_image_url('original');
            push @return_drone_run_band_image_ids, $image->get_image_id();
            push @return_drone_run_band_project_ids, $selected_drone_run_band_id;
        }
    }
    elsif ($new_drone_run_band_stitching eq 'yes') {
        my $upload_file = $c->req->upload('upload_drone_images_zipfile');
        my $upload_panel_file = $c->req->upload('upload_drone_images_panel_zipfile');
        my $stitching_work_pix = $c->req->param('upload_drone_images_stitching_work_pix');

        if (!$upload_file) {
            $c->stash->{rest} = { error => "Please provide a drone image zipfile of raw images to stitch!" };
            $c->detach();
        }
        if (!$upload_panel_file && $new_drone_run_camera_info eq 'micasense_5') {
            $c->stash->{rest} = { error => "Please provide a zipfile of images of the Micasense radiometric calibration panels!" };
            $c->detach();
        }

        my $upload_original_name = $upload_file->filename();
        my $upload_tempfile = $upload_file->tempname;
        my $time = DateTime->now();
        my $timestamp = $time->ymd()."_".$time->hms();

        my $uploader = CXGN::UploadFile->new({
            tempfile => $upload_tempfile,
            subdirectory => "drone_imagery_upload",
            archive_path => $c->config->{archive_path},
            archive_filename => $upload_original_name,
            timestamp => $timestamp,
            user_id => $user_id,
            user_role => $user_role
        });
        my $archived_filename_with_path = $uploader->archive();
        my $md5 = $uploader->get_md5($archived_filename_with_path);
        if (!$archived_filename_with_path) {
            $c->stash->{rest} = { error => "Could not save file $upload_original_name in archive." };
            $c->detach();
        }
        unlink $upload_tempfile;
        print STDERR "Archived Drone Image File: $archived_filename_with_path\n";

        my $image = SGN::Image->new( $c->dbc->dbh, undef, $c );
        my $zipfile_return = $image->upload_drone_imagery_zipfile($archived_filename_with_path, $user_id, $selected_drone_run_id);
        print STDERR Dumper $zipfile_return;
        if ($zipfile_return->{error}) {
            $c->stash->{rest} = { error => "Problem saving images!".$zipfile_return->{error} };
            $c->detach();
        }
        my $image_paths = $zipfile_return->{image_files};

        my $dir = $c->tempfiles_subdir('/upload_drone_imagery_raw_to_stitch');
        my $temp_file_image_file_names = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_raw_to_stitch/fileXXXX');
        open (my $fh, ">", $temp_file_image_file_names ) || die ("\nERROR: the file $temp_file_image_file_names could not be found\n" );
            foreach (@$image_paths) {
                my $dir = $c->tempfiles_subdir('/upload_drone_imagery_temp_raw');
                my $temp_file_raw_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_temp_raw/fileXXXX').".png";
                print $fh "$_,$temp_file_raw_image\n";
            }
        close($fh);
        print STDERR "Drone image stitch temp file $temp_file_image_file_names\n";

        $dir = $c->tempfiles_subdir('/upload_drone_imagery_stitched_result');
        my $temp_file_stitched_result_band1 = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_stitched_result/fileXXXX').".png";
        my $temp_file_stitched_result_band2 = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_stitched_result/fileXXXX').".png";
        my $temp_file_stitched_result_band3 = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_stitched_result/fileXXXX').".png";
        my $temp_file_stitched_result_band4 = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_stitched_result/fileXXXX').".png";
        my $temp_file_stitched_result_band5 = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_stitched_result/fileXXXX').".png";
        my $temp_file_stitched_result_rgb = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_stitched_result/fileXXXX').".png";
        my $temp_file_stitched_result_rnre = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_stitched_result/fileXXXX').".png";

        my @stitched_bands;
        if ($new_drone_run_camera_info eq 'micasense_5') {
            my $upload_original_name_panel = $upload_panel_file->filename();
            my $upload_tempfile_panel = $upload_panel_file->tempname;
            $time = DateTime->now();
            $timestamp = $time->ymd()."_".$time->hms();

            my $uploader_panel = CXGN::UploadFile->new({
                tempfile => $upload_tempfile_panel,
                subdirectory => "drone_imagery_upload_panel",
                archive_path => $c->config->{archive_path},
                archive_filename => $upload_original_name_panel,
                timestamp => $timestamp,
                user_id => $user_id,
                user_role => $user_role
            });
            my $archived_filename_with_path_panel = $uploader_panel->archive();
            my $md5_panel = $uploader->get_md5($archived_filename_with_path_panel);
            if (!$archived_filename_with_path_panel) {
                $c->stash->{rest} = { error => "Could not save file $upload_original_name_panel in archive." };
                $c->detach();
            }
            unlink $upload_tempfile_panel;
            print STDERR "Archived Drone Image Panel File: $archived_filename_with_path_panel\n";

            $image = SGN::Image->new( $c->dbc->dbh, undef, $c );
            my $zipfile_return_panel = $image->upload_drone_imagery_zipfile($archived_filename_with_path_panel, $user_id, $selected_drone_run_id);
            print STDERR Dumper $zipfile_return_panel;
            if ($zipfile_return_panel->{error}) {
                $c->stash->{rest} = { error => "Problem saving panel images!".$zipfile_return_panel->{error} };
                $c->detach();
            }
            my $image_paths_panel = $zipfile_return_panel->{image_files};

            my $temp_file_image_file_names_panel = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_raw_to_stitch/fileXXXX');
            open ($fh, ">", $temp_file_image_file_names_panel ) || die ("\nERROR: the file $temp_file_image_file_names_panel could not be found\n" );
                foreach (@$image_paths_panel) {
                    print $fh "$_\n";
                }
            close($fh);
            print STDERR "Drone image stitch temp file panel $temp_file_image_file_names_panel\n";

            # $cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/AlignImagesMicasense.py --log_file_path '".$c->config->{error_log}."' --file_with_image_paths '$temp_file_image_file_names' --file_with_panel_image_paths '$temp_file_image_file_names_panel' --output_path '$dir' --output_path_band1 '$temp_file_stitched_result_band1' --output_path_band2 '$temp_file_stitched_result_band2' --output_path_band3 '$temp_file_stitched_result_band3' --output_path_band4 '$temp_file_stitched_result_band4' --output_path_band5 '$temp_file_stitched_result_band5' --final_rgb_output_path '$temp_file_stitched_result_rgb' --final_rnre_output_path '$temp_file_stitched_result_rnre' --work_megapix $stitching_work_pix";

            $cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/AlignImagesMicasense.py $log_file_path --file_with_image_paths '$temp_file_image_file_names' --file_with_panel_image_paths '$temp_file_image_file_names_panel' --output_path '$dir' --output_path_band1 '$temp_file_stitched_result_band1' --output_path_band2 '$temp_file_stitched_result_band2' --output_path_band3 '$temp_file_stitched_result_band3' --output_path_band4 '$temp_file_stitched_result_band4' --output_path_band5 '$temp_file_stitched_result_band5' --final_rgb_output_path '$temp_file_stitched_result_rgb' --final_rnre_output_path '$temp_file_stitched_result_rnre'";

            @stitched_bands = (
                ["Band 1", "Blue", "Blue (450-520nm)", $temp_file_stitched_result_band1],
                ["Band 2", "Green", "Green (515-600nm)", $temp_file_stitched_result_band2],
                ["Band 3", "Red", "Red (600-690nm)", $temp_file_stitched_result_band3],
                ["Band 4", "NIR", "NIR (780-3000nm)", $temp_file_stitched_result_band4],
                ["Band 5", "RedEdge", "Red Edge (690-750nm)", $temp_file_stitched_result_band5]
            );
        }
        elsif ($new_drone_run_camera_info eq 'ccd_color' || $new_drone_run_camera_info eq 'cmos_color') {
            $cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/AlignImagesRGB.py $log_file_path --file_with_image_paths '$temp_file_image_file_names' --output_path '$dir' --final_rgb_output_path '$temp_file_stitched_result_rgb'";

            @stitched_bands = (
                ["Color Image", "RGB Color Image", "RGB Color Image", $temp_file_stitched_result_rgb],
            );
        }
        else {
            die "Camera info not supported for stitching: $new_drone_run_camera_info\n";
        }
        print STDERR Dumper $cmd;
        my $status = system($cmd);

        foreach my $m (@stitched_bands) {
            my $project_rs = $schema->resultset("Project::Project")->create({
                name => $new_drone_run_name."_".$m->[1],
                description => $new_drone_run_desc.". ".$m->[0]." ".$m->[1].". Orthomosaic stitched by ImageBreed.",
                projectprops => [{type_id => $drone_run_band_type_cvterm_id, value => $m->[2]}, {type_id => $design_cvterm_id, value => 'drone_run_band'}],
                project_relationship_subject_projects => [{type_id => $project_relationship_type_id, object_project_id => $selected_drone_run_id}]
            });
            my $selected_drone_run_band_id = $project_rs->project_id();

            my $time = DateTime->now();
            my $timestamp = $time->ymd()."_".$time->hms();
            my $upload_original_name = $new_drone_run_name."_ImageBreed_stitched_".$m->[1].".png";

            my $uploader = CXGN::UploadFile->new({
                tempfile => $m->[3],
                subdirectory => "drone_imagery_upload",
                archive_path => $c->config->{archive_path},
                archive_filename => $upload_original_name,
                timestamp => $timestamp,
                user_id => $user_id,
                user_role => $user_role
            });
            my $archived_filename_with_path = $uploader->archive();
            my $md5 = $uploader->get_md5($archived_filename_with_path);
            if (!$archived_filename_with_path) {
                $c->stash->{rest} = { error => "Could not save file $upload_original_name in archive." };
                $c->detach();
            }
            unlink $upload_tempfile;
            print STDERR "Archived Drone Image File: $archived_filename_with_path\n";

            my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
            $image->set_sp_person_id($user_id);
            my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
            my $ret = $image->process_image($archived_filename_with_path, 'project', $selected_drone_run_band_id, $linking_table_type_id);
            push @return_drone_run_band_image_urls, $image->get_image_url('original');
            push @return_drone_run_band_image_ids, $image->get_image_id();
            push @return_drone_run_band_project_ids, $selected_drone_run_band_id;
        }
    } elsif ($new_drone_run_band_stitching eq 'yes_automated') {
        print STDERR Dumper $c->req->params();
        my $upload_file = $c->req->upload('upload_drone_images_zipfile');
        my $upload_panel_file = $c->req->upload('upload_drone_images_panel_zipfile');
        my $drone_run_raw_image_boundaries_first_plot_corner = $c->req->param('drone_run_raw_image_boundaries_first_plot_corner');
        my $drone_run_raw_image_boundaries_second_plot_direction = $c->req->param('drone_run_raw_image_boundaries_second_plot_direction');
        my $drone_run_raw_image_boundaries_plot_orientation = $c->req->param('drone_run_raw_image_boundaries_plot_orientation');
        my $drone_run_raw_image_boundaries_corners_json = $c->req->param('drone_run_raw_image_boundaries_corners_json');
        my $drone_run_raw_image_boundaries_corners_gps_json = $c->req->param('drone_run_raw_image_boundaries_corners_gps_json');
        my $drone_run_raw_image_boundaries_rotate_angle = $c->req->param('drone_run_raw_image_boundaries_rotate_angle');
        my $drone_run_raw_image_boundaries_row_num = $c->req->param('drone_run_raw_image_boundaries_row_num');
        my $drone_run_raw_image_boundaries_col_num = $c->req->param('drone_run_raw_image_boundaries_col_num');
        my $drone_run_raw_image_boundaries_flight_direction = $c->req->param('drone_run_raw_image_boundaries_flight_direction');
        my $drone_run_raw_image_boundaries_plot_width = $c->req->param('drone_run_raw_image_boundaries_plot_width');
        my $drone_run_raw_image_boundaries_plot_length = $c->req->param('drone_run_raw_image_boundaries_plot_length');
        my $drone_run_raw_image_boundaries_corners_plots_json = $c->req->param('drone_run_raw_image_boundaries_corners_plots_json');
        my $drone_run_raw_image_boundaries_latitude_precision = $c->req->param('drone_run_raw_image_boundaries_latitude_precision');
        my $drone_run_raw_image_boundaries_start_direction = $c->req->param('drone_run_raw_image_boundaries_start_direction');
        my $drone_run_raw_image_boundaries_turn_direction = $c->req->param('drone_run_raw_image_boundaries_turn_direction');
        my $drone_run_raw_image_boundaries_geographic_position = $c->req->param('drone_run_raw_image_boundaries_geographic_position');
        my $drone_run_raw_image_boundaries_image_top_direction = $c->req->param('drone_run_raw_image_boundaries_image_top_direction');
        my $drone_run_raw_image_boundaries_row_alley_width = $c->req->param('drone_run_raw_image_boundaries_row_alley_width');
        my $drone_run_raw_image_boundaries_column_alley_width = $c->req->param('drone_run_raw_image_boundaries_column_alley_width');

        if (!$upload_file) {
            $c->stash->{rest} = { error => "Please provide a drone image zipfile of raw images to stitch!" };
            $c->detach();
        }
        if (!$upload_panel_file && $new_drone_run_camera_info eq 'micasense_5') {
            $c->stash->{rest} = { error => "Please provide a zipfile of images of the Micasense radiometric calibration panels!" };
            $c->detach();
        }

        my $upload_original_name = $upload_file->filename();
        my $upload_tempfile = $upload_file->tempname;
        my $time = DateTime->now();
        my $timestamp = $time->ymd()."_".$time->hms();

        my $uploader = CXGN::UploadFile->new({
            tempfile => $upload_tempfile,
            subdirectory => "drone_imagery_upload",
            archive_path => $c->config->{archive_path},
            archive_filename => $upload_original_name,
            timestamp => $timestamp,
            user_id => $user_id,
            user_role => $user_role
        });
        my $archived_filename_with_path = $uploader->archive();
        my $md5 = $uploader->get_md5($archived_filename_with_path);
        if (!$archived_filename_with_path) {
            $c->stash->{rest} = { error => "Could not save file $upload_original_name in archive." };
            $c->detach();
        }
        unlink $upload_tempfile;
        print STDERR "Archived Drone Image File: $archived_filename_with_path\n";

        my $image = SGN::Image->new( $c->dbc->dbh, undef, $c );
        my $zipfile_return = $image->upload_drone_imagery_zipfile($archived_filename_with_path, $user_id, $selected_drone_run_id);
        print STDERR Dumper $zipfile_return;
        if ($zipfile_return->{error}) {
            $c->stash->{rest} = { error => "Problem saving images!".$zipfile_return->{error} };
            $c->detach();
        }
        my $image_paths = $zipfile_return->{image_files};

        my $dir = $c->tempfiles_subdir('/upload_drone_imagery_raw_boundaries');
        my $base_path = $c->config->{basepath}."/";
        my $temp_file_image_file_names = $base_path.$c->tempfile( TEMPLATE => 'upload_drone_imagery_raw_boundaries/fileXXXX');
        open (my $fh, ">", $temp_file_image_file_names ) || die ("\nERROR: the file $temp_file_image_file_names could not be found\n" );
            foreach (@$image_paths) {
                my $temp_file_raw_image_blue = $c->tempfile( TEMPLATE => 'upload_drone_imagery_raw_boundaries/fileXXXX').".png";
                my $temp_file_raw_image_green = $c->tempfile( TEMPLATE => 'upload_drone_imagery_raw_boundaries/fileXXXX').".png";
                my $temp_file_raw_image_red = $c->tempfile( TEMPLATE => 'upload_drone_imagery_raw_boundaries/fileXXXX').".png";
                my $temp_file_raw_image_nir = $c->tempfile( TEMPLATE => 'upload_drone_imagery_raw_boundaries/fileXXXX').".png";
                my $temp_file_raw_image_red_edge = $c->tempfile( TEMPLATE => 'upload_drone_imagery_raw_boundaries/fileXXXX').".png";
                print $fh "$_,$base_path,$temp_file_raw_image_blue,$temp_file_raw_image_green,$temp_file_raw_image_red,$temp_file_raw_image_nir,$temp_file_raw_image_red_edge\n";
            }
        close($fh);
        print STDERR "Drone image raw boundaries temp file $temp_file_image_file_names\n";

        my @stitched_bands;
        if ($new_drone_run_camera_info eq 'micasense_5') {
            my $upload_original_name_panel = $upload_panel_file->filename();
            my $upload_tempfile_panel = $upload_panel_file->tempname;
            $time = DateTime->now();
            $timestamp = $time->ymd()."_".$time->hms();

            my $uploader_panel = CXGN::UploadFile->new({
                tempfile => $upload_tempfile_panel,
                subdirectory => "drone_imagery_upload_panel",
                archive_path => $c->config->{archive_path},
                archive_filename => $upload_original_name_panel,
                timestamp => $timestamp,
                user_id => $user_id,
                user_role => $user_role
            });
            my $archived_filename_with_path_panel = $uploader_panel->archive();
            my $md5_panel = $uploader->get_md5($archived_filename_with_path_panel);
            if (!$archived_filename_with_path_panel) {
                $c->stash->{rest} = { error => "Could not save file $upload_original_name_panel in archive." };
                $c->detach();
            }
            unlink $upload_tempfile_panel;
            print STDERR "Archived Drone Image Panel File: $archived_filename_with_path_panel\n";

            $image = SGN::Image->new( $c->dbc->dbh, undef, $c );
            my $zipfile_return_panel = $image->upload_drone_imagery_zipfile($archived_filename_with_path_panel, $user_id, $selected_drone_run_id);
            print STDERR Dumper $zipfile_return_panel;
            if ($zipfile_return_panel->{error}) {
                $c->stash->{rest} = { error => "Problem saving panel images!".$zipfile_return_panel->{error} };
                $c->detach();
            }
            my $image_paths_panel = $zipfile_return_panel->{image_files};

            my $temp_file_image_file_names_panel = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_raw_boundaries/fileXXXX');
            open ($fh, ">", $temp_file_image_file_names_panel ) || die ("\nERROR: the file $temp_file_image_file_names_panel could not be found\n" );
                foreach (@$image_paths_panel) {
                    print $fh "$_\n";
                }
            close($fh);
            print STDERR "Drone image stitch temp file panel $temp_file_image_file_names_panel\n";

            my $trial_layout = CXGN::Trial::TrialLayout->new( { schema => $schema, trial_id => $selected_trial_id, experiment_type=>'field_layout' });
            my $trial_design = $trial_layout->get_design();

            my $field_layout_path = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_raw_boundaries/fileXXXX');
            open ($fh, ">", $field_layout_path ) || die ("\nERROR: the file $field_layout_path could not be found\n" );
                foreach (sort { $a <=> $b } keys %$trial_design) {
                    my $v = $trial_design->{$_};
                    print $fh $v->{plot_id}.",".$v->{plot_name}.",".$v->{plot_number}."\n";
                }
            close($fh);

            my $field_layout_params_path = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_raw_boundaries/fileXXXX');
            open ($fh, ">", $field_layout_params_path ) || die ("\nERROR: the file $field_layout_params_path could not be found\n" );
                print $fh "$drone_run_raw_image_boundaries_first_plot_corner\n";
                print $fh "$drone_run_raw_image_boundaries_second_plot_direction\n";
                print $fh "$drone_run_raw_image_boundaries_plot_orientation\n";
                print $fh "$drone_run_raw_image_boundaries_corners_json\n";
                print $fh "$drone_run_raw_image_boundaries_corners_gps_json\n";
                print $fh "$drone_run_raw_image_boundaries_rotate_angle\n";
                print $fh "$drone_run_raw_image_boundaries_row_num\n";
                print $fh "$drone_run_raw_image_boundaries_col_num\n";
                print $fh "$drone_run_raw_image_boundaries_flight_direction\n";
                print $fh "$drone_run_raw_image_boundaries_plot_width\n";
                print $fh "$drone_run_raw_image_boundaries_plot_length\n";
                print $fh "$drone_run_raw_image_boundaries_corners_plots_json\n";
                print $fh "$drone_run_raw_image_boundaries_latitude_precision\n";
                print $fh "$drone_run_raw_image_boundaries_start_direction\n";
                print $fh "$drone_run_raw_image_boundaries_turn_direction\n";
                print $fh "$drone_run_raw_image_boundaries_geographic_position\n";
                print $fh "$drone_run_raw_image_boundaries_image_top_direction\n";
                print $fh "$drone_run_raw_image_boundaries_row_alley_width\n";
                print $fh "$drone_run_raw_image_boundaries_column_alley_width\n";
            close($fh);

            $output_path = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_raw_boundaries/fileXXXX');

            # $cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/MicasenseRawImagePlotBoundaries.py $log_file_path --file_with_image_paths '$temp_file_image_file_names' --file_with_panel_image_paths '$temp_file_image_file_names_panel' --output_path '$output_path' --field_layout_path '$field_layout_path' --field_layout_params '$field_layout_params_path' --temporary_development_path '/home/nmorales/Downloads'";
            $cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/MicasenseRawImagePlotBoundaries.py $log_file_path --file_with_image_paths '$temp_file_image_file_names' --file_with_panel_image_paths '$temp_file_image_file_names_panel' --output_path '$output_path' --field_layout_path '$field_layout_path' --field_layout_params '$field_layout_params_path'";

            # @stitched_bands = (
            #     ["Band 1", "Blue", "Blue (450-520nm)", $temp_file_stitched_result_band1],
            #     ["Band 2", "Green", "Green (515-600nm)", $temp_file_stitched_result_band2],
            #     ["Band 3", "Red", "Red (600-690nm)", $temp_file_stitched_result_band3],
            #     ["Band 4", "NIR", "NIR (780-3000nm)", $temp_file_stitched_result_band4],
            #     ["Band 5", "RedEdge", "Red Edge (690-750nm)", $temp_file_stitched_result_band5]
            # );
        }
        elsif ($new_drone_run_camera_info eq 'ccd_color' || $new_drone_run_camera_info eq 'cmos_color') {
            # $cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/AlignImagesRGB.py $log_file_path --file_with_image_paths '$temp_file_image_file_names' --output_path '$dir' --final_rgb_output_path '$temp_file_stitched_result_rgb'";
            #
            # @stitched_bands = (
            #     ["Color Image", "RGB Color Image", "RGB Color Image", $temp_file_stitched_result_rgb],
            # );
        }
        else {
            die "Camera info not supported for stitching: $new_drone_run_camera_info\n";
        }
        print STDERR Dumper $cmd;
        my $status = system($cmd);

        my $csv = Text::CSV->new({ sep_char => ',' });
        open(my $fh_out, '<', $output_path) or die "Could not open file '$output_path' $!";
            while ( my $row = <$fh_out> ){
                my @columns;
                if ($csv->parse($row)) {
                    @columns = $csv->fields();
                }
                push @raw_image_boundaries_temp_images, \@columns;
            }
        close($fh);
        print STDERR Dumper \@raw_image_boundaries_temp_images;

        foreach my $m (@stitched_bands) {
            my $project_rs = $schema->resultset("Project::Project")->create({
                name => $new_drone_run_name."_".$m->[1],
                description => $new_drone_run_desc.". ".$m->[0]." ".$m->[1].". Orthomosaic stitched by ImageBreed.",
                projectprops => [{type_id => $drone_run_band_type_cvterm_id, value => $m->[2]}, {type_id => $design_cvterm_id, value => 'drone_run_band'}],
                project_relationship_subject_projects => [{type_id => $project_relationship_type_id, object_project_id => $selected_drone_run_id}]
            });
            my $selected_drone_run_band_id = $project_rs->project_id();

            my $time = DateTime->now();
            my $timestamp = $time->ymd()."_".$time->hms();
            my $upload_original_name = $new_drone_run_name."_ImageBreed_stitched_".$m->[1].".png";

            my $uploader = CXGN::UploadFile->new({
                tempfile => $m->[3],
                subdirectory => "drone_imagery_upload",
                archive_path => $c->config->{archive_path},
                archive_filename => $upload_original_name,
                timestamp => $timestamp,
                user_id => $user_id,
                user_role => $user_role
            });
            my $archived_filename_with_path = $uploader->archive();
            my $md5 = $uploader->get_md5($archived_filename_with_path);
            if (!$archived_filename_with_path) {
                $c->stash->{rest} = { error => "Could not save file $upload_original_name in archive." };
                $c->detach();
            }
            unlink $upload_tempfile;
            print STDERR "Archived Drone Image File: $archived_filename_with_path\n";

            my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
            $image->set_sp_person_id($user_id);
            my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
            my $ret = $image->process_image($archived_filename_with_path, 'project', $selected_drone_run_band_id, $linking_table_type_id);
            push @return_drone_run_band_image_urls, $image->get_image_url('original');
            push @return_drone_run_band_image_ids, $image->get_image_id();
            push @return_drone_run_band_project_ids, $selected_drone_run_band_id;
        }
    }
    elsif ($new_drone_run_band_stitching eq 'yes_raw') {
        my $upload_file = $c->req->upload('upload_drone_images_zipfile');
        my $upload_panel_file = $c->req->upload('upload_drone_images_panel_zipfile');

        if (!$upload_file) {
            $c->stash->{rest} = { error => "Please provide a drone image zipfile of raw images!" };
            $c->detach();
        }
        if (!$upload_panel_file && $new_drone_run_camera_info eq 'micasense_5') {
            $c->stash->{rest} = { error => "Please provide a zipfile of images of the Micasense radiometric calibration panels!" };
            $c->detach();
        }

        my $upload_original_name = $upload_file->filename();
        my $upload_tempfile = $upload_file->tempname;
        my $time = DateTime->now();
        my $timestamp = $time->ymd()."_".$time->hms();

        my $uploader = CXGN::UploadFile->new({
            tempfile => $upload_tempfile,
            subdirectory => "drone_imagery_upload",
            archive_path => $c->config->{archive_path},
            archive_filename => $upload_original_name,
            timestamp => $timestamp,
            user_id => $user_id,
            user_role => $user_role
        });
        my $archived_filename_with_path = $uploader->archive();
        my $md5 = $uploader->get_md5($archived_filename_with_path);
        if (!$archived_filename_with_path) {
            $c->stash->{rest} = { error => "Could not save file $upload_original_name in archive." };
            $c->detach();
        }
        unlink $upload_tempfile;
        print STDERR "Archived Drone Image File: $archived_filename_with_path\n";

        my $image = SGN::Image->new( $c->dbc->dbh, undef, $c );
        my $zipfile_return = $image->upload_drone_imagery_zipfile($archived_filename_with_path, $user_id, $selected_drone_run_id);
        print STDERR Dumper $zipfile_return;
        if ($zipfile_return->{error}) {
            $c->stash->{rest} = { error => "Problem saving images!".$zipfile_return->{error} };
            $c->detach();
        }
        my $image_paths = $zipfile_return->{image_files};
        # print STDERR Dumper $image_paths;

        my $dir = $c->tempfiles_subdir('/upload_drone_imagery_raw_images');
        my $base_path = $c->config->{basepath}."/";
        my $temp_file_image_file_names = $base_path.$c->tempfile( TEMPLATE => 'upload_drone_imagery_raw_images/fileXXXX');
        open (my $fh, ">", $temp_file_image_file_names ) || die ("\nERROR: the file $temp_file_image_file_names could not be found\n" );
            foreach (@$image_paths) {
                my $temp_file_raw_image_blue = $c->tempfile( TEMPLATE => 'upload_drone_imagery_raw_images/fileXXXX').".png";
                my $temp_file_raw_image_green = $c->tempfile( TEMPLATE => 'upload_drone_imagery_raw_images/fileXXXX').".png";
                my $temp_file_raw_image_red = $c->tempfile( TEMPLATE => 'upload_drone_imagery_raw_images/fileXXXX').".png";
                my $temp_file_raw_image_nir = $c->tempfile( TEMPLATE => 'upload_drone_imagery_raw_images/fileXXXX').".png";
                my $temp_file_raw_image_red_edge = $c->tempfile( TEMPLATE => 'upload_drone_imagery_raw_images/fileXXXX').".png";
                print $fh "$_,$base_path,$temp_file_raw_image_blue,$temp_file_raw_image_green,$temp_file_raw_image_red,$temp_file_raw_image_nir,$temp_file_raw_image_red_edge\n";
            }
        close($fh);
        # print STDERR $temp_file_image_file_names."\n";

        my @stitched_bands;
        my %raw_image_bands;
        if ($new_drone_run_camera_info eq 'micasense_5') {
            my $upload_original_name_panel = $upload_panel_file->filename();
            my $upload_tempfile_panel = $upload_panel_file->tempname;
            $time = DateTime->now();
            $timestamp = $time->ymd()."_".$time->hms();

            my $uploader_panel = CXGN::UploadFile->new({
                tempfile => $upload_tempfile_panel,
                subdirectory => "drone_imagery_upload_panel",
                archive_path => $c->config->{archive_path},
                archive_filename => $upload_original_name_panel,
                timestamp => $timestamp,
                user_id => $user_id,
                user_role => $user_role
            });
            my $archived_filename_with_path_panel = $uploader_panel->archive();
            my $md5_panel = $uploader->get_md5($archived_filename_with_path_panel);
            if (!$archived_filename_with_path_panel) {
                $c->stash->{rest} = { error => "Could not save file $upload_original_name_panel in archive." };
                $c->detach();
            }
            unlink $upload_tempfile_panel;
            print STDERR "Archived Drone Image Panel File: $archived_filename_with_path_panel\n";

            $image = SGN::Image->new( $c->dbc->dbh, undef, $c );
            my $zipfile_return_panel = $image->upload_drone_imagery_zipfile($archived_filename_with_path_panel, $user_id, $selected_drone_run_id);
            print STDERR Dumper $zipfile_return_panel;
            if ($zipfile_return_panel->{error}) {
                $c->stash->{rest} = { error => "Problem saving panel images!".$zipfile_return_panel->{error} };
                $c->detach();
            }
            my $image_paths_panel = $zipfile_return_panel->{image_files};

            my $temp_file_image_file_names_panel = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_raw_images/fileXXXX');
            open ($fh, ">", $temp_file_image_file_names_panel ) || die ("\nERROR: the file $temp_file_image_file_names_panel could not be found\n" );
                foreach (@$image_paths_panel) {
                    print $fh "$_\n";
                }
            close($fh);

            $output_path = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_raw_images/fileXXXX');
            $alignment_output_path = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_raw_images/fileXXXX').".pkl";

            # $cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/MicasenseRawImageAlign.py $log_file_path --file_with_image_paths '$temp_file_image_file_names' --file_with_panel_image_paths '$temp_file_image_file_names_panel' --output_path '$output_path' --temporary_development_path '/home/nmorales/Downloads'";
            $cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/MicasenseRawImageAlign.py $log_file_path --file_with_image_paths '$temp_file_image_file_names' --file_with_panel_image_paths '$temp_file_image_file_names_panel' --output_path '$output_path' --outfile_alignment_file '$alignment_output_path' ";

            @stitched_bands = (
                ["Band 1", "Blue", "Blue (450-520nm)", 0],
                ["Band 2", "Green", "Green (515-600nm)", 1],
                ["Band 3", "Red", "Red (600-690nm)", 2],
                ["Band 4", "NIR", "NIR (780-3000nm)", 3],
                ["Band 5", "RedEdge", "Red Edge (690-750nm)", 4]
            );
        }
        # elsif ($new_drone_run_camera_info eq 'ccd_color' || $new_drone_run_camera_info eq 'cmos_color') {
        #     @stitched_bands = (
        #         ["Color Image", "RGB Color Image", "RGB Color Image", 0],
        #     );
        #     $raw_image_bands{0} = $image_paths;
        # }
        else {
            die "Camera info not supported for raw image upload: $new_drone_run_camera_info\n";
        }

        print STDERR Dumper $cmd;
        my $status = system($cmd);

        my $alignment_output_path_name = basename($alignment_output_path);
        my $alignment_matrices_type = "drone_imagery_upload_alignment_matrices";
        my $uploader_alignment = CXGN::UploadFile->new({
            tempfile => $alignment_output_path,
            subdirectory => $alignment_matrices_type,
            archive_path => $c->config->{archive_path},
            archive_filename => $alignment_output_path_name,
            timestamp => $timestamp,
            user_id => $user_id,
            user_role => $user_role
        });
        my $alignment_archived_filename_with_path = $uploader_alignment->archive();
        my $alignment_md5 = $uploader_alignment->get_md5($archived_filename_with_path);
        if (!$alignment_archived_filename_with_path) {
            return { error => "Could not save file $alignment_output_path_name in archive." };
        }
        print STDERR "Archived Alignment Matrices File: $alignment_archived_filename_with_path\n";

        my $alignment_md_row = $metadata_schema->resultset("MdMetadata")->create({create_person_id => $user_id});
        my $alignment_file_row = $metadata_schema->resultset("MdFiles")->create({
            basename => basename($alignment_archived_filename_with_path),
            dirname => dirname($alignment_archived_filename_with_path),
            filetype => $alignment_matrices_type,
            md5checksum => $alignment_md5->hexdigest(),
            metadata_id => $alignment_md_row->metadata_id()
        });

        my $experiment_files = $phenome_schema->resultset("NdExperimentMdFiles")->create({
            nd_experiment_id => $drone_run_nd_experiment_id,
            file_id => $alignment_file_row->file_id()
        });

        my @aligned_images;
        my $csv = Text::CSV->new({ sep_char => ',' });
        open(my $fh_out, '<', $output_path) or die "Could not open file '$output_path' $!";
            while ( my $row = <$fh_out> ) {
                my @columns;
                if ($csv->parse($row)) {
                    @columns = $csv->fields();
                }
                push @aligned_images, \@columns;
            }
        close($fh_out);

        my $counter = 0;
        my $total_images = scalar(@aligned_images);
        my $total_captures = $total_images/5;
        foreach (@aligned_images) {
            push @{$raw_image_bands{$counter}}, $_;
            $counter++;
            if ($counter >= 5) {
                $counter = 0;
            }
        }

        foreach my $m (@stitched_bands) {
            my $project_rs = $schema->resultset("Project::Project")->create({
                name => $new_drone_run_name."_".$m->[1],
                description => $new_drone_run_desc.". ".$m->[0]." ".$m->[1].". Raw image upload.",
                projectprops => [{type_id => $drone_run_band_type_cvterm_id, value => $m->[2]}, {type_id => $design_cvterm_id, value => 'drone_run_band'}],
                project_relationship_subject_projects => [{type_id => $project_relationship_type_id, object_project_id => $selected_drone_run_id}]
            });
            my $selected_drone_run_band_id = $project_rs->project_id();

            my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'raw_drone_imagery', 'project_md_image')->cvterm_id();
            foreach my $image_info (@{$raw_image_bands{$m->[3]}}) {
                my $im = $image_info->[0];
                my $image_id;
                my $image_url;
                if ($im ne 'NA') {
                    my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
                    $image->set_sp_person_id($user_id);
                    my $ret = $image->process_image($im, 'project', $selected_drone_run_band_id, $linking_table_type_id);
                    $image_id = $image->get_image_id();
                    $image_url = $image->get_image_url('original');
                }
                else {
                    $image_id = undef;
                    $image_url = undef;
                }
                push @return_drone_run_band_image_urls, $image_url;
                push @return_drone_run_band_image_ids, {
                    image_id => $image_id,
                    latitude => $image_info->[1],
                    longitude => $image_info->[2],
                    altitude => $image_info->[3]
                };
            }
            push @return_drone_run_band_project_ids, $selected_drone_run_band_id;
        }

        my $image_stack_counter = 0;
        foreach (@return_drone_run_band_image_ids) {
            push @{$saved_image_stacks{$image_stack_counter}}, $_;
            $image_stack_counter++;
            if ($image_stack_counter >= $total_captures) {
                $image_stack_counter = 0;
            }
        }

        my $saved_image_stacks_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_raw_images_saved_micasense_stacks', 'project_property')->cvterm_id();
        my $image_stack_projectprop_rs = $schema->resultset("Project::Projectprop")->create({
            project_id => $selected_drone_run_id,
            type_id => $saved_image_stacks_type_id,
            value => encode_json \%saved_image_stacks
        });
    }
    elsif ($new_drone_run_band_stitching eq 'yes_open_data_map_stitch') {
        my $upload_file = $c->req->upload('upload_drone_images_zipfile');
        my $upload_panel_file = $c->req->upload('upload_drone_images_panel_zipfile');

        my $upload_original_name = $upload_file->filename();
        my $upload_tempfile = $upload_file->tempname;
        my $time = DateTime->now();
        my $timestamp = $time->ymd()."_".$time->hms();
        print STDERR Dumper [$upload_original_name, $upload_tempfile];

        my $uploader = CXGN::UploadFile->new({
            tempfile => $upload_tempfile,
            subdirectory => "drone_imagery_upload_odm_zips",
            second_subdirectory => "$selected_drone_run_id",
            archive_path => $c->config->{archive_path},
            archive_filename => $upload_original_name,
            timestamp => $timestamp,
            user_id => $user_id,
            user_role => $user_role
        });
        my $archived_filename_with_path = $uploader->archive();
        my $md5 = $uploader->get_md5($archived_filename_with_path);
        if (!$archived_filename_with_path) {
            $c->stash->{rest} = { error => "Could not save file $upload_original_name in archive." };
            $c->detach();
        }
        unlink $upload_tempfile;
        print STDERR "Archived Drone Image ODM Zip File: $archived_filename_with_path\n";

        my $image = SGN::Image->new( $c->dbc->dbh, undef, $c );
        my $zipfile_return = $image->upload_drone_imagery_zipfile($archived_filename_with_path, $user_id, $selected_drone_run_id);
        # print STDERR Dumper $zipfile_return;
        if ($zipfile_return->{error}) {
            $c->stash->{rest} = { error => "Problem saving images!".$zipfile_return->{error} };
            $c->detach();
        }
        my $image_paths = $zipfile_return->{image_files};

        my $example_archived_filename_with_path_odm_img;
        foreach my $i (@$image_paths) {
            my $uploader_odm_dir = CXGN::UploadFile->new({
                tempfile => $i,
                subdirectory => "drone_imagery_upload_odm_dir",
                second_subdirectory => "$selected_drone_run_id",
                third_subdirectory => 'images',
                archive_path => $c->config->{archive_path},
                archive_filename => basename($i),
                timestamp => $timestamp,
                user_id => $user_id,
                user_role => $user_role,
                include_timestamp => 0
            });
            my $archived_filename_with_path_odm_img = $uploader_odm_dir->archive();
            my $md5 = $uploader_odm_dir->get_md5($archived_filename_with_path_odm_img);
            if (!$archived_filename_with_path_odm_img) {
                $c->stash->{rest} = { error => "Could not save file $i in archive." };
                $c->detach();
            }
            print STDERR "Archived Drone Image ODM IMG File: $archived_filename_with_path_odm_img\n";
            $example_archived_filename_with_path_odm_img = $archived_filename_with_path_odm_img;
        }

        my $current_odm_image_count = $new_drone_run_band_stitching_odm_current_image_count+scalar(@$image_paths);
        if ($new_drone_run_band_stitching_odm_more_images eq 'Yes') {
            $c->stash->{rest} = { drone_run_project_id => $selected_drone_run_id, current_image_count => $current_odm_image_count };
            $c->detach();
        }

        if ($current_odm_image_count < 25) {
            $c->stash->{rest} = { error => "Upload more than $current_odm_image_count images! Atleast 25 are required for OpenDroneMap to stitch. Upload now and try again!", drone_run_project_id => $selected_drone_run_id, current_image_count => $current_odm_image_count };
            $c->detach();
        }

        print STDERR $example_archived_filename_with_path_odm_img."\n";
        my @img_path_split = split '\/', $example_archived_filename_with_path_odm_img;
        my $image_path_img_name = pop(@img_path_split);
        my $image_path_project_name = pop(@img_path_split);
        my $image_path_remaining = join '/', @img_path_split;
        # my $image_path_remaining_host = $image_path_remaining =~ s/cxgn\/sgn\/static\/documents\/tempfiles/tmp\/breedbase\-site/gr;
        my $hostpath = $c->config->{hostpath_archive};
        my $image_path_remaining_host = $image_path_remaining =~ s/\/home\/production/$hostpath/gr;
        print STDERR Dumper [$image_path_img_name, $image_path_project_name, $image_path_remaining, $image_path_remaining_host];

        my $dir = $c->tempfiles_subdir('/upload_drone_imagery_raw_images');
        my $temp_file_docker_log = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_raw_images/fileXXXX');

        my $odm_check_prop = $schema->resultset("Project::Projectprop")->find_or_create({
            project_id => $selected_drone_run_id,
            type_id => $odm_process_running_cvterm_id
        });
        $odm_check_prop->value('1');
        $odm_check_prop->update();

        my @stitched_bands;
        my %raw_image_bands;
        eval {
            if ($new_drone_run_camera_info eq 'micasense_5') {
                my $upload_panel_original_name = $upload_panel_file->filename();
                my $upload_panel_tempfile = $upload_panel_file->tempname;

                my $uploader_panel = CXGN::UploadFile->new({
                    tempfile => $upload_panel_tempfile,
                    subdirectory => "drone_imagery_upload_odm_panel_zips",
                    second_subdirectory => "$selected_drone_run_id",
                    archive_path => $c->config->{archive_path},
                    archive_filename => $upload_panel_original_name,
                    timestamp => $timestamp,
                    user_id => $user_id,
                    user_role => $user_role
                });
                my $archived_filename_panel_with_path = $uploader_panel->archive();
                my $md5_panel = $uploader_panel->get_md5($archived_filename_panel_with_path);
                if (!$archived_filename_panel_with_path) {
                    $c->stash->{rest} = { error => "Could not save file $archived_filename_panel_with_path in archive." };
                    $c->detach();
                }
                unlink $upload_panel_tempfile;
                print STDERR "Archived Drone Image ODM Zip File: $archived_filename_panel_with_path\n";

                # my $dtm_string = '';
                # my $ua       = LWP::UserAgent->new();
                # my $response = $ua->post( $c->config->{main_production_site_url}."/RunODMDocker.php", { 'file_path' => $image_path_remaining_host, 'dtm_string' => $dtm_string } );
                # my $content  = $response->decoded_content();
                # print STDERR Dumper $content;

                my $odm_radiometric_calibration = $new_drone_run_band_stitching_odm_radiocalibration ? '--radiometric-calibration camera' : '';

                my $odm_command = 'docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v '.$image_path_remaining_host.':/datasets/code opendronemap/odm --project-path /datasets --rerun-all --dsm --dtm '.$odm_radiometric_calibration.' > '.$temp_file_docker_log;
                print STDERR $odm_command."\n";
                my $odm_status = system($odm_command);

                my $odm_b1 = "$image_path_remaining/odm_orthophoto/b1.png";
                my $odm_b2 = "$image_path_remaining/odm_orthophoto/b2.png";
                my $odm_b3 = "$image_path_remaining/odm_orthophoto/b3.png";
                my $odm_b4 = "$image_path_remaining/odm_orthophoto/b4.png";
                my $odm_b5 = "$image_path_remaining/odm_orthophoto/b5.png";
                my $odm_cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/ODMOpenImage.py --image_path $image_path_remaining/odm_orthophoto/odm_orthophoto.tif --outfile_path_b1 $odm_b1 --outfile_path_b2 $odm_b2 --outfile_path_b3 $odm_b3 --outfile_path_b4 $odm_b4 --outfile_path_b5 $odm_b5 --odm_radiocalibrated True";
                my $odm_open_status = system($odm_cmd);

                my $odm_dsm_png = "$image_path_remaining/odm_dem/dsm.png";
                my $odm_dtm_png = "$image_path_remaining/odm_dem/dtm.png";
                my $odm_subtract_png = "$image_path_remaining/odm_dem/subtract.png";
                my $odm_dem_cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/ODMOpenImageDSM.py --image_path_dsm $image_path_remaining/odm_dem/dsm.tif --image_path_dtm $image_path_remaining/odm_dem/dtm.tif --outfile_path_dsm $odm_dsm_png --outfile_path_dtm $odm_dtm_png --outfile_path_subtract $odm_subtract_png --band_number 1";
                my $odm_dem_open_status = system($odm_dem_cmd);

                @stitched_bands = (
                    ["Band 1", "OpenDroneMap Blue", "Blue (450-520nm)", $odm_b1],
                    ["Band 2", "OpenDroneMap Green", "Green (515-600nm)", $odm_b2],
                    ["Band 3", "OpenDroneMap Red", "Red (600-690nm)", $odm_b3],
                    ["Band 4", "OpenDroneMap NIR", "NIR (780-3000nm)", $odm_b4],
                    ["Band 5", "OpenDroneMap RedEdge", "Red Edge (690-750nm)", $odm_b5],
                    ["Band 6", "OpenDroneMap DSM", "Black and White Image", $odm_dsm_png]
                );
            }
            elsif ($new_drone_run_camera_info eq 'ccd_color' || $new_drone_run_camera_info eq 'cmos_color') {
                my $odm_command = 'docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v '.$image_path_remaining_host.':/datasets/code opendronemap/odm --project-path /datasets --rerun-all --dsm --dtm > '.$temp_file_docker_log;
                print STDERR $odm_command."\n";
                my $odm_status = system($odm_command);

                my $odm_dsm_png = "$image_path_remaining/odm_dem/dsm.png";
                my $odm_dtm_png = "$image_path_remaining/odm_dem/dtm.png";
                my $odm_subtract_png = "$image_path_remaining/odm_dem/subtract.png";
                my $odm_dem_cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/ODMOpenImageDSM.py --image_path_dsm $image_path_remaining/odm_dem/dsm.tif --image_path_dtm $image_path_remaining/odm_dem/dtm.tif --outfile_path_dsm $odm_dsm_png --outfile_path_dtm $odm_dtm_png --outfile_path_subtract $odm_subtract_png --band_number 1";
                my $odm_dem_open_status = system($odm_dem_cmd);

                @stitched_bands = (
                    ["Color Image", "OpenDroneMap RGB Color Image", "RGB Color Image", "$image_path_remaining/odm_orthophoto/odm_orthophoto.tif"],
                    ["DSM", "OpenDroneMap DSM", "Black and White Image", $odm_dsm_png]
                );
            }
            else {
                die "Camera info not supported for raw image upload ODM stitch: $new_drone_run_camera_info\n";
            }

            my $calibration_info = '';
            if ($new_drone_run_band_stitching_odm_radiocalibration && $new_drone_run_camera_info eq 'micasense_5') {
                $calibration_info = ' with radiocalibration';
            }
            elsif (!$new_drone_run_band_stitching_odm_radiocalibration && $new_drone_run_camera_info eq 'micasense_5') {
                $calibration_info = ' without radiocalibration';
            }

            foreach my $m (@stitched_bands) {
                my $project_rs = $schema->resultset("Project::Project")->create({
                    name => $new_drone_run_name."_".$m->[1],
                    description => $new_drone_run_desc.". ".$m->[0]." ".$m->[1].". Orthomosaic stitched by OpenDroneMap in ImageBreed".$calibration_info.".",
                    projectprops => [{type_id => $drone_run_band_type_cvterm_id, value => $m->[2]}, {type_id => $design_cvterm_id, value => 'drone_run_band'}],
                    project_relationship_subject_projects => [{type_id => $project_relationship_type_id, object_project_id => $selected_drone_run_id}]
                });
                my $selected_drone_run_band_id = $project_rs->project_id();

                my $time = DateTime->now();
                my $timestamp = $time->ymd()."_".$time->hms();
                my $upload_original_name = $new_drone_run_name."_ImageBreed_stitched_".$m->[1].".png";

                my $uploader = CXGN::UploadFile->new({
                    tempfile => $m->[3],
                    subdirectory => "drone_imagery_upload",
                    archive_path => $c->config->{archive_path},
                    archive_filename => $upload_original_name,
                    timestamp => $timestamp,
                    user_id => $user_id,
                    user_role => $user_role
                });
                my $archived_filename_with_path = $uploader->archive();
                my $md5 = $uploader->get_md5($archived_filename_with_path);
                if (!$archived_filename_with_path) {
                    $c->stash->{rest} = { error => "Could not save file $upload_original_name in archive." };
                    $c->detach();
                }
                unlink $upload_tempfile;
                print STDERR "Archived Drone Image File: $archived_filename_with_path\n";

                my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
                $image->set_sp_person_id($user_id);
                my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
                my $ret = $image->process_image($archived_filename_with_path, 'project', $selected_drone_run_band_id, $linking_table_type_id);
                push @return_drone_run_band_image_urls, $image->get_image_url('original');
                push @return_drone_run_band_image_ids, $image->get_image_id();
                push @return_drone_run_band_project_ids, $selected_drone_run_band_id;
            }
        };

        $odm_check_prop->value('0');
        $odm_check_prop->update();
    }

    $c->stash->{rest} = { success => 1, drone_run_project_id => $selected_drone_run_id, drone_run_band_project_ids => \@return_drone_run_band_project_ids, drone_run_band_image_ids => \@return_drone_run_band_image_ids, drone_run_band_image_urls => \@return_drone_run_band_image_urls, drone_run_band_raw_image_boundaries_temp_images => \@raw_image_boundaries_temp_images, saved_image_stacks => \%saved_image_stacks };
}

sub upload_drone_imagery_bulk : Path('/api/drone_imagery/upload_drone_imagery_bulk') : ActionClass('REST') { }
sub upload_drone_imagery_bulk_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    $c->response->headers->header( "Access-Control-Allow-Origin" => '*' );
    $c->response->headers->header( "Access-Control-Allow-Methods" => "POST, GET, PUT, DELETE" );
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    print STDERR Dumper $c->req->params();

    my $imaging_vehicle_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'imaging_event_vehicle', 'stock_type')->cvterm_id();
    my $imaging_vehicle_properties_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'imaging_event_vehicle_json', 'stock_property')->cvterm_id();
    my $drone_run_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_experiment', 'experiment_type')->cvterm_id();
    my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property')->cvterm_id();
    my $drone_run_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_project_type', 'project_property')->cvterm_id();
    my $drone_run_is_raw_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_is_raw_images', 'project_property')->cvterm_id();
    my $drone_run_camera_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_camera_type', 'project_property')->cvterm_id();
    my $project_start_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_start_date', 'project_property')->cvterm_id();
    my $drone_run_base_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_base_date', 'project_property')->cvterm_id();
    my $drone_run_rig_desc_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_camera_rig_description', 'project_property')->cvterm_id();
    my $drone_run_related_cvterms_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_related_time_cvterms_json', 'project_property')->cvterm_id();
    my $drone_run_band_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
    my $drone_run_drone_run_band_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
    my $calendar_funcs = CXGN::Calendar->new({});

    my %seen_field_trial_drone_run_dates;
    my $drone_run_date_q = "SELECT drone_run_date.value
        FROM project AS drone_run_band_project
        JOIN project_relationship AS drone_run_band_rel ON (drone_run_band_rel.subject_project_id = drone_run_band_project.project_id AND drone_run_band_rel.type_id = $drone_run_drone_run_band_type_id)
        JOIN project AS drone_run_project ON (drone_run_band_rel.object_project_id = drone_run_project.project_id)
        JOIN projectprop AS drone_run_date ON(drone_run_project.project_id=drone_run_date.project_id AND drone_run_date.type_id=$project_start_date_type_id);";
    my $drone_run_date_h = $schema->storage->dbh()->prepare($drone_run_date_q);
    $drone_run_date_h->execute();
    while( my ($drone_run_date) = $drone_run_date_h->fetchrow_array()) {
        my $drone_run_date_formatted = $drone_run_date ? $calendar_funcs->display_start_date($drone_run_date) : '';
        if ($drone_run_date_formatted) {
            my $date_obj = Time::Piece->strptime($drone_run_date_formatted, "%Y-%B-%d %H:%M:%S");
            $seen_field_trial_drone_run_dates{$date_obj->epoch}++;
        }
    }

    my $upload_file = $c->req->upload('upload_drone_imagery_bulk_images_zipfile');
    my $imaging_events_file = $c->req->upload('upload_drone_imagery_bulk_imaging_events');

    my $upload_original_name = $upload_file->filename();
    my $upload_tempfile = $upload_file->tempname;
    my $upload_imaging_events_file = $imaging_events_file->tempname;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => "drone_imagery_upload_bulk_orthophoto_zips",
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        $c->stash->{rest} = { error => "Could not save file $upload_original_name in archive." };
        $c->detach();
    }
    unlink $upload_tempfile;
    print STDERR "Archived Drone Image Bulk Orthophoto Zip File: $archived_filename_with_path\n";

    my $archived_zip = CXGN::ZipFile->new(archived_zipfile_path=>$archived_filename_with_path);
    my $file_members = $archived_zip->file_members();
    if (!$file_members){
        $c->stash->{rest} = {error => 'Could not read your orthophoto bulk zipfile. Is it .zip format?</br></br>'};
        return;
    }

    my %spectral_lookup = (
        blue => "Blue (450-520nm)",
        green => "Green (515-600nm)",
        red => "Red (600-690nm)",
        rededge => "Red Edge (690-750nm)",
        nir => "NIR (780-3000nm)",
        mir => "MIR (3000-50000nm)",
        fir => "FIR (50000-1000000nm)",
        thir => "Thermal IR (9000-14000nm)",
        rgb => "RGB Color Image",
        bw => "Black and White Image"
    );

    my %sensor_map = (
        "MicaSense 5 Channel Camera" => "micasense_5",
        "CCD Color Camera" => "ccd_color",
        "CMOS Color Camera" => "cmos_color"
    );

    my %filename_imaging_event_lookup;
    my %filename_imaging_event_band_check;
    foreach (@$file_members) {
        my $image = SGN::Image->new( $dbh, undef, $c );
        my $filename = $_->fileName();
        my @zipfile_comp = split '\/', $filename;
        my $filename_wext;
        if (scalar(@zipfile_comp)==1) {
            $filename_wext = $zipfile_comp[0];
        }
        else {
            $filename_wext = $zipfile_comp[1];
        }
        my @filename_comps = split '\.', $filename_wext;
        my $filename_only = $filename_comps[0];
        my @image_spectra = split '\_\_', $filename_only;
        my $temp_file = $image->upload_zipfile_images($_);
        my $imaging_event_name = $image_spectra[0];
        my $band = $image_spectra[1];

        if (!exists($spectral_lookup{$band})) {
            $c->stash->{rest} = {error => "The spectral band $band is not allowed in the provided orthophoto $filename_only. Make sure the orthophotos are saved as a concatenation of the imaging event name and the spectral band, with a pipe (|) as the separator (e.g. Ortho1_01012020|blue.tiff) and the allowed spectral bands are blue,green,red,rededge,nir,mir,fir,thir,rgb,bw." };
            $c->detach;
        }
        my $spectral_band = $spectral_lookup{$band};
        print STDERR Dumper [$filename_wext, $filename, $temp_file, $imaging_event_name, $spectral_band];
        $filename_imaging_event_lookup{$filename_wext} = {
            file => $temp_file,
            band => $spectral_band,
            band_short => $band
        };
        if (exists($filename_imaging_event_band_check{$imaging_event_name}->{$spectral_band})) {
            $c->stash->{rest} = {error => "Do not upload duplicate spectral types for the same imaging event. There is already a $band image for $imaging_event_name in the zipfile! Make sure the orthophotos are saved as a concatenation of the imaging event name and the spectral band, with a pipe (|) as the separator (e.g. Ortho1_01012020|blue.tiff)" };
            $c->detach;
        } else {
            $filename_imaging_event_band_check{$imaging_event_name} = $spectral_band;
        }
    }

    my @parse_csv_errors;
    my %field_trial_name_lookup;
    my %vehicle_name_lookup;

    my $parser = Spreadsheet::ParseExcel->new();
    my $excel_obj = $parser->parse($upload_imaging_events_file);
    if (!$excel_obj) {
        $c->stash->{rest} = {error => 'The Excel (.xls) file could not be opened:'.$parser->error().'.</br></br>'};
        $c->detach;
    }

    my $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
    if (!$worksheet) {
        $c->stash->{rest} = {error => 'Spreadsheet must be on 1st tab in Excel (.xls) file.</br></br>'};
        $c->detach;
    }
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();
    if (($col_max - $col_min)  < 1 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of plot data
        $c->stash->{rest} = {error => 'Spreadsheet (.xls) is missing header or contains no rows.</br></br>'};
        $c->detach;
    }

    if ($worksheet->get_cell(0,0)->value() ne 'Imaging Event Name' ||
        $worksheet->get_cell(0,1)->value() ne 'Type' ||
        $worksheet->get_cell(0,2)->value() ne 'Description' ||
        $worksheet->get_cell(0,3)->value() ne 'Date' ||
        $worksheet->get_cell(0,4)->value() ne 'Vehicle Name' ||
        $worksheet->get_cell(0,5)->value() ne 'Vehicle Battery Set' ||
        $worksheet->get_cell(0,6)->value() ne 'Sensor' ||
        $worksheet->get_cell(0,7)->value() ne 'Field Trial Name' ||
        $worksheet->get_cell(0,8)->value() ne 'Image Filenames' ||
        $worksheet->get_cell(0,9)->value() ne 'Coordinate System' ||
        $worksheet->get_cell(0,10)->value() ne 'Base Date' ||
        $worksheet->get_cell(0,11)->value() ne 'Camera Rig') {
            $c->stash->{rest} = {error => "The header row in the CSV spreadsheet must be 'Imaging Event Name,Type,Description,Date,Vehicle Name,Vehicle Battery Set,Sensor,Field Trial Name,GeoJSON Filename,Image Filenames,Coordinate System,Base Date,Camera Rig'." };
            $c->detach;
    }

    my %seen_upload_dates;
    for my $row ( 1 .. $row_max ) {
        my $imaging_event_name;
        if ($worksheet->get_cell($row,0)) {
            $imaging_event_name = $worksheet->get_cell($row,0)->value();
        }
        my $imaging_event_type;
        if ($worksheet->get_cell($row,1)) {
            $imaging_event_type = $worksheet->get_cell($row,1)->value();
        }
        my $imaging_event_desc;
        if ($worksheet->get_cell($row,2)) {
            $imaging_event_desc = $worksheet->get_cell($row,2)->value();
        }
        my $imaging_event_date;
        if ($worksheet->get_cell($row,3)) {
            $imaging_event_date = $worksheet->get_cell($row,3)->value();
        }
        my $vehicle_name;
        if ($worksheet->get_cell($row,4)) {
            $vehicle_name = $worksheet->get_cell($row,4)->value();
        }
        my $vehicle_battery = 'default_battery';
        if ($worksheet->get_cell($row,5)) {
            $vehicle_battery = $worksheet->get_cell($row,5)->value();
        }
        my $sensor;
        if ($worksheet->get_cell($row,6)) {
            $sensor = $worksheet->get_cell($row,6)->value();
        }
        my $field_trial_name;
        if ($worksheet->get_cell($row,7)) {
            $field_trial_name = $worksheet->get_cell($row,7)->value();
        }
        my $image_filenames;
        if ($worksheet->get_cell($row,8)) {
            $image_filenames = $worksheet->get_cell($row,8)->value();
        }
        my $coordinate_system;
        if ($worksheet->get_cell($row,9)) {
            $coordinate_system = $worksheet->get_cell($row,9)->value();
        }
        my $base_date;
        if ($worksheet->get_cell($row,10)) {
            $base_date = $worksheet->get_cell($row,10)->value();
        }
        my $rig_desc;
        if ($worksheet->get_cell($row,11)) {
            $rig_desc = $worksheet->get_cell($row,11)->value();
        }

        if (!$imaging_event_name){
            push @parse_csv_errors, "Please give a new imaging event name!";
        }
        if (!$imaging_event_type){
            push @parse_csv_errors, "Please give an imaging event type!";
        }
        if (!$imaging_event_desc){
            push @parse_csv_errors, "Please give an imaging event description!";
        }
        if (!$imaging_event_date){
            push @parse_csv_errors, "Please give an imaging event date!";
        }
        if (!$vehicle_name){
            push @parse_csv_errors, "Please give a vehicle name!";
        }
        if (!$sensor){
            push @parse_csv_errors, "Please give a sensor name!";
        }
        if (!$field_trial_name){
            push @parse_csv_errors, "Please give a field trial name!";
        }

        if ($coordinate_system ne 'UTM' && $coordinate_system ne 'WGS84' && $coordinate_system ne 'Pixels') {
            push @parse_csv_errors, "The given coordinate system $coordinate_system is not one of: UTM, WGS84, or Pixels!";
        }
        if ($coordinate_system ne 'Pixels') {
            $c->stash->{rest} = {error => "Only the Pixels coordinate system is currently supported. In the future GeoTIFFs will be supported, but for now please only upload simple raster images (.png, .tiff, .jpg)." };
            $c->detach;
        }

        my $field_trial_rs = $schema->resultset("Project::Project")->search({name=>$field_trial_name});
        if ($field_trial_rs->count != 1) {
            $c->stash->{rest} = {error => "The field trial $field_trial_name does not exist in the database already! Please add it first." };
            $c->detach;
        }
        my $field_trial_id = $field_trial_rs->first->project_id();
        $field_trial_name_lookup{$field_trial_name} = $field_trial_id;

        if ($imaging_event_date !~ /^\d{4}\/\d{2}\/\d{2}\s\d\d:\d\d:\d\d$/){
            $c->stash->{rest} = {error => "Please give a new imaging event date in the format YYYY/MM/DD HH:mm:ss! The provided $imaging_event_date is not correct!" };
            $c->detach;
        }
        if ($imaging_event_type ne 'Aerial Medium to High Res' && $imaging_event_type ne 'Aerial Low Res'){
            $c->stash->{rest} = {error => "The imaging event type $imaging_event_type is not one of 'Aerial Low Res' or 'Aerial Medium to High Res'!" };
            $c->detach;
        }
        if (!exists($sensor_map{$sensor})){
            $c->stash->{rest} = {error => "The sensor $sensor is not one of 'MicaSense 5 Channel Camera' or 'CCD Color Camera' or 'CMOS Color Camera'!" };
            $c->detach;
        }

        my $project_rs = $schema->resultset("Project::Project")->search({name=>$imaging_event_name});
        if ($project_rs->count > 0) {
            push @parse_csv_errors, "Please use a globally unique imaging event name! The name you specified $imaging_event_name has already been used.";
        }
        my $vehicle_prop = $schema->resultset("Stock::Stock")->search({uniquename => $vehicle_name, type_id=>$imaging_vehicle_cvterm_id});
        if ($vehicle_prop->count != 1) {
            push @parse_csv_errors, "Imaging event vehicle $vehicle_name is not already in the database! Please add it first!";
        }
        else {
            $vehicle_name_lookup{$vehicle_name} = $vehicle_prop->first->stock_id;
        }

        my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $field_trial_id });
        my $planting_date = $trial->get_planting_date();
        if (!$planting_date) {
            $c->stash->{rest} = {error => "The field trial $field_trial_name does not have a planting date set! Please set this first!" };
            $c->detach;
        }
        my $planting_date_time_object = Time::Piece->strptime($planting_date, "%Y-%B-%d");
        my $imaging_event_date_time_object = Time::Piece->strptime($imaging_event_date, "%Y/%m/%d %H:%M:%S");

        if (exists($seen_field_trial_drone_run_dates{$imaging_event_date_time_object->epoch})) {
            $c->stash->{rest} = { error => "An imaging event has already occured on this field trial at the same date and time ($imaging_event_date)! Please give a unique date/time for each imaging event!" };
            $c->detach();
        }
        $seen_field_trial_drone_run_dates{$imaging_event_date_time_object->epoch}++;

        if ($imaging_event_date_time_object->epoch - $planting_date_time_object->epoch <= 0) {
            push @parse_csv_errors, "The date of the imaging event $imaging_event_date is not after the field trial planting date $planting_date!";
        }
        if ($base_date) {
            if ($base_date !~ /^\d{4}\/\d{2}\/\d{2}\s\d\d:\d\d:\d\d$/){
                $c->stash->{rest} = {error => "Please give a new imaging event base date in the format YYYY/MM/DD HH:mm:ss! The provided $base_date is not correct! Leave empty if not relevant!" };
                $c->detach;
            }
            my $imaging_event_base_time_object = Time::Piece->strptime($base_date, "%Y/%m/%d %H:%M:%S");

            if ($imaging_event_date_time_object->epoch - $imaging_event_base_time_object->epoch < 0) {
                push @parse_csv_errors, "The date of the imaging event $imaging_event_date is not after the base date $base_date!";
            }
        }

        my @orthoimage_names = split ',', $image_filenames;
        foreach (@orthoimage_names) {
            if (!exists($filename_imaging_event_lookup{$_})) {
                push @parse_csv_errors, "The orthophoto filename $_ does not exist in the uploaded orthophoto zipfile. Make sure the orthophotos are saved as a concatenation of the ortho filename defined in the spreadsheet and the spectral band, with a double-underscore (__) as the separator (e.g. Ortho1_01012020__blue.tiff)";
            }
        }
    }

    if (scalar(@parse_csv_errors) > 0) {
        my $error_string = join "<br/>", @parse_csv_errors;
        $c->stash->{rest} = {error_string => $error_string };
        $c->detach;
    }

    my @drone_run_project_ids;
    my %drone_run_band_hash;
    for my $row ( 1 .. $row_max ) {
        my $imaging_event_name = $worksheet->get_cell($row,0)->value();
        my $imaging_event_type = $worksheet->get_cell($row,1)->value();
        my $imaging_event_desc = $worksheet->get_cell($row,2)->value();
        my $imaging_event_date = $worksheet->get_cell($row,3)->value();
        my $vehicle_name = $worksheet->get_cell($row,4)->value();
        my $vehicle_battery = $worksheet->get_cell($row,5) ? $worksheet->get_cell($row,5)->value() : 'default_battery';
        my $sensor = $worksheet->get_cell($row,6)->value();
        my $field_trial_name = $worksheet->get_cell($row,7)->value();
        my $image_filenames = $worksheet->get_cell($row,8)->value();
        my $coordinate_system = $worksheet->get_cell($row,9)->value();
        my $base_date = $worksheet->get_cell($row,10) ? $worksheet->get_cell($row,10)->value() : '';
        my $rig_desc = $worksheet->get_cell($row,11) ? $worksheet->get_cell($row,11)->value() : '';

        my $new_drone_run_vehicle_id = $vehicle_name_lookup{$vehicle_name};
        my $selected_trial_id = $field_trial_name_lookup{$field_trial_name};
        my $new_drone_run_camera_info = $sensor_map{$sensor};
        my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $selected_trial_id });
        my $trial_location_id = $trial->get_location()->[0];
        my $planting_date = $trial->get_planting_date();
        my $planting_date_time_object = Time::Piece->strptime($planting_date, "%Y-%B-%d");
        my $imaging_event_date_time_object = Time::Piece->strptime($imaging_event_date, "%Y/%m/%d %H:%M:%S");
        my $drone_run_event = $calendar_funcs->check_value_format($imaging_event_date);
        my $time_diff;
        my $base_date_event;
        if ($base_date) {
            my $imaging_event_base_date_time_object = Time::Piece->strptime($base_date, "%Y/%m/%d %H:%M:%S");
            $time_diff = $imaging_event_date_time_object - $imaging_event_base_date_time_object;
            $base_date_event = $calendar_funcs->check_value_format($base_date);
        }
        else {
            $time_diff = $imaging_event_date_time_object - $planting_date_time_object;
        }
        my $time_diff_weeks = $time_diff->weeks;
        my $time_diff_days = $time_diff->days;
        my $time_diff_hours = $time_diff->hours;
        my $rounded_time_diff_weeks = round($time_diff_weeks);
        if ($rounded_time_diff_weeks == 0) {
            $rounded_time_diff_weeks = 1;
        }

        my $week_term_string = "week $rounded_time_diff_weeks";
        my $q = "SELECT t.cvterm_id FROM cvterm as t JOIN cv ON(t.cv_id=cv.cv_id) WHERE t.name=? and cv.name=?;";
        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute($week_term_string, 'cxgn_time_ontology');
        my ($week_cvterm_id) = $h->fetchrow_array();

        if (!$week_cvterm_id) {
            my $new_week_term = $schema->resultset("Cv::Cvterm")->create_with({
               name => $week_term_string,
               cv => 'cxgn_time_ontology'
            });
            $week_cvterm_id = $new_week_term->cvterm_id();
        }

        my $day_term_string = "day $time_diff_days";
        $h->execute($day_term_string, 'cxgn_time_ontology');
        my ($day_cvterm_id) = $h->fetchrow_array();

        if (!$day_cvterm_id) {
            my $new_day_term = $schema->resultset("Cv::Cvterm")->create_with({
               name => $day_term_string,
               cv => 'cxgn_time_ontology'
            });
            $day_cvterm_id = $new_day_term->cvterm_id();
        }

        my $week_term = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $week_cvterm_id, 'extended');
        my $day_term = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $day_cvterm_id, 'extended');

        my %related_cvterms = (
            week => $week_term,
            day => $day_term
        );

        my $drone_run_projectprops = [
            {type_id => $drone_run_type_cvterm_id, value => $imaging_event_type},
            {type_id => $project_start_date_type_id, value => $drone_run_event},
            {type_id => $design_cvterm_id, value => 'drone_run'},
            {type_id => $drone_run_camera_type_cvterm_id, value => $new_drone_run_camera_info},
            {type_id => $drone_run_related_cvterms_cvterm_id, value => encode_json \%related_cvterms}
        ];
        if ($base_date) {
            push @$drone_run_projectprops, {type_id => $drone_run_base_date_type_id, value => $base_date_event};
        }
        if ($rig_desc) {
            push @$drone_run_projectprops, {type_id => $drone_run_rig_desc_type_id, value => $rig_desc};
        }

        my $nd_experiment_rs = $schema->resultset("NaturalDiversity::NdExperiment")->create({
            nd_geolocation_id => $trial_location_id,
            type_id => $drone_run_experiment_type_id,
            nd_experiment_stocks => [{stock_id => $new_drone_run_vehicle_id, type_id => $drone_run_experiment_type_id}]
        });
        my $drone_run_nd_experiment_id = $nd_experiment_rs->nd_experiment_id();

        my $project_rs = $schema->resultset("Project::Project")->create({
            name => $imaging_event_name,
            description => $imaging_event_desc,
            projectprops => $drone_run_projectprops,
            project_relationship_subject_projects => [{type_id => $project_relationship_type_id, object_project_id => $selected_trial_id}],
            nd_experiment_projects => [{nd_experiment_id => $drone_run_nd_experiment_id}]
        });
        my $selected_drone_run_id = $project_rs->project_id();
        push @drone_run_project_ids, $selected_drone_run_id;

        my $vehicle_prop = decode_json $schema->resultset("Stock::Stockprop")->search({stock_id => $new_drone_run_vehicle_id, type_id=>$imaging_vehicle_properties_cvterm_id})->first()->value();
        $vehicle_prop->{batteries}->{$vehicle_battery}->{usage}++;
        my $vehicle_prop_update = $schema->resultset('Stock::Stockprop')->update_or_create({
            type_id=>$imaging_vehicle_properties_cvterm_id,
            stock_id=>$new_drone_run_vehicle_id,
            rank=>0,
            value=>encode_json $vehicle_prop
        },
        {
            key=>'stockprop_c1'
        });

        my @orthoimage_names = split ',', $image_filenames;
        my @ortho_images;
        foreach (@orthoimage_names) {
            push @ortho_images, $filename_imaging_event_lookup{$_};
        }
        foreach my $m (@ortho_images) {
            my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
            my $band = $m->{band};
            my $band_short = $m->{band_short};
            my $file = $m->{file};
            my $project_rs = $schema->resultset("Project::Project")->create({
                name => $imaging_event_name."_".$band_short,
                description => $imaging_event_desc.". ".$band,
                projectprops => [{type_id => $drone_run_band_type_cvterm_id, value => $band}, {type_id => $design_cvterm_id, value => 'drone_run_band'}],
                project_relationship_subject_projects => [{type_id => $project_relationship_type_id, object_project_id => $selected_drone_run_id}]
            });
            my $selected_drone_run_band_id = $project_rs->project_id();

            my $time = DateTime->now();
            my $timestamp = $time->ymd()."_".$time->hms();
            my $upload_original_name = $imaging_event_name."_".$band_short.".png";

            my $uploader = CXGN::UploadFile->new({
                tempfile => $file,
                subdirectory => "drone_imagery_upload",
                archive_path => $c->config->{archive_path},
                archive_filename => $upload_original_name,
                timestamp => $timestamp,
                user_id => $user_id,
                user_role => $user_role
            });
            my $archived_filename_with_path = $uploader->archive();
            my $md5 = $uploader->get_md5($archived_filename_with_path);
            if (!$archived_filename_with_path) {
                $c->stash->{rest} = { error => "Could not save file $upload_original_name in archive." };
                $c->detach();
            }
            unlink $upload_tempfile;
            print STDERR "Archived Bulk Orthophoto File: $archived_filename_with_path\n";

            my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
            $image->set_sp_person_id($user_id);
            my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
            my $ret = $image->process_image($archived_filename_with_path, 'project', $selected_drone_run_band_id, $linking_table_type_id);

            push @{$drone_run_band_hash{$selected_drone_run_id}}, {
                drone_run_band_project_id => $selected_drone_run_band_id,
                band => $band
            };
        }
    }

    $c->stash->{rest} = { success => 1, drone_run_project_ids => \@drone_run_project_ids, drone_run_band_hash => \%drone_run_band_hash };
}

sub upload_drone_imagery_bulk_previous : Path('/api/drone_imagery/upload_drone_imagery_bulk_previous') : ActionClass('REST') { }
sub upload_drone_imagery_bulk_previous_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    $c->response->headers->header( "Access-Control-Allow-Origin" => '*' );
    $c->response->headers->header( "Access-Control-Allow-Methods" => "POST, GET, PUT, DELETE" );
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    print STDERR Dumper $c->req->params();

    my $imaging_vehicle_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'imaging_event_vehicle', 'stock_type')->cvterm_id();
    my $imaging_vehicle_properties_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'imaging_event_vehicle_json', 'stock_property')->cvterm_id();
    my $drone_run_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_experiment', 'experiment_type')->cvterm_id();
    my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property')->cvterm_id();
    my $geoparam_coordinates_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_geoparam_coordinates', 'project_property')->cvterm_id();
    my $drone_run_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_project_type', 'project_property')->cvterm_id();
    my $drone_run_is_raw_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_is_raw_images', 'project_property')->cvterm_id();
    my $drone_run_camera_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_camera_type', 'project_property')->cvterm_id();
    my $project_start_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_start_date', 'project_property')->cvterm_id();
    my $drone_run_base_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_base_date', 'project_property')->cvterm_id();
    my $drone_run_rig_desc_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_camera_rig_description', 'project_property')->cvterm_id();
    my $drone_run_related_cvterms_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_related_time_cvterms_json', 'project_property')->cvterm_id();
    my $drone_run_band_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
    my $process_indicator_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_standard_process_in_progress', 'project_property')->cvterm_id();
    my $processed_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_standard_process_completed', 'project_property')->cvterm_id();
    my $processed_minimal_vi_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_standard_process_vi_completed', 'project_property')->cvterm_id();
    my $drone_run_band_type_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $rotate_angle_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_rotate_angle', 'project_property')->cvterm_id();
    my $cropping_polygon_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_cropped_polygon', 'project_property')->cvterm_id();
    my $plot_polygon_template_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_plot_polygons', 'project_property')->cvterm_id();
    my $project_image_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $drone_run_drone_run_band_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
    my $calendar_funcs = CXGN::Calendar->new({});

    my %seen_field_trial_drone_run_dates;
    my $drone_run_date_q = "SELECT drone_run_date.value
        FROM project AS drone_run_band_project
        JOIN project_relationship AS drone_run_band_rel ON (drone_run_band_rel.subject_project_id = drone_run_band_project.project_id AND drone_run_band_rel.type_id = $drone_run_drone_run_band_type_id)
        JOIN project AS drone_run_project ON (drone_run_band_rel.object_project_id = drone_run_project.project_id)
        JOIN projectprop AS drone_run_date ON(drone_run_project.project_id=drone_run_date.project_id AND drone_run_date.type_id=$project_start_date_type_id);";
    my $drone_run_date_h = $schema->storage->dbh()->prepare($drone_run_date_q);
    $drone_run_date_h->execute();
    while( my ($drone_run_date) = $drone_run_date_h->fetchrow_array()) {
        my $drone_run_date_formatted = $drone_run_date ? $calendar_funcs->display_start_date($drone_run_date) : '';
        if ($drone_run_date_formatted) {
            my $date_obj = Time::Piece->strptime($drone_run_date_formatted, "%Y-%B-%d %H:%M:%S");
            $seen_field_trial_drone_run_dates{$date_obj->epoch}++;
        }
    }

    my %spectral_lookup = (
        blue => "Blue (450-520nm)",
        green => "Green (515-600nm)",
        red => "Red (600-690nm)",
        rededge => "Red Edge (690-750nm)",
        nir => "NIR (780-3000nm)",
        mir => "MIR (3000-50000nm)",
        fir => "FIR (50000-1000000nm)",
        thir => "Thermal IR (9000-14000nm)",
        rgb => "RGB Color Image",
        bw => "Black and White Image"
    );

    my %sensor_map = (
        "MicaSense 5 Channel Camera" => "micasense_5",
        "CCD Color Camera" => "ccd_color",
        "CMOS Color Camera" => "cmos_color"
    );

    my $upload_file = $c->req->upload('upload_drone_imagery_bulk_images_zipfile_previous');
    my $upload_geojson_file = $c->req->upload('upload_drone_imagery_bulk_geojson_zipfile_previous');
    my $imaging_events_file = $c->req->upload('upload_drone_imagery_bulk_imaging_events_previous');

    my $upload_original_name = $upload_file->filename();
    my $upload_tempfile = $upload_file->tempname;
    my $upload_geojson_original_name = $upload_geojson_file->filename();
    my $upload_geojson_tempfile = $upload_geojson_file->tempname;
    my $upload_imaging_events_file = $imaging_events_file->tempname;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => "drone_imagery_upload_bulk_previous_orthophoto_zips",
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        $c->stash->{rest} = { error => "Could not save file $upload_original_name in archive." };
        $c->detach();
    }
    unlink $upload_tempfile;
    print STDERR "Archived Drone Image Bulk Previous Orthophoto Zip File: $archived_filename_with_path\n";

    my $archived_zip = CXGN::ZipFile->new(archived_zipfile_path=>$archived_filename_with_path);
    my $file_members = $archived_zip->file_members();
    if (!$file_members){
        $c->stash->{rest} = {error => 'Could not read your orthophoto bulk zipfile. Is it .zip format?</br></br>'};
        $c->detach;
    }

    my %filename_imaging_event_lookup;
    my %filename_imaging_event_band_check;
    foreach (@$file_members) {
        my $image = SGN::Image->new( $dbh, undef, $c );
        my $filename = $_->fileName();
        my @zipfile_comp = split '\/', $filename;
        my $filename_wext;
        if (scalar(@zipfile_comp)==1) {
            $filename_wext = $zipfile_comp[0];
        }
        else {
            $filename_wext = $zipfile_comp[1];
        }
        my @filename_comps = split '\.', $filename_wext;
        my $filename_only = $filename_comps[0];
        my @image_spectra = split '\_\_', $filename_only;
        my $temp_file = $image->upload_zipfile_images($_);
        my $imaging_event_name = $image_spectra[0];
        my $band = $image_spectra[1];

        if (!exists($spectral_lookup{$band})) {
            $c->stash->{rest} = {error => "The spectral band $band is not allowed in the provided orthophoto $filename. Make sure the orthophotos are saved as a concatenation with the spectral band, with a double-underscore (__) as the separator (e.g. Ortho1_01012020|blue.tiff) and the allowed spectral bands are blue,green,red,rededge,nir,mir,fir,thir,rgb,bw." };
            $c->detach;
        }
        my $spectral_band = $spectral_lookup{$band};
        print STDERR Dumper [$filename_wext, $filename, $temp_file, $imaging_event_name, $spectral_band];
        $filename_imaging_event_lookup{$filename_wext} = {
            file => $temp_file,
            band => $spectral_band,
            band_short => $band
        };
        if (exists($filename_imaging_event_band_check{$imaging_event_name}->{$spectral_band})) {
            $c->stash->{rest} = {error => "Do not upload duplicate spectral types for the same imaging event. There is already a $band image for $imaging_event_name in the zipfile! Make sure the orthophotos are saved as a concatenation of the imaging event name and the spectral band, with a pipe (|) as the separator (e.g. Ortho1_01012020|blue.tiff)" };
            $c->detach;
        } else {
            $filename_imaging_event_band_check{$imaging_event_name}->{$spectral_band}++;
        }
    }

    my $uploader_geojson = CXGN::UploadFile->new({
        tempfile => $upload_geojson_tempfile,
        subdirectory => "drone_imagery_upload_bulk_previous_geojson_zips",
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_geojson_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });
    my $geojson_archived_filename_with_path = $uploader_geojson->archive();
    my $md5_geojson = $uploader_geojson->get_md5($geojson_archived_filename_with_path);
    if (!$geojson_archived_filename_with_path) {
        $c->stash->{rest} = { error => "Could not save file $upload_geojson_original_name in archive." };
        $c->detach();
    }
    unlink $upload_geojson_tempfile;
    print STDERR "Archived Drone Image Bulk Previous GeoJSON Zip File: $geojson_archived_filename_with_path\n";

    my $archived_zip_geojson = CXGN::ZipFile->new(archived_zipfile_path=>$geojson_archived_filename_with_path);
    my $file_members_geojson = $archived_zip_geojson->file_members();
    if (!$file_members_geojson){
        $c->stash->{rest} = {error => 'Could not read your geojson bulk zipfile. Is it .zip format?</br></br>'};
        $c->detach;
    }

    my %filename_imaging_event_geojson_lookup;
    foreach (@$file_members_geojson) {
        my $image = SGN::Image->new( $dbh, undef, $c );
        my $filename = $_->fileName();
        my $temp_file = $image->upload_zipfile_images($_);

        my @zipfile_comp = split '\/', $filename;
        my $filename_wext;
        if (scalar(@zipfile_comp) == 1) {
            $filename_wext = $zipfile_comp[0];
        }
        else {
            $filename_wext = $zipfile_comp[1];
        }

        print STDERR Dumper [$filename, $temp_file, $filename_wext];
        $filename_imaging_event_geojson_lookup{$filename_wext} = $temp_file;

        open(my $fh_geojson_check, '<', $temp_file) or die "Could not open file '$temp_file' $!";
            print STDERR "Opened $temp_file\n";
            my $geojson_value_check = decode_json <$fh_geojson_check>;
            # print STDERR Dumper $geojson_value_check;
            if (!$geojson_value_check->{features}) {
                $c->stash->{rest} = {error => 'The GeoJSON file '.$filename.' does not have a \'features\' key in it. Make sure the GeoJSON is formatted correctly.</br></br>'};
                $c->detach;
            }
            foreach (@{$geojson_value_check->{features}}) {
                if (!$_->{properties}) {
                    $c->stash->{rest} = {error => 'The GeoJSON file '.$filename.' does not have a \'properties\' key in it. Make sure the GeoJSON is formatted correctly.</br></br>'};
                    $c->detach;
                }
                if (!$_->{properties}->{ID}) {
                    $c->stash->{rest} = {error => 'The GeoJSON file '.$filename.' does not have an \'ID\' key in the \'properties\' object. Make sure the GeoJSON is formatted correctly.</br></br>'};
                    $c->detach;
                }
                if (!$_->{geometry}) {
                    $c->stash->{rest} = {error => 'The GeoJSON file '.$filename.' does not have a \'geometry\' key in it. Make sure the GeoJSON is formatted correctly.</br></br>'};
                    $c->detach;
                }
                if (!$_->{geometry}->{coordinates}) {
                    $c->stash->{rest} = {error => 'The GeoJSON file '.$filename.' does not have a \'coordinates\' key in the \'geometry\' object. Make sure the GeoJSON is formatted correctly.</br></br>'};
                    $c->detach;
                }
                if (scalar(@{$_->{geometry}->{coordinates}->[0]}) != 5) {
                    $c->stash->{rest} = {error => 'The GeoJSON file '.$filename.' \'coordinates\' first object has less than 4 objects in it. The polygons must be rectangular Make sure the GeoJSON is formatted correctly.</br></br>'};
                    $c->detach;
                }
            }
        close($fh_geojson_check);
    }

    my @parse_csv_errors;
    my %field_trial_name_lookup;
    my %field_trial_layout_lookup;
    my %vehicle_name_lookup;

    my $parser = Spreadsheet::ParseExcel->new();
    my $excel_obj = $parser->parse($upload_imaging_events_file);
    if (!$excel_obj) {
        $c->stash->{rest} = {error => 'The Excel (.xls) file could not be opened:'.$parser->error().'.</br></br>'};
        $c->detach;
    }

    my $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
    if (!$worksheet) {
        $c->stash->{rest} = {error => 'Spreadsheet must be on 1st tab in Excel (.xls) file.</br></br>'};
        $c->detach;
    }
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();
    if (($col_max - $col_min)  < 1 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of plot data
        $c->stash->{rest} = {error => 'Spreadsheet (.xls) is missing header or contains no rows.</br></br>'};
        $c->detach;
    }

    if ($worksheet->get_cell(0,0)->value() ne 'Imaging Event Name' ||
        $worksheet->get_cell(0,1)->value() ne 'Type' ||
        $worksheet->get_cell(0,2)->value() ne 'Description' ||
        $worksheet->get_cell(0,3)->value() ne 'Date' ||
        $worksheet->get_cell(0,4)->value() ne 'Vehicle Name' ||
        $worksheet->get_cell(0,5)->value() ne 'Vehicle Battery Set' ||
        $worksheet->get_cell(0,6)->value() ne 'Sensor' ||
        $worksheet->get_cell(0,7)->value() ne 'Field Trial Name' ||
        $worksheet->get_cell(0,8)->value() ne 'GeoJSON Filename' ||
        $worksheet->get_cell(0,9)->value() ne 'Image Filenames' ||
        $worksheet->get_cell(0,10)->value() ne 'Coordinate System' ||
        $worksheet->get_cell(0,11)->value() ne 'Rotation Angle' ||
        $worksheet->get_cell(0,12)->value() ne 'Base Date' ||
        $worksheet->get_cell(0,13)->value() ne 'Camera Rig') {
            $c->stash->{rest} = {error => "The header row in the CSV spreadsheet must be 'Imaging Event Name,Type,Description,Date,Vehicle Name,Vehicle Battery Set,Sensor,Field Trial Name,GeoJSON Filename,Image Filenames,Coordinate System,Rotation Angle,Base Date,Camera Rig'." };
            $c->detach;
    }

    my %seen_upload_dates;
    for my $row ( 1 .. $row_max ) {
        my $imaging_event_name;
        if ($worksheet->get_cell($row,0)) {
            $imaging_event_name = $worksheet->get_cell($row,0)->value();
        }
        my $imaging_event_type;
        if ($worksheet->get_cell($row,1)) {
            $imaging_event_type = $worksheet->get_cell($row,1)->value();
        }
        my $imaging_event_desc;
        if ($worksheet->get_cell($row,2)) {
            $imaging_event_desc = $worksheet->get_cell($row,2)->value();
        }
        my $imaging_event_date;
        if ($worksheet->get_cell($row,3)) {
            $imaging_event_date = $worksheet->get_cell($row,3)->value();
        }
        my $vehicle_name;
        if ($worksheet->get_cell($row,4)) {
            $vehicle_name = $worksheet->get_cell($row,4)->value();
        }
        my $vehicle_battery = 'default_battery';
        if ($worksheet->get_cell($row,5)) {
            $vehicle_battery = $worksheet->get_cell($row,5)->value();
        }
        my $sensor;
        if ($worksheet->get_cell($row,6)) {
            $sensor = $worksheet->get_cell($row,6)->value();
        }
        my $field_trial_name;
        if ($worksheet->get_cell($row,7)) {
            $field_trial_name = $worksheet->get_cell($row,7)->value();
        }
        my $geojson_filename;
        if ($worksheet->get_cell($row,8)) {
            $geojson_filename = $worksheet->get_cell($row,8)->value();
        }
        my $image_filenames;
        if ($worksheet->get_cell($row,9)) {
            $image_filenames = $worksheet->get_cell($row,9)->value();
        }
        my $coordinate_system;
        if ($worksheet->get_cell($row,10)) {
            $coordinate_system = $worksheet->get_cell($row,10)->value();
        }
        my $rotation_angle;
        if ($worksheet->get_cell($row,11)) {
            $rotation_angle = $worksheet->get_cell($row,11)->value();
        }
        my $base_date;
        if ($worksheet->get_cell($row,12)) {
            $base_date = $worksheet->get_cell($row,12)->value();
        }
        my $rig_desc;
        if ($worksheet->get_cell($row,13)) {
            $rig_desc = $worksheet->get_cell($row,13)->value();
        }

        if (!$imaging_event_name){
            push @parse_csv_errors, "Please give a new imaging event name!";
        }
        if (!$imaging_event_type){
            push @parse_csv_errors, "Please give an imaging event type!";
        }
        if (!$imaging_event_desc){
            push @parse_csv_errors, "Please give an imaging event description!";
        }
        if (!$imaging_event_date){
            push @parse_csv_errors, "Please give an imaging event date!";
        }
        if (!$vehicle_name){
            push @parse_csv_errors, "Please give a vehicle name!";
        }
        if (!$sensor){
            push @parse_csv_errors, "Please give a sensor name!";
        }
        if (!$field_trial_name){
            push @parse_csv_errors, "Please give a field trial name!";
        }
        if (defined($rotation_angle) && ($rotation_angle < 0 || $rotation_angle > 360) ) {
            push @parse_csv_errors, "Rotation angle $rotation_angle not valid! Must be clock-wise between 0 and 360!";
        }

        if ($coordinate_system ne 'UTM' && $coordinate_system ne 'WGS84' && $coordinate_system ne 'Pixels') {
            push @parse_csv_errors, "The given coordinate system $coordinate_system is not one of: UTM, WGS84, or Pixels!";
        }
        # if ($coordinate_system ne 'Pixels') {
        #     $c->stash->{rest} = {error => "Only the Pixels coordinate system is currently supported. In the future GeoTIFFs will be supported, but for now please only upload simple raster images (.png, .tiff, .jpg)." };
        #     $c->detach;
        # }

        my $field_trial_rs = $schema->resultset("Project::Project")->search({name=>$field_trial_name});
        if ($field_trial_rs->count != 1) {
            $c->stash->{rest} = {error => "The field trial $field_trial_name does not exist in the database already! Please add it first." };
            $c->detach;
        }
        my $field_trial_id = $field_trial_rs->first->project_id();
        $field_trial_name_lookup{$field_trial_name} = $field_trial_id;

        if ($imaging_event_date !~ /^\d{4}\/\d{2}\/\d{2}\s\d\d:\d\d:\d\d$/){
            $c->stash->{rest} = {error => "Please give a new imaging event date in the format YYYY/MM/DD HH:mm:ss! The provided $imaging_event_date is not correct!" };
            $c->detach;
        }
        if ($imaging_event_type ne 'Aerial Medium to High Res' && $imaging_event_type ne 'Aerial Low Res'){
            $c->stash->{rest} = {error => "The imaging event type $imaging_event_type is not one of 'Aerial Low Res' or 'Aerial Medium to High Res'!" };
            $c->detach;
        }
        if (!exists($sensor_map{$sensor})){
            $c->stash->{rest} = {error => "The sensor $sensor is not one of 'MicaSense 5 Channel Camera' or 'CCD Color Camera' or 'CMOS Color Camera'!" };
            $c->detach;
        }

        my $project_rs = $schema->resultset("Project::Project")->search({name=>$imaging_event_name});
        if ($project_rs->count > 0) {
            push @parse_csv_errors, "Please use a globally unique imaging event name! The name you specified $imaging_event_name has already been used.";
        }
        my $vehicle_prop = $schema->resultset("Stock::Stock")->search({uniquename => $vehicle_name, type_id=>$imaging_vehicle_cvterm_id});
        if ($vehicle_prop->count != 1) {
            push @parse_csv_errors, "Imaging event vehicle $vehicle_name is not already in the database! Please add it first!";
        }
        else {
            $vehicle_name_lookup{$vehicle_name} = $vehicle_prop->first->stock_id;
        }

        my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $field_trial_id });
        my $trial_layout = $trial->get_layout()->get_design();
        $field_trial_layout_lookup{$field_trial_id} = $trial_layout;

        my $planting_date = $trial->get_planting_date();
        if (!$planting_date) {
            $c->stash->{rest} = {error => "The field trial $field_trial_name does not have a planting date set! Please set this first!" };
            $c->detach;
        }
        my $planting_date_time_object = Time::Piece->strptime($planting_date, "%Y-%B-%d");
        my $imaging_event_date_time_object = Time::Piece->strptime($imaging_event_date, "%Y/%m/%d %H:%M:%S");

        if (exists($seen_field_trial_drone_run_dates{$imaging_event_date_time_object->epoch})) {
            $c->stash->{rest} = { error => "An imaging event has already occured on this field trial at the same date and time ($imaging_event_date)! Please give a unique date/time for each imaging event!" };
            $c->detach();
        }
        $seen_field_trial_drone_run_dates{$imaging_event_date_time_object->epoch}++;

        if ($imaging_event_date_time_object->epoch - $planting_date_time_object->epoch <= 0) {
            push @parse_csv_errors, "The date of the imaging event $imaging_event_date is not after the field trial planting date $planting_date!";
        }
        if ($base_date) {
            if ($base_date !~ /^\d{4}\/\d{2}\/\d{2}\s\d\d:\d\d:\d\d$/){
                $c->stash->{rest} = {error => "Please give a new imaging event base date in the format YYYY/MM/DD HH:mm:ss! The provided $base_date is not correct! Leave empty if not relevant!" };
                $c->detach;
            }
            my $imaging_event_base_time_object = Time::Piece->strptime($base_date, "%Y/%m/%d %H:%M:%S");

            if ($imaging_event_date_time_object->epoch - $imaging_event_base_time_object->epoch < 0) {
                push @parse_csv_errors, "The date of the imaging event $imaging_event_date is not after the base date $base_date!";
            }
        }

        my @orthoimage_names = split ',', $image_filenames;
        foreach (@orthoimage_names) {
            if (!exists($filename_imaging_event_lookup{$_})) {
                push @parse_csv_errors, "The orthophoto filename $_ does not exist in the uploaded orthophoto zipfile. Make sure the orthophotos are saved as a concatenation of the ortho filename defined in the spreadsheet and the spectral band, with a double-underscore (__) as the separator (e.g. Ortho1_01012020__blue.tiff)";
            }
        }
        if (!exists($filename_imaging_event_geojson_lookup{$geojson_filename})) {
            push @parse_csv_errors, "The GeoJSON filename $geojson_filename does not exist in the uploaded GeoJSON zipfile!";
        }
        open(my $fh_geojson_check, '<', $filename_imaging_event_geojson_lookup{$geojson_filename}) or die "Could not open file '".$filename_imaging_event_geojson_lookup{$geojson_filename}."' $!";
            print STDERR "Opened ".$filename_imaging_event_geojson_lookup{$geojson_filename}."\n";
            my $geojson_value_check = decode_json <$fh_geojson_check>;
            foreach (@{$geojson_value_check->{features}}) {
                my $plot_number = $_->{properties}->{ID};
                if (!exists($trial_layout->{$plot_number})) {
                    push @parse_csv_errors, "The ID $plot_number in the GeoJSON file $geojson_filename does not exist in the field trial $field_trial_name!";
                }
            }
        close($fh_geojson_check);
    }

    if (scalar(@parse_csv_errors) > 0) {
        my $error_string = join "<br/>", @parse_csv_errors;
        $c->stash->{rest} = {error_string => $error_string };
        $c->detach;
    }

    my $dir = $c->tempfiles_subdir('/upload_drone_imagery_bulk_previous');

    my @drone_run_project_ids;
    my @drone_run_projects;
    my %drone_run_project_info;
    for my $row ( 1 .. $row_max ) {
        my $imaging_event_name = $worksheet->get_cell($row,0)->value();
        my $imaging_event_type = $worksheet->get_cell($row,1)->value();
        my $imaging_event_desc = $worksheet->get_cell($row,2)->value();
        my $imaging_event_date = $worksheet->get_cell($row,3)->value();
        my $vehicle_name = $worksheet->get_cell($row,4)->value();
        my $vehicle_battery = $worksheet->get_cell($row,5) ? $worksheet->get_cell($row,5)->value() : 'default_battery';
        my $sensor = $worksheet->get_cell($row,6)->value();
        my $field_trial_name = $worksheet->get_cell($row,7)->value();
        my $geojson_filename = $worksheet->get_cell($row,8)->value();
        my $image_filenames = $worksheet->get_cell($row,9)->value();
        my $coordinate_system = $worksheet->get_cell($row,10)->value();
        my $rotation_angle = $worksheet->get_cell($row,11) ? $worksheet->get_cell($row,11)->value() : 0;
        my $base_date = $worksheet->get_cell($row,12) ? $worksheet->get_cell($row,12)->value() : '';
        my $rig_desc = $worksheet->get_cell($row,13) ? $worksheet->get_cell($row,13)->value() : '';

        my $new_drone_run_vehicle_id = $vehicle_name_lookup{$vehicle_name};
        my $selected_trial_id = $field_trial_name_lookup{$field_trial_name};
        my $new_drone_run_camera_info = $sensor_map{$sensor};
        my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $selected_trial_id });
        my $trial_location_id = $trial->get_location()->[0];
        my $planting_date = $trial->get_planting_date();
        my $planting_date_time_object = Time::Piece->strptime($planting_date, "%Y-%B-%d");
        my $imaging_event_date_time_object = Time::Piece->strptime($imaging_event_date, "%Y/%m/%d %H:%M:%S");
        my $drone_run_event = $calendar_funcs->check_value_format($imaging_event_date);
        my $time_diff;
        my $base_date_event;
        if ($base_date) {
            my $imaging_event_base_date_time_object = Time::Piece->strptime($base_date, "%Y/%m/%d %H:%M:%S");
            $time_diff = $imaging_event_date_time_object - $imaging_event_base_date_time_object;
            $base_date_event = $calendar_funcs->check_value_format($base_date);
        }
        else {
            $time_diff = $imaging_event_date_time_object - $planting_date_time_object;
        }
        my $time_diff_weeks = $time_diff->weeks;
        my $time_diff_days = $time_diff->days;
        my $time_diff_hours = $time_diff->hours;
        my $rounded_time_diff_weeks = round($time_diff_weeks);
        if ($rounded_time_diff_weeks == 0) {
            $rounded_time_diff_weeks = 1;
        }

        my $week_term_string = "week $rounded_time_diff_weeks";
        my $q = "SELECT t.cvterm_id FROM cvterm as t JOIN cv ON(t.cv_id=cv.cv_id) WHERE t.name=? and cv.name=?;";
        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute($week_term_string, 'cxgn_time_ontology');
        my ($week_cvterm_id) = $h->fetchrow_array();

        if (!$week_cvterm_id) {
            my $new_week_term = $schema->resultset("Cv::Cvterm")->create_with({
               name => $week_term_string,
               cv => 'cxgn_time_ontology'
            });
            $week_cvterm_id = $new_week_term->cvterm_id();
        }

        my $day_term_string = "day $time_diff_days";
        $h->execute($day_term_string, 'cxgn_time_ontology');
        my ($day_cvterm_id) = $h->fetchrow_array();

        if (!$day_cvterm_id) {
            my $new_day_term = $schema->resultset("Cv::Cvterm")->create_with({
               name => $day_term_string,
               cv => 'cxgn_time_ontology'
            });
            $day_cvterm_id = $new_day_term->cvterm_id();
        }

        my $week_term = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $week_cvterm_id, 'extended');
        my $day_term = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $day_cvterm_id, 'extended');

        my %related_cvterms = (
            week => $week_term,
            day => $day_term
        );

        my $drone_run_projectprops = [
            {type_id => $drone_run_type_cvterm_id, value => $imaging_event_type},
            {type_id => $project_start_date_type_id, value => $drone_run_event},
            {type_id => $design_cvterm_id, value => 'drone_run'},
            {type_id => $drone_run_camera_type_cvterm_id, value => $new_drone_run_camera_info},
            {type_id => $drone_run_related_cvterms_cvterm_id, value => encode_json \%related_cvterms}
        ];
        if ($base_date) {
            push @$drone_run_projectprops, {type_id => $drone_run_base_date_type_id, value => $base_date_event};
        }
        if ($rig_desc) {
            push @$drone_run_projectprops, {type_id => $drone_run_rig_desc_type_id, value => $rig_desc};
        }

        my $nd_experiment_rs = $schema->resultset("NaturalDiversity::NdExperiment")->create({
            nd_geolocation_id => $trial_location_id,
            type_id => $drone_run_experiment_type_id,
            nd_experiment_stocks => [{stock_id => $new_drone_run_vehicle_id, type_id => $drone_run_experiment_type_id}]
        });
        my $drone_run_nd_experiment_id = $nd_experiment_rs->nd_experiment_id();

        my $project_rs = $schema->resultset("Project::Project")->create({
            name => $imaging_event_name,
            description => $imaging_event_desc,
            projectprops => $drone_run_projectprops,
            project_relationship_subject_projects => [{type_id => $project_relationship_type_id, object_project_id => $selected_trial_id}],
            nd_experiment_projects => [{nd_experiment_id => $drone_run_nd_experiment_id}]
        });
        my $selected_drone_run_id = $project_rs->project_id();
        push @drone_run_project_ids, $selected_drone_run_id;

        my $vehicle_prop = decode_json $schema->resultset("Stock::Stockprop")->search({stock_id => $new_drone_run_vehicle_id, type_id=>$imaging_vehicle_properties_cvterm_id})->first()->value();
        $vehicle_prop->{batteries}->{$vehicle_battery}->{usage}++;
        my $vehicle_prop_update = $schema->resultset('Stock::Stockprop')->update_or_create({
            type_id=>$imaging_vehicle_properties_cvterm_id,
            stock_id=>$new_drone_run_vehicle_id,
            rank=>0,
            value=>encode_json $vehicle_prop
        },
        {
            key=>'stockprop_c1'
        });

        my @orthoimage_names = split ',', $image_filenames;
        my @ortho_images;
        foreach (@orthoimage_names) {
            push @ortho_images, $filename_imaging_event_lookup{$_};
        }
        my @drone_run_band_projects;
        my @drone_run_band_project_ids;
        my @drone_run_band_geoparams_coordinates;
        foreach my $m (@ortho_images) {
            my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
            my $band = $m->{band};
            my $band_short = $m->{band_short};
            my $file = $m->{file};

            my $time = DateTime->now();
            my $timestamp = $time->ymd()."_".$time->hms();
            my $upload_original_name = $imaging_event_name."_".$band_short.".png";

            my $ortho_file;
            my @geoparams_coordinates;
            if ($coordinate_system eq 'Pixels') {
                $ortho_file = $file;
            }
            else {
                if ($band_short eq 'rgb') {
                    my $outfile_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_bulk_previous/imageXXXX').".png";
                    my $outfile_image_r = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_bulk_previous/imageXXXX').".png";
                    my $outfile_image_g = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_bulk_previous/imageXXXX').".png";
                    my $outfile_image_b = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_bulk_previous/imageXXXX').".png";
                    my $outfile_geoparams = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_bulk_previous/fileXXXX').".csv";

                    my $geo_cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/GDALOpenImageRGBGeoTiff.py --image_path $file --outfile_path_image $outfile_image --outfile_path_image_1 $outfile_image_r --outfile_path_image_2 $outfile_image_g --outfile_path_image_3 $outfile_image_b --outfile_path_geo_params $outfile_geoparams ";
                    print STDERR $geo_cmd."\n";
                    my $geo_cmd_status = system($geo_cmd);
                    $ortho_file = $outfile_image;

                    open(my $fh_geoparams, '<', $outfile_geoparams) or die "Could not open file '".$outfile_geoparams."' $!";
                        print STDERR "Opened ".$outfile_geoparams."\n";
                        my $geoparams = <$fh_geoparams>;
                        chomp $geoparams;
                        @geoparams_coordinates = split ',', $geoparams;
                        print STDERR Dumper [$geoparams, \@geoparams_coordinates];
                    close($fh_geoparams);
                }
                else {
                    my $outfile_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_bulk_previous/imageXXXX').".png";
                    my $outfile_geoparams = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_bulk_previous/fileXXXX').".csv";

                    my $geo_cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/GDALOpenSingleChannelImageGeoTiff.py --image_path $file --outfile_path_image $outfile_image --outfile_path_geo_params $outfile_geoparams ";
                    print STDERR $geo_cmd."\n";
                    my $geo_cmd_status = system($geo_cmd);
                    $ortho_file = $outfile_image;

                    open(my $fh_geoparams, '<', $outfile_geoparams) or die "Could not open file '".$outfile_geoparams."' $!";
                        print STDERR "Opened ".$outfile_geoparams."\n";
                        my $geoparams = <$fh_geoparams>;
                        chomp $geoparams;
                        @geoparams_coordinates = split ',', $geoparams;
                        print STDERR Dumper [$geoparams, \@geoparams_coordinates];
                    close($fh_geoparams);
                }
            }
            push @drone_run_band_geoparams_coordinates, \@geoparams_coordinates;

            my $project_rs = $schema->resultset("Project::Project")->create({
                name => $imaging_event_name."_".$band_short,
                description => $imaging_event_desc.". ".$band,
                projectprops => [
                    {type_id => $drone_run_band_type_cvterm_id, value => $band},
                    {type_id => $design_cvterm_id, value => 'drone_run_band'},
                    {type_id => $geoparam_coordinates_cvterm_id, value => encode_json \@geoparams_coordinates}
                ],
                project_relationship_subject_projects => [{type_id => $project_relationship_type_id, object_project_id => $selected_drone_run_id}]
            });
            my $selected_drone_run_band_id = $project_rs->project_id();

            my $uploader = CXGN::UploadFile->new({
                tempfile => $ortho_file,
                subdirectory => "drone_imagery_upload",
                archive_path => $c->config->{archive_path},
                archive_filename => $upload_original_name,
                timestamp => $timestamp,
                user_id => $user_id,
                user_role => $user_role
            });
            my $archived_filename_with_path = $uploader->archive();
            my $md5 = $uploader->get_md5($archived_filename_with_path);
            if (!$archived_filename_with_path) {
                $c->stash->{rest} = { error => "Could not save file $upload_original_name in archive." };
                $c->detach();
            }
            unlink $upload_tempfile;
            print STDERR "Archived Bulk Orthophoto File: $archived_filename_with_path\n";

            my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
            $image->set_sp_person_id($user_id);
            my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
            my $ret = $image->process_image($archived_filename_with_path, 'project', $selected_drone_run_band_id, $linking_table_type_id);

            push @drone_run_band_projects, {
                drone_run_band_project_id => $selected_drone_run_band_id,
                band => $band
            };
            push @drone_run_band_project_ids, $selected_drone_run_band_id;
        }

        my $geojson_temp_filename = $filename_imaging_event_geojson_lookup{$geojson_filename};
        push @drone_run_projects, {
            drone_run_project_id => $selected_drone_run_id,
            drone_run_band_projects => \@drone_run_band_projects,
            drone_run_band_project_ids => \@drone_run_band_project_ids,
            geojson_temp_filename => $geojson_temp_filename,
            time_cvterm_id => $day_cvterm_id,
            field_trial_id => $selected_trial_id,
            coordinate_system => $coordinate_system,
            drone_run_band_geoparams_coordinates => \@drone_run_band_geoparams_coordinates,
            rotation_angle => $rotation_angle
        };

        $drone_run_project_info{$selected_drone_run_id} = {
            name => $project_rs->name()
        };
    }

    my $vegetative_indices = ['VARI', 'TGI', 'NDRE', 'NDVI'];
    my $phenotype_methods = ['zonal'];
    my $standard_process_type = 'minimal';

    foreach (@drone_run_projects) {
        my $drone_run_project_id_in = $_->{drone_run_project_id};
        my $time_cvterm_id = $_->{time_cvterm_id};
        my $apply_drone_run_band_project_ids = $_->{drone_run_band_project_ids};
        my $geojson_filename = $_->{geojson_temp_filename};
        my $field_trial_id = $_->{field_trial_id};
        my $coordinate_system = $_->{coordinate_system};
        my $drone_run_band_geoparams_coordinates = $_->{drone_run_band_geoparams_coordinates};
        my $rotate_value = 0;

        my $drone_run_process_in_progress = $schema->resultset('Project::Projectprop')->update_or_create({
            type_id=>$process_indicator_cvterm_id,
            project_id=>$drone_run_project_id_in,
            rank=>0,
            value=>1
        },
        {
            key=>'projectprop_c1'
        });

        my $drone_run_process_completed = $schema->resultset('Project::Projectprop')->update_or_create({
            type_id=>$processed_cvterm_id,
            project_id=>$drone_run_project_id_in,
            rank=>0,
            value=>0
        },
        {
            key=>'projectprop_c1'
        });

        my $drone_run_process_minimal_vi_completed = $schema->resultset('Project::Projectprop')->update_or_create({
            type_id=>$processed_minimal_vi_cvterm_id,
            project_id=>$drone_run_project_id_in,
            rank=>0,
            value=>0
        },
        {
            key=>'projectprop_c1'
        });

        my %vegetative_indices_hash;
        foreach (@$vegetative_indices) {
            $vegetative_indices_hash{$_}++;
        }

        my $geojson_value;

        open(my $fh_geojson, '<', $geojson_filename) or die "Could not open file '$geojson_filename' $!";
            print STDERR "Opened $geojson_filename\n";
            $geojson_value = decode_json <$fh_geojson>;
        close($fh_geojson);

        my $trial_lookup = $field_trial_layout_lookup{$field_trial_id};

        my %selected_drone_run_band_types;
        my $q2 = "SELECT project_md_image.image_id, drone_run_band_type.value, drone_run_band.project_id
            FROM project AS drone_run_band
            JOIN projectprop AS drone_run_band_type ON(drone_run_band_type.project_id = drone_run_band.project_id AND drone_run_band_type.type_id = $drone_run_band_type_type_id)
            JOIN phenome.project_md_image AS project_md_image ON(project_md_image.project_id = drone_run_band.project_id)
            JOIN metadata.md_image ON(project_md_image.image_id = metadata.md_image.image_id)
            WHERE project_md_image.type_id = $project_image_type_id
            AND drone_run_band.project_id = ?
            AND metadata.md_image.obsolete = 'f';";

        my $h2 = $schema->storage->dbh()->prepare($q2);

        my $term_map = CXGN::DroneImagery::ImageTypes::get_base_imagery_observation_unit_plot_polygon_term_map();

        my %drone_run_band_info;
        my $drone_run_band_counter = 0;
        foreach my $apply_drone_run_band_project_id (@$apply_drone_run_band_project_ids) {

            my $plot_polygons_value;
            foreach (@{$geojson_value->{features}}) {
                my $plot_number = $_->{properties}->{ID};
                my $coordinates = $_->{geometry}->{coordinates};
                my $stock_name = $trial_lookup->{$plot_number}->{plot_name};
                my @coords;
                foreach my $crd (@{$coordinates->[0]}) {
                    if ($coordinate_system eq 'Pixels') {
                        push @coords, {
                            x => $crd->[0],
                            y => $crd->[1],
                        };
                    }
                    else {
                        my $geocoords = $drone_run_band_geoparams_coordinates->[$drone_run_band_counter];
                        my $xOrigin = $geocoords->[0];
                        my $yOrigin = $geocoords->[3];
                        my $pixelWidth = $geocoords->[1];
                        my $pixelHeight = -1*$geocoords->[5];
                        my $x_pos = round(($crd->[0] - $xOrigin) / $pixelWidth);
                        my $y_pos = round(($yOrigin - $crd->[1] ) / $pixelHeight);
                        push @coords, {
                            x => $x_pos,
                            y => $y_pos,
                        };
                    }
                }
                my $last_point = pop @coords;
                $plot_polygons_value->{$stock_name} = \@coords;
            }
            $plot_polygons_value = encode_json $plot_polygons_value;

            my $h2 = $schema->storage->dbh()->prepare($q2);
            $h2->execute($apply_drone_run_band_project_id);
            my ($image_id, $drone_run_band_type, $drone_run_band_project_id) = $h2->fetchrow_array();
            $selected_drone_run_band_types{$drone_run_band_type} = $drone_run_band_project_id;

            my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
            my $image_fullpath = $image->get_filename('original_converted', 'full');

            my @size = imgsize($image_fullpath);
            my $width = $size[0];
            my $length = $size[1];

            my $cropping_value = encode_json [[{x=>0, y=>0}, {x=>$width, y=>0}, {x=>$width, y=>$length}, {x=>0, y=>$length}]];

            my $apply_image_width_ratio = 1;
            my $apply_image_height_ratio = 1;

            my $dir = $c->tempfiles_subdir('/drone_imagery_rotate');
            my $archive_rotate_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_rotate/imageXXXX');
            $archive_rotate_temp_image .= '.png';

            my $rotate_return = SGN::Controller::AJAX::DroneImagery::DroneImagery::_perform_image_rotate($c, $schema, $metadata_schema, $drone_run_band_project_id, $image_id, $rotate_value, 0, $user_id, $user_name, $user_role, $archive_rotate_temp_image, 0, 0);
            my $rotated_image_id = $rotate_return->{rotated_image_id};

            $dir = $c->tempfiles_subdir('/drone_imagery_cropped_image');
            my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_cropped_image/imageXXXX');
            $archive_temp_image .= '.png';

            my $cropping_return = SGN::Controller::AJAX::DroneImagery::DroneImagery::_perform_image_cropping($c, $schema, $drone_run_band_project_id, $rotated_image_id, $cropping_value, $user_id, $user_name, $user_role, $archive_temp_image, $apply_image_width_ratio, $apply_image_height_ratio);
            my $cropped_image_id = $cropping_return->{cropped_image_id};

            $dir = $c->tempfiles_subdir('/drone_imagery_denoise');
            my $archive_denoise_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_denoise/imageXXXX');
            $archive_denoise_temp_image .= '.png';

            my $denoise_return = SGN::Controller::AJAX::DroneImagery::DroneImagery::_perform_image_denoise($c, $schema, $metadata_schema, $cropped_image_id, $drone_run_band_project_id, $user_id, $user_name, $user_role, $archive_denoise_temp_image);
            my $denoised_image_id = $denoise_return->{denoised_image_id};

            $drone_run_band_info{$drone_run_band_project_id} = {
                denoised_image_id => $denoised_image_id,
                rotate_value => $rotate_value,
                cropping_value => $cropping_value,
                drone_run_band_type => $drone_run_band_type,
                drone_run_project_id => $drone_run_project_id_in,
                drone_run_project_name => $drone_run_project_info{$drone_run_project_id_in}->{name},
                plot_polygons_value => $plot_polygons_value
            };

            my @denoised_plot_polygon_type = @{$term_map->{$drone_run_band_type}->{observation_unit_plot_polygon_types}->{base}};
            my @denoised_background_threshold_removed_imagery_types = @{$term_map->{$drone_run_band_type}->{imagery_types}->{threshold_background}};
            my @denoised_background_threshold_removed_plot_polygon_types = @{$term_map->{$drone_run_band_type}->{observation_unit_plot_polygon_types}->{threshold_background}};

            foreach (@denoised_plot_polygon_type) {
                my $plot_polygon_original_denoised_return = SGN::Controller::AJAX::DroneImagery::DroneImagery::_perform_plot_polygon_assign($c, $schema, $metadata_schema, $denoised_image_id, $drone_run_band_project_id, $plot_polygons_value, $_, $user_id, $user_name, $user_role, 0, 0, $apply_image_width_ratio, $apply_image_height_ratio, 'rectangular_polygon');
            }

            for my $iterator (0..(scalar(@denoised_background_threshold_removed_imagery_types)-1)) {
                $dir = $c->tempfiles_subdir('/drone_imagery_remove_background');
                my $archive_remove_background_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_remove_background/imageXXXX');
                $archive_remove_background_temp_image .= '.png';

                my $background_removed_threshold_return = SGN::Controller::AJAX::DroneImagery::DroneImagery::_perform_image_background_remove_threshold_percentage($c, $schema, $denoised_image_id, $drone_run_band_project_id, $denoised_background_threshold_removed_imagery_types[$iterator], '25', '25', $user_id, $user_name, $user_role, $archive_remove_background_temp_image);

                my $plot_polygon_return = SGN::Controller::AJAX::DroneImagery::DroneImagery::_perform_plot_polygon_assign($c, $schema, $metadata_schema, $background_removed_threshold_return->{removed_background_image_id}, $drone_run_band_project_id, $plot_polygons_value, $denoised_background_threshold_removed_plot_polygon_types[$iterator], $user_id, $user_name, $user_role, 0, 0, $apply_image_width_ratio, $apply_image_height_ratio, 'rectangular_polygon');
            }

            $drone_run_band_counter++;
        }

        print STDERR Dumper \%selected_drone_run_band_types;
        print STDERR Dumper \%vegetative_indices_hash;

        SGN::Controller::AJAX::DroneImagery::DroneImagery::_perform_minimal_vi_standard_process($c, $schema, $metadata_schema, \%vegetative_indices_hash, \%selected_drone_run_band_types, \%drone_run_band_info, $user_id, $user_name, $user_role, 'rectangular_polygon');

        $drone_run_process_in_progress = $schema->resultset('Project::Projectprop')->update_or_create({
            type_id=>$process_indicator_cvterm_id,
            project_id=>$drone_run_project_id_in,
            rank=>0,
            value=>0
        },
        {
            key=>'projectprop_c1'
        });

        $drone_run_process_completed = $schema->resultset('Project::Projectprop')->update_or_create({
            type_id=>$processed_cvterm_id,
            project_id=>$drone_run_project_id_in,
            rank=>0,
            value=>1
        },
        {
            key=>'projectprop_c1'
        });

        $drone_run_process_minimal_vi_completed = $schema->resultset('Project::Projectprop')->update_or_create({
            type_id=>$processed_minimal_vi_cvterm_id,
            project_id=>$drone_run_project_id_in,
            rank=>0,
            value=>1
        },
        {
            key=>'projectprop_c1'
        });

        my $return = SGN::Controller::AJAX::DroneImagery::DroneImagery::_perform_phenotype_automated($c, $schema, $metadata_schema, $phenome_schema, $drone_run_project_id_in, $time_cvterm_id, $phenotype_methods, $standard_process_type, 1, undef, $user_id, $user_name, $user_role);
    }

    $c->stash->{rest} = { success => 1, drone_run_project_ids => \@drone_run_project_ids, drone_run_bands => \@drone_run_projects };
}

sub upload_drone_imagery_new_vehicle : Path('/api/drone_imagery/new_imaging_vehicle') : ActionClass('REST') { }
sub upload_drone_imagery_new_vehicle_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    $c->response->headers->header( "Access-Control-Allow-Origin" => '*' );
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    my $vehicle_name = $c->req->param('vehicle_name');
    my $vehicle_desc = $c->req->param('vehicle_description');
    my $battery_names_string = $c->req->param('battery_names');
    my @battery_names = split ',', $battery_names_string;

    my $vehicle_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'imaging_event_vehicle', 'stock_type')->cvterm_id();
    my $vehicle_prop_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'imaging_event_vehicle_json', 'stock_property')->cvterm_id();

    my $v_check = $schema->resultset("Stock::Stock")->find({uniquename => $vehicle_name});
    if ($v_check) {
        $c->stash->{rest} = {error => "Vehicle name $vehicle_name is already in use!"};
        $c->detach();
    }

    my %vehicle_prop;
    foreach (@battery_names) {
        $vehicle_prop{batteries}->{$_} = {
            usage => 0,
            obsolete => 0
        };
    }

    my $new_vehicle = $schema->resultset("Stock::Stock")->create({
        uniquename => $vehicle_name,
        name => $vehicle_name,
        description => $vehicle_desc,
        type_id => $vehicle_cvterm_id,
        stockprops => [{type_id => $vehicle_prop_cvterm_id, value => encode_json \%vehicle_prop}]
    });
    my $new_vehicle_id = $new_vehicle->stock_id();

    $c->stash->{rest} = {success => 1, new_vehicle_id => $new_vehicle_id};
}

sub _check_user_login {
    my $c = shift;
    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to do this!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to do this!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }
    return ($user_id, $user_name, $user_role);
}

1;
