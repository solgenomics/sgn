
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
use CXGN::Phenotypes::PhenotypeMatrix;
use CXGN::BrAPI::FileResponse;
use CXGN::Onto;
#use Inline::Python;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub upload_drone_imagery : Path('/api/drone_imagery/upload_drone_imagery') : ActionClass('REST') { }

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

sub raw_drone_imagery_summary : Path('/api/drone_imagery/raw_drone_imagery') : ActionClass('REST') { }

sub raw_drone_imagery_summary_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $raw_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'raw_drone_imagery', 'project_md_image')->cvterm_id();
    my $stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $cropped_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cropped_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $rotated_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'rotated_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $denoised_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $vegetative_index_tgi_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_tgi_drone_imagery', 'project_md_image')->cvterm_id();
    my $vegetative_index_vari_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_vari_drone_imagery', 'project_md_image')->cvterm_id();
    my $vegetative_index_ndvi_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_ndvi_drone_imagery', 'project_md_image')->cvterm_id();
    my $vegetative_index_ndre_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_ndre_drone_imagery', 'project_md_image')->cvterm_id();
    my $threshold_background_removed_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $threshold_background_removed_tgi_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_tgi_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $threshold_background_removed_vari_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_vari_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $threshold_background_removed_ndvi_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_ndvi_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $threshold_background_removed_ndre_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_ndre_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $denoised_background_removed_thresholded_tgi_mask_original_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_background_removed_thresholded_tgi_mask_original', 'project_md_image')->cvterm_id();
    my $denoised_background_removed_thresholded_vari_mask_original_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_background_removed_thresholded_vari_mask_original', 'project_md_image')->cvterm_id();
    my $denoised_background_removed_thresholded_ndvi_mask_original_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_background_removed_thresholded_ndvi_mask_original', 'project_md_image')->cvterm_id();
    my $denoised_background_removed_thresholded_ndre_mask_original_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_background_removed_thresholded_ndre_mask_original', 'project_md_image')->cvterm_id();

    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id_list=>[
            $raw_drone_images_cvterm_id,
            $stitched_drone_images_cvterm_id,
            $cropped_stitched_drone_images_cvterm_id,
            $rotated_stitched_drone_images_cvterm_id,
            $denoised_stitched_drone_images_cvterm_id,
            $vegetative_index_tgi_drone_images_cvterm_id,
            $vegetative_index_vari_drone_images_cvterm_id,
            $vegetative_index_ndvi_drone_images_cvterm_id,
            $vegetative_index_ndre_drone_images_cvterm_id,
            $threshold_background_removed_drone_images_cvterm_id,
            $threshold_background_removed_tgi_drone_images_cvterm_id,
            $threshold_background_removed_vari_drone_images_cvterm_id,
            $threshold_background_removed_ndvi_drone_images_cvterm_id,
            $threshold_background_removed_ndre_drone_images_cvterm_id,
            $denoised_background_removed_thresholded_tgi_mask_original_cvterm_id,
            $denoised_background_removed_thresholded_vari_mask_original_cvterm_id,
            $denoised_background_removed_thresholded_ndvi_mask_original_cvterm_id,
            $denoised_background_removed_thresholded_ndre_mask_original_cvterm_id
        ]
    });
    my ($result, $total_count) = $images_search->search();
    #print STDERR Dumper $result;

    # my $ft_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'fourier_transform_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    # my $ft_stitched_images_search = CXGN::DroneImagery::ImagesSearch->new({
    #     bcs_schema=>$schema,
    #     project_image_type_id=>$ft_stitched_drone_images_cvterm_id
    # });
    # my ($ft_stitched_result, $ft_stitched_total_count) = $ft_stitched_images_search->search();
    #print STDERR Dumper $ft_stitched_result;

    my @return;
    my %unique_drone_runs;
    my %trial_id_hash;
    foreach (@$result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_source_tag_tiny = $image->get_img_src_tag("tiny");
        my $image_source_tag_small = $image->get_img_src_tag("thumbnail");
        my $image_original = $image->get_image_url("original");
        if ($_->{project_image_type_name} eq 'raw_drone_imagery') {
            push @{$unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{images}}, '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{usernames}->{$_->{username}}++;
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_project_name} = $_->{drone_run_band_project_name};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_project_description} = $_->{drone_run_band_project_description};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_project_type} = $_->{drone_run_band_project_type};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{trial_id} = $_->{trial_id};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{trial_name} = $_->{trial_name};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{drone_run_project_name} = $_->{drone_run_project_name};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{drone_run_date} = $_->{drone_run_date};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{drone_run_type} = $_->{drone_run_type};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{drone_run_indicator} = $_->{drone_run_indicator};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{drone_run_processed} = $_->{drone_run_processed};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{drone_run_phenotypes_indicator} = $_->{drone_run_phenotypes_indicator};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{drone_run_project_description} = $_->{drone_run_project_description};
            $trial_id_hash{$_->{trial_name}} = $_->{trial_id};
        }
        elsif ($_->{project_image_type_name} eq 'stitched_drone_imagery') {
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{stitched_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{stitched_image_username} = $_->{username};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{stitched_image_modified_date} = $_->{image_modified_date};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{stitched_image_original} = $image_original;
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{stitched_image_id} = $image_id;
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_project_name} = $_->{drone_run_band_project_name};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_project_description} = $_->{drone_run_band_project_description};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_project_type} = $_->{drone_run_band_project_type};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{usernames}->{$_->{username}}++;
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{trial_id} = $_->{trial_id};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{trial_name} = $_->{trial_name};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{drone_run_project_name} = $_->{drone_run_project_name};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{drone_run_date} = $_->{drone_run_date};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{drone_run_type} = $_->{drone_run_type};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{drone_run_indicator} = $_->{drone_run_indicator};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{drone_run_processed} = $_->{drone_run_processed};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{drone_run_phenotypes_indicator} = $_->{drone_run_phenotypes_indicator};
            $unique_drone_runs{$_->{trial_name}}->{$_->{drone_run_project_id}}->{drone_run_project_description} = $_->{drone_run_project_description};
            $trial_id_hash{$_->{trial_name}} = $_->{trial_id};
        }
    }

    #print STDERR Dumper \%unique_drone_runs;

    my $calendar_funcs = CXGN::Calendar->new({});
    foreach my $trial_name (sort keys %unique_drone_runs) {
        my %unique_drone_runs_k = %{$unique_drone_runs{$trial_name}};

        my $drone_run_html = '<div class="panel-group" id="drone_runs_trial_accordion_table_wrapper_'.$trial_id_hash{$trial_name}.'" ><div class="panel panel-default"><div class="panel-heading"><h4 class="panel-title"><a data-toggle="collapse" data-parent="#drone_runs_trial_accordion_table_wrapper_'.$trial_id_hash{$trial_name}.'" href="#drone_runs_trial_accordion_table_wrapper_one_'.$trial_id_hash{$trial_name}.'" >Field Trial: '.$trial_name.'&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;('.scalar(keys %unique_drone_runs_k).' Drone Runs)</a></h4></div><div id="drone_runs_trial_accordion_table_wrapper_one_'.$trial_id_hash{$trial_name}.'" class="panel-collapse collapse"><div class="panel-body">';

        foreach my $k (sort keys %unique_drone_runs_k) {
            my $v = $unique_drone_runs_k{$k};
            my $drone_run_bands = $v->{bands};
            my $drone_run_date = $v->{drone_run_date} ? $calendar_funcs->display_start_date($v->{drone_run_date}) : '';

            $drone_run_html .= '<div class="panel-group" id="drone_run_band_accordion_drone_run_wrapper_'.$k.'" ><div class="panel panel-default"><div class="panel-heading"><h4 class="panel-title"><a data-toggle="collapse" data-parent="#drone_run_band_accordion_drone_run_wrapper_'.$k.'" href="#drone_run_band_accordion_drone_run_wrapper_one_'.$k.'" >'.$v->{drone_run_project_name}.'&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp'.$drone_run_date.'</a></h4></div><div id="drone_run_band_accordion_drone_run_wrapper_one_'.$k.'" class="panel-collapse collapse"><div class="panel-body">';

            $drone_run_html .= '<div class="well well-sm">';

            $drone_run_html .= '<div class="row"><div class="col-sm-6">';
            $drone_run_html .= '<div class="row"><div class="col-sm-5"><b>Drone Run Name</b>:</div><div class="col-sm-7">'.$v->{drone_run_project_name}.'</div></div>';
            $drone_run_html .= '<div class="row"><div class="col-sm-5"><b>Drone Run Type</b>:</div><div class="col-sm-7">'.$v->{drone_run_type}.'</div></div>';
            $drone_run_html .= '<div class="row"><div class="col-sm-5"><b>Description</b>:</div><div class="col-sm-7">'.$v->{drone_run_project_description}.'</div></div>';
            $drone_run_html .= '<div class="row"><div class="col-sm-5"><b>Date</b>:</div><div class="col-sm-7">'.$drone_run_date.'</div></div>';
            $drone_run_html .= '<div class="row"><div class="col-sm-5"><b>Field Trial</b>:</div><div class="col-sm-7"><a href="/breeders_toolbox/trial/'.$v->{trial_id}.'">'.$v->{trial_name}.'</a></div></div>';
            $drone_run_html .= '</div><div class="col-sm-3">';
            if ($v->{drone_run_indicator}) {
                $drone_run_html .= '<span class="label label-info" ><span class="glyphicon glyphicon-hourglass"></span>&nbsp;&nbsp;&nbsp;Processing Images in Progress</span><br/><br/>';
            }
            if ($v->{drone_run_phenotypes_indicator}) {
                $drone_run_html .= '<span class="label label-info" ><span class="glyphicon glyphicon-hourglass"></span>&nbsp;&nbsp;&nbsp;Processing Phenotypes in Progress</span><br/><br/>';
            } elsif ($v->{drone_run_processed} || scalar(keys %$drone_run_bands)<=1) {
                $drone_run_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_phenotype_run" data-drone_run_project_id="'.$k.'" data-field_trial_id="'.$v->{trial_id}.'" data-field_trial_name="'.$v->{trial_name}.'" >Generate Phenotypes for <br/>'.$v->{drone_run_project_name}.'</button>';
            }
            $drone_run_html .= '</div><div class="col-sm-3">';
            if (!$v->{drone_run_processed} && scalar(keys %$drone_run_bands)>1) {
                $drone_run_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_standard_process" data-drone_run_project_id="'.$k.'" data-drone_run_project_name="'.$v->{drone_run_project_name}.'" data-field_trial_id="'.$v->{trial_id}.'" data-field_trial_name="'.$v->{trial_name}.'" >Run Standard Process For<br/>'.$v->{drone_run_project_name}.'</button><br/><br/>';
            }
            $drone_run_html .= '<button class="btn btn-danger btn-sm" name="project_drone_imagery_delete_drone_run" data-drone_run_project_id="'.$k.'" data-drone_run_project_name="'.$v->{drone_run_project_name}.'" >Delete Drone Run</button>';

            $drone_run_html .= '</div></div></div>';

            $drone_run_html .= "<hr>";

            $drone_run_html .= '<div name="drone_run_band_total_plot_image_div" id="drone_run_band_total_plot_image_count_div_'.$k.'">';
            $drone_run_html .= '<div class="panel-group"><div class="panel panel-default panel-sm"><div class="panel-heading"><h4 class="panel-title"><a data-toggle="collapse" >Loading Plot Image Summary...</a></h4></div></div></div>';
            $drone_run_html .= '</div>';

            $drone_run_html .= '<div class="panel-group" id="drone_run_band_accordion_table_wrapper_'.$k.'" ><div class="panel panel-default"><div class="panel-heading"><h4 class="panel-title"><a data-toggle="collapse" data-parent="#drone_run_band_accordion_table_wrapper_'.$k.'" href="#drone_run_band_accordion_table_wrapper_one_'.$k.'" >View All Drone Run Images</a></h4></div><div id="drone_run_band_accordion_table_wrapper_one_'.$k.'" class="panel-collapse collapse"><div class="panel-body">';

            my $drone_run_band_table_html = '<table class="table table-bordered"><thead><tr><th>Drone Run Band(s)</th><th>Images/Actions</th></thead><tbody>';

            foreach my $drone_run_band_project_id (sort keys %$drone_run_bands) {
                my $d = $drone_run_bands->{$drone_run_band_project_id};

                $drone_run_band_table_html .= '<tr><td><b>Name</b>: '.$d->{drone_run_band_project_name}.'<br/><b>Description</b>: '.$d->{drone_run_band_project_description}.'<br/><b>Type</b>: '.$d->{drone_run_band_project_type}.'</td><td>';

                $drone_run_band_table_html .= '<div class="panel-group" id="drone_run_band_accordion_'.$drone_run_band_project_id.'" ><div class="panel panel-default"><div class="panel-heading"><h4 class="panel-title"><a data-toggle="collapse" data-parent="#drone_run_band_accordion_'.$drone_run_band_project_id.'" href="#drone_run_band_accordion_one_'.$drone_run_band_project_id.'" onclick="manageDroneImageryDroneRunBandDisplay('.$drone_run_band_project_id.')">View Images</a></h4></div><div id="drone_run_band_accordion_one_'.$drone_run_band_project_id.'" class="panel-collapse collapse"><div class="panel-body">';

                $drone_run_band_table_html .= '<div id="drone_run_band_accordian_drone_run_band_div_'.$drone_run_band_project_id.'"></div>';

                $drone_run_band_table_html .= '</div></div></div></div>';
                $drone_run_band_table_html .= '</td></tr>';

            }
            $drone_run_band_table_html .= '</tbody></table>';

            $drone_run_html .= $drone_run_band_table_html;

            $drone_run_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_merge_channels" data-drone_run_project_id="'.$k.'" data-drone_run_project_name="'.$v->{drone_run_project_name}.'" >Merge Drone Run Bands For '.$v->{drone_run_project_name}.'</button><br/><br/>';

            $drone_run_html .= '</div></div></div></div>';

            $drone_run_html .= '</div></div></div>';
            $drone_run_html .= '<br/>';
        }
        $drone_run_html .= '</div></div></div></div>';

        push @return, [$drone_run_html];
    }

    $c->stash->{rest} = { data => \@return };
}

sub raw_drone_imagery_plot_image_count : Path('/api/drone_imagery/raw_drone_imagery_plot_image_count') : ActionClass('REST') { }

sub raw_drone_imagery_plot_image_count_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $observation_unit_polygon_bw_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_bw_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_rgb_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_blue_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_blue_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_green_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_green_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_red_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_red_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_red_edge_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_red_edge_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_nir_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_nir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_mir_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_mir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_fir_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_tir_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_tir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_tgi_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_tgi_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_vari_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_vari_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_ndvi_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_ndvi_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_ndre_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_ndre_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_background_removed_tgi_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_background_removed_tgi_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_background_removed_vari_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_background_removed_vari_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_background_removed_ndvi_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_background_removed_ndvi_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_background_removed_ndre_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_background_removed_ndre_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_original_background_removed_thresholded_tgi_mask_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_original_background_removed_thresholded_vari_mask_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_original_background_removed_thresholded_ndvi_mask_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_ndvi_mask_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_original_background_removed_thresholded_ndre_mask_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_ndre_mask_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_original_background_removed_tgi_mask_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_tgi_mask_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_original_background_removed_vari_mask_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_vari_mask_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_original_background_removed_ndvi_mask_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_ndvi_mask_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_original_background_removed_ndre_mask_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_ndre_mask_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_original_ourier_transform_hpf30_nrn_denoised_stitched_image_channel_1_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id();
    my $plot_polygon_original_ourier_transform_hpf30_blue_denoised_stitched_image_channel_1_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id();
    my $plot_polygon_original_ourier_transform_hpf30_green_denoised_stitched_image_channel_1_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_green_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id();
    my $plot_polygon_original_ourier_transform_hpf30_red_denoised_stitched_image_channel_1_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_red_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id();
    my $plot_polygon_original_ourier_transform_hpf30_rededge_denoised_stitched_image_channel_1_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id();
    my $plot_polygon_original_ourier_transform_hpf30_nir_denoised_stitched_image_channel_1_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id();
    my $drone_run_band_drone_run_relationship_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();

    my @project_image_type_id_list = (
        $observation_unit_polygon_bw_background_removed_threshold_imagery_cvterm_id,
        $observation_unit_polygon_rgb_background_removed_threshold_imagery_cvterm_id,
        $observation_unit_polygon_blue_background_removed_threshold_imagery_cvterm_id,
        $observation_unit_polygon_green_background_removed_threshold_imagery_cvterm_id,
        $observation_unit_polygon_red_background_removed_threshold_imagery_cvterm_id,
        $observation_unit_polygon_red_edge_background_removed_threshold_imagery_cvterm_id,
        $observation_unit_polygon_nir_background_removed_threshold_imagery_cvterm_id,
        $observation_unit_polygon_mir_background_removed_threshold_imagery_cvterm_id,
        $observation_unit_polygon_fir_background_removed_threshold_imagery_cvterm_id,
        $observation_unit_polygon_tir_background_removed_threshold_imagery_cvterm_id,
        $plot_polygon_tgi_stitched_drone_images_cvterm_id,
        $plot_polygon_vari_stitched_drone_images_cvterm_id,
        $plot_polygon_ndvi_stitched_drone_images_cvterm_id,
        $plot_polygon_ndre_stitched_drone_images_cvterm_id,
        $plot_polygon_background_removed_tgi_stitched_drone_images_cvterm_id,
        $plot_polygon_background_removed_vari_stitched_drone_images_cvterm_id,
        $plot_polygon_background_removed_ndvi_stitched_drone_images_cvterm_id,
        $plot_polygon_background_removed_ndre_stitched_drone_images_cvterm_id,
        $plot_polygon_original_background_removed_thresholded_tgi_mask_images_cvterm_id,
        $plot_polygon_original_background_removed_thresholded_vari_mask_images_cvterm_id,
        $plot_polygon_original_background_removed_thresholded_ndvi_mask_images_cvterm_id,
        $plot_polygon_original_background_removed_thresholded_ndre_mask_images_cvterm_id,
        $plot_polygon_original_background_removed_tgi_mask_images_cvterm_id,
        $plot_polygon_original_background_removed_vari_mask_images_cvterm_id,
        $plot_polygon_original_background_removed_ndvi_mask_images_cvterm_id,
        $plot_polygon_original_background_removed_ndre_mask_images_cvterm_id,
        $plot_polygon_original_ourier_transform_hpf30_nrn_denoised_stitched_image_channel_1_cvterm_id,
        $plot_polygon_original_ourier_transform_hpf30_blue_denoised_stitched_image_channel_1_cvterm_id,
        $plot_polygon_original_ourier_transform_hpf30_green_denoised_stitched_image_channel_1_cvterm_id,
        $plot_polygon_original_ourier_transform_hpf30_red_denoised_stitched_image_channel_1_cvterm_id,
        $plot_polygon_original_ourier_transform_hpf30_rededge_denoised_stitched_image_channel_1_cvterm_id,
        $plot_polygon_original_ourier_transform_hpf30_nir_denoised_stitched_image_channel_1_cvterm_id
    );
    my $sql = join ("," , @project_image_type_id_list);
    my $q = "SELECT drone_run.project_id, project_image_type.name
        FROM project AS drone_run_band
        JOIN project_relationship AS drone_run_band_rel ON(drone_run_band.project_id=drone_run_band_rel.subject_project_id AND drone_run_band_rel.type_id=$drone_run_band_drone_run_relationship_id)
        JOIN project AS drone_run ON(drone_run.project_id=drone_run_band_rel.object_project_id)
        JOIN phenome.project_md_image AS project_image ON(drone_run_band.project_id=project_image.project_id)
        JOIN cvterm AS project_image_type ON(project_image_type.cvterm_id=project_image.type_id)
        WHERE project_image.type_id in ($sql);";

    #print STDERR Dumper $q;
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();

    my %unique_drone_runs;
    while (my ($drone_run_project_id, $project_image_type_name) = $h->fetchrow_array()) {
        $unique_drone_runs{$drone_run_project_id}->{$project_image_type_name}++;
        $unique_drone_runs{$drone_run_project_id}->{total_plot_image_count}++;
    }
    #print STDERR Dumper \%unique_drone_runs;

    $c->stash->{rest} = { data => \%unique_drone_runs };
}

sub raw_drone_imagery_drone_run_band_summary : Path('/api/drone_imagery/raw_drone_imagery_drone_run_band') : ActionClass('REST') { }

