
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
use Data::Dumper;
use Try::Tiny;

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

       my $all_locations = $location->get_all_locations();

       print STDERR "Returning with all locations: ".Dumper($all_locations)."\n";

       $c->stash->{rest} = { data => $all_locations };

   }

   sub store_location :Path("/ajax/location/store") Args(0) {
       my $self = shift;
       my $c = shift;
       my $params = $c->request->parameters();
       my $id = $params->{id};
       my $name = $params->{name};
       my $abbreviation =  $params->{abbreviation};
       my $country_name =  $params->{country_name};
       my $country_code =  $params->{country_code};
       my $type =  $params->{type};
       my $latitude    = $params->{latitude};
       my $longitude   = $params->{longitude};
       my $altitude    = $params->{altitude};

       if (! $c->user()) {
           $c->stash->{rest} = { error => 'You must be logged in to add or edit a location.' };
           return;
       }

       if (! $c->user->check_roles("submitter") && !$c->user->check_roles("curator")) {
           $c->stash->{rest} = { error => 'You do not have the necessary privileges to add or edit locations.' };
           return;
       }

       my $location = CXGN::Location->new( {
           bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
           nd_geolocation_id => $id || undef,
           name => $name,
           abbreviation => $abbreviation,
           country_name => $country_name,
           country_code => $country_code,
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
           $c->stash->{rest} = { success => $store->{'success'} };
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


1;
