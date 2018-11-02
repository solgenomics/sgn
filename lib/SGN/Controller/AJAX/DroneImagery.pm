
=head1 NAME

SGN::Controller::AJAX::DroneImagery - a REST controller class to provide the
functions for uploading and analyzing drone imagery

=head1 DESCRIPTION

=head1 AUTHOR

=cut

package SGN::Controller::AJAX::DroneImagery;

use Moose;
use Data::Dumper;
use LWP::UserAgent;
use JSON;
use SGN::Model::Cvterm;
use DateTime;
use CXGN::UploadFile;
use SGN::Image;
use CXGN::DroneImagery::ImagesSearch;
use URI::Encode qw(uri_encode uri_decode);
use CXGN::Calendar;
use Image::Size;
#use Inline::Python;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub upload_drone_imagery : Path('/ajax/drone_imagery/upload_drone_imagery') : ActionClass('REST') { }

sub upload_drone_imagery_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $selected_trial_id = $c->req->param('upload_drone_images_field_trial_id');
    if (!$selected_trial_id) {
        $c->stash->{rest} = { error => "Please select a field trial!" };
        $c->detach();
    }
    my $selected_drone_run_id = $c->req->param('drone_image_upload_drone_run_id');
    my $new_drone_run_name = $c->req->param('drone_image_upload_drone_run_name');
    my $new_drone_run_date = $c->req->param('drone_image_upload_drone_run_date');
    my $new_drone_run_desc = $c->req->param('drone_image_upload_drone_run_desc');
    if (!$selected_drone_run_id && !$new_drone_run_name) {
        $c->stash->{rest} = { error => "Please select a drone run or create a new drone run!" };
        $c->detach();
    }
    if ($selected_drone_run_id && $new_drone_run_name){
        $c->stash->{rest} = { error => "Please select a drone run OR create a new drone run, not both!" };
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

    my $new_drone_run_band_numbers = $c->req->param('drone_image_upload_drone_run_band_number');
    my $new_drone_run_band_stitching = $c->req->param('drone_image_upload_drone_run_band_stitching');

    if (!$new_drone_run_band_numbers) {
        $c->stash->{rest} = { error => "Please give the number of new drone run bands!" };
        $c->detach();
    }
    if (!$new_drone_run_band_stitching) {
        $c->stash->{rest} = { error => "Please indicate if the images are stitched!" };
        $c->detach();
    }

    my @new_drone_run_bands;
    if ($new_drone_run_band_numbers eq 'one_bw' || $new_drone_run_band_numbers eq 'one_rgb') {
        my $new_drone_run_band_name = $c->req->param('drone_image_upload_drone_run_band_name');
        my $new_drone_run_band_desc = $c->req->param('drone_image_upload_drone_run_band_desc');
        my $new_drone_run_band_type = $c->req->param('drone_image_upload_drone_run_band_type');
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
        
        my $upload_file;
        if ($new_drone_run_band_stitching eq 'yes') {
            $upload_file = $c->req->upload('upload_drone_images_zipfile');
        } elsif ($new_drone_run_band_stitching eq 'no') {
            $upload_file = $c->req->upload('upload_drone_images_stitched_ortho');
        }
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
            my $new_drone_run_band_name = $c->req->param('drone_image_upload_drone_run_band_name_'.$_);
            my $new_drone_run_band_desc = $c->req->param('drone_image_upload_drone_run_band_desc_'.$_);
            my $new_drone_run_band_type = $c->req->param('drone_image_upload_drone_run_band_type_'.$_);
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

            my $upload_file;
            if ($new_drone_run_band_stitching eq 'yes') {
                $upload_file = $c->req->upload('upload_drone_images_zipfile_'.$_);
            } elsif ($new_drone_run_band_stitching eq 'no') {
                $upload_file = $c->req->upload('upload_drone_images_stitched_ortho_'.$_);
            }
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

    if (!$selected_drone_run_id) {
        my $calendar_funcs = CXGN::Calendar->new({});
        my $drone_run_event = $calendar_funcs->check_value_format($new_drone_run_date);
        my $project_start_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_start_date', 'project_property')->cvterm_id();
        my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property')->cvterm_id();
        my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
        my $project_rs = $schema->resultset("Project::Project")->create({
            name => $new_drone_run_name,
            description => $new_drone_run_desc,
            projectprops => [{type_id => $project_start_date_type_id, value => $drone_run_event}, {type_id => $design_cvterm_id, value => 'drone_run'}],
            project_relationship_subject_projects => [{type_id => $project_relationship_type_id, object_project_id => $selected_trial_id}]
        });
        $selected_drone_run_id = $project_rs->project_id();
    }

    my $drone_run_band_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property')->cvterm_id();
    my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();

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

        if ($new_drone_run_band_stitching eq 'no') {
            my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
            $image->set_sp_person_id($user_id);
            my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
            my $ret = $image->process_image($archived_filename_with_path, 'project', $selected_drone_run_band_id, $linking_table_type_id);
        } elsif ($new_drone_run_band_stitching eq 'yes') {
            my $image = SGN::Image->new( $c->dbc->dbh, undef, $c );
            my $image_error = $image->upload_drone_imagery_zipfile($archived_filename_with_path, $user_id, $selected_drone_run_band_id);
            if ($image_error) {
                $c->stash->{rest} = { error => "Problem saving images!".$image_error };
                $c->detach();
            }
        }
    }

    $c->stash->{rest} = { success => 1 };
}