sub raw_drone_imagery_drone_run_band_summary_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $raw_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'raw_drone_imagery', 'project_md_image')->cvterm_id();
    my $stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $cropped_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cropped_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $rotated_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'rotated_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $denoised_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $vegetative_index_tgi_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_tgi_drone_imagery', 'project_md_image')->cvterm_id();
    my $vegetative_index_vari_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_vari_drone_imagery', 'project_md_image')->cvterm_id();
    my $vegetative_index_ndvi_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_ndvi_drone_imagery', 'project_md_image')->cvterm_id();
    my $vegetative_index_ndre_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_ndre_drone_imagery', 'project_md_image')->cvterm_id();
    my $threshold_background_removed_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id();
    my $fourier_transform_hpf30_blue_denoised_stitched_image_channel_1_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id();
    my $fourier_transform_hpf30_green_denoised_stitched_image_channel_1_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_green_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id();
    my $fourier_transform_hpf30_red_denoised_stitched_image_channel_1_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_red_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id();
    my $fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id();
    my $fourier_transform_hpf30_nir_denoised_stitched_image_channel_1_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id();
    my $threshold_background_removed_tgi_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_tgi_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $threshold_background_removed_vari_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_vari_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $threshold_background_removed_ndvi_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_ndvi_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $threshold_background_removed_ndre_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_ndre_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $denoised_background_removed_thresholded_tgi_mask_original_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_background_removed_thresholded_tgi_mask_original', 'project_md_image')->cvterm_id();
    my $denoised_background_removed_thresholded_vari_mask_original_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_background_removed_thresholded_vari_mask_original', 'project_md_image')->cvterm_id();
    my $denoised_background_removed_thresholded_ndvi_mask_original_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_background_removed_thresholded_ndvi_mask_original', 'project_md_image')->cvterm_id();
    my $denoised_background_removed_thresholded_ndre_mask_original_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_background_removed_thresholded_ndre_mask_original', 'project_md_image')->cvterm_id();
    my $denoised_background_removed_tgi_mask_original_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_background_removed_tgi_mask_original', 'project_md_image')->cvterm_id();
    my $denoised_background_removed_vari_mask_original_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_background_removed_vari_mask_original', 'project_md_image')->cvterm_id();
    my $denoised_background_removed_ndvi_mask_original_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_background_removed_ndvi_mask_original', 'project_md_image')->cvterm_id();
    my $denoised_background_removed_ndre_mask_original_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_background_removed_ndre_mask_original', 'project_md_image')->cvterm_id();

    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_band_project_id_list=>[$drone_run_band_project_id],
        project_image_type_id_list=>[
            $raw_drone_images_cvterm_id,
            $stitched_drone_images_cvterm_id,
            $cropped_stitched_drone_images_cvterm_id,
            $rotated_stitched_drone_images_cvterm_id,
            $denoised_stitched_drone_images_cvterm_id,
            $vegetative_index_tgi_drone_images_cvterm_id,
            $vegetative_index_vari_drone_images_cvterm_id,
            $vegetative_index_ndvi_drone_images_cvterm_id,
            $vegetative_index_ndre_drone_images_cvterm_id,
            $threshold_background_removed_drone_images_cvterm_id,
            $threshold_background_removed_tgi_drone_images_cvterm_id,
            $threshold_background_removed_vari_drone_images_cvterm_id,
            $threshold_background_removed_ndvi_drone_images_cvterm_id,
            $threshold_background_removed_ndre_drone_images_cvterm_id,
            $denoised_background_removed_thresholded_tgi_mask_original_cvterm_id,
            $denoised_background_removed_thresholded_vari_mask_original_cvterm_id,
            $denoised_background_removed_thresholded_ndvi_mask_original_cvterm_id,
            $denoised_background_removed_thresholded_ndre_mask_original_cvterm_id,
            $denoised_background_removed_tgi_mask_original_cvterm_id,
            $denoised_background_removed_vari_mask_original_cvterm_id,
            $denoised_background_removed_ndvi_mask_original_cvterm_id,
            $denoised_background_removed_ndre_mask_original_cvterm_id,
            $fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1_cvterm_id,
            $fourier_transform_hpf30_blue_denoised_stitched_image_channel_1_cvterm_id,
            $fourier_transform_hpf30_green_denoised_stitched_image_channel_1_cvterm_id,
            $fourier_transform_hpf30_red_denoised_stitched_image_channel_1_cvterm_id,
            $fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1_cvterm_id,
            $fourier_transform_hpf30_nir_denoised_stitched_image_channel_1_cvterm_id
        ]
    });
    my ($result, $total_count) = $images_search->search();
    #print STDERR Dumper $result;

    # my $ft_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'fourier_transform_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    # my $ft_stitched_images_search = CXGN::DroneImagery::ImagesSearch->new({
    #     bcs_schema=>$schema,
    #     project_image_type_id=>$ft_stitched_drone_images_cvterm_id
    # });
    # my ($ft_stitched_result, $ft_stitched_total_count) = $ft_stitched_images_search->search();
    #print STDERR Dumper $ft_stitched_result;

    my $observation_unit_polygon_bw_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_bw_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_rgb_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_blue_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_blue_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_green_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_green_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_red_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_red_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_red_edge_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_red_edge_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_nir_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_nir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_mir_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_mir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_fir_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_tir_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_tir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();

    my $observation_unit_polygon_original_background_removed_threshold_imagery_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_band_project_id_list=>[$drone_run_band_project_id],
        project_image_type_id_list=>[$observation_unit_polygon_bw_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_rgb_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_blue_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_green_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_red_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_red_edge_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_nir_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_mir_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_fir_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_tir_background_removed_threshold_imagery_cvterm_id]
    });
    my ($observation_unit_polygon_original_background_removed_threshold_imagery_result, $observation_unit_polygon_original_background_removed_threshold_imagery_total_count) = $observation_unit_polygon_original_background_removed_threshold_imagery_search->search();
    #print STDERR Dumper $observation_unit_polygon_original_background_removed_threshold_imagery_result;

    my $plot_polygon_tgi_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_tgi_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_vari_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_vari_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_ndvi_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_ndvi_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_ndre_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_ndre_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_background_removed_tgi_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_background_removed_tgi_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_background_removed_vari_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_background_removed_vari_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_background_removed_ndvi_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_background_removed_ndvi_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_background_removed_ndre_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_background_removed_ndre_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_original_background_removed_thresholded_tgi_mask_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_original_background_removed_thresholded_vari_mask_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_original_background_removed_thresholded_ndvi_mask_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_ndvi_mask_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_original_background_removed_thresholded_ndre_mask_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_ndre_mask_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_original_background_removed_tgi_mask_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_tgi_mask_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_original_background_removed_vari_mask_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_vari_mask_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_original_background_removed_ndvi_mask_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_ndvi_mask_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_original_background_removed_ndre_mask_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_ndre_mask_imagery', 'project_md_image')->cvterm_id();
    my $plot_polygon_original_ourier_transform_hpf30_nrn_denoised_stitched_image_channel_1_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id();
    my $plot_polygon_original_ourier_transform_hpf30_blue_denoised_stitched_image_channel_1_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id();
    my $plot_polygon_original_ourier_transform_hpf30_green_denoised_stitched_image_channel_1_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_green_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id();
    my $plot_polygon_original_ourier_transform_hpf30_red_denoised_stitched_image_channel_1_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_red_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id();
    my $plot_polygon_original_ourier_transform_hpf30_rededge_denoised_stitched_image_channel_1_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id();
    my $plot_polygon_original_ourier_transform_hpf30_nir_denoised_stitched_image_channel_1_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id();

    my $plot_polygons_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_band_project_id_list=>[$drone_run_band_project_id],
        project_image_type_id_list=>[
            $plot_polygon_tgi_stitched_drone_images_cvterm_id,
            $plot_polygon_vari_stitched_drone_images_cvterm_id,
            $plot_polygon_ndvi_stitched_drone_images_cvterm_id,
            $plot_polygon_ndre_stitched_drone_images_cvterm_id,
            $plot_polygon_background_removed_tgi_stitched_drone_images_cvterm_id,
            $plot_polygon_background_removed_vari_stitched_drone_images_cvterm_id,
            $plot_polygon_background_removed_ndvi_stitched_drone_images_cvterm_id,
            $plot_polygon_background_removed_ndre_stitched_drone_images_cvterm_id,
            $plot_polygon_original_background_removed_thresholded_tgi_mask_images_cvterm_id,
            $plot_polygon_original_background_removed_thresholded_vari_mask_images_cvterm_id,
            $plot_polygon_original_background_removed_thresholded_ndvi_mask_images_cvterm_id,
            $plot_polygon_original_background_removed_thresholded_ndre_mask_images_cvterm_id,
            $plot_polygon_original_background_removed_tgi_mask_images_cvterm_id,
            $plot_polygon_original_background_removed_vari_mask_images_cvterm_id,
            $plot_polygon_original_background_removed_ndvi_mask_images_cvterm_id,
            $plot_polygon_original_background_removed_ndre_mask_images_cvterm_id,
            $plot_polygon_original_ourier_transform_hpf30_nrn_denoised_stitched_image_channel_1_cvterm_id,
            $plot_polygon_original_ourier_transform_hpf30_blue_denoised_stitched_image_channel_1_cvterm_id,
            $plot_polygon_original_ourier_transform_hpf30_green_denoised_stitched_image_channel_1_cvterm_id,
            $plot_polygon_original_ourier_transform_hpf30_red_denoised_stitched_image_channel_1_cvterm_id,
            $plot_polygon_original_ourier_transform_hpf30_rededge_denoised_stitched_image_channel_1_cvterm_id,
            $plot_polygon_original_ourier_transform_hpf30_nir_denoised_stitched_image_channel_1_cvterm_id
        ]
    });
    my ($plot_polygons_result, $plot_polygons_total_count) = $plot_polygons_images_search->search();
    #print STDERR Dumper $plot_polygons_result;

    my @return;
    my %unique_drone_runs;
    foreach (@$result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_source_tag_tiny = $image->get_img_src_tag("tiny");
        my $image_source_tag_small = $image->get_img_src_tag("thumbnail");
        my $image_original = $image->get_image_url("original");
        if ($_->{project_image_type_name} eq 'raw_drone_imagery') {
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
        elsif ($_->{project_image_type_name} eq 'stitched_drone_imagery') {
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
        elsif ($_->{project_image_type_name} eq 'cropped_stitched_drone_imagery') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{cropped_stitched_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{cropped_stitched_image_username} = $_->{username};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{cropped_stitched_image_modified_date} = $_->{image_modified_date};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{cropped_stitched_image_original} = $image_original;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{cropped_stitched_image_id} = $image_id;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{cropped_stitched_image_polygon} = $_->{drone_run_band_cropped_polygon};
        }
        elsif ($_->{project_image_type_name} eq 'rotated_stitched_drone_imagery') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{rotated_stitched_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{rotated_stitched_image_username} = $_->{username};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{rotated_stitched_image_modified_date} = $_->{image_modified_date};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{rotated_stitched_image_original} = $image_original;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{rotated_stitched_image_id} = $image_id;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{rotated_stitched_image_angle} = $_->{drone_run_band_rotate_angle};
        }
        elsif ($_->{project_image_type_name} eq 'denoised_stitched_drone_imagery') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_stitched_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_stitched_image_username} = $_->{username};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_stitched_image_modified_date} = $_->{image_modified_date};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_stitched_image_original} = $image_original;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_stitched_image_id} = $image_id;
        }
        elsif ($_->{project_image_type_name} eq 'calculate_tgi_drone_imagery') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{vegetative_index_tgi_stitched_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{vegetative_index_tgi_username} = $_->{username};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{vegetative_index_tgi_modified_date} = $_->{image_modified_date};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{vegetative_index_tgi_image_original} = $image_original;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{vegetative_index_tgi_image_id} = $image_id;
        }
        elsif ($_->{project_image_type_name} eq 'calculate_vari_drone_imagery') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{vegetative_index_vari_stitched_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{vegetative_index_vari_username} = $_->{username};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{vegetative_index_vari_modified_date} = $_->{image_modified_date};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{vegetative_index_vari_image_original} = $image_original;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{vegetative_index_vari_image_id} = $image_id;
        }
        elsif ($_->{project_image_type_name} eq 'calculate_ndvi_drone_imagery') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{vegetative_index_ndvi_stitched_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{vegetative_index_ndvi_username} = $_->{username};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{vegetative_index_ndvi_modified_date} = $_->{image_modified_date};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{vegetative_index_ndvi_image_original} = $image_original;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{vegetative_index_ndvi_image_id} = $image_id;
        }
        elsif ($_->{project_image_type_name} eq 'calculate_ndre_drone_imagery') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{vegetative_index_ndre_stitched_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{vegetative_index_ndre_username} = $_->{username};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{vegetative_index_ndre_modified_date} = $_->{image_modified_date};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{vegetative_index_ndre_image_original} = $image_original;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{vegetative_index_ndre_image_id} = $image_id;
        }
        elsif ($_->{project_image_type_name} eq 'threshold_background_removed_stitched_drone_imagery') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{threshold_background_removed_stitched_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{threshold_background_removed_stitched_image_username} = $_->{username};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{threshold_background_removed_stitched_image_modified_date} = $_->{image_modified_date};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{threshold_background_removed_stitched_image_original} = $image_original;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{threshold_background_removed_stitched_image_id} = $image_id;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{threshold_background_removed_stitched_image_threshold} = $_->{drone_run_band_removed_background_threshold};
        }
        elsif ($_->{project_image_type_name} eq 'threshold_background_removed_tgi_stitched_drone_imagery') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{threshold_background_removed_tgi_stitched_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{threshold_background_removed_tgi_stitched_image_username} = $_->{username};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{threshold_background_removed_tgi_stitched_image_modified_date} = $_->{image_modified_date};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{threshold_background_removed_tgi_stitched_image_original} = $image_original;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{threshold_background_removed_tgi_stitched_image_id} = $image_id;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{threshold_background_removed_tgi_stitched_image_threshold} = $_->{drone_run_band_removed_background_tgi_threshold};
        }
        elsif ($_->{project_image_type_name} eq 'threshold_background_removed_vari_stitched_drone_imagery') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{threshold_background_removed_vari_stitched_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{threshold_background_removed_vari_stitched_image_username} = $_->{username};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{threshold_background_removed_vari_stitched_image_modified_date} = $_->{image_modified_date};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{threshold_background_removed_vari_stitched_image_original} = $image_original;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{threshold_background_removed_vari_stitched_image_id} = $image_id;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{threshold_background_removed_vari_stitched_image_threshold} = $_->{drone_run_band_removed_background_vari_threshold};
        }
        elsif ($_->{project_image_type_name} eq 'threshold_background_removed_ndvi_stitched_drone_imagery') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{threshold_background_removed_ndvi_stitched_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{threshold_background_removed_ndvi_stitched_image_username} = $_->{username};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{threshold_background_removed_ndvi_stitched_image_modified_date} = $_->{image_modified_date};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{threshold_background_removed_ndvi_stitched_image_original} = $image_original;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{threshold_background_removed_ndvi_stitched_image_id} = $image_id;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{threshold_background_removed_ndvi_stitched_image_threshold} = $_->{drone_run_band_removed_background_ndvi_threshold};
        }
        elsif ($_->{project_image_type_name} eq 'threshold_background_removed_ndre_stitched_drone_imagery') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{threshold_background_removed_ndre_stitched_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{threshold_background_removed_ndre_stitched_image_username} = $_->{username};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{threshold_background_removed_ndre_stitched_image_modified_date} = $_->{image_modified_date};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{threshold_background_removed_ndre_stitched_image_original} = $image_original;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{threshold_background_removed_ndre_stitched_image_id} = $image_id;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{threshold_background_removed_ndre_stitched_image_threshold} = $_->{drone_run_band_removed_background_ndre_threshold};
        }
        elsif ($_->{project_image_type_name} eq 'denoised_background_removed_thresholded_tgi_mask_original') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_thresholded_tgi_mask_original_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_thresholded_tgi_mask_original_image_username} = $_->{username};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_thresholded_tgi_mask_original_modified_date} = $_->{image_modified_date};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_thresholded_tgi_mask_original_image_original} = $image_original;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_thresholded_tgi_mask_original_image_id} = $image_id;
        }
        elsif ($_->{project_image_type_name} eq 'denoised_background_removed_thresholded_vari_mask_original') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_thresholded_vari_mask_original_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_thresholded_vari_mask_original_image_username} = $_->{username};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_thresholded_vari_mask_original_modified_date} = $_->{image_modified_date};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_thresholded_vari_mask_original_image_original} = $image_original;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_thresholded_vari_mask_original_image_id} = $image_id;
        }
        elsif ($_->{project_image_type_name} eq 'denoised_background_removed_thresholded_ndvi_mask_original') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_thresholded_ndvi_mask_original_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_thresholded_ndvi_mask_original_image_username} = $_->{username};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_thresholded_ndvi_mask_original_modified_date} = $_->{image_modified_date};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_thresholded_ndvi_mask_original_image_original} = $image_original;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_thresholded_ndvi_mask_original_image_id} = $image_id;
        }
        elsif ($_->{project_image_type_name} eq 'denoised_background_removed_thresholded_ndre_mask_original') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_thresholded_ndre_mask_original_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_thresholded_ndre_mask_original_image_username} = $_->{username};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_thresholded_ndre_mask_original_modified_date} = $_->{image_modified_date};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_thresholded_ndre_mask_original_image_original} = $image_original;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_thresholded_ndre_mask_original_image_id} = $image_id;
        }
        elsif ($_->{project_image_type_name} eq 'denoised_background_removed_tgi_mask_original') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_tgi_mask_original_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_tgi_mask_original_image_username} = $_->{username};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_tgi_mask_original_modified_date} = $_->{image_modified_date};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_tgi_mask_original_image_original} = $image_original;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_tgi_mask_original_image_id} = $image_id;
        }
        elsif ($_->{project_image_type_name} eq 'denoised_background_removed_vari_mask_original') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_vari_mask_original_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_vari_mask_original_image_username} = $_->{username};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_vari_mask_original_modified_date} = $_->{image_modified_date};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_vari_mask_original_image_original} = $image_original;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_vari_mask_original_image_id} = $image_id;
        }
        elsif ($_->{project_image_type_name} eq 'denoised_background_removed_ndvi_mask_original') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_ndvi_mask_original_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_ndvi_mask_original_image_username} = $_->{username};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_ndvi_mask_original_modified_date} = $_->{image_modified_date};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_ndvi_mask_original_image_original} = $image_original;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_ndvi_mask_original_image_id} = $image_id;
        }
        elsif ($_->{project_image_type_name} eq 'denoised_background_removed_ndre_mask_original') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_ndre_mask_original_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_ndre_mask_original_image_username} = $_->{username};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_ndre_mask_original_modified_date} = $_->{image_modified_date};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_ndre_mask_original_image_original} = $image_original;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{denoised_background_removed_ndre_mask_original_image_id} = $image_id;
        }
        elsif ($_->{project_image_type_name} eq 'calculate_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{calculate_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{calculate_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1_image_username} = $_->{username};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{calculate_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1_modified_date} = $_->{image_modified_date};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{calculate_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1_original} = $image_original;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{calculate_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1_image_id} = $image_id;
        }
        elsif ($_->{project_image_type_name} eq 'calculate_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{calculate_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{calculate_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1_image_username} = $_->{username};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{calculate_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1_modified_date} = $_->{image_modified_date};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{calculate_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1_original} = $image_original;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{calculate_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1_image_id} = $image_id;
        }
        elsif ($_->{project_image_type_name} eq 'calculate_fourier_transform_hpf30_green_denoised_stitched_image_channel_1') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{calculate_fourier_transform_hpf30_green_denoised_stitched_image_channel_1_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{calculate_fourier_transform_hpf30_green_denoised_stitched_image_channel_1_image_username} = $_->{username};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{calculate_fourier_transform_hpf30_green_denoised_stitched_image_channel_1_modified_date} = $_->{image_modified_date};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{calculate_fourier_transform_hpf30_green_denoised_stitched_image_channel_1_original} = $image_original;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{calculate_fourier_transform_hpf30_green_denoised_stitched_image_channel_1_image_id} = $image_id;
        }
        elsif ($_->{project_image_type_name} eq 'calculate_fourier_transform_hpf30_red_denoised_stitched_image_channel_1') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{calculate_fourier_transform_hpf30_red_denoised_stitched_image_channel_1_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{calculate_fourier_transform_hpf30_red_denoised_stitched_image_channel_1_image_username} = $_->{username};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{calculate_fourier_transform_hpf30_red_denoised_stitched_image_channel_1_modified_date} = $_->{image_modified_date};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{calculate_fourier_transform_hpf30_red_denoised_stitched_image_channel_1_original} = $image_original;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{calculate_fourier_transform_hpf30_red_denoised_stitched_image_channel_1_image_id} = $image_id;
        }
        elsif ($_->{project_image_type_name} eq 'calculate_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{calculate_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{calculate_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1_image_username} = $_->{username};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{calculate_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1_modified_date} = $_->{image_modified_date};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{calculate_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1_original} = $image_original;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{calculate_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1_image_id} = $image_id;
        }
        elsif ($_->{project_image_type_name} eq 'calculate_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{calculate_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{calculate_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1_image_username} = $_->{username};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{calculate_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1_modified_date} = $_->{image_modified_date};
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{calculate_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1_original} = $image_original;
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{calculate_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1_image_id} = $image_id;
        }
        else {
            die "ERROR: project_image_type_name: ".$_->{project_image_type_name}." not accepted 1!\n";
        }
    }

    foreach (@$plot_polygons_result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_source_tag_tiny = $image->get_img_src_tag("tiny");
        my $image_original = $image->get_image_url("original");
        if ($_->{project_image_type_name} eq 'observation_unit_polygon_tgi_imagery') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_plot_polygons_tgi} = $_->{drone_run_band_plot_polygons};
            push @{$unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{plot_polygon_tgi_images}}, '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
        }
        elsif ($_->{project_image_type_name} eq 'observation_unit_polygon_vari_imagery') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_plot_polygons_vari} = $_->{drone_run_band_plot_polygons};
            push @{$unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{plot_polygon_vari_images}}, '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
        }
        elsif ($_->{project_image_type_name} eq 'observation_unit_polygon_ndvi_imagery') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_plot_polygons_ndvi} = $_->{drone_run_band_plot_polygons};
            push @{$unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{plot_polygon_ndvi_images}}, '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
        }
        elsif ($_->{project_image_type_name} eq 'observation_unit_polygon_ndre_imagery') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_plot_polygons_ndre} = $_->{drone_run_band_plot_polygons};
            push @{$unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{plot_polygon_ndre_images}}, '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
        }
        elsif ($_->{project_image_type_name} eq 'observation_unit_polygon_background_removed_tgi_imagery') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_plot_polygons_background_removed_tgi} = $_->{drone_run_band_plot_polygons};
            push @{$unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{plot_polygon_background_removed_tgi_images}}, '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
        }
        elsif ($_->{project_image_type_name} eq 'observation_unit_polygon_background_removed_vari_imagery') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_plot_polygons_background_removed_vari} = $_->{drone_run_band_plot_polygons};
            push @{$unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{plot_polygon_background_removed_vari_images}}, '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
        }
        elsif ($_->{project_image_type_name} eq 'observation_unit_polygon_background_removed_ndvi_imagery') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_plot_polygons_background_removed_ndvi} = $_->{drone_run_band_plot_polygons};
            push @{$unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{plot_polygon_background_removed_ndvi_images}}, '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
        }
        elsif ($_->{project_image_type_name} eq 'observation_unit_polygon_background_removed_ndre_imagery') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_plot_polygons_background_removed_ndre} = $_->{drone_run_band_plot_polygons};
            push @{$unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{plot_polygon_background_removed_ndre_images}}, '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
        }
        elsif ($_->{project_image_type_name} eq 'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_plot_polygons_original_background_removed_thresholded_tgi_mask} = $_->{drone_run_band_plot_polygons};
            push @{$unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{plot_polygon_original_background_removed_thresholded_tgi_mask_images}}, '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
        }
        elsif ($_->{project_image_type_name} eq 'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_plot_polygons_original_background_removed_thresholded_vari_mask} = $_->{drone_run_band_plot_polygons};
            push @{$unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{plot_polygon_original_background_removed_thresholded_vari_mask_images}}, '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
        }
        elsif ($_->{project_image_type_name} eq 'observation_unit_polygon_original_background_removed_thresholded_ndvi_mask_imagery') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_plot_polygons_original_background_removed_thresholded_ndvi_mask} = $_->{drone_run_band_plot_polygons};
            push @{$unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{plot_polygon_original_background_removed_thresholded_ndvi_mask_images}}, '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
        }
        elsif ($_->{project_image_type_name} eq 'observation_unit_polygon_original_background_removed_thresholded_ndre_mask_imagery') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_plot_polygons_original_background_removed_thresholded_ndre_mask} = $_->{drone_run_band_plot_polygons};
            push @{$unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{plot_polygon_original_background_removed_thresholded_ndre_mask_images}}, '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
        }
        elsif ($_->{project_image_type_name} eq 'observation_unit_polygon_original_background_removed_tgi_mask_imagery') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_plot_polygons_original_background_removed_tgi_mask} = $_->{drone_run_band_plot_polygons};
            push @{$unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{plot_polygon_original_background_removed_tgi_mask_images}}, '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
        }
        elsif ($_->{project_image_type_name} eq 'observation_unit_polygon_original_background_removed_vari_mask_imagery') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_plot_polygons_original_background_removed_vari_mask} = $_->{drone_run_band_plot_polygons};
            push @{$unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{plot_polygon_original_background_removed_vari_mask_images}}, '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
        }
        elsif ($_->{project_image_type_name} eq 'observation_unit_polygon_original_background_removed_ndvi_mask_imagery') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_plot_polygons_original_background_removed_ndvi_mask} = $_->{drone_run_band_plot_polygons};
            push @{$unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{plot_polygon_original_background_removed_ndvi_mask_images}}, '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
        }
        elsif ($_->{project_image_type_name} eq 'observation_unit_polygon_original_background_removed_ndre_mask_imagery') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_plot_polygons_original_background_removed_ndre_mask} = $_->{drone_run_band_plot_polygons};
            push @{$unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{plot_polygon_original_background_removed_ndre_mask_images}}, '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
        }
        elsif ($_->{project_image_type_name} eq 'observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_plot_polygons_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1} = $_->{drone_run_band_plot_polygons};
            push @{$unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{plot_polygon_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1_images}}, '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
        }
        elsif ($_->{project_image_type_name} eq 'observation_unit_polygon_fourier_transform_hpf30_red_denoised_stitched_image_channel_1') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_plot_polygons_fourier_transform_hpf30_red_denoised_stitched_image_channel_1} = $_->{drone_run_band_plot_polygons};
            push @{$unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{plot_polygon_fourier_transform_hpf30_red_denoised_stitched_image_channel_1_images}}, '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
        }
        elsif ($_->{project_image_type_name} eq 'observation_unit_polygon_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_plot_polygons_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1} = $_->{drone_run_band_plot_polygons};
            push @{$unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{plot_polygon_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1_images}}, '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
        }
        elsif ($_->{project_image_type_name} eq 'observation_unit_polygon_fourier_transform_hpf30_green_denoised_stitched_image_channel_1') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_plot_polygons_fourier_transform_hpf30_green_denoised_stitched_image_channel_1} = $_->{drone_run_band_plot_polygons};
            push @{$unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{plot_polygon_fourier_transform_hpf30_green_denoised_stitched_image_channel_1_images}}, '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
        }
        elsif ($_->{project_image_type_name} eq 'observation_unit_polygon_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_plot_polygons_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1} = $_->{drone_run_band_plot_polygons};
            push @{$unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{plot_polygon_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1_images}}, '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
        }
        elsif ($_->{project_image_type_name} eq 'observation_unit_polygon_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1') {
            $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_plot_polygons_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1} = $_->{drone_run_band_plot_polygons};
            push @{$unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{plot_polygon_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1_images}}, '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
        }
        else {
            print STDERR "ERROR: project_image_type_name: ".$_->{project_image_type_name}." not accepted 2!\n";
        }
    }

    foreach (@$observation_unit_polygon_original_background_removed_threshold_imagery_result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_source_tag_tiny = $image->get_img_src_tag("tiny");
        my $image_original = $image->get_image_url("original");
        $unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{drone_run_band_plot_polygons} = $_->{drone_run_band_plot_polygons};
        push @{$unique_drone_runs{$_->{drone_run_project_id}}->{bands}->{$_->{drone_run_band_project_id}}->{observation_unit_polygon_original_background_removed_threshold_images}}, '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
    }

    #print STDERR Dumper \%unique_drone_runs;

    my $calendar_funcs = CXGN::Calendar->new({});
    foreach my $k (sort keys %unique_drone_runs) {
        my $v = $unique_drone_runs{$k};

        my $drone_run_bands = $v->{bands};

        my $drone_run_band_table_html = '';

        foreach my $drone_run_band_project_id (sort keys %$drone_run_bands) {
            my $d = $drone_run_bands->{$drone_run_band_project_id};

            # $drone_run_band_table_html .= '<div class="panel-group" id="drone_run_band_raw_images_accordion_'.$drone_run_band_project_id.'"><div class="panel panel-default"><div class="panel-heading"><h4 class="panel-title"><a data-toggle="collapse" data-parent="#drone_run_band_raw_images_accordion_'.$drone_run_band_project_id.'" href="#drone_run_band_raw_images_accordion_one_'.$drone_run_band_project_id.'">View Raw Drone Run Images</a></h4></div><div id="drone_run_band_raw_images_accordion_one_'.$drone_run_band_project_id.'" class="panel-collapse collapse"><div class="panel-body">';
            #
            # $drone_run_band_table_html .= '<div class="well well-sm">';
            #
            # if ($d->{images}) {
            #     $drone_run_band_table_html .= '<b>'.scalar(@{$d->{images}})." Raw Unstitched Images</b>:<br/><span>";
            #     $drone_run_band_table_html .= join '', @{$d->{images}};
            #     $drone_run_band_table_html .= "</span>";
            #
            #     my $usernames = '';
            #     foreach (keys %{$d->{usernames}}){
            #         $usernames .= " $_ ";
            #     }
            #     $drone_run_band_table_html .= '<br/><br/>';
            #     $drone_run_band_table_html .= '<b>Uploaded By</b>: '.$usernames;
            # } else {
            #     $drone_run_band_table_html .= '<b>No Raw Unstitched Images</b>';
            # }
            # $drone_run_band_table_html .= '</div>';
            #
            # $drone_run_band_table_html .= '</div></div></div></div>';

            if ($d->{stitched_image}) {
                $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-6"><h5>Stitched Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{stitched_image_id}.'"></span></h5><b>By</b>: '.$d->{stitched_image_username}.'<br/><b>Date</b>: '.$d->{stitched_image_modified_date}.'</div><div class="col-sm-6">'.$d->{stitched_image}.'</div></div></div>';

                if ($d->{rotated_stitched_image}) {
                    $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-6"><h5>Rotated Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{rotated_stitched_image_id}.'"></span></h5><b>By</b>: '.$d->{rotated_stitched_image_username}.'<br/><b>Date</b>: '.$d->{rotated_stitched_image_modified_date}.'<br/><b>Rotated Angle</b>: '.$d->{rotated_stitched_image_angle}.'</div><div class="col-sm-6">'.$d->{rotated_stitched_image}.'</div></div></div>';

                    if ($d->{cropped_stitched_image}) {
                        $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-6"><h5>Cropped Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{cropped_stitched_image_id}.'"></span></h5><b>By</b>: '.$d->{cropped_stitched_image_username}.'<br/><b>Date</b>: '.$d->{cropped_stitched_image_modified_date}.'<br/><b>Cropped Polygon</b>: '.$d->{cropped_stitched_image_polygon}.'</div><div class="col-sm-6">'.$d->{cropped_stitched_image}.'</div></div></div>';

                        if ($d->{denoised_stitched_image}) {
                            $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-6"><h5>Original Denoised Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{denoised_stitched_image_id}.'"></span></h5><b>By</b>: '.$d->{denoised_stitched_image_username}.'</br><b>Date</b>: '.$d->{denoised_stitched_image_modified_date}.'</div><div class="col-sm-6">'.$d->{denoised_stitched_image}.'</div></div></div>';

                            $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_add_georeference" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" >Add Georeferenced Points</button><br/><br/>';

                            if ($d->{drone_run_band_project_type} eq 'RGB Color Image' || $d->{drone_run_band_project_type} eq 'Merged 3 Bands BGR' || $d->{drone_run_band_project_type} eq 'Merged 3 Bands NRN' || $d->{drone_run_band_project_type} eq 'Merged 3 Bands NReN') {
                                if ($d->{drone_run_band_project_type} eq 'RGB Color Image') {
                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_rgb_vegetative" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-denoised_stitched_image="'.uri_encode($d->{denoised_stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'">Convert to Vegetative Index</button><br/><br/>';
                                }
                                if ($d->{drone_run_band_project_type} eq 'Merged 3 Bands BGR') {
                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_3_band_bgr_vegetative" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-denoised_stitched_image="'.uri_encode($d->{denoised_stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'">Convert to Vegetative Index</button><br/><br/>';
                                }
                                if ($d->{drone_run_band_project_type} eq 'Merged 3 Bands NRN') {
                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_3_band_nrn_vegetative" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-denoised_stitched_image="'.uri_encode($d->{denoised_stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'">Convert to Vegetative Index</button><br/><br/>';
                                }
                                if ($d->{drone_run_band_project_type} eq 'Merged 3 Bands NReN') {
                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_3_band_nren_vegetative" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-denoised_stitched_image="'.uri_encode($d->{denoised_stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'">Convert to Vegetative Index</button><br/><br/>';
                                }
                            } else {
                                $drone_run_band_table_html .= '<button class="btn btn-default btn-sm disabled">Vegetative index cannot be calculated on an image with a single channel.<br/>You can merge bands into a multi-channel image using the "Merge Drone Run Bands" button below this table</button><br/><br/>';
                            }

                            $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_fourier_transform_hpf30" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-denoised_stitched_image="'.uri_encode($d->{denoised_stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'", data-selected_image_type="denoised_stitched_image" >Convert to Fourier Transform HPF30</button><br/><br/>';

                            my $plot_polygon_type = '';
                            if ($d->{drone_run_band_project_type} eq 'Black and White Image') {
                                $plot_polygon_type = 'observation_unit_polygon_bw_background_removed_threshold_imagery';
                            } elsif ($d->{drone_run_band_project_type} eq 'RGB Color Image') {
                                $plot_polygon_type = 'observation_unit_polygon_rgb_background_removed_threshold_imagery';
                            } elsif ($d->{drone_run_band_project_type} eq 'Blue (450-520nm)') {
                                $plot_polygon_type = 'observation_unit_polygon_blue_background_removed_threshold_imagery';
                            } elsif ($d->{drone_run_band_project_type} eq 'Green (515-600nm)') {
                                $plot_polygon_type = 'observation_unit_polygon_green_background_removed_threshold_imagery';
                            } elsif ($d->{drone_run_band_project_type} eq 'Red (600-690nm)') {
                                $plot_polygon_type = 'observation_unit_polygon_red_background_removed_threshold_imagery';
                            } elsif ($d->{drone_run_band_project_type} eq 'Red Edge (690-750nm)') {
                                $plot_polygon_type = 'observation_unit_polygon_red_edge_background_removed_threshold_imagery';
                            } elsif ($d->{drone_run_band_project_type} eq 'NIR (750-900nm)') {
                                $plot_polygon_type = 'observation_unit_polygon_nir_background_removed_threshold_imagery';
                            } elsif ($d->{drone_run_band_project_type} eq 'MIR (1550-1750nm)') {
                                $plot_polygon_type = 'observation_unit_polygon_mir_background_removed_threshold_imagery';
                            } elsif ($d->{drone_run_band_project_type} eq 'FIR (2080-2350nm)') {
                                $plot_polygon_type = 'observation_unit_polygon_fir_background_removed_threshold_imagery';
                            } elsif ($d->{drone_run_band_project_type} eq 'Thermal IR (10400-12500nm)') {
                                $plot_polygon_type = 'observation_unit_polygon_tir_background_removed_threshold_imagery';
                            }

                            if ($d->{vegetative_index_tgi_stitched_image}) {
                                $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>TGI Vegetative Index Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{vegetative_index_tgi_image_id}.'"></span></h5><b>By</b>: '.$d->{vegetative_index_tgi_username}.'</br><b>Date</b>: '.$d->{vegetative_index_tgi_modified_date}.'</div><div class="col-sm-3">'.$d->{vegetative_index_tgi_stitched_image}.'</div><div class="col-sm-6">';

                                $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{vegetative_index_tgi_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_tgi_imagery">Create/View Plot Polygons</button>';

                                $drone_run_band_table_html .= '<hr>';
                                my $plot_polygon_tgi_images = '';
                                if ($d->{plot_polygon_tgi_images}) {
                                    $plot_polygon_tgi_images = scalar(@{$d->{plot_polygon_tgi_images}})." Plot Polygons<br/><span>";
                                    $plot_polygon_tgi_images .= join '', @{$d->{plot_polygon_tgi_images}};
                                    $plot_polygon_tgi_images .= "</span>";
                                    $plot_polygon_tgi_images .= '<br/><br/>';
                                    $plot_polygon_tgi_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_tgi_imagery" >Calculate Phenotypes</button>';
                                } else {
                                    $plot_polygon_tgi_images = 'No Plot Polygons Assigned';
                                }
                                $drone_run_band_table_html .= $plot_polygon_tgi_images;

                                $drone_run_band_table_html .= '</div></div></div>';

                                if ($d->{threshold_background_removed_tgi_stitched_image}) {
                                    $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>Background Removed TGI Vegetative Index Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{threshold_background_removed_tgi_stitched_image_id}.'"></span></h5><b>By</b>: '.$d->{threshold_background_removed_tgi_stitched_image_username}.'</br><b>Date</b>: '.$d->{threshold_background_removed_tgi_stitched_image_modified_date}.'<br/><b>Background Removed Threshold</b>: '.$d->{threshold_background_removed_tgi_stitched_image_threshold}.'</div><div class="col-sm-3">'.$d->{threshold_background_removed_tgi_stitched_image}.'</div><div class="col-sm-6">';

                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{threshold_background_removed_tgi_stitched_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_background_removed_tgi_imagery">Create/View Plot Polygons</button>';

                                    $drone_run_band_table_html .= '<hr>';
                                    my $plot_polygon_background_removed_tgi_images = '';
                                    if ($d->{plot_polygon_background_removed_tgi_images}) {
                                        $plot_polygon_background_removed_tgi_images = scalar(@{$d->{plot_polygon_background_removed_tgi_images}})." Plot Polygons<br/><span>";
                                        $plot_polygon_background_removed_tgi_images .= join '', @{$d->{plot_polygon_background_removed_tgi_images}};
                                        $plot_polygon_background_removed_tgi_images .= "</span>";
                                        $plot_polygon_background_removed_tgi_images .= '<br/><br/>';
                                        $plot_polygon_background_removed_tgi_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_background_removed_tgi_imagery" >Calculate Phenotypes</button>';
                                    } else {
                                        $plot_polygon_background_removed_tgi_images = 'No Plot Polygons Assigned';
                                    }
                                    $drone_run_band_table_html .= $plot_polygon_background_removed_tgi_images;

                                    $drone_run_band_table_html .= '</div></div></div>';

                                    if ($d->{denoised_background_removed_thresholded_tgi_mask_original_image}) {
                                        $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>Background Removed TGI Vegetative Index Mask on Original Denoised Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{denoised_background_removed_thresholded_tgi_mask_original_image_id}.'"></span></h5><b>By</b>: '.$d->{denoised_background_removed_thresholded_tgi_mask_original_image_username}.'</br><b>Date</b>: '.$d->{denoised_background_removed_thresholded_tgi_mask_original_modified_date}.'</div><div class="col-sm-3">'.$d->{denoised_background_removed_thresholded_tgi_mask_original_image}.'</div><div class="col-sm-6">';

                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{denoised_background_removed_thresholded_tgi_mask_original_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery">Create/View Plot Polygons</button>';

                                        $drone_run_band_table_html .= '<hr>';
                                        my $plot_polygon_original_background_removed_thresholded_tgi_mask_images = '';
                                        if ($d->{plot_polygon_original_background_removed_thresholded_tgi_mask_images}) {
                                            $plot_polygon_original_background_removed_thresholded_tgi_mask_images = scalar(@{$d->{plot_polygon_original_background_removed_thresholded_tgi_mask_images}})." Plot Polygons<br/><span>";
                                            $plot_polygon_original_background_removed_thresholded_tgi_mask_images .= join '', @{$d->{plot_polygon_original_background_removed_thresholded_tgi_mask_images}};
                                            $plot_polygon_original_background_removed_thresholded_tgi_mask_images .= "</span>";
                                            $plot_polygon_original_background_removed_thresholded_tgi_mask_images .= '<br/><br/>';
                                            $plot_polygon_original_background_removed_thresholded_tgi_mask_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery" >Calculate Phenotypes</button>';
                                        } else {
                                            $plot_polygon_original_background_removed_thresholded_tgi_mask_images = 'No Plot Polygons Assigned';
                                        }
                                        $drone_run_band_table_html .= $plot_polygon_original_background_removed_thresholded_tgi_mask_images;

                                        $drone_run_band_table_html .= '</div></div></div>';
                                    } else {
                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_apply_tgi_removed_background_mask_to_denoised_image" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'"  data-background_removed_tgi_stitched_image_id="'.$d->{threshold_background_removed_tgi_stitched_image_id}.'" >Remove Background From Original Denoised Image via Thresholded TGI Mask</button><br/><br/>';
                                    }
                                    if ($d->{denoised_background_removed_tgi_mask_original_image}) {
                                        $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>TGI Vegetative Index Mask on Original Denoised Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{denoised_background_removed_tgi_mask_original_image_id}.'"></span></h5><b>By</b>: '.$d->{denoised_background_removed_tgi_mask_original_image_username}.'</br><b>Date</b>: '.$d->{denoised_background_removed_tgi_mask_original_modified_date}.'</div><div class="col-sm-3">'.$d->{denoised_background_removed_tgi_mask_original_image}.'</div><div class="col-sm-6">';

                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{denoised_background_removed_tgi_mask_original_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_original_background_removed_tgi_mask_imagery">Create/View Plot Polygons</button>';

                                        $drone_run_band_table_html .= '<hr>';
                                        my $plot_polygon_original_background_removed_tgi_mask_images = '';
                                        if ($d->{plot_polygon_original_background_removed_tgi_mask_images}) {
                                            $plot_polygon_original_background_removed_tgi_mask_images = scalar(@{$d->{plot_polygon_original_background_removed_tgi_mask_images}})." Plot Polygons<br/><span>";
                                            $plot_polygon_original_background_removed_tgi_mask_images .= join '', @{$d->{plot_polygon_original_background_removed_tgi_mask_images}};
                                            $plot_polygon_original_background_removed_tgi_mask_images .= "</span>";
                                            $plot_polygon_original_background_removed_tgi_mask_images .= '<br/><br/>';
                                            $plot_polygon_original_background_removed_tgi_mask_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_original_background_removed_tgi_mask_imagery" >Calculate Phenotypes</button>';
                                        } else {
                                            $plot_polygon_original_background_removed_tgi_mask_images = 'No Plot Polygons Assigned';
                                        }
                                        $drone_run_band_table_html .= $plot_polygon_original_background_removed_tgi_mask_images;

                                        $drone_run_band_table_html .= '</div></div></div>';
                                    } else {
                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_apply_tgi_mask_to_denoised_image" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'"  data-tgi_stitched_image_id="'.$d->{calculate_tgi_drone_imagery}.'" >Remove Background From Original Denoised Image via TGI Mask</button><br/><br/>';
                                    }
                                } else {
                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_remove_background" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-denoised_stitched_image="'.uri_encode($d->{denoised_stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-remove_background_current_image_id="'.$d->{vegetative_index_tgi_image_id}.'" data-remove_background_current_image_type="threshold_background_removed_tgi_stitched_drone_imagery" >TGI Vegetative Index Remove Background via Threshold</button><br/><br/>';
                                }
                            }
                            if ($d->{vegetative_index_vari_stitched_image}) {
                                $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>VARI Vegetative Index Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{vegetative_index_vari_image_id}.'"></span></h5><b>By</b>: '.$d->{vegetative_index_tgi_username}.'</br><b>Date</b>: '.$d->{vegetative_index_vari_modified_date}.'</div><div class="col-sm-3">'.$d->{vegetative_index_vari_stitched_image}.'</div><div class="col-sm-6">';

                                $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{vegetative_index_vari_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_vari_imagery">Create/View Plot Polygons</button>';

                                $drone_run_band_table_html .= '<hr>';
                                my $plot_polygon_vari_images = '';
                                if ($d->{plot_polygon_vari_images}) {
                                    $plot_polygon_vari_images = scalar(@{$d->{plot_polygon_vari_images}})." Plot Polygons<br/><span>";
                                    $plot_polygon_vari_images .= join '', @{$d->{plot_polygon_vari_images}};
                                    $plot_polygon_vari_images .= "</span>";
                                    $plot_polygon_vari_images .= '<br/><br/>';
                                    $plot_polygon_vari_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_vari_imagery" >Calculate Phenotypes</button>';
                                } else {
                                    $plot_polygon_vari_images = 'No Plot Polygons Assigned';
                                }
                                $drone_run_band_table_html .= $plot_polygon_vari_images;

                                $drone_run_band_table_html .= '</div></div></div>';

                                if ($d->{threshold_background_removed_vari_stitched_image}) {
                                    $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>Background Removed VARI Vegetative Index Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{threshold_background_removed_vari_stitched_image_id}.'"></span></h5><b>By</b>: '.$d->{threshold_background_removed_vari_stitched_image_username}.'</br><b>Date</b>: '.$d->{threshold_background_removed_vari_stitched_image_modified_date}.'<br/><b>Background Removed Threshold</b>: '.$d->{threshold_background_removed_vari_stitched_image_threshold}.'</div><div class="col-sm-3">'.$d->{threshold_background_removed_vari_stitched_image}.'</div><div class="col-sm-6">';

                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{threshold_background_removed_vari_stitched_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_background_removed_vari_imagery">Create/View Plot Polygons</button>';

                                    $drone_run_band_table_html .= '<hr>';
                                    my $plot_polygon_background_removed_vari_images = '';
                                    if ($d->{plot_polygon_background_removed_vari_images}) {
                                        $plot_polygon_background_removed_vari_images = scalar(@{$d->{plot_polygon_background_removed_vari_images}})." Plot Polygons<br/><span>";
                                        $plot_polygon_background_removed_vari_images .= join '', @{$d->{plot_polygon_background_removed_vari_images}};
                                        $plot_polygon_background_removed_vari_images .= "</span>";
                                        $plot_polygon_background_removed_vari_images .= '<br/><br/>';
                                        $plot_polygon_background_removed_vari_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_background_removed_vari_imagery" >Calculate Phenotypes</button>';
                                    } else {
                                        $plot_polygon_background_removed_vari_images = 'No Plot Polygons Assigned';
                                    }
                                    $drone_run_band_table_html .= $plot_polygon_background_removed_vari_images;

                                    $drone_run_band_table_html .= '</div></div></div>';

                                    if ($d->{denoised_background_removed_thresholded_vari_mask_original_image}) {
                                        $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>Background Removed VARI Vegetative Index Mask on Original Denoised Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{denoised_background_removed_thresholded_vari_mask_original_image_id}.'"></span></h5><b>By</b>: '.$d->{denoised_background_removed_thresholded_vari_mask_original_image_username}.'</br><b>Date</b>: '.$d->{denoised_background_removed_thresholded_vari_mask_original_image_modified_date}.'</div><div class="col-sm-3">'.$d->{denoised_background_removed_thresholded_vari_mask_original_image}.'</div><div class="col-sm-6">';

                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{denoised_background_removed_thresholded_vari_mask_original_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery" >Create/View Plot Polygons</button>';

                                        $drone_run_band_table_html .= '<hr>';
                                        my $plot_polygon_original_background_removed_thresholded_vari_mask_images = '';
                                        if ($d->{plot_polygon_original_background_removed_thresholded_vari_mask_images}) {
                                            $plot_polygon_original_background_removed_thresholded_vari_mask_images = scalar(@{$d->{plot_polygon_original_background_removed_thresholded_vari_mask_images}})." Plot Polygons<br/><span>";
                                            $plot_polygon_original_background_removed_thresholded_vari_mask_images .= join '', @{$d->{plot_polygon_original_background_removed_thresholded_vari_mask_images}};
                                            $plot_polygon_original_background_removed_thresholded_vari_mask_images .= "</span>";
                                            $plot_polygon_original_background_removed_thresholded_vari_mask_images .= '<br/><br/>';
                                            $plot_polygon_original_background_removed_thresholded_vari_mask_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery" >Calculate Phenotypes</button>';
                                        } else {
                                            $plot_polygon_original_background_removed_thresholded_vari_mask_images = 'No Plot Polygons Assigned';
                                        }
                                        $drone_run_band_table_html .= $plot_polygon_original_background_removed_thresholded_vari_mask_images;

                                        $drone_run_band_table_html .= '</div></div></div>';
                                    } else {
                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_apply_vari_removed_background_mask_to_denoised_image" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'"  data-background_removed_vari_stitched_image_id="'.$d->{threshold_background_removed_vari_stitched_image_id}.'" >Remove Background From Original Denoised Image via Thresholded VARI Mask</button><br/><br/>';
                                    }
                                    if ($d->{denoised_background_removed_vari_mask_original_image}) {
                                        $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>VARI Vegetative Index Mask on Original Denoised Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{denoised_background_removed_vari_mask_original_image_id}.'"></span></h5><b>By</b>: '.$d->{denoised_background_removed_vari_mask_original_image_username}.'</br><b>Date</b>: '.$d->{denoised_background_removed_vari_mask_original_image_modified_date}.'</div><div class="col-sm-3">'.$d->{denoised_background_removed_vari_mask_original_image}.'</div><div class="col-sm-6">';

                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{denoised_background_removed_vari_mask_original_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_original_background_removed_vari_mask_imagery" >Create/View Plot Polygons</button>';

                                        $drone_run_band_table_html .= '<hr>';
                                        my $plot_polygon_original_background_removed_vari_mask_images = '';
                                        if ($d->{plot_polygon_original_background_removed_vari_mask_images}) {
                                            $plot_polygon_original_background_removed_vari_mask_images = scalar(@{$d->{plot_polygon_original_background_removed_vari_mask_images}})." Plot Polygons<br/><span>";
                                            $plot_polygon_original_background_removed_vari_mask_images .= join '', @{$d->{plot_polygon_original_background_removed_vari_mask_images}};
                                            $plot_polygon_original_background_removed_vari_mask_images .= "</span>";
                                            $plot_polygon_original_background_removed_vari_mask_images .= '<br/><br/>';
                                            $plot_polygon_original_background_removed_vari_mask_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_original_background_removed_vari_mask_imagery" >Calculate Phenotypes</button>';
                                        } else {
                                            $plot_polygon_original_background_removed_vari_mask_images = 'No Plot Polygons Assigned';
                                        }
                                        $drone_run_band_table_html .= $plot_polygon_original_background_removed_vari_mask_images;

                                        $drone_run_band_table_html .= '</div></div></div>';
                                    } else {
                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_apply_vari_mask_to_denoised_image" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'"  data-vari_stitched_image_id="'.$d->{calculate_vari_drone_imagery}.'" >Remove Background From Original Denoised Image via VARI Mask</button><br/><br/>';
                                    }
                                } else {
                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_remove_background" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-denoised_stitched_image="'.uri_encode($d->{denoised_stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-remove_background_current_image_id="'.$d->{vegetative_index_vari_image_id}.'" data-remove_background_current_image_type="threshold_background_removed_vari_stitched_drone_imagery" >VARI Vegetative Index Remove Background via Threshold</button><br/><br/>';
                                }
                            }
                            if ($d->{vegetative_index_ndvi_stitched_image}) {
                                $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>NDVI Vegetative Index Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{vegetative_index_ndvi_image_id}.'"></span></h5><b>By</b>: '.$d->{vegetative_index_ndvi_username}.'</br><b>Date</b>: '.$d->{vegetative_index_ndvi_modified_date}.'</div><div class="col-sm-3">'.$d->{vegetative_index_ndvi_stitched_image}.'</div><div class="col-sm-6">';

                                $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{vegetative_index_ndvi_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_ndvi_imagery">Create/View Plot Polygons</button>';

                                $drone_run_band_table_html .= '<hr>';
                                my $plot_polygon_ndvi_images = '';
                                if ($d->{plot_polygon_ndvi_images}) {
                                    $plot_polygon_ndvi_images = scalar(@{$d->{plot_polygon_ndvi_images}})." Plot Polygons<br/><span>";
                                    $plot_polygon_ndvi_images .= join '', @{$d->{plot_polygon_ndvi_images}};
                                    $plot_polygon_ndvi_images .= "</span>";
                                    $plot_polygon_ndvi_images .= '<br/><br/>';
                                    $plot_polygon_ndvi_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_ndvi_imagery" >Calculate Phenotypes</button>';
                                } else {
                                    $plot_polygon_ndvi_images = 'No Plot Polygons Assigned';
                                }
                                $drone_run_band_table_html .= $plot_polygon_ndvi_images;

                                $drone_run_band_table_html .= '</div></div></div>';

                                if ($d->{threshold_background_removed_ndvi_stitched_image}) {
                                    $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>Background Removed NDVI Vegetative Index Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{threshold_background_removed_ndvi_stitched_image_id}.'"></span></h5><b>By</b>: '.$d->{threshold_background_removed_ndvi_stitched_image_username}.'</br><b>Date</b>: '.$d->{threshold_background_removed_ndvi_stitched_image_modified_date}.'<br/><b>Background Removed Threshold</b>: '.$d->{threshold_background_removed_ndvi_stitched_image_threshold}.'</div><div class="col-sm-3">'.$d->{threshold_background_removed_ndvi_stitched_image}.'</div><div class="col-sm-6">';

                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{threshold_background_removed_ndvi_stitched_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_background_removed_ndvi_imagery">Create/View Plot Polygons</button>';

                                    $drone_run_band_table_html .= '<hr>';
                                    my $plot_polygon_background_removed_ndvi_images = '';
                                    if ($d->{plot_polygon_background_removed_ndvi_images}) {
                                        $plot_polygon_background_removed_ndvi_images = scalar(@{$d->{plot_polygon_background_removed_ndvi_images}})." Plot Polygons<br/><span>";
                                        $plot_polygon_background_removed_ndvi_images .= join '', @{$d->{plot_polygon_background_removed_ndvi_images}};
                                        $plot_polygon_background_removed_ndvi_images .= "</span>";
                                        $plot_polygon_background_removed_ndvi_images .= '<br/><br/>';
                                        $plot_polygon_background_removed_ndvi_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_background_removed_ndvi_imagery" >Calculate Phenotypes</button>';
                                    } else {
                                        $plot_polygon_background_removed_ndvi_images = 'No Plot Polygons Assigned';
                                    }
                                    $drone_run_band_table_html .= $plot_polygon_background_removed_ndvi_images;

                                    $drone_run_band_table_html .= '</div></div></div>';

                                    if ($d->{denoised_background_removed_thresholded_ndvi_mask_original_image}) {
                                        $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>Background Removed NDVI Vegetative Index Mask on Original Denoised Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{denoised_background_removed_thresholded_ndvi_mask_original_image_id}.'"></span></h5><b>By</b>: '.$d->{denoised_background_removed_thresholded_ndvi_mask_original_image_username}.'</br><b>Date</b>: '.$d->{denoised_background_removed_thresholded_ndvi_mask_original_image_modified_date}.'</div><div class="col-sm-3">'.$d->{denoised_background_removed_thresholded_ndvi_mask_original_image}.'</div><div class="col-sm-6">';

                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{denoised_background_removed_thresholded_ndvi_mask_original_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_original_background_removed_thresholded_ndvi_mask_imagery" >Create/View Plot Polygons</button>';

                                        $drone_run_band_table_html .= '<hr>';
                                        my $plot_polygon_original_background_removed_thresholded_ndvi_mask_images = '';
                                        if ($d->{plot_polygon_original_background_removed_thresholded_ndvi_mask_images}) {
                                            $plot_polygon_original_background_removed_thresholded_ndvi_mask_images = scalar(@{$d->{plot_polygon_original_background_removed_thresholded_ndvi_mask_images}})." Plot Polygons<br/><span>";
                                            $plot_polygon_original_background_removed_thresholded_ndvi_mask_images .= join '', @{$d->{plot_polygon_original_background_removed_thresholded_ndvi_mask_images}};
                                            $plot_polygon_original_background_removed_thresholded_ndvi_mask_images .= "</span>";
                                            $plot_polygon_original_background_removed_thresholded_ndvi_mask_images .= '<br/><br/>';
                                            $plot_polygon_original_background_removed_thresholded_ndvi_mask_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_original_background_removed_thresholded_ndvi_mask_imagery" >Calculate Phenotypes</button>';
                                        } else {
                                            $plot_polygon_original_background_removed_thresholded_ndvi_mask_images = 'No Plot Polygons Assigned';
                                        }
                                        $drone_run_band_table_html .= $plot_polygon_original_background_removed_thresholded_ndvi_mask_images;

                                        $drone_run_band_table_html .= '</div></div></div>';
                                    } else {
                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_apply_ndvi_removed_background_mask_to_denoised_image" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'"  data-background_removed_ndvi_stitched_image_id="'.$d->{threshold_background_removed_ndvi_stitched_image_id}.'" >Remove Background From Original Denoised Image via Thresholded NDVI Mask</button><br/><br/>';
                                    }
                                    if ($d->{denoised_background_removed_ndvi_mask_original_image}) {
                                        $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>NDVI Vegetative Index Mask on Original Denoised Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{denoised_background_removed_ndvi_mask_original_image_id}.'"></span></h5><b>By</b>: '.$d->{denoised_background_removed_ndvi_mask_original_image_username}.'</br><b>Date</b>: '.$d->{denoised_background_removed_ndvi_mask_original_image_modified_date}.'</div><div class="col-sm-3">'.$d->{denoised_background_removed_ndvi_mask_original_image}.'</div><div class="col-sm-6">';

                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{denoised_background_removed_ndvi_mask_original_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_original_background_removed_ndvi_mask_imagery" >Create/View Plot Polygons</button>';

                                        $drone_run_band_table_html .= '<hr>';
                                        my $plot_polygon_original_background_removed_ndvi_mask_images = '';
                                        if ($d->{plot_polygon_original_background_removed_ndvi_mask_images}) {
                                            $plot_polygon_original_background_removed_ndvi_mask_images = scalar(@{$d->{plot_polygon_original_background_removed_ndvi_mask_images}})." Plot Polygons<br/><span>";
                                            $plot_polygon_original_background_removed_ndvi_mask_images .= join '', @{$d->{plot_polygon_original_background_removed_ndvi_mask_images}};
                                            $plot_polygon_original_background_removed_ndvi_mask_images .= "</span>";
                                            $plot_polygon_original_background_removed_ndvi_mask_images .= '<br/><br/>';
                                            $plot_polygon_original_background_removed_ndvi_mask_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_original_background_removed_ndvi_mask_imagery" >Calculate Phenotypes</button>';
                                        } else {
                                            $plot_polygon_original_background_removed_ndvi_mask_images = 'No Plot Polygons Assigned';
                                        }
                                        $drone_run_band_table_html .= $plot_polygon_original_background_removed_ndvi_mask_images;

                                        $drone_run_band_table_html .= '</div></div></div>';
                                    } else {
                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_apply_ndvi_mask_to_denoised_image" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'"  data-ndvi_stitched_image_id="'.$d->{calculate_ndvi_drone_imagery}.'" >Remove Background From Original Denoised Image via NDVI Mask</button><br/><br/>';
                                    }
                                } else {
                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_remove_background" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-denoised_stitched_image="'.uri_encode($d->{denoised_stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-remove_background_current_image_id="'.$d->{vegetative_index_ndvi_image_id}.'" data-remove_background_current_image_type="threshold_background_removed_ndvi_stitched_drone_imagery" >NDVI Vegetative Index Remove Background via Threshold</button><br/><br/>';
                                }
                            }
                            if ($d->{vegetative_index_ndre_stitched_image}) {
                                $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>NDRE Vegetative Index Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{vegetative_index_ndre_image_id}.'"></span></h5><b>By</b>: '.$d->{vegetative_index_ndre_username}.'</br><b>Date</b>: '.$d->{vegetative_index_ndre_modified_date}.'</div><div class="col-sm-3">'.$d->{vegetative_index_ndre_stitched_image}.'</div><div class="col-sm-6">';

                                $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{vegetative_index_ndre_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_ndre_imagery">Create/View Plot Polygons</button>';

                                $drone_run_band_table_html .= '<hr>';
                                my $plot_polygon_ndre_images = '';
                                if ($d->{plot_polygon_ndre_images}) {
                                    $plot_polygon_ndre_images = scalar(@{$d->{plot_polygon_ndre_images}})." Plot Polygons<br/><span>";
                                    $plot_polygon_ndre_images .= join '', @{$d->{plot_polygon_ndre_images}};
                                    $plot_polygon_ndre_images .= "</span>";
                                    $plot_polygon_ndre_images .= '<br/><br/>';
                                    $plot_polygon_ndre_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_ndre_imagery" >Calculate Phenotypes</button>';
                                } else {
                                    $plot_polygon_ndre_images = 'No Plot Polygons Assigned';
                                }
                                $drone_run_band_table_html .= $plot_polygon_ndre_images;

                                $drone_run_band_table_html .= '</div></div></div>';

                                if ($d->{threshold_background_removed_ndre_stitched_image}) {
                                    $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>Background Removed NDRE Vegetative Index Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{threshold_background_removed_ndre_stitched_image_id}.'"></span></h5><b>By</b>: '.$d->{threshold_background_removed_ndre_stitched_image_username}.'</br><b>Date</b>: '.$d->{threshold_background_removed_ndre_stitched_image_modified_date}.'<br/><b>Background Removed Threshold</b>: '.$d->{threshold_background_removed_ndre_stitched_image_threshold}.'</div><div class="col-sm-3">'.$d->{threshold_background_removed_ndre_stitched_image}.'</div><div class="col-sm-6">';

                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{threshold_background_removed_ndre_stitched_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_background_removed_ndre_imagery">Create/View Plot Polygons</button>';

                                    $drone_run_band_table_html .= '<hr>';
                                    my $plot_polygon_background_removed_ndre_images = '';
                                    if ($d->{plot_polygon_background_removed_ndre_images}) {
                                        $plot_polygon_background_removed_ndre_images = scalar(@{$d->{plot_polygon_background_removed_ndre_images}})." Plot Polygons<br/><span>";
                                        $plot_polygon_background_removed_ndre_images .= join '', @{$d->{plot_polygon_background_removed_ndre_images}};
                                        $plot_polygon_background_removed_ndre_images .= "</span>";
                                        $plot_polygon_background_removed_ndre_images .= '<br/><br/>';
                                        $plot_polygon_background_removed_ndre_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_background_removed_ndre_imagery" >Calculate Phenotypes</button>';
                                    } else {
                                        $plot_polygon_background_removed_ndre_images = 'No Plot Polygons Assigned';
                                    }
                                    $drone_run_band_table_html .= $plot_polygon_background_removed_ndre_images;

                                    $drone_run_band_table_html .= '</div></div></div>';

                                    if ($d->{denoised_background_removed_thresholded_ndre_mask_original_image}) {
                                        $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>Background Removed NDRE Vegetative Index Mask on Original Denoised Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{denoised_background_removed_thresholded_ndre_mask_original_image_id}.'"></span></h5><b>By</b>: '.$d->{denoised_background_removed_thresholded_ndre_mask_original_image_username}.'</br><b>Date</b>: '.$d->{denoised_background_removed_thresholded_ndre_mask_original_image_modified_date}.'</div><div class="col-sm-3">'.$d->{denoised_background_removed_thresholded_ndre_mask_original_image}.'</div><div class="col-sm-6">';

                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{denoised_background_removed_thresholded_ndre_mask_original_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_original_background_removed_thresholded_ndre_mask_imagery" >Create/View Plot Polygons</button>';

                                        $drone_run_band_table_html .= '<hr>';
                                        my $plot_polygon_original_background_removed_thresholded_ndre_mask_images = '';
                                        if ($d->{plot_polygon_original_background_removed_thresholded_ndre_mask_images}) {
                                            $plot_polygon_original_background_removed_thresholded_ndre_mask_images = scalar(@{$d->{plot_polygon_original_background_removed_thresholded_ndre_mask_images}})." Plot Polygons<br/><span>";
                                            $plot_polygon_original_background_removed_thresholded_ndre_mask_images .= join '', @{$d->{plot_polygon_original_background_removed_thresholded_ndre_mask_images}};
                                            $plot_polygon_original_background_removed_thresholded_ndre_mask_images .= "</span>";
                                            $plot_polygon_original_background_removed_thresholded_ndre_mask_images .= '<br/><br/>';
                                            $plot_polygon_original_background_removed_thresholded_ndre_mask_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_original_background_removed_thresholded_ndre_mask_imagery" >Calculate Phenotypes</button>';
                                        } else {
                                            $plot_polygon_original_background_removed_thresholded_ndre_mask_images = 'No Plot Polygons Assigned';
                                        }
                                        $drone_run_band_table_html .= $plot_polygon_original_background_removed_thresholded_ndre_mask_images;

                                        $drone_run_band_table_html .= '</div></div></div>';
                                    } else {
                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_apply_ndre_removed_background_mask_to_denoised_image" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'"  data-background_removed_ndre_stitched_image_id="'.$d->{threshold_background_removed_ndre_stitched_image_id}.'" >Remove Background From Original Denoised Image via Tresholded NDRE Mask</button><br/><br/>';
                                    }
                                    if ($d->{denoised_background_removed_ndre_mask_original_image}) {
                                        $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>NDRE Vegetative Index Mask on Original Denoised Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{denoised_background_removed_ndre_mask_original_image_id}.'"></span></h5><b>By</b>: '.$d->{denoised_background_removed_ndre_mask_original_image_username}.'</br><b>Date</b>: '.$d->{denoised_background_removed_ndre_mask_original_image_modified_date}.'</div><div class="col-sm-3">'.$d->{denoised_background_removed_ndre_mask_original_image}.'</div><div class="col-sm-6">';

                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{denoised_background_removed_ndre_mask_original_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_original_background_removed_ndre_mask_imagery" >Create/View Plot Polygons</button>';

                                        $drone_run_band_table_html .= '<hr>';
                                        my $plot_polygon_original_background_removed_ndre_mask_images = '';
                                        if ($d->{plot_polygon_original_background_removed_ndre_mask_images}) {
                                            $plot_polygon_original_background_removed_ndre_mask_images = scalar(@{$d->{plot_polygon_original_background_removed_ndre_mask_images}})." Plot Polygons<br/><span>";
                                            $plot_polygon_original_background_removed_ndre_mask_images .= join '', @{$d->{plot_polygon_original_background_removed_ndre_mask_images}};
                                            $plot_polygon_original_background_removed_ndre_mask_images .= "</span>";
                                            $plot_polygon_original_background_removed_ndre_mask_images .= '<br/><br/>';
                                            $plot_polygon_original_background_removed_ndre_mask_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_original_background_removed_ndre_mask_imagery" >Calculate Phenotypes</button>';
                                        } else {
                                            $plot_polygon_original_background_removed_ndre_mask_images = 'No Plot Polygons Assigned';
                                        }
                                        $drone_run_band_table_html .= $plot_polygon_original_background_removed_ndre_mask_images;

                                        $drone_run_band_table_html .= '</div></div></div>';
                                    } else {
                                        $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_apply_ndre_mask_to_denoised_image" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'"  data-ndre_stitched_image_id="'.$d->{calculate_ndre_drone_imagery}.'" >Remove Background From Original Denoised Image via NDRE Mask</button><br/><br/>';
                                    }
                                } else {
                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_remove_background" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-denoised_stitched_image="'.uri_encode($d->{denoised_stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-remove_background_current_image_id="'.$d->{vegetative_index_ndre_image_id}.'" data-remove_background_current_image_type="threshold_background_removed_ndre_stitched_drone_imagery" >NDRE Vegetative Index Remove Background via Threshold</button><br/><br/>';
                                }
                            }
                            if ($d->{calculate_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1_image}) {
                                $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>Fourier Transform HPF30 on NRN Denoised Channel 1 Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{calculate_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1_image_id}.'"></span></h5><b>By</b>: '.$d->{calculate_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1_image_username}.'</br><b>Date</b>: '.$d->{calculate_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1_modified_date}.'</div><div class="col-sm-3">'.$d->{calculate_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1_image}.'</div><div class="col-sm-6">';

                                $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{calculate_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1">Create/View Plot Polygons</button>';

                                $drone_run_band_table_html .= '<hr>';
                                my $plot_polygon_images = '';
                                if ($d->{plot_polygon_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1_images}) {
                                    $plot_polygon_images = scalar(@{$d->{plot_polygon_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1_images}})." Plot Polygons<br/><span>";
                                    $plot_polygon_images .= join '', @{$d->{plot_polygon_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1_images}};
                                    $plot_polygon_images .= "</span>";
                                    $plot_polygon_images .= '<br/><br/>';
                                    $plot_polygon_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1" >Calculate Phenotypes</button>';
                                } else {
                                    $plot_polygon_images = 'No Plot Polygons Assigned';
                                }
                                $drone_run_band_table_html .= $plot_polygon_images;

                                $drone_run_band_table_html .= '</div></div></div>';
                            }
                            if ($d->{calculate_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1_image}) {
                                $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>Fourier Transform HPF30 on Blue Denoised Channel 1 Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{calculate_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1_image_id}.'"></span></h5><b>By</b>: '.$d->{calculate_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1_image_username}.'</br><b>Date</b>: '.$d->{calculate_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1_modified_date}.'</div><div class="col-sm-3">'.$d->{calculate_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1_image}.'</div><div class="col-sm-6">';

                                $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{calculate_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1">Create/View Plot Polygons</button>';

                                $drone_run_band_table_html .= '<hr>';
                                my $plot_polygon_images = '';
                                if ($d->{plot_polygon_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1_images}) {
                                    $plot_polygon_images = scalar(@{$d->{plot_polygon_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1_images}})." Plot Polygons<br/><span>";
                                    $plot_polygon_images .= join '', @{$d->{plot_polygon_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1_images}};
                                    $plot_polygon_images .= "</span>";
                                    $plot_polygon_images .= '<br/><br/>';
                                    $plot_polygon_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1" >Calculate Phenotypes</button>';
                                } else {
                                    $plot_polygon_images = 'No Plot Polygons Assigned';
                                }
                                $drone_run_band_table_html .= $plot_polygon_images;

                                $drone_run_band_table_html .= '</div></div></div>';
                            }
                            if ($d->{calculate_fourier_transform_hpf30_green_denoised_stitched_image_channel_1_image}) {
                                $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>Fourier Transform HPF30 on Green Denoised Channel 1 Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{calculate_fourier_transform_hpf30_green_denoised_stitched_image_channel_1_image_id}.'"></span></h5><b>By</b>: '.$d->{calculate_fourier_transform_hpf30_green_denoised_stitched_image_channel_1_image_username}.'</br><b>Date</b>: '.$d->{calculate_fourier_transform_hpf30_green_denoised_stitched_image_channel_1_modified_date}.'</div><div class="col-sm-3">'.$d->{calculate_fourier_transform_hpf30_green_denoised_stitched_image_channel_1_image}.'</div><div class="col-sm-6">';

                                $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{calculate_fourier_transform_hpf30_green_denoised_stitched_image_channel_1_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_fourier_transform_hpf30_green_denoised_stitched_image_channel_1">Create/View Plot Polygons</button>';

                                $drone_run_band_table_html .= '<hr>';
                                my $plot_polygon_images = '';
                                if ($d->{plot_polygon_fourier_transform_hpf30_green_denoised_stitched_image_channel_1_images}) {
                                    $plot_polygon_images = scalar(@{$d->{plot_polygon_fourier_transform_hpf30_green_denoised_stitched_image_channel_1_images}})." Plot Polygons<br/><span>";
                                    $plot_polygon_images .= join '', @{$d->{plot_polygon_fourier_transform_hpf30_green_denoised_stitched_image_channel_1_images}};
                                    $plot_polygon_images .= "</span>";
                                    $plot_polygon_images .= '<br/><br/>';
                                    $plot_polygon_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_fourier_transform_hpf30_green_denoised_stitched_image_channel_1" >Calculate Phenotypes</button>';
                                } else {
                                    $plot_polygon_images = 'No Plot Polygons Assigned';
                                }
                                $drone_run_band_table_html .= $plot_polygon_images;

                                $drone_run_band_table_html .= '</div></div></div>';
                            }
                            if ($d->{calculate_fourier_transform_hpf30_red_denoised_stitched_image_channel_1_image}) {
                                $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>Fourier Transform HPF30 on Red Denoised Channel 1 Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{calculate_fourier_transform_hpf30_red_denoised_stitched_image_channel_1_image_id}.'"></span></h5><b>By</b>: '.$d->{calculate_fourier_transform_hpf30_red_denoised_stitched_image_channel_1_image_username}.'</br><b>Date</b>: '.$d->{calculate_fourier_transform_hpf30_red_denoised_stitched_image_channel_1_modified_date}.'</div><div class="col-sm-3">'.$d->{calculate_fourier_transform_hpf30_red_denoised_stitched_image_channel_1_image}.'</div><div class="col-sm-6">';

                                $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{calculate_fourier_transform_hpf30_red_denoised_stitched_image_channel_1_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_fourier_transform_hpf30_red_denoised_stitched_image_channel_1">Create/View Plot Polygons</button>';

                                $drone_run_band_table_html .= '<hr>';
                                my $plot_polygon_images = '';
                                if ($d->{plot_polygon_fourier_transform_hpf30_red_denoised_stitched_image_channel_1_images}) {
                                    $plot_polygon_images = scalar(@{$d->{plot_polygon_fourier_transform_hpf30_red_denoised_stitched_image_channel_1_images}})." Plot Polygons<br/><span>";
                                    $plot_polygon_images .= join '', @{$d->{plot_polygon_fourier_transform_hpf30_red_denoised_stitched_image_channel_1_images}};
                                    $plot_polygon_images .= "</span>";
                                    $plot_polygon_images .= '<br/><br/>';
                                    $plot_polygon_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_fourier_transform_hpf30_red_denoised_stitched_image_channel_1" >Calculate Phenotypes</button>';
                                } else {
                                    $plot_polygon_images = 'No Plot Polygons Assigned';
                                }
                                $drone_run_band_table_html .= $plot_polygon_images;

                                $drone_run_band_table_html .= '</div></div></div>';
                            }
                            if ($d->{calculate_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1_image}) {
                                $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>Fourier Transform HPF30 on Red Edge Denoised Channel 1 Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{calculate_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1_image_id}.'"></span></h5><b>By</b>: '.$d->{calculate_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1_image_username}.'</br><b>Date</b>: '.$d->{calculate_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1_modified_date}.'</div><div class="col-sm-3">'.$d->{calculate_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1_image}.'</div><div class="col-sm-6">';

                                $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{calculate_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1">Create/View Plot Polygons</button>';

                                $drone_run_band_table_html .= '<hr>';
                                my $plot_polygon_images = '';
                                if ($d->{plot_polygon_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1_images}) {
                                    $plot_polygon_images = scalar(@{$d->{plot_polygon_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1_images}})." Plot Polygons<br/><span>";
                                    $plot_polygon_images .= join '', @{$d->{plot_polygon_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1_images}};
                                    $plot_polygon_images .= "</span>";
                                    $plot_polygon_images .= '<br/><br/>';
                                    $plot_polygon_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1" >Calculate Phenotypes</button>';
                                } else {
                                    $plot_polygon_images = 'No Plot Polygons Assigned';
                                }
                                $drone_run_band_table_html .= $plot_polygon_images;

                                $drone_run_band_table_html .= '</div></div></div>';
                            }
                            if ($d->{calculate_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1_image}) {
                                $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>Fourier Transform HPF30 on NIR Denoised Channel 1 Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{calculate_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1_image_id}.'"></span></h5><b>By</b>: '.$d->{calculate_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1_image_username}.'</br><b>Date</b>: '.$d->{calculate_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1_modified_date}.'</div><div class="col-sm-3">'.$d->{calculate_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1_image}.'</div><div class="col-sm-6">';

                                $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{calculate_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1_image_id}.'" data-assign_plot_polygons_type="observation_unit_polygon_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1">Create/View Plot Polygons</button>';

                                $drone_run_band_table_html .= '<hr>';
                                my $plot_polygon_images = '';
                                if ($d->{plot_polygon_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1_images}) {
                                    $plot_polygon_images = scalar(@{$d->{plot_polygon_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1_images}})." Plot Polygons<br/><span>";
                                    $plot_polygon_images .= join '', @{$d->{plot_polygon_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1_images}};
                                    $plot_polygon_images .= "</span>";
                                    $plot_polygon_images .= '<br/><br/>';
                                    $plot_polygon_images .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="observation_unit_polygon_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1" >Calculate Phenotypes</button>';
                                } else {
                                    $plot_polygon_images = 'No Plot Polygons Assigned';
                                }
                                $drone_run_band_table_html .= $plot_polygon_images;

                                $drone_run_band_table_html .= '</div></div></div>';
                            }
                            if ( (!$d->{vegetative_index_tgi_stitched_image} && !$d->{vegetative_index_vari_stitched_image} && !$d->{vegetative_index_ndvi_stitched_image} && !$d->{vegetative_index_ndre_stitched_image} ) || $d->{threshold_background_removed_stitched_image} ) {

                                if ($d->{threshold_background_removed_stitched_image}) {
                                    $drone_run_band_table_html .= '<div class="well well-sm"><div class="row"><div class="col-sm-3"><h5>Background Removed Original Denoised Image&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$d->{threshold_background_removed_stitched_image_id}.'"></span></h5><b>By</b>: '.$d->{threshold_background_removed_stitched_image_username}.'</br><b>Date</b>: '.$d->{threshold_background_removed_stitched_image_modified_date}.'<br/><b>Background Removed Threshold</b>: '.$d->{threshold_background_removed_stitched_image_threshold}.'</div><div class="col-sm-3">'.$d->{threshold_background_removed_stitched_image}.'</div><div class="col-sm-6">';

                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$d->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$d->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-background_removed_stitched_image_id="'.$d->{threshold_background_removed_stitched_image_id}.'" data-assign_plot_polygons_type="'.$plot_polygon_type.'">Create/View Plot Polygons</button>';

                                    $drone_run_band_table_html .= '<hr>';
                                    my $plot_polygon_original_background_removed_threshold_images = '';
                                    if ($d->{observation_unit_polygon_original_background_removed_threshold_images}) {
                                        $plot_polygon_original_background_removed_threshold_images = scalar(@{$d->{observation_unit_polygon_original_background_removed_threshold_images}})." Plot Polygons<br/><span>";
                                        $plot_polygon_original_background_removed_threshold_images .= join '', @{$d->{observation_unit_polygon_original_background_removed_threshold_images}};
                                        $plot_polygon_original_background_removed_threshold_images .= "</span>";
                                        $plot_polygon_original_background_removed_threshold_images .= '<br/><br/><button class="btn btn-primary btn-sm" name="project_drone_imagery_get_phenotypes" data-field_trial_id="'.$v->{trial_id}.'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-drone_run_band_project_type="'.$d->{drone_run_band_project_type}.'" data-plot_polygons_type="'.$plot_polygon_type.'" >Calculate Phenotypes</button>';
                                    } else {
                                        $plot_polygon_original_background_removed_threshold_images = 'No Plot Polygons Assigned';
                                    }
                                    $drone_run_band_table_html .= $plot_polygon_original_background_removed_threshold_images;

                                    $drone_run_band_table_html .= '</div></div></div>';
                                } else {
                                    $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_remove_background" data-denoised_stitched_image_id="'.$d->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($d->{stitched_image_original}).'" data-denoised_stitched_image="'.uri_encode($d->{denoised_stitched_image_original}).'" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" data-remove_background_current_image_id="'.$d->{denoised_stitched_image_id}.'" data-remove_background_current_image_type="threshold_background_removed_stitched_drone_imagery" >Remove Background From Original Denoised Image via Threshold</button><br/><br/>';
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
                $drone_run_band_table_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_stitch" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" >Stitch Uploaded Images Into Ortho Image Now</button><br/><br/>';
                $drone_run_band_table_html .= '<button class="btn btn-default btn-sm" name="project_drone_imagery_upload_stitched" data-drone_run_project_id="'.$k.'" data-drone_run_band_project_id="'.$drone_run_band_project_id.'" >Upload Previously Stitched Ortho Image</button>';
            }


        }

        push @return, [$drone_run_band_table_html];
    }

    $c->stash->{rest} = { data => \@return };
}

sub drone_imagery_analysis_query : Path('/api/drone_imagery/analysis_query') : ActionClass('REST') { }

sub drone_imagery_analysis_query_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    my $main_production_site = $c->config->{main_production_site_url};

    my $observation_unit_polygon_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_bw_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_bw_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_rgb_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_blue_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_blue_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_green_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_green_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_red_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_red_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_red_edge_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_red_edge_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_nir_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_nir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_mir_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_mir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_fir_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_tir_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_tir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_tgi_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_tgi_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_vari_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_vari_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_ndvi_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_ndvi_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_background_removed_tgi_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_background_removed_tgi_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_background_removed_vari_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_background_removed_vari_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_background_removed_ndvi_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_background_removed_ndvi_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_original_background_removed_tgi_mask_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_tgi_mask_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_original_background_removed_vari_mask_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_vari_mask_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_original_background_removed_ndvi_mask_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_ndvi_mask_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_original_background_removed_thresholded_ndvi_mask_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_ndvi_mask_imagery', 'project_md_image')->cvterm_id();

    my $drone_run_project_id_list = $c->req->param('drone_run_project_id_list') ? decode_json $c->req->param('drone_run_project_id_list') : [];
    my $drone_run_band_project_id_list = $c->req->param('drone_run_band_project_id_list') ? decode_json $c->req->param('drone_run_band_project_id_list') : [];
    my $trait_id_list = $c->req->param('observation_variable_id_list') ? decode_json $c->req->param('observation_variable_id_list') : [];
    my $return_format = $c->req->param('format') || 'csv';
    my $trial_name_list = $c->req->param('trial_name_list');
    my $trial_id_list = $c->req->param('field_trial_id_list') ? decode_json $c->req->param('field_trial_id_list') : [];
    my $project_image_type_id_list = $c->req->param('project_image_type_id_list') ? decode_json $c->req->param('project_image_type_id_list') : [$observation_unit_polygon_imagery_cvterm_id,
    $observation_unit_polygon_bw_background_removed_threshold_imagery_cvterm_id,
    $observation_unit_polygon_rgb_background_removed_threshold_imagery_cvterm_id,
    $observation_unit_polygon_blue_background_removed_threshold_imagery_cvterm_id,
    $observation_unit_polygon_green_background_removed_threshold_imagery_cvterm_id,
    $observation_unit_polygon_red_background_removed_threshold_imagery_cvterm_id,
    $observation_unit_polygon_red_edge_background_removed_threshold_imagery_cvterm_id,
    $observation_unit_polygon_nir_background_removed_threshold_imagery_cvterm_id,
    $observation_unit_polygon_mir_background_removed_threshold_imagery_cvterm_id,
    $observation_unit_polygon_fir_background_removed_threshold_imagery_cvterm_id,
    $observation_unit_polygon_tir_background_removed_threshold_imagery_cvterm_id,
    $observation_unit_polygon_tgi_imagery_cvterm_id,
    $observation_unit_polygon_vari_imagery_cvterm_id,
    $observation_unit_polygon_ndvi_imagery_cvterm_id,
    $observation_unit_polygon_background_removed_tgi_imagery_cvterm_id,
    $observation_unit_polygon_background_removed_vari_imagery_cvterm_id,
    $observation_unit_polygon_background_removed_ndvi_imagery_cvterm_id,
    $observation_unit_polygon_original_background_removed_tgi_mask_imagery_cvterm_id,
    $observation_unit_polygon_original_background_removed_vari_mask_imagery_cvterm_id,
    $observation_unit_polygon_original_background_removed_ndvi_mask_imagery_cvterm_id,
    $observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_cvterm_id,
    $observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_cvterm_id,
    $observation_unit_polygon_original_background_removed_thresholded_ndvi_mask_imagery_cvterm_id];

    my %return;

    my $raw_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'raw_drone_imagery', 'project_md_image')->cvterm_id();
    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_project_id_list=>$drone_run_project_id_list,
        drone_run_band_project_id_list=>$drone_run_band_project_id_list,
        project_image_type_id_list=>$project_image_type_id_list
    });
    my ($result, $total_count) = $images_search->search();
    print STDERR "Query found ".scalar(@$result)." Images\n";

    my %image_data_hash;
    my %project_image_type_names;
    foreach (@$result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_url = $image->get_image_url("original");
        my $image_fullpath = $image->get_filename('original_converted', 'full');
        push @{$image_data_hash{$_->{stock_id}}->{$_->{drone_run_band_project_name}.$_->{project_image_type_name}}}, $main_production_site.$image_url;
        $project_image_type_names{$_->{drone_run_band_project_name}.$_->{project_image_type_name}}++;
    }
    my @project_image_names_list = sort keys %project_image_type_names;

    if ($trial_name_list) {
        my @trial_names = split ',', $trial_name_list;
        my $trial_search = CXGN::Trial::Search->new({
            bcs_schema=>$schema,
            trial_name_list=>\@trial_names
        });
        my ($result, $total_count) = $trial_search->search();
        foreach (@$result) {
            push @$trial_id_list, $_->{trial_id};
        }
    }

    my %data_hash;
    my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
        bcs_schema=>$schema,
        search_type=>'MaterializedViewTable',
        data_level=>'plot',
        trait_list=>$trait_id_list,
        trial_list=>$trial_id_list,
        include_timestamp=>0,
        exclude_phenotype_outlier=>0,
    );
    my @data = $phenotypes_search->get_phenotype_matrix();

    my $phenotype_header = shift @data;
    my @total_phenotype_header = (@$phenotype_header, @project_image_names_list);
    foreach (@data) {
        $data_hash{$_->[21]} = $_;
    }

    while (my($stock_id, $image_info_hash) = each %image_data_hash) {
        foreach (@project_image_names_list) {
            my $image_string = $image_info_hash->{$_} ? join ',', @{$image_info_hash->{$_}} : '';
            push @{$data_hash{$stock_id}}, $image_string;
        }
    }
    #print STDERR Dumper \%data_hash;
    my @data_array = values %data_hash;
    my @data_total = (\@total_phenotype_header, @data_array);

    if ($return_format eq 'csv') {
        my $dir = $c->tempfiles_subdir('download');
        my ($download_file_path, $download_uri) = $c->tempfile( TEMPLATE => 'download/drone_imagery_analysis_csv_'.'XXXXX');
        my $file_response = CXGN::BrAPI::FileResponse->new({
            absolute_file_path => $download_file_path,
            absolute_file_uri => $main_production_site.$download_uri,
            format => $return_format,
            data => \@data_total
        });
        my @data_files = $file_response->get_datafiles();
        $return{file} = $data_files[0];
    } elsif ($return_format eq 'xls') {
        my $dir = $c->tempfiles_subdir('download');
        my ($download_file_path, $download_uri) = $c->tempfile( TEMPLATE => 'download/drone_imagery_analysis_xls_'.'XXXXX');
        my $file_response = CXGN::BrAPI::FileResponse->new({
            absolute_file_path => $download_file_path,
            absolute_file_uri => $main_production_site.$download_uri,
            format => $return_format,
            data => \@data_total
        });
        my @data_files = $file_response->get_datafiles();
        $return{file} = $data_files[0];
    } elsif ($return_format eq 'json') {
        $return{header} = \@total_phenotype_header;
        $return{data} = \@data_array;
    }

    $c->stash->{rest} = \%return;
}

sub raw_drone_imagery_stitch : Path('/api/drone_imagery/raw_drone_imagery_stitch') : ActionClass('REST') { }

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
    #print STDERR Dumper \@image_urls;
    my $image_urls_string = join ',', @image_urls;

    my $dir = $c->tempfiles_subdir('/stitched_drone_imagery');
    my $archive_stitched_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'stitched_drone_imagery/imageXXXX');
    $archive_stitched_temp_image .= '.png';
    print STDERR $archive_stitched_temp_image."\n";

    my $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageStitching/PanoramaStitch.py --images_urls \''.$image_urls_string.'\' --outfile_path \''.$archive_stitched_temp_image.'\'';
    print STDERR Dumper $cmd;
    my $status = system($cmd);

    my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);
    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $ret = $image->process_image($archive_stitched_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);

    $c->stash->{rest} = { data => \@image_urls };
}

sub upload_drone_imagery_stitch : Path('/api/drone_imagery/upload_drone_imagery_stitch') : ActionClass('REST') { }

sub upload_drone_imagery_stitch_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    print STDERR Dumper $c->req->params;
    my $drone_run_band_project_id = $c->req->param('drone_imagery_upload_stitched_ortho_drone_run_band_project_id');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $upload_file = $c->req->upload('drone_imagery_upload_stitched_ortho');

    my $upload_original_name = $upload_file->filename();
    my $upload_tempfile = $upload_file->tempname;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => "drone_imagery_upload_ortho",
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
    print STDERR "Archived Ortho Drone Image File: $archived_filename_with_path\n";

    my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);
    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $ret = $image->process_image($archived_filename_with_path, 'project', $drone_run_band_project_id, $linking_table_type_id);
    my $uploaded_image_fullpath = $image->get_filename('original_converted', 'full');
    my $uploaded_image_url = $image->get_image_url('original');

    $c->stash->{rest} = { success => 1, uploaded_image_url => $uploaded_image_url, uploaded_image_fullpath => $uploaded_image_fullpath };
}

sub drone_imagery_rotate_image : Path('/api/drone_imagery/rotate_image') : ActionClass('REST') { }

sub drone_imagery_rotate_image_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $image_id = $c->req->param('image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $angle_rotation = $c->req->param('angle');
    my $view_only = $c->req->param('view_only');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $dir = $c->tempfiles_subdir('/drone_imagery_rotate');
    my $archive_rotate_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_rotate/imageXXXX');
    $archive_rotate_temp_image .= '.png';
    print STDERR $archive_rotate_temp_image."\n";

    my $return = _perform_image_rotate($c, $schema, $metadata_schema, $drone_run_band_project_id, $image_id, $angle_rotation, $view_only, $user_id, $user_name, $user_role, $archive_rotate_temp_image);

    $c->stash->{rest} = $return;
}

sub _perform_image_rotate {
    my $c = shift;
    my $schema = shift;
    my $metadata_schema = shift;
    my $drone_run_band_project_id = shift;
    my $image_id = shift;
    my $angle_rotation = shift;
    my $view_only = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    my $archive_rotate_temp_image = shift;

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');
    print STDERR Dumper $image_url;
    print STDERR Dumper $image_fullpath;

    my $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/Rotate.py --image_path \''.$image_fullpath.'\' --outfile_path \''.$archive_rotate_temp_image.'\' --angle '.$angle_rotation;
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
        foreach (@$rotated_stitched_temporary_result){
            my $temp_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
            $temp_image->delete(); #Sets to obsolete
        }
        $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'rotated_stitched_drone_imagery', 'project_md_image')->cvterm_id();

        my $rotated_stitched_images_search = CXGN::DroneImagery::ImagesSearch->new({
            bcs_schema=>$schema,
            project_image_type_id=>$linking_table_type_id,
            drone_run_band_project_id_list=>[$drone_run_band_project_id]
        });
        my ($rotated_stitched_result, $rotated_stitched_total_count) = $rotated_stitched_images_search->search();
        print STDERR Dumper $rotated_stitched_total_count;
        foreach (@$rotated_stitched_result){
            my $previous_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
            $previous_image->delete(); #Sets to obsolete
        }

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

    my $rotated_image_fullpath;
    my $rotated_image_url;
    my $rotated_image_id;
    my $md5checksum = $image->calculate_md5sum($archive_rotate_temp_image);
    my $md_image = $metadata_schema->resultset("MdImage")->search({md5sum=>$md5checksum, obsolete=>'f'});
    if ($md_image->count() > 0) {
        print STDERR Dumper "Image $archive_rotate_temp_image has already been added to the database and will not be added again.";
        $image = SGN::Image->new( $schema->storage->dbh, $md_image->first->image_id, $c );
        $rotated_image_fullpath = $image->get_filename('original_converted', 'full');
        $rotated_image_url = $image->get_image_url('original');
        $rotated_image_id = $image->get_image_id();
    } else {
        my $ret = $image->process_image($archive_rotate_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
        $rotated_image_fullpath = $image->get_filename('original_converted', 'full');
        $rotated_image_url = $image->get_image_url('original');
        $rotated_image_id = $image->get_image_id();
    }
    return {
        rotated_image_id => $rotated_image_id, image_url => $image_url, image_fullpath => $image_fullpath, rotated_image_url => $rotated_image_url, rotated_image_fullpath => $rotated_image_fullpath
    };
}

sub drone_imagery_get_contours : Path('/api/drone_imagery/get_contours') : ActionClass('REST') { }

sub drone_imagery_get_contours_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
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

    my $status = system($c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/GetContours.py --image_url \''.$main_production_site.$image_url.'\' --outfile_path \''.$archive_contours_temp_image.'\'');

    my @size = imgsize($archive_contours_temp_image);

    my $contours_image_fullpath;
    my $contours_image_url;
    my $contours_image_id;

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    my $md5checksum = $image->calculate_md5sum($archive_contours_temp_image);
    my $md_image = $metadata_schema->resultset("MdImage")->search({md5sum=>$md5checksum, obsolete=>'f'});
    if ($md_image->count() > 0) {
        print STDERR Dumper "Image $archive_contours_temp_image has already been added to the database and will not be added again.";
        $image = SGN::Image->new( $schema->storage->dbh, $md_image->first->image_id, $c );
        $contours_image_fullpath = $image->get_filename('original_converted', 'full');
        $contours_image_url = $image->get_image_url('original');
        $contours_image_id = $image->get_image_id();
    } else {
        $image->set_sp_person_id($user_id);
        my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'contours_stitched_drone_imagery', 'project_md_image')->cvterm_id();

        my $previous_contour_images_search = CXGN::DroneImagery::ImagesSearch->new({
            bcs_schema=>$schema,
            project_image_type_id=>$linking_table_type_id,
            drone_run_band_project_id_list=>[$drone_run_band_project_id]
        });
        my ($previous_contour_result, $previous_contour_total_count) = $previous_contour_images_search->search();
        print STDERR Dumper $previous_contour_total_count;
        foreach (@$previous_contour_result){
            my $previous_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
            $previous_image->delete(); #Sets to obsolete
        }

        my $ret = $image->process_image($archive_contours_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
        $contours_image_fullpath = $image->get_filename('original_converted', 'full');
        $contours_image_url = $image->get_image_url('original');
        $contours_image_id = $image->get_image_id();
    }

    $c->stash->{rest} = { image_url => $image_url, image_fullpath => $image_fullpath, contours_image_id => $contours_image_id, contours_image_url => $contours_image_url, contours_image_fullpath => $contours_image_fullpath, image_width => $size[0], image_height => $size[1] };
}

sub drone_imagery_retrieve_parameter_template : Path('/api/drone_imagery/retrieve_parameter_template') : ActionClass('REST') { }

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

sub drone_imagery_assign_plot_polygons : Path('/api/drone_imagery/assign_plot_polygons') : ActionClass('REST') { }

sub drone_imagery_assign_plot_polygons_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $image_id = $c->req->param('image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $stock_polygons = $c->req->param('stock_polygons');
    my $assign_plot_polygons_type = $c->req->param('assign_plot_polygons_type');
    #print STDERR Dumper $c->req->params;

    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $return = _perform_plot_polygon_assign($c, $schema, $metadata_schema, $image_id, $drone_run_band_project_id, $stock_polygons, $assign_plot_polygons_type, $user_id, $user_name, $user_role, 1);

    $c->stash->{rest} = $return;
}

sub _perform_plot_polygon_assign {
    my $c = shift;
    my $schema = shift;
    my $metadata_schema = shift;
    my $image_id = shift;
    my $drone_run_band_project_id = shift;
    my $stock_polygons = shift;
    my $assign_plot_polygons_type = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    my $from_web_interface = shift;

    if (!$assign_plot_polygons_type) {
        my $drone_run_band_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
        my $projectprop_rs = $schema->resultset('Project::Projectprop')->search({project_id=>$drone_run_band_project_id, type_id=>$drone_run_band_type_cvterm_id});
        if ($projectprop_rs->count != 1) {
            die "Only One drone run band project type for a drone run band!\n";
        }
        my $drone_run_project_type = $projectprop_rs->first->value;
        if ($drone_run_project_type eq 'Black and White Image') {
            $assign_plot_polygons_type = 'observation_unit_polygon_bw_background_removed_threshold_imagery';
        } elsif ($drone_run_project_type eq 'RGB Color Image') {
            $assign_plot_polygons_type = 'observation_unit_polygon_rgb_background_removed_threshold_imagery';
        } elsif ($drone_run_project_type eq 'Blue (450-520nm)') {
            $assign_plot_polygons_type = 'observation_unit_polygon_blue_background_removed_threshold_imagery';
        } elsif ($drone_run_project_type eq 'Green (515-600nm)') {
            $assign_plot_polygons_type = 'observation_unit_polygon_green_background_removed_threshold_imagery';
        } elsif ($drone_run_project_type eq 'Red (600-690nm)') {
            $assign_plot_polygons_type = 'observation_unit_polygon_red_background_removed_threshold_imagery';
        } elsif ($drone_run_project_type eq 'Red Edge (690-750nm)') {
            $assign_plot_polygons_type = 'observation_unit_polygon_red_edge_background_removed_threshold_imagery';
        } elsif ($drone_run_project_type eq 'NIR (750-900nm)') {
            $assign_plot_polygons_type = 'observation_unit_polygon_nir_background_removed_threshold_imagery';
        } elsif ($drone_run_project_type eq 'MIR (1550-1750nm)') {
            $assign_plot_polygons_type = 'observation_unit_polygon_mir_background_removed_threshold_imagery';
        } elsif ($drone_run_project_type eq 'FIR (2080-2350nm)') {
            $assign_plot_polygons_type = 'observation_unit_polygon_fir_background_removed_threshold_imagery';
        } elsif ($drone_run_project_type eq 'Thermal IR (10400-12500nm)') {
            $assign_plot_polygons_type = 'observation_unit_polygon_tir_background_removed_threshold_imagery';
        }
    }

    my $main_production_site = $c->config->{main_production_site_url};

    my $polygon_objs = decode_json $stock_polygons;
    my %stock_ids;

    #print STDERR Dumper $polygon_objs;
    foreach my $stock_name (keys %$polygon_objs) {
        my $polygon = $polygon_objs->{$stock_name};
        if ($from_web_interface) {
            my $last_point = pop @$polygon;
        }
        if (scalar(@$polygon) != 4){
            $c->stash->{rest} = {error=>'Error: Polygon for '.$stock_name.' should be 4 long!'};
            $c->detach();
        }
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

    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $assign_plot_polygons_type, 'project_md_image')->cvterm_id();;

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

        my $cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/CropToPolygon.py --inputfile_path '$image_fullpath' --outputfile_path '$archive_plot_polygons_temp_image' --polygon_json '$polygons'";
        print STDERR Dumper $cmd;
        my $status = system($cmd);

        my $plot_polygon_image_fullpath;
        my $plot_polygon_image_url;
        $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
        my $md5checksum = $image->calculate_md5sum($archive_plot_polygons_temp_image);
        my $q = "SELECT md_image.image_id FROM metadata.md_image AS md_image
            JOIN phenome.project_md_image AS project_md_image ON(project_md_image.image_id = md_image.image_id)
            JOIN phenome.stock_image AS stock_image ON (stock_image.image_id = md_image.image_id)
            WHERE md_image.obsolete = 'f' AND md_image.md5sum = ? AND project_md_image.type_id = ? AND project_md_image.project_id = ? AND stock_image.stock_id = ?;";
        my $h = $schema->storage->dbh->prepare($q);
        $h->execute($md5checksum, $linking_table_type_id, $drone_run_band_project_id, $stock_id);
        my ($image_id) = $h->fetchrow_array();

        if ($image_id) {
            print STDERR Dumper "Image $archive_plot_polygons_temp_image has already been added to the database and will not be added again.";
            $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
            $plot_polygon_image_fullpath = $image->get_filename('original_converted', 'full');
            $plot_polygon_image_url = $image->get_image_url('original');
        } else {
            $image->set_sp_person_id($user_id);
            my $ret = $image->process_image($archive_plot_polygons_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
            my $stock_associate = $image->associate_stock($stock_id);
            $plot_polygon_image_fullpath = $image->get_filename('original_converted', 'full');
            $plot_polygon_image_url = $image->get_image_url('original');
        }
        push @plot_polygon_image_fullpaths, $plot_polygon_image_fullpath;
        push @plot_polygon_image_urls, $plot_polygon_image_url;
    }
    # print STDERR Dumper \@plot_polygon_image_fullpaths;
    # print STDERR Dumper \@plot_polygon_image_urls;

    return {
        image_url => $image_url, image_fullpath => $image_fullpath, success => 1
    };
}

sub drone_imagery_fourier_transform : Path('/api/drone_imagery/fourier_transform') : ActionClass('REST') { }

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

    my $status = system($c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/FourierTransform.py --image_path \''.$image_fullpath.'\' --outfile_path \''.$archive_fourier_temp_image.'\'');

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);
    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'fourier_transform_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $ret = $image->process_image($archive_fourier_temp_image, 'project', $drone_run_project_id, $linking_table_type_id);

    $c->stash->{rest} = { image_url => $image_url, image_fullpath => $image_fullpath };
}

sub drone_imagery_denoise : Path('/api/drone_imagery/denoise') : ActionClass('REST') { }

sub drone_imagery_denoise_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $image_id = $c->req->param('image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $dir = $c->tempfiles_subdir('/drone_imagery_denoise');
    my $archive_denoise_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_denoise/imageXXXX');
    $archive_denoise_temp_image .= '.png';
    print STDERR $archive_denoise_temp_image."\n";

    my $main_production_site = $c->config->{main_production_site_url};

    my $return = _perform_image_denoise($c, $schema, $metadata_schema, $image_id, $drone_run_band_project_id, $user_id, $user_name, $user_role, $archive_denoise_temp_image);

    $c->stash->{rest} = $return;
}

sub _perform_image_denoise {
    my $c = shift;
    my $schema = shift;
    my $metadata_schema = shift;
    my $image_id = shift;
    my $drone_run_band_project_id = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    my $archive_denoise_temp_image = shift;

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');
    print STDERR Dumper $image_url;
    print STDERR Dumper $image_fullpath;

    my $status = system($c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/Denoise.py --image_path \''.$image_fullpath.'\' --outfile_path \''.$archive_denoise_temp_image.'\'');

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);

    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_stitched_drone_imagery', 'project_md_image')->cvterm_id();

    my $previous_denoised_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$linking_table_type_id,
        drone_run_band_project_id_list=>[$drone_run_band_project_id]
    });
    my ($previous_denoised_result, $previous_denoised_total_count) = $previous_denoised_images_search->search();
    print STDERR Dumper $previous_denoised_total_count;
    foreach (@$previous_denoised_result){
        my $previous_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
        $previous_image->delete(); #Sets to obsolete
    }

    my $denoised_image_fullpath;
    my $denoised_image_url;
    my $denoised_image_id;
    my $md5checksum = $image->calculate_md5sum($archive_denoise_temp_image);
    my $md_image = $metadata_schema->resultset("MdImage")->search({md5sum=>$md5checksum, obsolete=>'f'});
    if ($md_image->count() > 0) {
        print STDERR Dumper "Image $archive_denoise_temp_image has already been added to the database and will not be added again.";
        $image = SGN::Image->new( $schema->storage->dbh, $md_image->first->image_id, $c );
        $denoised_image_fullpath = $image->get_filename('original_converted', 'full');
        $denoised_image_url = $image->get_image_url('original');
        $denoised_image_id = $image->get_image_id();
    } else {
        my $ret = $image->process_image($archive_denoise_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
        $denoised_image_fullpath = $image->get_filename('original_converted', 'full');
        $denoised_image_url = $image->get_image_url('original');
        $denoised_image_id = $image->get_image_id();
    }

    return {
        image_url => $image_url, image_fullpath => $image_fullpath, denoised_image_id => $denoised_image_id, denoised_image_url => $denoised_image_url, denoised_image_fullpath => $denoised_image_fullpath
    };
}

sub drone_imagery_remove_background_display : Path('/api/drone_imagery/remove_background_display') : ActionClass('REST') { }

sub drone_imagery_remove_background_display_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $image_id = $c->req->param('image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $lower_threshold = $c->req->param('lower_threshold');
    my $upper_threshold = $c->req->param('upper_threshold');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    if (!$lower_threshold && !defined($lower_threshold)) {
        $c->stash->{rest} = {error => 'Please give a lower threshold'};
        $c->detach();
    }
    if (!$upper_threshold && !defined($upper_threshold)) {
        $c->stash->{rest} = {error => 'Please give an upper threshold'};
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

    my $status = system($c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/RemoveBackground.py --image_path \''.$image_fullpath.'\' --outfile_path \''.$archive_remove_background_temp_image.'\' --lower_threshold '.$lower_threshold.' --upper_threshold '.$upper_threshold);

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);
    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'background_removed_temporary_stitched_drone_imagery', 'project_md_image')->cvterm_id();

    my $previous_background_removed_temp_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$linking_table_type_id,
        drone_run_band_project_id_list=>[$drone_run_band_project_id]
    });
    my ($previous_result, $previous_total_count) = $previous_background_removed_temp_images_search->search();
    print STDERR Dumper $previous_total_count;
    foreach (@$previous_result){
        my $previous_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
        $previous_image->delete(); #Sets to obsolete
    }

    my $ret = $image->process_image($archive_remove_background_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
    my $removed_background_image_fullpath = $image->get_filename('original_converted', 'full');
    my $removed_background_image_url = $image->get_image_url('original');

    $c->stash->{rest} = { image_url => $image_url, image_fullpath => $image_fullpath, removed_background_image_url => $removed_background_image_url, removed_background_image_fullpath => $removed_background_image_fullpath };
}

sub drone_imagery_remove_background_save : Path('/api/drone_imagery/remove_background_save') : ActionClass('REST') { }

sub drone_imagery_remove_background_save_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR Dumper $c->req->params();
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $image_id = $c->req->param('image_id');
    my $image_type = $c->req->param('image_type');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $lower_threshold = $c->req->param('lower_threshold');
    my $upper_threshold = $c->req->param('upper_threshold') || '255';
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    if (!$lower_threshold && !defined($lower_threshold)) {
        $c->stash->{rest} = {error => 'Please give a lower threshold'};
        $c->detach();
    }
    if (!$upper_threshold && !defined($upper_threshold)) {
        $c->stash->{rest} = {error => 'Please give an upper threshold'};
        $c->detach();
    }

    my $dir = $c->tempfiles_subdir('/drone_imagery_remove_background');
    my $archive_remove_background_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_remove_background/imageXXXX');
    $archive_remove_background_temp_image .= '.png';
    print STDERR $archive_remove_background_temp_image."\n";

    my $return = _perform_image_background_remove_threshold($c, $schema, $image_id, $drone_run_band_project_id, $image_type, $lower_threshold, $upper_threshold, $user_id, $user_name, $user_role, $archive_remove_background_temp_image);

    $c->stash->{rest} = $return;
}

sub _perform_image_background_remove_threshold {
    my $c = shift;
    my $schema = shift;
    my $image_id = shift;
    my $drone_run_band_project_id = shift;
    my $image_type = shift;
    my $lower_threshold = shift;
    my $upper_threshold = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    my $archive_remove_background_temp_image = shift;

    my $main_production_site = $c->config->{main_production_site_url};

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');
    print STDERR Dumper $image_url;
    print STDERR Dumper $image_fullpath;

    my $status = system($c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/RemoveBackground.py --image_path \''.$image_fullpath.'\' --outfile_path \''.$archive_remove_background_temp_image.'\' --lower_threshold '.$lower_threshold.' --upper_threshold '.$upper_threshold);

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);

    my $linking_table_type_id;
    my $drone_run_band_remove_background_threshold_type_id;
    if ($image_type eq 'threshold_background_removed_tgi_stitched_drone_imagery') {
        $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_tgi_stitched_drone_imagery', 'project_md_image')->cvterm_id();
        $drone_run_band_remove_background_threshold_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_background_removed_tgi_threshold', 'project_property')->cvterm_id();
    } elsif ($image_type eq 'threshold_background_removed_vari_stitched_drone_imagery') {
        $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_vari_stitched_drone_imagery', 'project_md_image')->cvterm_id();
        $drone_run_band_remove_background_threshold_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_background_removed_vari_threshold', 'project_property')->cvterm_id();
    } elsif ($image_type eq 'threshold_background_removed_ndvi_stitched_drone_imagery') {
        $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_ndvi_stitched_drone_imagery', 'project_md_image')->cvterm_id();
        $drone_run_band_remove_background_threshold_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_background_removed_ndvi_threshold', 'project_property')->cvterm_id();
    } elsif ($image_type eq 'threshold_background_removed_ndre_stitched_drone_imagery') {
        $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_ndre_stitched_drone_imagery', 'project_md_image')->cvterm_id();
        $drone_run_band_remove_background_threshold_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_background_removed_ndre_threshold', 'project_property')->cvterm_id();
    } elsif ($image_type eq 'threshold_background_removed_stitched_drone_imagery') {
        $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_stitched_drone_imagery', 'project_md_image')->cvterm_id();
        $drone_run_band_remove_background_threshold_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_background_removed_threshold', 'project_property')->cvterm_id();
    }

    my $previous_background_removed_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$linking_table_type_id,
        drone_run_band_project_id_list=>[$drone_run_band_project_id]
    });
    my ($previous_result, $previous_total_count) = $previous_background_removed_images_search->search();
    print STDERR Dumper $previous_total_count;
    foreach (@$previous_result){
        my $previous_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
        $previous_image->delete(); #Sets to obsolete
    }

    my $ret = $image->process_image($archive_remove_background_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
    my $removed_background_image_fullpath = $image->get_filename('original_converted', 'full');
    my $removed_background_image_url = $image->get_image_url('original');
    my $removed_background_image_id = $image->get_image_id();

    my $drone_run_band_remove_background_threshold = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$drone_run_band_remove_background_threshold_type_id,
        project_id=>$drone_run_band_project_id,
        rank=>0,
        value=>"Lower Threshold:$lower_threshold. Upper Threshold:$upper_threshold"
    },
    {
        key=>'projectprop_c1'
    });

    return {
        image_url => $image_url, image_fullpath => $image_fullpath, removed_background_image_id => $removed_background_image_id, removed_background_image_url => $removed_background_image_url, removed_background_image_fullpath => $removed_background_image_fullpath
    };
}

sub _perform_image_background_remove_threshold_percentage {
    my $c = shift;
    my $schema = shift;
    my $image_id = shift;
    my $drone_run_band_project_id = shift;
    my $image_type = shift;
    my $lower_threshold_percentage = shift;
    my $upper_threshold_percentage = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    my $archive_remove_background_temp_image = shift;

    my $main_production_site = $c->config->{main_production_site_url};

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');
    print STDERR Dumper $image_url;
    print STDERR Dumper $image_fullpath;

    my $status = system($c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/RemoveBackgroundPercentage.py --image_path \''.$image_fullpath.'\' --outfile_path \''.$archive_remove_background_temp_image.'\' --lower_percentage \''.$lower_threshold_percentage.'\' --upper_percentage \''.$upper_threshold_percentage.'\'');

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);

    my $linking_table_type_id;
    my $drone_run_band_remove_background_threshold_type_id;
    if ($image_type eq 'threshold_background_removed_tgi_stitched_drone_imagery') {
        $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_tgi_stitched_drone_imagery', 'project_md_image')->cvterm_id();
        $drone_run_band_remove_background_threshold_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_background_removed_tgi_threshold', 'project_property')->cvterm_id();
    } elsif ($image_type eq 'threshold_background_removed_vari_stitched_drone_imagery') {
        $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_vari_stitched_drone_imagery', 'project_md_image')->cvterm_id();
        $drone_run_band_remove_background_threshold_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_background_removed_vari_threshold', 'project_property')->cvterm_id();
    } elsif ($image_type eq 'threshold_background_removed_ndvi_stitched_drone_imagery') {
        $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_ndvi_stitched_drone_imagery', 'project_md_image')->cvterm_id();
        $drone_run_band_remove_background_threshold_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_background_removed_ndvi_threshold', 'project_property')->cvterm_id();
    } elsif ($image_type eq 'threshold_background_removed_stitched_drone_imagery') {
        $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'threshold_background_removed_stitched_drone_imagery', 'project_md_image')->cvterm_id();
        $drone_run_band_remove_background_threshold_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_background_removed_threshold', 'project_property')->cvterm_id();
    }

    my $previous_background_removed_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$linking_table_type_id,
        drone_run_band_project_id_list=>[$drone_run_band_project_id]
    });
    my ($previous_result, $previous_total_count) = $previous_background_removed_images_search->search();
    print STDERR Dumper $previous_total_count;
    foreach (@$previous_result){
        my $previous_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
        $previous_image->delete(); #Sets to obsolete
    }

    my $ret = $image->process_image($archive_remove_background_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
    my $removed_background_image_fullpath = $image->get_filename('original_converted', 'full');
    my $removed_background_image_url = $image->get_image_url('original');
    my $removed_background_image_id = $image->get_image_id();

    my $drone_run_band_remove_background_threshold = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$drone_run_band_remove_background_threshold_type_id,
        project_id=>$drone_run_band_project_id,
        rank=>0,
        value=>"Lower Threshold Percentage:$lower_threshold_percentage. Upper Threshold Percentage:$upper_threshold_percentage"
    },
    {
        key=>'projectprop_c1'
    });

    return {
        image_url => $image_url, image_fullpath => $image_fullpath, removed_background_image_id => $removed_background_image_id, removed_background_image_url => $removed_background_image_url, removed_background_image_fullpath => $removed_background_image_fullpath
    };
}

