package SimulateC;

use Moose;

use Catalyst::Authentication::User;
use CXGN::People::Person;

has 'dbh' => ( isa => 'Ref',
	       is  => 'rw',
	       required => 1,
    );

has 'sp_person_id' => ( isa => 'Int',
			is  => 'rw',
			required => 1,
    );

has 'user' => ( isa => 'Object',
		is => 'rw',

    );

has 'bcs_schema' => (isa => 'Bio::Chado::Schema',
		     is => 'rw',
		     required => 1,
    );

has 'metadata_schema' => (isa => 'CXGN::Metadata::Schema',
			  is => 'rw',
    );

has 'phenome_schema' => ( isa => 'CXGN::Phenome::Schema',
			  is => 'rw',
    );

has 'sgn_schema' => ( isa => 'SGN::Schema',
		      is => 'rw',
    );

sub BUILD { 
    my $self = shift;
    my $args = shift;
    my $catalyst_user = Catalyst::Authentication::User->new();
    my $sgn_user = CXGN::People::Person->new($args->{dbh}, $args->{sp_person_id});
    $catalyst_user->set_object($sgn_user);
    $self->user($catalyst_user);

}


1;

sub dbic_schema { 
    my $self = shift;
    my $name = shift;
    
    if ($name eq 'Bio::Chado::Schema') { 
	return $self->bcs_schema();
    }
    if ($name eq 'CXGN::Phenome::Schema') { 
	return $self->phenome_schema();
    }
    if ($name eq 'SGN::Schema') { 
	return $self->sgn_schema();
    }
    if ($name eq 'CXGN::Metadata::Schema') { 
	return $self->metadata_schema();
    }
   
    return undef;
}
