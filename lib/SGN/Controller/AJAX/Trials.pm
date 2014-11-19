
package SGN::Controller::AJAX::Trials;

use Moose;

use CXGN::BreedersToolbox::Projects;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );



sub get_trials : Path('/ajax/breeders/get_trials') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $p = CXGN::BreedersToolbox::Projects->new( { schema => $c->dbic_schema("Bio::Chado::Schema") } );

    my $projects = $p->get_breeding_programs();

    my %data = ();
    foreach my $project (@$projects) { 
	my $trials = $p->get_trials_by_breeding_program($project->[0]);
	$data{$project->[1]} = $trials;

    }

    $c->stash->{rest} = \%data;
    

}
