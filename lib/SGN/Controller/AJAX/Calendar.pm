
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
	[{'type.name'=>'project planting date'}, {'type.name'=>'project fertilizer date'}],
	{join=>{'projectprops'=>'type'},
	'+select'=> ['projectprops.projectprop_id', 'type.name', 'projectprops.value', 'type.cvterm_id'],
	'+as'=> ['pp_id', 'cv_name', 'pp_value', 'cv_id'],
	}
    );
    my @events;
    my $display_date;
    my $allday;
    while (my $result = $search_rs->next) {
	my $formatted_time = format_time($result->get_column('pp_value'));
	my $save_time = $formatted_time->datetime;
	if ($formatted_time->hms('') == '000000') {
	    $display_date = $formatted_time->strftime("%Y-%m-%d");
	    $allday = 1;
	} else {
	    $display_date = $formatted_time->strftime("%Y-%m-%d %H:%M:%S");
	    $allday = 0;
	}
	push(@events, {projectprop_id=>$result->get_column('pp_id'), title=>$result->name, property=>$result->get_column('cv_name'), start=>$save_time, save=>$save_time, display_date=>$display_date, project_id=>$result->project_id, project_url=>'/breeders_toolbox/trial/'.$result->project_id.'/', cvterm_url=>'/chado/cvterm?cvterm_id='.$result->get_column('cv_id'), allDay=>$allday});
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
    $formatted_datetime += $delta;
    my $newdate = Time::Piece->strptime($formatted_datetime, '%s')->datetime;
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    if (my $update_rs = $schema->resultset('Project::Projectprop')->find({projectprop_id=>$projectprop_id}, columns=>['value'])->update({value=>$newdate})) {
	$c->stash->{rest} = {success => 1, save=> $newdate};
    } else {
	$c->stash->{rest} = {error => 1,};
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
    my $format_date = format_time($date)->datetime;

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

#when an event is deleted using the day_dialog_delete_event_form, this function is called to delete it from the database.
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

#This function is used to return a Time::Piece object, which is useful for format consistensy.
#Reformat all dates in projectprop table to datetime ISO8601 format.
#Update projectprop set value='2007-09-21T00:00:00' where project_id='149' and type_id='76773'; Update projectprop set value='2007-08-10T00:00:00' where project_id='149' and type_id='76772'; Update projectprop set value='2008-06-04T00:00:00' where project_id='150' and type_id='76773'; Update projectprop set value='2008-04-23T00:00:00' where project_id='150' and type_id='76772'; Update projectprop set value='2010-08-12T00:00:00' where project_id='159' and type_id='76772'; Update projectprop set value='2011-08-04T00:00:00' where project_id='160' and type_id='76772'; Update projectprop set value='2010-08-11T00:00:00' where project_id='156' and type_id='76772'; Update projectprop set value='2012-04-28T00:00:00' where project_id='143' and type_id='76772'; Update projectprop set value='2008-05-15T00:00:00' where project_id='152' and type_id='76772'; Update projectprop set value='2008-06-25T00:00:00' where project_id='152' and type_id='76773'; Update projectprop set value='2006-02-01T00:00:00' where project_id='146' and type_id='76772'; Update projectprop set value='2006-12-08T00:00:00' where project_id='148' and type_id='76772'; Update projectprop set value='2007-01-20T00:00:00' where project_id='148' and type_id='76773'; Update projectprop set value='2006-05-02T00:00:00' where project_id='147' and type_id='76772'; Update projectprop set value='2006-07-02T00:00:00' where project_id='147' and type_id='76773'; Update projectprop set value='2008-04-29T00:00:00' where project_id='151' and type_id='76772'; Update projectprop set value='2008-06-10T00:00:00' where project_id='151' and type_id='76773'; Update projectprop set value='2011-08-08T00:00:00' where project_id='155' and type_id='76772'; Update projectprop set value='2011-10-21T00:00:00' where project_id='155' and type_id='76773'; Update projectprop set value='2011-09-28T00:00:00' where project_id='133' and type_id='76772'; Update projectprop set value='2011-06-24T00:00:00' where project_id='133' and type_id='76773'; Update projectprop set value='2011-06-01T00:00:00' where project_id='145' and type_id='76772'; Update projectprop set value='2011-08-10T00:00:00' where project_id='145' and type_id='76773'; Update projectprop set value='2010-08-12T00:00:00' where project_id='158' and type_id='76772'; Update projectprop set value='2010-05-07T00:00:00' where project_id='132' and type_id='76772'; Update projectprop set value='2010-06-06T00:00:00' where project_id='136' and type_id='76772'; Update projectprop set value='2010-05-18T00:00:00' where project_id='135' and type_id='76772'; Update projectprop set value='2010-07-28T00:00:00' where project_id='135' and type_id='76773';
sub format_time {
    my $input_time = shift;
    my $formatted_time;
    #print STDERR $input_time;
    if ($input_time =~ /^\d{4}-\d\d-\d\d$/) {
	$formatted_time = Time::Piece->strptime($input_time, '%Y-%m-%d');
    }
    if ($input_time =~ /(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})$/) {
	$formatted_time = Time::Piece->strptime($input_time, '%Y-%m-%dT%H:%M:%S');
    }
    return $formatted_time;
}

1;
