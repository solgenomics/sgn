
package SGN::Controller::BreedingProgram;

=head1 NAME

SGN::Controller::BreedingProgram - Catalyst controller for the Breeding Program page


=cut
use Moose;

use Data::Dumper;
use CXGN::BreedingProgram ; # the BP object
use SGN::Model::Cvterm; # maybe need this for the projectprop.type_id breeding_program
use URI::FromHash 'uri';

##use CXGN::People::Roles;


BEGIN { extends 'Catalyst::Controller'; }



sub get_breeding_program : Chained('/') PathPart('breeders/program') CaptureArgs(1) {
    my ($self, $c, $program_id) = @_;
    
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    
    my $program;
    eval { 
	$program = CXGN::BreedingProgram->new( { schema=> $schema , program_id => $program_id } );
	print STDERR "^^^^^^^^^^^^^^^^NEW PROGRAM $program_id\n\n";
    };
    if ($@) {
	print STDERR "********ERRRR $@\n\n";
	$c->stash->{template} = 'system_message.txt';
	$c->stash->{message} = "The requested breeding program ($program_id) does not exist";
	return;
    } 
    print STDERR "*************GET BREEDING PROGRAM :: $program_id\n\n";
    $c->stash->{user} = $c->user();
    $c->stash->{program} = $program;
}


sub program_info : Chained('get_breeding_program') PathPart('') Args(0) {
    my $self = shift;
    my $c = shift;
    my $user = $c->user();
    
    $c->stash->{user_can_modify} = ($user->check_roles("submitter") || $user->check_roles("curator")) ;

    my $program = $c->stash->{program};
    print STDERR "************* PROGRAM INFO :: $program \n\n";

    if (!$program) {
	$c->stash->{message} = "The requested breeding program does not exist or has been deleted.";
	$c->stash->{template} = 'generic_message.mas';
	return;
    }
    $c->stash->{template} = '/breeders_toolbox/breeding_program.mas';
    
}

1;
