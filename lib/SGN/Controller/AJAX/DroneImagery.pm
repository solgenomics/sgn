
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
use Text::CSV;
use CXGN::Phenotypes::StorePhenotypes;
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
    my $new_drone_run_type = $c->req->param('drone_image_upload_drone_run_type');
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
        my $drone_run_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_project_type', 'project_property')->cvterm_id();
        my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
        my $project_rs = $schema->resultset("Project::Project")->create({
            name => $new_drone_run_name,
            description => $new_drone_run_desc,
            projectprops => [{type_id => $drone_run_type_cvterm_id, value => $new_drone_run_type},{type_id => $project_start_date_type_id, value => $drone_run_event}, {type_id => $design_cvterm_id, value => 'drone_run'}],
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
    #print STDERR Dumper $stitched_result;

    my $cropped_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cropped_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $cropped_stitched_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$cropped_stitched_drone_images_cvterm_id
    });
    my ($cropped_stitched_result, $cropped_stitched_total_count) = $cropped_stitched_images_search->search();
    #print STDERR Dumper $cropped_stitched_result;

    my $rotated_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'rotated_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $rotated_stitched_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$rotated_stitched_drone_images_cvterm_id
    });
    my ($rotated_stitched_result, $rotated_stitched_total_count) = $rotated_stitched_images_search->search();
    #print STDERR Dumper $rotated_stitched_result;

    my $denoised_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $denoised_stitched_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$denoised_stitched_drone_images_cvterm_id
    });
    my ($denoised_stitched_result, $denoised_stitched_total_count) = $denoised_stitched_images_search->search();
    #print STDERR Dumper $denoised_stitched_result;

    my $vegetative_index_tgi_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_tgi_drone_imagery', 'project_md_image')->cvterm_id();
    my $vegetative_index_tgi_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$vegetative_index_tgi_drone_images_cvterm_id
    });
    my ($vegetative_index_tgi_result, $vegetative_index_tgi_total_count) = $vegetative_index_tgi_images_search->search();
    #print STDERR Dumper $vegetative_index_tgi_result;

    my $background_removed_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'background_removed_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $background_removed_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$background_removed_drone_images_cvterm_id
    });
    my ($background_removed_result, $background_removed_total_count) = $background_removed_images_search->search();
    #print STDERR Dumper $background_removed_result;

    my $background_removed_tgi_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'background_removed_tgi_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $background_removed_tgi_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$background_removed_tgi_drone_images_cvterm_id
    });
    my ($background_removed_tgi_result, $background_removed_tgi_total_count) = $background_removed_tgi_images_search->search();
    #print STDERR Dumper $background_removed_tgi_result;

    # my $ft_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'fourier_transform_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    # my $ft_stitched_images_search = CXGN::DroneImagery::ImagesSearch->new({
    #     bcs_schema=>$schema,
    #     project_image_type_id=>$ft_stitched_drone_images_cvterm_id
    # });
    # my ($ft_stitched_result, $ft_stitched_total_count) = $ft_stitched_images_search->search();
    #print STDERR Dumper $ft_stitched_result;

    my $plot_polygon_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygons_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$plot_polygon_stitched_drone_images_cvterm_id
    });
    my ($plot_polygons_result, $plot_polygons_total_count) = $plot_polygons_images_search->search();
    #print STDERR Dumper $plot_polygons_result;

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
        $unique_drone_runs{$_->{drone_run_project_id}}->{drone_run_type} = $_->{drone_run_type};
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
        $unique_drone_runs{$_->{drone_run_project_id}}->{drone_run_type} = $_->{drone_run_type};
        $unique_drone_runs{$_->{drone_run_project_id}}->{drone_run_project_description} = $_->{drone_run_project_description};
    }
    foreach (@$rotated_stitched_result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_source_tag_small = $image->get_img_src_tag("thumbnail");
        my $image_original = $image->get_image_url("original");
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{rotated_stitched_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{rotated_stitched_image_username} = $_->{username};
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{rotated_stitched_image_modified_date} = $_->{image_modified_date};
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{rotated_stitched_image_original} = $image_original;
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{rotated_stitched_image_id} = $image_id;
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{rotated_stitched_image_angle} = $_->{drone_run_band_rotate_angle};
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
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{cropped_stitched_image_polygon} = $_->{drone_run_band_cropped_polygon};
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
    foreach (@$vegetative_index_tgi_result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_source_tag_small = $image->get_img_src_tag("thumbnail");
        my $image_original = $image->get_image_url("original");
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{vegetative_index_tgi_stitched_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{vegetative_index_tgi_username} = $_->{username};
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{vegetative_index_tgi_modified_date} = $_->{image_modified_date};
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{vegetative_index_tgi_image_original} = $image_original;
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{vegetative_index_tgi_image_id} = $image_id;
    }
    foreach (@$background_removed_tgi_result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_source_tag_small = $image->get_img_src_tag("thumbnail");
        my $image_original = $image->get_image_url("original");
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{background_removed_tgi_stitched_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{background_removed_tgi_stitched_image_username} = $_->{username};
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{background_removed_tgi_stitched_image_modified_date} = $_->{image_modified_date};
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{background_removed_tgi_stitched_image_original} = $image_original;
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{background_removed_tgi_stitched_image_id} = $image_id;
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{background_removed_tgi_stitched_image_threshold} = $_->{drone_run_band_removed_background_tgi_threshold};
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
    # foreach (@$ft_stitched_result) {
    #     my $image_id = $_->{image_id};
    #     my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    #     my $image_source_tag_small = $image->get_img_src_tag("thumbnail");
    #     my $image_original = $image->get_image_url("original");
    #     $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{ft_stitched_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
    #     $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{ft_stitched_image_username} = $_->{username};
    #     $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{ft_stitched_image_original} = $image_original;
    #     $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{ft_stitched_image_id} = $image_id;
    # }
    foreach (@$plot_polygons_result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_source_tag_tiny = $image->get_img_src_tag("tiny");
        my $image_original = $image->get_image_url("original");
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_plot_polygons} = $_->{drone_run_band_plot_polygons};
        push @{$unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{plot_polygon_images}}, '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
    }
    #print STDERR Dumper \%unique_drone_runs;

    my $calendar_funcs = CXGN::Calendar->new({});
    foreach my $k (sort keys %unique_drone_runs) {
        my $v = $unique_drone_runs{$k};

        my $drone_run_bands = $v->{bands};

        my $drone_run_band_table_html = '<table class="table table-bordered"><thead><tr><th>Drone Run Band(s)</th><th>Images/Actions</th></thead><tbody>';

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

                if ($d->{rotated_stitched_image}) {
                    $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-6"><h5>Rotated Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{rotated_stitched_image_id}.'"></span></h5><b>By</b>: '.$d->{rotated_stitched_image_username}.'<br/><b>Date</b>: '.$d->{rotated_stitched_image_modified_date}.'<br/><b>Rotated Angle</b>: '.$d->{rotated_stitched_image_angle}.'</div><div class="col-sm-6">'.$d->{rotated_stitched_image}.'</div></div></div>';

                    if ($d->{cropped_stitched_image}) {
                        $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-6"><h5>Cropped Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{cropped_stitched_image_id}.'"></span></h5><b>By</b>: '.$d->{cropped_stitched_image_username}.'<br/><b>Date</b>: '.$d->{cropped_stitched_image_modified_date}.'<br/><b>Cropped Polygon</b>: '.$d->{cropped_stitched_image_polygon}.'</div><div class="col-sm-6">'.$d->{cropped_stitched_image}.'</div></div></div>';

                        if ($d->{denoised_stitched_image}) {
                            $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-6"><h5>Denoised Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{denoised_stitched_image_id}.'"></span></h5><b>By</b>: '.$d->{denoised_stitched_image_username}.'</br><b>Date</b>: '.$d->{denoised_stitched_image_modified_date}.'</div><div class="col-sm-6">'.$d->{denoised_stitched_image}.'</div></div></div>';

                            $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_add_georeference" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" >Add Georeferenced Points</button><br/><br/>';

                            if ($d->{vegetative_index_tgi_stitched_image}) {
                                $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-6"><h5>TGI Vegetative Index Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{vegetative_index_tgi_image_id}.'"></span></h5><b>By</b>: '.$d->{vegetative_index_tgi_username}.'</br><b>Date</b>: '.$d->{vegetative_index_tgi_modified_date}.'</div><div class="col-sm-6">'.$d->{vegetative_index_tgi_stitched_image}.'</div></div></div>';

                                if ($d->{background_removed_tgi_stitched_image}) {
                                    $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-6"><h5>Background Removed TGI Vegetative Index Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{background_removed_tgi_stitched_image_id}.'"></span></h5><b>By</b>: '.$d->{background_removed_tgi_stitched_image_username}.'</br><b>Date</b>: '.$d->{background_removed_tgi_stitched_image_modified_date}.'<br/><b>Background Removed Threshold</b>: '.$d->{background_removed_tgi_stitched_image_threshold}.'</div><div class="col-sm-6">'.$d->{background_removed_tgi_stitched_image}.'</div></div></div>';

                                    if ($d->{background_removed_stitched_image}) {
                                        $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-6"><h5>Background Removed TGI Vegetative Index Mask on Denoised Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{background_removed_stitched_image_id}.'"></span></h5><b>By</b>: '.$d->{background_removed_stitched_image_username}.'</br><b>Date</b>: '.$d->{background_removed_stitched_image_modified_date}.'</div><div class="col-sm-6">'.$d->{background_removed_stitched_image}.'</div></div></div>';
                                        
                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{background_removed_stitched_image_id}.'" >Create/View Plot Polygons</button>';

                                        $drone_run_band_table_html .= '<hr>';
                                        my $plot_polygon_images = '';
                                        if ($d->{plot_polygon_images}) {
                                            $plot_polygon_images = scalar(@{$d->{plot_polygon_images}})." Plot Polygons<br/><span>";
                                            $plot_polygon_images .= join '', @{$d->{plot_polygon_images}};
                                            $plot_polygon_images .= "</span>";
                                            $plot_polygon_images .= '<br/><br/>';
                                            $plot_polygon_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" >Calculate Phenotypes</button>';
                                        } else {
                                            $plot_polygon_images = 'No Plot Polygons Assigned';
                                        }
                                        $drone_run_band_table_html .= $plot_polygon_images;
                                    } else {
                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_apply_tgi_removed_background_mask_to_denoised_image" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-vegetative_index_tgi_image_id="'.$d->{vegetative_index_tgi_image_id}.'" data-background_removed_tgi_stitched_image_id="'.$d->{background_removed_tgi_stitched_image_id}.'" >Remove Background From Denoised Image</button><br/><br/>';
                                    }
                                } else {
                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_remove_background" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-denoised_stitched_image="'.uri_encode($d->{denoised_stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-remove_background_current_image_id="'.$d->{vegetative_index_tgi_image_id}.'" data-remove_background_current_image_type="TGI" >TGI Vegetative Index Remove Background</button><br/><br/>';
                                }
                            } else {
                                if ($d->{drone_run_band_project_type} eq 'RGB Color Image') {
                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_rgb_vegetative" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-denoised_stitched_image="'.uri_encode($d->{denoised_stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'">Convert to Vegetative Index</button><br/><br/>';
                                } else {
                                    $drone_run_band_table_html .= '<button class="btn btn-default btn-sm disabled">Vegetative index cannot be calculated on an image with a single channel.<br/>You can merge bands into a multi-channel image using the "Merge Drone Run Bands" button below this table</button><br/><br/>';

                                    if ($d->{background_removed_stitched_image}) {
                                        $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-6"><h5>Background Removed Denoised Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{background_removed_stitched_image_id}.'"></span></h5><b>By</b>: '.$d->{background_removed_stitched_image_username}.'</br><b>Date</b>: '.$d->{background_removed_stitched_image_modified_date}.'</div><div class="col-sm-6">'.$d->{background_removed_stitched_image}.'</div></div></div>';
                                        
                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{background_removed_stitched_image_id}.'" >Create/View Plot Polygons</button>';

                                        $drone_run_band_table_html .= '<hr>';
                                        my $plot_polygon_images = '';
                                        if ($d->{plot_polygon_images}) {
                                            $plot_polygon_images = scalar(@{$d->{plot_polygon_images}})." Plot Polygons<br/><span>";
                                            $plot_polygon_images .= join '', @{$d->{plot_polygon_images}};
                                            $plot_polygon_images .= "</span>";
                                            $plot_polygon_images .= '<br/><br/><button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" >Calculate Phenotypes</button>';
                                        } else {
                                            $plot_polygon_images = 'No Plot Polygons Assigned';
                                        }
                                        $drone_run_band_table_html .= $plot_polygon_images;
                                    } else {
                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_remove_background" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-denoised_stitched_image="'.uri_encode($d->{denoised_stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-remove_background_current_image_id="'.$d->{denoised_stitched_image_id}.'" data-remove_background_current_image_type="Single Band" >Remove Background From Denoised Image</button><br/><br/>';
                                    }
                                }
                            }
                        } else {
                            $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_denoise" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-cropped_stitched_image="'.uri_encode($d->{cropped_stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" >Denoise</button><br/><br/>';
                        }
                    } else {
                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_crop_image" data-rotated_stitched_image_id="'.$d->{rotated_stitched_image_id}.'" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" >Crop Rotated Image</button><br/><br/>';
                    }
                } else {
                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_rotate_image" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" >Rotate Stitched Image</button><br/><br/>';
                }
            } else {
                $drone_run_band_table_html .= '<button class="btn btn-primary" name="project_drone_imagery_stitch" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" >Stitch Uploaded Images</button>';
            }
            $drone_run_band_table_html .= '</td></tr>';

        }
        $drone_run_band_table_html .= '</tbody></table>';

        my $drone_run_date = $v->{drone_run_date} ? $calendar_funcs->display_start_date($v->{drone_run_date}) : '';
        my $drone_run_html = '<div class="well well-sm"><b>Drone Run Name</b>: '.$v->{drone_run_project_name}.'<br/><b>Drone Run Type</b>: '.$v->{drone_run_type}.'<br/><b>Description</b>: '.$v->{drone_run_project_description}.'<br/><b>Date</b>: '.$drone_run_date;
        $drone_run_html .= "<br/><b>Field Trial</b>: <a href=\"/breeders_toolbox/trial/$v->{trial_id}\">$v->{trial_name}</a></div>";
        $drone_run_html .= $drone_run_band_table_html;
        $drone_run_html .= '<button class="btn btn-primary" name="project_drone_imagery_merge_channels" data-drone_run_project_id="'.$k.'" data-drone_run_project_name="'.$v->{drone_run_project_name}.'" >Merge Drone Run Bands For '.$v->{drone_run_project_name}.'</button><br/><br/>';

        push @return, [$drone_run_html];
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

    my $status = system('python /home/nmorales/cxgn/DroneImageScripts/ImageStitching/PanoramaStitch.py --images_urls \''.$image_urls_string.'\' --outfile_path \''.$archive_stitched_temp_image.'\'');

    my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);
    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $ret = $image->process_image($archive_stitched_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);

    $c->stash->{rest} = { data => \@image_urls };
}

sub drone_imagery_rotate_image : Path('/ajax/drone_imagery/rotate_image') : ActionClass('REST') { }

sub drone_imagery_rotate_image_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $image_id = $c->req->param('image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $angle_rotation = $c->req->param('angle');
    my $view_only = $c->req->param('view_only');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');
    print STDERR Dumper $image_url;
    print STDERR Dumper $image_fullpath;

    my $dir = $c->tempfiles_subdir('/drone_imagery_rotate');
    my $archive_rotate_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_rotate/imageXXXX');
    $archive_rotate_temp_image .= '.png';
    print STDERR $archive_rotate_temp_image."\n";

    my $cmd = 'python /home/nmorales/cxgn/DroneImageScripts/ImageProcess/Rotate.py --image_path \''.$image_fullpath.'\' --outfile_path \''.$archive_rotate_temp_image.'\' --angle '.$angle_rotation;
    print STDERR $cmd."\n";
    my $status = system($cmd);

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);

    my $linking_table_type_id;
    if ($view_only) {
        $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'rotated_stitched_temporary_drone_imagery', 'project_md_image')->cvterm_id();
    } else {
        my $rotated_stitched_temporary_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'rotated_stitched_temporary_drone_imagery', 'project_md_image')->cvterm_id();
        my $rotated_stitched_temporary_images_search = CXGN::DroneImagery::ImagesSearch->new({
            bcs_schema=>$schema,
            project_image_type_id=>$rotated_stitched_temporary_drone_images_cvterm_id,
            drone_run_band_project_id_list=>[$drone_run_band_project_id]
        });
        my ($rotated_stitched_temporary_result, $rotated_stitched_temporary_total_count) = $rotated_stitched_temporary_images_search->search();
        print STDERR Dumper $rotated_stitched_temporary_total_count;
        
        $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'rotated_stitched_drone_imagery', 'project_md_image')->cvterm_id();

        my $drone_run_band_rotate_angle_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_rotate_angle', 'project_property')->cvterm_id();
        my $drone_run_band_rotate_angle = $schema->resultset('Project::Projectprop')->update_or_create({
            type_id=>$drone_run_band_rotate_angle_type_id,
            project_id=>$drone_run_band_project_id,
            rank=>0,
            value=>$angle_rotation
        },
        {
            key=>'projectprop_c1'
        });
    }
    my $ret = $image->process_image($archive_rotate_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
    my $rotated_image_fullpath = $image->get_filename('original_converted', 'full');
    my $rotated_image_url = $image->get_image_url('original');

    $c->stash->{rest} = { image_url => $image_url, image_fullpath => $image_fullpath, rotated_image_url => $rotated_image_url, rotated_image_fullpath => $rotated_image_fullpath };
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

    my $status = system('python /home/nmorales/cxgn/DroneImageScripts/GetContours.py --image_url \''.$main_production_site.$image_url.'\' --outfile_path \''.$archive_contours_temp_image.'\'');

    my @size = imgsize($archive_contours_temp_image);

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);
    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'contours_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $ret = $image->process_image($archive_contours_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
    my $contours_image_fullpath = $image->get_filename('original_converted', 'full');
    my $contours_image_url = $image->get_image_url('original');

    $c->stash->{rest} = { image_url => $image_url, image_fullpath => $image_fullpath, contours_image_url => $contours_image_url, contours_image_fullpath => $contours_image_fullpath, image_width => $size[0], image_height => $size[1] };
}

