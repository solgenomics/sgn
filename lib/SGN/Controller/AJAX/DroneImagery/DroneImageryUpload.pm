
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

   my $new_drone_run_band_numbers = $c->req->param('drone_run_band_number');
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

       my $upload_file;
       if ($new_drone_run_band_stitching eq 'yes') {
           $upload_file = $c->req->upload('upload_drone_images_zipfile');
       } elsif ($new_drone_run_band_stitching eq 'no') {
           $upload_file = $c->req->upload('drone_run_band_stitched_ortho_image_1');
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

           my $upload_file;
           if ($new_drone_run_band_stitching eq 'yes') {
               $upload_file = $c->req->upload('upload_drone_images_zipfile_'.$_);
           } elsif ($new_drone_run_band_stitching eq 'no') {
               $upload_file = $c->req->upload('drone_run_band_stitched_ortho_image_'.$_);
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
