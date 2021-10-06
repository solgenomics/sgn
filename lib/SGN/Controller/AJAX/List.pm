
package SGN::Controller::AJAX::List;

use Moose;

use List::MoreUtils qw | uniq |;
use Data::Dumper;

use CXGN::List;
use CXGN::List::Validate;
use CXGN::List::Transform;
use CXGN::List::FuzzySearch;
use CXGN::List::Desynonymize;
use CXGN::Cross;
use JSON;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
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

    my $list = CXGN::List->new( { dbh => $c->dbc->dbh, list_id=>$list_id });
    my $public = $list->check_if_public();
    if ($public == 0) {
        my $error = $self->check_user($c, $list_id);
        if ($error) {
            $c->stash->{rest} = { error => $error };
            return;
        }
    }
    my $description = $list->description;

    $list = $self->retrieve_list($c, $list_id);

    my $metadata = $self->get_list_metadata($c, $list_id);

    $c->stash->{rest} = {
        list_id     => $list_id,
        type_id     => $metadata->{type_id},
        type_name   => $metadata->{list_type},
        elements    => $list,
        description => $description
    };
}


sub retrieve_contents :Path('/list/contents') Args(1) {
    my $self = shift;
    my $c = shift;
    my $list_id = shift;

    my $list = CXGN::List->new( { dbh=>$c->dbc->dbh(), list_id=>$list_id });
    my $public = $list->check_if_public();
    if ($public == 0) {
        my $error = $self->check_user($c, $list_id);
        if ($error) {
            $c->stash->{rest} = { error => $error };
            return;
        }
    }

    my $elements = $list->elements();
    $c->stash->{rest} = $elements;
}