sub drone_imagery_retrieve_parameter_template : Path('/ajax/drone_imagery/retrieve_parameter_template') : ActionClass('REST') { }

sub drone_imagery_retrieve_parameter_template_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $template_projectprop_id = $c->req->param('plot_polygons_template_projectprop_id');

    my $rs = $schema->resultset("Project::Projectprop")->find({projectprop_id => $template_projectprop_id});
    my $plot_polygons = decode_json $rs->value;
    #print STDERR Dumper $plot_polygons;

    $c->stash->{rest} = {
        success => 1,
        parameter => $plot_polygons
    };
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

        my $cmd = "python /home/nmorales/cxgn/DroneImageScripts/CropToPolygon.py --inputfile_path '$image_fullpath' --outputfile_path '$archive_plot_polygons_temp_image' --polygon_json '$polygons'";
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

    my $drone_run_band_plot_polygons_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_plot_polygons', 'project_property')->cvterm_id();
    my $previous_plot_polygons_rs = $schema->resultset('Project::Projectprop')->search({type_id=>$drone_run_band_plot_polygons_type_id, project_id=>$drone_run_band_project_id});
    if ($previous_plot_polygons_rs->count > 1) {
        die "There should not be more than one saved entry for plot polygons for a drone run band";
    }

    my $save_stock_polygons;
    if ($previous_plot_polygons_rs->count > 0) {
        $save_stock_polygons = decode_json $previous_plot_polygons_rs->first->value;
    }
    foreach my $stock_name (keys %$polygon_objs) {
        $save_stock_polygons->{$stock_name} = $polygon_objs->{$stock_name};
    }

    my $drone_run_band_plot_polygons = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$drone_run_band_plot_polygons_type_id,
        project_id=>$drone_run_band_project_id,
        rank=>0,
        value=> encode_json($save_stock_polygons)
    },
    {
        key=>'projectprop_c1'
    });

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

    my $status = system('python /home/nmorales/cxgn/DroneImageScripts/ImageProcess/FourierTransform.py --image_path \''.$image_fullpath.'\' --outfile_path \''.$archive_fourier_temp_image.'\'');

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

    my $status = system('python /home/nmorales/cxgn/DroneImageScripts/ImageProcess/Denoise.py --image_path \''.$image_fullpath.'\' --outfile_path \''.$archive_denoise_temp_image.'\'');

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

    my $status = system('python /home/nmorales/cxgn/DroneImageScripts/ImageProcess/RemoveBackground.py --image_path \''.$image_fullpath.'\' --outfile_path \''.$archive_remove_background_temp_image.'\' --threshold '.$threshold);

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
    my $image_type = $c->req->param('image_type');
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

    my $status = system('python /home/nmorales/cxgn/DroneImageScripts/ImageProcess/RemoveBackground.py --image_path \''.$image_fullpath.'\' --outfile_path \''.$archive_remove_background_temp_image.'\' --threshold '.$threshold);

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);

    my $linking_table_type_id;
    my $drone_run_band_remove_background_threshold_type_id;
    if ($image_type eq 'TGI') {
        $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'background_removed_tgi_stitched_drone_imagery', 'project_md_image')->cvterm_id();
        $drone_run_band_remove_background_threshold_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_background_removed_tgi_threshold', 'project_property')->cvterm_id();
    } else {
        $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'background_removed_stitched_drone_imagery', 'project_md_image')->cvterm_id();
        $drone_run_band_remove_background_threshold_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_background_removed_threshold', 'project_property')->cvterm_id();
    }
    my $ret = $image->process_image($archive_remove_background_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
    my $removed_background_image_fullpath = $image->get_filename('original_converted', 'full');
    my $removed_background_image_url = $image->get_image_url('original');

    my $drone_run_band_remove_background_threshold = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$drone_run_band_remove_background_threshold_type_id,
        project_id=>$drone_run_band_project_id,
        rank=>0,
        value=>$threshold
    },
    {
        key=>'projectprop_c1'
    });

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
    my $drone_run_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_project_type', 'project_property')->cvterm_id();
    my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();

    my $where_clause = '';
    if ($field_trial_id) {
        $where_clause = ' WHERE field_trial.project_id = ? ';
    }

    my $q = "SELECT project.project_id, project.name, project.description, drone_run_type.value, project_start_date.value, field_trial.project_id, field_trial.name, field_trial.description FROM project
        JOIN projectprop AS project_start_date ON (project.project_id=project_start_date.project_id AND project_start_date.type_id=$project_start_date_type_id)
        LEFT JOIN projectprop AS drone_run_type ON (project.project_id=drone_run_type.project_id AND drone_run_type.type_id=$drone_run_project_type_cvterm_id)
        JOIN project_relationship ON (project.project_id = project_relationship.subject_project_id AND project_relationship.type_id=$project_relationship_type_id)
        JOIN project AS field_trial ON (field_trial.project_id=project_relationship.object_project_id)
        $where_clause
        ORDER BY project.project_id;";

    my $calendar_funcs = CXGN::Calendar->new({});

    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute($field_trial_id);
    my @result;
    while (my ($drone_run_project_id, $drone_run_project_name, $drone_run_project_description, $drone_run_type, $drone_run_date, $field_trial_project_id, $field_trial_project_name, $field_trial_project_description) = $h->fetchrow_array()) {
        my @res;
        if ($checkbox_select_name){
            push @res, "<input type='checkbox' name='$checkbox_select_name' value='$drone_run_project_id'>";
        }
        my $drone_run_date_display = $drone_run_date ? $calendar_funcs->display_start_date($drone_run_date) : '';
        push @res, (
            "<a href=\"/breeders_toolbox/trial/$drone_run_project_id\">$drone_run_project_name</a>",
            $drone_run_type,
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
    my $size = $c->req->param('size') || 'original';
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $main_production_site = $c->config->{main_production_site_url};

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url($size);
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

    my $cmd = "python /home/nmorales/cxgn/DroneImageScripts/CropToPolygon.py --inputfile_path '$image_fullpath' --outputfile_path '$archive_temp_image' --polygon_json '$polygons'";
    my $status = system($cmd);

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);
    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cropped_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $ret = $image->process_image($archive_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
    my $cropped_image_fullpath = $image->get_filename('original_converted', 'full');
    my $cropped_image_url = $image->get_image_url('original');

    my $drone_run_band_cropped_polygon_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_cropped_polygon', 'project_property')->cvterm_id();
    my $drone_run_band_cropped_polygon = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$drone_run_band_cropped_polygon_type_id,
        project_id=>$drone_run_band_project_id,
        rank=>0,
        value=>$polygons
    },
    {
        key=>'projectprop_c1'
    });

    $c->stash->{rest} = { image_url => $image_url, image_fullpath => $image_fullpath, cropped_image_url => $cropped_image_url, cropped_image_fullpath => $cropped_image_fullpath };
}

