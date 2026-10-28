
=head1 NAME

CXGN::List - class that deals with website lists

=head1 SYNOPSIS

 my $list = CXGN::List->new( { dbh => $dbh, list_id => 34 } );

 my $name = $list->name();
 my $elements = $list->elements();
 my $owner_id = $list->owner();
 my $type = $list->type();
 $list->remove_element('blabla');
 $list->add_bulk(['blabla', 'bla']);


Class function (without instantiation):

 my $new_list_id = CXGN::List::create_list($dbh, $name, $desc, $owner);
 my $lists = CXGN::List::available_lists($dbh);
 my $list_id = CXGN::List::exists_list($dbh, $name, $owner);
 CXGN::List::delete_list($dbh, $list_id);

=head1 AUTHOR

 Lukas Mueller <lam87@cornell.edu>

=cut


package CXGN::List;

use Moose;
use SGN::I18N ();
use Data::Dumper;
use CXGN::Stock::Seedlot;

has 'i18n' => ( isa => 'Maybe[SGN::I18N]', is => 'ro', default => undef );

has 'dbh' => ( isa => 'DBI::db',
	       is => 'rw',
	       required => 1,
    );

has 'list_id' => (isa => 'Int',
		  is => 'ro',
		  required => 1,
    );

has 'owner' => (isa => 'Maybe[Int]',
		is => 'rw',
    );

has 'name' => (isa => 'Str',
	       is => 'rw',
    );

has 'description' => (isa => 'Str',
		      is => 'rw',
    );

has 'type' => (isa => 'Str',
	       is => 'rw',
    );

has 'elements' => (isa => 'ArrayRef',
		   is => 'rw',
    );

has 'schema' => (isa => 'Bio::Chado::Schema', is => 'rw');

has 'phenome_schema' => (isa => 'CXGN::Phenome::Schema',is => 'rw');

has 'create_date' => (isa => 'Str',
    is => 'rw',
);

has 'modified_date' => (isa => 'Str',
    is => 'rw',
);

sub _list_error_fallback {
    my ($source, $vars) = @_;
    $vars ||= {};
    $source =~ s/%\{([A-Za-z_][A-Za-z0-9_]*)\}/exists($vars->{$1}) ? (defined($vars->{$1}) ? "$vars->{$1}" : '') : "%{$1}"/ge;
    return $source;
}


# class method: Use like so: CXGN::List::create_list
sub create_list {
    my $dbh = shift;

    my ($name, $desc, $owner) = @_;
    my $new_list_id;
    eval {
    my $q = "INSERT INTO sgn_people.list (name, description, owner) VALUES (?, ?, ?) RETURNING list_id";
    my $h = $dbh->prepare($q);
    $h->execute($name, $desc, $owner);
    ($new_list_id) = $h->fetchrow_array();
    print STDERR "NEW LIST using returning = $new_list_id\n";

    #$q = "SELECT list.name, list.description, type_id, cvterm.name, list_id FROM sgn_people.list LEFT JOIN cvterm ON (type_id=cvterm_id)";
    #$h = $dbh->prepare($q);
    #$h->execute();
    #while (my @data = $h->fetchrow_array()) {
	#print STDERR join ", ", @data;
	#print STDERR "\n";
    #}
    ###END TEST
    };
    if ($@) {
	print "AN ERROR OCCURRED: $@\n";
	return;
    }
    return $new_list_id;
}

# class method! see above
sub all_types {
    my $dbh = shift;
    my $q = "SELECT cvterm_id, cvterm.name FROM cvterm JOIN cv USING(cv_id) WHERE cv.name = 'list_types' ";
    my $h = $dbh->prepare($q);
    $h->execute();
    my @all_types = ();
    while (my ($id, $name) = $h->fetchrow_array()) {
        if ($name ne 'catalog_items') {
            push @all_types, [ $id, $name ];
        }
    }
    return \@all_types;

}

