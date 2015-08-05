
=head1 NAME

SGN::Controller::AJAX::Calendar - a REST controller class to provide the
backend for displaying, adding, deleting, dragging, modifying, and requesting more info about events.

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

#When the calendar is loaded and when controls (such as next month or year) are used, this function is called to get date data.
sub get_calendar_events_GET { 
    my $self = shift;
    my $c = shift;
    
    #Fullcalendar sends start and end dates for the current view on the calendar. These values currently not used in query. 
    my $start = $c->req->param("start");
    my $end = $c->req->param("end");

    #cvterm names of interest:  "project year", "project fertilizer date", "project planting date"
    #Calendar event info is retrieved using DBIx class.
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $search_rs = $schema->resultset('Project::Project')->search(
	[{'type.name'=>'project planting date'}, {'type.name'=>'project fertilizer date'}],
	{join=>{'projectprops'=>'type'},
	'+select'=> ['projectprops.projectprop_id', 'type.name', 'projectprops.value', 'type.cvterm_id'],
	'+as'=> ['pp_id', 'cv_name', 'pp_value', 'cv_id'],
	}
    );

    my @events;
    my $allday;
    my $start_time;
    my $start_drag;
    my $start_display;
    my $end_time;
    my $end_drag;
    my $end_display;
    my $formatted_time;
    my $raw_value;
    my @time_array;
    while (my $result = $search_rs->next) {

	#In the database, the start/end datetime info is stored as a string like: {"2015-08-12T00:00:00","2015-08-15T00:00:00"}. The string is then transcribed and split into an array.
	$raw_value = $result->get_column('pp_value'); 
	$raw_value =~ tr/{}"//d;
	@time_array = split(/,/, $raw_value);

	#We start with the start datetime, or the first element in the time_array.
	#A time::piece object is returned from format_date(). Calling ->datetime on this object returns an ISO8601 datetime string. This string is what is used as the calendar event's start. 
	$formatted_time = format_time($time_array[0]);
	$start_time = $formatted_time->datetime;

	#Displaying 00:00:00 time on mouseover and mouseclick is ugly, so start_display is used to determine date display format.
	if ($formatted_time->hms('') == '000000') {
	    $start_display = $formatted_time->strftime("%Y-%m-%d");
	    $allday = 1;
	} else {
	    $start_display = $formatted_time->strftime("%Y-%m-%d %H:%M:%S");
	    $allday = 0;
	}

	#Then we process the end datetime, which is the second element in the time_array.
	$formatted_time = format_time($time_array[1]);

	#Displaying 00:00:00 time on mouseover and mouseclick is ugly, so end_display is used to determine date display format. FullCalendar's end datetime in exclusive, so for a datetime with 00:00:00, a full day must be added so that it is displayed correctly on the calendar. If the end datetime has an actual time, Fullcalendar handles it correctly.
	if ($formatted_time->hms('') == '000000') {
	    $end_time = $formatted_time->epoch;
	    $end_time += ONE_DAY;
	    $end_time = Time::Piece->strptime($end_time, '%s')->datetime;
	    $end_display = $formatted_time->strftime("%Y-%m-%d");
	} else {
	    $end_time = $formatted_time->datetime;
	    $end_display = $formatted_time->strftime("%Y-%m-%d %H:%M:%S");
	}

	#Because FullCallendar's end date is exclusive, an end datetime with 00:00:00 will be displayed as one day short on the calendar, and so corrections to the event's end must be made. To facilitate event dragging, an event.end_drag property is used. 
	$end_drag = $formatted_time->datetime;

	#Variables are pushed into the event array and will become properties of Fullcalendar events, like event.start, event.cvterm_url, etc.
	push(@events, {projectprop_id=>$result->get_column('pp_id'), title=>$result->name, property=>$result->get_column('cv_name'), start=>$start_time, start_drag=>$start_time, start_display=>$start_display, end=>$end_time, end_drag=>$end_drag, end_display=>$end_display, project_id=>$result->project_id, project_url=>'/breeders_toolbox/trial/'.$result->project_id.'/', cvterm_url=>'/chado/cvterm?cvterm_id='.$result->get_column('cv_id'), allDay=>$allday});
    }
    $c->stash->{rest} = \@events;
}

sub drag_or_resize_event : Path('/ajax/calendar/drag_or_resize') : ActionClass('REST') { }

