
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
our $VERSION = '0.01';
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
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
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
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema", undef, $sp_person_id);
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema", undef, $sp_person_id);
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

sub upload_drone_imagery_new_vehicle : Path('/api/drone_imagery/new_imaging_vehicle') : ActionClass('REST') { }
sub upload_drone_imagery_new_vehicle_GET : Args(0) {
    my $self = shift;
    my $c = shift;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id);
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