sub get_drone_run_projects : Path('/api/drone_imagery/drone_runs') : ActionClass('REST') { }

sub get_drone_run_projects_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    #print STDERR Dumper $c->req->params();
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
    #print STDERR Dumper \@result;

    $c->stash->{rest} = { data => \@result };
}


sub get_plot_polygon_types : Path('/api/drone_imagery/plot_polygon_types') : ActionClass('REST') { }

sub get_plot_polygon_types_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $checkbox_select_name = $c->req->param('select_checkbox_name');
    my $field_trial_id = $c->req->param('field_trial_id');
    my $drone_run_ids = $c->req->param('drone_run_ids') ? decode_json $c->req->param('drone_run_ids') : [];

    my $drone_run_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_project_type', 'project_property')->cvterm_id();
    my $drone_run_band_project_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $drone_run_field_trial_project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
    my $drone_run_band_drone_run_project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
    my $observation_unit_polygon_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'observation_unit_polygon_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_bw_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'observation_unit_polygon_bw_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_rgb_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'observation_unit_polygon_rgb_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_blue_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'observation_unit_polygon_blue_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_green_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'observation_unit_polygon_green_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_red_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'observation_unit_polygon_red_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_red_edge_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'observation_unit_polygon_red_edge_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_nir_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'observation_unit_polygon_nir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_mir_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'observation_unit_polygon_mir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_fir_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'observation_unit_polygon_fir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_tir_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'observation_unit_polygon_tir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_tgi_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'observation_unit_polygon_tgi_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_vari_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'observation_unit_polygon_vari_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_ndvi_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'observation_unit_polygon_ndvi_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_background_removed_tgi_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'observation_unit_polygon_background_removed_tgi_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_background_removed_vari_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'observation_unit_polygon_background_removed_vari_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_background_removed_ndvi_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'observation_unit_polygon_background_removed_ndvi_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_original_background_removed_tgi_mask_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'observation_unit_polygon_original_background_removed_tgi_mask_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_original_background_removed_vari_mask_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'observation_unit_polygon_original_background_removed_vari_mask_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_original_background_removed_ndvi_mask_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'observation_unit_polygon_original_background_removed_ndvi_mask_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_original_background_removed_thresholded_ndvi_mask_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'observation_unit_polygon_original_background_removed_thresholded_ndvi_mask_imagery', 'project_md_image')->cvterm_id();

    my @where_clause;
    push @where_clause, "project_md_image.type_id in ($observation_unit_polygon_imagery_cvterm_id, $observation_unit_polygon_bw_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_rgb_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_blue_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_green_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_red_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_red_edge_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_nir_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_mir_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_fir_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_tir_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_tgi_imagery_cvterm_id, $observation_unit_polygon_vari_imagery_cvterm_id, $observation_unit_polygon_ndvi_imagery_cvterm_id, $observation_unit_polygon_background_removed_tgi_imagery_cvterm_id, $observation_unit_polygon_background_removed_vari_imagery_cvterm_id, $observation_unit_polygon_background_removed_ndvi_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_tgi_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_vari_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_ndvi_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_thresholded_ndvi_mask_imagery_cvterm_id)";

    if ($field_trial_id) {
        push @where_clause, "field_trial.project_id = ?";
    }
    if ($drone_run_ids && scalar(@$drone_run_ids)>0) {
        my $sql = join ("," , @$drone_run_ids);
        push @where_clause, "drone_run.project_id in ($sql)";
    }
    my $where_clause = scalar(@where_clause)>0 ? " WHERE " . (join (" AND " , @where_clause)) : '';

    my $q = "SELECT drone_run_band.project_id, drone_run_band.name, drone_run_band.description, drone_run_band_type.value, drone_run.project_id, drone_run.name, drone_run.description, drone_run_type.value, field_trial.project_id, field_trial.name, field_trial.description, project_md_image.type_id, project_md_image_type.name, count(project_md_image.image_id)
        FROM project AS drone_run_band
        LEFT JOIN projectprop AS drone_run_band_type ON (drone_run_band.project_id=drone_run_band_type.project_id AND drone_run_band_type.type_id=$drone_run_band_project_type_cvterm_id)
        JOIN project_relationship AS drone_run_band_rel ON (drone_run_band.project_id = drone_run_band_rel.subject_project_id AND drone_run_band_rel.type_id=$drone_run_band_drone_run_project_relationship_type_id)
        JOIN project AS drone_run ON (drone_run.project_id=drone_run_band_rel.object_project_id)
        LEFT JOIN projectprop AS drone_run_type ON (drone_run.project_id=drone_run_type.project_id AND drone_run_type.type_id=$drone_run_project_type_cvterm_id)
        JOIN project_relationship AS field_trial_rel ON (drone_run.project_id = field_trial_rel.subject_project_id AND field_trial_rel.type_id=$drone_run_field_trial_project_relationship_type_id)
        JOIN project AS field_trial ON (field_trial.project_id=field_trial_rel.object_project_id)
        JOIN phenome.project_md_image AS project_md_image ON (drone_run_band.project_id = project_md_image.project_id)
        JOIN cvterm AS project_md_image_type ON (project_md_image_type.cvterm_id = project_md_image.type_id)
        $where_clause
        GROUP BY drone_run_band.project_id, drone_run_band.name, drone_run_band.description, drone_run_band_type.value, drone_run.project_id, drone_run.name, drone_run.description, drone_run_type.value, field_trial.project_id, field_trial.name, field_trial.description, project_md_image.type_id, project_md_image_type.name
        ORDER BY drone_run_band.project_id;";

    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute($field_trial_id);
    my @result;
    while (my ($drone_run_band_project_id, $drone_run_band_project_name, $drone_run_band_project_description, $drone_run_band_type, $drone_run_project_id, $drone_run_project_name, $drone_run_project_description, $drone_run_type, $field_trial_project_id, $field_trial_project_name, $field_trial_project_description, $project_md_image_type_id, $project_md_image_type_name, $plot_polygon_count) = $h->fetchrow_array()) {
        my @res;
        if ($checkbox_select_name){
            push @res, "<input type='checkbox' name='$checkbox_select_name' value='$project_md_image_type_id' checked>";
        }
        push @res, (
            "<a href=\"/breeders_toolbox/trial/$field_trial_project_id\">$field_trial_project_name</a>",
            $drone_run_project_name,
            $drone_run_band_project_name,
            $drone_run_band_type,
            $project_md_image_type_name,
            $plot_polygon_count
        );
        push @result, \@res;
    }

    $c->stash->{rest} = { data => \@result };
}


