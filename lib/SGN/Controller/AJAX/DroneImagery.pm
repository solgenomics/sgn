
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

    my $images_zip = $c->req->upload('upload_drone_images_zipfile');
    if (!$images_zip) {
        $c->stash->{rest} = { error => "Please provide a drone image zipfile!" };
        $c->detach();
    }
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

    my $upload_original_name = $images_zip->filename();
    my $upload_tempfile = $images_zip->tempname;
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
    my $image_error = $image->upload_drone_imagery_zipfile($archived_filename_with_path, $user_id, $selected_drone_run_id);
    if ($image_error) {
        $c->stash->{rest} = { error => "Problem saving images!".$image_error };
        $c->detach();
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

    my $ft_stitched_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'fourier_transform_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $ft_stitched_images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        project_image_type_id=>$ft_stitched_drone_images_cvterm_id
    });
    my ($ft_stitched_result, $ft_stitched_total_count) = $ft_stitched_images_search->search();
    #print STDERR Dumper $result;

    my @return;
    my %unique_drone_runs;
    foreach (@$result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_source_tag_tiny = $image->get_img_src_tag("tiny");
        push @{$unique_drone_runs{$_->{drone_run_project_id}}->{images}}, '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
        $unique_drone_runs{$_->{drone_run_project_id}}->{usernames}->{$_->{username}}++;
        $unique_drone_runs{$_->{drone_run_project_id}}->{trial_id} = $_->{trial_id};
        $unique_drone_runs{$_->{drone_run_project_id}}->{trial_name} = $_->{trial_name};
        $unique_drone_runs{$_->{drone_run_project_id}}->{drone_run_project_name} = $_->{drone_run_project_name};
        $unique_drone_runs{$_->{drone_run_project_id}}->{drone_run_date} = $_->{drone_run_date};
        $unique_drone_runs{$_->{drone_run_project_id}}->{drone_run_project_description} = $_->{drone_run_project_description};
    }
    foreach (@$stitched_result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_source_tag_small = $image->get_img_src_tag("small");
        my $image_original = $image->get_image_url("original");
        $unique_drone_runs{$_->{drone_run_project_id}}->{stitched_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
        $unique_drone_runs{$_->{drone_run_project_id}}->{stitched_image_username} = $_->{username};
        $unique_drone_runs{$_->{drone_run_project_id}}->{stitched_image_original} = $image_original;
        $unique_drone_runs{$_->{drone_run_project_id}}->{stitched_image_id} = $image_id;
    }
    foreach (@$cropped_stitched_result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_source_tag_small = $image->get_img_src_tag("small");
        my $image_original = $image->get_image_url("original");
        $unique_drone_runs{$_->{drone_run_project_id}}->{cropped_stitched_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
        $unique_drone_runs{$_->{drone_run_project_id}}->{cropped_stitched_image_username} = $_->{username};
        $unique_drone_runs{$_->{drone_run_project_id}}->{cropped_stitched_image_original} = $image_original;
        $unique_drone_runs{$_->{drone_run_project_id}}->{cropped_stitched_image_id} = $image_id;
    }
    foreach (@$denoised_stitched_result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_source_tag_small = $image->get_img_src_tag("small");
        my $image_original = $image->get_image_url("original");
        $unique_drone_runs{$_->{drone_run_project_id}}->{denoised_stitched_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
        $unique_drone_runs{$_->{drone_run_project_id}}->{denoised_stitched_image_username} = $_->{username};
        $unique_drone_runs{$_->{drone_run_project_id}}->{denoised_stitched_image_original} = $image_original;
        $unique_drone_runs{$_->{drone_run_project_id}}->{denoised_stitched_image_id} = $image_id;
    }
    foreach (@$ft_stitched_result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_source_tag_small = $image->get_img_src_tag("small");
        my $image_original = $image->get_image_url("original");
        $unique_drone_runs{$_->{drone_run_project_id}}->{ft_stitched_image} = '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_small.'</a>';
        $unique_drone_runs{$_->{drone_run_project_id}}->{ft_stitched_image_username} = $_->{username};
        $unique_drone_runs{$_->{drone_run_project_id}}->{ft_stitched_image_original} = $image_original;
        $unique_drone_runs{$_->{drone_run_project_id}}->{ft_stitched_image_id} = $image_id;
    }

    my $calendar_funcs = CXGN::Calendar->new({});
    foreach my $k (sort keys %unique_drone_runs) {
        my $v = $unique_drone_runs{$k};
        my $images = scalar(@{$v->{images}})." Images<br/><span>";
        $images .= join '', @{$v->{images}};
        $images .= "</span>";
        my $usernames = '';
        foreach (keys %{$v->{usernames}}){
            $usernames .= " $_ ";
        }

        my $cell_html = '';
        if ($v->{stitched_image}) {
            $cell_html .= '<center><h5>Stitched&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$v->{stitched_image_id}.'"></span></h5></center>'.$v->{stitched_image}.'<br/><br/>';

            if ($v->{cropped_stitched_image}) {
                $cell_html .= '<center><h5>Cropped&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$v->{cropped_stitched_image_id}.'"></span></h5></center>'.$v->{cropped_stitched_image}.'<br/><br/>';

                if ($v->{denoised_stitched_image}) {
                    $cell_html .= '<center><h5>Denoised&nbsp;&nbsp;&nbsp;<span class="glyphicon glyphicon-remove-sign text-danger" name="drone_image_remove" data-image_id="'.$v->{denoised_stitched_image_id}.'"></span></h5></center>'.$v->{denoised_stitched_image}.'<br/><br/>';

                    $cell_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-stitched_image_id="'.$v->{stitched_image_id}.'" data-cropped_stitched_image_id="'.$v->{cropped_stitched_image_id}.'" data-denoised_stitched_image_id="'.$v->{denoised_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($v->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'">Create/View Plot Polygons</button>';

                    # if ($v->{ft_stitched_image}) {
                    #     $cell_html .= '<center><h5>FT High Pass</h5></center>'.$v->{ft_stitched_image}.'<br/><br/>';
                    #     $cell_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_plot_polygons" data-image_id="'.$v->{stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($v->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'">Create/View Plot Polygons</button>';
                    # } else {
                    #     $cell_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_fourier_transform" data-image_id="'.$v->{stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($v->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'">Apply FT Low Pass</button><br/><br/>';
                    # }

                } else {
                    $cell_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_denoise" data-cropped_stitched_image_id="'.$v->{cropped_stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($v->{stitched_image_original}).'" data-cropped_stitched_image="'.uri_encode($v->{cropped_stitched_image_original}).'" data-drone_run_project_id="'.$k.'">Denoise</button><br/><br/>';
                }

            } else {
                $cell_html .= '<button class="btn btn-primary btn-sm" name="project_drone_imagery_crop_image" data-stitched_image_id="'.$v->{stitched_image_id}.'" data-field_trial_id="'.$v->{trial_id}.'" data-stitched_image="'.uri_encode($v->{stitched_image_original}).'" data-drone_run_project_id="'.$k.'">Crop Stitched Image</button><br/><br/>';
            }
        } else {
            $cell_html .= '<button class="btn btn-primary" name="project_drone_imagery_stitch" data-drone_run_project_id="'.$k.'">Stitch Uploaded Images</button>';
        }

        my $drone_run_date = $v->{drone_run_date} ? $calendar_funcs->display_start_date($v->{drone_run_date}) : '';
        push @return, ["<a href=\"/breeders_toolbox/trial/$v->{trial_id}\">$v->{trial_name}</a>", $v->{drone_run_project_name}, $v->{drone_run_project_description}, $drone_run_date, $images, $cell_html];
    }

    $c->stash->{rest} = { data => \@return };
}

sub raw_drone_imagery_stitch : Path('/ajax/drone_imagery/raw_drone_imagery_stitch') : ActionClass('REST') { }

sub raw_drone_imagery_stitch_GET : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my ($user_id, $user_name, $user_role) = _check_user_login($c);

    my $raw_drone_images_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'raw_drone_imagery', 'project_md_image')->cvterm_id();
    my $images_search = CXGN::DroneImagery::ImagesSearch->new({
        bcs_schema=>$schema,
        drone_run_project_id_list=>[$drone_run_project_id],
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
    my $ret = $image->process_image($archive_stitched_temp_image, 'project', $drone_run_project_id, $linking_table_type_id);

    $c->stash->{rest} = { data => \@image_urls };
}

sub drone_imagery_get_contours : Path('/ajax/drone_imagery/get_contours') : ActionClass('REST') { }

sub drone_imagery_get_contours_GET : Args(0) {
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

    my $dir = $c->tempfiles_subdir('/drone_imagery_contours');
    my $archive_contours_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_contours/imageXXXX');
    $archive_contours_temp_image .= '.png';
    print STDERR $archive_contours_temp_image."\n";

    my $status = system('python /home/nmorales/cxgn/DroneImageScripts/ImageContours/GetContours.py --image_url '.$main_production_site.$image_url.' --outfile_path '.$archive_contours_temp_image);
    print STDERR Dumper $status;

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);
    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'contours_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $ret = $image->process_image($archive_contours_temp_image, 'project', $drone_run_project_id, $linking_table_type_id);
    my $contours_image_fullpath = $image->get_filename('original_converted', 'full');
    my $contours_image_url = $image->get_image_url('original');

    $c->stash->{rest} = { image_url => $image_url, image_fullpath => $image_fullpath, contours_image_url => $contours_image_url, contours_image_fullpath => $contours_image_fullpath };
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
    my $drone_run_project_id = $c->req->param('drone_run_project_id');
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
    print STDERR Dumper $status;

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);
    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'denoised_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $ret = $image->process_image($archive_denoise_temp_image, 'project', $drone_run_project_id, $linking_table_type_id);
    my $denoised_image_fullpath = $image->get_filename('original_converted', 'full');
    my $denoised_image_url = $image->get_image_url('original');

    $c->stash->{rest} = { image_url => $image_url, image_fullpath => $image_fullpath, denoised_image_url => $denoised_image_url, denoised_image_dullpath => $denoised_image_fullpath };
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
    my $drone_run_project_id = $c->req->param('drone_run_project_id');
    my $polygon = $c->req->param('polygon');
    my $polygon_obj = decode_json $polygon;
    if (scalar(@$polygon_obj) != 4){
        $c->stash->{rest} = {error=>'Polygon should be 4 long!'};
        $c->detach();
    }
    $polygon = encode_json $polygon_obj;
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

    my $cmd = "python /home/nmorales/cxgn/DroneImageScripts/ImageCropping/CropToPolygon.py --inputfile_path $image_fullpath --outputfile_path $archive_temp_image --polygon '$polygon'";
    print STDERR Dumper $cmd;
    my $status = system($cmd);
    print STDERR Dumper $status;

    $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
    $image->set_sp_person_id($user_id);
    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cropped_stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $ret = $image->process_image($archive_temp_image, 'project', $drone_run_project_id, $linking_table_type_id);
    my $cropped_image_fullpath = $image->get_filename('original_converted', 'full');
    my $cropped_image_url = $image->get_image_url('original');

    $c->stash->{rest} = { image_url => $image_url, image_fullpath => $image_fullpath, cropped_image_url => $cropped_image_url, cropped_image_fullpath => $cropped_image_fullpath };
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
