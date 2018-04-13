
=head1 NAME

SGN::Controller::AJAX::Locations - a REST controller class to provide the
backend for managing Locations

=head1 DESCRIPTION

Managing Locations

=cut

package SGN::Controller::AJAX::Locations;

use Moose;
use CXGN::Location;
use CXGN::BreedersToolbox::Projects;
use CXGN::Location::ParseUpload;
use Data::Dumper;
use Try::Tiny;
use JSON;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

   sub get_all_locations :Path("/ajax/location/all") Args(0) {
       my $self = shift;
       my $c = shift;

       my $location = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") });

       my $all_locations = $location->get_location_geojson();
       #print STDERR "Returning with all locations: ".$all_locations."\n";
       $c->stash->{rest} = { data => $all_locations };

   }

   sub store_location :Path("/ajax/location/store") Args(0) {
       my $self = shift;
       my $c = shift;
       my $params = $c->request->parameters();
       my $id = $params->{id} || undef;
       my $name = $params->{name};
       my $abbreviation =  $params->{abbreviation}; 
       my $country_name =  $params->{country_name};
       my $country_code =  $params->{country_code};
       my $program =  $params->{program};
       my $type =  $params->{type};
       my $latitude    = $params->{latitude} || undef;
       my $longitude   = $params->{longitude} || undef;
       my $altitude    = $params->{altitude} || undef;

       if (! $c->user()) {
           $c->stash->{rest} = { error => 'You must be logged in to add or edit a location.' };
           return;
       }

       if (! $c->user->check_roles("submitter") && !$c->user->check_roles("curator")) {
           $c->stash->{rest} = { error => 'You do not have the necessary privileges to add or edit locations.' };
           return;
       }

       print STDERR "Creating location object\n";

       my $location = CXGN::Location->new( {
           bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
           nd_geolocation_id => $id,
           name => $name,
           abbreviation => $abbreviation,
           country_name => $country_name,
           country_code => $country_code,
           breeding_program => $program,
           location_type => $type,
           latitude => $latitude,
           longitude => $longitude,
           altitude => $altitude
       });

       my $store = $location->store_location();

       if ($store->{'error'}) {
           $c->stash->{rest} = { error => $store->{'error'} };
       }
       else {
           $c->stash->{rest} = { success => $store->{'success'}, nd_geolocation_id => $store->{'nd_geolocation_id'} };
       }

   }

   sub delete_location :Path('/ajax/location/delete') Args(1) {
       my $self = shift;
       my $c = shift;
       my $location_id = shift;

       if (!$c->user) {  # require login
   	$c->stash->{rest} = { error => "You need to be logged in to delete a location." };
   	return;
       }

       if (! ($c->user->check_roles('curator') || $c->user->check_roles('submitter'))) { # require curator or submitter roles
   	$c->stash->{rest} = { error => "You don't have the privileges to delete a location." };
   	return;
       }

       my $location_to_delete = CXGN::Location->new( {
           bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
           nd_geolocation_id => $location_id
       } );

       my $delete = $location_to_delete->delete_location();

   	if ($delete->{'success'}) {
   	    $c->stash->{rest} = { success => $delete->{'success'} };
   	}
   	else {
   	    $c->stash->{rest} = { error => $delete->{'error'} };
   	}
   }

   sub upload_locations : Path('/ajax/locations/upload') : ActionClass('REST') { }

   sub upload_locations_POST : Args(0) {
     my ($self, $c) = @_;
     my $schema = $c->dbic_schema("Bio::Chado::Schema");

     my $upload = $c->req->upload('locations_upload_file');
     my $upload_original_name = $upload->filename();
     my $upload_tempfile = $upload->tempname;

     my $time = DateTime->now();
     my $timestamp = $time->ymd()."_".$time->hms();
     my (@errors, %response);


     if (!$c->user()) {
       print STDERR "User not logged in... not uploading locations.\n";
       push @errors, "You need to be logged in to upload locations.";
       $c->stash->{rest} = {filename => $upload_original_name, error => \@errors };
       return;
     }

     my $user_id = $c->user()->get_object()->get_sp_person_id();
     my $user_role = $c->user->get_object->get_user_type();

     my $uploader = CXGN::UploadFile->new({
       tempfile => $upload_tempfile,
       subdirectory => 'location_upload',
       archive_path => $c->config->{archive_path},
       archive_filename => $upload_original_name,
       timestamp => $timestamp,
       user_id => $user_id,
       user_role => $user_role
     });

     ## Store uploaded temporary file in archive
     my $archived_filename_with_path = $uploader->archive();
     my $md5 = $uploader->get_md5($archived_filename_with_path);
     if (!$archived_filename_with_path) {
         push @errors, "Could not save file $upload_original_name in archive";
         $c->stash->{rest} = {filename => $upload_original_name, error => \@errors };
         return;
     }
     unlink $upload_tempfile;

     #parse uploaded file with appropriate plugin
     my $type = 'location excel';
     my $parser = CXGN::Location::ParseUpload->new();
     my $parse_result = $parser->parse($type, $archived_filename_with_path, $schema);

     print STDERR "Dump of parsed result:\t" . Dumper($parse_result) . "\n";

     if (!$parse_result) {
         push @errors, "Error parsing file.";
         $c->stash->{rest} = {filename => $upload_original_name, error => \@errors };
         return;
     }
     if ($parse_result->{'error'}) {
         $c->stash->{rest} = {filename => $upload_original_name, error => $parse_result->{'error'}};
         return;
     }

    foreach my $row (@{$parse_result->{'success'}}) {
     #get data from rows one at a time
        my @data = @$row;
         my $location = CXGN::Location->new( {
             bcs_schema => $schema,
             nd_geolocation_id => undef,
             name => $data[0],
             abbreviation => $data[1],
             country_code => $data[2],
             country_name => $data[3],
             breeding_program => $data[4],
             location_type => $data[5],
             latitude => $data[6],
             longitude => $data[7],
             altitude => $data[8]
         });

         my $store = $location->store_location();

         if ($store->{'error'}) {
            $response{$data[0]} = $store->{'error'};
         }
         else {
             $response{$data[0]} = $store->{'success'};
         }
    }

     $c->stash->{rest} = \%response;
   }

1;