# jQuery('#drone_image_upload_drone_bands_table').DataTable({
#     destroy : true,
#     ajax : '/api/drone_imagery/drone_run_bands?select_checkbox_name=upload_drone_imagery_drone_run_band_select&drone_run_project_id='+drone_run_project_id
# });
sub get_drone_run_band_projects : Path('/api/drone_imagery/drone_run_bands') : ActionClass('REST') { }

sub get_drone_run_band_projects_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $checkbox_select_name = $c->req->param('select_checkbox_name');
    my $field_trial_id = $c->req->param('field_trial_id');
    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my $exclude_drone_run_band_project_id = $c->req->param('exclude_drone_run_band_project_id') || 0;
    my $select_all = $c->req->param('select_all') || 0;
    my $disable = $c->req->param('disable') || 0;

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
        if ($drone_run_band_project_id != $exclude_drone_run_band_project_id) {
            if ($checkbox_select_name){
                my $checked = $select_all ? 'checked' : '';
                my $disabled = $disable ? 'disabled' : '';
                push @res, "<input type='checkbox' name='$checkbox_select_name' value='$drone_run_band_project_id' $checked $disabled>";
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
    }

    $c->stash->{rest} = { data => \@result };
}

sub standard_process_apply : Path('/api/drone_imagery/standard_process_apply') : ActionClass('REST') { }