# class method! (see above)
#
sub available_lists {
    my $dbh = shift;
    my $owner = shift;
    my $requested_type = shift;

    my $q = "SELECT list_id, list.name, description, count(distinct(list_item_id)), type_id, cvterm.name, is_public, list.create_date, list.modified_date FROM sgn_people.list left join sgn_people.list_item using(list_id) LEFT JOIN cvterm ON (type_id=cvterm_id) WHERE owner=? GROUP BY list_id, list.name, description, type_id, cvterm.name, is_public, list.create_date, list.modified_date ORDER BY list.name";
    my $h = $dbh->prepare($q);
    $h->execute($owner);

    my @lists = ();
    while (my ($id, $name, $desc, $item_count, $type_id, $type, $public, $timestamp, $modify_timestamp) = $h->fetchrow_array()) {
	if ($requested_type) {
	    if ($type && ($type eq $requested_type)) {
		push @lists, [ $id, $name, $desc, $item_count, $type_id, $type, $public, $timestamp, $modify_timestamp ];
	    }
	}
	else {
	    push @lists, [ $id, $name, $desc, $item_count, $type_id, $type, $public, $timestamp, $modify_timestamp ];
	}
    }
    return \@lists;
}

sub available_public_lists {
    my $dbh = shift;
    my $requested_type = shift;

    my $q = "SELECT list_id, list.name, description, count(distinct(list_item_id)), type_id, cvterm.name, sp_person.username, list.create_date, list.modified_date FROM sgn_people.list LEFT JOIN sgn_people.sp_person AS sp_person ON (sgn_people.list.owner=sp_person.sp_person_id) LEFT JOIN sgn_people.list_item using(list_id) LEFT JOIN cvterm ON (type_id=cvterm_id) WHERE is_public='t' GROUP BY list_id, list.name, description, type_id, cvterm.name, sp_person.username, list.create_date, list.modified_date ORDER BY list.name";
    my $h = $dbh->prepare($q);
    $h->execute();

    my @lists = ();
    while (my ($id, $name, $desc, $item_count, $type_id, $type, $username, $timestamp, $modify_timestamp) = $h->fetchrow_array()) {
        if ($requested_type) {
            if ($type && ($type eq $requested_type)) {
                push @lists, [ $id, $name, $desc, $item_count, $type_id, $type, $username, $timestamp, $modify_timestamp];
            }
        }
        else {
            push @lists, [ $id, $name, $desc, $item_count, $type_id, $type, $username, $timestamp, $modify_timestamp];
        }
    }
    return \@lists;
}

sub all_lists {
    my $dbh = shift;
    my $owner = shift;
    my $requested_type = shift;

    my $h;
    if ($owner) {
        my $q = "SELECT list_id, list.name, description, count(distinct(list_item_id)), type_id, cvterm.name, is_public, list.create_date, list.modified_date FROM sgn_people.list left join sgn_people.list_item using(list_id) LEFT JOIN cvterm ON (type_id=cvterm_id) WHERE owner=? GROUP BY list_id, list.name, description, type_id, cvterm.name, is_public, list.create_date, list.modified_date ORDER BY list.name";
        $h = $dbh->prepare($q);
        $h->execute($owner);
    } else {
        my $q = "SELECT list_id, list.name, description, count(distinct(list_item_id)), type_id, cvterm.name, is_public, list.create_date, list.modified_date FROM sgn_people.list left join sgn_people.list_item using(list_id) LEFT JOIN cvterm ON (type_id=cvterm_id) GROUP BY list_id, list.name, description, type_id, cvterm.name, is_public, list.create_date, list.modified_date ORDER BY list.name";
        $h = $dbh->prepare($q);
        $h->execute();
    }

    my @lists = ();
    while (my ($id, $name, $desc, $item_count, $type_id, $type, $public, $timestamp, $modify_timestamp) = $h->fetchrow_array()) {
        if ($requested_type) {
            if ($type && ($type eq $requested_type)) {
                push @lists, [ $id, $name, $desc, $item_count, $type_id, $type, $public, $timestamp, $modify_timestamp ];
            }
        }
        else {
            push @lists, [ $id, $name, $desc, $item_count, $type_id, $type, $public, $timestamp, $modify_timestamp ];
        }
    }
    return \@lists;
}

sub delete_list {
    my $dbh = shift;
    my $list_id = shift;
    my SGN::I18N $delete_list_i18n = shift;

    my $q = "DELETE FROM sgn_people.list WHERE list_id=?";

    eval {
	my $h = $dbh->prepare($q);
	$h->execute($list_id);
    };
    if ($@) {
        my $source = "An error occurred while deleting list with id %{id}: %{detail}";
        return $delete_list_i18n ? $delete_list_i18n->p("lists.model.delete_failed", "An error occurred while deleting list with id %{id}: %{detail}", {id => $list_id, detail => $@}) : _list_error_fallback($source, {id => $list_id, detail => $@});
    }
    return 0;
}