sub raw_drone_imagery_summary : Path('/ajax/drone_imagery/raw_drone_imagery') : ActionClass('REST') { }

sub raw_drone_imagery_summary_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $raw_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'raw_drone_imagery', 'project_md_image')->cvterm_id();
    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$raw_drone_images_cvterm_id
    });
    my ($result, $total_count) = $images_search->search();
    #print STDERR Dumper $result;

    my $stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $stitched_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$stitched_drone_images_cvterm_id
    });
    my ($stitched_result, $stitched_total_count) = $stitched_images_search->search();
    #print STDERR Dumper $result;

    my $cropped_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cropped_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $cropped_stitched_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$cropped_stitched_drone_images_cvterm_id
    });
    my ($cropped_stitched_result, $cropped_stitched_total_count) = $cropped_stitched_images_search->search();
    #print STDERR Dumper $result;

    my $denoised_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $denoised_stitched_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$denoised_stitched_drone_images_cvterm_id
    });
    my ($denoised_stitched_result, $denoised_stitched_total_count) = $denoised_stitched_images_search->search();
    #print STDERR Dumper $result;

    my $background_removed_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'background_removed_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $background_removed_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$background_removed_drone_images_cvterm_id
    });
    my ($background_removed_result, $background_removed_total_count) = $background_removed_images_search->search();
    #print STDERR Dumper $result;

    my $ft_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'fourier_transform_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $ft_stitched_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$ft_stitched_drone_images_cvterm_id
    });
    my ($ft_stitched_result, $ft_stitched_total_count) = $ft_stitched_images_search->search();
    #print STDERR Dumper $result;

    my $plot_polygon_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygons_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$plot_polygon_stitched_drone_images_cvterm_id
    });
    my ($plot_polygons_result, $plot_polygons_total_count) = $plot_polygons_images_search->search();
    #print STDERR Dumper $result;

    my @return;
    my %unique_drone_runs;
    foreach (@$result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_source_tag_tiny = $image->get_img_src_tag("tiny");
        push @{$unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{images}}, '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{usernames}->{$_->{username}}++;
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_project_name} = $_->{drone_run_band_project_name};
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_project_description} = $_->{drone_run_band_project_description};
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_project_type} = $_->{drone_run_band_project_type};
        $unique_drone_runs{$_->{drone_run_project_id}}->{trial_id} = $_->{trial_id};
        $unique_drone_runs{$_->{drone_run_project_id}}->{trial_name} = $_->{trial_name};
        $unique_drone_runs{$_->{drone_run_project_id}}->{drone_run_project_name} = $_->{drone_run_project_name};
        $unique_drone_runs{$_->{drone_run_project_id}}->{drone_run_date} = $_->{drone_run_date};
        $unique_drone_runs{$_->{drone_run_project_id}}->{drone_run_project_description} = $_->{drone_run_project_description};
    }
    foreach (@$stitched_result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_source_tag_small = $image->get_img_src_tag("thumbnail");
        my $image_original = $image->get_image_url("original");
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{stitched_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{stitched_image_username} = $_->{username};
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{stitched_image_modified_date} = $_->{image_modified_date};
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{stitched_image_original} = $image_original;
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{stitched_image_id} = $image_id;
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_project_name} = $_->{drone_run_band_project_name};
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_project_description} = $_->{drone_run_band_project_description};
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_project_type} = $_->{drone_run_band_project_type};
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{usernames}->{$_->{username}}++;
        $unique_drone_runs{$_->{drone_run_project_id}}->{trial_id} = $_->{trial_id};
        $unique_drone_runs{$_->{drone_run_project_id}}->{trial_name} = $_->{trial_name};
        $unique_drone_runs{$_->{drone_run_project_id}}->{drone_run_project_name} = $_->{drone_run_project_name};
        $unique_drone_runs{$_->{drone_run_project_id}}->{drone_run_date} = $_->{drone_run_date};
        $unique_drone_runs{$_->{drone_run_project_id}}->{drone_run_project_description} = $_->{drone_run_project_description};
    }
    foreach (@$cropped_stitched_result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_source_tag_small = $image->get_img_src_tag("thumbnail");
        my $image_original = $image->get_image_url("original");
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{cropped_stitched_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{cropped_stitched_image_username} = $_->{username};
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{cropped_stitched_image_modified_date} = $_->{image_modified_date};
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{cropped_stitched_image_original} = $image_original;
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{cropped_stitched_image_id} = $image_id;
    }
    foreach (@$denoised_stitched_result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_source_tag_small = $image->get_img_src_tag("thumbnail");
        my $image_original = $image->get_image_url("original");
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_stitched_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_stitched_image_username} = $_->{username};
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_stitched_image_modified_date} = $_->{image_modified_date};
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_stitched_image_original} = $image_original;
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_stitched_image_id} = $image_id;
    }
    foreach (@$background_removed_result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_source_tag_small = $image->get_img_src_tag("thumbnail");
        my $image_original = $image->get_image_url("original");
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{background_removed_stitched_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{background_removed_stitched_image_username} = $_->{username};
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{background_removed_stitched_image_modified_date} = $_->{image_modified_date};
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{background_removed_stitched_image_original} = $image_original;
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{background_removed_stitched_image_id} = $image_id;
    }
    foreach (@$ft_stitched_result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_source_tag_small = $image->get_img_src_tag("thumbnail");
        my $image_original = $image->get_image_url("original");
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{ft_stitched_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{ft_stitched_image_username} = $_->{username};
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{ft_stitched_image_original} = $image_original;
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{ft_stitched_image_id} = $image_id;
    }
    foreach (@$plot_polygons_result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_source_tag_tiny = $image->get_img_src_tag("tiny");
        my $image_original = $image->get_image_url("original");
        push @{$unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{plot_polygon_images}}, '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
    }
    #print STDERR Dumper \%unique_drone_runs;

    my $calendar_funcs = CXGN::Calendar->new({});
    foreach my $k (sort keys %unique_drone_runs) {
        my $v = $unique_drone_runs{$k};

        my $drone_run_bands = $v->{bands};

        my $drone_run_band_table_html = '<table class="table table-bordered"><thead><tr><th>Drone Run Band</th><th>Images/Actions</th></thead><tbody>';

        foreach my $drone_run_band_project_id (sort keys %$drone_run_bands) {
            my $d = $drone_run_bands->{$drone_run_band_project_id};

            $drone_run_band_table_html .= '<tr><td><b>Name</b>: '.$d->{drone_run_band_project_name}.'<br/><b>Description</b>: '.$d->{drone_run_band_project_description}.'<br/><b>Type</b>: '.$d->{drone_run_band_project_type}.'</td><td>';

            $drone_run_band_table_html .= '<div class="well well-sm">';
            if ($d->{images}) {
                $drone_run_band_table_html .= '<b>'.scalar(@{$d->{images}})." Raw Unstitched Images</b>:<br/><span>";
                $drone_run_band_table_html .= join '', @{$d->{images}};
                $drone_run_band_table_html .= "</span>";

                my $usernames = '';
                foreach (keys %{$d->{usernames}}){
                    $usernames .= " $_ ";
                }
                $drone_run_band_table_html .= '<br/><br/>';
                $drone_run_band_table_html .= '<b>Uploaded By</b>: '.$usernames;
            } else {
                $drone_run_band_table_html .= '<b>No Raw Unstitched Images</b>';
            }
            $drone_run_band_table_html .= '</div>';

            if ($d->{stitched_image}) {
                $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-6"><h5>Stitched Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{stitched_image_id}.'"></span></h5><b>By</b>: '.$d->{stitched_image_username}.'<br/><b>Date</b>: '.$d->{stitched_image_modified_date}.'</div><div class="col-sm-6">'.$d->{stitched_image}.'</div></div></div>';

                if ($d->{cropped_stitched_image}) {
                    $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-5"><h5>Cropped Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{cropped_stitched_image_id}.'"></span></h5><b>By</b>: '.$d->{cropped_stitched_image_username}.'<br/><b>Date</b>: '.$d->{cropped_stitched_image_modified_date}.'</div><div class="col-sm-7">'.$d->{cropped_stitched_image}.'</div></div></div>';

                    if ($d->{denoised_stitched_image}) {
                        $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-5"><h5>Denoised Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{denoised_stitched_image_id}.'"></span></h5><b>By</b>: '.$d->{denoised_stitched_image_username}.'</br><b>Date</b>: '.$d->{denoised_stitched_image_modified_date}.'</div><div class="col-sm-7">'.$d->{denoised_stitched_image}.'</div></div></div>';

                        if ($d->{background_removed_stitched_image}) {
                            $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-5"><h5>Background Removed Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{background_removed_stitched_image_id}.'"></span></h5><b>By</b>: '.$d->{background_removed_stitched_image_username}.'</br><b>Date</b>: '.$d->{background_removed_stitched_image_modified_date}.'</div><div class="col-sm-7">'.$d->{background_removed_stitched_image}.'</div></div></div>';

                            $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{background_removed_stitched_image_id}.'">Create/View Plot Polygons</button>';

                            $drone_run_band_table_html .= '<hr>';
                            my $plot_polygon_images = '';
                            if ($d->{plot_polygon_images}) {
                                $plot_polygon_images = scalar(@{$d->{plot_polygon_images}})." Plot Polygons<br/><span>";
                                $plot_polygon_images .= join '', @{$d->{plot_polygon_images}};
                                $plot_polygon_images .= "</span>";
                                $plot_polygon_images .= '<br/><br/><button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" >Calculate Phenotypes</button>';
                            } else {
                                $plot_polygon_images = 'No Plot Polygons Assigned';
                            }
                            $drone_run_band_table_html .= $plot_polygon_images;

                            # if ($v->{ft_stitched_image}) {
                            #     $cell_html .= '<center><h5>FT High Pass</h5></center>'.$v->{ft_stitched_image}.'<br/><br/>';
                            #     $cell_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-image_id="'.$v->{stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($v->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'">Create/View Plot Polygons</button>';
                            # } else {
                            #     $cell_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_fourier_transform" data-image_id="'.$v->{stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($v->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'">Apply FT Low Pass</button><br/><br/>';
                            # }

                        } else {
                            $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_remove_background" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-denoised_stitched_image="'.uri_encode($d->{denoised_stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" >Remove Background</button><br/><br/>';
                        }

                    } else {
                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_denoise" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-cropped_stitched_image="'.uri_encode($d->{cropped_stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" >Denoise</button><br/><br/>';
                    }

                } else {
                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_crop_image" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" >Crop Stitched Image</button><br/><br/>';
                }
            } else {
                $drone_run_band_table_html .= '<button class="btn btn-primary" name="project_drone_imagery_stitch" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" >Stitch Uploaded Images</button>';
            }
            $drone_run_band_table_html .= '</td></tr>';

        }
        $drone_run_band_table_html .= '</tbody></table>';

        my $drone_run_date = $v->{drone_run_date} ? $calendar_funcs->display_start_date($v->{drone_run_date}) : '';
        my $drone_run_html = '<b>Name</b>: '.$v->{drone_run_project_name}.'<br/><b>Description</b>: '.$v->{drone_run_project_description}.'<br/><b>Date</b>: '.$drone_run_date;

        push @return, ["<a href=\"/breeders_toolbox/trial/$v->{trial_id}\">$v->{trial_name}</a>", $drone_run_html, $drone_run_band_table_html];
    }

    $c->stash->{rest} = { data => \@return };
}

sub raw_drone_imagery_stitch : Path('/ajax/drone_imagery/raw_drone_imagery_stitch') : ActionClass('REST') { }

sub raw_drone_imagery_stitch_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $raw_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'raw_drone_imagery', 'project_md_image')->cvterm_id();
    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_band_project_id_list=>[$drone_run_band_project_id],
        project_image_type_id=>$raw_drone_images_cvterm_id
    });
    my ($result, $total_count) = $images_search->search();
    #print STDERR Dumper $result;

    my $main_production_site = $c->config->{main_production_site_url};

    my @image_urls;
    foreach (@$result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_url = $image->get_image_url("original");
        push @image_urls, $main_production_site.$image_url;
    }
    print STDERR Dumper \@image_urls;
    my $image_urls_string = join ',', @image_urls;

    my $dir = $c->tempfiles_subdir('/stitched_drone_imagery');
    my $archive_stitched_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'stitched_drone_imagery/imageXXXX');
    $archive_stitched_temp_image .= '.png';
    print STDERR $archive_stitched_temp_image."\n";

    my $status = system('python /home/nmorales/cxgn/DroneImageScripts/ImageStitching/PanoramaStitch.py --images_urls '.$image_urls_string.' --outfile_path '.$archive_stitched_temp_image);

    my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);
    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $ret = $image->process_image($archive_stitched_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);

    $c->stash->{rest} = { data => \@image_urls };
}