sub standard_process_apply_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema');
    my $apply_drone_run_band_project_ids = decode_json $c->req->param('apply_drone_run_band_project_ids');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $drone_run_project_id_input = $c->req->param('drone_run_project_id');
    my $vegetative_indices = decode_json $c->req->param('vegetative_indices');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $process_indicator_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_standard_process_in_progress', 'project_property')->cvterm_id();
    my $processed_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_standard_process_completed', 'project_property')->cvterm_id();
    my $drone_run_process_in_progress = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$process_indicator_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>1
    },
    {
        key=>'projectprop_c1'
    });

    $drone_run_process_in_progress = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$processed_cvterm_id,
        project_id=>$drone_run_project_id_input,
        rank=>0,
        value=>1
    },
    {
        key=>'projectprop_c1'
    });

    my %vegetative_indices_hash;
    foreach (@$vegetative_indices) {
        $vegetative_indices_hash{$_}++;
    }

    my $rotate_angle_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_rotate_angle', 'project_property')->cvterm_id();
    my $cropping_polygon_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_cropped_polygon', 'project_property')->cvterm_id();
    my $plot_polygon_template_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_plot_polygons', 'project_property')->cvterm_id();
    my $drone_run_drone_run_band_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();

    my $q = "SELECT rotate.value, plot_polygons.value, cropping.value, drone_run.project_id, drone_run.name
        FROM project AS drone_run_band
        JOIN project_relationship ON(project_relationship.subject_project_id = drone_run_band.project_id AND project_relationship.type_id = $drone_run_drone_run_band_type_id)
        JOIN project AS drone_run ON(project_relationship.object_project_id = drone_run.project_id)
        JOIN projectprop AS rotate ON(drone_run_band.project_id = rotate.project_id AND rotate.type_id=$rotate_angle_type_id)
        JOIN projectprop AS plot_polygons ON(drone_run_band.project_id = plot_polygons.project_id AND plot_polygons.type_id=$plot_polygon_template_type_id)
        JOIN projectprop AS cropping ON(drone_run_band.project_id = cropping.project_id AND cropping.type_id=$cropping_polygon_type_id)
        WHERE drone_run_band.project_id = $drone_run_band_project_id;";

    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute();
    my ($rotate_value, $plot_polygons_value, $cropping_value, $drone_run_project_id, $drone_run_project_name) = $h->fetchrow_array();
    # print STDERR Dumper $rotate_value;
    # print STDERR Dumper $plot_polygons_value;
    # print STDERR Dumper $cropping_value;

    my %selected_drone_run_band_types;
    my $project_image_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $drone_run_band_type_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    $q = "SELECT project_md_image.image_id, drone_run_band_type.value, drone_run_band.project_id
        FROM project AS drone_run_band
        JOIN projectprop AS drone_run_band_type ON(drone_run_band_type.project_id = drone_run_band.project_id AND drone_run_band_type.type_id = $drone_run_band_type_type_id)
        JOIN phenome.project_md_image AS project_md_image ON(project_md_image.project_id = drone_run_band.project_id)
        WHERE project_md_image.type_id = $project_image_type_id AND drone_run_band.project_id = ?;";

    $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute($drone_run_band_project_id);
    my ($image_id, $drone_run_band_type, $drone_run_band_project_id_q) = $h->fetchrow_array();
    $selected_drone_run_band_types{$drone_run_band_type} = $drone_run_band_project_id_q;

    foreach my $apply_drone_run_band_project_id (@$apply_drone_run_band_project_ids) {
        my $h = $bcs_schema->storage->dbh()->prepare($q);
        $h->execute($apply_drone_run_band_project_id);
        my ($image_id, $drone_run_band_type, $drone_run_band_project_id) = $h->fetchrow_array();
        $selected_drone_run_band_types{$drone_run_band_type} = $drone_run_band_project_id;

        my $dir = $c->tempfiles_subdir('/drone_imagery_rotate');
        my $archive_rotate_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_rotate/imageXXXX');
        $archive_rotate_temp_image .= '.png';
        print STDERR $archive_rotate_temp_image."\n";

        my $rotate_return = _perform_image_rotate($c, $bcs_schema, $metadata_schema, $drone_run_band_project_id, $image_id, $rotate_value, 0, $user_id, $user_name, $user_role, $archive_rotate_temp_image);
        my $rotated_image_id = $rotate_return->{rotated_image_id};

        $dir = $c->tempfiles_subdir('/drone_imagery_cropped_image');
        my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_cropped_image/imageXXXX');
        $archive_temp_image .= '.png';
        print STDERR $archive_temp_image."\n";

        my $cropping_return = _perform_image_cropping($c, $bcs_schema, $drone_run_band_project_id, $rotated_image_id, $cropping_value, $user_id, $user_name, $user_role, $archive_temp_image);
        my $cropped_image_id = $cropping_return->{cropped_image_id};

        $dir = $c->tempfiles_subdir('/drone_imagery_denoise');
        my $archive_denoise_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_denoise/imageXXXX');
        $archive_denoise_temp_image .= '.png';
        print STDERR $archive_denoise_temp_image."\n";

        my $denoise_return = _perform_image_denoise($c, $bcs_schema, $metadata_schema, $cropped_image_id, $drone_run_band_project_id, $user_id, $user_name, $user_role, $archive_denoise_temp_image);
        my $denoised_image_id = $denoise_return->{denoised_image_id};

        $dir = $c->tempfiles_subdir('/drone_imagery_remove_background');
        my $archive_remove_background_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_remove_background/imageXXXX');
        $archive_remove_background_temp_image .= '.png';
        print STDERR $archive_remove_background_temp_image."\n";

        my $background_removed_threshold_return = _perform_image_background_remove_threshold_percentage($c, $bcs_schema, $denoised_image_id, $drone_run_band_project_id, 'threshold_background_removed_stitched_drone_imagery', '25', '25', $user_id, $user_name, $user_role, $archive_remove_background_temp_image);
        my $background_removed_threshold_image_id = $background_removed_threshold_return->{removed_background_image_id};

        my $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $background_removed_threshold_image_id, $drone_run_band_project_id, $plot_polygons_value, undef, $user_id, $user_name, $user_role, 0);
    }

    print STDERR Dumper \%selected_drone_run_band_types;
    print STDERR Dumper \%vegetative_indices_hash;

    if (exists($vegetative_indices_hash{'TGI'}) || exists($vegetative_indices_hash{'VARI'})) {
        if(exists($selected_drone_run_band_types{'Blue (450-520nm)'}) && exists($selected_drone_run_band_types{'Green (515-600nm)'}) && exists($selected_drone_run_band_types{'Red (600-690nm)'}) ) {
            my $merged_return = _perform_image_merge($c, $bcs_schema, $metadata_schema, $drone_run_project_id, $drone_run_project_name, $selected_drone_run_band_types{'Blue (450-520nm)'}, $selected_drone_run_band_types{'Green (515-600nm)'}, $selected_drone_run_band_types{'Red (600-690nm)'}, 'BGR', $user_id, $user_name, $user_role);
            my $merged_image_id = $merged_return->{merged_image_id};
            my $merged_drone_run_band_project_id = $merged_return->{merged_drone_run_band_project_id};

            my $dir = $c->tempfiles_subdir('/drone_imagery_rotate');
            my $archive_rotate_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_rotate/imageXXXX');
            $archive_rotate_temp_image .= '.png';
            print STDERR $archive_rotate_temp_image."\n";

            my $rotate_return = _perform_image_rotate($c, $bcs_schema, $metadata_schema, $merged_drone_run_band_project_id, $merged_image_id, $rotate_value, 0, $user_id, $user_name, $user_role, $archive_rotate_temp_image);
            my $rotated_image_id = $rotate_return->{rotated_image_id};

            $dir = $c->tempfiles_subdir('/drone_imagery_cropped_image');
            my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_cropped_image/imageXXXX');
            $archive_temp_image .= '.png';
            print STDERR $archive_temp_image."\n";

            my $cropping_return = _perform_image_cropping($c, $bcs_schema, $merged_drone_run_band_project_id, $rotated_image_id, $cropping_value, $user_id, $user_name, $user_role, $archive_temp_image);
            my $cropped_image_id = $cropping_return->{cropped_image_id};

            $dir = $c->tempfiles_subdir('/drone_imagery_denoise');
            my $archive_denoise_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_denoise/imageXXXX');
            $archive_denoise_temp_image .= '.png';
            print STDERR $archive_denoise_temp_image."\n";

            my $denoise_return = _perform_image_denoise($c, $bcs_schema, $metadata_schema, $cropped_image_id, $merged_drone_run_band_project_id, $user_id, $user_name, $user_role, $archive_denoise_temp_image);
            my $denoised_image_id = $denoise_return->{denoised_image_id};

            # $dir = $c->tempfiles_subdir('/drone_imagery_remove_background');
            # my $archive_remove_background_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_remove_background/imageXXXX');
            # $archive_remove_background_temp_image .= '.png';
            # print STDERR $archive_remove_background_temp_image."\n";

            # my $background_removed_threshold_return = _perform_image_background_remove_threshold_percentage($c, $bcs_schema, $denoised_image_id, $merged_drone_run_band_project_id, 'threshold_background_removed_stitched_drone_imagery', '25', '25', $user_id, $user_name, $user_role, $archive_remove_background_temp_image);
            # my $background_removed_threshold_image_id = $background_removed_threshold_return->{removed_background_image_id};
            #
            # my $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $background_removed_threshold_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, undef, $user_id, $user_name, $user_role, 0);

            if (exists($vegetative_indices_hash{'TGI'})) {
                my $index_return = _perform_vegetative_index_calculation($c, $bcs_schema, $metadata_schema, $denoised_image_id, $merged_drone_run_band_project_id, 'TGI', 0, 'BGR', $user_id, $user_name, $user_role);
                my $index_image_id = $index_return->{index_image_id};

                my $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $index_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, 'observation_unit_polygon_tgi_imagery', $user_id, $user_name, $user_role, 0);

                $dir = $c->tempfiles_subdir('/drone_imagery_remove_background');
                my $archive_remove_background_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_remove_background/imageXXXX');
                $archive_remove_background_temp_image .= '.png';
                print STDERR $archive_remove_background_temp_image."\n";

                my $background_removed_threshold_return = _perform_image_background_remove_threshold_percentage($c, $bcs_schema, $index_image_id, $merged_drone_run_band_project_id, 'threshold_background_removed_tgi_stitched_drone_imagery', '25', '25', $user_id, $user_name, $user_role, $archive_remove_background_temp_image);
                my $background_removed_threshold_image_id = $background_removed_threshold_return->{removed_background_image_id};

                $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $background_removed_threshold_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, 'observation_unit_polygon_background_removed_tgi_imagery', $user_id, $user_name, $user_role, 0);

                my $threshold_masked_return = _perform_image_background_remove_mask($c, $bcs_schema, $denoised_image_id, $background_removed_threshold_image_id, $merged_drone_run_band_project_id, 'denoised_background_removed_thresholded_tgi_mask_original', $user_id, $user_name, $user_role);
                my $threshold_masked_image_id = $threshold_masked_return->{masked_image_id};

                $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, 'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery', $user_id, $user_name, $user_role, 0);

                my $masked_return = _perform_image_background_remove_mask($c, $bcs_schema, $denoised_image_id, $index_image_id, $merged_drone_run_band_project_id, 'denoised_background_removed_tgi_mask_original', $user_id, $user_name, $user_role);
                my $masked_image_id = $masked_return->{masked_image_id};

                $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, 'observation_unit_polygon_original_background_removed_tgi_mask_imagery', $user_id, $user_name, $user_role, 0);
            }
            if (exists($vegetative_indices_hash{'VARI'})) {
                my $index_return = _perform_vegetative_index_calculation($c, $bcs_schema, $metadata_schema, $denoised_image_id, $merged_drone_run_band_project_id, 'VARI', 0, 'BGR', $user_id, $user_name, $user_role);
                my $index_image_id = $index_return->{index_image_id};

                my $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $index_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, 'observation_unit_polygon_vari_imagery', $user_id, $user_name, $user_role, 0);

                $dir = $c->tempfiles_subdir('/drone_imagery_remove_background');
                my $archive_remove_background_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_remove_background/imageXXXX');
                $archive_remove_background_temp_image .= '.png';
                print STDERR $archive_remove_background_temp_image."\n";

                my $background_removed_threshold_return = _perform_image_background_remove_threshold_percentage($c, $bcs_schema, $index_image_id, $merged_drone_run_band_project_id, 'threshold_background_removed_vari_stitched_drone_imagery', '25', '25', $user_id, $user_name, $user_role, $archive_remove_background_temp_image);
                my $background_removed_threshold_image_id = $background_removed_threshold_return->{removed_background_image_id};

                $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $background_removed_threshold_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, 'observation_unit_polygon_background_removed_vari_imagery', $user_id, $user_name, $user_role, 0);

                my $threshold_masked_return = _perform_image_background_remove_mask($c, $bcs_schema, $denoised_image_id, $background_removed_threshold_image_id, $merged_drone_run_band_project_id, 'denoised_background_removed_thresholded_vari_mask_original', $user_id, $user_name, $user_role);
                my $threshold_masked_image_id = $threshold_masked_return->{masked_image_id};

                $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, 'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery', $user_id, $user_name, $user_role, 0);

                my $masked_return = _perform_image_background_remove_mask($c, $bcs_schema, $denoised_image_id, $index_image_id, $merged_drone_run_band_project_id, 'denoised_background_removed_vari_mask_original', $user_id, $user_name, $user_role);
                my $masked_image_id = $masked_return->{masked_image_id};

                $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, 'observation_unit_polygon_original_background_removed_vari_mask_imagery', $user_id, $user_name, $user_role, 0);
            }
        }
    }
    if (exists($vegetative_indices_hash{'NDVI'})) {
        if(exists($selected_drone_run_band_types{'NIR (750-900nm)'}) && exists($selected_drone_run_band_types{'Red (600-690nm)'}) ) {
            my $merged_return = _perform_image_merge($c, $bcs_schema, $metadata_schema, $drone_run_project_id, $drone_run_project_name, $selected_drone_run_band_types{'NIR (750-900nm)'}, $selected_drone_run_band_types{'Red (600-690nm)'}, $selected_drone_run_band_types{'NIR (750-900nm)'}, 'NRN', $user_id, $user_name, $user_role);
            my $merged_image_id = $merged_return->{merged_image_id};
            my $merged_drone_run_band_project_id = $merged_return->{merged_drone_run_band_project_id};

            my $dir = $c->tempfiles_subdir('/drone_imagery_rotate');
            my $archive_rotate_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_rotate/imageXXXX');
            $archive_rotate_temp_image .= '.png';
            print STDERR $archive_rotate_temp_image."\n";

            my $rotate_return = _perform_image_rotate($c, $bcs_schema, $metadata_schema, $merged_drone_run_band_project_id, $merged_image_id, $rotate_value, 0, $user_id, $user_name, $user_role, $archive_rotate_temp_image);
            my $rotated_image_id = $rotate_return->{rotated_image_id};

            $dir = $c->tempfiles_subdir('/drone_imagery_cropped_image');
            my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_cropped_image/imageXXXX');
            $archive_temp_image .= '.png';
            print STDERR $archive_temp_image."\n";

            my $cropping_return = _perform_image_cropping($c, $bcs_schema, $merged_drone_run_band_project_id, $rotated_image_id, $cropping_value, $user_id, $user_name, $user_role, $archive_temp_image);
            my $cropped_image_id = $cropping_return->{cropped_image_id};

            $dir = $c->tempfiles_subdir('/drone_imagery_denoise');
            my $archive_denoise_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_denoise/imageXXXX');
            $archive_denoise_temp_image .= '.png';
            print STDERR $archive_denoise_temp_image."\n";

            my $denoise_return = _perform_image_denoise($c, $bcs_schema, $metadata_schema, $cropped_image_id, $merged_drone_run_band_project_id, $user_id, $user_name, $user_role, $archive_denoise_temp_image);
            my $denoised_image_id = $denoise_return->{denoised_image_id};

            my $index_return = _perform_vegetative_index_calculation($c, $bcs_schema, $metadata_schema, $denoised_image_id, $merged_drone_run_band_project_id, 'NDVI', 0, 'NRN', $user_id, $user_name, $user_role);
            my $index_image_id = $index_return->{index_image_id};

            my $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $index_image_id, $merged_drone_run_band_project_id,   $plot_polygons_value, 'observation_unit_polygon_ndvi_imagery', $user_id, $user_name, $user_role, 0);

            $dir = $c->tempfiles_subdir('/drone_imagery_remove_background');
            my $archive_remove_background_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_remove_background/imageXXXX');
            $archive_remove_background_temp_image .= '.png';
            print STDERR $archive_remove_background_temp_image."\n";

            my $background_removed_threshold_return = _perform_image_background_remove_threshold_percentage($c, $bcs_schema, $index_image_id, $merged_drone_run_band_project_id, 'threshold_background_removed_ndvi_stitched_drone_imagery', '25', '25', $user_id, $user_name, $user_role, $archive_remove_background_temp_image);
            my $background_removed_threshold_image_id = $background_removed_threshold_return->{removed_background_image_id};

            $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $background_removed_threshold_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, 'observation_unit_polygon_background_removed_ndvi_imagery', $user_id, $user_name, $user_role, 0);

            my $threshold_masked_return = _perform_image_background_remove_mask($c, $bcs_schema, $denoised_image_id, $background_removed_threshold_image_id, $merged_drone_run_band_project_id, 'denoised_background_removed_thresholded_ndvi_mask_original', $user_id, $user_name, $user_role);
            my $threshold_masked_image_id = $threshold_masked_return->{masked_image_id};

            $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $threshold_masked_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, 'observation_unit_polygon_original_background_removed_thresholded_ndvi_mask_imagery', $user_id, $user_name, $user_role, 0);

            my $masked_return = _perform_image_background_remove_mask($c, $bcs_schema, $denoised_image_id, $index_image_id, $merged_drone_run_band_project_id, 'denoised_background_removed_ndvi_mask_original', $user_id, $user_name, $user_role);
            my $masked_image_id = $masked_return->{masked_image_id};

            $plot_polygon_return = _perform_plot_polygon_assign($c, $bcs_schema, $metadata_schema, $masked_image_id, $merged_drone_run_band_project_id, $plot_polygons_value, 'observation_unit_polygon_original_background_removed_ndvi_mask_imagery', $user_id, $user_name, $user_role, 0);
        }
    }

    $drone_run_process_in_progress = $bcs_schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$process_indicator_cvterm_id,
        project_id=>$drone_run_project_id,
        rank=>0,
        value=>0
    },
    {
        key=>'projectprop_c1'
    });

    my @result;
    $c->stash->{rest} = { data => \@result, success => 1 };
}

