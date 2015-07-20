
=head1 NAME

SGN::Controller::AJAX::Calendar - a REST controller class to provide the
backend for displaying events on the calendar

=head1 DESCRIPTION

The FullCalendar Event call sends a GET request with a start, end, and _ value. These values can be used to query specific date ranges. 
Using REST, json values for FullCalendar Event Object properties can be sent to be displayed, simply by stash->{rest}

=head1 AUTHOR

Nicolas Morales <nm529@cornell.edu>

=cut


package SGN::Controller::AJAX::Calendar;

use strict;
use Moose;
use JSON;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub get_calendar_events : Path('/ajax/calendar/populate') : ActionClass('REST') { }

sub get_calendar_events_GET { 
    my $self = shift;
    my $c = shift;
    my $start = $c->req->param("start");
    my $end = $c->req->param("end");

    #cvterm names of interest:  "project year", "project fertilizer date", "project planting date"

    my $q = "SELECT c.name, a.value, b.name FROM ((projectprop as a INNER JOIN cvterm as b on (a.type_id=b.cvterm_id)) INNER JOIN project as c on (a.project_id=c.project_id)) WHERE b.name='project planting date'";
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute();

    my @results;
    while (my ($project_name, $project_date, $project_prop) = $sth->fetchrow_array ) {
	push(@results, {title=>$project_name, property=>$project_prop, start=>$project_date});
    }

    #Add some dummy test values. The dates retrieved from database are not formatted like YYYY-MM-DD, which the FullCalendar requires
    push(@results, {title=>"Populate Test 1", property=>"Test Date", start=>"2015-07-16"});
    push(@results, {title=>"Populate Test 2", property=>"Test Date", start=>"2015-07-10"});
    $c->stash->{rest} = \@results;

}

1;