sub drone_imagery_get_contours : Path('/ajax/drone_imagery/get_contours') : ActionClass('REST') { }

sub drone_imagery_get_contours_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $image_id = $c->req->param('image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $main_production_site = $c->config->{main_production_site_url};

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');
    print STDERR Dumper $image_url;
    print STDERR Dumper $image_fullpath;

    my $dir = $c->tempfiles_subdir('/drone_imagery_contours');
    my $archive_contours_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_contours/imageXXXX');
    $archive_contours_temp_image .= '.png';
    print STDERR $archive_contours_temp_image."\n";

    my $status = system('python /home/nmorales/cxgn/DroneImageScripts/GetContours.py --image_url '.$main_production_site.$image_url.' --outfile_path '.$archive_contours_temp_image);

    my @size = imgsize($archive_contours_temp_image);

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);
    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'contours_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $ret = $image->process_image($archive_contours_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
    my $contours_image_fullpath = $image->get_filename('original_converted', 'full');
    my $contours_image_url = $image->get_image_url('original');

    $c->stash->{rest} = { image_url => $image_url, image_fullpath => $image_fullpath, contours_image_url => $contours_image_url, contours_image_fullpath => $contours_image_fullpath, image_width => $size[0], image_height => $size[1] };
}

sub drone_imagery_assign_plot_polygons : Path('/ajax/drone_imagery/assign_plot_polygons') : ActionClass('REST') { }

