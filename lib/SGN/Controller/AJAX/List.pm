
package SGN::Controller::AJAX::List;

use Moose;

use List::MoreUtils qw | uniq |;
use CXGN::List::Validate;
use CXGN::List::Transform;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

sub get_list_action :Path('/list/get') Args(0) { 
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

sub get_list_data_action :Path('/list/data') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $list_id = $c->req->param("list_id");

    my $type_id = ""; # fIX this
    my $list_type = ""; #fix this
    my $error = $self->check_user($c, $list_id);
    if ($error) { 
	$c->stash->{rest} = { error => $error };
	return; 
    }

    my $list = $self->retrieve_list($c, $list_id);

    my $metadata = $self->get_list_metadata($c, $list_id);

    $c->stash->{rest} = { 
	list_id     => $list_id,
	type_id     => $metadata->{type_id},
	type_name   => $metadata->{list_type},
	elements    => $list,
    };			  
}


sub retrieve_contents :Path('/list/contents') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $list_id = shift;

    my $error = $self->check_user($c, $list_id);
    if ($error) { 
	$c->stash->{rest} = { error => $error };
	return;
    }

    my $q = "SELECT  content from sgn_people.list join sgn_people.list_item using(list_id) WHERE list_id=?";

    my $h = $c->dbc->dbh()->prepare($q);
    $h->execute($list_id);
    my @list = ();
    while (my ($content) = $h->fetchrow_array()) { 
	push @list, $content;
    }
    $c->stash->{rest} =  \@list;
}

sub get_list_metadata { 
    my $self = shift;
    my $c = shift;
    my $list_id = shift;
    my $q = "SELECT list.name, list.description, type_id, cvterm.name FROM sgn_people.list JOIN cvterm ON (type_id=cvterm_id) WHERE list_id=?";
    my $h = $c->dbc->dbh()->prepare($q);
    $h->execute($list_id);
    my ($name, $desc, $type_id, $list_type) = $h->fetchrow_array();
    return { name => $name,
	     description => $desc,
	     type_id => $type_id,
	     list_type => $list_type
    };
}

sub get_type_action :Path('/list/type') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $list_id = shift;

    my $data = $self->get_list_metadata($c, $list_id);
    
    $c->stash->{rest} = { type_id => $data->{type_id},
			  list_type => $data->{list_type},
    };
}

sub update_list_name_action :Path('/list/name/update') :Args(0) { 
    my $self = shift;
    my $c = shift;
    my $list_id = $c->req->param('list_id');
    my $name = $c->req->param('name');

    my $user_id = $self->get_user($c);
    my $error = $self->check_user($c, $list_id);

    if ($error) { 
	$c->stash->{rest} = { error => $error };
	return;
    }

    my $q = "SELECT list_id FROM sgn_people.list where name=? and owner=?";
    my $h = $c->dbc->dbh->prepare($q);
    $h->execute($name, $user_id);
    my ($old_list) = $h->fetchrow_array();
    if ($old_list) { 
	$c->stash->{rest} = { error => "The list name $name already exists. Please choose another name." };
	return;
    }

    $q = "UPDATE sgn_people.list SET name=? WHERE list_id=?"; #removed "my"
    $h = $c->dbc->dbh->prepare($q); #removed "my"


    eval { 
	$h->execute($name, $list_id);
    };
    
    if ($@) { 
	$c->stash->{rest} = { error => 'An error occurred when trying to update the name of the list.' };
	return;
    }

    $c->stash->{rest} = { success => 1 };

}

sub set_type :Path('/list/type') Args(2) { 
    my $self = shift;
    my $c = shift;
    my $list_id = shift;
    my $type = shift;

    my $user_id = $self->get_user($c);

    my $error = $self->check_user($c, $list_id);
    if ($error) { 
	$c->stash->{rest} = { error => $error };
	return;
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $rs = $schema->resultset("Cv::Cvterm")->search({ 'me.name' => $type }, { join => "cv" });
    if ($rs->count ==0) { 
	$c->stash->{rest}= { error => "The type specified does not exist" };
	return;
    }
    my $type_id = $rs->first->cvterm_id();

    my $q = "SELECT owner FROM sgn_people.list WHERE list_id=?";
    my $h = $c->dbc->dbh->prepare($q);
    $h->execute($list_id);

    my ($list_owner) = $h->fetchrow_array();

    if ($list_owner != $user_id) { 
	$c->stash->{rest} = { error => "Only the list owner can change the type of a list" };
	return;
    }

    eval { 
	$q = "UPDATE sgn_people.list SET type_id=? WHERE list_id=?";
	$h = $c->dbc->dbh->prepare($q);
	$h->execute($type_id, $list_id);
    };
    if ($@) { 
	$c->stash->{rest} = { error => "An error occurred. $@" };
	return;
    }
    
    $c->stash->{rest} = { success => 1 };
    
}

sub new_list_action :Path('/list/new') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $name = $c->req->param("name");
    my $desc = $c->req->param("desc");


    my $user_id = $self->get_user($c);
    if (!$user_id) { 
	$c->stash->{rest} = { error => "You must be logged in to use lists", }; 
	return;
    }
	
    my $new_list_id = 0;
    eval { 
	$new_list_id = $self->new_list($c, $name, $desc, $user_id);
    };

    if ($@) { 
	$c->stash->{rest} = { error => "An error occurred, $@", };
	return;
    }
    else { 
	$c->stash->{rest}  = { list_id => $new_list_id };
    }
}

