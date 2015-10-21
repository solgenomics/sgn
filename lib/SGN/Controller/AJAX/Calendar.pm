
=head1 NAME

SGN::Controller::AJAX::Calendar - a REST controller class to provide the
backend for displaying, adding, deleting, dragging, modifying, and requesting more info about events. All calendar related functions are here.

=head1 DESCRIPTION

Calendar events are saved in the projectprop table value field as a tuple of the format {"2007-09-21T00:00:00","2007-09-21T00:00:00","N/A","#"} which correspond to the start datetime, end datetime, description, and web url, respectively. 

The calendar can display events for projects (breeding programs and their trials) which a user has a role for in the sp_person_roles table. 


=head1 AUTHOR

Nicolas Morales <nm529@cornell.edu>
Created: 08/01/2015
Modified: 10/21/2015

=cut


package SGN::Controller::AJAX::Calendar;

use strict;
use Moose;
use JSON;
use Time::Piece;
use Time::Seconds;
use Data::Dumper;
use CXGN::Login;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

=head2 /ajax/calendar/populate/personal/{view}

 Usage: When the calendar is loaded and when controls (such as next month or year) are used, this function is called to get event data. Arguments are the calendar views which are either month or agendaWeek.
 Desc:
 Return JSON example:
[{"event_description":"N/A","end_drag":"2015-10-28T00:00:00","event_url":"#","allDay":1,"end_display":"2015-10-28","project_id":89,"property":"Planting Event","p_description":"Plants assayed at Zaria in 2002/03","cvterm_url":"/chado/cvterm?cvterm_id=76941","start_drag":"2015-10-28T00:00:00","end":"2015-10-29T00:00:00","start_display":"2015-10-28","projectprop_id":2735,"cvterm_id":76941,"title":"Cassava Zaria 2002/03","project_url":"/breeders_toolbox/trial/89/","start":"2015-10-28T00:00:00"},{"event_description":"N/A","end_drag":"2015-10-23T00:00:00","event_url":"#","allDay":1,"end_display":"2015-10-23","project_id":599,"property":"Presentation Event","p_description":"Test Bootstrap2","cvterm_url":"/chado/cvterm?cvterm_id=76946","start_drag":"2015-10-22T00:00:00","end":"2015-10-24T00:00:00","start_display":"2015-10-22","projectprop_id":2729,"cvterm_id":76946,"title":"TestBootstrap2","project_url":"/breeders_toolbox/trial/599/","start":"2015-10-22T00:00:00"}]
 Args: The calendar view being displayed, either month or agendaWeek
 Side Effects:
 Example:

=cut

sub calendar_events_personal  : Path('/ajax/calendar/populate/personal') : ActionClass('REST') { }
sub calendar_events_personal_GET : Args(1) { 
    my $self = shift;
    my $c = shift;
    my $view = shift;
    if (!$c->user()) {die;}
    my $search_rs = get_calendar_events_personal($c);
    $c->stash->{rest} = populate_calendar_events($search_rs, $view);
}

=head2 /ajax/calendar/drag_or_resize

 Usage: When an event is added using the day_dialog_add_event_form, this function is called to save it to the database.
 Desc:
 Return JSON example:
 Args: event_start, event_end, event_description, event_url, event_project_select, event_type_select
 Side Effects:
 Example:

=cut

