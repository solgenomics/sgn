
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
	push(@results, {projectprop_id=>$projectprop_id, title=>$project_name, property=>$project_prop, start=>$project_date});
    }

    #Add some dummy test values
    push(@results, {projectprop_id=>'9000', title=>"Populate Test 1", property=>"Test Date", start=>"2015-07-16"});
    push(@results, {projectprop_id=>'9001', title=>"Populate Test 2", property=>"Test Date", start=>"2015-07-10"});
    push(@results, {projectprop_id=>'9002', title=>"Populate Test 3", property=>"Test Date", start=>"2015-08-02"});
    $c->stash->{project_dates_data} = \@results;
    $c->stash->{template} = '/calendar/test_page.mas';
    $c->stash->{static_content_path} = $c->config->{static_content_path};
}


1;