sub drone_imagery_assign_plot_polygons_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $image_id = $c->req->param('image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $stock_polygons = $c->req->param('stock_polygons');

    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $main_production_site = $c->config->{main_production_site_url};

    my $polygon_objs = decode_json $stock_polygons;
    my %stock_ids;
    foreach my $stock_name (keys %$polygon_objs) {
        my $polygon = $polygon_objs->{$stock_name};
        if (scalar(@$polygon) != 5){
            $c->stash->{rest} = {error=>'Error: Polygon for '.$stock_name.'should be 5 long!'};
            $c->detach();
        }
        my $last_point = pop @$polygon;
        $polygon_objs->{$stock_name} = $polygon;

        my $stock = $schema->resultset("Stock::Stock")->find({uniquename => $stock_name});
        if (!$stock) {
            $c->stash->{rest} = {error=>'Error: Stock name '.$stock_name.' does not exist in the database!'};
            $c->detach();
        }
        $stock_ids{$stock_name} = $stock->stock_id;
    }

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');
    print STDERR Dumper $image_url;
    print STDERR Dumper $image_fullpath;

    my @plot_polygon_image_fullpaths;
    my @plot_polygon_image_urls;
    foreach my $stock_name (keys %$polygon_objs) {
        my $polygon = $polygon_objs->{$stock_name};
        my $polygons = encode_json [$polygon];
        my $stock_id = $stock_ids{$stock_name};

        my $dir = $c->tempfiles_subdir('/drone_imagery_plot_polygons');
        my $archive_plot_polygons_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_plot_polygons/imageXXXX');
        $archive_plot_polygons_temp_image .= '.png';
        print STDERR $archive_plot_polygons_temp_image."\n";

        my $cmd = "python /home/nmorales/cxgn/DroneImageScripts/CropToPolygon.py --inputfile_path $image_fullpath --outputfile_path $archive_plot_polygons_temp_image --polygon_json '$polygons'";
        print STDERR Dumper $cmd;
        my $status = system($cmd);

        $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
        $image->set_sp_person_id($user_id);
        my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_imagery', 'project_md_image')->cvterm_id();
        my $ret = $image->process_image($archive_plot_polygons_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
        my $stock_associate = $image->associate_stock($stock_id);
        my $plot_polygon_image_fullpath = $image->get_filename('original_converted', 'full');
        my $plot_polygon_image_url = $image->get_image_url('original');
        push @plot_polygon_image_fullpaths, $plot_polygon_image_fullpath;
        push @plot_polygon_image_urls, $plot_polygon_image_url;
    }
    print STDERR Dumper \@plot_polygon_image_fullpaths;
    print STDERR Dumper \@plot_polygon_image_urls;

    $c->stash->{rest} = { image_url => $image_url, image_fullpath => $image_fullpath };
}

sub drone_imagery_fourier_transform : Path('/ajax/drone_imagery/fourier_transform') : ActionClass('REST') { }

sub drone_imagery_fourier_transform_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $image_id = $c->req->param('image_id');
    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $main_production_site = $c->config->{main_production_site_url};

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');
    print STDERR Dumper $image_url;
    print STDERR Dumper $image_fullpath;

    my $dir = $c->tempfiles_subdir('/drone_imagery_fourier_transform');
    my $archive_fourier_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_fourier_transform/imageXXXX');
    $archive_fourier_temp_image .= '.png';
    print STDERR $archive_fourier_temp_image."\n";

    my $status = system('python /home/nmorales/cxgn/DroneImageScripts/ImageProcess/FourierTransform.py --image_path '.$image_fullpath.' --outfile_path '.$archive_fourier_temp_image);

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);
    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'fourier_transform_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $ret = $image->process_image($archive_fourier_temp_image, 'project', $drone_run_project_id, $linking_table_type_id);

    $c->stash->{rest} = { image_url => $image_url, image_fullpath => $image_fullpath };
}