sub exists_list {
    my $dbh = shift;
    my $name = shift;
    my $owner = shift;

    my $q = "SELECT list_id, cvterm.name FROM sgn_people.list AS list LEFT JOIN cvterm ON (type_id=cvterm_id) WHERE list.name=? AND (list.owner=? OR list.is_public=TRUE)";
    my $h = $dbh->prepare($q);
    $h->execute($name, $owner);
    my ($list_id, $list_type) = $h->fetchrow_array();

    if ($list_id) {
        return { list_id => $list_id, list_type => $list_type };
    }
    return { list_id => undef };
}

around 'BUILDARGS' => sub {
    my $orig = shift;
    my $class = shift;
    my $args = shift;

    my $q = "SELECT content from sgn_people.list join sgn_people.list_item using(list_id) WHERE list_id=? ORDER BY list_item_id ASC;";

    my $h = $args->{dbh}->prepare($q);
    $h->execute($args->{list_id});
    my @list = ();
    while (my ($content) = $h->fetchrow_array()) {
	push @list, $content;
    }
    $args->{elements} = \@list;

    $q = "SELECT list.name, list.description, type_id, cvterm.name, owner FROM sgn_people.list LEFT JOIN cvterm ON (type_id=cvterm_id) WHERE list_id=?";
    $h = $args->{dbh}->prepare($q);
    $h->execute($args->{list_id});
    my ($name, $desc, $type_id, $list_type, $owner) = $h->fetchrow_array();

    $args->{name} = $name || '';
    $args->{description} = $desc || '';
    $args->{type} = $list_type || '';
    $args->{owner} = $owner;

    return $class->$orig($args);
};

after 'name' => sub {
    my $self = shift;
    my $name = shift;
    my SGN::I18N $name_i18n = $self->i18n;

    if (!$name) { return; }

    my $q = "SELECT list_id FROM sgn_people.list where name=? and owner=?";
    my $h = $self->dbh->prepare($q);
    $h->execute($name, $self->owner());
    my ($old_list) = $h->fetchrow_array();
    if ($old_list) {
        my $source = "The list name %{name} already exists. Please choose another name.";
        return $name_i18n ? $name_i18n->p("lists.model.name_exists", "The list name %{name} already exists. Please choose another name.", {name => $name}) : _list_error_fallback($source, {name => $name});
    }

    $q = "UPDATE sgn_people.list SET name=? WHERE list_id=?"; #removed "my"
    $h = $self->dbh->prepare($q);
    eval {
        $h->execute($name, $self->list_id());
    };
    if ($@) {
        my $source = "An error occurred updating the list name (%{detail})";
        return $name_i18n ? $name_i18n->p("lists.model.name_update_failed", "An error occurred updating the list name (%{detail})", {detail => $@}) : _list_error_fallback($source, {detail => $@});
    }
    return 0;
};

after 'type' => sub {
    my $self = shift;
    my $type = shift;
    my SGN::I18N $type_i18n = $self->i18n;

    if (!$type) { return; }

    my $q1 = "SELECT cvterm_id FROM cvterm WHERE name =?";
    my $h1 = $self->dbh->prepare($q1);
    $h1->execute($type);
    my ($cvterm_id) =$h1->fetchrow_array();
    if (!$cvterm_id) {
        my $source = "The specified type does not exist";
        return $type_i18n ? $type_i18n->p("lists.model.type_not_found", "The specified type does not exist") : $source;
    }

    my $q = "SELECT owner FROM sgn_people.list WHERE list_id=?";
    my $h = $self->dbh()->prepare($q);
    $h->execute($self->list_id);

    eval {
			$q = "UPDATE sgn_people.list SET type_id=? WHERE list_id=?";
			$h = $self->dbh->prepare($q);
			$h->execute($cvterm_id, $self->list_id);
    };
    if ($@) {
			return "An error occurred while updating the type of list ".self->list_id." to $type. $@";
    }
    return 0;
};