sub drone_imagery_calculate_rgb_vegetative_index : Path('/ajax/drone_imagery/calculate_rgb_vegetative_index') : ActionClass('REST') { }

sub drone_imagery_calculate_rgb_vegetative_index_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $image_id = $c->req->param('image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $vegetative_index = $c->req->param('vegetative_index');
    my $drone_run_band_project_type = $c->req->param('drone_run_band_project_type');
    my $view_only = $c->req->param('view_only');

    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $index_script = '';
    my $linking_table_type_id;
    if ($vegetative_index eq 'TGI') {
        $index_script = 'TGI';
        if ($view_only == 1){
            $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_tgi_temporary_drone_imagery', 'project_md_image')->cvterm_id();
        } else {
            $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_tgi_drone_imagery', 'project_md_image')->cvterm_id();
        }
    }
    if ($vegetative_index eq 'VARI') {
        $index_script = 'VARI';
        if ($view_only == 1){
            $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_vari_temporary_drone_imagery', 'project_md_image')->cvterm_id();
        } else {
            $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_vari_drone_imagery', 'project_md_image')->cvterm_id();
        }
    }

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');
    print STDERR Dumper $image_url;
    print STDERR Dumper $image_fullpath;

    my $dir = $c->tempfiles_subdir('/drone_imagery_vegetative_index_image');
    my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_vegetative_index_image/imageXXXX');
    $archive_temp_image .= '.png';
    print STDERR $archive_temp_image."\n";

    my $cmd = "python /home/nmorales/cxgn/DroneImageScripts/VegetativeIndex/$index_script.py --image_path '$image_fullpath' --outfile_path '$archive_temp_image'";
    my $status = system($cmd);

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);

    my $ret = $image->process_image($archive_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
    my $index_image_fullpath = $image->get_filename('original_converted', 'full');
    my $index_image_url = $image->get_image_url('original');

    $c->stash->{rest} = { image_url => $image_url, image_fullpath => $image_fullpath, index_image_url => $index_image_url, index_image_fullpath => $index_image_fullpath };
}

