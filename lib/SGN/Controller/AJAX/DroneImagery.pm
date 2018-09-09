
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
use CXGN::DroneImagery::RawImagesSearch;

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
    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to upload this seedlot info!'};
            $c->detach();
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload this seedlot info!'};
            $c->detach();
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

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
    my $image_error = $image->upload_drone_imagery_zipfile($archived_filename_with_path, $user_id, $selected_trial_id);
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

    my $images_search = CXGN::DroneImagery::RawImagesSearch->new({
        bcs_schema=>$schema,
        # location_list=>\@locations,
        # program_list=>\@breeding_program_names,
        # program_id_list=>\@breeding_programs_ids,
        # year_list=>\@years,
        # trial_type_list=>\@trial_types,
        # trial_id_list=>\@trial_ids,
        # trial_name_list=>\@trial_names,
        # trial_name_is_exact=>1
    });
    my ($result, $total_count) = $images_search->search();
    #print STDERR Dumper $result;

    my @return;
    my %unique_trials;
    foreach (@$result) {
        my $image_id = $_->{image_id};
        my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
        my $image_source_tag_tiny = $image->get_img_src_tag("tiny");
        push @{$unique_trials{$_->{trial_id}}->{images}}, '<a href="/image/view/'.$image_id.'" target="_blank">'.$image_source_tag_tiny.'</a>';
        $unique_trials{$_->{trial_id}}->{usernames}->{$_->{username}}++;
        $unique_trials{$_->{trial_id}}->{trial_name} = $_->{trial_name};
    }
    while (my ($k, $v) = each %unique_trials) {
        my $images = scalar(@{$v->{images}})." Images<br/><span>";
        $images .= join '', @{$v->{images}};
        $images .= "</span>";
        my $usernames = '';
        foreach (keys %{$v->{usernames}}){
            $usernames .= " $_ ";
        }
        push @return, ["<a href=\"/breeders_toolbox/trial/$k\">$v->{trial_name}</a>", $usernames, $images, ''];
    }

    $c->stash->{rest} = { data => \@return };
}

1;
