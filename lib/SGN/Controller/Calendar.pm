
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
    $c->stash->{template} = '/calendar/test_page.mas';
    $c->stash->{static_content_path} = $c->config->{static_content_path};
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

1;
