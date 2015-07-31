
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
use Data::Dumper;

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

    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $search_rs = $schema->resultset('Cv::Cvterm')->search(
	[{'me.name'=>'project planting date'}, {'me.name'=>'project fertilizer date'}],
	{join=>{'projectprops'=>'project'},
	'+select'=> ['projectprops.projectprop_id', 'project.name', 'projectprops.value', 'project.project_id'],
	'+as'=> ['pp_id', 'p_name', 'pp_value', 'p_id'],
	}
    );
    my @events;
    while (my $result = $search_rs->next) {
	push(@events, {projectprop_id=>$result->get_column('pp_id'), title=>$result->get_column('p_name'), property=>$result->name, start=>$result->get_column('pp_value'), save=>$result->get_column('pp_value'), project_id=>$result->get_column('p_id'), project_url=>'/breeders_toolbox/trial/'.$result->get_column('p_id').'/', cvterm_url=>'/chado/cvterm?cvterm_id='.$result->cvterm_id});
    }
    $c->stash->{rest} = \@events;
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
    my $newdate = $dt->strftime('%Y-%b-%d'); #2015-Jul-01
    my $q = "UPDATE projectprop SET value = ? WHERE projectprop_id = ?";
    my $sth = $c->dbc->dbh->prepare($q);
    if ($sth->execute($newdate, $projectprop_id)) {
	$c->stash->{rest} = {success => "1", save=> $newdate};
    } else {
	$c->stash->{rest} = {error => "1",};
    }
}

sub add_event : Path('/ajax/calendar/add_event') : ActionClass('REST') { }