sub drone_imagery_mask_remove_background : Path('/ajax/drone_imagery/mask_remove_background') : ActionClass('REST') { }

sub drone_imagery_mask_remove_background_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    print STDERR Dumper $c->req->params;
    my $image_id = $c->req->param('image_id');
    my $mask_image_id = $c->req->param('mask_image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');

    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');
    print STDERR Dumper $image_url;
    print STDERR Dumper $image_fullpath;

    my $mask_image = SGN::Image->new( $schema->storage->dbh, $mask_image_id, $c );
    my $mask_image_url = $mask_image->get_image_url("original");
    my $mask_image_fullpath = $mask_image->get_filename('original_converted', 'full');
    print STDERR Dumper $mask_image_url;
    print STDERR Dumper $mask_image_fullpath;

    my $dir = $c->tempfiles_subdir('/drone_imagery_mask_remove_background');
    my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_mask_remove_background/imageXXXX');
    $archive_temp_image .= '.png';
    print STDERR $archive_temp_image."\n";

    my $cmd = "python /home/nmorales/cxgn/DroneImageScripts/ImageProcess/MaskRemoveBackground.py --image_path '$image_fullpath' --mask_image_path '$mask_image_fullpath' --outfile_path '$archive_temp_image'";
    my $status = system($cmd);

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);

    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'background_removed_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $ret = $image->process_image($archive_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
    my $masked_image_fullpath = $image->get_filename('original_converted', 'full');
    my $masked_image_url = $image->get_image_url('original');

    $c->stash->{rest} = { image_url => $image_url, image_fullpath => $image_fullpath, masked_image_url => $masked_image_url, masked_image_fullpath => $masked_image_fullpath };
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