sub get_project_md_image : Path('/api/drone_imagery/get_project_md_image') : ActionClass('REST') { }

sub get_project_md_image_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $project_image_type_name = $c->req->param('project_image_type_name');

    my $project_image_type_id = SGN::Model::Cvterm->get_cvterm_row($bcs_schema, $project_image_type_name, 'project_md_image')->cvterm_id();

    my $q = "SELECT project_md_image.image_id
        FROM project AS drone_run_band
        JOIN phenome.project_md_image AS project_md_image USING(project_id)
        WHERE project_md_image.type_id = $project_image_type_id AND project_id = $drone_run_band_project_id
        ORDER BY project_id;";

    my $h = $bcs_schema->storage->dbh()->prepare($q);
    $h->execute();
    my @result;
    while (my ($image_id) = $h->fetchrow_array()) {
        push @result, {
            image_id => $image_id
        };
    }

    $c->stash->{rest} = { data => \@result };
}

sub drone_imagery_get_image : Path('/api/drone_imagery/get_image') : ActionClass('REST') { }

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

sub drone_imagery_remove_image : Path('/api/drone_imagery/remove_image') : ActionClass('REST') { }

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

sub drone_imagery_crop_image : Path('/api/drone_imagery/crop_image') : ActionClass('REST') { }

sub drone_imagery_crop_image_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
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

    my $dir = $c->tempfiles_subdir('/drone_imagery_cropped_image');
    my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_cropped_image/imageXXXX');
    $archive_temp_image .= '.png';
    print STDERR $archive_temp_image."\n";

    my $return = _perform_image_cropping($c, $schema, $drone_run_band_project_id, $image_id, $polygons, $user_id, $user_name, $user_role, $archive_temp_image);

    $c->stash->{rest} = $return;
}

sub _perform_image_cropping {
    my $c = shift;
    my $schema = shift;
    my $drone_run_band_project_id = shift;
    my $image_id = shift;
    my $polygons = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    my $archive_temp_image = shift;

    my $main_production_site = $c->config->{main_production_site_url};

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');
    print STDERR Dumper $image_url;
    print STDERR Dumper $image_fullpath;

    my $cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/CropToPolygon.py --inputfile_path '$image_fullpath' --outputfile_path '$archive_temp_image' --polygon_json '$polygons'";
    my $status = system($cmd);

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);
    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cropped_stitched_drone_imagery', 'project_md_image')->cvterm_id();

    my $previous_cropped_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$linking_table_type_id,
        drone_run_band_project_id_list=>[$drone_run_band_project_id]
    });
    my ($previous_result, $previous_total_count) = $previous_cropped_images_search->search();
    print STDERR Dumper $previous_total_count;
    foreach (@$previous_result){
        my $previous_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
        $previous_image->delete(); #Sets to obsolete
    }

    my $ret = $image->process_image($archive_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
    my $cropped_image_fullpath = $image->get_filename('original_converted', 'full');
    my $cropped_image_url = $image->get_image_url('original');
    my $cropped_image_id = $image->get_image_id();

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

    return {
        cropped_image_id => $cropped_image_id, image_url => $image_url, image_fullpath => $image_fullpath, cropped_image_url => $cropped_image_url, cropped_image_fullpath => $cropped_image_fullpath
    };
}

sub drone_imagery_calculate_fourier_transform : Path('/api/drone_imagery/calculate_fourier_transform') : ActionClass('REST') { }

sub drone_imagery_calculate_fourier_transform_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $image_id = $c->req->param('image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $drone_run_band_project_type = $c->req->param('drone_run_band_project_type');
    my $selected_channel = $c->req->param('selected_channel');
    my $image_type = $c->req->param('image_type');
    my $high_pass_filter = $c->req->param('high_pass_filter');

    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $return = _perform_fourier_transform_calculation($c, $schema, $metadata_schema, $image_id, $drone_run_band_project_id, $drone_run_band_project_type, $selected_channel, $image_type, $high_pass_filter, $user_id, $user_name, $user_role);

    $c->stash->{rest} = $return;
}

sub _perform_fourier_transform_calculation {
    my $c = shift;
    my $schema = shift;
    my $metadata_schema = shift;
    my $image_id = shift;
    my $drone_run_band_project_id = shift;
    my $drone_run_band_project_type = shift;
    my $selected_channel = shift;
    my $image_type = shift;
    my $high_pass_filter = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    print STDERR Dumper $high_pass_filter;
    print STDERR Dumper $drone_run_band_project_type;
    print STDERR Dumper $image_type;
    print STDERR Dumper $selected_channel;
    my $linking_table_type_id;
    if ($high_pass_filter eq '30') {
        if ($drone_run_band_project_type eq 'Merged 3 Bands NRN') {
            if ($image_type eq 'denoised_stitched_image') {
                if ($selected_channel eq '0') {
                    $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_nrn_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id();
                }
            }
        }
        if ($drone_run_band_project_type eq 'Blue (450-520nm)') {
            if ($image_type eq 'denoised_stitched_image') {
                if ($selected_channel eq '0') {
                    $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id();
                }
            }
        }
        if ($drone_run_band_project_type eq 'Green (515-600nm)') {
            if ($image_type eq 'denoised_stitched_image') {
                if ($selected_channel eq '0') {
                    $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_green_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id();
                }
            }
        }
        if ($drone_run_band_project_type eq 'Red (600-690nm)') {
            if ($image_type eq 'denoised_stitched_image') {
                if ($selected_channel eq '0') {
                    $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_red_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id();
                }
            }
        }
        if ($drone_run_band_project_type eq 'Red Edge (690-750nm)') {
            if ($image_type eq 'denoised_stitched_image') {
                if ($selected_channel eq '0') {
                    $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id();
                }
            }
        }
        if ($drone_run_band_project_type eq 'NIR (750-900nm)') {
            if ($image_type eq 'denoised_stitched_image') {
                if ($selected_channel eq '0') {
                    $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1', 'project_md_image')->cvterm_id();
                }
            }
        }
    }
    if (!$linking_table_type_id) {
        die "Could not get fourier transform image type id\n";
    }

    my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
    my $image_url = $image->get_image_url("original");
    my $image_fullpath = $image->get_filename('original_converted', 'full');
    print STDERR Dumper $image_url;
    print STDERR Dumper $image_fullpath;

    my $dir = $c->tempfiles_subdir('/drone_imagery_fourier_transform_hpf_image');
    my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_fourier_transform_hpf_image/imageXXXX');
    $archive_temp_image .= '.png';
    print STDERR $archive_temp_image."\n";

    my $cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/FourierTransform.py --image_path '$image_fullpath' --outfile_path '$archive_temp_image' --image_band_index $selected_channel --frequency_threshold $high_pass_filter";
    my $status = system($cmd);

    my $index_image_fullpath;
    my $index_image_url;
    my $index_image_id;
    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    my $md5checksum = $image->calculate_md5sum($archive_temp_image);
    my $md_image = $metadata_schema->resultset("MdImage")->search({md5sum=>$md5checksum, obsolete=>'f'});
    if ($md_image->count() > 0) {
        print STDERR Dumper "Image $archive_temp_image has already been added to the database and will not be added again.";
        $image = SGN::Image->new( $schema->storage->dbh, $md_image->first->image_id, $c );
        $index_image_fullpath = $image->get_filename('original_converted', 'full');
        $index_image_url = $image->get_image_url('original');
        $index_image_id = $image->get_image_id();
    } else {
        $image->set_sp_person_id($user_id);

        my $previous_index_images_search = CXGN::DroneImagery::ImagesSearch->new({
            bcs_schema=>$schema,
            project_image_type_id=>$linking_table_type_id,
            drone_run_band_project_id_list=>[$drone_run_band_project_id]
        });
        my ($previous_result, $previous_total_count) = $previous_index_images_search->search();
        print STDERR Dumper $previous_total_count;
        foreach (@$previous_result){
            my $previous_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
            $previous_image->delete(); #Sets to obsolete
        }

        my $ret = $image->process_image($archive_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
        $index_image_fullpath = $image->get_filename('original_converted', 'full');
        $index_image_url = $image->get_image_url('original');
        $index_image_id = $image->get_image_id();
    }

    return {
        image_url => $image_url, image_fullpath => $image_fullpath, index_image_id => $index_image_id, index_image_url => $index_image_url, index_image_fullpath => $index_image_fullpath
    };
}

sub drone_imagery_calculate_rgb_vegetative_index : Path('/api/drone_imagery/calculate_rgb_vegetative_index') : ActionClass('REST') { }

sub drone_imagery_calculate_rgb_vegetative_index_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $image_id = $c->req->param('image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $vegetative_index = $c->req->param('vegetative_index');
    my $image_type = $c->req->param('image_type');
    my $view_only = $c->req->param('view_only');

    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $return = _perform_vegetative_index_calculation($c, $schema, $metadata_schema, $image_id, $drone_run_band_project_id, $vegetative_index, $view_only, $image_type, $user_id, $user_name, $user_role);

    $c->stash->{rest} = $return;
}

sub _perform_vegetative_index_calculation {
    my $c = shift;
    my $schema = shift;
    my $metadata_schema = shift;
    my $image_id = shift;
    my $drone_run_band_project_id = shift;
    my $vegetative_index = shift;
    my $view_only = shift;
    my $image_type = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;

    my $index_script = '';
    my $linking_table_type_id;
    if ($image_type eq 'BGR') {
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
    }
    elsif ($image_type eq 'NRN') {
        if ($vegetative_index eq 'NDVI') {
            $index_script = 'NDVI';
            if ($view_only == 1){
                $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_ndvi_temporary_drone_imagery', 'project_md_image')->cvterm_id();
            } else {
                $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_ndvi_drone_imagery', 'project_md_image')->cvterm_id();
            }
        }
    }
    elsif ($image_type eq 'NReN') {
        if ($vegetative_index eq 'NDRE') {
            $index_script = 'NDRE';
            if ($view_only == 1){
                $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_ndre_temporary_drone_imagery', 'project_md_image')->cvterm_id();
            } else {
                $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_ndre_drone_imagery', 'project_md_image')->cvterm_id();
            }
        }
    }
    if (!$linking_table_type_id) {
        die "Could not get vegetative index image type id\n";
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

    my $cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/VegetativeIndex/$index_script.py --image_path '$image_fullpath' --outfile_path '$archive_temp_image'";
    my $status = system($cmd);

    my $index_image_fullpath;
    my $index_image_url;
    my $index_image_id;
    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    my $md5checksum = $image->calculate_md5sum($archive_temp_image);
    my $md_image = $metadata_schema->resultset("MdImage")->search({md5sum=>$md5checksum, obsolete=>'f'});
    if ($view_only == 1 && $md_image->count() > 0) {
        print STDERR Dumper "Image $archive_temp_image has already been added to the database and will not be added again.";
        $image = SGN::Image->new( $schema->storage->dbh, $md_image->first->image_id, $c );
        $index_image_fullpath = $image->get_filename('original_converted', 'full');
        $index_image_url = $image->get_image_url('original');
        $index_image_id = $image->get_image_id();
    } else {
        $image->set_sp_person_id($user_id);

        my $previous_index_images_search = CXGN::DroneImagery::ImagesSearch->new({
            bcs_schema=>$schema,
            project_image_type_id=>$linking_table_type_id,
            drone_run_band_project_id_list=>[$drone_run_band_project_id]
        });
        my ($previous_result, $previous_total_count) = $previous_index_images_search->search();
        print STDERR Dumper $previous_total_count;
        foreach (@$previous_result){
            my $previous_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
            $previous_image->delete(); #Sets to obsolete
        }

        my $ret = $image->process_image($archive_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
        $index_image_fullpath = $image->get_filename('original_converted', 'full');
        $index_image_url = $image->get_image_url('original');
        $index_image_id = $image->get_image_id();
    }

    return {
        image_url => $image_url, image_fullpath => $image_fullpath, index_image_id => $index_image_id, index_image_url => $index_image_url, index_image_fullpath => $index_image_fullpath
    };
}

sub drone_imagery_mask_remove_background : Path('/api/drone_imagery/mask_remove_background') : ActionClass('REST') { }

sub drone_imagery_mask_remove_background_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    print STDERR Dumper $c->req->params;
    my $image_id = $c->req->param('image_id');
    my $mask_image_id = $c->req->param('mask_image_id');
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $mask_type = $c->req->param('mask_type');

    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $return = _perform_image_background_remove_mask($c, $schema, $image_id, $mask_image_id, $drone_run_band_project_id, $mask_type, $user_id, $user_name, $user_role);

    $c->stash->{rest} = $return;
}

sub _perform_image_background_remove_mask {
    my $c = shift;
    my $schema = shift;
    my $image_id = shift;
    my $mask_image_id = shift;
    my $drone_run_band_project_id = shift;
    my $mask_type = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;

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

    my $cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/MaskRemoveBackground.py --image_path '$image_fullpath' --mask_image_path '$mask_image_fullpath' --outfile_path '$archive_temp_image'";
    print STDERR Dumper $cmd;
    my $status = system($cmd);

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);

    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $mask_type, 'project_md_image')->cvterm_id();;

    my $previous_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$linking_table_type_id,
        drone_run_band_project_id_list=>[$drone_run_band_project_id]
    });
    my ($previous_result, $previous_total_count) = $previous_images_search->search();
    print STDERR Dumper $previous_total_count;
    foreach (@$previous_result){
        my $previous_image = SGN::Image->new( $schema->storage->dbh, $_->{image_id}, $c );
        $previous_image->delete(); #Sets to obsolete
    }

    my $ret = $image->process_image($archive_temp_image, 'project', $drone_run_band_project_id, $linking_table_type_id);
    my $masked_image_fullpath = $image->get_filename('original_converted', 'full');
    my $masked_image_url = $image->get_image_url('original');
    my $masked_image_id = $image->get_image_id();

    return {
        image_url => $image_url, image_fullpath => $image_fullpath, masked_image_id => $masked_image_id, masked_image_url => $masked_image_url, masked_image_fullpath => $masked_image_fullpath
    };
}

sub drone_imagery_get_plot_polygon_images : Path('/api/drone_imagery/get_plot_polygon_images') : ActionClass('REST') { }

sub drone_imagery_get_plot_polygon_images_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $plot_polygons_type = $c->req->param('plot_polygons_type');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $main_production_site = $c->config->{main_production_site_url};

    my $plot_polygons_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, $plot_polygons_type, 'project_md_image')->cvterm_id();
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

sub drone_imagery_merge_bands : Path('/api/drone_imagery/merge_bands') : ActionClass('REST') { }

sub drone_imagery_merge_bands_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    print STDERR Dumper $c->req->params();

    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my $drone_run_project_name = $c->req->param('drone_run_project_name');
    my $band_1_drone_run_band_project_id = $c->req->param('band_1_drone_run_band_project_id');
    my $band_2_drone_run_band_project_id = $c->req->param('band_2_drone_run_band_project_id');
    my $band_3_drone_run_band_project_id = $c->req->param('band_3_drone_run_band_project_id');
    my $merged_image_type = $c->req->param('merged_image_type');

    my $return = _perform_image_merge($c, $schema, $metadata_schema, $drone_run_project_id, $drone_run_project_name, $band_1_drone_run_band_project_id, $band_2_drone_run_band_project_id, $band_3_drone_run_band_project_id, $merged_image_type, $user_id, $user_name, $user_role);

    $c->stash->{rest} = $return;
}

sub _perform_image_merge {
    my $c = shift;
    my $schema = shift;
    my $metadata_schema = shift;
    my $drone_run_project_id = shift;
    my $drone_run_project_name = shift;
    my $band_1_drone_run_band_project_id = shift;
    my $band_2_drone_run_band_project_id = shift;
    my $band_3_drone_run_band_project_id = shift;
    my $merged_image_type = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;

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
    #print STDERR Dumper \%drone_run_bands_images;

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

    my $cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/MergeChannels.py --image_path_band_1 '".$image_filesnames[0]."' --image_path_band_2 '".$image_filesnames[1]."' --image_path_band_3 '".$image_filesnames[2]."' --outfile_path '$archive_temp_image'";
    print STDERR Dumper $cmd;
    my $status = system($cmd);

    my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);

    my $drone_run_band_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property')->cvterm_id();
    my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();

    my $band_1_drone_run_band_project_type = $schema->resultset("Project::Projectprop")->search({project_id => $band_1_drone_run_band_project_id, type_id => $drone_run_band_type_cvterm_id})->first->value;
    my $band_2_drone_run_band_project_type = $schema->resultset("Project::Projectprop")->search({project_id => $band_2_drone_run_band_project_id, type_id => $drone_run_band_type_cvterm_id})->first->value;
    my $band_3_drone_run_band_project_type = $schema->resultset("Project::Projectprop")->search({project_id => $band_3_drone_run_band_project_id, type_id => $drone_run_band_type_cvterm_id})->first->value;

    my $merged_drone_run_band_id;
    my $project_rs_check = $schema->resultset("Project::Project")->find({
        name => "$drone_run_project_name Merged:$band_1_drone_run_band_project_type (project_id:$band_1_drone_run_band_project_id),$band_2_drone_run_band_project_type (project_id:$band_2_drone_run_band_project_id),$band_3_drone_run_band_project_type (project_id:$band_3_drone_run_band_project_id)"
    });
    if ($project_rs_check) {
        $merged_drone_run_band_id = $project_rs_check->project_id;
    } else {
        my $project_rs = $schema->resultset("Project::Project")->create({
            name => "$drone_run_project_name Merged:$band_1_drone_run_band_project_type (project_id:$band_1_drone_run_band_project_id),$band_2_drone_run_band_project_type (project_id:$band_2_drone_run_band_project_id),$band_3_drone_run_band_project_type (project_id:$band_3_drone_run_band_project_id)",
            description => "Merged $band_1_drone_run_band_project_type (project_id:$band_1_drone_run_band_project_id),$band_2_drone_run_band_project_type (project_id:$band_2_drone_run_band_project_id),$band_3_drone_run_band_project_type (project_id:$band_3_drone_run_band_project_id)",
            projectprops => [{type_id => $drone_run_band_type_cvterm_id, value => 'Merged 3 Bands '.$merged_image_type}, {type_id => $design_cvterm_id, value => 'drone_run_band'}],
            project_relationship_subject_projects => [{type_id => $project_relationship_type_id, object_project_id => $drone_run_project_id}]
        });
        $merged_drone_run_band_id = $project_rs->project_id();
    }

    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $ret = $image->process_image($archive_temp_image, 'project', $merged_drone_run_band_id, $linking_table_type_id);
    my $merged_image_fullpath = $image->get_filename('original_converted', 'full');
    my $merged_image_url = $image->get_image_url('original');
    my $merged_image_id = $image->get_image_id();

    return {
        merged_drone_run_band_project_id => $merged_drone_run_band_id, merged_image_url => $merged_image_url, merged_image_fullpath => $merged_image_fullpath, merged_image_id => $merged_image_id
    };
}

sub drone_imagery_standard_process_apply_phenotypes : Path('/api/drone_imagery/standard_process_apply_phenotypes') : ActionClass('REST') { }

sub drone_imagery_standard_process_apply_phenotypes_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my $time_cvterm_id = $c->req->param('time_cvterm_id');
    my $phenotype_types = decode_json $c->req->param('phenotype_types');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $return = _perform_phenotype_automated($c, $schema, $metadata_schema, $phenome_schema, $drone_run_project_id, $time_cvterm_id, $phenotype_types, $user_id, $user_name, $user_role);

    $c->stash->{rest} = $return;
}

