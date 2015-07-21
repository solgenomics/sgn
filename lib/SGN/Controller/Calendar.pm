
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
    my $q = "SELECT a.projectprop_id, c.name, a.value, b.name FROM ((projectprop as a INNER JOIN cvterm as b on (a.type_id=b.cvterm_id)) INNER JOIN project as c on (a.project_id=c.project_id))";
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute();
    my @results;
    while (my ($projectprop_id, $project_name, $project_date, $project_prop) = $sth->fetchrow_array ) {
	push(@results, {projectprop_id=>$projectprop_id, title=>$project_name, property=>$project_prop, start=>$project_date, save=>$project_date});
    }

    $q = "SELECT DISTINCT b.cvterm_id, b.name FROM (projectprop as a INNER JOIN cvterm as b on (a.type_id=b.cvterm_id))";
    $sth = $c->dbc->dbh->prepare($q);
    $sth->execute();
    my @projectprop_types;
    while (my ($cvterm_id, $cvterm_name) = $sth->fetchrow_array ) {
	push(@projectprop_types, {cvterm_id=>$cvterm_id, cvterm_name=>$cvterm_name});
    }

    $q = "SELECT DISTINCT project_id, name FROM project";
    $sth = $c->dbc->dbh->prepare($q);
    $sth->execute();
    my @projects;
    while (my ($project_id, $project_name) = $sth->fetchrow_array ) {
	push(@projects, {project_id=>$project_id, project_name=>$project_name});
    }

    $c->stash->{projects} = \@projects;
    $c->stash->{projectprop_types} = \@projectprop_types;
    $c->stash->{project_dates_data} = \@results;
    $c->stash->{template} = '/calendar/test_page.mas';
    $c->stash->{static_content_path} = $c->config->{static_content_path};
}

sub add_event :Path('/calendar/add_event') :Args(0) { 
    my $self = shift;
    my $c = shift;
    my $project_id = $c->req->param("event_project");
    my $cvterm_id = $c->req->param("event_type");
    my $date = $c->req->param("event_start");
    my $count = $c->dbc->dbh->selectrow_array("SELECT count(projectprop_id) FROM projectprop WHERE project_id='$project_id' and type_id='$cvterm_id'");
    if ($count > 0){
      $c->stash->{add_event} = 'false';
    } else {
      my $q = "INSERT INTO projectprop (project_id, type_id, value) VALUES (?, ?, ?)";
      my $sth = $c->dbc->dbh->prepare($q);
      $sth->execute($project_id, $cvterm_id, $date);
      $c->stash->{add_event} = 'true';
    }

    my $q = "SELECT a.projectprop_id, c.name, a.value, b.name FROM ((projectprop as a INNER JOIN cvterm as b on (a.type_id=b.cvterm_id)) INNER JOIN project as c on (a.project_id=c.project_id))";
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute();
    my @results;
    while (my ($projectprop_id, $project_name, $project_date, $project_prop) = $sth->fetchrow_array ) {
	push(@results, {projectprop_id=>$projectprop_id, title=>$project_name, property=>$project_prop, start=>$project_date, save=>$project_date});
    }

    $q = "SELECT DISTINCT b.cvterm_id, b.name FROM (projectprop as a INNER JOIN cvterm as b on (a.type_id=b.cvterm_id))";
    $sth = $c->dbc->dbh->prepare($q);
    $sth->execute();
    my @projectprop_types;
    while (my ($cvterm_id, $cvterm_name) = $sth->fetchrow_array ) {
	push(@projectprop_types, {cvterm_id=>$cvterm_id, cvterm_name=>$cvterm_name});
    }

    $q = "SELECT DISTINCT project_id, name FROM project";
    $sth = $c->dbc->dbh->prepare($q);
    $sth->execute();
    my @projects;
    while (my ($project_id, $project_name) = $sth->fetchrow_array ) {
	push(@projects, {project_id=>$project_id, project_name=>$project_name});
    }

    $c->stash->{projects} = \@projects;
    $c->stash->{projectprop_types} = \@projectprop_types;
    $c->stash->{project_dates_data} = \@results;
    $c->stash->{template} = '/calendar/test_page.mas';
}

1;