sub drone_imagery_merge_bands : Path('/ajax/drone_imagery/merge_bands') : ActionClass('REST') { }

sub drone_imagery_merge_bands_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    print STDERR Dumper $c->req->params();

    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my $drone_run_project_name = $c->req->param('drone_run_project_name');
    my $band_1_drone_run_band_project_id = $c->req->param('band_1_drone_run_band_project_id');
    my $band_2_drone_run_band_project_id = $c->req->param('band_2_drone_run_band_project_id');
    my $band_3_drone_run_band_project_id = $c->req->param('band_3_drone_run_band_project_id');
    if (!$band_1_drone_run_band_project_id || !$band_2_drone_run_band_project_id || !$band_3_drone_run_band_project_id) {
        $c->stash->{rest} = { error => 'Please select 3 drone run bands' };
        $c->detach();
    }
    my @drone_run_bands = ($band_1_drone_run_band_project_id, $band_2_drone_run_band_project_id, $band_3_drone_run_band_project_id);

    my $project_image_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$project_image_type_id,
        drone_run_band_project_id_list=>\@drone_run_bands,
    });
    my ($result, $total_count) = $images_search->search();
    #print STDERR Dumper $result;

    my %drone_run_bands_images;
    foreach (@$result) {
        $drone_run_bands_images{$_->{drone_run_band_project_id}} = $_->{image_id};
    }
    print STDERR Dumper \%drone_run_bands_images;
    
    my @image_filesnames;
    foreach (@drone_run_bands) {
        my $image = SGN::Image->new( $schema->storage->dbh, $drone_run_bands_images{$_}, $c );
        my $image_url = $image->get_image_url("original");
        my $image_fullpath = $image->get_filename('original_converted', 'full');
        print STDERR Dumper $image_url;
        print STDERR Dumper $image_fullpath;
        push @image_filesnames, $image_fullpath;
    }

    my $dir = $c->tempfiles_subdir('/drone_imagery_merge_bands');
    my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_merge_bands/imageXXXX');
    $archive_temp_image .= '.png';
    print STDERR $archive_temp_image."\n";

    my $cmd = "python /home/nmorales/cxgn/DroneImageScripts/ImageProcess/MergeChannels.py --image_path_band_1 '".$image_filesnames[0]."' --image_path_band_2 '".$image_filesnames[1]."' --image_path_band_3 '".$image_filesnames[2]."' --outfile_path '$archive_temp_image'";
    print STDERR Dumper $cmd;
    my $status = system($cmd);

    my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);

    my $drone_run_band_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property')->cvterm_id();
    my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();

    my $project_rs = $schema->resultset("Project::Project")->create({
        name => "$drone_run_project_name Merged:$band_1_drone_run_band_project_id,$band_2_drone_run_band_project_id,$band_3_drone_run_band_project_id",
        description => "Merged $band_1_drone_run_band_project_id,$band_2_drone_run_band_project_id,$band_3_drone_run_band_project_id",
        projectprops => [{type_id => $drone_run_band_type_cvterm_id, value => 'Merged 3 Bands'}, {type_id => $design_cvterm_id, value => 'drone_run_band'}],
        project_relationship_subject_projects => [{type_id => $project_relationship_type_id, object_project_id => $drone_run_project_id}]
    });
    my $merged_drone_run_band_id = $project_rs->project_id();

    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $ret = $image->process_image($archive_temp_image, 'project', $merged_drone_run_band_id, $linking_table_type_id);
    my $merged_image_fullpath = $image->get_filename('original_converted', 'full');
    my $merged_image_url = $image->get_image_url('original');

    $c->stash->{rest} = { merged_image_url => $merged_image_url, merged_image_fullpath => $merged_image_fullpath };
}

