
=head1 NAME

SGN::Controller::AJAX::BreedingProgram  
 REST controller for viewing breeding programs and the data associated with them

=head1 DESCRIPTION


=head1 AUTHOR

Naama Menda <nm249@cornell.edu>


=cut

package SGN::Controller::AJAX::BreedingProgram;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' };

use List::MoreUtils qw | any all |;
use JSON::Any;
use Data::Dumper;
use Try::Tiny;
use CXGN::BreedingProgram;


__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
    );


=head2 action program_trials()
    
  Usage:        /breeders/program/<program_id>/datatables/trials
  Desc:         retrieves trials associated with the breeding program
  Ret:          a table in json suitable for datatables
  Args:
    Side Effects:
  Example:
    
=cut


sub ajax_breeding_program : Chained('/')  PathPart('ajax/breeders/program')  CaptureArgs(1) {
    my ($self, $c, $program_id) = @_;
    
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $program = CXGN::BreedingProgram->new( { schema=> $schema , program_id => $program_id } );

    $c->stash->{program} = $program;
    $c->stash->{trials} = $program->get_trials;
}




sub program_trials :Chained('ajax_breeding_program') PathPart('trials') Args(0) { 
    my $self = shift;
    my $c = shift;
    my $program = $c->stash->{program};
  
    my $trials = $program->get_trials();

    my @formatted_trials;
    while (my $trial = $trials->next ) {

	my $name = $trial->name;
	my $id = $trial->project_id;
	my $description = $trial->description;
        push @formatted_trials, [ '<a href="/breeders/trial/'.$id.'">'.$name.'</a>', $description ];
    }
    $c->stash->{rest} = { data => \@formatted_trials };
}



1;