sub drone_imagery_denoise : Path('/ajax/drone_imagery/denoise') : ActionClass('REST') { }

sub drone_imagery_denoise_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $image_id = $c->req->param('image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $main_production_site = $c->config->{main_production_site_url};

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');
    print STDERR Dumper $image_url;
    print STDERR Dumper $image_fullpath;

    my $dir = $c->tempfiles_subdir('/drone_imagery_denoise');
    my $archive_denoise_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_denoise/imageXXXX');
    $archive_denoise_temp_image .= '.png';
    print STDERR $archive_denoise_temp_image."\n";

    my $status = system('python /home/nmorales/cxgn/DroneImageScripts/ImageProcess/Denoise.py --image_path '.$image_fullpath.' --outfile_path '.$archive_denoise_temp_image);

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);
    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $ret = $image->process_image($archive_denoise_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
    my $denoised_image_fullpath = $image->get_filename('original_converted', 'full');
    my $denoised_image_url = $image->get_image_url('original');

    $c->stash->{rest} = { image_url => $image_url, image_fullpath => $image_fullpath, denoised_image_url => $denoised_image_url, denoised_image_fullpath => $denoised_image_fullpath };
}

sub drone_imagery_remove_background_display : Path('/ajax/drone_imagery/remove_background_display') : ActionClass('REST') { }