after 'description' => sub {
    my $self = shift;
    my $description = shift;
    my SGN::I18N $description_i18n = $self->i18n;

    if (!$description) {
	#print STDERR "NO desc provided... skipping!\n";
	return;
    }

    my $q = "UPDATE sgn_people.list SET description=? WHERE list_id=?";
    my $h = $self->dbh->prepare($q);
    eval {
        $h->execute($description, $self->list_id());
    };
    if ($@) {
        my $source = "An error occurred updating the list description (%{detail})";
        return $description_i18n ? $description_i18n->p("lists.model.description_update_failed", "An error occurred updating the list description (%{detail})", {detail => $@}) : _list_error_fallback($source, {detail => $@});
    }
    return 0;
};


sub add_element {
    my $self = shift;
    my $element = shift;
    my SGN::I18N $add_element_i18n = $self->i18n;
    #remove trailing spaces
    $element =~ s/^\s+|\s+$//g;
    if (!$element) {
            my $source = "Empty list elements are not allowed";
            return $add_element_i18n ? $add_element_i18n->p("lists.model.empty_element", "Empty list elements are not allowed") : $source;
    }
    if ($self->exists_element($element)) {
            my $source = "The element %{element} already exists";
            return $add_element_i18n ? $add_element_i18n->p("lists.model.element_exists", "The element %{element} already exists", {element => $element}) : _list_error_fallback($source, {element => $element});
    }

    my $iq = "INSERT INTO sgn_people.list_item (list_id, content) VALUES (?, ?)";
    my $ih = $self->dbh()->prepare($iq);
    eval {
			$ih->execute($self->list_id(), $element);
    };
    if ($@) {
        print STDERR Dumper $@;
                my $source = "An error occurred storing the element %{element} (%{detail})";
                return $add_element_i18n ? $add_element_i18n->p("lists.model.store_element_failed", "An error occurred storing the element %{element} (%{detail})", {element => $element, detail => $@}) : _list_error_fallback($source, {element => $element, detail => $@});
    }

		eval {
    	my $q = "UPDATE sgn_people.list SET modified_date = now() WHERE list_id=?";
    	my $h = $self->dbh()->prepare($q);
    	$h->execute($self->list_id());
		};


    my $elements = $self->elements();
    push @$elements, $element;
    $self->elements($elements);
    return 0;
}

sub remove_element {
    my $self = shift;
    my $element = shift;
    my SGN::I18N $remove_element_i18n = $self->i18n;

    my $h = $self->dbh()->prepare("DELETE FROM sgn_people.list_item where list_id=? and content=?");

    eval {
	$h->execute($self->list_id(), $element);
    };
    if ($@) {

        my $source = "An error occurred while attempting to delete item %{element}";
        return $remove_element_i18n ? $remove_element_i18n->p("lists.model.delete_element_failed", "An error occurred while attempting to delete item %{element}", {element => $element}) : _list_error_fallback($source, {element => $element});
    }

    eval {
    	my $q = "UPDATE sgn_people.list SET modified_date = now() WHERE list_id=?";
    	my $h1 = $self->dbh()->prepare($q);
    	$h1->execute($self->list_id());
    };

    my $elements = $self->elements();

    # the following loop was refactored from a grep statement, as lists sometimes contain
    # json data and gets interpreted wrong using grep, leading to errors. For example,
    # in some lists, usernames are stored, and when they contain dashes, an error occurs
    # as it is not legal regexp. See issue: https://github.com/solgenomics/sgn/issues/5689
    
    my @clean;
    foreach my $e (@$elements) {
	if ($e ne $element) { 
	    push @clean, $e;
	}
    }
    
    $self->elements(\@clean);
    return 0;
}

sub remove_element_by_id {
    my $self = shift;
    my $element_id = shift;
    my SGN::I18N $remove_element_id_i18n = $self->i18n;
    my $h = $self->dbh()->prepare("SELECT content  FROM sgn_people.list_item where list_id=? and list_item_id=?");

    eval {
	$h->execute($self->list_id(), $element_id);
    };
    if ($@) {
        my $source = "An error occurred while attempting to delete item %{id}";
        return $remove_element_id_i18n ? $remove_element_id_i18n->p("lists.model.delete_element_id_failed", "An error occurred while attempting to delete item %{id}", {id => $element_id}) : _list_error_fallback($source, {id => $element_id});
    }
    my ($element) = $h->fetchrow_array();

    if (my $error = $self->remove_element($element)) {
	return $error;
    }

    return 0;
}

