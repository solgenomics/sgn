package CXGN::Location::LocationLookup;

=head1 NAME

CXGN::Location::LocationLookup - a module to lookup geolocations by name.


=head1 USAGE

 my $location_lookup = CXGN::Location::LocationLookup->new({ schema => $schema} );


=head1 DESCRIPTION

Looks up geolocations ("NaturalDiversity::NdGeolocation") by name. Provides the NaturalDiversity::NdGeolocation object when a geolocation matches.

=head1 AUTHORS

 Jeremy D. Edwards (jde22@cornell.edu)

=cut

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;

has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 lazy_build => 1,
		);
has 'location_name' => (isa => 'Str', is => 'rw', predicate => 'has_location_name', clearer => 'clear_location_name');

sub get_geolocation {
  my $self = shift;
  my $schema = $self->get_schema();
  my $geolocation;
  if (!$self->has_location_name()){
    return;
  }
  $geolocation = $schema->resultset("NaturalDiversity::NdGeolocation")
    ->find({
	    description => $self->get_location_name(),
	   });
  return $geolocation;
}


#######
1;
#######
