
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
use SGN::Model::Cvterm;
use CXGN::Calendar;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
   );


=head2 /ajax/calendar/populate/personal/{view}

 Usage: When the calendar is loaded and when controls (such as next month or year) are used, this function is called to get event data. Arguments are the calendar views which are either month or agendaWeek.
 Desc:
 Return JSON example:
[{"event_description":"N/A","end_drag":"2015-10-28T00:00:00","event_url":"#","allDay":1,"end_display":"2015-10-28","project_id":89,"property":"Planting Event","p_description":"Plants assayed at Zaria in 2002/03","cvterm_url":"/cvterm/76941/view","start_drag":"2015-10-28T00:00:00","end":"2015-10-29T00:00:00","start_display":"2015-10-28","projectprop_id":2735,"cvterm_id":76941,"title":"Cassava Zaria 2002/03","project_url":"/breeders_toolbox/trial/89/","start":"2015-10-28T00:00:00"},{"event_description":"N/A","end_drag":"2015-10-23T00:00:00","event_url":"#","allDay":1,"end_display":"2015-10-23","project_id":599,"property":"Presentation Event","p_description":"Test Bootstrap2","cvterm_url":"/cvterm/76946/view","start_drag":"2015-10-22T00:00:00","end":"2015-10-24T00:00:00","start_display":"2015-10-22","projectprop_id":2729,"cvterm_id":76946,"title":"TestBootstrap2","project_url":"/breeders_toolbox/trial/599/","start":"2015-10-22T00:00:00"}]
 Args: The calendar view being displayed, either month or agendaWeek
 Side Effects:
 Example:

=cut