#When an event is dragged to a new date a value of drag = 1 is passed to the function. When an event is simply resized a value of drag =0 is passed to the function. This function saves the new start and end date to the db.
sub drag_or_resize_event_POST { 
    my $self = shift;
    my $c = shift;

    #variables from javascript AJAX are requested
    my $start = $c->req->param("start_drag");
    my $end = $c->req->param("end_drag");
    my $projectprop_id = $c->req->param("projectprop_id");
    my $delta = $c->req->param("delta");
    my $drag = $c->req->param("drag");

    #First we process the start datetime.
    #A time::piece object is returned from format_time(). Delta is the number of seconds that the date was changed. Calling ->epoch on the time::piece object returns a string representing number of sec since epoch.
    my $formatted_start = format_time($start)->epoch;
    
    #If the event is being dragged to a new start, then the delta is added to the start here. When resizing, the start is not changed, only the end is changed.
    if ($drag == 1) {
	$formatted_start += $delta;

	#The string representing the new number of sec since epoch is parsed into a time::piece object.
	$formatted_start = Time::Piece->strptime($formatted_start, '%s');
    } elsif ($drag == 0) {
	#The string representing the new number of sec since epoch is parsed into a time::piece object.
	$formatted_start = Time::Piece->strptime($formatted_start, '%s');
    }

    #Calling ->datetime on a time::piece object returns a string ISO8601 datetime. new_start is what is saved in db.
    my $new_start = $formatted_start->datetime;
    
    #Displaying 00:00:00 time on mouseover and mouseclick is ugly, so new_start_display is used to determine date display format.
    my $new_start_display;
    if ($formatted_start->hms('') == '000000') {
        $new_start_display = $formatted_start->strftime("%Y-%m-%d");
    } else {
	$new_start_display = $formatted_start->strftime("%Y-%m-%d %H:%M:%S");
    }
    
    #Next we process the end datetime.
    my $new_end_time;
    my $new_end_display;

    my $formatted_end = format_time($end)->epoch;
    $formatted_end += $delta;
    $formatted_end = Time::Piece->strptime($formatted_end, '%s');

    #Calling ->datetime on the time::piece object returns an ISO8601 datetime string. This is what is saved in db. 
    my $new_end = $formatted_end->datetime;

    #Displaying 00:00:00 time on mouseover and mouseclick is ugly, so new_end_display is used to determine date display format. FullCalendar's end datetime in exclusive, so for a datetime with 00:00:00, a full day must be added so that it is displayed correctly on the calendar. If the end datetime has an actual time, Fullcalendar handles it correctly.
    if ($formatted_end->hms('') == '000000') {
	$new_end_time = $formatted_end->epoch;
	$new_end_time += ONE_DAY;
	$new_end_time = Time::Piece->strptime($new_end_time, '%s')->datetime;
	$new_end_display = $formatted_end->strftime("%Y-%m-%d");
    } else {
        $new_end_time = $formatted_end->datetime;
	$new_end_display = $formatted_end->strftime("%Y-%m-%d %H:%M:%S");
    }

    #The new start and end datetimes are saved to the DB using DBIx class.
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    if (my $update_rs = $schema->resultset('Project::Projectprop')->find({projectprop_id=>$projectprop_id}, columns=>['value'])->update({value=>[$new_start, $new_end]})) {

	#If the update was successfull, data is passed back to AJAX so that the event can be properly updated.
	$c->stash->{rest} = {success => 1, start=>$new_start, start_drag=>$new_start, start_display=>$new_start_display, end=>$new_end_time, end_drag=>$new_end, end_display=>$new_end_display};
    } else {
	$c->stash->{rest} = {error => 1,};
    }
}

sub add_event : Path('/ajax/calendar/add_event') : ActionClass('REST') { }

#When an event is added using the day_dialog_add_event_form, this function is called to save it to the database.
sub add_event_POST { 
    my $self = shift;
    my $c = shift;

    #Variables sent from AJAX are requested.
    my $project_id = $c->req->param("event_project");
    my $cvterm_id = $c->req->param("event_type");
    my $start = $c->req->param("event_start");
    my $end = $c->req->param("event_end");

    #A time::piece object is returned from format_time(). Calling ->datetime on this object return an ISO8601 datetime string. This is what is saved in the db.
    my $format_start = format_time($start)->datetime;
    
    #If an event end is given, then it is converted to an ISO8601 datetime string to be saved. If none is given then '' will be saved.
    my $format_end;
    if ($end eq '') {$format_end = $format_start;} else {$format_end = format_time($end)->datetime;}
    
    #Check if the projectprop unique (project_id, type_id, rank) constraint will cause the insert to fail.
    my $result_set = $c->dbic_schema('Bio::Chado::Schema')->resultset('Project::Projectprop');
    my $count = $result_set->search({project_id=>$project_id, type_id=>$cvterm_id, rank=>0})->count;
    if ($count == 0) {

      #If there is no record already in the database, then it is created using DBIx class.
      if (my $insert = $result_set->create({project_id=>$project_id, type_id=>$cvterm_id, value=>[$format_start, $format_end]})) {
	  $c->stash->{rest} = {status => 1,};
      } else {
	  $c->stash->{rest} = {status => 2,};
      }
    } else {
      $c->stash->{rest} = {status => 0,};
    }
}

sub delete_event : Path('/ajax/calendar/delete_event') : ActionClass('REST') { }

