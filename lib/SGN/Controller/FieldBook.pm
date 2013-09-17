
package SGN::Controller::FieldBook;

use Moose;
use URI::FromHash 'uri';


BEGIN { extends 'Catalyst::Controller'; }

sub field_book :Path("/fieldbook") Args(0) { 
    my ($self , $c) = @_;
    if (!$c->user()) { 
	# redirect to login page
	$c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) ); 
	return;
    }
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    # get projects
    #
    my @rows = $schema->resultset('Project::Project')->all();
    my @projects = ();
    foreach my $row (@rows) { 
	push @projects, [ $row->project_id, $row->name, $row->description ];
    }
    $c->stash->{projects} = \@projects;
    # get roles
    my @roles = $c->user->roles();
    $c->stash->{roles}=\@roles;
    $c->stash->{template} = '/fieldbook/home.mas';
}




1;
