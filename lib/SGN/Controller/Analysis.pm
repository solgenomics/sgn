
package SGN::Controller::Analysis;

use Moose;

BEGIN { extends 'Catalyst::Controller' };

sub view_analyses :Path('/analyses') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/analyses/index.mas';
}

sub analysis_detail :Path('/analyses') Args(1) {
    my $self = shift;
    my $c = shift;
    my $analysis_id = shift;
    


    my $a = CXGN::Analysis->new( 
	{ 
	    bcs_schema => $c->dbic_schema("Bio::Chado::Schema"),
	    people_schema => $c->dbic_schema("CXGN::People::Schema"),
	    project_id => $analysis_id,
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
    