sub add_event : Path('/ajax/calendar/add_event') : ActionClass('REST') { }
sub add_event_POST { 
    my $self = shift;
    my $c = shift;
    my $params = $c->req->params();

    #A time::piece object is returned from format_time(). Calling ->datetime on this object return an ISO8601 datetime string. This is what is saved in the db.
    my $format_start = format_time($params->{event_start})->datetime;
    
    #If an event end is given, then it is converted to an ISO8601 datetime string to be saved. If none is given then the end will be the same as the start.
    my $format_end;
    if ($params->{event_end} eq '') {$format_end = $format_start;} else {$format_end = format_time($params->{event_end})->datetime;}

    #If no description or URL given, then default values will be given.
    if ($params->{event_description} eq '') {$params->{event_description} = 'N/A';}
    if ($params->{event_url} eq '') {$params->{event_url} = '#';} else {$params->{event_url} = 'http://www.'.$params->{event_url};}
    
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $rs = $schema->resultset('Project::Projectprop');
    my $count = $rs->search({ project_id=>$params->{event_project_select}, type_id=>$params->{event_type_select} })->count;

    $schema->storage->txn_begin;
    if (my $insert = $rs->create({project_id=>$params->{event_project_select}, type_id=>$params->{event_type_select}, rank=>$count, value=>[$format_start, $format_end, $params->{event_description}, $params->{event_url}] })) {
	$schema->storage->txn_commit;
	$c->stash->{rest} = {status => 1,};
    } else {
	$schema->storage->txn_rollback;
	$c->stash->{rest} = {status => 2,};
    }
}

=head2 /ajax/calendar/delete_event

 Usage: To delete an event
 Desc:
 Return JSON example:
 Args: event_projectprop_id
 Side Effects:
 Example:

=cut

sub delete_event : Path('/ajax/calendar/delete_event') : ActionClass('REST') { }
sub delete_event_POST { 
    my $self = shift;
    my $c = shift;
    my $projectprop_id = $c->req->param("event_projectprop_id");
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    $schema->storage->txn_begin;
    if (my $delete = $schema->resultset('Project::Projectprop')->find({projectprop_id=>$projectprop_id})->delete) {
	$schema->storage->txn_commit;
	$c->stash->{rest} = {status => 1,};
    } else {
	$schema->storage->txn_rollback;
	$c->stash->{rest} = {status => 0,};
    }
}

=head2 /ajax/calendar/drag_or_resize

 Usage: When an event is dragged to a new date a value of drag = 1 is passed to the function. When an event is simply resized a value of drag = 0 is passed to the function. This function saves the new start and end date to the db and updates the calendar display and mouseover.
 Desc:
 Return JSON example:
 Args: start_drag, delta, end_drag, drag, view, allday, projectprop_id, description, url
 Side Effects:
 Example:

=cut

sub drag_or_resize_event : Path('/ajax/calendar/drag_or_resize') : ActionClass('REST') { }
sub drag_or_resize_event_POST { 
    my $self = shift;
    my $c = shift;
    my $params = $c->req->params();

    #First we process the start datetime.
    #A time::piece object is returned from format_time(). Delta is the number of seconds that the date was changed. Calling ->epoch on the time::piece object returns a string representing number of sec since epoch.
    my $formatted_start = format_time($params->{start_drag} )->epoch;
    
    #If the event is being dragged to a new start, then the delta is added to the start here. When resizing, the start is not changed, only the end is changed.
    if ($params->{drag} == 1) {
	$formatted_start += $params->{delta};
    }

    #The string representing the new number of sec since epoch is parsed into a time::piece object.
    $formatted_start = Time::Piece->strptime($formatted_start, '%s');

    # $new_start is what is saved to db. $new_start_display is what is displayed on mouseover.
    my $new_start = $formatted_start->datetime;
    my $new_start_display = format_display_date($formatted_start);
    
    #Next we process the end datetime. Whether the event is being dragged or resized, the end = end + delta.
    my $formatted_end = format_time($params->{end_drag} )->epoch;
    $formatted_end += $params->{delta};
    $formatted_end = Time::Piece->strptime($formatted_end, '%s');

    # $new_end is what is saved in db. 
    my $new_end = $formatted_end->datetime;
    my $new_end_time = calendar_end_display($formatted_end, $params->{view}, $params->{allday} );
    my $new_end_display = format_display_date($formatted_end);

    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    $schema->storage->txn_begin;
    if (my $update_rs = $schema->resultset('Project::Projectprop')->find({projectprop_id=>$params->{projectprop_id} }, columns=>['value'])->update({value=>[$new_start, $new_end, $params->{description}, $params->{url}] })) {
	$schema->storage->txn_commit;

	#If the update was successfull, data is passed back to AJAX so that the event can be properly updated in display.
	$c->stash->{rest} = {success => 1, start=>$new_start, start_drag=>$new_start, start_display=>$new_start_display, end=>$new_end_time, end_drag=>$new_end, end_display=>$new_end_display};
    } else {
	$schema->storage->txn_rollback;
	$c->stash->{rest} = {error => 1,};
    }
}