sub all_types : Path('/list/alltypes') :Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $q = "SELECT cvterm_id, cvterm.name FROM cvterm JOIN cv USING(cv_id) WHERE cv.name = 'list_types' ";
    my $h = $c->dbc->dbh->prepare($q);
    $h->execute();
    my @all_types = ();
    while (my ($id, $name) = $h->fetchrow_array()) { 
	push @all_types, [ $id, $name ];
    }
    $c->stash->{rest} = \@all_types;

}

=head2 available_lists()

 Usage:
 Desc:          returns the available lists. Optionally, a 
                parameter "list_type" can be provided that will limit the 
                lists to the provided type.

 Ret:
 Args:
 Side Effects:  
 Example:

=cut

sub available_lists : Path('/list/available') Args(0) { 
    my $self = shift;
    my $c = shift;
    
    my $requested_type = $c->req->param("type");

    my $user_id = $self->get_user($c);
    if (!$user_id) { 
	$c->stash->{rest} = { error => "You must be logged in to use lists.", };
	return;
    }

    my $q = "SELECT list_id, list.name, description, count(distinct(list_item_id)), type_id, cvterm.name FROM sgn_people.list left join sgn_people.list_item using(list_id) LEFT JOIN cvterm ON (type_id=cvterm_id) WHERE owner=? GROUP BY list_id, list.name, description, type_id, cvterm.name ORDER BY list.name";
    my $h = $c->dbc->dbh()->prepare($q);
    $h->execute($user_id);

    my @lists = ();
    while (my ($id, $name, $desc, $item_count, $type_id, $type) = $h->fetchrow_array()) { 
	if ($requested_type) { 
	    if ($type && ($type eq $requested_type)) { 
		push @lists, [ $id, $name, $desc, $item_count, $type_id, $type ];
	    }
	}
	else { 
	    push @lists, [ $id, $name, $desc, $item_count, $type_id, $type ];
	}
    }
    $c->stash->{rest} = \@lists;
}

sub add_item :Path('/list/item/add') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $list_id = $c->req->param("list_id");
    my $element = $c->req->param("element");

    my $user_id = $self->get_user($c);
    
    my $error = $self->check_user($c, $list_id);
    if ($error) { 
	$c->stash->{rest} = { error => $error };
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
	$self->insert_element($c, $list_id, $element);
    };
    if ($@) { 
	$c->stash->{rest} = { error => "An error occurred: $@" };
	return;
    }
    else { 
	$c->stash->{rest} = [ "SUCCESS" ];
    }
}

sub add_bulk : Path('/list/add/bulk') Args(0) { 
    my $self = shift;
    my $c = shift;
    my $list_id = $c->req->param("list_id");
    my $elements = $c->req->param("elements");

    my $user_id = $self->get_user($c);
    
    my $error = $self->check_user($c, $list_id);
    if ($error) { 
	$c->stash->{rest} = { error => $error };
	return;
    }

    if (!$elements) { 
	$c->stash->{rest} = { error => "You must provide one or more elements to add to the list" };
	return;
    }

    my @elements = split "\t", $elements;

    #print STDERR "ADDING ELEMENTS: ".join(", ", @elements)."\n";

    my @duplicates = ();
    my $count = 0;
    my $iq = "INSERT INTO sgn_people.list_item (list_id, content) VALUES (?, ?)";
    my $ih = $c->dbc->dbh()->prepare($iq);
    
    print STDERR "Adding accessions ";
    
    foreach my $element (@elements) { 
	print STDERR ".";
	if ($self->exists_item($c, $list_id, $element)) { 
	    push @duplicates, $element;
	}
	else { 
	    $ih->execute($list_id, $element);	    
	    $count++;
	}
    }
    if (@duplicates) { 
	$c->stash->{rest} = { duplicates => \@duplicates };
    }
    $c->stash->{rest}->{success} = $count;

}