sub drone_imagery_remove_background_display_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $image_id = $c->req->param('image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $threshold = $c->req->param('threshold');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    if (!$threshold) {
        $c->stash->{rest} = {error => 'Please give a threshold'};
        $c->detach();
    }

    my $main_production_site = $c->config->{main_production_site_url};

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');
    print STDERR Dumper $image_url;
    print STDERR Dumper $image_fullpath;

    my $dir = $c->tempfiles_subdir('/drone_imagery_remove_background');
    my $archive_remove_background_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_remove_background/imageXXXX');
    $archive_remove_background_temp_image .= '.png';
    print STDERR $archive_remove_background_temp_image."\n";

    my $status = system('python /home/nmorales/cxgn/DroneImageScripts/ImageProcess/RemoveBackground.py --image_path '.$image_fullpath.' --outfile_path '.$archive_remove_background_temp_image.' --threshold '.$threshold);

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);
    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'background_removed_temporary_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $ret = $image->process_image($archive_remove_background_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
    my $removed_background_image_fullpath = $image->get_filename('original_converted', 'full');
    my $removed_background_image_url = $image->get_image_url('original');

    $c->stash->{rest} = { image_url => $image_url, image_fullpath => $image_fullpath, removed_background_image_url => $removed_background_image_url, removed_background_image_fullpath => $removed_background_image_fullpath };
}

sub drone_imagery_remove_background_save : Path('/ajax/drone_imagery/remove_background_save') : ActionClass('REST') { }

sub drone_imagery_remove_background_save_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $image_id = $c->req->param('image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $threshold = $c->req->param('threshold');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    if (!$threshold) {
        $c->stash->{rest} = {error => 'Please give a threshold'};
        $c->detach();
    }

    my $main_production_site = $c->config->{main_production_site_url};

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');
    print STDERR Dumper $image_url;
    print STDERR Dumper $image_fullpath;

    my $dir = $c->tempfiles_subdir('/drone_imagery_remove_background');
    my $archive_remove_background_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_remove_background/imageXXXX');
    $archive_remove_background_temp_image .= '.png';
    print STDERR $archive_remove_background_temp_image."\n";

    my $status = system('python /home/nmorales/cxgn/DroneImageScripts/ImageProcess/RemoveBackground.py --image_path '.$image_fullpath.' --outfile_path '.$archive_remove_background_temp_image.' --threshold '.$threshold);

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);
    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'background_removed_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $ret = $image->process_image($archive_remove_background_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
    my $removed_background_image_fullpath = $image->get_filename('original_converted', 'full');
    my $removed_background_image_url = $image->get_image_url('original');

    $c->stash->{rest} = { image_url => $image_url, image_fullpath => $image_fullpath, removed_background_image_url => $removed_background_image_url, removed_background_image_fullpath => $removed_background_image_fullpath };
}

sub get_drone_run_projects : Path('/ajax/drone_imagery/drone_runs') : ActionClass('REST') { }

sub get_drone_run_projects_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $checkbox_select_name = $c->req->param('select_checkbox_name');
    my $field_trial_id = $c->req->param('field_trial_id');

    my $project_start_date_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'project_start_date', 'project_property')->cvterm_id();
    my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'design', 'project_property')->cvterm_id();
    my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();

    my $where_clause = '';
    if ($field_trial_id) {
        $where_clause = ' WHERE field_trial.project_id = ? ';
    }

    my $q = "SELECT project.project_id, project.name, project.description, project_start_date.value, field_trial.project_id, field_trial.name, field_trial.description FROM project
        JOIN projectprop AS project_start_date ON (project.project_id=project_start_date.project_id AND project_start_date.type_id=$project_start_date_type_id)
        JOIN project_relationship ON (project.project_id = project_relationship.subject_project_id AND project_relationship.type_id=$project_relationship_type_id)
        JOIN project AS field_trial ON (field_trial.project_id=project_relationship.object_project_id)
        $where_clause
        ORDER BY project.project_id;";

    my $calendar_funcs = CXGN::Calendar->new({});

    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute($field_trial_id);
    my @result;
    while (my ($drone_run_project_id, $drone_run_project_name, $drone_run_project_description, $drone_run_date, $field_trial_project_id, $field_trial_project_name, $field_trial_project_description) = $h->fetchrow_array()) {
        my @res;
        if ($checkbox_select_name){
            push @res, "<input type='checkbox' name='$checkbox_select_name' value='$drone_run_project_id'>";
        }
        my $drone_run_date_display = $drone_run_date ? $calendar_funcs->display_start_date($drone_run_date) : '';
        push @res, (
            "<a href=\"/breeders_toolbox/trial/$drone_run_project_id\">$drone_run_project_name</a>",
            $drone_run_project_description,
            $drone_run_date_display,
            "<a href=\"/breeders_toolbox/trial/$field_trial_project_id\">$field_trial_project_name</a>",
            $field_trial_project_description
        );
        push @result, \@res;
    }

    $c->stash->{rest} = { data => \@result };
}


# jQuery('#drone_image_upload_drone_bands_table').DataTable({
#     destroy : true,
#     ajax : '/ajax/drone_imagery/drone_run_bands?select_checkbox_name=upload_drone_imagery_drone_run_band_select&drone_run_project_id='+drone_run_project_id
# });
sub get_drone_run_band_projects : Path('/ajax/drone_imagery/drone_run_bands') : ActionClass('REST') { }