sub update_element_by_id {
	my $self = shift;
	my $element_id = shift;
	my $content = shift;
    my SGN::I18N $update_element_id_i18n = $self->i18n;
	my $h = $self->dbh()->prepare("UPDATE sgn_people.list_item SET content=? where list_id=? and list_item_id=?");

	eval {
		$h->execute($content, $self->list_id(), $element_id);
	};
	if ($@) {
        my $source = "An error occurred while attempting to update item %{id}";
        return $update_element_id_i18n ? $update_element_id_i18n->p("lists.model.update_element_id_failed", "An error occurred while attempting to update item %{id}", {id => $element_id}) : _list_error_fallback($source, {id => $element_id});
	}

	eval {
		my $q = "UPDATE sgn_people.list SET modified_date = now() WHERE list_id=?";
		my $h1 = $self->dbh()->prepare($q);
		$h1->execute($self->list_id());
	};

	return;
}

sub replace_by_name {
	my $self = shift;
	my $item_name = shift;
	my $new_name = shift;
    my SGN::I18N $replace_element_i18n = $self->i18n;
	my $h = $self->dbh()->prepare("UPDATE sgn_people.list_item SET content=? where list_id=? and content=?");

	eval {
		$h->execute($new_name, $self->list_id(), $item_name);
	};
	if ($@) {
        my $source = "An error occurred while attempting to update item %{item}";
        return $replace_element_i18n ? $replace_element_i18n->p("lists.model.replace_element_failed", "An error occurred while attempting to update item %{item}", {item => $item_name}) : _list_error_fallback($source, {item => $item_name});
	}

	eval {
		my $q = "UPDATE sgn_people.list SET modified_date = now() WHERE list_id=?";
		my $h1 = $self->dbh()->prepare($q);
		$h1->execute($self->list_id());
	};

	return;
}

sub remove_by_name {
	my $self = shift;
	my $item_name = shift;
    my SGN::I18N $remove_element_name_i18n = $self->i18n;
	my $h = $self->dbh()->prepare("DELETE FROM sgn_people.list_item WHERE list_id=? and content=?");

	eval {
		$h->execute($self->list_id(), $item_name);
	};
	if ($@) {
        my $source = "An error occurred while attempting to remove item %{item}";
        return $remove_element_name_i18n ? $remove_element_name_i18n->p("lists.model.remove_element_failed", "An error occurred while attempting to remove item %{item}", {item => $item_name}) : _list_error_fallback($source, {item => $item_name});
	}

	eval {
		my $q = "UPDATE sgn_people.list SET modified_date = now() WHERE list_id=?";
		my $h1 = $self->dbh()->prepare($q);
		$h1->execute($self->list_id());
	};

	return;
}

sub list_size {
    my $self = shift;

    my $h = $self->dbh->prepare("SELECT count(*) from sgn_people.list_item WHERE list_id=?");
    $h->execute($self->list_id());
    my ($count) = $h->fetchrow_array();
    return $count;
}

sub toggle_public {
    my $self = shift;

    my $h = $self->dbh->prepare("SELECT is_public FROM sgn_people.list WHERE list_id=?");
    $h->execute($self->list_id());
    my $public = $h->fetchrow_array();

    my $rows_affected;
    if ($public == 0) {
	my $h = $self->dbh->prepare("UPDATE sgn_people.list SET is_public='t' WHERE list_id=?");
	$h->execute($self->list_id());
	$rows_affected = $h->rows;
    } elsif ($public == 1) {
	my $h = $self->dbh->prepare("UPDATE sgn_people.list SET is_public='f' WHERE list_id=?");
	$h->execute($self->list_id());
	$rows_affected = $h->rows;
    }
    return ($public, $rows_affected);
}

sub make_public {
    my $self = shift;

	my $h = $self->dbh->prepare("UPDATE sgn_people.list SET is_public='t' WHERE list_id=?");
	$h->execute($self->list_id());
	my $rows_affected = $h->rows;
    return $rows_affected;
}

