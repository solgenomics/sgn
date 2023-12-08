
package SGN::Controller::AJAX::Access;

use Moose;
use CXGN::Access;


BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub access :Path('/ajax/access/privileges/') :Args(2) {
    my $self = shift;
    my $c = shift;
    my $resource = shift;
    my $role = shift;

    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $access = CXGN::Access->new( { people_schema => $people_schema });

    my @privileges = $access -> check_role($role, $resource);

    $c->stash->{rest} = { privileges => \@privileges };
}

sub access_by_user :Path('/ajax/access/by_user_id/') :Args(1) {
    my $self = shift;
    my $c = shift;
    my $resource = shift;

    my $sp_person_id;
    if (!$c->user()) {
	print STDERR "Not logged in!\n";
	$sp_person_id = undef;
    }
    else {
        $sp_person_id = $c->user()->get_object()->get_sp_person_id();
    }
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $access = CXGN::Access->new( { people_schema => $people_schema });

    my @privileges = $access -> check_user($resource, $sp_person_id);

    $c->stash->{rest} = { privileges => \@privileges };
}



1;
