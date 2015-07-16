package SGN::Controller::Calendar;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

#this function maps the url /cassbasetest/test_page/ to test_page.mas
sub test_page :Path('/calendar/test_page/') :Args(0) { 
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/calendar/test_page.mas';
    $c->stash->{static_content_path} = $c->config->{static_content_path};
}


1;