sub _perform_phenotype_automated {
    my $c = shift;
    my $schema = shift;
    my $metadata_schema = shift;
    my $phenome_schema = shift;
    my $drone_run_project_id = shift;
    my $time_cvterm_id = shift;
    my $phenotype_types = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;

    my @allowed_composed_cvs = split ',', $c->config->{composable_cvs};
    my $composable_cvterm_delimiter = $c->config->{composable_cvterm_delimiter};
    my $composable_cvterm_format = $c->config->{composable_cvterm_format};

    my $drone_run_phenotype_calc_progress_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_standard_process_phenotype_calculation_in_progress', 'project_property')->cvterm_id();
    my $drone_run_phenotype_calc_progress = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$drone_run_phenotype_calc_progress_type_id,
        project_id=>$drone_run_project_id,
        rank=>0,
        value=>1
    },
    {
        key=>'projectprop_c1'
    });

    my $in_progress_indicator = 1;
    while ($in_progress_indicator == 1) {
        sleep(10);
        print STDERR "Waiting for drone standard image process to finish before calculating phenotypes\n";
        my $process_indicator_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_standard_process_in_progress', 'project_property')->cvterm_id();
        my $drone_run_band_remove_background_threshold_rs = $schema->resultset('Project::Projectprop')->search({
            type_id=>$process_indicator_cvterm_id,
            project_id=>$drone_run_project_id,
        });
        $in_progress_indicator = $drone_run_band_remove_background_threshold_rs->first->value();
    }

    my @possible_plot_polygon_types = (
        'observation_unit_polygon_bw_background_removed_threshold_imagery',
        'observation_unit_polygon_rgb_background_removed_threshold_imagery',
        'observation_unit_polygon_blue_background_removed_threshold_imagery',
        'observation_unit_polygon_green_background_removed_threshold_imagery',
        'observation_unit_polygon_red_background_removed_threshold_imagery',
        'observation_unit_polygon_red_edge_background_removed_threshold_imagery',
        'observation_unit_polygon_nir_background_removed_threshold_imagery',
        'observation_unit_polygon_mir_background_removed_threshold_imagery',
        'observation_unit_polygon_fir_background_removed_threshold_imagery',
        'observation_unit_polygon_tir_background_removed_threshold_imagery',
        'observation_unit_polygon_tgi_imagery',
        'observation_unit_polygon_vari_imagery',
        'observation_unit_polygon_ndvi_imagery',
        'observation_unit_polygon_background_removed_tgi_imagery',
        'observation_unit_polygon_background_removed_vari_imagery',
        'observation_unit_polygon_background_removed_ndvi_imagery',
        'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery',
        'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery',
        'observation_unit_polygon_original_background_removed_thresholded_ndvi_mask_imagery',
        'observation_unit_polygon_original_background_removed_tgi_mask_imagery',
        'observation_unit_polygon_original_background_removed_vari_mask_imagery',
        'observation_unit_polygon_original_background_removed_ndvi_mask_imagery'
    );

    my $drone_run_band_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
    my $drone_run_band_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $q = "SELECT drone_run_band.project_id, drone_run_band.name, drone_run_band_project_type.value
        FROM project AS drone_run_band
        JOIN projectprop AS drone_run_band_project_type ON (drone_run_band_project_type.project_id=drone_run_band.project_id AND drone_run_band_project_type.type_id=$drone_run_band_type_cvterm_id)
        JOIN project_relationship AS drone_run_band_rel ON(drone_run_band.project_id=drone_run_band_rel.subject_project_id AND drone_run_band_rel.type_id=$drone_run_band_relationship_type_id)
        JOIN project ON (drone_run_band_rel.object_project_id = project.project_id)
        WHERE project.project_id = ?;";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($drone_run_project_id);
    my @result;
    while (my ($drone_run_band_project_id, $drone_run_band_name, $drone_run_band_project_type) = $h->fetchrow_array()) {
        foreach my $phenotype_method (@$phenotype_types) {
            foreach my $plot_polygons_type (@possible_plot_polygon_types) {
                foreach my $channel (0..2) {
                    my $return = _perform_phenotype_calculation($c, $schema, $metadata_schema, $phenome_schema, $drone_run_band_project_id, $drone_run_band_project_type, $phenotype_method, $channel, $time_cvterm_id, $plot_polygons_type, $user_id, $user_name, $user_role, \@allowed_composed_cvs, $composable_cvterm_delimiter, $composable_cvterm_format);
                    if ($return->{error}){
                        print STDERR Dumper $return->{error};
                    }
                }
            }
        }
    }

    $drone_run_phenotype_calc_progress = $schema->resultset('Project::Projectprop')->update_or_create({
        type_id=>$drone_run_phenotype_calc_progress_type_id,
        project_id=>$drone_run_project_id,
        rank=>0,
        value=>0
    },
    {
        key=>'projectprop_c1'
    });

    return {
        success => 1
    };
}

sub drone_imagery_calculate_phenotypes : Path('/api/drone_imagery/calculate_phenotypes') : ActionClass('REST') { }

sub drone_imagery_calculate_phenotypes_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $drone_run_band_project_id = $c->req->param('drone_run_band_project_id');
    my $drone_run_band_project_type = $c->req->param('drone_run_band_project_type');
    my $phenotype_method = $c->req->param('method');
    my $image_band_selected = $c->req->param('image_band');
    my $time_cvterm_id = $c->req->param('time_cvterm_id');
    my $plot_polygons_type = $c->req->param('plot_polygons_type');
    my @allowed_composed_cvs = split ',', $c->config->{composable_cvs};
    my $composable_cvterm_delimiter = $c->config->{composable_cvterm_delimiter};
    my $composable_cvterm_format = $c->config->{composable_cvterm_format};
    #print STDERR Dumper $c->req->params();
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $return = _perform_phenotype_calculation($c, $schema, $metadata_schema, $phenome_schema, $drone_run_band_project_id, $drone_run_band_project_type, $phenotype_method, $image_band_selected, $time_cvterm_id, $plot_polygons_type, $user_id, $user_name, $user_role, \@allowed_composed_cvs, $composable_cvterm_delimiter, $composable_cvterm_format);

    $c->stash->{rest} = $return;
}

sub drone_imagery_generate_phenotypes : Path('/api/drone_imagery/generate_phenotypes') : ActionClass('REST') { }

sub drone_imagery_generate_phenotypes_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my $time_cvterm_id = $c->req->param('time_cvterm_id');
    my $phenotype_methods = $c->req->param('phenotype_types') ? decode_json $c->req->param('phenotype_types') : ['zonal'];
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $return = _perform_phenotype_automated($c, $schema, $metadata_schema, $phenome_schema, $drone_run_project_id, $time_cvterm_id, $phenotype_methods, $user_id, $user_name, $user_role);

    $c->stash->{rest} = $return;
}

sub _perform_phenotype_calculation {
    my $c = shift;
    my $schema = shift;
    my $metadata_schema = shift;
    my $phenome_schema = shift;
    my $drone_run_band_project_id = shift;
    my $drone_run_band_project_type = shift;
    my $phenotype_method = shift;
    my $image_band_selected = shift;
    my $time_cvterm_id = shift;
    my $plot_polygons_type = shift;
    my $user_id = shift;
    my $user_name = shift;
    my $user_role = shift;
    my $allowed_composed_cvs = shift;
    my $composable_cvterm_delimiter = shift;
    my $composable_cvterm_format = shift;

    print STDERR Dumper [$drone_run_band_project_id, $drone_run_band_project_type, $phenotype_method, $plot_polygons_type, $image_band_selected];

    my $main_production_site = $c->config->{main_production_site_url};

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
    my $majority_pixel_count_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Majority Pixel Count|G2F:0000027')->cvterm_id;
    my $pixel_group_count_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Pixel Group Count|G2F:0000028')->cvterm_id;

    my $tgi_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'TGI|ISOL:0000017')->cvterm_id;
    my $ndvi_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'NDVI|ISOL:0000018')->cvterm_id;
    my $vari_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'VARI|ISOL:0000019')->cvterm_id;
    my $merged_3_bands_bgr_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Merged 3 Bands BGR|ISOL:0000061')->cvterm_id;
    my $merged_3_bands_nrn_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Merged 3 Bands NRN|ISOL:0000062')->cvterm_id;
    my $rgb_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'RGB Color Image|ISOL:0000002')->cvterm_id;
    my $bw_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Black and White Image|ISOL:0000003')->cvterm_id;
    my $blue_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Blue (450-520nm)|ISOL:0000004')->cvterm_id;
    my $green_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Green (515-600nm)|ISOL:0000005')->cvterm_id;
    my $red_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Red (600-690nm)|ISOL:0000006')->cvterm_id;
    my $red_edge_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Red Edge (690-750nm)|ISOL:0000060')->cvterm_id;
    my $nir_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'NIR (750-900nm)|ISOL:0000007')->cvterm_id;
    my $mir_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'MIR (1550-1750nm)|ISOL:0000008')->cvterm_id;
    my $fir_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FIR (2080-2350nm)|ISOL:0000009')->cvterm_id;
    my $thermal_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Thermal IR (10400-12500nm)|ISOL:0000010')->cvterm_id;

    my $tgi_from_denoised_original_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'TGI From Denoised Original Image|ISOL:0000022')->cvterm_id;
    my $vari_from_denoised_original_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'VARI From Denoised Original Image|ISOL:0000023')->cvterm_id;
    my $ndvi_from_denoised_original_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'NDVI From Denoised Original Image|ISOL:0000024')->cvterm_id;
    my $threshold_background_removed_tgi_from_denoised_original_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'TGI with Background Removed via Threshold|ISOL:0000046')->cvterm_id;
    my $threshold_background_removed_vari_from_denoised_original_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'VARI with Background Removed via Threshold|ISOL:0000047')->cvterm_id;
    my $threshold_background_removed_ndvi_from_denoised_original_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'NDVI with Background Removed via Threshold|ISOL:0000048')->cvterm_id;

    my $channel_1_denoised_original_background_removed_original_tgi_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 1 in Denoised Original Image with Background Removed via Original TGI Mask|ISOL:0000025')->cvterm_id;
    my $channel_1_denoised_original_background_removed_thresholded_tgi_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 1 in Denoised Original Image with Background Removed via Thresholded TGI Mask|ISOL:0000026')->cvterm_id;
    my $channel_1_denoised_original_background_removed_original_vari_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 1 in Denoised Original Image with Background Removed via Original VARI Mask|ISOL:0000027')->cvterm_id;
    my $channel_1_denoised_original_background_removed_thresholded_vari_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 1 in Denoised Original Image with Background Removed via Thresholded VARI Mask|ISOL:0000028')->cvterm_id;
    my $channel_1_denoised_original_background_removed_original_ndvi_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 1 in Denoised Original Image with Background Removed via Original NDVI Mask|ISOL:0000029')->cvterm_id;
    my $channel_1_denoised_original_background_removed_thresholded_ndvi_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 1 in Denoised Original Image with Background Removed via Thresholded NDVI Mask|ISOL:0000030')->cvterm_id;
    my $channel_1_denoised_original_background_removed_threshold_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 1 in Denoised Original Image with Background Removed via Threshold|ISOL:0000031')->cvterm_id;

    my $channel_2_denoised_original_background_removed_original_tgi_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 2 in Denoised Original Image with Background Removed via Original TGI Mask|ISOL:0000032')->cvterm_id;
    my $channel_2_denoised_original_background_removed_thresholded_tgi_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 2 in Denoised Original Image with Background Removed via Thresholded TGI Mask|ISOL:0000033')->cvterm_id;
    my $channel_2_denoised_original_background_removed_original_vari_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 2 in Denoised Original Image with Background Removed via Original VARI Mask|ISOL:0000034')->cvterm_id;
    my $channel_2_denoised_original_background_removed_thresholded_vari_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 2 in Denoised Original Image with Background Removed via Thresholded VARI Mask|ISOL:0000035')->cvterm_id;
    my $channel_2_denoised_original_background_removed_original_ndvi_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 2 in Denoised Original Image with Background Removed via Original NDVI Mask|ISOL:0000036')->cvterm_id;
    my $channel_2_denoised_original_background_removed_thresholded_ndvi_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 2 in Denoised Original Image with Background Removed via Thresholded NDVI Mask|ISOL:0000037')->cvterm_id;
    my $channel_2_denoised_original_background_removed_threshold_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 2 in Denoised Original Image with Background Removed via Threshold|ISOL:0000038')->cvterm_id;

    my $channel_3_denoised_original_background_removed_original_tgi_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 3 in Denoised Original Image with Background Removed via Original TGI Mask|ISOL:0000039')->cvterm_id;
    my $channel_3_denoised_original_background_removed_thresholded_tgi_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 3 in Denoised Original Image with Background Removed via Thresholded TGI Mask|ISOL:0000040')->cvterm_id;
    my $channel_3_denoised_original_background_removed_original_vari_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 3 in Denoised Original Image with Background Removed via Original VARI Mask|ISOL:0000041')->cvterm_id;
    my $channel_3_denoised_original_background_removed_thresholded_vari_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 3 in Denoised Original Image with Background Removed via Thresholded VARI Mask|ISOL:0000042')->cvterm_id;
    my $channel_3_denoised_original_background_removed_original_ndvi_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 3 in Denoised Original Image with Background Removed via Original NDVI Mask|ISOL:0000043')->cvterm_id;
    my $channel_3_denoised_original_background_removed_thresholded_ndvi_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 3 in Denoised Original Image with Background Removed via Thresholded NDVI Mask|ISOL:0000044')->cvterm_id;
    my $channel_3_denoised_original_background_removed_threshold_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 3 in Denoised Original Image with Background Removed via Threshold|ISOL:0000045')->cvterm_id;

    my $channel_1_denoised_original_bw_background_removed_threshold_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 1 in Denoised Original Black and White Image with Background Removed via Threshold|ISOL:0000049')->cvterm_id;
    my $channel_1_denoised_original_rgb_background_removed_threshold_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 1 in Denoised Original RGB Image with Background Removed via Threshold|ISOL:0000050')->cvterm_id;
    my $channel_2_denoised_original_rgb_background_removed_threshold_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 2 in Denoised Original RGB Image with Background Removed via Threshold|ISOL:0000051')->cvterm_id;
    my $channel_3_denoised_original_rgb_background_removed_threshold_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 3 in Denoised Original RGB Image with Background Removed via Threshold|ISOL:0000052')->cvterm_id;
    my $channel_1_denoised_original_blue_background_removed_threshold_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 1 in Denoised Original Blue Image with Background Removed via Threshold|ISOL:0000053')->cvterm_id;
    my $channel_1_denoised_original_green_background_removed_threshold_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 1 in Denoised Original Green Image with Background Removed via Threshold|ISOL:0000054')->cvterm_id;
    my $channel_1_denoised_original_red_background_removed_threshold_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 1 in Denoised Original Red Image with Background Removed via Threshold|ISOL:0000055')->cvterm_id;
    my $channel_1_denoised_original_red_edge_background_removed_threshold_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 1 in Denoised Original Red Edge Image with Background Removed via Threshold|ISOL:0000063')->cvterm_id;
    my $channel_1_denoised_original_nir_background_removed_threshold_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 1 in Denoised Original NIR Image with Background Removed via Threshold|ISOL:0000056')->cvterm_id;
    my $channel_1_denoised_original_mir_background_removed_threshold_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 1 in Denoised Original MIR Image with Background Removed via Threshold|ISOL:0000057')->cvterm_id;
    my $channel_1_denoised_original_fir_background_removed_threshold_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 1 in Denoised Original FIR Image with Background Removed via Threshold|ISOL:0000058')->cvterm_id;
    my $channel_1_denoised_original_tir_background_removed_threshold_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'Channel 1 in Denoised Original Thermal IR Image with Background Removed via Threshold|ISOL:0000059')->cvterm_id;

    my $ft_hpf30_tgi_from_denoised_original_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 TGI From Denoised Original Image|ISOL:0000064')->cvterm_id;
    my $ft_hpf30_vari_from_denoised_original_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 VARI From Denoised Original Image|ISOL:0000065')->cvterm_id;
    my $ft_hpf30_ndvi_from_denoised_original_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 NDVI From Denoised Original Image|ISOL:0000066')->cvterm_id;

    my $ft_hpf30_channel_1_denoised_original_background_removed_original_tgi_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 1 in Denoised Original Image with Background Removed via Original TGI Mask|ISOL:0000067')->cvterm_id;
    my $ft_hpf30_channel_1_denoised_original_background_removed_thresholded_tgi_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 1 in Denoised Original Image with Background Removed via Thresholded TGI Mask|ISOL:0000068')->cvterm_id;
    my $ft_hpf30_channel_1_denoised_original_background_removed_original_vari_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 1 in Denoised Original Image with Background Removed via Original VARI Mask|ISOL:0000069')->cvterm_id;
    my $ft_hpf30_channel_1_denoised_original_background_removed_thresholded_vari_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 1 in Denoised Original Image with Background Removed via Thresholded VARI Mask|ISOL:0000070')->cvterm_id;
    my $ft_hpf30_channel_1_denoised_original_background_removed_original_ndvi_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 1 in Denoised Original Image with Background Removed via Original NDVI Mask|ISOL:0000071')->cvterm_id;
    my $ft_hpf30_channel_1_denoised_original_background_removed_thresholded_ndvi_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 1 in Denoised Original Image with Background Removed via Thresholded NDVI Mask|ISOL:0000072')->cvterm_id;
    my $ft_hpf30_channel_1_denoised_original_background_removed_threshold_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 1 in Denoised Original Image with Background Removed via Threshold|ISOL:0000073')->cvterm_id;

    my $ft_hpf30_channel_2_denoised_original_background_removed_original_tgi_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 2 in Denoised Original Image with Background Removed via Original TGI Mask|ISOL:0000074')->cvterm_id;
    my $ft_hpf30_channel_2_denoised_original_background_removed_thresholded_tgi_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 2 in Denoised Original Image with Background Removed via Thresholded TGI Mask|ISOL:0000075')->cvterm_id;
    my $ft_hpf30_channel_2_denoised_original_background_removed_original_vari_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 2 in Denoised Original Image with Background Removed via Original VARI Mask|ISOL:0000076')->cvterm_id;
    my $ft_hpf30_channel_2_denoised_original_background_removed_thresholded_vari_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 2 in Denoised Original Image with Background Removed via Thresholded VARI Mask|ISOL:0000077')->cvterm_id;
    my $ft_hpf30_channel_2_denoised_original_background_removed_original_ndvi_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 2 in Denoised Original Image with Background Removed via Original NDVI Mask|ISOL:0000078')->cvterm_id;
    my $ft_hpf30_channel_2_denoised_original_background_removed_thresholded_ndvi_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 2 in Denoised Original Image with Background Removed via Thresholded NDVI Mask|ISOL:0000079')->cvterm_id;
    my $ft_hpf30_channel_2_denoised_original_background_removed_threshold_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 2 in Denoised Original Image with Background Removed via Threshold|ISOL:0000080')->cvterm_id;

    my $ft_hpf30_channel_3_denoised_original_background_removed_original_tgi_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 3 in Denoised Original Image with Background Removed via Original TGI Mask|ISOL:0000081')->cvterm_id;
    my $ft_hpf30_channel_3_denoised_original_background_removed_thresholded_tgi_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 3 in Denoised Original Image with Background Removed via Thresholded TGI Mask|ISOL:0000082')->cvterm_id;
    my $ft_hpf30_channel_3_denoised_original_background_removed_original_vari_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 3 in Denoised Original Image with Background Removed via Original VARI Mask|ISOL:0000083')->cvterm_id;
    my $ft_hpf30_channel_3_denoised_original_background_removed_thresholded_vari_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 3 in Denoised Original Image with Background Removed via Thresholded VARI Mask|ISOL:0000084')->cvterm_id;
    my $ft_hpf30_channel_3_denoised_original_background_removed_original_ndvi_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 3 in Denoised Original Image with Background Removed via Original NDVI Mask|ISOL:0000085')->cvterm_id;
    my $ft_hpf30_channel_3_denoised_original_background_removed_thresholded_ndvi_mask_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 3 in Denoised Original Image with Background Removed via Thresholded NDVI Mask|ISOL:0000086')->cvterm_id;
    my $ft_hpf30_channel_3_denoised_original_background_removed_threshold_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 3 in Denoised Original Image with Background Removed via Threshold|ISOL:0000087')->cvterm_id;

    my $ft_hpf30_threshold_background_removed_tgi_from_denoised_original_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 TGI with Background Removed via Threshold|ISOL:0000088')->cvterm_id;
    my $ft_hpf30_threshold_background_removed_vari_from_denoised_original_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 VARI with Background Removed via Threshold|ISOL:0000089')->cvterm_id;
    my $ft_hpf30_threshold_background_removed_ndvi_from_denoised_original_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 NDVI with Background Removed via Threshold|ISOL:0000090')->cvterm_id;

    my $ft_hpf30_channel_1_denoised_original_bw_background_removed_threshold_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 1 in Denoised Original Black and White Image with Background Removed via Threshold|ISOL:0000091')->cvterm_id;
    my $ft_hpf30_channel_1_denoised_original_rgb_background_removed_threshold_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 1 in Denoised Original RGB Image with Background Removed via Threshold|ISOL:0000092')->cvterm_id;
    my $ft_hpf30_channel_2_denoised_original_rgb_background_removed_threshold_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 2 in Denoised Original RGB Image with Background Removed via Threshold|ISOL:0000093')->cvterm_id;
    my $ft_hpf30_channel_3_denoised_original_rgb_background_removed_threshold_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 3 in Denoised Original RGB Image with Background Removed via Threshold|ISOL:0000094')->cvterm_id;
    my $ft_hpf30_channel_1_denoised_original_blue_background_removed_threshold_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 1 in Denoised Original Blue Image with Background Removed via Threshold|ISOL:0000095')->cvterm_id;
    my $ft_hpf30_channel_1_denoised_original_green_background_removed_threshold_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 1 in Denoised Original Green Image with Background Removed via Threshold|ISOL:0000096')->cvterm_id;
    my $ft_hpf30_channel_1_denoised_original_red_background_removed_threshold_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 1 in Denoised Original Red Image with Background Removed via Threshold|ISOL:0000097')->cvterm_id;
    my $ft_hpf30_channel_1_denoised_original_red_edge_background_removed_threshold_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 1 in Denoised Original Red Edge Image with Background Removed via Threshold|ISOL:0000102')->cvterm_id;
    my $ft_hpf30_channel_1_denoised_original_nir_background_removed_threshold_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 1 in Denoised Original NIR Image with Background Removed via Threshold|ISOL:0000098')->cvterm_id;
    my $ft_hpf30_channel_1_denoised_original_mir_background_removed_threshold_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 1 in Denoised Original MIR Image with Background Removed via Threshold|ISOL:0000099')->cvterm_id;
    my $ft_hpf30_channel_1_denoised_original_fir_background_removed_threshold_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 1 in Denoised Original FIR Image with Background Removed via Threshold|ISOL:0000100')->cvterm_id;
    my $ft_hpf30_channel_1_denoised_original_tir_background_removed_threshold_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 1 in Denoised Original Thermal IR Image with Background Removed via Threshold|ISOL:0000101')->cvterm_id;

    my $ft_hpf30_channel_1_denoised_original_blue_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 1 in Denoised Original Blue Image|ISOL:0000103')->cvterm_id;
    my $ft_hpf30_channel_1_denoised_original_green_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 1 in Denoised Original Green Image|ISOL:0000104')->cvterm_id;
    my $ft_hpf30_channel_1_denoised_original_red_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 1 in Denoised Original Red Image|ISOL:0000105')->cvterm_id;
    my $ft_hpf30_channel_1_denoised_original_red_edge_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 1 in Denoised Original Red Edge Image|ISOL:0000106')->cvterm_id;
    my $ft_hpf30_channel_1_denoised_original_nir_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 1 in Denoised Original NIR Image|ISOL:0000107')->cvterm_id;
    my $ft_hpf30_channel_1_denoised_original_mir_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 1 in Denoised Original MIR Image|ISOL:0000108')->cvterm_id;
    my $ft_hpf30_channel_1_denoised_original_tir_cvterm_id = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'FT HPF 30 Channel 1 in Denoised Original TIR Image|ISOL:0000109')->cvterm_id;

    my $drone_run_band_project_type_cvterm_id;
    #print STDERR Dumper $drone_run_band_project_type;

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
    if ($drone_run_band_project_type eq 'Red Edge (690-750nm)') {
        $drone_run_band_project_type_cvterm_id = $red_edge_cvterm_id;
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
    if ($drone_run_band_project_type eq 'RGB Color Image') {
        $drone_run_band_project_type_cvterm_id = $rgb_cvterm_id;
    }
    if ($drone_run_band_project_type eq 'Merged 3 Bands BGR') {
        $drone_run_band_project_type_cvterm_id = $merged_3_bands_bgr_cvterm_id;
    }
    if ($drone_run_band_project_type eq 'Merged 3 Bands NRN') {
        $drone_run_band_project_type_cvterm_id = $merged_3_bands_nrn_cvterm_id;
    }

    my $drone_run_band_plot_polygons_preprocess_cvterm_id;
    #print STDERR Dumper $plot_polygons_type;
    #print STDERR Dumper $image_band_selected;

    if ($phenotype_method eq 'fourier_transform') {
        if ($plot_polygons_type eq 'observation_unit_polygon_tgi_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_tgi_from_denoised_original_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error => "On TGI there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_vari_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_vari_from_denoised_original_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error =>  "On VARI there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_ndvi_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_ndvi_from_denoised_original_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error =>  "On NDVI there is only the first channel!"};
            }
        }

        if ($plot_polygons_type eq 'observation_unit_polygon_background_removed_tgi_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_threshold_background_removed_tgi_from_denoised_original_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error =>  "On TGI there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_background_removed_vari_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_threshold_background_removed_vari_from_denoised_original_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error =>  "On VARI there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_background_removed_ndvi_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_threshold_background_removed_ndvi_from_denoised_original_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error =>  "On NDVI there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_original_background_removed_tgi_mask_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_1_denoised_original_background_removed_original_tgi_mask_cvterm_id;
            }
            if ($image_band_selected eq '1') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_2_denoised_original_background_removed_original_tgi_mask_cvterm_id;
            }
            if ($image_band_selected eq '2') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_3_denoised_original_background_removed_original_tgi_mask_cvterm_id;
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_original_background_removed_vari_mask_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_1_denoised_original_background_removed_original_vari_mask_cvterm_id;
            }
            if ($image_band_selected eq '1') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_2_denoised_original_background_removed_original_vari_mask_cvterm_id;
            }
            if ($image_band_selected eq '2') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_3_denoised_original_background_removed_original_vari_mask_cvterm_id;
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_original_background_removed_ndvi_mask_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_1_denoised_original_background_removed_original_ndvi_mask_cvterm_id;
            }
            if ($image_band_selected eq '1') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_2_denoised_original_background_removed_original_ndvi_mask_cvterm_id;
            }
            if ($image_band_selected eq '2') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_3_denoised_original_background_removed_original_ndvi_mask_cvterm_id;
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_1_denoised_original_background_removed_thresholded_tgi_mask_cvterm_id;
            }
            if ($image_band_selected eq '1') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_2_denoised_original_background_removed_thresholded_tgi_mask_cvterm_id;
            }
            if ($image_band_selected eq '2') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_3_denoised_original_background_removed_thresholded_tgi_mask_cvterm_id;
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_1_denoised_original_background_removed_thresholded_vari_mask_cvterm_id;
            }
            if ($image_band_selected eq '1') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_2_denoised_original_background_removed_thresholded_vari_mask_cvterm_id;
            }
            if ($image_band_selected eq '2') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_3_denoised_original_background_removed_thresholded_vari_mask_cvterm_id;
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_original_background_removed_thresholded_ndvi_mask_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_1_denoised_original_background_removed_thresholded_ndvi_mask_cvterm_id;
            }
            if ($image_band_selected eq '1') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_2_denoised_original_background_removed_thresholded_ndvi_mask_cvterm_id;
            }
            if ($image_band_selected eq '2') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_3_denoised_original_background_removed_thresholded_ndvi_mask_cvterm_id;
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_bw_background_removed_threshold_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_1_denoised_original_bw_background_removed_threshold_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error => "On Black and White there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_rgb_background_removed_threshold_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_1_denoised_original_rgb_background_removed_threshold_cvterm_id;
            }
            if ($image_band_selected eq '1') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_2_denoised_original_rgb_background_removed_threshold_cvterm_id;
            }
            if ($image_band_selected eq '2') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_3_denoised_original_rgb_background_removed_threshold_cvterm_id;
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_blue_background_removed_threshold_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_1_denoised_original_blue_background_removed_threshold_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error => "On Blue original image there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_green_background_removed_threshold_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_1_denoised_original_green_background_removed_threshold_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error => "On Green original image there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_red_background_removed_threshold_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_1_denoised_original_red_background_removed_threshold_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error => "On Red original image there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_red_edge_background_removed_threshold_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_1_denoised_original_red_edge_background_removed_threshold_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error => "On Red original image there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_nir_background_removed_threshold_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_1_denoised_original_nir_background_removed_threshold_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error => "On NIR original image there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_mir_background_removed_threshold_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_1_denoised_original_mir_background_removed_threshold_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error => "On MIR original image there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_fir_background_removed_threshold_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_1_denoised_original_fir_background_removed_threshold_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error => "On FIR original image there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_tir_background_removed_threshold_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_1_denoised_original_tir_background_removed_threshold_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error => "On TIR original image there is only the first channel!"};
            }
        }
    } else {
        if ($plot_polygons_type eq 'observation_unit_polygon_tgi_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $tgi_from_denoised_original_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error => "On TGI there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_vari_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $vari_from_denoised_original_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error =>  "On VARI there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_ndvi_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ndvi_from_denoised_original_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error =>  "On NDVI there is only the first channel!"};
            }
        }

        if ($plot_polygons_type eq 'observation_unit_polygon_background_removed_tgi_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $threshold_background_removed_tgi_from_denoised_original_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error =>  "On TGI there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_background_removed_vari_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $threshold_background_removed_vari_from_denoised_original_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error =>  "On VARI there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_background_removed_ndvi_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $threshold_background_removed_ndvi_from_denoised_original_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error =>  "On NDVI there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_original_background_removed_tgi_mask_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $channel_1_denoised_original_background_removed_original_tgi_mask_cvterm_id;
            }
            if ($image_band_selected eq '1') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $channel_2_denoised_original_background_removed_original_tgi_mask_cvterm_id;
            }
            if ($image_band_selected eq '2') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $channel_3_denoised_original_background_removed_original_tgi_mask_cvterm_id;
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_original_background_removed_vari_mask_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $channel_1_denoised_original_background_removed_original_vari_mask_cvterm_id;
            }
            if ($image_band_selected eq '1') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $channel_2_denoised_original_background_removed_original_vari_mask_cvterm_id;
            }
            if ($image_band_selected eq '2') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $channel_3_denoised_original_background_removed_original_vari_mask_cvterm_id;
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_original_background_removed_ndvi_mask_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $channel_1_denoised_original_background_removed_original_ndvi_mask_cvterm_id;
            }
            if ($image_band_selected eq '1') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $channel_2_denoised_original_background_removed_original_ndvi_mask_cvterm_id;
            }
            if ($image_band_selected eq '2') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $channel_3_denoised_original_background_removed_original_ndvi_mask_cvterm_id;
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $channel_1_denoised_original_background_removed_thresholded_tgi_mask_cvterm_id;
            }
            if ($image_band_selected eq '1') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $channel_2_denoised_original_background_removed_thresholded_tgi_mask_cvterm_id;
            }
            if ($image_band_selected eq '2') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $channel_3_denoised_original_background_removed_thresholded_tgi_mask_cvterm_id;
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $channel_1_denoised_original_background_removed_thresholded_vari_mask_cvterm_id;
            }
            if ($image_band_selected eq '1') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $channel_2_denoised_original_background_removed_thresholded_vari_mask_cvterm_id;
            }
            if ($image_band_selected eq '2') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $channel_3_denoised_original_background_removed_thresholded_vari_mask_cvterm_id;
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_original_background_removed_thresholded_ndvi_mask_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $channel_1_denoised_original_background_removed_thresholded_ndvi_mask_cvterm_id;
            }
            if ($image_band_selected eq '1') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $channel_2_denoised_original_background_removed_thresholded_ndvi_mask_cvterm_id;
            }
            if ($image_band_selected eq '2') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $channel_3_denoised_original_background_removed_thresholded_ndvi_mask_cvterm_id;
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_bw_background_removed_threshold_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $channel_1_denoised_original_bw_background_removed_threshold_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error => "On Black and White there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_rgb_background_removed_threshold_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $channel_1_denoised_original_rgb_background_removed_threshold_cvterm_id;
            }
            if ($image_band_selected eq '1') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $channel_2_denoised_original_rgb_background_removed_threshold_cvterm_id;
            }
            if ($image_band_selected eq '2') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $channel_3_denoised_original_rgb_background_removed_threshold_cvterm_id;
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_blue_background_removed_threshold_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $channel_1_denoised_original_blue_background_removed_threshold_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error => "On Blue original image there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_green_background_removed_threshold_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $channel_1_denoised_original_green_background_removed_threshold_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error => "On Green original image there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_red_background_removed_threshold_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $channel_1_denoised_original_red_background_removed_threshold_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error => "On Red original image there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_red_edge_background_removed_threshold_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $channel_1_denoised_original_red_edge_background_removed_threshold_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error => "On Red original image there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_nir_background_removed_threshold_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $channel_1_denoised_original_nir_background_removed_threshold_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error => "On NIR original image there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_mir_background_removed_threshold_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $channel_1_denoised_original_mir_background_removed_threshold_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error => "On MIR original image there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_fir_background_removed_threshold_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $channel_1_denoised_original_fir_background_removed_threshold_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error => "On FIR original image there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_tir_background_removed_threshold_imagery') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $channel_1_denoised_original_tir_background_removed_threshold_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error => "On TIR original image there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_fourier_transform_hpf30_blue_denoised_stitched_image_channel_1') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_1_denoised_original_blue_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error => "On blue image there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_fourier_transform_hpf30_green_denoised_stitched_image_channel_1') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_1_denoised_original_green_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error => "On green image there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_fourier_transform_hpf30_red_denoised_stitched_image_channel_1') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_1_denoised_original_red_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error => "On red image there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_fourier_transform_hpf30_rededge_denoised_stitched_image_channel_1') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_1_denoised_original_red_edge_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error => "On rededge image there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_fourier_transform_hpf30_nir_denoised_stitched_image_channel_1') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_1_denoised_original_nir_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error => "On nir image there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_fourier_transform_hpf30_mir_denoised_stitched_image_channel_1') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_1_denoised_original_mir_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error => "On mir image there is only the first channel!"};
            }
        }
        if ($plot_polygons_type eq 'observation_unit_polygon_fourier_transform_hpf30_tir_denoised_stitched_image_channel_1') {
            if ($image_band_selected eq '0') {
                $drone_run_band_plot_polygons_preprocess_cvterm_id = $ft_hpf30_channel_1_denoised_original_tir_cvterm_id;
            }
            if ($image_band_selected eq '1' || $image_band_selected eq '2') {
                return {error => "On tir image there is only the first channel!"};
            }
        }
    }
    if (!$drone_run_band_plot_polygons_preprocess_cvterm_id) {
        die "Could not get preprocess cvterm for $plot_polygons_type\n";
    }

    my $plot_polygons_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, $plot_polygons_type, 'project_md_image')->cvterm_id();
    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_band_project_id_list=>[$drone_run_band_project_id],
        project_image_type_id=>$plot_polygons_images_cvterm_id
    });
    my ($result, $total_count) = $images_search->search();
    #print STDERR Dumper $result;
    print STDERR Dumper $total_count;

    my @header_cols;
    my @stocks;
    if ($total_count == 0) {
        return {error => "No plot polygon images for this type $plot_polygons_type!"};
    } else {

        my $traits = SGN::Model::Cvterm->get_traits_from_component_categories($schema, $allowed_composed_cvs, $composable_cvterm_delimiter, $composable_cvterm_format, {
            object => [],
            attribute => [$drone_run_band_project_type_cvterm_id],
            method => [],
            unit => [],
            trait => [$non_zero_pixel_count_cvterm_id, $total_pixel_sum_cvterm_id, $mean_pixel_value_cvterm_id, $harmonic_mean_pixel_value_cvterm_id, $median_pixel_value_cvterm_id, $pixel_variance_cvterm_id, $pixel_standard_dev_cvterm_id, $pixel_pstandard_dev_cvterm_id, $minimum_pixel_value_cvterm_id, $maximum_pixel_value_cvterm_id, $minority_pixel_value_cvterm_id, $minority_pixel_count_cvterm_id, $majority_pixel_value_cvterm_id, $majority_pixel_count_cvterm_id, $pixel_group_count_cvterm_id],
            tod => [$drone_run_band_plot_polygons_preprocess_cvterm_id],
            toy => [$time_cvterm_id],
            gen => [],
        });
        my $existing_traits = $traits->{existing_traits};
        my $new_traits = $traits->{new_traits};
        print STDERR Dumper $new_traits;
        print STDERR Dumper $existing_traits;
        my %new_trait_names;
        foreach (@$new_traits) {
            my $components = $_->[0];
            $new_trait_names{$_->[1]} = join ',', @$components;
        }

        my $onto = CXGN::Onto->new( { schema => $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado') } );
        my $new_terms = $onto->store_composed_term(\%new_trait_names);

        my $non_zero_pixel_count_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$non_zero_pixel_count_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $total_pixel_sum_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$total_pixel_sum_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $mean_pixel_value_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$mean_pixel_value_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $harmonic_mean_pixel_value_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$harmonic_mean_pixel_value_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $median_pixel_value_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$median_pixel_value_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $pixel_variance_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$pixel_variance_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $pixel_standard_dev_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$pixel_standard_dev_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $pixel_pstandard_dev_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$pixel_pstandard_dev_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $minimum_pixel_value_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$minimum_pixel_value_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $maximum_pixel_value_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$maximum_pixel_value_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $minority_pixel_value_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$minority_pixel_value_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $minority_pixel_count_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$minority_pixel_count_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $majority_pixel_value_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$majority_pixel_value_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $majority_pixel_count_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$majority_pixel_count_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);
        my $pixel_group_count_composed_cvterm_id = SGN::Model::Cvterm->get_trait_from_exact_components($schema, [$pixel_group_count_cvterm_id, $drone_run_band_project_type_cvterm_id, $drone_run_band_plot_polygons_preprocess_cvterm_id, $time_cvterm_id]);

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

        my $temp_images_subdir = '';
        my $temp_results_subdir = '';
        my $calculate_phenotypes_script = '';
        my $linking_table_type_id;
        my $calculate_phenotypes_extra_args = '';
        my $archive_file_type = '';
        if ($phenotype_method eq 'zonal') {
            $temp_images_subdir = 'drone_imagery_calc_phenotypes_zonal_stats';
            $temp_results_subdir = 'drone_imagery_calc_phenotypes_zonal_stats_results';
            $calculate_phenotypes_script = 'CalculatePhenotypeZonalStats.py';
            $calculate_phenotypes_extra_args = ' --image_band_index '.$image_band_selected.' --plot_polygon_type '.$plot_polygons_type. ' --margin_percent 5';
            $archive_file_type = 'zonal_statistics_image_phenotypes';
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
        } elsif ($phenotype_method eq 'fourier_transform') {
            $temp_images_subdir = 'drone_imagery_calc_phenotypes_fourier_transform';
            $temp_results_subdir = 'drone_imagery_calc_phenotypes_fourier_transform_results';
            $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'calculate_phenotypes_fourier_transform_drone_imagery', 'project_md_image')->cvterm_id();
            $calculate_phenotypes_script = 'CalculatePhenotypeFourierTransform.py';
            $calculate_phenotypes_extra_args = ' --image_band_index '.$image_band_selected.' --plot_polygon_type '.$plot_polygons_type. ' --margin_percent 5 --frequency_threshold 30';
            $archive_file_type = 'fourier_transform_image_phenotypes';
        }

        my @image_paths;
        my @out_paths;
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
                image => '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>',
                image_id => $image_id
            };
        }
        #print STDERR Dumper \@image_paths;
        my $image_paths_string = join ',', @image_paths;
        my $out_paths_string = join ',', @out_paths;

        if ($out_paths_string) {
            $out_paths_string = ' --outfile_paths '.$out_paths_string;
        }

        my $dir = $c->tempfiles_subdir('/'.$temp_results_subdir);
        my $archive_temp_results = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => $temp_results_subdir.'/imageXXXX');

        my $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/ImageProcess/'.$calculate_phenotypes_script.' --image_paths \''.$image_paths_string.'\' '.$out_paths_string.' --results_outfile_path \''.$archive_temp_results.'\''.$calculate_phenotypes_extra_args;
        #print STDERR Dumper $cmd;
        my $status = system($cmd);

        my $time = DateTime->now();
        my $timestamp = $time->ymd()."_".$time->hms();

        my $csv = Text::CSV->new({ sep_char => ',' });
        open(my $fh, '<', $archive_temp_results)
            or die "Could not open file '$archive_temp_results' $!";

            print STDERR "Opened $archive_temp_results\n";
            my $header = <$fh>;
            if ($csv->parse($header)) {
                @header_cols = $csv->fields();
            }

            my $line = 0;
            my %zonal_stat_phenotype_data;
            my %plots_seen;
            my @traits_seen;
            if ($phenotype_method eq 'zonal' || $phenotype_method eq 'fourier_transform') {
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
                    $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$non_zero_pixel_count_composed_trait_name} = [$columns[0], $timestamp, $user_name, '', $stocks[$line]->{image_id}];
                    $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$total_pixel_sum_composed_trait_name} = [$columns[1], $timestamp, $user_name, '', $stocks[$line]->{image_id}];
                    $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$mean_pixel_value_composed_trait_name} = [$columns[2], $timestamp, $user_name, '', $stocks[$line]->{image_id}];
                    $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$harmonic_mean_pixel_value_composed_trait_name} = [$columns[3], $timestamp, $user_name, '', $stocks[$line]->{image_id}];
                    $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$median_pixel_value_composed_trait_name} = [$columns[4], $timestamp, $user_name, '', $stocks[$line]->{image_id}];
                    $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$pixel_variance_composed_trait_name} = [$columns[5], $timestamp, $user_name, '', $stocks[$line]->{image_id}];
                    $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$pixel_standard_dev_composed_trait_name} = [$columns[6], $timestamp, $user_name, '', $stocks[$line]->{image_id}];
                    $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$pixel_pstandard_dev_composed_trait_name} = [$columns[7], $timestamp, $user_name, '', $stocks[$line]->{image_id}];
                    $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$minimum_pixel_value_composed_trait_name} = [$columns[8], $timestamp, $user_name, '', $stocks[$line]->{image_id}];
                    $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$maximum_pixel_value_composed_trait_name} = [$columns[9], $timestamp, $user_name, '', $stocks[$line]->{image_id}];
                    $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$minority_pixel_value_composed_trait_name} = [$columns[10], $timestamp, $user_name, '', $stocks[$line]->{image_id}];
                    $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$minority_pixel_count_composed_trait_name} = [$columns[11], $timestamp, $user_name, '', $stocks[$line]->{image_id}];
                    $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$majority_pixel_value_composed_trait_name} = [$columns[12], $timestamp, $user_name, '', $stocks[$line]->{image_id}];
                    $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$majority_pixel_count_composed_trait_name} = [$columns[13], $timestamp, $user_name, '', $stocks[$line]->{image_id}];
                    $zonal_stat_phenotype_data{$stocks[$line]->{stock_uniquename}}->{$pixel_group_count_composed_trait_name} = [$columns[14], $timestamp, $user_name, '', $stocks[$line]->{image_id}];

                    $line++;
                }
            }

        close $fh;
        print STDERR "Read $line lines in results file\n";

        if ($line > 0) {
            my %phenotype_metadata = (
                'archived_file' => $archive_temp_results,
                'archived_file_type' => $archive_file_type,
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

            my $image_fullpath;
            my $image_url;
            my $image_source_tag_small;
            my $image_id;

            my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
            my $md5checksum = $image->calculate_md5sum($_);
            my $md_image = $metadata_schema->resultset("MdImage")->search({md5sum=>$md5checksum, obsolete=>'f'});
            if ($md_image->count() > 0) {
                print STDERR Dumper "Image $_ has already been added to the database and will not be added again.";
                $image_id = $md_image->first->image_id;
                $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
                $image_fullpath = $image->get_filename('original_converted', 'full');
                $image_url = $image->get_image_url('original');
                $image_source_tag_small = $image->get_img_src_tag("tiny");
            } else {
                $image->set_sp_person_id($user_id);
                my $ret = $image->process_image($_, 'project', $drone_run_band_project_id, $linking_table_type_id);
                $ret = $image->associate_stock($stock->{stock_id});
                $image_fullpath = $image->get_filename('original_converted', 'full');
                $image_url = $image->get_image_url('original');
                $image_source_tag_small = $image->get_img_src_tag("tiny");
                $image_id = $image->get_image_id;
            }

            $stocks[$count]->{image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
            $stocks[$count]->{image_path} = $image_fullpath;
            $stocks[$count]->{image_url} = $image_url;
            $count++;
        }
    }

    return {
        result_header => \@header_cols, results => \@stocks
    };
}

