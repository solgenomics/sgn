
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
use SGN::Image;
use CXGN::DroneImagery::ImagesSearch;
use URI::Encode qw(uri_encode uri_decode);
use CXGN::Calendar;
use Image::Size;
use CXGN::DroneImagery::ImageTypes;
#use Inline::Python;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
);

sub upload_drone_imagery_check_drone_name : Path('/api/drone_imagery/upload_drone_imagery_check_drone_name') : ActionClass('REST') { }
sub upload_drone_imagery_check_drone_name_GET : Args(0) {
    my $self = shift;
    my $c = shift;
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
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

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
    if (!$selected_drone_run_id && !$new_drone_run_name) {
        $c->stash->{rest} = { error => "Please select a drone run or create a new drone run!" };
        $c->detach();
    }
    if ($selected_drone_run_id && $new_drone_run_name){
        $c->stash->{rest} = { error => "Please select a drone run OR create a new drone run, not both!" };
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

    if ($selected_drone_run_id && $new_drone_run_band_stitching eq 'yes') {
        $c->stash->{rest} = { error => "Please create a new drone run if you are uploading a zipfile of images to stitch!" };
        $c->detach();
    }

    if (!$selected_drone_run_id) {
        my $calendar_funcs = CXGN::Calendar->new({});
        my $drone_run_event = $calendar_funcs->check_value_format($new_drone_run_date);
        my $project_start_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_start_date', 'project_property')->cvterm_id();
        my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property')->cvterm_id();
        my $drone_run_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_project_type', 'project_property')->cvterm_id();
        my $drone_run_camera_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_camera_type', 'project_property')->cvterm_id();
        my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
        my $project_rs = $schema->resultset("Project::Project")->create({
            name => $new_drone_run_name,
            description => $new_drone_run_desc,
            projectprops => [{type_id => $drone_run_type_cvterm_id, value => $new_drone_run_type},{type_id => $project_start_date_type_id, value => $drone_run_event}, {type_id => $design_cvterm_id, value => 'drone_run'}, {type_id => $drone_run_camera_type_cvterm_id, value => $new_drone_run_camera_info}],
            project_relationship_subject_projects => [{type_id => $project_relationship_type_id, object_project_id => $selected_trial_id}]
        });
        $selected_drone_run_id = $project_rs->project_id();
    }

    my $drone_run_band_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property')->cvterm_id();
    my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();

    my @return_drone_run_band_project_ids;
    my @return_drone_run_band_image_ids;
    my @return_drone_run_band_image_urls;
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
            $c->stash->{rest} = { error => "Please provide a drone image zipfile of images to stitch!" };
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

        my $cmd;
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
            $cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/AlignImagesMicasense.py --log_file_path '".$c->config->{error_log}."' --file_with_image_paths '$temp_file_image_file_names' --file_with_panel_image_paths '$temp_file_image_file_names_panel' --output_path '$dir' --output_path_band1 '$temp_file_stitched_result_band1' --output_path_band2 '$temp_file_stitched_result_band2' --output_path_band3 '$temp_file_stitched_result_band3' --output_path_band4 '$temp_file_stitched_result_band4' --output_path_band5 '$temp_file_stitched_result_band5' --final_rgb_output_path '$temp_file_stitched_result_rgb' --final_rnre_output_path '$temp_file_stitched_result_rnre'";

            @stitched_bands = (
                ["Band 1", "Blue", "Blue (450-520nm)", $temp_file_stitched_result_band1],
                ["Band 2", "Green", "Green (515-600nm)", $temp_file_stitched_result_band2],
                ["Band 3", "Red", "Red (600-690nm)", $temp_file_stitched_result_band3],
                ["Band 4", "NIR", "NIR (780-3000nm)", $temp_file_stitched_result_band4],
                ["Band 5", "RedEdge", "Red Edge (690-750nm)", $temp_file_stitched_result_band5]
            );
        }
        elsif ($new_drone_run_camera_info eq 'ccd_color' || $new_drone_run_camera_info eq 'cmos_color') {
            $cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/AlignImagesRGB.py --log_file_path '".$c->config->{error_log}."' --file_with_image_paths '$temp_file_image_file_names' --output_path '$dir' --final_rgb_output_path '$temp_file_stitched_result_rgb'";

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
    }

    $c->stash->{rest} = { success => 1, drone_run_project_id => $selected_drone_run_id, drone_run_band_project_ids => \@return_drone_run_band_project_ids, drone_run_band_image_ids => \@return_drone_run_band_image_ids, drone_run_band_image_urls => \@return_drone_run_band_image_urls };
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