#When an event is deleted using the day_dialog_delete_event_form, this function is called to delete it from the database.
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
#Reformat all dates in projectprop table to datetime ISO8601 format, with start and end datetimes.
#Update projectprop set value='{"2007-09-21T00:00:00","2007-09-21T00:00:00"}' where project_id='149' and type_id='76773'; Update projectprop set value='{"2007-08-10T00:00:00","2007-08-10T00:00:00"}' where project_id='149' and type_id='76772'; Update projectprop set value='{"2008-06-04T00:00:00","2008-06-04T00:00:00"}' where project_id='150' and type_id='76773'; Update projectprop set value='{"2008-04-23T00:00:00","2008-04-23T00:00:00"}' where project_id='150' and type_id='76772'; Update projectprop set value='{"2010-08-12T00:00:00","2010-08-12T00:00:00"}' where project_id='159' and type_id='76772'; Update projectprop set value='{"2011-08-04T00:00:00","2011-08-04T00:00:00"}' where project_id='160' and type_id='76772'; Update projectprop set value='{"2010-08-11T00:00:00","2010-08-11T00:00:00"}' where project_id='156' and type_id='76772'; Update projectprop set value='{"2012-04-28T00:00:00","2012-04-28T00:00:00"}' where project_id='143' and type_id='76772'; Update projectprop set value='{"2008-05-15T00:00:00","2008-05-15T00:00:00"}' where project_id='152' and type_id='76772'; Update projectprop set value='{"2008-06-25T00:00:00","2008-06-25T00:00:00"}' where project_id='152' and type_id='76773'; Update projectprop set value='{"2006-02-01T00:00:00","2006-02-01T00:00:00"}' where project_id='146' and type_id='76772'; Update projectprop set value='{"2006-12-08T00:00:00","2006-12-08T00:00:00"}' where project_id='148' and type_id='76772'; Update projectprop set value='{"2007-01-20T00:00:00","2007-01-20T00:00:00"}' where project_id='148' and type_id='76773'; Update projectprop set value='{"2006-05-02T00:00:00","2006-05-02T00:00:00"}' where project_id='147' and type_id='76772'; Update projectprop set value='{"2006-07-02T00:00:00","2006-07-02T00:00:00"}' where project_id='147' and type_id='76773'; Update projectprop set value='{"2008-04-29T00:00:00","2008-04-29T00:00:00"}' where project_id='151' and type_id='76772'; Update projectprop set value='{"2008-06-10T00:00:00","2008-06-10T00:00:00"}' where project_id='151' and type_id='76773'; Update projectprop set value='{"2011-08-08T00:00:00","2011-08-08T00:00:00"}' where project_id='155' and type_id='76772'; Update projectprop set value='{"2011-10-21T00:00:00","2011-10-21T00:00:00"}' where project_id='155' and type_id='76773'; Update projectprop set value='{"2011-09-28T00:00:00","2011-09-28T00:00:00"}' where project_id='133' and type_id='76772'; Update projectprop set value='{"2011-06-24T00:00:00","2011-06-24T00:00:00"}' where project_id='133' and type_id='76773'; Update projectprop set value='{"2011-06-01T00:00:00","2011-06-01T00:00:00"}' where project_id='145' and type_id='76772'; Update projectprop set value='{"2011-08-10T00:00:00","2011-08-10T00:00:00"}' where project_id='145' and type_id='76773'; Update projectprop set value='{"2010-08-12T00:00:00","2010-08-12T00:00:00"}' where project_id='158' and type_id='76772'; Update projectprop set value='{"2010-05-07T00:00:00","2010-05-07T00:00:00"}' where project_id='132' and type_id='76772'; Update projectprop set value='{"2010-06-06T00:00:00","2010-06-06T00:00:00"}' where project_id='136' and type_id='76772'; Update projectprop set value='{"2010-05-18T00:00:00","2010-05-18T00:00:00"}' where project_id='135' and type_id='76772'; Update projectprop set value='{"2010-07-28T00:00:00","2010-07-28T00:00:00"}' where project_id='135' and type_id='76773'; Update projectprop set value='{"2010-05-18T00:00:00","2010-05-18T00:00:00"}' where project_id='135' and type_id='76772'; Update projectprop set value='{"2015-08-12T00:00:00","2015-08-15T00:00:00"}' where project_id='134' and type_id='76773'; Update projectprop set value='{"2015-08-28T00:00:00","2015-08-28T00:00:00"}' where project_id='153' and type_id='76773'; Update projectprop set value='{"2015-08-23T00:00:00","2015-08-23T00:00:00"}' where project_id='134' and type_id='76772'; Update projectprop set value='{"2015-08-07T00:00:00","2015-08-07T00:00:00"}' where project_id='153' and type_id='76772'; Update projectprop set value='{"2015-08-06T00:00:00","2015-08-06T00:00:00"}' where project_id='154' and type_id='76773'; Update projectprop set value='{"2015-08-20T00:00:00","2015-08-20T00:00:00"}' where project_id='154' and type_id='76772';
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
    #print STDERR $formatted_time;
    return $formatted_time;
}

1;