=head2 /ajax/calendar/edit_event

 Usage: When an event is editted using the edit_event_form
 Desc:
 Return JSON example:
 Args: edit_event_start, edit_event_end, edit_event_description, edit_event_url, edit_event_projectprop_id, edit_event_project_select, edit_event_type_select
 Side Effects:
 Example:

=cut

sub edit_event : Path('/ajax/calendar/edit_event') : ActionClass('REST') { }
sub edit_event_POST { 
    my $self = shift;
    my $c = shift;
    my $params = $c->req->params();

    #A time::piece object is returned from format_time(). Calling ->datetime on this object return an ISO8601 datetime string. This is what is saved in the db.
    my $format_start = format_time($params->{edit_event_start})->datetime;
    
    #If an event end is given, then it is converted to an ISO8601 datetime string to be saved. If none is given then the end will be the same as the start.
    my $format_end;
    if ($params->{edit_event_end} eq '') {$format_end = $format_start;} else {$format_end = format_time($params->{edit_event_end})->datetime;}

    #If no description or URL given or end date given, then default values will be given.
    if ($params->{edit_event_description} eq '') {$params->{edit_event_description} = 'N/A';}
    if ($params->{edit_event_url} eq '') {$params->{edit_event_url} = '#';}

    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    $schema->storage->txn_begin;
    if (my $update_rs = $schema->resultset('Project::Projectprop')->find({projectprop_id=>$params->{edit_event_projectprop_id} }, columns=>['project_id', 'type_id', 'value'])->update({project_id=>$params->{edit_event_project_select}, type_id=>$params->{edit_event_type_select}, value=>[$format_start, $format_end, $params->{edit_event_description}, $params->{edit_event_url}] })) {
	$schema->storage->txn_commit;
	$c->stash->{rest} = {status => 1,};
    } else {
	$schema->storage->txn_rollback;
	$c->stash->{rest} = {error => 1,};
    }
}

sub get_user_roles {
    my $c = shift;
    my $person_id = shift;
    my @roles;

    my $q = "SELECT sgn_people.sp_roles.name FROM sgn_people.sp_person JOIN sgn_people.sp_person_roles using(sp_person_id) join sgn_people.sp_roles using(sp_role_id) WHERE sp_person_id=?";
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute($person_id);
    while (my ($role) = $sth->fetchrow_array ) {
	push(@roles, $role);
    }
    return @roles;
}


sub get_calendar_events_personal {
    my $c = shift;
    my $person_id = $c->user->get_object->get_sp_person_id;
    my @roles = get_user_roles($c, $person_id);
    my @search_project_ids = '-1';
    foreach (@roles) {
	my $q="SELECT project_id FROM project WHERE name=?";
	my $sth = $c->dbc->dbh->prepare($q);
	$sth->execute($_);
        while (my ($project_id) = $sth->fetchrow_array ) {
	    push(@search_project_ids, $project_id);

	    my $q="SELECT subject_project_id FROM project_relationship JOIN cvterm ON (type_id=cvterm_id) WHERE object_project_id=? and cvterm.name='breeding_program_trial_relationship'";
	    my $sth = $c->dbc->dbh->prepare($q);
	    $sth->execute($project_id);
	    while (my ($trial) = $sth->fetchrow_array ) {
		push(@search_project_ids, $trial);
	    }
	}
    }

    @search_project_ids = map{$_='me.project_id='.$_; $_} @search_project_ids;
    my $search_projects = join(" OR ", @search_project_ids);
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $search_rs = $schema->resultset('Project::Project')->search(
	undef,
	{join=>{'projectprops'=>{'type'=>'cv'}},
	'+select'=> ['projectprops.projectprop_id', 'type.name', 'projectprops.value', 'type.cvterm_id'],
	'+as'=> ['pp_id', 'cv_name', 'pp_value', 'cv_id'],
	}
    );
    $search_rs = $search_rs->search([$search_projects]);
    return $search_rs;
}

