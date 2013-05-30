
package SGN::Controller::List;

use Moose; 

BEGIN { extends 'Catalyst::Controller'; }

sub download_list :Path('/list/download') Args(0) { 
    my $self = shift;
    my $c = shift;

    
    if (!$c->user()) { 
	$c->stash->{template} = 'generic_message.mas';
	$c->stash->{message} = 'You need to be logged in to download lists.';
	
	return;
    }

    my $list_id = $c->req->param("list_id");

    my $list = SGN::Controller::AJAX::List->retrieve_list($c, $list_id);
    
    $c->res->content_type("text/plain");

    $c->res->body(join "\n", map { $_->[1] }  @$list);

}

1;
