
=head1 NAME

SGN::Controller::Calendar - a controller class to handle calendar related methods, such as editing, viewing, modifying, deleting, and adding of events.

=head1 DESCRIPTION

For display and processing of calendar. AJAX calendar requests are located in SGN::Controller::AJAX::Calendar

Currently maps to Cassbase mason files

=head1 AUTHOR

Nicolas Morales <nm529@cornell.edu>

=cut


package SGN::Controller::Calendar;

use Moose;
use JSON;

BEGIN { extends 'Catalyst::Controller'; }

#this function maps the url /calender/test_page/ to test_page.mas
sub test_page :Path('/calendar/test_page/') :Args(0) { 
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/calendar/test_page.mas';
    $c->stash->{static_content_path} = $c->config->{static_content_path};
}


1;
