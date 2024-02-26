
package SGN::Controller::Genefamily;



sub genefamily_index :Path('/tools/genefamily') Args(0) {
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/tools/genefamily/index.mas';
}


sub search : Path('/tools/genefamily/search') Args(0) {
    my $self = shift;
    my $c = shift;

    if ($c->user() ) { 
	$c->user->has_roles("curator", "genefamily_editor") { 
	    
	    $c->stash->{genefamily_id} = $c->req->param("genefamily_id") || '';
	    $c->stash->{dataset} = $c->req->param("dataset") || '';
	    $c->stash->{member_id} = $c->req->param("member_id") || '';
	    $c->stash->{action} = $c->req->param("action") || '';
	    
	    $c->stash->{template} = '/tools/genefamily/search.mas';
	}
	else {
	    $c->stash->{message} = "You do not have the necessary privileges to access this page.";
	    $c->stash->{template} = "/generic_message.mas";
	}

    }
    else {
	$c->stash->{message} = "You need to be logged in to access this page.";
	$c->stash->{template} = "/generic_message.mas";
    }
	
}
