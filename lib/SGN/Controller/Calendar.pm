
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

    $c->stash->{projects} = get_projects($c);
    $c->stash->{projectprop_types} = get_distinct_projectprop($c);
    $c->stash->{project_dates_data} = get_projectprop_data($c);
    $c->stash->{project_relationships_data} = get_project_relationships($c);
    $c->stash->{template} = '/calendar/test_page.mas';
    $c->stash->{static_content_path} = $c->config->{static_content_path};
}

#this gets the data which fills the table at the bottom of test_page.mas
sub get_projectprop_data {
    my $c = shift;
    my $q = "SELECT a.projectprop_id, c.name, a.value, b.name FROM ((projectprop as a INNER JOIN cvterm as b on (a.type_id=b.cvterm_id)) INNER JOIN project as c on (a.project_id=c.project_id))";
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute();
    my @results;
    while (my ($projectprop_id, $project_name, $project_date, $project_prop) = $sth->fetchrow_array ) {
	push(@results, {projectprop_id=>$projectprop_id, title=>$project_name, property=>$project_prop, start=>$project_date, save=>$project_date});
    }
    return \@results;
}

#this populates the project dropdown in the add_event dialog
sub get_projects {
    my $c = shift;
    my $q = "SELECT DISTINCT project_id, name FROM project";
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute();
    my @projects;
    while (my ($project_id, $project_name) = $sth->fetchrow_array ) {
	push(@projects, {project_id=>$project_id, project_name=>$project_name});
    }
    return \@projects;
}

#this populates the event type dropdown in the add_event dialog
sub get_distinct_projectprop {
    my $c = shift;
    my $q = "SELECT DISTINCT b.cvterm_id, b.name FROM (projectprop as a INNER JOIN cvterm as b on (a.type_id=b.cvterm_id))";
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute();
    my @projectprop_types;
    while (my ($cvterm_id, $cvterm_name) = $sth->fetchrow_array ) {
	push(@projectprop_types, {cvterm_id=>$cvterm_id, cvterm_name=>$cvterm_name});
    }
    return \@projectprop_types;
}

sub get_project_relationships {
    my $c = shift;
    my $q = "SELECT b.name, a.subject_project_id, a.object_project_id, c.name, d.name FROM (((project_relationship as a INNER JOIN cvterm as b on (a.type_id=b.cvterm_id)) INNER JOIN project as c on (a.subject_project_id=c.project_id)) INNER JOIN project as d on (a.object_project_id=d.project_id))";
    my $sth = $c->dbc->dbh->prepare($q);
    $sth->execute();
    my @project_relationships;
    while (my ($cvterm_name, $subject_project_id, $object_project_id, $subject_project, $object_project) = $sth->fetchrow_array ) {
	push(@project_relationships, {relationship_type=>$cvterm_name, subject_project_id=>$subject_project_id, object_project_id=>$object_project_id, subject_project=>$subject_project, object_project=>$object_project});
    }
    return \@project_relationships;
}

1;