sub insert_element : Private { 
    my $self = shift;
    my $c = shift;
    my $list_id = shift;
    my $element = shift;

    my $iq = "INSERT INTO sgn_people.list_item (list_id, content) VALUES (?, ?)";
    my $ih = $c->dbc->dbh()->prepare($iq);
    $ih->execute($list_id, $element);
}

sub delete_list_action :Path('/list/delete') Args(0) { 
    my $self = shift;
    my $c = shift;

    my $list_id = $c->req->param("list_id");
    
    my $error = $self->check_user($c, $list_id);
    if ($error) {
	$c->stash->{rest} = { error => $error };
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


sub exists_list_action : Path('/list/exists') Args(0) { 
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

sub exists_item_action : Path('/list/exists_item') :Args(0) { 
    my $self =shift;
    my $c = shift;
    my $list_id = $c->req->param("list_id");
    my $name = $c->req->param("name");

    my $error = $self->check_user($c, $list_id);
    if ($error) { 
	$c->stash->{rest} = { error => $error };
	return;
    }

    my $user_id = $self->get_user($c);
    
    if ($self->get_list_owner($c, $list_id) != $user_id) { 
	$c->stash->{rest} = { error => "You have insufficient privileges to manipulate this list.", };
	return;
    }

    my $list_item_id = $self->exists_item($c, $list_id, $name);

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
    
sub validate : Path('/list/validate') Args(2) { 
    my $self = shift;
    my $c = shift;
    my $list_id = shift;
    my $type = shift;

    my $list = $self->retrieve_list($c, $list_id);

    my @flat_list = map { $_->[1] } @$list;

    my $lv = CXGN::List::Validate->new();
    my $data = $lv->validate($c->dbic_schema("Bio::Chado::Schema"), $type, \@flat_list);

    $c->stash->{rest} = $data;
}

sub transform :Path('/list/transform/') Args(2) { 
    my $self = shift;
    my $c = shift;
    my $list_id = shift;
    my $transform_name = shift;

    my $t = CXGN::List::Transform->new();

    my $data = $self->get_list_metadata($c, $list_id);

#    my $transform_name = $t->can_transform($data->{list_type}, $new_type);
#    if (!$transform_name) {
#	$c->stash->{rest} = { error => "Cannot transform $data->{list_type} into #$new_type\n", };
#	return;
 #   }
    
    my $list_data = $self->retrieve_list($c, $list_id);

    my @list_items = map { $_->[1] } @$list_data;

    my $result = $t->transform($c->dbic_schema("Bio::Chado::Schema"), $transform_name, \@list_items);

    if (exists($result->{missing}) && (scalar(@{$result->{missing}}) > 0)) { 
	$c->stash->{rest} = { error => "This lists contains elements that cannot be converted. Not converting list.", };
	return;
    }
	
    $c->stash->{rest} = $result;

}
    
sub replace_elements :Path('/list/item/replace') Args(2) { 
    my $self = shift;
    my $c = shift;

    my $list_id = shift;
    my $new_list = shift; # tab delimited new list elements

    

}

sub combine_lists : Path('/list/combine') Args(2) { 
    my $self = shift;
    my $c = shift;
    my $list1_id = shift;
    my $list2_id = shift;
    
    my $list1 = $self->get_list($c, $list1_id);
    my $list2 = $self->get_list($c, $list2_id);

    my $combined_list_id = $self->new_list(
	$c, 
	$list1->{name}."_".$list2->{name}, 
	$list1->{description}.", ".$list2->{description});

    my @combined_elements = (@{$list1->{elements}}, @{$list2->{elements}});
    
    my @unique_elements = uniq(@combined_elements);

    foreach my $item (@unique_elements) { 
	$self->add_item($c, $combined_list_id, $item);
    }
}

sub intersect_lists : Path('/list/intersect') Args(2) { 
    my $self = shift;
    my $c = shift;
    my $list1_id = shift;
    my $list2_id = shift;
    
    my $list1 = $self->get_list($c, $list1_id);
    my $list2 = $self->get_list($c, $list2_id);

    my $combined_list_id = $self->new_list(
	$c, 
	$list1->{name}."_".$list2->{name}."_intersect", 
	$list1->{description}.", ".$list2->{description});

    my @intersect_elements = ();

    my $list1_hashref; my $list2_hashref;
    map { $list1_hashref->{$_}=1 } @{$list1->{elements}};
    map { $list2_hashref->{$_}=1 } @{$list2->{elements}};

    foreach my $item (keys(%{$list1_hashref})) { 
	if (exists($list1_hashref->{$item}) && exists($list2_hashref->{$item})) { 
	    push @intersect_elements, $item;
	}
    }
    
    my @unique_elements = uniq(@intersect_elements);

    foreach my $item (@unique_elements) { 
	$self->add_item($c, $combined_list_id, $item);
    }
}


sub remove_element_action :Path('/list/item/remove') Args(0) { 
    my $self = shift;
    my $c = shift;
 
    my $list_id = $c->req->param("list_id");
    my $item_id = $c->req->param("item_id");

    my $error = $self->check_user($c, $list_id);

    if ($error) { 
	$c->stash->{rest} = { error => $error };
	return;
    }
    
    my $response = $self->remove_element($c, $list_id, $item_id);
    
    $c->stash->{rest} = $response;
    
}

sub new_list : Private { 
    my $self = shift;
    my $c = shift;
    my ($name, $desc, $owner) = @_;

    my $user_id = $self->get_user($c);

    my $q = "INSERT INTO sgn_people.list (name, description, owner) VALUES (?, ?, ?)";
    my $h = $c->dbc->dbh->prepare($q);
    $h->execute($name, $desc, $user_id);
    
    $q = "SELECT currval('sgn_people.list_list_id_seq')";
    $h = $c->dbc->dbh->prepare($q);
    $h->execute();
    my ($new_list_id) = $h->fetchrow_array();
    
    return $new_list_id;
    
}

sub get_list : Private { 
    my $self = shift;
    my $c = shift;
    my $list_id = shift;

    my $list = $self->retrieve_list($c, $list_id);

    my ($name, $desc, $type_id, $list_type) = $self->get_list_metadata($c, $list_id);

    $c->stash->{rest} = { 
	name        => $name,
	description => $desc,
	type_id     => $type_id,
	type_name   => $list_type,
	elements    => $list,
    };
}

sub retrieve_list : Private { 
    my $self = shift;
    my $c = shift;
    my $list_id = shift;
    
    my $error = $self->check_user($c, $list_id);
    if ($error) { 
	$c->stash->{rest} = { error => $error };
	return;
    }

    my $q = "SELECT list_item_id, content from sgn_people.list join sgn_people.list_item using(list_id) WHERE list_id=?";

    my $h = $c->dbc->dbh()->prepare($q);
    $h->execute($list_id);
    my @list = ();
    while (my ($id, $content) = $h->fetchrow_array()) { 
	push @list, [ $id, $content ];
    }
    return \@list;
}


sub remove_element : Private { 
    my $self = shift;
    my $c = shift;
    my $list_id = shift;
    my $item_id = shift;

    my $h = $c->dbc->dbh()->prepare("DELETE FROM sgn_people.list_item where list_id=? and list_item_id=?");

    eval { 
	$h->execute($list_id, $item_id);
    };
    if ($@) { 
	
	return { error => "An error occurred while attempting to delete item $item_id" };
    }
    else { 
	return { success => 1 };
    }
 
}

sub exists_item : Private { 
    my $self = shift;
    my $c = shift;
    my $list_id = shift;
    my $item = shift;

    my $q = "SELECT list_item_id FROM sgn_people.list join sgn_people.list_item using(list_id) where list.list_id =? and content = ?";
    my $h = $c->dbc->dbh()->prepare($q);
    $h->execute($list_id, $item);
    my ($list_item_id) = $h->fetchrow_array();

    return $list_item_id;
}

sub get_list_owner : Private { 
    my $self = shift;
    my $c = shift;
    my $list_id = shift;

    my $q = "SELECT owner FROM sgn_people.list WHERE list_id=?";
    my $h = $c->dbc->dbh()->prepare($q);
    $h->execute($list_id);
    my ($owner_id) = $h->fetchrow_array();
    return $owner_id;
}
    
sub get_user : Private { 
    my $self = shift;
    my $c = shift;

    my $user = $c->user();
 
    if ($user) { 
	my $user_object = $c->user->get_object();
	return $user_object->get_sp_person_id();
    }
    return undef;
}
    
sub check_user : Private { 
    my $self = shift;
    my $c = shift;
    my $list_id = shift;

    my $user_id = $self->get_user($c);

    my $error = "";

    if (!$user_id) { 
	$error = "You must be logged in to delete a list";

    }

    if ($self->get_list_owner($c, $list_id) != $user_id) { 
	$error = "You have insufficient privileges to manipulate this list.";
	
    }
    return $error;

}


