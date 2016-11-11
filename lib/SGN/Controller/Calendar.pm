
package SGN::Controller::Calendar;

use Moose;

use Data::Dumper;


use CXGN::Calendar;
use CXGN::People::Roles;
use SGN::Model::Cvterm;
use URI::FromHash 'uri';

BEGIN { extends 'Catalyst::Controller'; }


sub personal_calendar :Path('/calendar/personal/') :Args(0) { 
    my $self = shift;
    my $c = shift;
    my $user = $c->user();
    if (!$user) {
        $c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    $c->stash->{user_can_add_roles} = $user->check_roles("curator");

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $person_roles = CXGN::People::Roles->new({ bcs_schema=>$schema });
    my $breeding_programs = $person_roles->get_breeding_program_roles();

    $c->stash->{roles} = $breeding_programs;
    $c->stash->{template} = '/calendar/personal.mas';
}

1;
