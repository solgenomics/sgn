
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
use SGN::Image;
use CXGN::DroneImagery::ImagesSearch;
use File::Basename qw | basename dirname|;
use URI::Encode qw(uri_encode uri_decode);
use CXGN::Calendar;
use Image::Size;
use CXGN::DroneImagery::ImageTypes;
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
    my $new_drone_run_desc = $c->req->param('drone_run_description');
    my $new_drone_run_vehicle_id = $c->req->param('drone_run_imaging_vehicle_id');
    my $new_drone_run_battery_name = $c->req->param('drone_run_imaging_vehicle_battery_name');

    if (!$new_drone_run_vehicle_id) {
        $c->stash->{rest} = { error => "Please give an imaging event vehicle id!" };
        $c->detach();
    }

    if (!$selected_drone_run_id && !$new_drone_run_name) {
        $c->stash->{rest} = { error => "Please select a drone run or create a new drone run!" };
        $c->detach();
    }
    # if ($selected_drone_run_id && $new_drone_run_name){
    #     $c->stash->{rest} = { error => "Please select a drone run OR create a new drone run, not both!" };
    #     $c->detach();
    # }
    if ($new_drone_run_name && !$new_drone_run_type){
        $c->stash->{rest} = { error => "Please give a new drone run type!" };
        $c->detach();
    }
    if ($new_drone_run_name && !$new_drone_run_date){
        $c->stash->{rest} = { error => "Please give a new drone run date!" };
        $c->detach();
    }
    if ($new_drone_run_name && $new_drone_run_date !~ /^\d{4}\/\d{2}\/\d{2}\s\d\d:\d\d:\d\d$/){
        $c->stash->{rest} = { error => "Please give a new drone run date in the format YYYY/MM/DD HH:mm:ss!" };
        $c->detach();
    }
    if ($new_drone_run_name && !$new_drone_run_desc){
        $c->stash->{rest} = { error => "Please give a new drone run description!" };
        $c->detach();
    }

    my $new_drone_run_camera_info = $c->req->param('drone_image_upload_camera_info');
    my $new_drone_run_band_numbers = $c->req->param('drone_run_band_number');
    my $new_drone_run_band_stitching = $c->req->param('drone_image_upload_drone_run_band_stitching');

    if (!$new_drone_run_camera_info) {
        $c->stash->{rest} = { error => "Please indicate the type of camera!" };
        $c->detach();
    }

    if ($new_drone_run_band_stitching eq 'no' && !$new_drone_run_band_numbers) {
        $c->stash->{rest} = { error => "Please give the number of new drone run bands!" };
        $c->detach();
    }
    if (!$new_drone_run_band_stitching) {
        $c->stash->{rest} = { error => "Please indicate if the images are stitched!" };
        $c->detach();
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
        my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $selected_trial_id });
        my $trial_location_id = $trial->get_location()->[0];
        my $planting_date = $trial->get_planting_date();
        my $planting_date_time_object = Time::Piece->strptime($planting_date, "%Y-%B-%d");
        my $drone_run_date_time_object = Time::Piece->strptime($new_drone_run_date, "%Y/%m/%d %H:%M:%S");
        my $time_diff = $drone_run_date_time_object - $planting_date_time_object;
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

        my $calendar_funcs = CXGN::Calendar->new({});
        my $drone_run_event = $calendar_funcs->check_value_format($new_drone_run_date);
        my $drone_run_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_experiment', 'experiment_type')->cvterm_id();
        my $project_start_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_start_date', 'project_property')->cvterm_id();
        my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property')->cvterm_id();
        my $drone_run_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_project_type', 'project_property')->cvterm_id();
        my $drone_run_is_raw_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_is_raw_images', 'project_property')->cvterm_id();
        my $drone_run_camera_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_camera_type', 'project_property')->cvterm_id();
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
                $c->stash->{rest} = { error => "Please give a new drone run band name!" };
                $c->detach();
            }
            if (!$new_drone_run_band_desc){
                $c->stash->{rest} = { error => "Please give a new drone run band description!" };
                $c->detach();
            }
            if (!$new_drone_run_band_type){
                $c->stash->{rest} = { error => "Please give a new drone run band type!" };
                $c->detach();
            }
            if (!exists($image_types_allowed->{$new_drone_run_band_type})) {
                $c->stash->{rest} = { error => "Drone run band type not supported: $new_drone_run_band_type!" };
                $c->detach();
            }
            if (exists($seen_image_types_upload{$new_drone_run_band_type})) {
                $c->stash->{rest} = { error => "Drone run band type is repeated: $new_drone_run_band_type! Each drone run band in an imaging event should have a unique type!" };
                $c->detach();
            }
            $seen_image_types_upload{$new_drone_run_band_type}++;

            my $upload_file = $c->req->upload('drone_run_band_stitched_ortho_image_1');
            if (!$upload_file) {
                $c->stash->{rest} = { error => "Please provide a drone image zipfile OR a stitched ortho image!" };
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
                    $c->stash->{rest} = { error => "Please give a new drone run band name!".$_ };
                    $c->detach();
                }
                if (!$new_drone_run_band_desc){
                    $c->stash->{rest} = { error => "Please give a new drone run band description!" };
                    $c->detach();
                }
                if (!$new_drone_run_band_type){
                    $c->stash->{rest} = { error => "Please give a new drone run band type!" };
                    $c->detach();
                }
                if (!exists($image_types_allowed->{$new_drone_run_band_type})) {
                    $c->stash->{rest} = { error => "Drone run band type not supported: $new_drone_run_band_type!" };
                    $c->detach();
                }
                if (exists($seen_image_types_upload{$new_drone_run_band_type})) {
                    $c->stash->{rest} = { error => "Drone run band type is repeated: $new_drone_run_band_type! Each drone run band in an imaging event should have a unique type!" };
                    $c->detach();
                }
                $seen_image_types_upload{$new_drone_run_band_type}++;

                my $upload_file = $c->req->upload('drone_run_band_stitched_ortho_image_'.$_);
                if (!$upload_file) {
                    $c->stash->{rest} = { error => "Please provide a drone image zipfile OR a stitched ortho image!" };
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

        my @img_path_split = split '\/', $image_paths->[0];
        my $image_path_img_name = pop(@img_path_split);
        my $image_path_project_name = pop(@img_path_split);
        my $image_path_remaining = join '/', @img_path_split;
        print STDERR Dumper [$image_path_img_name, $image_path_project_name, $image_path_remaining];

        my $dir = $c->tempfiles_subdir('/upload_drone_imagery_raw_images');

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

            $cmd = "docker run --rm -v $image_path_remaining:/datasets/code opendronemap/odm --project-path /$image_path_project_name";
            print STDERR Dumper $cmd;
            my $status = system($cmd);

            my $temp_file_raw_image_blue = $c->tempfile( TEMPLATE => 'upload_drone_imagery_raw_images/fileXXXX').".png";
            my $temp_file_raw_image_green = $c->tempfile( TEMPLATE => 'upload_drone_imagery_raw_images/fileXXXX').".png";
            my $temp_file_raw_image_red = $c->tempfile( TEMPLATE => 'upload_drone_imagery_raw_images/fileXXXX').".png";
            my $temp_file_raw_image_nir = $c->tempfile( TEMPLATE => 'upload_drone_imagery_raw_images/fileXXXX').".png";
            my $temp_file_raw_image_red_edge = $c->tempfile( TEMPLATE => 'upload_drone_imagery_raw_images/fileXXXX').".png";

            my $cmd_2 = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/ODMOpenImage.py --image_path '$image_path_remaining/$image_path_project_name/odm_orthophoto/odm_orthophoto_render.tif' --outfile_path_b1 '$temp_file_raw_image_blue' --outfile_path_b2 '$temp_file_raw_image_green' --outfile_path_b3 '$temp_file_raw_image_red' --outfile_path_b4 '$temp_file_raw_image_nir' --outfile_path_b5 '$temp_file_raw_image_red_edge' ";
            system($cmd_2);

            @stitched_bands = (
                ["Band 1", "Blue", "Blue (450-520nm)", $temp_file_raw_image_blue],
                ["Band 2", "Green", "Green (515-600nm)", $temp_file_raw_image_green],
                ["Band 3", "Red", "Red (600-690nm)", $temp_file_raw_image_red],
                ["Band 4", "NIR", "NIR (780-3000nm)", $temp_file_raw_image_nir],
                ["Band 5", "RedEdge", "Red Edge (690-750nm)", $temp_file_raw_image_red_edge]
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

    $c->stash->{rest} = { success => 1, drone_run_project_id => $selected_drone_run_id, drone_run_band_project_ids => \@return_drone_run_band_project_ids, drone_run_band_image_ids => \@return_drone_run_band_image_ids, drone_run_band_image_urls => \@return_drone_run_band_image_urls, drone_run_band_raw_image_boundaries_temp_images => \@raw_image_boundaries_temp_images, saved_image_stacks => \%saved_image_stacks };
}

sub upload_drone_imagery_additional_raw_images : Path('/api/drone_imagery/upload_drone_imagery_additional_raw_images') : ActionClass('REST') { }
sub upload_drone_imagery_additional_raw_images_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    my $new_drone_run_camera_info = 'micasense_5';

    my $selected_trial_id = $c->req->param('upload_drone_imagery_additional_raw_images_field_trial_id');
    if (!$selected_trial_id) {
        $c->stash->{rest} = { error => "Please select a field trial!" };
        $c->detach();
    }
    my $selected_drone_run_id = $c->req->param('upload_drone_imagery_additional_raw_images_drone_run_id');

    my $upload_file = $c->req->upload('upload_drone_imagery_additional_raw_images_zipfile');
    my $upload_panel_file = $c->req->upload('upload_drone_imagery_additional_raw_images_calibration_zipfile');

    if (!$upload_file) {
        $c->stash->{rest} = { error => "Please provide a drone image zipfile of raw images!" };
        $c->detach();
    }
    if (!$upload_panel_file && $new_drone_run_camera_info eq 'micasense_5') {
        $c->stash->{rest} = { error => "Please provide a zipfile of images of the Micasense radiometric calibration panels!" };
        $c->detach();
    }

    my $drone_run_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_experiment', 'experiment_type')->cvterm_id();

    my $alignment_q = "SELECT basename, dirname, md.file_id, md.filetype
        FROM metadata.md_files AS md
        JOIN phenome.nd_experiment_md_files using(file_id)
        JOIN nd_experiment using(nd_experiment_id)
        JOIN nd_experiment_project using(nd_experiment_id)
        WHERE nd_experiment.type_id=$drone_run_experiment_type_id AND nd_experiment_project.project_id=?;";
    my $alignment_h = $schema->storage->dbh()->prepare($alignment_q);
    $alignment_h->execute($selected_drone_run_id);
    my ($basename, $filename, $file_id, $filetype) = $alignment_h->fetchrow_array();
    my $alignment_file;
    if ($basename && $filename) {
        $alignment_file = $filename."/".$basename;
    }

    my @return_drone_run_band_project_ids;
    my @return_drone_run_band_image_ids;
    my @return_drone_run_band_image_urls;
    my @raw_image_boundaries_temp_images;
    my $output_path;
    my $cmd;

    my $log_file_path = '';
    if ($c->config->{error_log}){
        $log_file_path = "--log_file_path '".$c->config->{error_log}."'";
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

        # $cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/MicasenseRawImageAlign.py $log_file_path --file_with_image_paths '$temp_file_image_file_names' --file_with_panel_image_paths '$temp_file_image_file_names_panel' --output_path '$output_path' --temporary_development_path '/home/nmorales/Downloads'";
        my $alignment = '';
        if ($alignment_file) {
            $alignment = "--infile_alignment_file '$alignment_file' ";
        }
        $cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/MicasenseRawImageAlign.py $log_file_path --file_with_image_paths '$temp_file_image_file_names' --file_with_panel_image_paths '$temp_file_image_file_names_panel' --output_path '$output_path' $alignment";

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

    my $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();

    my $q_drone_run_bands = "SELECT drone_run_band.project_id, drone_run_band_project_type.value
        FROM project AS drone_run
        JOIN project_relationship ON (drone_run.project_id = project_relationship.object_project_id AND project_relationship.type_id=$project_relationship_type_id)
        JOIN project as drone_run_band ON (drone_run_band.project_id=project_relationship.subject_project_id)
        JOIN projectprop AS drone_run_band_project_type ON (drone_run_band_project_type.project_id=drone_run_band.project_id AND drone_run_band_project_type.type_id=$drone_run_band_project_type_cvterm_id)
        WHERE drone_run.project_id=?;";
    my $h_drone_run_bands = $schema->storage->dbh->prepare($q_drone_run_bands);
    $h_drone_run_bands->execute($selected_drone_run_id);
    my %drone_run_bands_all;
    while (my ($drone_run_band_id, $drone_run_band_type) = $h_drone_run_bands->fetchrow_array()) {
        $drone_run_bands_all{$drone_run_band_type} = $drone_run_band_id;
    }
    print STDERR Dumper \%drone_run_bands_all;

    foreach my $m (@stitched_bands) {
        my $selected_drone_run_band_id = $drone_run_bands_all{$m->[2]};

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

    my $saved_image_stacks_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_raw_images_saved_micasense_stacks', 'project_property')->cvterm_id();
    my $image_stack_projectprop_previous_rs = $schema->resultset("Project::Projectprop")->find({project_id => $selected_drone_run_id, type_id => $saved_image_stacks_type_id});
    my $image_stack_projectprop_previous_value = decode_json $image_stack_projectprop_previous_rs->value();
    my $image_stack_projectprop_previous_id = $image_stack_projectprop_previous_rs->projectprop_id();

    my $image_stack_counter_start = scalar(keys %$image_stack_projectprop_previous_value);
    my $image_stack_counter = $image_stack_counter_start;
    foreach (@return_drone_run_band_image_ids) {
        push @{$image_stack_projectprop_previous_value->{$image_stack_counter}}, $_;
        $image_stack_counter++;
        if ($image_stack_counter >= $total_captures + $image_stack_counter_start) {
            $image_stack_counter = $image_stack_counter_start;
        }
    }
    # print STDERR Dumper $image_stack_projectprop_previous_value;

    my $q_update = "UPDATE projectprop SET value=? WHERE projectprop_id=?;";
    my $h_update = $schema->storage->dbh->prepare($q_update);
    $h_update->execute(encode_json($image_stack_projectprop_previous_value), $image_stack_projectprop_previous_id);

    $c->stash->{rest} = {success => 1, drone_run_band_project_ids => \@return_drone_run_band_project_ids, drone_run_band_image_ids => \@return_drone_run_band_image_ids, drone_run_band_image_urls => \@return_drone_run_band_image_urls, drone_run_band_raw_image_boundaries_temp_images => \@raw_image_boundaries_temp_images, saved_image_stacks => $image_stack_projectprop_previous_value};
}

sub upload_drone_imagery_raw_images_automated_boundaries : Path('/api/drone_imagery/upload_drone_imagery_raw_images_automated_boundaries') : ActionClass('REST') { }
sub upload_drone_imagery_raw_images_automated_boundaries_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $upload_file_top_left_image = $c->req->upload('upload_drone_images_top_left_image');
    my $upload_file_top_right_image = $c->req->upload('upload_drone_images_top_right_image');
    my $upload_file_bottom_left_image = $c->req->upload('upload_drone_images_bottom_left_image');
    my $upload_file_bottom_right_image = $c->req->upload('upload_drone_images_bottom_right_image');

    if (!$upload_file_top_left_image) {
        $c->stash->{rest} = { error => "Please provide a north west image!" };
        $c->detach();
    }
    if (!$upload_file_top_right_image) {
        $c->stash->{rest} = { error => "Please provide a north east image!" };
        $c->detach();
    }
    if (!$upload_file_bottom_left_image) {
        $c->stash->{rest} = { error => "Please provide a south west image!" };
        $c->detach();
    }
    if (!$upload_file_bottom_right_image) {
        $c->stash->{rest} = { error => "Please provide a south east image!" };
        $c->detach();
    }

    my $selected_trial_id = $c->req->param('drone_run_field_trial_id');
    if (!$selected_trial_id) {
        $c->stash->{rest} = { error => "Please select a field trial!" };
        $c->detach();
    }
    my $new_drone_run_name = $c->req->param('drone_run_name');
    my $new_drone_run_type = $c->req->param('drone_run_type');
    my $new_drone_run_date = $c->req->param('drone_run_date');
    my $new_drone_run_desc = $c->req->param('drone_run_description');
    if (!$new_drone_run_name) {
        $c->stash->{rest} = { error => "Please create a new drone run!" };
        $c->detach();
    }
    if ($new_drone_run_name && !$new_drone_run_type){
        $c->stash->{rest} = { error => "Please give a new drone run type!" };
        $c->detach();
    }
    if ($new_drone_run_name && !$new_drone_run_date){
        $c->stash->{rest} = { error => "Please give a new drone run date!" };
        $c->detach();
    }
    if ($new_drone_run_name && $new_drone_run_date !~ /^\d{4}\/\d{2}\/\d{2}\s\d\d:\d\d:\d\d$/){
        $c->stash->{rest} = { error => "Please give a new drone run date in the format YYYY/MM/DD HH:mm:ss!" };
        $c->detach();
    }
    if ($new_drone_run_name && !$new_drone_run_desc){
        $c->stash->{rest} = { error => "Please give a new drone run description!" };
        $c->detach();
    }

    my $new_drone_run_camera_info = $c->req->param('drone_image_upload_camera_info');
    my $new_drone_run_band_numbers = $c->req->param('drone_run_band_number');
    my $new_drone_run_band_stitching = $c->req->param('drone_image_upload_drone_run_band_stitching');

    if (!$new_drone_run_camera_info) {
        $c->stash->{rest} = { error => "Please indicate the type of camera!" };
        $c->detach();
    }

    if ($new_drone_run_band_stitching eq 'no' && !$new_drone_run_band_numbers) {
        $c->stash->{rest} = { error => "Please give the number of new drone run bands!" };
        $c->detach();
    }
    if (!$new_drone_run_band_stitching) {
        $c->stash->{rest} = { error => "Please indicate if the images are stitched!" };
        $c->detach();
    }

    my $log_file_path = '';
    if ($c->config->{error_log}){
        $log_file_path = "--log_file_path '".$c->config->{error_log}."'";
    }

    my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $selected_trial_id });
    my $planting_date = $trial->get_planting_date();
    my $planting_date_time_object = Time::Piece->strptime($planting_date, "%Y-%B-%d");
    my $drone_run_date_time_object = Time::Piece->strptime($new_drone_run_date, "%Y/%m/%d %H:%M:%S");
    my $time_diff = $drone_run_date_time_object - $planting_date_time_object;
    my $time_diff_weeks = $time_diff->weeks;
    my $time_diff_days = $time_diff->days;
    my $rounded_time_diff_weeks = round($time_diff_weeks);

    my $q = "SELECT t.cvterm_id FROM cvterm as t JOIN cv ON(t.cv_id=cv.cv_id) WHERE t.name=? and cv.name=?;";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute("week $rounded_time_diff_weeks", 'cxgn_time_ontology');
    my ($week_cvterm_id) = $h->fetchrow_array();

    $h->execute("day $time_diff_days", 'cxgn_time_ontology');
    my ($day_cvterm_id) = $h->fetchrow_array();

    my $week_term = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $week_cvterm_id, 'extended');
    my $day_term = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $day_cvterm_id, 'extended');

    my %related_cvterms = (
        week => $week_term,
        day => $day_term
    );

    my $calendar_funcs = CXGN::Calendar->new({});
    my $drone_run_event = $calendar_funcs->check_value_format($new_drone_run_date);
    my $project_start_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_start_date', 'project_property')->cvterm_id();
    my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property')->cvterm_id();
    my $drone_run_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_project_type', 'project_property')->cvterm_id();
    my $drone_run_camera_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_camera_type', 'project_property')->cvterm_id();
    my $drone_run_related_cvterms_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_related_time_cvterms_json', 'project_property')->cvterm_id();
    my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
    my $project_rs = $schema->resultset("Project::Project")->create({
        name => $new_drone_run_name,
        description => $new_drone_run_desc,
        projectprops => [{type_id => $drone_run_type_cvterm_id, value => $new_drone_run_type},{type_id => $project_start_date_type_id, value => $drone_run_event}, {type_id => $design_cvterm_id, value => 'drone_run'}, {type_id => $drone_run_camera_type_cvterm_id, value => $new_drone_run_camera_info}, {type_id => $drone_run_related_cvterms_cvterm_id, value => encode_json \%related_cvterms}],
        project_relationship_subject_projects => [{type_id => $project_relationship_type_id, object_project_id => $selected_trial_id}]
    });
    my $selected_drone_run_id = $project_rs->project_id();

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my $upload_original_name_tl = $upload_file_top_left_image->filename();
    my $upload_tempfile_tl = $upload_file_top_left_image->tempname;

    my $uploader_tl = CXGN::UploadFile->new({
        tempfile => $upload_tempfile_tl,
        subdirectory => "drone_imagery_upload_boundary_images",
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name_tl,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });
    my $archived_filename_with_path_tl = $uploader_tl->archive();
    my $md5_tl = $uploader_tl->get_md5($archived_filename_with_path_tl);
    if (!$archived_filename_with_path_tl) {
        $c->stash->{rest} = { error => "Could not save file $upload_original_name_tl in archive." };
        $c->detach();
    }
    
    my $upload_original_name_tr = $upload_file_top_right_image->filename();
    my $upload_tempfile_tr = $upload_file_top_right_image->tempname;

    my $uploader_tr = CXGN::UploadFile->new({
        tempfile => $upload_tempfile_tr,
        subdirectory => "drone_imagery_upload_boundary_images",
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name_tr,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });
    my $archived_filename_with_path_tr = $uploader_tr->archive();
    my $md5_tr = $uploader_tr->get_md5($archived_filename_with_path_tr);
    if (!$archived_filename_with_path_tr) {
        $c->stash->{rest} = { error => "Could not save file $upload_original_name_tr in archive." };
        $c->detach();
    }

    my $upload_original_name_bl = $upload_file_bottom_left_image->filename();
    my $upload_tempfile_bl = $upload_file_bottom_left_image->tempname;

    my $uploader_bl = CXGN::UploadFile->new({
        tempfile => $upload_tempfile_bl,
        subdirectory => "drone_imagery_upload_boundary_images",
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name_bl,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });
    my $archived_filename_with_path_bl = $uploader_bl->archive();
    my $md5_bl = $uploader_bl->get_md5($archived_filename_with_path_bl);
    if (!$archived_filename_with_path_bl) {
        $c->stash->{rest} = { error => "Could not save file $upload_original_name_bl in archive." };
        $c->detach();
    }

    my $upload_original_name_br = $upload_file_bottom_right_image->filename();
    my $upload_tempfile_br = $upload_file_bottom_right_image->tempname;

    my $uploader_br = CXGN::UploadFile->new({
        tempfile => $upload_tempfile_br,
        subdirectory => "drone_imagery_upload_boundary_images",
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name_br,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });
    my $archived_filename_with_path_br = $uploader_br->archive();
    my $md5_br = $uploader_br->get_md5($archived_filename_with_path_br);
    if (!$archived_filename_with_path_br) {
        $c->stash->{rest} = { error => "Could not save file $upload_original_name_br in archive." };
        $c->detach();
    }

    my $dir = $c->tempfiles_subdir('/upload_drone_imagery_raw_image_boundaries');
    my $temp_file_gps_tl = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_raw_image_boundaries/fileXXXX');
    my $temp_file_gps_tr = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_raw_image_boundaries/fileXXXX');
    my $temp_file_gps_bl = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_raw_image_boundaries/fileXXXX');
    my $temp_file_gps_br = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_raw_image_boundaries/fileXXXX');

    my $status_tl = system($c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/GetMicasenseImageGPS.py $log_file_path --input_image_file '$upload_tempfile_tl' --outfile_path '$temp_file_gps_tl'");
    my $status_tr = system($c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/GetMicasenseImageGPS.py $log_file_path --input_image_file '$upload_tempfile_tr' --outfile_path '$temp_file_gps_tr'");
    my $status_bl = system($c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/GetMicasenseImageGPS.py $log_file_path --input_image_file '$upload_tempfile_bl' --outfile_path '$temp_file_gps_bl'");
    my $status_br = system($c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/GetMicasenseImageGPS.py $log_file_path --input_image_file '$upload_tempfile_br' --outfile_path '$temp_file_gps_br'");

    unlink $upload_tempfile_tl;
    unlink $upload_tempfile_tr;
    unlink $upload_tempfile_bl;
    unlink $upload_tempfile_br;

    my @tl_gps;
    my @tr_gps;
    my @bl_gps;
    my @br_gps;
    my $csv = Text::CSV->new({ sep_char => ',' });

    open(my $fh_tl, '<', $temp_file_gps_tl) or die "Could not open file '$temp_file_gps_tl' $!";
        if ($csv->parse(<$fh_tl>)) {
            @tl_gps = $csv->fields();
        }
    close $fh_tl;
    open(my $fh_tr, '<', $temp_file_gps_tr) or die "Could not open file '$temp_file_gps_tr' $!";
        if ($csv->parse(<$fh_tr>)) {
            @tr_gps = $csv->fields();
        }
    close $fh_tr;
    open(my $fh_bl, '<', $temp_file_gps_bl) or die "Could not open file '$temp_file_gps_bl' $!";
        if ($csv->parse(<$fh_bl>)) {
            @bl_gps = $csv->fields();
        }
    close $fh_bl;
    open(my $fh_br, '<', $temp_file_gps_br) or die "Could not open file '$temp_file_gps_br' $!";
        if ($csv->parse(<$fh_br>)) {
            @br_gps = $csv->fields();
        }
    close $fh_br;

    print STDERR Dumper \@tl_gps;
    print STDERR Dumper \@tr_gps;
    print STDERR Dumper \@bl_gps;
    print STDERR Dumper \@br_gps;

    my %corners = (north_west => \@tl_gps, north_east => \@tr_gps, south_west => \@bl_gps, south_east => \@br_gps);

    my $linking_table_tl_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'raw_boundaries_top_left_drone_imagery', 'project_md_image')->cvterm_id();
    my $image_tl = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image_tl->set_sp_person_id($user_id);
    my $ret_tl = $image_tl->process_image($archived_filename_with_path_tl, 'project', $selected_drone_run_id, $linking_table_tl_type_id);
    my $tl_url = $image_tl->get_image_url('original_converted');
    my $tl_image_id = $image_tl->get_image_id();

    my $linking_table_tr_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'raw_boundaries_top_right_drone_imagery', 'project_md_image')->cvterm_id();
    my $image_tr = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image_tr->set_sp_person_id($user_id);
    my $ret_tr = $image_tr->process_image($archived_filename_with_path_tr, 'project', $selected_drone_run_id, $linking_table_tr_type_id);
    my $tr_url = $image_tr->get_image_url('original_converted');
    my $tr_image_id = $image_tr->get_image_id();

    my $linking_table_bl_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'raw_boundaries_bottom_left_drone_imagery', 'project_md_image')->cvterm_id();
    my $image_bl = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image_bl->set_sp_person_id($user_id);
    my $ret_bl = $image_bl->process_image($archived_filename_with_path_bl, 'project', $selected_drone_run_id, $linking_table_bl_type_id);
    my $bl_url = $image_bl->get_image_url('original_converted');
    my $bl_image_id = $image_bl->get_image_id();

    my $linking_table_br_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'raw_boundaries_bottom_right_drone_imagery', 'project_md_image')->cvterm_id();
    my $image_br = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image_br->set_sp_person_id($user_id);
    my $ret_br = $image_br->process_image($archived_filename_with_path_br, 'project', $selected_drone_run_id, $linking_table_br_type_id);
    my $br_url = $image_br->get_image_url('original_converted');
    my $br_image_id = $image_br->get_image_id();

    $c->stash->{rest} = { success => 1, drone_run_project_id => $selected_drone_run_id, tl_url => $tl_url, tl_image_id => $tl_image_id, tr_url => $tr_url, tr_image_id => $tr_image_id, bl_url => $bl_url, bl_image_id => $bl_image_id, br_url => $br_url, br_image_id => $br_image_id, corners_gps => \%corners };
}

sub upload_drone_imagery_new_vehicle : Path('/api/drone_imagery/new_imaging_vehicle') : ActionClass('REST') { }
sub upload_drone_imagery_new_vehicle_GET : Args(0) {
    my $self = shift;
    my $c = shift;
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
