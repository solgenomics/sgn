
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
use Time::Piece;
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
    my $search_rs = $schema->resultset('Project::Project')->search(
	#[{'type.name'=>'project planting date'}, {'type.name'=>'project fertilizer date'}],
	{'type.name'=>'project fertilizer date'},
	{join=>{'projectprops'=>'type'},
	'+select'=> ['projectprops.projectprop_id', 'type.name', 'projectprops.value', 'type.cvterm_id'],
	'+as'=> ['pp_id', 'cv_name', 'pp_value', 'cv_id'],
	}
    );
    my @events;
    while (my $result = $search_rs->next) {
	my $formatted_datetime = format_time($result->get_column('pp_value'))->datetime;
	push(@events, {projectprop_id=>$result->get_column('pp_id'), title=>$result->name, property=>$result->get_column('cv_name'), start=>$formatted_datetime, save=>$formatted_datetime, project_id=>$result->project_id, project_url=>'/breeders_toolbox/trial/'.$result->project_id.'/', cvterm_url=>'/chado/cvterm?cvterm_id='.$result->get_column('cv_id'), allDay=>'true'});
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
    my $formatted_datetime = format_time($start)->epoch;
    print STDERR "formatteddatetime".$formatted_datetime;
    $formatted_datetime += $delta;
    my $newdate = Time::Piece->strptime($formatted_datetime, '%s')->datetime;
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    if (my $update_rs = $schema->resultset('Project::Projectprop')->find({projectprop_id=>$projectprop_id}, columns=>['value'])->update({value=>$newdate})) {
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
    my $result_set = $c->dbic_schema('Bio::Chado::Schema')->resultset('Project::Projectprop');
    my $count = $result_set->search({project_id=>$project_id, type_id=>$cvterm_id, rank=>0})->count;
    if ($count == 0) {
      if (my $insert = $result_set->create({project_id=>$project_id, type_id=>$cvterm_id, value=>$format_date})) {
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

    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    if (my $delete = $schema->resultset('Project::Projectprop')->find({projectprop_id=>$projectprop_id})->delete) {
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
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $search_rs = $schema->resultset('Project::Projectprop')->search(
	{'me.project_id'=>$project_id},
	{join=>'type',
	'+select'=> ['type.name', 'type.cvterm_id'],
	'+as'=> ['cv_name', 'cv_id'],
	}
    );
    my @project_properties;
    while (my $result = $search_rs->next) {
	push(@project_properties, {property=>$result->get_column('cv_name'), value=>$result->value, cvterm_url=>'/chado/cvterm?cvterm_id='.$result->get_column('cv_id')});
    }
    $c->stash->{rest} = {data=>\@project_properties};
}

sub event_more_info_relationships : Path('/ajax/calendar/more_info_relationships') : ActionClass('REST') { }

#when the event_dialog_more_info_form is submitted, this function is called to retrieve all relationships for that project.
sub event_more_info_relationships_POST { 
    my $self = shift;
    my $c = shift;
    my $project_id = $c->req->param("event_project_id");
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $search_rs = $schema->resultset('Project::ProjectRelationship')->search(
	{'me.subject_project_id'=>$project_id},
	{join=>['type','object_project'],
	'+select'=> ['type.name', 'type.cvterm_id', 'object_project.name'],
	'+as'=> ['cv_name', 'cv_id', 'op_name'],
	}
    );
    my @project_relationships;
    while (my $result = $search_rs->next) {
  	push(@project_relationships, {object_project=>$result->get_column('op_name'), cvterm=>$result->get_column('cv_name'), cvterm_url=>'/chado/cvterm?cvterm_id='.$result->get_column('cv_id')});
    }
    $c->stash->{rest} = {data=>\@project_relationships};
}

sub datatables_project_properties : Path('/ajax/calendar/datatables_project_properties') : ActionClass('REST') { }

#this fills the datatable #project_dates_data at the bottom of the test_page.
sub datatables_project_properties_GET { 
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $search_rs = $schema->resultset('Project::Project')->search(undef,
	{join=>{'projectprops'=>'type'},
	'+select'=> ['projectprops.projectprop_id', 'type.name', 'projectprops.value', 'type.cvterm_id'],
	'+as'=> ['pp_id', 'cv_name', 'pp_value', 'cv_id'],
	}
    );
    my @project_properties;
    while (my $result = $search_rs->next) {
	push(@project_properties, {title=>$result->name, property=>$result->get_column('cv_name'), value=>$result->get_column('pp_value'), project_url=>'/breeders_toolbox/trial/'.$result->project_id.'/', cvterm_url=>'/chado/cvterm?cvterm_id='.$result->get_column('cv_id')});
    }
    $c->stash->{rest} = {aaData=>\@project_properties};
}

sub datatables_project_relationships : Path('/ajax/calendar/datatables_project_relationships') : ActionClass('REST') { }

#this fills the datatable #project_relationships_data at thebottom of the test_page.
sub datatables_project_relationships_GET { 
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $search_rs = $schema->resultset('Project::ProjectRelationship')->search(undef,
	{join=>['type','object_project','subject_project'],
	'+select'=> ['type.name', 'type.cvterm_id', 'object_project.name', 'subject_project.name'],
	'+as'=> ['cv_name', 'cv_id', 'op_name', 'sp_name'],
	}
    );
    my @project_relationships;
    while (my $result = $search_rs->next) {
      push(@project_relationships, {relationship_type=>$result->get_column('cv_name'), subject_project=>$result->get_column('sp_name'), object_project=>$result->get_column('op_name'), subject_project_url=>'/breeders_toolbox/trial/'.$result->subject_project_id.'/', object_project_url=>'/breeders_toolbox/trial/'.$result->object_project_id.'/', cvterm_url=>"/chado/cvterm?cvterm_id=".$result->get_column('cv_id')});
    }
    $c->stash->{rest} = {aaData=>\@project_relationships};
}

#This function is used to return a Time::Piece object, which is useful for format consistensy. This function can take a variety of input formats.
sub format_time {
    my $input_time = shift;
    my $formatted_time;
    print STDERR $input_time;
    #if ($input_time =~ /^\d{4}-\d\d-\d\d$/) {
	#$formatted_time = Time::Piece->strptime($input_time, '%Y-%m-%d');
    #}
    #if ($input_time =~ /^(3[0-1]|2[0-9]|1[0-9]|0[1-9])[\s{1}|\/|-](Jan|JAN|January|Feb|FEB|February|Mar|MAR|March|Apr|APR|April|May|MAY|Jun|JUN|June|Jul|JUL|July|Aug|AUG|August|Sep|SEP|Sept|September|Oct|OCT|October|Nov|NOV|November|Dec|DEC|December)[\s{1}|\/|-]\d{4}$/) {
	#$formatted_time = Time::Piece->strptime($input_time, '%d-%b-%Y');
    #}
    if ($input_time =~ /^\d{4}[\s{1}|\/|-](January|February|March|April|May|June|July|August|September|October|November|December)[\s{1}|\/|-](3[0-1]|2[0-9]|1[0-9]|0[1-9])$/) {
	$formatted_time = Time::Piece->strptime($input_time, '%Y-%B-%d');
    }
    if ($input_time =~ /^\d{4}[\s{1}|\/|-](Jan|JAN|Feb|FEB|Mar|MAR|Apr|APR|May|MAY|Jun|JUN|Jul|JUL|Aug|AUG|Sep|SEP|Oct|OCT|Nov|NOV|Dec|DEC)[\s{1}|\/|-](3[0-1]|2[0-9]|1[0-9]|0[1-9])$/) {
	$formatted_time = Time::Piece->strptime($input_time, '%Y-%b-%d');
    }
    if ($input_time =~ /(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})$/) {
	$formatted_time = Time::Piece->strptime($input_time, '%Y-%m-%dT%H:%M:%S');
    }
    print STDERR $formatted_time.'TT';
    return $formatted_time;
}

1;