sub get_drone_run_band_projects_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $checkbox_select_name = $c->req->param('select_checkbox_name');
    my $field_trial_id = $c->req->param('field_trial_id');
    my $drone_run_project_id = $c->req->param('drone_run_project_id');

    my $project_start_date_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'project_start_date', 'project_property')->cvterm_id();
    my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'design', 'project_property')->cvterm_id();
    my $drone_run_band_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
    my $drone_run_band_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();

    my $where_clause = '';
    if ($drone_run_project_id) {
        $where_clause = ' WHERE project.project_id = ? ';
    }

    my $q = "SELECT drone_run_band.project_id, drone_run_band.name, drone_run_band.description, drone_run_band_type.value, project.project_id, project.name, project.description, project_start_date.value, field_trial.project_id, field_trial.name, field_trial.description
        FROM project AS drone_run_band
        JOIN projectprop AS drone_run_band_type ON(drone_run_band.project_id=drone_run_band_type.project_id AND drone_run_band_type.type_id=$drone_run_band_type_cvterm_id)
        JOIN project_relationship AS drone_run_band_rel ON(drone_run_band.project_id=drone_run_band_rel.subject_project_id AND drone_run_band_rel.type_id=$drone_run_band_relationship_type_id)
        JOIN project ON (drone_run_band_rel.object_project_id = project.project_id)
        JOIN projectprop AS project_start_date ON (project.project_id=project_start_date.project_id AND project_start_date.type_id=$project_start_date_type_id)
        JOIN project_relationship ON (project.project_id = project_relationship.subject_project_id AND project_relationship.type_id=$project_relationship_type_id)
        JOIN project AS field_trial ON (field_trial.project_id=project_relationship.object_project_id)
        $where_clause
        ORDER BY project.project_id;";

    my $calendar_funcs = CXGN::Calendar->new({});

    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute($drone_run_project_id);
    my @result;
    while (my ($drone_run_band_project_id, $drone_run_band_name, $drone_run_band_description, $drone_run_band_type, $drone_run_project_id, $drone_run_project_name, $drone_run_project_description, $drone_run_date, $field_trial_project_id, $field_trial_project_name, $field_trial_project_description) = $h->fetchrow_array()) {
        my @res;
        if ($checkbox_select_name){
            push @res, "<input type='checkbox' name='$checkbox_select_name' value='$drone_run_band_project_id'>";
        }
        my $drone_run_date_display = $drone_run_date ? $calendar_funcs->display_start_date($drone_run_date) : '';
        push @res, (
            $drone_run_band_name,
            $drone_run_band_description,
            $drone_run_band_type,
            $drone_run_project_name,
            $drone_run_project_description,
            $drone_run_date_display,
            "<a href=\"/breeders_toolbox/trial/$field_trial_project_id\">$field_trial_project_name</a>",
            $field_trial_project_description
        );
        push @result, \@res;
    }

    $c->stash->{rest} = { data => \@result };
}

sub drone_imagery_get_image : Path('/ajax/drone_imagery/get_image') : ActionClass('REST') { }

sub drone_imagery_get_image_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $image_id = $c->req->param('image_id');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $main_production_site = $c->config->{main_production_site_url};

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');
    print STDERR Dumper $image_url;
    print STDERR Dumper $image_fullpath;

    $c->stash->{rest} = { image_url => $image_url, image_fullpath => $image_fullpath };
}

sub drone_imagery_remove_image : Path('/ajax/drone_imagery/remove_image') : ActionClass('REST') { }

sub drone_imagery_remove_image_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $image_id = $c->req->param('image_id');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $main_production_site = $c->config->{main_production_site_url};

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $resp = $image->delete(); #Sets to obsolete

    $c->stash->{rest} = { status => $resp };
}

sub drone_imagery_crop_image : Path('/ajax/drone_imagery/crop_image') : ActionClass('REST') { }

sub drone_imagery_crop_image_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $image_id = $c->req->param('image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $polygon = $c->req->param('polygon');
    my $polygon_obj = decode_json $polygon;
    if (scalar(@$polygon_obj) != 4){
        $c->stash->{rest} = {error=>'Polygon should be 4 long!'};
        $c->detach();
    }
    my $polygons = encode_json [$polygon_obj];
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $main_production_site = $c->config->{main_production_site_url};

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');
    print STDERR Dumper $image_url;
    print STDERR Dumper $image_fullpath;

    my $dir = $c->tempfiles_subdir('/drone_imagery_cropped_image');
    my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_cropped_image/imageXXXX');
    $archive_temp_image .= '.png';
    print STDERR $archive_temp_image."\n";

    my $cmd = "python /home/nmorales/cxgn/DroneImageScripts/CropToPolygon.py --inputfile_path $image_fullpath --outputfile_path $archive_temp_image --polygon_json '$polygons'";
    my $status = system($cmd);

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);
    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cropped_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $ret = $image->process_image($archive_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
    my $cropped_image_fullpath = $image->get_filename('original_converted', 'full');
    my $cropped_image_url = $image->get_image_url('original');

    $c->stash->{rest} = { image_url => $image_url, image_fullpath => $image_fullpath, cropped_image_url => $cropped_image_url, cropped_image_fullpath => $cropped_image_fullpath };
}