#when an event is added using the day_dialog_add_event_form, this function is called to save it to the database.
sub add_event_POST { 
    my $self = shift;
    my $c = shift;
    my $project_id = $c->req->param("event_project");
    my $cvterm_id = $c->req->param("event_type");
    my $date = $c->req->param("event_start");
    my $check_date;

    # regular expressions are used to try to decipher the date format
    if ($date =~ /^\d{4}-\d\d-\d\d$/) {
	$check_date = Time::Piece->strptime($date, '%Y-%m-%d');
    }
    my $format_date = $check_date->strftime('%Y-%b-%d'); #2015-Jul-01

    #Check if the projectprop unique (project_id, type_id, rank) constraint will cause the insert to fail.
    my $count = $c->dbc->dbh->selectrow_array("SELECT count(projectprop_id) FROM projectprop WHERE project_id='$project_id' and type_id='$cvterm_id' and rank='0'");
    if ($count == 0) {
      my $q = "INSERT INTO projectprop (project_id, type_id, value) VALUES (?, ?, ?)";
      my $sth = $c->dbc->dbh->prepare($q);
      if ($sth->execute($project_id, $cvterm_id, $format_date)) {
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

sub event_more_info : Path('/ajax/calendar/more_info_properties') : ActionClass('REST') { }

#when the event_dialog_more_info_form is submitted, this function is called to retrieve all other projectprops for that project and also to display the project_relationships.
sub event_more_info_POST { 
    my $self = shift;
    my $c = shift;
    my $project_id = $c->req->param("event_project_id");
    my $q = "SELECT a.projectprop_id, c.name, a.value, b.name, c.project_id, b.cvterm_id FROM ((projectprop as a INNER JOIN cvterm as b on (a.type_id=b.cvterm_id)) INNER JOIN project as c on (a.project_id=c.project_id)) WHERE a.project_id='$project_id'";
    my $sth = $c->dbc->dbh->prepare($q);
    my @project_properties;
    if ($sth->execute()) {
      while (my ($projectprop_id, $project_name, $prop_value, $project_prop, $project_id, $cvterm_id) = $sth->fetchrow_array ) {
	  push(@project_properties, {property=>$project_prop, value=>$prop_value, cvterm_url=>'/chado/cvterm?cvterm_id='.$cvterm_id});
      }
      #print STDERR Dumper(encode_json({data=>\@project_properties}));
    } else {
    }
    $c->stash->{rest} = {data=>\@project_properties};
}

sub event_more_info_relationships : Path('/ajax/calendar/more_info_relationships') : ActionClass('REST') { }

#when the event_dialog_more_info_form is submitted, this function is called to retrieve all relationships for that project.
sub event_more_info_relationships_POST { 
    my $self = shift;
    my $c = shift;
    my $project_id = $c->req->param("event_project_id");
    my $q = "SELECT b.name, a.object_project_id, d.name, b.cvterm_id FROM (((project_relationship as a INNER JOIN cvterm as b on (a.type_id=b.cvterm_id)) INNER JOIN project as c on (a.subject_project_id=c.project_id)) INNER JOIN project as d on (a.object_project_id=d.project_id)) WHERE subject_project_id='$project_id'";
    my $sth = $c->dbc->dbh->prepare($q);
    my @project_relationships;
    if ($sth->execute()) {
      while (my ($cvterm_name, $object_project_id, $object_project, $cvterm_id) = $sth->fetchrow_array ) {
  	  push(@project_relationships, {object_project=>$object_project, cvterm=>$cvterm_name, cvterm_url=>'/chado/cvterm?cvterm_id='.$cvterm_id});
      }
    } else {
    }
    $c->stash->{rest} = {data=>\@project_relationships};
}

sub datatables_project_properties : Path('/ajax/calendar/datatables_project_properties') : ActionClass('REST') { }

#this fills the datatable #project_dates_data at the bottom of the test_page.
sub datatables_project_properties_GET { 
    my $self = shift;
    my $c = shift;
    my $q = "SELECT c.name, a.value, b.name, c.project_id, b.cvterm_id FROM ((projectprop as a INNER JOIN cvterm as b on (a.type_id=b.cvterm_id)) INNER JOIN project as c on (a.project_id=c.project_id))";
    my $sth = $c->dbc->dbh->prepare($q);
    my @project_properties;
    if ($sth->execute()) {
      while (my ($project_name, $value, $project_prop, $project_id, $cvterm_id) = $sth->fetchrow_array ) {
	push(@project_properties, {title=>$project_name, property=>$project_prop, value=>$value, project_url=>'/breeders_toolbox/trial/'.$project_id.'/', cvterm_url=>"/chado/cvterm?cvterm_id=".$cvterm_id});
      }
    } else {
    }
    $c->stash->{rest} = {aaData=>\@project_properties};
}

sub datatables_project_relationships : Path('/ajax/calendar/datatables_project_relationships') : ActionClass('REST') { }

#this fills the datatable #project_relationships_data at thebottom of the test_page.
sub datatables_project_relationships_GET { 
    my $self = shift;
    my $c = shift;
    my $q = "SELECT b.name, a.subject_project_id, a.object_project_id, c.name, d.name, b.cvterm_id FROM (((project_relationship as a INNER JOIN cvterm as b on (a.type_id=b.cvterm_id)) INNER JOIN project as c on (a.subject_project_id=c.project_id)) INNER JOIN project as d on (a.object_project_id=d.project_id))";
    my $sth = $c->dbc->dbh->prepare($q);
    my @project_relationships;
    if ($sth->execute()) {
      while (my ($cvterm_name, $subject_project_id, $object_project_id, $subject_project, $object_project, $cvterm_id) = $sth->fetchrow_array ) {
	push(@project_relationships, {relationship_type=>$cvterm_name, subject_project=>$subject_project, object_project=>$object_project, subject_project_url=>'/breeders_toolbox/trial/'.$subject_project_id.'/', object_project_url=>'/breeders_toolbox/trial/'.$object_project_id.'/', cvterm_url=>"/chado/cvterm?cvterm_id=".$cvterm_id});
      }
    } else {
    }
    $c->stash->{rest} = {aaData=>\@project_relationships};
}

1;
