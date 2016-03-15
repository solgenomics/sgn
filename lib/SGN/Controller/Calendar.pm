
package SGN::Controller::Calendar;

use Moose;

use Data::Dumper;


use CXGN::Calendar;
use SGN::Model::Cvterm;

BEGIN { extends 'Catalyst::Controller'; }


sub personal_calendar :Path('/calendar/personal/') :Args(0) { 
    my $self = shift;
    my $c = shift;

    my $breeding_programs = CXGN::Calendar->get_breeding_program_roles();

    $c->stash->{roles} = $breeding_programs;
    $c->stash->{template} = '/calendar/personal.mas';
}

1;