sub calendar_events_personal  : Path('/ajax/calendar/populate/personal') : ActionClass('REST') { }
sub calendar_events_personal_GET : Args(1) { 
    my $self = shift;
    my $c = shift;
    my $view = shift;
    if (!$c->user()) {$c->detach();}
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my @roles = $c->user->get_roles();

    my $calendar_funcs = CXGN::Calendar->new({
        bcs_schema => $schema,
        sp_person_id => $c->user->get_object->get_sp_person_id,
        roles => \@roles
    });
    my $search_rs = $calendar_funcs->get_calendar_events_personal($c);
    $c->stash->{rest} = $calendar_funcs->populate_calendar_events($search_rs, $view);
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

    #if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter')) ) {
    if (my $message = $c->stash->{access}->denied ($c->stash->{user_id}, "write", "community" )) { 
        $c->stash->{rest} = {status => 3};
        return;
    }

    my $calendar_funcs = CXGN::Calendar->new({});

    #A time::piece object is returned from format_time(). Calling ->datetime on this object return an ISO8601 datetime string. This is what is saved in the db.
    my $format_start = $calendar_funcs->format_time($params->{event_start})->datetime;
    
    #If an event end is given, then it is converted to an ISO8601 datetime string to be saved. If none is given then the end will be the same as the start.
    my $format_end;
    if ($params->{event_end} eq '') {$format_end = $format_start;} else {$format_end = $calendar_funcs->format_time($params->{event_end})->datetime;}

    #If no description or URL given, then default values will be given.
    if ($params->{event_description} eq '') {$params->{event_description} = 'N/A';}
    if ($params->{event_url} eq '') {$params->{event_url} = '#';} else {$params->{event_url} = 'http://www.'.$params->{event_url};}
    
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my $rs = $schema->resultset('Project::Projectprop');
    my $count = $rs->search({ project_id=>$params->{event_project_select}, type_id=>$params->{event_type_select} })->count;

    if (my $insert = $rs->create({project_id=>$params->{event_project_select}, type_id=>$params->{event_type_select}, rank=>$count, value=>[$format_start, $format_end, $params->{event_description}, $params->{event_url}] })) {
	   $c->stash->{rest} = {status => 1,};
    } else {
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

    #if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter')) ) {
    if (my $message = $c->stash->{access}->denied ($c->stash->{user_id}, "write", "community" )) { 
        $c->stash->{rest} = {status => 3};
        return;
    }

    my $projectprop_id = $c->req->param("event_projectprop_id");
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    if (my $delete = $schema->resultset('Project::Projectprop')->find({projectprop_id=>$projectprop_id})->delete) {
	   $c->stash->{rest} = {status => 1,};
    } else {
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

    #if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter')) ) {
    if (my $message = $c->stash->{access}->denied ($c->stash->{user_id}, "write", "community" )) { 
        $c->stash->{rest} = {status => 3};
        return;
    }

    my $calendar_funcs = CXGN::Calendar->new({});

    #First we process the start datetime.
    #A time::piece object is returned from format_time(). Delta is the number of seconds that the date was changed. Calling ->epoch on the time::piece object returns a string representing number of sec since epoch.
    my $formatted_start = $calendar_funcs->format_time($params->{start_drag} )->epoch;
    
    #If the event is being dragged to a new start, then the delta is added to the start here. When resizing, the start is not changed, only the end is changed.
    if ($params->{drag} == 1) {
	$formatted_start += $params->{delta};
    }

    #The string representing the new number of sec since epoch is parsed into a time::piece object.
    $formatted_start = Time::Piece->strptime($formatted_start, '%s');

    # $new_start is what is saved to db. $new_start_display is what is displayed on mouseover.
    my $new_start = $formatted_start->datetime;
    my $new_start_display = $calendar_funcs->format_display_date($formatted_start);
    
    #Next we process the end datetime. Whether the event is being dragged or resized, the end = end + delta.
    my $formatted_end = $calendar_funcs->format_time($params->{end_drag} )->epoch;
    $formatted_end += $params->{delta};
    $formatted_end = Time::Piece->strptime($formatted_end, '%s');

    # $new_end is what is saved in db. 
    my $new_end = $formatted_end->datetime;
    my $new_end_time = $calendar_funcs->calendar_end_display($formatted_end, $params->{view}, $params->{allday} );
    my $new_end_display = $calendar_funcs->format_display_date($formatted_end);

    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    if (my $update_rs = $schema->resultset('Project::Projectprop')->find({projectprop_id=>$params->{projectprop_id} }, columns=>['value'])->update({value=>[$new_start, $new_end, $params->{description}, $params->{url}] })) {

	   $c->stash->{rest} = {success => 1, start=>$new_start, start_drag=>$new_start, start_display=>$new_start_display, end=>$new_end_time, end_drag=>$new_end, end_display=>$new_end_display};
    } else {
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

    #if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter')) ) {
    if (my $message = $c->stash->{access}->denied ($c->stash->{user_id}, "write", "community" )) { 
        $c->stash->{rest} = {status => 3};
        return;
    }

    my $params = $c->req->params();
    my $calendar_funcs = CXGN::Calendar->new({});

    #A time::piece object is returned from format_time(). Calling ->datetime on this object return an ISO8601 datetime string. This is what is saved in the db.
    my $format_start = $calendar_funcs->format_time($params->{edit_event_start})->datetime;
    
    #If an event end is given, then it is converted to an ISO8601 datetime string to be saved. If none is given then the end will be the same as the start.
    my $format_end;
    if ($params->{edit_event_end} eq '') {$format_end = $format_start;} else {$format_end = $calendar_funcs->format_time($params->{edit_event_end})->datetime;}

    #If no description or URL given or end date given, then default values will be given.
    if ($params->{edit_event_description} eq '') {$params->{edit_event_description} = 'N/A';}
    if ($params->{edit_event_url} eq '') {$params->{edit_event_url} = '#';}

    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    if (my $update_rs = $schema->resultset('Project::Projectprop')->find({projectprop_id=>$params->{edit_event_projectprop_id} }, columns=>['project_id', 'type_id', 'value'])->update({project_id=>$params->{edit_event_project_select}, type_id=>$params->{edit_event_type_select}, value=>[$format_start, $format_end, $params->{edit_event_description}, $params->{edit_event_url}] })) {
	   $c->stash->{rest} = {status => 1,};
    } else {
	   $c->stash->{rest} = {error => 1,};
    }
}


#When a day is clicked or when an event is being editted, this function is called to populate the add_event project name and property type dropdowns.
sub day_click_personal : Path('/ajax/calendar/dayclick/personal') : ActionClass('REST') { }
sub day_click_personal_GET { 
    my $self = shift;
    my $c = shift;

    my $person_id = $c->user->get_object->get_sp_person_id;

    my @roles = $c->user->get_roles();
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

    my @calendar_projectprop_names = (['project_planting_date', 'project_property'], ['project_harvest_date', 'project_property'], ['Fertilizer Event', 'calendar'], ['Meeting Event', 'calendar'], ['Planning Event', 'calendar'], ['Presentation Event', 'calendar'], ['Phenotyping Event', 'calendar'], ['Genotyping Event', 'calendar'] );
 
    my $schema = $c->dbic_schema('Bio::Chado::Schema');
    my @projectprop_types;
    foreach (@calendar_projectprop_names) {
        my $term = SGN::Model::Cvterm->get_cvterm_row($schema, $_->[0], $_->[1] );
        if ($term) {
            push(@projectprop_types, {cvterm_id=>$term->cvterm_id(), cvterm_name=>$term->name() });
        } else {
            push(@projectprop_types, {cvterm_id=>'', cvterm_name=>'Error: Missing cvterm '.$_->[0].' : '.$_->[1].' in database.'});
        }
    }
    
    $c->stash->{rest} = {project_list => \@projects, projectprop_list => \@projectprop_types};
}
    

1;