sub drone_imagery_train_keras_model : Path('/api/drone_imagery/train_keras_model') : ActionClass('REST') { }

sub drone_imagery_train_keras_model_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $field_trial_id = $c->req->param('field_trial_id');
    my $trait_id = $c->req->param('trait_id');
    my $drone_run_ids = decode_json($c->req->param('drone_run_ids'));
    my $plot_polygon_type_ids = decode_json($c->req->param('plot_polygon_type_ids'));
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $observation_unit_polygon_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_bw_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_bw_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_rgb_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_blue_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_blue_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_green_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_green_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_red_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_red_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_red_edge_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_red_edge_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_nir_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_nir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_mir_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_mir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_fir_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_tir_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_tir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_tgi_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_tgi_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_vari_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_vari_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_ndvi_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_ndvi_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_background_removed_tgi_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_background_removed_tgi_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_background_removed_vari_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_background_removed_vari_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_background_removed_ndvi_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_background_removed_ndvi_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_original_background_removed_tgi_mask_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_tgi_mask_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_original_background_removed_vari_mask_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_vari_mask_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_original_background_removed_ndvi_mask_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_ndvi_mask_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_original_background_removed_thresholded_ndvi_mask_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_ndvi_mask_imagery', 'project_md_image')->cvterm_id();

    my $dir = $c->tempfiles_subdir('/drone_imagery_keras_cnn_dir');
    my $archive_temp_result_agg_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/resultaggXXXX');

    my @result_agg;
    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_project_id_list=>$drone_run_ids,
        project_image_type_id_list=>$plot_polygon_type_ids
    });
    my ($result, $total_count) = $images_search->search();
    #print STDERR Dumper $result;
    print STDERR Dumper $total_count;

    my %data_hash;
    foreach (@$result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_url = $image->get_image_url("original");
        my $image_fullpath = $image->get_filename('original_converted', 'full');
        push @{$data_hash{$_->{stock_id}}->{image_fullpaths}}, $image_fullpath;
    }

    my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
        bcs_schema=>$schema,
        search_type=>'MaterializedViewTable',
        data_level=>'plot',
        trait_list=>[$trait_id],
        trial_list=>[$field_trial_id],
        include_timestamp=>0,
        exclude_phenotype_outlier=>0,
    );
    my @data = $phenotypes_search->get_phenotype_matrix();

    my $phenotype_header = shift @data;
    foreach (@data) {
        $data_hash{$_->[21]}->{trait_value} = $_->[39];
    }
    #print STDERR Dumper \%data_hash;

    my $archive_temp_input_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/inputfileXXXX');
    my $archive_temp_output_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/outputfileXXXX');
    my $archive_temp_output_model_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/modelfileXXXX');

    open(my $F, ">", $archive_temp_input_file) || die "Can't open file ".$archive_temp_input_file;
        foreach my $data (values %data_hash){
            my $image_fullpaths = $data->{image_fullpaths};
            my $value = $data->{trait_value};
            if ($value) {
                foreach (@$image_fullpaths) {
                    print $F '"'.$_.'",';
                    print $F '"'.$value.'"';
                    print $F "\n";
                }
            }
        }
    close($F);

    my $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/CNN/BasicCNN.py --input_image_label_file \''.$archive_temp_input_file.'\' --outfile_path \''.$archive_temp_output_file.'\' --output_model_file_path \''.$archive_temp_output_model_file.'\'';
    print STDERR Dumper $cmd;
    my $status = system($cmd);

    my @header_cols;
    my $csv = Text::CSV->new({ sep_char => ',' });
    open(my $fh, '<', $archive_temp_output_file)
        or die "Could not open file '$archive_temp_output_file' $!";

        my $header = <$fh>;
        if ($csv->parse($header)) {
            @header_cols = $csv->fields();
        }
        while ( my $row = <$fh> ){
            my @columns;
            if ($csv->parse($row)) {
                @columns = $csv->fields();
            }
            push @result_agg, \@columns;
        }
    close($fh);
    #print STDERR Dumper \@result_agg;

    print STDERR Dumper $archive_temp_result_agg_file;
    open($F, ">", $archive_temp_result_agg_file) || die "Can't open file ".$archive_temp_result_agg_file;
        foreach my $data (@result_agg){
            print $F join ',', @$data;
            print $F "\n";
        }
    close($F);

    $c->stash->{rest} = { success => 1, results => \@result_agg };
}

sub drone_imagery_train_keras_model_optimize : Path('/api/drone_imagery/train_keras_model_optimize') : ActionClass('REST') { }

sub drone_imagery_train_keras_model_optimize_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $field_trial_id = $c->req->param('field_trial_id');
    my $trait_id = $c->req->param('trait_id');
    my $drone_run_ids = decode_json($c->req->param('drone_run_ids'));
    my $plot_polygon_type_ids = decode_json($c->req->param('plot_polygon_type_ids'));
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $observation_unit_polygon_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_bw_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_bw_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_rgb_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_rgb_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_blue_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_blue_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_green_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_green_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_red_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_red_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_red_edge_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_red_edge_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_nir_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_nir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_mir_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_mir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_fir_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_fir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_tir_background_removed_threshold_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_tir_background_removed_threshold_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_tgi_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_tgi_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_vari_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_vari_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_ndvi_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_ndvi_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_background_removed_tgi_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_background_removed_tgi_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_background_removed_vari_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_background_removed_vari_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_background_removed_ndvi_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_background_removed_ndvi_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_original_background_removed_tgi_mask_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_tgi_mask_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_original_background_removed_vari_mask_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_vari_mask_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_original_background_removed_ndvi_mask_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_ndvi_mask_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery', 'project_md_image')->cvterm_id();
    my $observation_unit_polygon_original_background_removed_thresholded_ndvi_mask_imagery_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'observation_unit_polygon_original_background_removed_thresholded_ndvi_mask_imagery', 'project_md_image')->cvterm_id();

    my @polygon_type_combos = (
        # [$observation_unit_polygon_imagery_cvterm_id],
        # [$observation_unit_polygon_original_background_removed_threshold_imagery_cvterm_id],
        # [$observation_unit_polygon_tgi_imagery_cvterm_id],
        # [$observation_unit_polygon_vari_imagery_cvterm_id],
        # [$observation_unit_polygon_ndvi_imagery_cvterm_id],
        # [$observation_unit_polygon_background_removed_tgi_imagery_cvterm_id],
        # [$observation_unit_polygon_background_removed_vari_imagery_cvterm_id],
        # [$observation_unit_polygon_background_removed_ndvi_imagery_cvterm_id],
        # [$observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_cvterm_id],
        # [$observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_cvterm_id],
        # [$observation_unit_polygon_original_background_removed_thresholded_ndvi_mask_imagery_cvterm_id]
        # [$observation_unit_polygon_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_tgi_imagery_cvterm_id, $observation_unit_polygon_vari_imagery_cvterm_id, $observation_unit_polygon_ndvi_imagery_cvterm_id],
        # [$observation_unit_polygon_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_background_removed_tgi_imagery_cvterm_id, $observation_unit_polygon_background_removed_vari_imagery_cvterm_id, $observation_unit_polygon_background_removed_ndvi_imagery_cvterm_id],
        # [$observation_unit_polygon_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_tgi_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_vari_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_ndvi_mask_imagery_cvterm_id],
        # [$observation_unit_polygon_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_thresholded_ndvi_mask_imagery_cvterm_id],
        # [$observation_unit_polygon_tgi_imagery_cvterm_id, $observation_unit_polygon_vari_imagery_cvterm_id, $observation_unit_polygon_ndvi_imagery_cvterm_id, $observation_unit_polygon_background_removed_tgi_imagery_cvterm_id, $observation_unit_polygon_background_removed_vari_imagery_cvterm_id, $observation_unit_polygon_background_removed_ndvi_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_tgi_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_vari_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_ndvi_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_thresholded_ndvi_mask_imagery_cvterm_id],
        # [$observation_unit_polygon_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_tgi_imagery_cvterm_id, $observation_unit_polygon_vari_imagery_cvterm_id, $observation_unit_polygon_background_removed_tgi_imagery_cvterm_id, $observation_unit_polygon_background_removed_vari_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_tgi_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_vari_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_cvterm_id],
        # [$observation_unit_polygon_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_tgi_imagery_cvterm_id, $observation_unit_polygon_ndvi_imagery_cvterm_id, $observation_unit_polygon_background_removed_tgi_imagery_cvterm_id, $observation_unit_polygon_background_removed_ndvi_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_tgi_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_ndvi_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_thresholded_ndvi_mask_imagery_cvterm_id],
        # [$observation_unit_polygon_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_vari_imagery_cvterm_id, $observation_unit_polygon_ndvi_imagery_cvterm_id, $observation_unit_polygon_background_removed_vari_imagery_cvterm_id, $observation_unit_polygon_background_removed_ndvi_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_vari_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_ndvi_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_thresholded_ndvi_mask_imagery_cvterm_id],
        # [$observation_unit_polygon_tgi_imagery_cvterm_id, $observation_unit_polygon_vari_imagery_cvterm_id, $observation_unit_polygon_background_removed_tgi_imagery_cvterm_id, $observation_unit_polygon_background_removed_vari_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_tgi_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_vari_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_cvterm_id],
        # [$observation_unit_polygon_tgi_imagery_cvterm_id, $observation_unit_polygon_ndvi_imagery_cvterm_id, $observation_unit_polygon_background_removed_tgi_imagery_cvterm_id, $observation_unit_polygon_background_removed_ndvi_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_tgi_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_ndvi_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_thresholded_ndvi_mask_imagery_cvterm_id],
        # [$observation_unit_polygon_vari_imagery_cvterm_id, $observation_unit_polygon_ndvi_imagery_cvterm_id, $observation_unit_polygon_background_removed_vari_imagery_cvterm_id, $observation_unit_polygon_background_removed_ndvi_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_vari_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_ndvi_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_thresholded_ndvi_mask_imagery_cvterm_id],
        [$observation_unit_polygon_imagery_cvterm_id, $observation_unit_polygon_bw_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_rgb_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_blue_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_green_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_red_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_red_edge_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_nir_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_mir_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_fir_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_tir_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_tgi_imagery_cvterm_id, $observation_unit_polygon_vari_imagery_cvterm_id, $observation_unit_polygon_ndvi_imagery_cvterm_id, $observation_unit_polygon_background_removed_tgi_imagery_cvterm_id, $observation_unit_polygon_background_removed_vari_imagery_cvterm_id, $observation_unit_polygon_background_removed_ndvi_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_tgi_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_vari_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_ndvi_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_thresholded_ndvi_mask_imagery_cvterm_id],

    );

    my $dir = $c->tempfiles_subdir('/drone_imagery_keras_cnn_dir');
    my $archive_temp_result_agg_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/resultaggXXXX');

    my @result_agg;
    foreach my $combo (@polygon_type_combos){
        foreach (1..1) {
            my $images_search = CXGN::DroneImagery::ImagesSearch->new({
                bcs_schema=>$schema,
                drone_run_project_id_list=>$drone_run_ids,
                project_image_type_id_list=>$combo
                #project_image_type_id_list=>$plot_polygon_type_ids
                #project_image_type_id_list=>[$observation_unit_polygon_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_threshold_imagery_cvterm_id, $observation_unit_polygon_tgi_imagery_cvterm_id, $observation_unit_polygon_vari_imagery_cvterm_id, $observation_unit_polygon_ndvi_imagery_cvterm_id, $observation_unit_polygon_background_removed_tgi_imagery_cvterm_id, $observation_unit_polygon_background_removed_vari_imagery_cvterm_id, $observation_unit_polygon_background_removed_ndvi_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_tgi_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_vari_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_ndvi_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_thresholded_tgi_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_thresholded_vari_mask_imagery_cvterm_id, $observation_unit_polygon_original_background_removed_thresholded_ndvi_mask_imagery_cvterm_id]
            });
            my ($result, $total_count) = $images_search->search();
            #print STDERR Dumper $result;
            print STDERR Dumper $total_count;
            my $combo_string = join ',', @$combo;
            push @result_agg, [$combo_string, $_, $total_count];

            my %data_hash;
            foreach (@$result) {
                my $image_id = $_->{image_id};
                my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
                my $image_url = $image->get_image_url("original");
                my $image_fullpath = $image->get_filename('original_converted', 'full');
                push @{$data_hash{$_->{stock_id}}->{image_fullpaths}}, $image_fullpath;
            }

            my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
                bcs_schema=>$schema,
                search_type=>'MaterializedViewTable',
                data_level=>'plot',
                trait_list=>[$trait_id],
                trial_list=>[$field_trial_id],
                include_timestamp=>0,
                exclude_phenotype_outlier=>0,
            );
            my @data = $phenotypes_search->get_phenotype_matrix();

            my $phenotype_header = shift @data;
            foreach (@data) {
                $data_hash{$_->[21]}->{trait_value} = $_->[39];
            }
            #print STDERR Dumper \%data_hash;

            my $archive_temp_input_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/inputfileXXXX');
            my $archive_temp_output_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/outputfileXXXX');
            my $archive_temp_output_model_file = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_keras_cnn_dir/modelfileXXXX');

            open(my $F, ">", $archive_temp_input_file) || die "Can't open file ".$archive_temp_input_file;
                foreach my $data (values %data_hash){
                    my $image_fullpaths = $data->{image_fullpaths};
                    my $value = $data->{trait_value};
                    if ($value) {
                        foreach (@$image_fullpaths) {
                            print $F '"'.$_.'",';
                            print $F '"'.$value.'"';
                            print $F "\n";
                        }
                    }
                }
            close($F);

            my $cmd = $c->config->{python_executable}.' '.$c->config->{rootpath}.'/DroneImageScripts/CNN/TransferLearningCNN.py --input_image_label_file \''.$archive_temp_input_file.'\' --outfile_path \''.$archive_temp_output_file.'\' --output_model_file_path \''.$archive_temp_output_model_file.'\'';
            print STDERR Dumper $cmd;
            my $status = system($cmd);

            my @header_cols;
            my $csv = Text::CSV->new({ sep_char => ',' });
            open(my $fh, '<', $archive_temp_output_file)
                or die "Could not open file '$archive_temp_output_file' $!";

                my $header = <$fh>;
                if ($csv->parse($header)) {
                    @header_cols = $csv->fields();
                }
                while ( my $row = <$fh> ){
                    my @columns;
                    if ($csv->parse($row)) {
                        @columns = $csv->fields();
                    }
                    push @result_agg, \@columns;
                }
            close($fh);
        }
    }
    #print STDERR Dumper \@result_agg;

    print STDERR Dumper $archive_temp_result_agg_file;
    open(my $F, ">", $archive_temp_result_agg_file) || die "Can't open file ".$archive_temp_result_agg_file;
        foreach my $data (@result_agg){
            print $F join ',', @$data;
            print $F "\n";
        }
    close($F);

    $c->stash->{rest} = { success => 1, results => \@result_agg };
}

sub drone_imagery_delete_drone_run : Path('/api/drone_imagery/delete_drone_run') : ActionClass('REST') { }

sub drone_imagery_delete_drone_run_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    print STDERR "DELETING DRONE RUN\n";

    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_project_id_list=>[$drone_run_project_id],
    });
    my ($result, $total_count) = $images_search->search();
    print STDERR Dumper $total_count;

    my %drone_run_band_project_ids;
    my %image_ids;
    foreach (@$result) {
        $drone_run_band_project_ids{$_->{drone_run_band_project_id}}++;
        $image_ids{$_->{image_id}}++;
    }
    my @drone_run_band_ids = keys %drone_run_band_project_ids;
    my @drone_run_image_ids = keys %image_ids;

    foreach (keys %image_ids) {
        my $image = SGN::Image->new( $schema->storage->dbh, $_, $c );
        $image->delete(); #Sets to obsolete
    }

    my $drone_run_band_project_ids_sql = join ",", @drone_run_band_ids;
    my $drone_run_band_image_ids_sql = join ",", @drone_run_image_ids;
    my $q1 = "DELETE FROM phenome.project_md_image WHERE project_id in ($drone_run_band_project_ids_sql);";
    my $q2 = "DELETE FROM project WHERE project_id in ($drone_run_band_project_ids_sql);";
    my $q3 = "DELETE FROM project WHERE project_id = $drone_run_project_id;";
    my $h1 = $schema->storage->dbh()->prepare($q1);
    $h1->execute();
    my $h2 = $schema->storage->dbh()->prepare($q2);
    $h2->execute();
    my $h3 = $schema->storage->dbh()->prepare($q3);
    $h3->execute();

    my $q4 = "
        DROP TABLE IF EXISTS temp_drone_image_pheno_deletion;
        CREATE TEMP TABLE temp_drone_image_pheno_deletion AS
        (SELECT phenotype_id, nd_experiment_id, image_id
        FROM phenotype
        JOIN nd_experiment_phenotype using(phenotype_id)
        JOIN phenome.nd_experiment_md_images AS nd_experiment_md_images using(nd_experiment_id)
        WHERE nd_experiment_md_images.image_id IN ($drone_run_band_image_ids_sql) );
        DELETE FROM phenotype WHERE phenotype_id IN (SELECT phenotype_id FROM temp_drone_image_pheno_deletion);
        DELETE FROM phenome.nd_experiment_md_files WHERE nd_experiment_id IN (SELECT nd_experiment_id FROM temp_drone_image_pheno_deletion);
        DELETE FROM phenome.nd_experiment_md_images WHERE nd_experiment_id IN (SELECT nd_experiment_id FROM temp_drone_image_pheno_deletion);
        DELETE FROM nd_experiment WHERE nd_experiment_id IN (SELECT nd_experiment_id FROM temp_drone_image_pheno_deletion);
        DROP TABLE IF EXISTS temp_drone_image_pheno_deletion;
        ";
    my $h4 = $schema->storage->dbh()->prepare($q4);
    $h4->execute();

    $c->stash->{rest} = {success => 1};
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