sub drone_imagery_get_plot_polygon_images : Path('/ajax/drone_imagery/get_plot_polygon_images') : ActionClass('REST') { }

sub drone_imagery_get_plot_polygon_images_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $main_production_site = $c->config->{main_production_site_url};

    my $plot_polygons_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_imagery', 'project_md_image')->cvterm_id();
    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_band_project_id_list=>[$drone_run_band_project_id],
        project_image_type_id=>$plot_polygons_images_cvterm_id
    });
    my ($result, $total_count) = $images_search->search();
    #print STDERR Dumper $result;

    my @image_paths;
    my @image_urls;
    foreach (@$result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_url = $image->get_image_url("original");
        my $image_fullpath = $image->get_filename('original_converted', 'full');
        push @image_urls, $image_url;
        push @image_paths, $image_fullpath;
    }

    $c->stash->{rest} = { image_urls => \@image_urls };
}

sub drone_imagery_calculate_phenotypes : Path('/ajax/drone_imagery/calculate_phenotypes') : ActionClass('REST') { }

sub drone_imagery_calculate_phenotypes_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $phenotype_method = $c->req->param('method');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $main_production_site = $c->config->{main_production_site_url};

    my $plot_polygons_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_imagery', 'project_md_image')->cvterm_id();
    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_band_project_id_list=>[$drone_run_band_project_id],
        project_image_type_id=>$plot_polygons_images_cvterm_id
    });
    my ($result, $total_count) = $images_search->search();
    #print STDERR Dumper $result;

    my $temp_images_subdir = '';
    my $temp_results_subdir = '';
    my $calculate_phenotypes_script = '';
    my $linking_table_type_id;
    if ($phenotype_method eq 'sift') {
        $temp_images_subdir = 'drone_imagery_calc_phenotypes_sift';
        $temp_results_subdir = 'drone_imagery_calc_phenotypes_sift_results';
        $calculate_phenotypes_script = 'CalculatePhenotypeSift.py';
        $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_phenotypes_sift_drone_imagery', 'project_md_image')->cvterm_id();
    } elsif ($phenotype_method eq 'orb') {
        $temp_images_subdir = 'drone_imagery_calc_phenotypes_orb';
        $temp_results_subdir = 'drone_imagery_calc_phenotypes_orb_results';
        $calculate_phenotypes_script = 'CalculatePhenotypeOrb.py';
        $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_phenotypes_orb_drone_imagery', 'project_md_image')->cvterm_id();
    } elsif ($phenotype_method eq 'surf') {
        $temp_images_subdir = 'drone_imagery_calc_phenotypes_surf';
        $temp_results_subdir = 'drone_imagery_calc_phenotypes_surf_results';
        $calculate_phenotypes_script = 'CalculatePhenotypeSurf.py';
        $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_phenotypes_surf_drone_imagery', 'project_md_image')->cvterm_id();
    }

    my @image_paths;
    my @out_paths;
    my @stocks;
    foreach (@$result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_url = $image->get_image_url("original");
        my $image_fullpath = $image->get_filename('original_converted', 'full');
        push @image_paths, $image_fullpath;

        my $dir = $c->tempfiles_subdir('/'.$temp_images_subdir);
        my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => $temp_images_subdir.'/imageXXXX');
        $archive_temp_image .= '.png';
        push @out_paths, $archive_temp_image;

        push @stocks, {
            stock_id => $_->{stock_id},
            stock_uniquename => $_->{stock_uniquename},
            stock_type_id => $_->{stock_type_id},
        };
    }
    print STDERR Dumper \@image_paths;
    my $image_paths_string = join ',', @image_paths;
    my $out_paths_string = join ',', @out_paths;

    my $dir = $c->tempfiles_subdir('/'.$temp_results_subdir);
    my $archive_temp_sift_results = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => $temp_results_subdir.'/imageXXXX');

    my $status = system('python /home/nmorales/cxgn/DroneImageScripts/ImageProcess/'.$calculate_phenotypes_script.' --image_paths '.$image_paths_string.' --outfile_paths '.$out_paths_string);

    my @pheno_image_info;
    my $count = 0;
    foreach (@out_paths) {
        my $stock = $stocks[$count];

        my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
        $image->set_sp_person_id($user_id);
        my $ret = $image->process_image($_, 'project', $drone_run_band_project_id, $linking_table_type_id);
        my $ret = $image->associate_stock($stock->{stock_id});
        my $image_fullpath = $image->get_filename('original_converted', 'full');
        my $image_url = $image->get_image_url('original');

        my $image_source_tag_small = $image->get_img_src_tag("tiny");
        $count++;
        
        push @pheno_image_info, {
            stock_id => $stock->{stock_id},
            stock_uniquename => $stock->{stock_uniquename},
            image => '<a href="/image/view/'.$image->get_image_id.'" target="_blank">'.$image_source_tag_small.'</a>',
            image_path => $image_fullpath,
            image_url => $image_url
        };
    }

    $c->stash->{rest} = { images => \@pheno_image_info };
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
