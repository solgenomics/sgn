
=head1 NAME

SGN::Controller::AJAX::Calendar - a REST controller class to provide the
backend for displaying events on the calendar

=head1 DESCRIPTION

The FullCalendar Event call sends a GET request with a start, end, and _ value. These values can be used to query specific date ranges. 
Using REST, json values for FullCalendar Event Object properties can be sent to be displayed, simply by stash->{rest}

Currently maps to Cassbase Mason jquery calls

=head1 AUTHOR

Nicolas Morales <nm529@cornell.edu>

=cut


package SGN::Controller::AJAX::Calendar;

use strict;
use Moose;
use JSON;
use Time::Piece ();
use Time::Seconds;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub get_calendar_events : Path('/ajax/calendar/populate') : ActionClass('REST') { }

#when the calendar is loaded and when controls (such as next month or year) are used, this function is called to get date data
sub get_calendar_events_GET { 
    my $self = shift;
    my $c = shift;
    my $start = $c->req->param("start");
    my $end = $c->req->param("end");

    #cvterm names of interest:  "project year", "project fertilizer date", "project planting date"
    my $q = "SELECT a.projectprop_id, c.name, a.value, b.name FROM ((projectprop as a INNER JOIN cvterm as b on (a.type_id=b.cvterm_id)) INNER JOIN project as c on (a.project_id=c.project_id)) WHERE b.name='project planting date' or b.name='project fertilizer date'";
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute();
    my @results;
    while (my ($projectprop_id, $project_name, $project_date, $project_prop) = $sth->fetchrow_array ) {
	push(@results, {projectprop_id=>$projectprop_id, title=>$project_name, property=>$project_prop, start=>$project_date, save=>$project_date});
    }
    $c->stash->{rest} = \@results;
}

sub drag_events : Path('/ajax/calendar/drag') : ActionClass('REST') { }

#when an event is dragged to a new data, this function is called to save the new date in the databae.
sub drag_events_POST { 
    my $self = shift;
    my $c = shift;
    my $start = $c->req->param("save");
    my $projectprop_id = $c->req->param("projectprop_id");
    my $delta = $c->req->param("delta");
    my $dt;

    # regular expressions are used to try to decipher the date format
    if ($start =~ /^\d{4}-\d\d-\d\d$/) {
	$dt = Time::Piece->strptime($start, '%Y-%m-%d');
    }
    if ($start =~ /^(3[0-1]|2[0-9]|1[0-9]|0[1-9])[\s{1}|\/|-](Jan|JAN|Feb|FEB|Mar|MAR|Apr|APR|May|MAY|Jun|JUN|Jul|JUL|Aug|AUG|Sep|SEP|Oct|OCT|Nov|NOV|Dec|DEC)[\s{1}|\/|-]\d{4}$/) {
	$dt = Time::Piece->strptime($start, '%d-%b-%Y');
    }
    if ($start =~ /^\d{4}[\s{1}|\/|-](Jan|JAN|Feb|FEB|Mar|MAR|Apr|APR|May|MAY|Jun|JUN|Jul|JUL|Aug|AUG|Sep|SEP|Oct|OCT|Nov|NOV|Dec|DEC)[\s{1}|\/|-](3[0-1]|2[0-9]|1[0-9]|0[1-9])$/) {
	$dt = Time::Piece->strptime($start, '%Y-%b-%d');
    }
    $dt += ONE_DAY * $delta;
    my $newdate = $dt->strftime('%Y-%b-%d');
    my $q = "UPDATE projectprop SET value = ? WHERE projectprop_id = ?";
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute($newdate, $projectprop_id);
    $c->stash->{rest} = {success => "1",};
}

sub add_event : Path('/ajax/calendar/add_event') : ActionClass('REST') { }

#when an event is added using the day_dialog_add_event_form, this function is called to save it to the database.
sub add_event_POST { 
    my $self = shift;
    my $c = shift;
    my $project_id = $c->req->param("event_project");
    my $cvterm_id = $c->req->param("event_type");
    my $date = $c->req->param("event_start");

    #Check if the projectprop unique (project_id, type_id, rank) constraint will cause the insert to fail.
    my $count = $c->dbc->dbh->selectrow_array("SELECT count(projectprop_id) FROM projectprop WHERE project_id='$project_id' and type_id='$cvterm_id' and rank='0'");
    if ($count == 0) {
      my $q = "INSERT INTO projectprop (project_id, type_id, value) VALUES (?, ?, ?)";
      my $sth = $c->dbc->dbh->prepare($q);
      if ($sth->execute($project_id, $cvterm_id, $date)) {
	  $c->stash->{rest} = {status => 1,};
      } else {
	  $c->stash->{rest} = {status => 2,};
      }
    } else {
      $c->stash->{rest} = {status => 0,};
    }
}

sub delete_event : Path('/ajax/calendar/delete_event') : ActionClass('REST') { }

#when an event is added using the day_dialog_add_event_form, this function is called to save it to the database.
sub delete_event_POST { 
    my $self = shift;
    my $c = shift;
    my $projectprop_id = $c->req->param("event_projectprop_id");
    my $q = "DELETE FROM projectprop WHERE projectprop_id=?";
    my $sth = $c->dbc->dbh->prepare($q);
    if ($sth->execute($projectprop_id)) {
	$c->stash->{rest} = {status => 1,};
    } else {
	$c->stash->{rest} = {status => 0,};
    }
}

1;
