=head1 NAME

SGN::Controller::BreedingProgram - Catalyst controller for the Breeding Program page


=cut

package SGN::Controller::BreedingProgram;

use Moose;

use Data::Dumper;
use CXGN::BreedingProgram ; # the BP object
use SGN::Model::Cvterm; # maybe need this for the projectprop.type_id breeding_program
use URI::FromHash 'uri';
use JSON;
use List::Util qw| any|;

##use CXGN::People::Roles;


BEGIN { extends 'Catalyst::Controller' }
with 'Catalyst::Component::ApplicationAttribute';

has 'schema' => (
    is       => 'rw',
    isa      => 'DBIx::Class::Schema',
    lazy_build => 1,
);
sub _build_schema {
    shift->_app->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado' )
}

sub get_breeding_program : Chained('/') PathPart('breeders/program') CaptureArgs(1) {
    my ($self, $c, $program_id) = @_;

    my $schema = $self->schema;

    if (my $message = $c->stash->{access}->denied($c->stash->{user_id}, "read", "breeding_programs")) {
	$c->stash->{template} = '/access/access_denied.mas';
        $c->stash->{data_type} = 'breeding program';
        $c->stash->{message} = $message;
        $c->detach();
    }

    # check if the user has restricted breeding program access
    #
    my @user_breeding_programs;
    my $p =  $c->stash->{access}->user_privileges($c->stash->{user_id}, "breeding_programs");
    if (exists($p->{read})) {
        if ($p->{read}->{require_breeding_program}) {
            print STDERR "Requiring breeding program for reading, so limiting programs to user programs...\n";
            @user_breeding_programs = $c->stash->{access}->get_breeding_program_ids_for_user($c->stash->{user_id});
	    
	    my @user_breeding_program_ids = map { $_->[0] } @user_breeding_programs;
	    print STDERR "USER BREEDING PROGRAMS: ".Dumper(\@user_breeding_programs);

	    if (! (any { $_ eq $program_id } @user_breeding_program_ids)) {
			$c->stash->{template} = '/access/access_denied.mas';
			$c->stash->{data_type} = 'certain breeding program';
			$c->stash->{message} = "You do not have access to this breeding program or it does not exist.";
			$c->detach();
	    }
	}
    }
    
    
    
    my $program;
    eval {
	$program = CXGN::BreedingProgram->new( { schema=> $schema , program_id => $program_id } );
    };
    if ($@) {
	$c->stash->{template} = 'system_message.mas';
	$c->stash->{message} = "The requested breeding program ($program_id) does not exist";
	return;
    }

    $c->stash->{user} = $c->user();
    $c->stash->{program} = $program;
}


sub program_info : Chained('get_breeding_program') PathPart('') Args(0) {
    my $self = shift;
    my $c = shift;
    #my $user = $c->user();

    #$c->stash->{user_can_modify} = ($user->check_roles("submitter") || $user->check_roles("curator")) ;

    my $program = $c->stash->{program};

    if (!$program) {
	$c->stash->{message} = "The requested breeding program does not exist, has been deleted, or the object of the identifier not a breeding program.";
	$c->stash->{template} = 'generic_message.mas';
	return;
    }
    $c->stash->{template} = '/breeders_toolbox/breeding_program.mas';

}


sub profile_detail : Path('/profile') Args(1) {
    my $self = shift;
    my $c = shift;
    my $profile_id = shift;
    my $schema = $self->schema;
    my $profile_json_type_id = SGN::Model::Cvterm->get_cvterm_row($c->dbic_schema("Bio::Chado::Schema"), 'product_profile_json', 'project_property')->cvterm_id();
    my $profile_rs = $schema->resultset("Project::Projectprop")->search({ projectprop_id => $profile_id, type_id => $profile_json_type_id });

    if (!$profile_rs) {
        $c->stash->{message} = 'The requested profile does not exist.';
    }

    my $profile_row = $profile_rs->next();
    my $profile_detail_string = $profile_row->value();

    my $profile_detail_hash = decode_json $profile_detail_string;
    my $profile_name = $profile_detail_hash->{'product_profile_name'};

    $c->stash->{profile_name} = $profile_name;
    $c->stash->{user_id} = $c->user ? $c->user->get_object()->get_sp_person_id() : undef;
    $c->stash->{profile_id} = $profile_id;
    $c->stash->{template} = '/breeders_toolbox/program/profile_detail.mas';

}



__PACKAGE__->meta->make_immutable;

1;