sub populate_calendar_events {
    my $search_rs = shift;
    my $view = shift;
    my @events;
    my $allday;
    my $start_time;
    my $start_drag;
    my $start_display;
    my $end_time;
    my $end_drag;
    my $end_display;
    my $formatted_time;
    my @time_array;
    my $title;
    my $property;
    while (my $result = $search_rs->next) {

	#Check if project property value is an event, and if it is not, then skip to next result.
	if (check_value_format($result->get_column('pp_value')) == -1) {
	    next;
	}

	@time_array = parse_time_array($result->get_column('pp_value'));

	#We begin with the start datetime, or the first element in the time_array.
	#A time::piece object is returned from format_time(). Calling ->datetime on this object returns an ISO8601 datetime string. This string is what is used as the calendar event's start. Using format_display_date(), a nice date to display on mouse over is returned.
	$formatted_time = format_time($time_array[0]);
	$start_time = $formatted_time->datetime;
	$start_display = format_display_date($formatted_time);
	
	#Because fullcalendar does not allow event resizing of allDay=false events in the month view, the allDay parameter must be set depending on the view. The allDay parameter for the agendaWeek view is important and is set using determine_allday().
	if ($view eq 'month') {
	    $allday = 1;
	} elsif ($view eq 'agendaWeek') {
	    $allday = determine_allday($formatted_time);
	}

	#Then we process the end datetime, which is the second element in the time_array. calendar_end_display determines what the calendar should display as the end, and format_display_date() returns a nice date to display on mouseover.
	$formatted_time = format_time($time_array[1]);
	$end_time = calendar_end_display($formatted_time, $view, $allday);
	$end_display = format_display_date($formatted_time);

	#Because FullCallendar's end date is exclusive, an end datetime with 00:00:00 will be displayed as one day short on the calendar, and so corrections to the event's end must be made. To facilitate event dragging, an event.end_drag property is used. 
	$end_drag = $formatted_time->datetime;

	#To display the project name and project properties nicely in the mouseover and more info, we capitalize the first letter of each word.
	$title = $result->name;
	#$title =~ s/([\w']+)/\u\L$1/g;
	$property = $result->get_column('cv_name');
	$property =~ s/([\w']+)/\u\L$1/g;

	#Variables are pushed into the event array and will become properties of Fullcalendar events, like event.start, event.cvterm_url, etc.
	push(@events, {projectprop_id=>$result->get_column('pp_id'), title=>$title, property=>$property, start=>$start_time, start_drag=>$start_time, start_display=>$start_display, end=>$end_time, end_drag=>$end_drag, end_display=>$end_display, project_id=>$result->project_id, project_url=>'/breeders_toolbox/trial/'.$result->project_id.'/', cvterm_id=>$result->get_column('cv_id'), cvterm_url=>'/chado/cvterm?cvterm_id='.$result->get_column('cv_id'), allDay=>$allday, p_description=>$result->description, event_description=>$time_array[2], event_url=>$time_array[3]});
    }
    return \@events;
}

sub check_value_format {
    my $value = shift;
    if ($value and $value =~ /^{"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d","\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d","/) {
	return 1;
    } else {
	return -1;
    }
}

sub parse_time_array {
    my $raw_value = shift;
    $raw_value =~ tr/{}"//d;
    my @time_array = split(/,/, $raw_value);
    return @time_array;
}

sub format_display_date {
    #Displaying 00:00:00 time on mouseover and mouseclick is ugly, so this sub is used to determine date display format.
    my $date_display;
    my $formatted_time = shift;
    if ($formatted_time->hms('') == '000000') {
	$date_display = $formatted_time->strftime("%Y-%m-%d");
    } else {
	$date_display = $formatted_time->strftime("%Y-%m-%d %H:%M:%S");
    }
    return $date_display;
}

sub calendar_end_display {
    #FullCalendar's end datetime is exclusive for allday events in the month view. Since all events in the month view are allday = 1, a full day must be added so that it is displayed correctly on the calendar. In the agendaWeek view, not all events are allday = 1, so the end is only modified for allday events.
    my $formatted_time = shift;
    my $view = shift;
    my $allday = shift;
    my $end_time;
    $end_time = $formatted_time->epoch;
    if ($view eq 'month' || ($view eq 'agendaWeek' && $allday == 1)) {
	$end_time += ONE_DAY;
    }
    $end_time = Time::Piece->strptime($end_time, '%s')->datetime;
    return $end_time;
}

sub determine_allday {
    #On the agendaWeek view, events with start dates with 00:00:00 time are displayed as allDay=true.
    my $allday;
    my $formatted_time = shift;
    if ($formatted_time->hms('') == '000000') {
	$allday = 1;
    } else {
	$allday = 0;
    }
    return $allday;
}

#When a day is clicked or when an event is being editted, this function is called to populate the add_event project name and property type dropdowns.
sub day_click_personal : Path('/ajax/calendar/dayclick/personal') : ActionClass('REST') { }
sub day_click_personal_GET { 
    my $self = shift;
    my $c = shift;

    my $person_id = $c->user->get_object->get_sp_person_id;

    my @roles = get_user_roles($c, $person_id);
    my @projects;
    foreach (@roles) {
	my $q="SELECT project_id, name FROM project WHERE name=?";
	my $sth = $c->dbc->dbh->prepare($q);
	$sth->execute($_);
	while (my ($project_id, $name) = $sth->fetchrow_array ) {
	    push(@projects, {project_id=>$project_id, project_name=>$name});

	    my $q="SELECT subject_project_id, project.name FROM project_relationship JOIN cvterm ON (type_id=cvterm_id) JOIN project ON (subject_project_id=project_id) WHERE object_project_id=? and cvterm.name='breeding_program_trial_relationship'";
	    my $sth = $c->dbc->dbh->prepare($q);
	    $sth->execute($project_id);
	    while (my ($trial_id, $trial_name) = $sth->fetchrow_array ) {
		push(@projects, {project_id=>$trial_id, project_name=>$trial_name});
	    }
	}
    }

    my @projectprop_names = ('Planting Event', 'Harvest Event', 'Fertilizer Event', 'Meeting Event', 'Planning Event', 'Presentation Event', 'Phenotyping Event', 'Genotyping Event');
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my @projectprop_types;
    foreach (@projectprop_names) {
	my $q="SELECT cvterm_id, name FROM cvterm WHERE name=?";
	my $sth = $c->dbc->dbh->prepare($q);
	$sth->execute($_);
	if ($sth->rows == 0) {
	    my $add_term = $schema->resultset('Cv::Cvterm')->create_with({name=>$_, cv=>'calendar', db=>'local', dbxref=>$_});
	    push(@projectprop_types, {cvterm_id=>$add_term->cvterm_id(), cvterm_name=>$add_term->name() });
	} else {
	    while ( my ($cvterm_id, $cvterm_name ) = $sth->fetchrow_array ) {
		push(@projectprop_types, {cvterm_id=>$cvterm_id, cvterm_name=>$cvterm_name});
	    }
	}
    }
 
    $c->stash->{rest} = {project_list => \@projects, projectprop_list => \@projectprop_types};
}
    
#This function is used to return a Time::Piece object, which is useful for format consistensy.
sub format_time {
    my $input_time = shift;
    my $formatted_time;
    if ($input_time =~ /^\d{4}-\d\d-\d\d$/) {
	$formatted_time = Time::Piece->strptime($input_time, '%Y-%m-%d');
    }
    if ($input_time =~ /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})$/) {
	$formatted_time = Time::Piece->strptime($input_time, '%Y-%m-%dT%H:%M:%S');
    }
    return $formatted_time;
}


1;
