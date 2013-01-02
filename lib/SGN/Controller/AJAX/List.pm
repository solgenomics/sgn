
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

    my $name = $c->req->param("name");

    my $user_id = $self->get_user($c);
    if (!$user_id) { 
	$c->stash->{rest} = { error => 'You must be logged in to use lists.', }; 
	return;
    }

    my $q = "SELECT list_item_id, content from sgn_people.list join sgn_people.list_item using(list_id) WHERE name=?";

    my $h = $c->dbc->dbh()->prepare($q);
    $h->execute($name);
    my @list = ();
    while (my ($id, $content) = $h->fetchrow_array()) { 
	push @list, [ $id, $content ];
    }

    $c->stash->{rest} = \@list;

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

    my $q = "SELECT list_id, name, description FROM sgn_people.list WHERE owner=?";
    my $h = $c->dbc->dbh()->prepare($q);
    $h->execute($user_id);

    my @lists = ();
    while (my ($id, $name, $desc) = $h->fetchrow_array()) { 
	push @lists, [ $id, $name, $desc ] ;

    }

    $c->stash->{rest} = \@lists;
    

}

sub add_element :Path('/list/add_element') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $name = $c->req->param("name");
    my $element = $c->req->param("element");

    my $user_id = $self->get_user($c);
    if (!$user_id) { 
	$c->stash->{rest} = { error => "You must be logged in the add elements to a list" };
	return;
    }

    if (!$element) { 
	$c->stash->{rest} = { error => "You must provide an element to add to the list" };
	return;
    }

    my $list_id = $self->exists_list($c, $name);
    
    if (!$list_id) { 
	$c->stash->{rest} = { error => "List $name does not exist. Please create the list first before adding elements." };
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

    my $name = $c->req->param("name");
    
    my $user_id = $self->get_user($c);
    if (!$user_id) { 
	$c->stash->{rest} = { error => "You must be logged in to delete a list" };
	return;
    }
    
    my $q = "DELETE FROM sgn_people.list WHERE name=?";
    
    eval { 
	my $h = $c->dbc->dbh()->prepare($q);
	$h->execute($name);
    };
    if ($@) { 
	$c->stash->{rest} = { error => "An error occurred while deleting list $name: $@" };
	return;
    }
    else { 
	$c->stash->{rest} =  [ 1 ];
    }


    
    

}


sub exists_list { 
    my $self =shift;
    my $c = shift;
    my $name = shift;

    my $user_id = $self->get_user($c);
    if (!$user_id) { return 0; }
    my $q = "SELECT list_id FROM sgn_people.list where name = ? and owner=?";
    my $h = $c->dbc->dbh()->prepare($q);
    $h->execute($name, $user_id);
    my ($list_id) = $h->fetchrow_array();

    if ($list_id) { 
	return $list_id;
    }
    else { 
	return 0;
    }
}
    
    
    

sub remove_element :Path('/list/remove_element') Args(0) { 
    my $self = shift;
    my $c = shift;

}
    


sub get_user { 
    my $self = shift;
    my $c = shift;

    my $user = $c->user;
    
    my $user_object = $c->user->get_object();
    
    return $user_object->get_sp_person_id();

}
    
