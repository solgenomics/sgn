
package SGN::Controller::Analysis;

use Moose;
use URI::FromHash 'uri';


BEGIN { extends 'Catalyst::Controller' };

sub view_analyses :Path('/analyses') Args(0) {
    my $self = shift;
    my $c = shift;

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $user_id;
    if ($c->user()) {
	$user_id = $c->user->get_object()->get_sp_person_id();
    }
    if (!$user_id) {
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
    }

    
    $c->stash->{template} = '/analyses/index.mas';
}

sub analysis_detail :Path('/analyses') Args(1) {
    my $self = shift;
    my $c = shift;
    my $analysis_id = shift;
    
    print STDERR "Viewing analysis with id $analysis_id\n";

    my $a = CXGN::Analysis->new( 
	{ 
	    bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
	    people_schema => $c->dbic_schema("CXGN::People::Schema"),
	    trial_id => $analysis_id,
	});

    if (! $a) {
	$c->stash->{template} = '/generic_message.mas';
	$c->stash->{message} = 'The requested analysis ID does not exist in the database.';
	return;
    }

    $c->stash->{analysis_id} = $analysis_id;
    $c->stash->{analysis_name} = $a->name();
    $c->stash->{analysis_description} = $a->description();
    $c->stash->{template} = '/analyses/detail.mas';
}

1;
    