sub make_private {
    my $self = shift;

	my $h = $self->dbh->prepare("UPDATE sgn_people.list SET is_public='f' WHERE list_id=?");
	$h->execute($self->list_id());
	my $rows_affected = $h->rows;
    return $rows_affected;
}

sub copy_public {
    my $self = shift;
    my $user_id = shift;

    my $h = $self->dbh->prepare("INSERT INTO sgn_people.list (name, description, owner, type_id) SELECT name, description, ?, type_id FROM sgn_people.list as old WHERE old.list_id=? RETURNING list_id");
    $h->execute($user_id, $self->list_id());
    my $list_id = $h->fetchrow_array();

	$h = $self->dbh->prepare("SELECT content FROM sgn_people.list_item WHERE list_id=?");
	$h->execute($self->list_id());
	my @elements;
	while (my $el = $h->fetchrow_array) {
		push @elements, $el;
	}

	$self->add_bulk(\@elements, $list_id);

    return $list_id;
}

sub check_if_public {
    my $self = shift;
    my $h = $self->dbh->prepare("SELECT is_public FROM sgn_people.list WHERE list_id=?");
    $h->execute($self->list_id());
    my $public = $h->fetchrow_array();
    return $public;
}

sub exists_element {
    my $self =shift;
    my $item = shift;

    my $q = "SELECT list_item_id FROM sgn_people.list join sgn_people.list_item using(list_id) where list.list_id =? and content = ?";
    my $h = $self->dbh()->prepare($q);
    $h->execute($self->list_id(), $item);
    my ($list_item_id) = $h->fetchrow_array();
    return $list_item_id;
}

sub type_id {
    my $self =shift;

    my $q = "SELECT type_id FROM sgn_people.list WHERE list_id=?";
    my $h = $self->dbh()->prepare($q);
    $h->execute($self->list_id());
    my ($type_id) = $h->fetchrow_array();
    return $type_id;
}

sub retrieve_elements_with_ids {
    my $self = shift;
    my $list_id = shift;

    my $q = "SELECT list_item_id, content from sgn_people.list_item  WHERE list_id=? ORDER BY list_item_id ASC;";

    my $h = $self->dbh()->prepare($q);
    $h->execute($list_id);
    my @list = ();
    while (my ($id, $content) = $h->fetchrow_array()) {
	push @list, [ $id, $content ];
    }
    return \@list;
}

sub retrieve_elements {
    my $self = shift;
    my $list_id = shift;

    my $q = "SELECT list_item_id, content from sgn_people.list_item  WHERE list_id=? ORDER BY list_item_id ASC;";

    my $h = $self->dbh()->prepare($q);
    $h->execute($list_id);
    my @list = ();
    while (my ($item_id, $content) = $h->fetchrow_array()) {
        push @list, $content;
    }
    return \@list;
}

sub add_bulk {
	my $self = shift;
	my $elements = shift;
    my SGN::I18N $add_bulk_i18n = $self->i18n;
	my $list_id = shift // $self->list_id();
	my %elements_in_list;
	my @elements_added;
	my @duplicates;
	s/^\s+|\s+$//g for @$elements;
	#print STDERR Dumper $elements;

	my $q = "SELECT content FROM sgn_people.list join sgn_people.list_item using(list_id) where list.list_id =?";
	my $h = $self->dbh()->prepare($q);
	$h->execute($list_id);
	while (my $list_content = $h->fetchrow_array()) {
		$elements_in_list{$list_content} = 1;
	}

	$q = "SELECT list_item_id FROM sgn_people.list_item ORDER BY list_item_id DESC LIMIT 1";
	$h = $self->dbh()->prepare($q);
	$h->execute();
	my $list_item_id = $h->fetchrow_array() + 1;

	my $iq = "INSERT INTO sgn_people.list_item (list_item_id, list_id, content) VALUES";

	my $count = 0;
	eval {
		$self->dbh()->begin_work;

		my @values;
		foreach (@$elements) {
			if ($_ && !exists $elements_in_list{$_}){
				my $content = $_;
				$content =~ s/\'/\'\'/g;
				push @values, [$list_item_id, $list_id, $content];
				$elements_in_list{$content} = 1;
				push @elements_added, $content;
				$list_item_id++;
				$count++;
			} else {
				push @duplicates, $_;
			}
		}

		my $step = 1;
		my $num_values = scalar(@values);
		foreach (@values) {
			if ($step < $num_values) {
				$iq = $iq." (".$_->[0].",".$_->[1].",'".$_->[2]."'),";
			} else {
				$iq = $iq." (".$_->[0].",".$_->[1].",'".$_->[2]."');";
			}
			$step++;
		}
		#print STDERR Dumper $iq;
		if ($count>0){
			$self->dbh()->do($iq);
		}
		$self->dbh()->commit;
	};
	if ($@) {
		$self->dbh()->rollback;
        my $source = "An error occurred in bulk addition to list. (%{detail})";
        return {error => $add_bulk_i18n ? $add_bulk_i18n->p("lists.model.bulk_add_failed", "An error occurred in bulk addition to list. (%{detail})", {detail => $@}) : _list_error_fallback($source, {detail => $@})};
	}

	eval {
		my $q = "UPDATE sgn_people.list SET modified_date = now() WHERE list_id=?";
		my $h1 = $self->dbh()->prepare($q);
		$h1->execute($list_id);
	};

	$elements = $self->elements();
	push @$elements, \@elements_added;
	$self->elements($elements);

	my %response = (count => $count, duplicates => \@duplicates);
	return \%response;
}

