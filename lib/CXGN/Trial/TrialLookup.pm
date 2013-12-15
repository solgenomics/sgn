package CXGN::Trial::TrialLookup;

=head1 NAME

CXGN::Trial::TrialLookup - a module to lookup geolocations by name.


=head1 USAGE

 my $trial_lookup = CXGN::Trial::TrialLookup->new({ schema => $schema, trial_name => $trial_name} );


=head1 DESCRIPTION

Looks up trials ("Project::Project") by name. Provides the Project::Project object when a trial name matches.

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
has 'trial_name' => (isa => 'Str', is => 'rw', predicate => 'has_trial_name', clearer => 'clear_trial_name');

sub get_trial {
  my $self = shift;
  my $schema = $self->get_schema();
  my $trial;
  if (!$self->has_trial_name()){
    return;
  }
  my $trial_name = $self->get_trial_name;
  $trial = $schema->resultset("Project::Project")
    ->find({
	    name => $trial_name,
	   });
  if (!$trial) {
    print STDERR "The trial $trial_name was not found\n";
    return;
  }
  return $trial;
}


#######
1;
#######
