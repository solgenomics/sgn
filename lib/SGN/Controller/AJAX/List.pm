
package SGN::Controller::AJAX::List;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub get_list :Path('/list/get') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $list_id = $c->req->param("list_id");

    my $user_id = $self->get_user($c);
    if (!$user_id) { 
	$c->stash->{rest} = { error => 'You must be logged in to use lists.', }; 
	return;
    }

    my $list = $self->retrieve_list($c, $list_id);

    $c->stash->{rest} = $list;
}

sub retrieve_list { 
    my $self = shift;
    my $c = shift;
    my $list_id = shift;

    my $q = "SELECT list_item_id, content from sgn_people.list join sgn_people.list_item using(list_id) WHERE list_id=?";

    my $h = $c->dbc->dbh()->prepare($q);
    $h->execute($list_id);
    my @list = ();
    while (my ($id, $content) = $h->fetchrow_array()) { 
	push @list, [ $id, $content ];
    }my $q = "SELECT list_item_id, content from sgn_people.list join sgn_people.list_item using(list_id) WHERE list_id=?";

    my $h = $c->dbc->dbh()->prepare($q);
    $h->execute($list_id);
    my @list = ();
    while (my ($id, $content) = $h->fetchrow_array()) { 
	push @list, [ $id, $content ];
    }
    return \@list;
}

sub new_list :Path('/list/new') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $name = $c->req->param("name");
    my $desc = $c->req->param("desc");


    my $user_id = $self->get_user($c);
    if (!$user_id) { 
	$c->stash->{rest} = { error => "You must be logged in to use lists", }; 
	return;
    }
	
    eval { 
	my $q = "INSERT INTO sgn_people.list (name, description, owner) VALUES (?, ?, ?)";
	my $h = $c->dbc->dbh->prepare($q);
	$h->execute($name, $desc, $user_id);
    };

    if ($@) { 
	$c->stash->{rest} = { error => "An error occurred, $@", };
	return;
    }
    else { 
	$c->stash->{rest}  = [ 1 ];
    }
}

sub available_lists : Path('/list/available') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $user_id = $self->get_user($c);
    if (!$user_id) { 
	$c->stash->{rest} = { error => "You must be logged in to use lists.", };
	return;
    }

    my $q = "SELECT list_id, name, description, count(distinct(list_item_id)) FROM sgn_people.list left join sgn_people.list_item using(list_id) WHERE owner=? GROUP BY list_id, name, description ORDER BY name";
    my $h = $c->dbc->dbh()->prepare($q);
    $h->execute($user_id);

    my @lists = ();
    while (my ($id, $name, $desc, $item_count) = $h->fetchrow_array()) { 
	push @lists, [ $id, $name, $desc, $item_count ] ;
    }
    $c->stash->{rest} = \@lists;
}

sub add_item :Path('/list/item/add') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $list_id = $c->req->param("list_id");
    my $element = $c->req->param("element");

    my $user_id = $self->get_user($c);
    if (!$user_id) { 
	$c->stash->{rest} = { error => "You must be logged in to add elements to a list" };
	return;
    }

    if (!$element) { 
	$c->stash->{rest} = { error => "You must provide an element to add to the list" };
	return;
    }
    
    if (!$list_id) { 
	$c->stash->{rest} = { error => "Please specify a list_id." };
	return;
    }

    eval { 
	my $iq = "INSERT INTO sgn_people.list_item (list_id, content) VALUES (?, ?)";
	my $ih = $c->dbc->dbh()->prepare($iq);
	$ih->execute($list_id, $element);
    };
    if ($@) { 
	$c->stash->{rest} = { error => "An error occurred: $@" };
	return;
    }
    else { 
	$c->stash->{rest} = [ "SUCCESS" ];
    }
}