sub get_list_metadata {
    my $self = shift;
    my $c = shift;
    my $list_id = shift;

    my $list = CXGN::List->new( { dbh=> $c->dbc->dbh(), list_id=>$list_id });

    return { name => $list->name(),
	     description => $list->description(),
	     type_id => $list->type_id(),
	     list_type => $list->type(),
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

    my $list = CXGN::List->new( { dbh=>$c->dbc->dbh(), list_id=>$list_id });
    $list->name($name);

    $c->stash->{rest} = { success => 1 };
}

sub update_list_description_action :Path('/list/description/update') :Args(0) {
    my $self = shift;
    my $c = shift;
    my $list_id = $c->req->param('list_id');
    my $description = $c->req->param('description');

    my $user_id = $self->get_user($c);
    my $error = $self->check_user($c, $list_id);

    if ($error) {
        $c->stash->{rest} = { error => $error };
        return;
    }

    my $list = CXGN::List->new( { dbh=>$c->dbc->dbh(), list_id=>$list_id });
    $list->description($description);

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

    my $list = CXGN::List->new( { dbh=> $c->dbc->dbh(), list_id => $list_id });

    if ($list->owner() != $user_id) {
	$c->stash->{rest} = { error => "Only the list owner can change the type of a list" };
	return;
    }

    $error = $list->type($type);

    if (!$error) {
	$c->stash->{rest} = { error => "List type not found: ".$type };
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

    my $all_types = CXGN::List::all_types($c->dbc->dbh());

    $c->stash->{rest} = $all_types;
}

sub download_list :Path('/list/download') Args(0) {
    my $self = shift;
    my $c = shift;
    my $list_id = $c->req->param("list_id");

    my $list = CXGN::List->new( { dbh => $c->dbc->dbh, list_id=>$list_id });
    my $public = $list->check_if_public();
    if ($public == 0) {
	my $error = $self->check_user($c, $list_id);
	if ($error) {
	    $c->res->content_type("text/plain");
	    $c->res->body($error);
	    return;
	}
    }

    $list = $self->retrieve_list($c, $list_id);

    $c->res->content_type("text/plain");
    $c->res->body(join "\n", map { $_->[1] }  @$list);
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

    my $lists = CXGN::List::available_lists($c->dbc->dbh(), $user_id, $requested_type);

    $c->stash->{rest} = $lists;
}

sub available_public_lists : Path('/list/available_public') Args(0) {
    my $self = shift;
    my $c = shift;

    my $requested_type = $c->req->param("type");

    my $user_id = $self->get_user($c);
    if (!$user_id) {
        $c->stash->{rest} = { error => "You must be logged in to use lists." };
        $c->detach();
    }

    my $lists = CXGN::List::available_public_lists($c->dbc->dbh(), $requested_type);

    $c->stash->{rest} = $lists;
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

    $element =~ s/^\s*(.+?)\s*$/$1/;

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

sub toggle_public_list : Path('/list/public/toggle') Args(0) {
    my $self = shift;
    my $c = shift;
    my $list_id = $c->req->param("list_id");

    my $error = $self->check_user($c, $list_id);
    if ($error) {
        $c->stash->{rest} = { error => $error };
        $c->detach();
    }

    my $list = CXGN::List->new( { dbh => $c->dbc->dbh, list_id=>$list_id });
    my ($public, $rows_affected) = $list->toggle_public();
    if ($rows_affected == 1) {
	$c->stash->{rest} = { r => $public };
    } else {
	die;
    }
}

sub make_public_list : Path('/list/public/true') Args(0) {
    my $self = shift;
    my $c = shift;
    my $list_id = $c->req->param("list_id");

    my $error = $self->check_user($c, $list_id);
    if ($error) {
	$c->stash->{rest} = { error => $error };
	return;
    }

    my $list = CXGN::List->new( { dbh => $c->dbc->dbh, list_id=>$list_id });
    my ($rows_affected) = $list->make_public();
    if ($rows_affected == 1) {
	$c->stash->{rest} = { success=>1 };
    } else {
	die;
    }
}

sub make_private_list : Path('/list/public/false') Args(0) {
    my $self = shift;
    my $c = shift;
    my $list_id = $c->req->param("list_id");

    my $error = $self->check_user($c, $list_id);
    if ($error) {
	$c->stash->{rest} = { error => $error };
	return;
    }

    my $list = CXGN::List->new( { dbh => $c->dbc->dbh, list_id=>$list_id });
    my ($rows_affected) = $list->make_private();
    if ($rows_affected == 1) {
	$c->stash->{rest} = { success=>1 };
    } else {
	die;
    }
}

sub copy_public_list : Path('/list/public/copy') Args(0) {
    my $self = shift;
    my $c = shift;
    my $list_id = $c->req->param("list_id");

    my $list = CXGN::List->new( { dbh => $c->dbc->dbh, list_id=>$list_id });
    my $public = $list->check_if_public();
    my $user_id = $self->get_user($c);
    if (!$user_id || $public == 0) {
	$c->stash->{rest} = { error => 'You must be logged in to use lists and list must be public!' };
	return;
    }

    my $copied = $list->copy_public($user_id);
    if ($copied) {
	$c->stash->{rest} = { success => 'true' };
    } else {
	die;
    }
}

sub sort_list_items : Path('/list/sort') Args(0) {
    my $self = shift;
    my $c = shift;
    my $list_id = $c->req->param("list_id");
    my $sort = $c->req->param("sort");

    my $list = CXGN::List->new( { dbh => $c->dbc->dbh, list_id=>$list_id });
    my $return = $list->sort_items($sort);
    if ($return) {
        $c->stash->{rest} = { success => 1 };
    } else {
        $c->stash->{rest} = { error => 1 };
    }
}

sub add_cross_progeny : Path('/list/add_cross_progeny') Args(0) {
    my $self = shift;
    my $c = shift;
    my $cross_id_list = decode_json($c->req->param("cross_id_list"));
    #print STDERR Dumper $cross_id_list;
    my $list_id = $c->req->param("list_id");

    my $list = CXGN::List->new( { dbh=>$c->dbc->dbh(), list_id => $list_id });

    my %response;
    $response{'count'} = 0;
    foreach (@$cross_id_list) {
        my $cross = CXGN::Cross->new({ schema => $c->dbic_schema("Bio::Chado::Schema"), cross_stock_id=>$_});
        my ($maternal_parent, $paternal_parent, $progeny) = $cross->get_cross_relationships();

        my @accession_names;
        foreach (@$progeny) {
            push @accession_names, $_->[0];
        }

        my $r = $list->add_bulk(\@accession_names);
        if ($r->{error}) {
            $c->stash->{rest} = { error => $r->{error}};
            return;
        }
        if (scalar(@{$r->{duplicates}}) > 0){
            $response{'duplicates'} = $r->{duplicates};
        }
        $response{'count'} += $r->{count};
    }
    #print STDERR Dumper \%response;
    $c->stash->{rest} = { duplicates => $response{'duplicates'} };
    $c->stash->{rest}->{success} = { count => $response{'count'} };
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

    my $list = CXGN::List->new( { dbh=>$c->dbc->dbh(), list_id => $list_id });

    my @duplicates = ();
    my $count = 0;

    my $response = $list->add_bulk(\@elements);
    #print STDERR Dumper $response;

    if ($response->{error}) {
        $c->stash->{rest} = { error => $response->{error}};
        return;
    }
    if (scalar(@{$response->{duplicates}}) > 0){
        $c->stash->{rest} = { duplicates => $response->{duplicates} };
    }

    $c->stash->{rest}->{success} = $response->{count};
}

sub insert_element : Private {
    my $self = shift;
    my $c = shift;
    my $list_id = shift;
    my $element = shift;

    my $list = CXGN::List->new( { dbh=>$c->dbc->dbh(), list_id => $list_id });

    $list->add_bulk([$element]);
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

    $error = CXGN::List::delete_list($c->dbc->dbh(), $list_id);

    if ($error) {
	$c->stash->{rest} = { error => $error };
    }
    else {
	$c->stash->{rest} =  [ 1 ];
    }
}


sub exists_list_action : Path('/list/exists') Args(0) {
    my $self =shift;
    my $c = shift;
    my $name = $c->req->param("name") || undef;

    my $user_id = $self->get_user($c);
    if (!$user_id) {
	$c->stash->{rest} = { error => 'You need to be logged in to use lists.' };
    }

    my $list_info = CXGN::List::exists_list($c->dbc->dbh(), $name, $user_id);

    print STDERR "List info is ".Dumper($list_info);
	$c->stash->{rest} = $list_info;

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

    my $list = CXGN::List->new( { dbh => $c->dbc->dbh, list_id=>$list_id });
    my $count = $list->list_size();

    $c->stash->{rest} = { count => $count };
}

#
# Validate an existing list for a specified data type
#
# PATH: GET /list/validate/{list}/{type}
#   {list} is the list id
#   {type} is the name of the supported list type (accessions, trials, seedlots, etc...)
#
# RETURNS:
#   missing: array list item names not in the database
#
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

#
# Validate a list of names for a specified data type
# - Temporarily create a list
# - Validate the list
# - Delete the temp list
# - Return lists of missing and existing items
#
# PATH: POST /list/validate/{type}
#   {type} is the name of a supported list type (accessions, trials, seedlots, etc...)
# BODY:
#   items: array of item names to validate
#
# RETURNS:
#   error: error message, if an error was encountered
#   missing: array list item names not in the database
#   existing: array list item names found in the database
#
sub validate_temp : Path('/list/validate') : ActionClass('REST') { }
sub validate_temp_POST : Args(1) {
    my $self = shift;
    my $c = shift;
    my $type = shift;
    my $params = $c->request->parameters();

    # Check user status
    my $user_id = $self->get_user($c);
    if (!$user_id) {
        $c->stash->{rest} = { error => "You must be logged in to perform a list validation" };
	    $c->detach();
    }

    # Get list items
    my $items = $params->{'items[]'} || $params->{'items'};
    if (!defined $items) {
        $c->stash->{rest} = { error => "Data items not provided" };
        $c->detach();
    }

    # Create new temp list
    my $list_name = "TEMP_" . sprintf("%08X", rand(0xFFFFFFFF));
    my $list_id = $self->new_list($c, $list_name, "temp list used for validation...", $user_id);
    if (!$list_id) {
        $c->stash->{rest} = { error => "Could not create temporary list" };
        $c->detach();
    }
    my $list = CXGN::List->new( { dbh=>$c->dbc->dbh(), list_id => $list_id });
    if (!$list) {
        $c->stash->{rest} = { error => "Could not get temporary list" };
        $c->detach();
    }
    $list->type($type);

    # Add list items
    my $response = $list->add_bulk($items);
    if ($response->{error}) {
        $c->stash->{rest} = { error => $response->{error} };
        $c->detach();
    }

    # Validate the list
    my $list_elements = $list->retrieve_elements_with_ids($list_id);
    my @flat_list = map { $_->[1] } @$list_elements;
    my $lv = CXGN::List::Validate->new();
    my $data = $lv->validate($c->dbic_schema("Bio::Chado::Schema"), $type, \@flat_list);

    # Delete the list
    CXGN::List::delete_list($c->dbc->dbh(), $list_id);

    # Set missing
    my $m = $data->{missing};

    # Set existing
    my %comp = map { $_ => 1 } @$m;
    my @e = grep !$comp{$_}, @$items;

    $c->stash->{rest} = {
        missing => $m,
        existing => \@e
    };
}

sub fuzzysearch : Path('/list/fuzzysearch') Args(2) {
    my $self = shift;
    my $c = shift;
    my $list_id = shift;
    my $list_type = shift;

    my $list = $self->retrieve_list($c, $list_id);

    my @flat_list = map { $_->[1] } @$list;

    my $f = CXGN::List::FuzzySearch->new();
    my $data = $f->fuzzysearch($c->dbic_schema("Bio::Chado::Schema"), $list_type, \@flat_list);

    $c->stash->{rest} = $data;
}

sub transform :Path('/list/transform/') Args(2) {
    my $self = shift;
    my $c = shift;
    my $list_id = shift;
    my $transform_name = shift;

    my $t = CXGN::List::Transform->new();

    my $data = $self->get_list_metadata($c, $list_id);

    my $list_data = $self->retrieve_list($c, $list_id);

    my @list_items = map { $_->[1] } @$list_data;

    my $result = $t->transform($c->dbic_schema("Bio::Chado::Schema"), $transform_name, \@list_items);

    if (exists($result->{missing}) && (scalar(@{$result->{missing}}) > 0)) {
	$result->{error}  =  "Warning. This lists contains elements that cannot be converted.";
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

sub update_element_action :Path('/list/item/update') Args(0) {
    my $self = shift;
    my $c = shift;

    my $list_id = $c->req->param("list_id");
    my $item_id = $c->req->param("item_id");
    my $content = $c->req->param("content");
    my $error = $self->check_user($c, $list_id);

    if ($content) {
        print STDERR "update ".$list_id." ".$item_id." ".$content."\n";

        if ($error) {
            $c->stash->{rest} = { error => $error };
            return;
        }

        my $list = CXGN::List->new( { dbh => $c->dbc()->dbh(), list_id => $list_id });
        $error = $list->update_element_by_id($item_id, $content);
    }

    if ($error) {
        $c->stash->{rest} = { error => "An error occurred while attempting to update item $item_id" };
    }
    else {
        $c->stash->{rest} = { success => 1 };
    }
}

sub new_list : Private {
    my $self = shift;
    my $c = shift;
    my ($name, $desc, $owner) = @_;

    my $user_id = $self->get_user($c);

    my $new_list_id = CXGN::List::create_list($c->dbc->dbh(), $name, $desc, $owner);

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

    my $list = CXGN::List->new( { dbh => $c->dbc->dbh, list_id=>$list_id });
    my $public = $list->check_if_public();
    if ($public == 0) {
	my $error = $self->check_user($c, $list_id);
	if ($error) {
	    $c->stash->{rest} = { error => $error };
	    return;
	}
    }
    my $list_elements_with_ids = $list->retrieve_elements_with_ids($list_id);

    #print STDERR "LIST ELEMENTS WITH IDS: ".Dumper($list_elements_with_ids);
    return $list_elements_with_ids;
}


sub remove_element : Private {
    my $self = shift;
    my $c = shift;
    my $list_id = shift;
    my $item_id = shift;


    my $list = CXGN::List->new( { dbh => $c->dbc()->dbh(), list_id => $list_id });
    my $error = $list->remove_element_by_id($item_id);

    if ($error) {
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

    my $list = CXGN::List->new( { dbh => $c->dbc()->dbh(), list_id => $list_id });
    my $list_item_id = $list->exists_element($item);
    return $list_item_id;
}

sub get_list_owner : Private {
    my $self = shift;
    my $c = shift;
    my $list_id = shift;

    my $list = CXGN::List->new( { dbh => $c->dbc()->dbh(), list_id => $list_id });
    my $owner = $list->owner();

    return $owner;
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
        $error = "You must be logged in to manipulate this list.";
    }
    elsif ($c->user->get_object->get_user_type() ne 'curator' && $self->get_list_owner($c, $list_id) != $user_id) {
        $error = "You have insufficient privileges to manipulate this list.";
    }
    return $error;
}

sub desynonymize_list: Path('/list/desynonymize') Args(0) {
    my $self = shift;
    my $c = shift;

    my $list_id = $c->req->param("list_id");

    my $user_id = $self->get_user($c);
    if (!$user_id) {
    	$c->stash->{rest} = { error => 'You must be logged in to use lists.', };
    	return;
    }
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $dbh = $schema->storage->dbh;

    my $list = CXGN::List->new( { dbh => $dbh, list_id => $list_id } );
    my $flat_list = $list->retrieve_elements_with_ids($list_id);
    my @name_list = map {@{$_}[1]} @{$flat_list};
    my $dsyner = CXGN::List::Desynonymize->new();
    my $results = $dsyner
      ->desynonymize($schema,$list->type(),\@name_list);
    $results->{'previous_list'} = \@name_list;
    $results->{'list_type'} = $list->type();

    $c->stash->{rest} = $results;
}


sub available_marker_sets : Path('/marker_sets/available') Args(0) {
    my $self = shift;
    my $c = shift;

    my $user_id = $self->get_user($c);
    if (!$user_id) {
        $c->stash->{rest} = { error => "You must be logged in to use markerset.", };
        return;
    }

    my $lists = CXGN::List::available_lists($c->dbc->dbh(), $user_id, 'markers');
    my @marker_sets;
    foreach my $list (@$lists){
        my ($id, $name, $desc, $item_count, $type_id, $type, $public) = @$list;
        push @marker_sets, {
            markerset_id => $id,
            markerset_name => $name,
            number_of_markers => $item_count - 1,
            description => $desc,
        }
    }

    $c->stash->{rest} = {data => \@marker_sets};
}


sub delete_markerset : Path('/markerset/delete') Args(0) {
    my $self = shift;
    my $c = shift;

    my $user_id = $self->get_user($c);
    if (!$user_id) {
    	$c->stash->{rest} = { error => 'You must be logged in to delete markerset.', };
    	return;
    }

    my $markerset_id = $c->req->param("markerset_id");

    my $error = $self->check_user($c, $markerset_id);
    if ($error) {
	$c->stash->{rest} = { error => $error };
	return;
    }

    $error = CXGN::List::delete_list($c->dbc->dbh(), $markerset_id);

    if (!$error){
        $c->stash->{rest} = { success => 1 };
    }
    else {
        $c->stash->{rest} = { error => $error };
    }

}


sub get_markerset_items :Path('/markerset/items') Args(0) {
    my $self = shift;
    my $c = shift;
    my $markerset_id = $c->req->param("markerset_id");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");

    my $user_id = $self->get_user($c);
    if (!$user_id) {
    	$c->stash->{rest} = { error => 'You must be logged in to use markerset.', };
    	return;
    }

    my $markerset = CXGN::List->new({dbh => $schema->storage->dbh, list_id => $markerset_id});
    my $markerset_items_ref = $markerset->retrieve_elements_with_ids($markerset_id);

    my @items;
    foreach my $markerset_item (@$markerset_items_ref){
        my ($id, $name) = @$markerset_item;
        push @items, {
            item_id => $id,
            item_name => $name,
        }
    }

    $c->stash->{rest} = {success => 1, data => \@items};

}


sub get_markerset_type :Path('/markerset/type') Args(0) {
    my $self = shift;
    my $c = shift;
    my $markerset_id = $c->req->param("markerset_id");
    my $schema = $c->dbic_schema("Bio::Chado::Schema", "sgn_chado");

    my $user_id = $self->get_user($c);
    if (!$user_id) {
    	$c->stash->{rest} = { error => 'You must be logged in to use markerset.', };
    	return;
    }

    my $markerset = CXGN::List->new({dbh => $schema->storage->dbh, list_id => $markerset_id});
    my $markerset_items_ref = $markerset->retrieve_elements($markerset_id);
    my @markerset_items = @{$markerset_items_ref};

    my $type;
    foreach my $item (@markerset_items){
        my $item_ref = decode_json$item;
        my %item_hash = %{$item_ref};
        my $markerset_type = $item_hash{genotyping_data_type};

        if ($markerset_type){
            $type = $markerset_type;
        }
    }
#    print STDERR "MARKERSET TYPE =".Dumper($type)."\n";
    $c->stash->{rest} = {success => 1, type => $type};

}


sub adjust_case : Path('/ajax/list/adjust_case') Args(0) {
    my $self = shift;
    my $c = shift;
    my $list_id = $c->req->param("list_id");

    my $user_id = $self->get_user($c);
    if (!$user_id) {
        $c->stash->{rest} = { error => "You must be logged in to use lists.", };
        return;
    }

    my $list = CXGN::List->new( { dbh => $c->dbc->dbh, list_id => $list_id } );

    if ($user_id != $list->owner()) {
	$c->stash->{rest} = { error => "You don't own this list and you cannot modify it." };
	return;
    }

    if ($list->type() ne "accessions") {
	$c->stash->{rest} = { error => "Only lists with type 'accessions' can be adjusted for case in the database." };
    }

    my $lt = CXGN::List::Transform->new();
    my $elements = $list->elements();

    print STDERR "Elements: ".Dumper($elements);

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $data = $lt->transform($schema, 'accessions_2_accession_case', $elements);

    print STDERR "Converted data: ".Dumper($data);

    if (! $data) {
	$c->stash->{rest} = { error => "No data!" };
	return;
    }
    my $error_message = "";
    my $replace_count = 0;

    foreach my $item (@$elements) {
	print STDERR "Replacing element $item...\n";
	if ($data->{mapping}->{$item}) {
	    print STDERR "  with $data->{mapping}->{$item}...\n";
	    my $error = $list->replace_by_name($item, $data->{mapping}->{$item});
	    if ($error) {
		$error_message .= "Error: $item not replaced. ";
	    }
	    else {
		$replace_count++;
	    }
	}
    }

    $c->stash->{rest} = {
	transform => $data->{transform},
	error => $error_message,
	replace_count => $replace_count,
	missing => $data->{missing} || [],
	duplicated => $data->{duplicated} || [],
	mapping => $data->{mapping},
    }

}

sub adjust_synonyms :Path('/ajax/list/adjust_synonyms') Args(0) {
    my $self = shift;
    my $c = shift;

    my $list_id = $c->req->param("list_id");

    my $user_id = $self->get_user($c);
    if (!$user_id) {
        $c->stash->{rest} = { error => "You must be logged in to use lists.", };
        return;
    }

    my $list = CXGN::List->new( { dbh => $c->dbc->dbh, list_id => $list_id } );

    if ($user_id != $list->owner()) {
	$c->stash->{rest} = { error => "You don't own this list and you cannot modify it." };
	return;
    }

    if ($list->type() ne "accessions") {
	$c->stash->{rest} = { error => "Only lists with type 'accessions' can be adjusted for synonyms in the database." };
    }

    my $lt = CXGN::List::Transform->new();
    my $elements = $list->elements();
    print STDERR "Elements: ".Dumper($elements);

    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $data = $lt->transform($schema, 'synonyms2accession_uniquename', $elements);

    print STDERR "Converted data: ".Dumper($data);

    print STDERR Dumper($data);

    if (! $data) {
	$c->stash->{rest} = { error => "No data!" };
	return;
    }
    my $error_message = "";
    my $replace_count = 0;

    foreach my $item (@$elements) {
	print STDERR "Replacing element $item...\n";
	if ($data->{mapping}->{$item}) {
	    print STDERR "  with $data->{mapping}->{$item}...\n";
	    my $error = $list->replace_by_name($item, $data->{mapping}->{$item});
	    if ($error) {
		$error_message .= "Error: $item not replaced. ";
	    }
	    else {
		$replace_count++;
	    }
	}
    }

    $c->stash->{rest} = {
	transform => $data->{transform},
	error => $error_message,
	replace_count => $replace_count,
	missing => $data->{missing} || [],
	duplicated => $data->{duplicated} || [],
	mapping => $data->{mapping},
    }

}

#########
1;
#########