sub delete_bulk {
    my $self = shift;
    my $item_ids = shift;
    my $items_ids_sql = join ',', @$item_ids;

    my $q = "DELETE FROM sgn_people.list_item WHERE list_id=? AND list_item_id IN ($items_ids_sql)";
    my $h = $self->dbh()->prepare($q);
    $h->execute($self->list_id());
    return;
}

sub sort_items {
    no warnings 'uninitialized';
    my $self = shift;
    my $sort = shift;
    my $items = $self->retrieve_elements_with_ids($self->list_id);
    my @contents;
    my @item_ids;
    foreach (@$items){
        push @item_ids, $_->[0];
        push @contents, $_->[1];
    }
    my @sorted;
    if ($sort eq 'ASC'){
        @sorted = map  { $_->[0] }
            sort { $a->[1] <=> $b->[1] }
            map  { [$_, $_=~/(\d+)/ ] }
            @contents;
    } elsif ($sort eq 'DESC'){
        @sorted = map  { $_->[0] }
            sort { $b->[1] <=> $a->[1] }
            map  { [$_, $_=~/(\d+)/ ] }
            @contents;
    } else {
        return;
    }

    $self->delete_bulk(\@item_ids);
    $self->add_bulk(\@sorted, $self->list_id);
    return 1;
}


sub seedlot_list_details {
    my $self = shift;
    my $schema = $self->schema();
    my $phenome_schema = $self->phenome_schema();
    my $items = $self->elements();
    my @seedlot_names = @$items;
    my @seedlot_ids;
    my @seedlot_details;
    my $seedlot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "seedlot", "stock_type")->cvterm_id();

    foreach my $seedlot(sort@seedlot_names) {
        my $seedlot_rs = $schema->resultset("Stock::Stock")->find( { uniquename => $seedlot });
        my $seedlot_id = $seedlot_rs->stock_id();
        push @seedlot_ids, $seedlot_id;
    }

    foreach my $id (@seedlot_ids) {
        my $content_name;
        my $content_id;
        my $content_type;
        my $seedlot_obj = CXGN::Stock::Seedlot->new(
            schema => $schema,
            phenome_schema => $phenome_schema,
            seedlot_id => $id
        );

        my $accessions = $seedlot_obj->accession();
        my $crosses = $seedlot_obj->cross();

        if ($accessions) {
            $content_name = $accessions->[1];
            $content_id = $accessions->[0];
            $content_type = 'accession'
        }

        if ($crosses) {
            $content_name = $crosses->[1];
            $content_id = $crosses->[0];
            $content_type = 'cross';
        }

        push @seedlot_details, [$id, $seedlot_obj->uniquename(), $content_id, $content_name, $content_type, $seedlot_obj->description(), $seedlot_obj->box_name(), $seedlot_obj->get_current_count_property(), $seedlot_obj->get_current_weight_property(), $seedlot_obj->quality(), $seedlot_obj->material_type()];

    }

    return \@seedlot_details;

}

__PACKAGE__->meta->make_immutable;

1;