sub delete_list :Path('/list/delete') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $list_id = $c->req->param("list_id");
    
    my $user_id = $self->get_user($c);
    if (!$user_id) { 
	$c->stash->{rest} = { error => "You must be logged in to delete a list" };
	return;
    }
    
    my $q = "DELETE FROM sgn_people.list WHERE list_id=?";
    
    eval { 
	my $h = $c->dbc->dbh()->prepare($q);
	$h->execute($list_id);
    };
    if ($@) { 
	$c->stash->{rest} = { error => "An error occurred while deleting list with id $list_id: $@" };
	return;
    }
    else { 
	$c->stash->{rest} =  [ 1 ];
    }
}


sub exists_list : Path('/list/exists') Args(0) { 
    my $self =shift;
    my $c = shift;
    my $name = $c->req->param("name");

    my $user_id = $self->get_user($c);
    if (!$user_id) { 
	$c->stash->{rest} = { error => 'You need to be logged in to use lists.' };
    }
    my $q = "SELECT list_id FROM sgn_people.list where name = ? and owner=?";
    my $h = $c->dbc->dbh()->prepare($q);
    $h->execute($name, $user_id);
    my ($list_id) = $h->fetchrow_array();

    if ($list_id) { 
	$c->stash->{rest} = { list_id => $list_id };
    }
    else { 
	$c->stash->{rest} = { list_id => undef };
    }
}

sub exists_item : Path('/list/exists_item') :Args(0) { 
    my $self =shift;
    my $c = shift;
    my $list_id = $c->req->param("list_id");
    my $name = $c->req->param("name");

    my $user_id = $self->get_user($c);
    if (!$user_id) { 
	$c->stash->{rest} = { error => 'You need to be logged in to use lists.' };
    }
    my $q = "SELECT list_item_id FROM sgn_people.list join sgn_people.list_item using(list_id) where list.list_id =? and content = ? and owner=?";
    my $h = $c->dbc->dbh()->prepare($q);
    $h->execute($list_id, $name, $user_id);
    my ($list_item_id) = $h->fetchrow_array();

    if ($list_item_id) { 
	$c->stash->{rest} = { list_item_id => $list_item_id };
    }
    else { 
	$c->stash->{rest} = { list_item_id => 0 };
    }
}
    
sub list_size : Path('/list/size') Args(0) { 
    my $self = shift;
    my $c = shift;
    my $list_id = $c->req->param("list_id"); 
    my $h = $c->dbc->dbh->prepare("SELECT count(*) from sgn_people.list_item WHERE list_id=?");
    $h->execute($list_id);
    my ($count) = $h->fetchrow_array();
    $c->stash->{rest} = { count => $count };
}    
    

sub remove_element :Path('/list/item/remove') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $list_id = $c->req->param("list_id");
    my $item_id = $c->req->param("item_id");
    
    
    my $h = $c->dbc->dbh()->prepare("DELETE FROM sgn_people.list_item where list_id=? and list_item_id=?");

    eval { 
	$h->execute($list_id, $item_id);
    };
    if ($@) { 
	$c->stash->{rest} = { error => "An error occurred. $@\n", };
	return;
    }
    $c->stash->{rest} = [ 1 ];
}

sub download_list :Path('/list/download') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $user_id = $self->get_user($c);
    if (!$user_id) { 
	$c->stash->{template} = 'generic_message.mas';
	$c->stash->{message} = 'You need to be logged in to download lists.';
	
	return;
    }

    my $list_id = $c->req->param("list_id");

    my $list = $self->retrieve_list($c, $list_id);
	
    $c->res->headers()->title("cassavabase_list\_$list_id");
    $c->res->content_type("application/text");

    $c->res->body(join "\n", map { $_->[1] }  @$list);

}
    
sub get_user { 
    my $self = shift;
    my $c = shift;

    my $user = $c->user;
 
    if ($user) { 
	my $user_object = $c->user->get_object();
	return $user_object->get_sp_person_id();
    }
    return undef;
}
    