sub drone_imagery_calculate_phenotypes : Path('/ajax/drone_imagery/calculate_phenotypes') : ActionClass('REST') { }

sub drone_imagery_calculate_phenotypes_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $drone_run_band_project_type = $c->req->param('drone_run_band_project_type');
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
    if ($phenotype_method eq 'zonal') {
        $temp_images_subdir = 'drone_imagery_calc_phenotypes_zonal_stats';
        $temp_results_subdir = 'drone_imagery_calc_phenotypes_zonal_stats_results';
        $calculate_phenotypes_script = 'CalculatePhenotypeZonalStats.py';
        $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_phenotypes_zonal_stats_drone_imagery', 'project_md_image')->cvterm_id();
    } elsif ($phenotype_method eq 'sift') {
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
        my $image_source_tag_small = $image->get_img_src_tag("tiny");
        push @image_paths, $image_fullpath;

        if ($phenotype_method ne 'zonal') {
            my $dir = $c->tempfiles_subdir('/'.$temp_images_subdir);
            my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => $temp_images_subdir.'/imageXXXX');
            $archive_temp_image .= '.png';
            push @out_paths, $archive_temp_image;
        }

        push @stocks, {
            stock_id => $_->{stock_id},
            stock_uniquename => $_->{stock_uniquename},
            stock_type_id => $_->{stock_type_id},
            image => '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>'
        };
    }
    print STDERR Dumper \@image_paths;
    my $image_paths_string = join ',', @image_paths;
    my $out_paths_string = join ',', @out_paths;

    if ($out_paths_string) {
        $out_paths_string = ' --outfile_paths '.$out_paths_string;
    }

    my $dir = $c->tempfiles_subdir('/'.$temp_results_subdir);
    my $archive_temp_results = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => $temp_results_subdir.'/imageXXXX');

    my $status = system('python /home/nmorales/cxgn/DroneImageScripts/ImageProcess/'.$calculate_phenotypes_script.' --image_paths \''.$image_paths_string.'\' '.$out_paths_string.' --results_outfile_path \''.$archive_temp_results.'\'');

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my @header_cols;
    my $csv = Text::CSV->new({ sep_char => ',' });
    open(my $fh, '<', $archive_temp_results)
        or die "Could not open file '$archive_temp_results' $!";
    
        my $header = <$fh>;
        if ($csv->parse($header)) {
            @header_cols = $csv->fields();
        }

        my $line = 0;
        my %zonal_stat_phenotype_data;
        my %plots_seen;
        my @traits_seen;
        if ($phenotype_method eq 'zonal') {
            if ($header_cols[0] ne 'nonzero_pixel_count' ||
                $header_cols[1] ne 'total_pixel_sum' ||
                $header_cols[2] ne 'mean_pixel_value' ||
                $header_cols[3] ne 'harmonic_mean_value' ||
                $header_cols[4] ne 'median_pixel_value' ||
                $header_cols[5] ne 'variance_pixel_value' ||
                $header_cols[6] ne 'stdev_pixel_value' ||
                $header_cols[7] ne 'pstdev_pixel_value' ||
                $header_cols[8] ne 'min_pixel_value' ||
                $header_cols[9] ne 'max_pixel_value' ||
                $header_cols[10] ne 'minority_pixel_value' ||
                $header_cols[11] ne 'minority_pixel_count' ||
                $header_cols[12] ne 'majority_pixel_value' ||
                $header_cols[13] ne 'majority_pixel_count' ||
                $header_cols[14] ne 'pixel_variety_count'
            ) {
                $c->stash->{rest} = { error => "Pheno results must have header: 'nonzero_pixel_count', 'total_pixel_sum', 'mean_pixel_value', 'harmonic_mean_value', 'median_pixel_value', 'variance_pixel_value', 'stdev_pixel_value', 'pstdev_pixel_value', 'min_pixel_value', 'max_pixel_value', 'minority_pixel_value', 'minority_pixel_count', 'majority_pixel_value', 'majority_pixel_count', 'pixel_variety_count'" };
                return;
            }

            my $non_zero_pixel_count_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Nonzero Pixel Count|G2F:0000014')->cvterm_id;
            my $total_pixel_sum_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Total Pixel Sum|G2F:0000015')->cvterm_id;
            my $mean_pixel_value_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Mean Pixel Value|G2F:0000016')->cvterm_id;
            my $harmonic_mean_pixel_value_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Harmonic Mean Pixel Value|G2F:0000017')->cvterm_id;
            my $median_pixel_value_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Median Pixel Value|G2F:0000018')->cvterm_id;
            my $pixel_variance_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Pixel Variance|G2F:0000019')->cvterm_id;
            my $pixel_standard_dev_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Pixel Standard Deviation|G2F:0000020')->cvterm_id;
            my $pixel_pstandard_dev_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Pixel Population Standard Deviation|G2F:0000021')->cvterm_id;
            my $minimum_pixel_value_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Minimum Pixel Value|G2F:0000022')->cvterm_id;
            my $maximum_pixel_value_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Maximum Pixel Value|G2F:0000023')->cvterm_id;
            my $minority_pixel_value_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Minority Pixel Value|G2F:0000024')->cvterm_id;
            my $minority_pixel_count_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Minority Pixel Count|G2F:0000025')->cvterm_id;
            my $majority_pixel_value_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Majority Pixel Value|G2F:0000026')->cvterm_id;
            my $majority_puxel_count_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Majority Pixel Count|G2F:0000027')->cvterm_id;
            my $pixel_group_count_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Pixel Group Count|G2F:0000028')->cvterm_id;

            my $rgb_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'RGB Color Image|ISOL:0000002')->cvterm_id;
            my $bw_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Black and White Image|ISOL:0000003')->cvterm_id;
            my $blue_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Blue (450-520nm)|ISOL:0000004')->cvterm_id;
            my $green_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Green (515-600nm)|ISOL:0000005')->cvterm_id;
            my $red_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Red (600-690nm)|ISOL:0000006')->cvterm_id;
            my $nir_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'NIR (750-900nm)|ISOL:0000007')->cvterm_id;
            my $mir_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'MIR (1550-1750nm)|ISOL:0000008')->cvterm_id;
            my $fir_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FIR (2080-2350nm)|ISOL:0000009')->cvterm_id;
            my $thermal_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Thermal IR (10400-12500nm)|ISOL:0000010')->cvterm_id;

            my $drone_run_band_project_type_cvterm_id;
            print STDERR Dumper $drone_run_band_project_type;
            if ($drone_run_band_project_type eq 'RGB Color Image') {
                $drone_run_band_project_type_cvterm_id = $rgb_cvterm_id;
            }
            if ($drone_run_band_project_type eq 'Black and White Image') {
                $drone_run_band_project_type_cvterm_id = $bw_cvterm_id;
            }
            if ($drone_run_band_project_type eq 'Blue (450-520nm)') {
                $drone_run_band_project_type_cvterm_id = $blue_cvterm_id;
            }
            if ($drone_run_band_project_type eq 'Green (515-600nm)') {
                $drone_run_band_project_type_cvterm_id = $green_cvterm_id;
            }
            if ($drone_run_band_project_type eq 'Red (600-690nm)') {
                $drone_run_band_project_type_cvterm_id = $red_cvterm_id;
            }
            if ($drone_run_band_project_type eq 'NIR (750-900nm)') {
                $drone_run_band_project_type_cvterm_id = $nir_cvterm_id;
            }
            if ($drone_run_band_project_type eq 'MIR (1550-1750nm)') {
                $drone_run_band_project_type_cvterm_id = $mir_cvterm_id;
            }
            if ($drone_run_band_project_type eq 'FIR (2080-2350nm)') {
                $drone_run_band_project_type_cvterm_id = $fir_cvterm_id;
            }
            if ($drone_run_band_project_type eq 'Thermal IR (10400-12500nm)') {
                $drone_run_band_project_type_cvterm_id = $thermal_cvterm_id;
            }

            my $non_zero_pixel_count_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$non_zero_pixel_count_cvterm_id, $drone_run_band_project_type_cvterm_id]);
            my $total_pixel_sum_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$total_pixel_sum_cvterm_id, $drone_run_band_project_type_cvterm_id]);
            my $mean_pixel_value_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$mean_pixel_value_cvterm_id, $drone_run_band_project_type_cvterm_id]);
            my $harmonic_mean_pixel_value_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$harmonic_mean_pixel_value_cvterm_id, $drone_run_band_project_type_cvterm_id]);
            my $median_pixel_value_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$median_pixel_value_cvterm_id, $drone_run_band_project_type_cvterm_id]);
            my $pixel_variance_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$pixel_variance_cvterm_id, $drone_run_band_project_type_cvterm_id]);
            my $pixel_standard_dev_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$pixel_standard_dev_cvterm_id, $drone_run_band_project_type_cvterm_id]);
            my $pixel_pstandard_dev_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$pixel_pstandard_dev_cvterm_id, $drone_run_band_project_type_cvterm_id]);
            my $minimum_pixel_value_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$minimum_pixel_value_cvterm_id, $drone_run_band_project_type_cvterm_id]);
            my $maximum_pixel_value_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$maximum_pixel_value_cvterm_id, $drone_run_band_project_type_cvterm_id]);
            my $minority_pixel_value_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$minority_pixel_value_cvterm_id, $drone_run_band_project_type_cvterm_id]);
            my $minority_pixel_count_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$minority_pixel_count_cvterm_id, $drone_run_band_project_type_cvterm_id]);
            my $majority_pixel_value_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$majority_pixel_value_cvterm_id, $drone_run_band_project_type_cvterm_id]);
            my $majority_pixel_count_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$majority_puxel_count_cvterm_id, $drone_run_band_project_type_cvterm_id]);
            my $pixel_group_count_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$pixel_group_count_cvterm_id, $drone_run_band_project_type_cvterm_id]);

            my $non_zero_pixel_count_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $non_zero_pixel_count_composed_cvterm_id, 'extended');
            my $total_pixel_sum_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $total_pixel_sum_composed_cvterm_id, 'extended');
            my $mean_pixel_value_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $mean_pixel_value_composed_cvterm_id, 'extended');
            my $harmonic_mean_pixel_value_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $harmonic_mean_pixel_value_composed_cvterm_id, 'extended');
            my $median_pixel_value_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $median_pixel_value_composed_cvterm_id, 'extended');
            my $pixel_variance_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $pixel_variance_composed_cvterm_id, 'extended');
            my $pixel_standard_dev_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $pixel_standard_dev_composed_cvterm_id, 'extended');
            my $pixel_pstandard_dev_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $pixel_pstandard_dev_composed_cvterm_id, 'extended');
            my $minimum_pixel_value_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $minimum_pixel_value_composed_cvterm_id, 'extended');
            my $maximum_pixel_value_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $maximum_pixel_value_composed_cvterm_id, 'extended');
            my $majority_pixel_value_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $minority_pixel_value_composed_cvterm_id, 'extended');
            my $majority_pixel_count_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $minority_pixel_count_composed_cvterm_id, 'extended');
            my $minority_pixel_value_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $majority_pixel_value_composed_cvterm_id, 'extended');
            my $minority_pixel_count_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $majority_pixel_count_composed_cvterm_id, 'extended');
            my $pixel_group_count_composed_trait_name = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $pixel_group_count_composed_cvterm_id, 'extended');

            @traits_seen = (
                $non_zero_pixel_count_composed_trait_name,
                $total_pixel_sum_composed_trait_name,
                $mean_pixel_value_composed_trait_name,
                $harmonic_mean_pixel_value_composed_trait_name,
                $median_pixel_value_composed_trait_name,
                $pixel_variance_composed_trait_name,
                $pixel_standard_dev_composed_trait_name,
                $pixel_pstandard_dev_composed_trait_name,
                $minimum_pixel_value_composed_trait_name,
                $maximum_pixel_value_composed_trait_name,
                $majority_pixel_value_composed_trait_name,
                $majority_pixel_count_composed_trait_name,
                $minority_pixel_value_composed_trait_name,
                $minority_pixel_count_composed_trait_name,
                $pixel_group_count_composed_trait_name
            );

            while ( my $row = <$fh> ){
                my @columns;
                if ($csv->parse($row)) {
                    @columns = $csv->fields();
                }
                #print STDERR Dumper \@columns;
                $stocks[$line]->{result} = \@columns;

                $plots_seen{$stocks[$line]->{stock_uniquename}} = 1;
                $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$non_zero_pixel_count_composed_trait_name} = [$columns[0], $timestamp, $user_name, ''];
                $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$total_pixel_sum_composed_trait_name} = [$columns[1], $timestamp, $user_name, ''];
                $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$mean_pixel_value_composed_trait_name} = [$columns[2], $timestamp, $user_name, ''];
                $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$harmonic_mean_pixel_value_composed_trait_name} = [$columns[3], $timestamp, $user_name, ''];
                $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$median_pixel_value_composed_trait_name} = [$columns[4], $timestamp, $user_name, ''];
                $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$pixel_variance_composed_trait_name} = [$columns[5], $timestamp, $user_name, ''];
                $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$pixel_standard_dev_composed_trait_name} = [$columns[6], $timestamp, $user_name, ''];
                $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$pixel_pstandard_dev_composed_trait_name} = [$columns[7], $timestamp, $user_name, ''];
                $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$minimum_pixel_value_composed_trait_name} = [$columns[8], $timestamp, $user_name, ''];
                $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$maximum_pixel_value_composed_trait_name} = [$columns[9], $timestamp, $user_name, ''];
                $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$minority_pixel_value_composed_trait_name} = [$columns[10], $timestamp, $user_name, ''];
                $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$minority_pixel_count_composed_trait_name} = [$columns[11], $timestamp, $user_name, ''];
                $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$majority_pixel_value_composed_trait_name} = [$columns[12], $timestamp, $user_name, ''];
                $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$majority_pixel_count_composed_trait_name} = [$columns[13], $timestamp, $user_name, ''];
                $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$pixel_group_count_composed_trait_name} = [$columns[14], $timestamp, $user_name, ''];

                $line++;
            }
        }
    
    close $fh;

    if ($line > 0) {
        my %phenotype_metadata = (
            'archived_file' => $archive_temp_results,
            'archived_file_type' => 'zonal_statistics_image_phenotypes',
            'operator' => $user_name,
            'date' => $timestamp
        );
        my @plot_units_seen = keys %plots_seen;
        my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
            bcs_schema=>$schema,
            metadata_schema=>$metadata_schema,
            phenome_schema=>$phenome_schema,
            user_id=>$user_id,
            stock_list=>\@plot_units_seen,
            trait_list=>\@traits_seen,
            values_hash=>\%zonal_stat_phenotype_data,
            has_timestamps=>1,
            overwrite_values=>1,
            metadata_hash=>\%phenotype_metadata
        );
        my ($verified_warning, $verified_error) = $store_phenotypes->verify();
        my ($stored_phenotype_error, $stored_phenotype_success) = $store_phenotypes->store();
        
        my $bs = CXGN::BreederSearch->new( { dbh=>$c->dbc->dbh, dbname=>$c->config->{dbname}, } );
        my $refresh = $bs->refresh_matviews($c->config->{dbhost}, $c->config->{dbname}, $c->config->{dbuser}, $c->config->{dbpass}, 'fullview', 'concurrent', $c->config->{basepath});
    }

    my $count = 0;
    foreach (@out_paths) {
        my $stock = $stocks[$count];

        my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
        $image->set_sp_person_id($user_id);
        my $ret = $image->process_image($_, 'project', $drone_run_band_project_id, $linking_table_type_id);
        $ret = $image->associate_stock($stock->{stock_id});
        my $image_fullpath = $image->get_filename('original_converted', 'full');
        my $image_url = $image->get_image_url('original');

        my $image_source_tag_small = $image->get_img_src_tag("tiny");
        
        $stocks[$count]->{image} = '<a href="/image/view/'.$image->get_image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
        $stocks[$count]->{image_path} = $image_fullpath;
        $stocks[$count]->{image_url} = $image_url;
        $count++;
    }

    $c->stash->{rest} = { result_header => \@header_cols, results => \@stocks };
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
