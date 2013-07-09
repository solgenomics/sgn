package CXGN::Location::LocationLookup;

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
