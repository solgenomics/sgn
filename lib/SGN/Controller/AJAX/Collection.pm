package SGN::Controller::AJAX::Collection;

=head1 NAME

SGN::Controller::AJAX::Collection - AJAX endpoints for image/file collections

=cut

use Moose;
use Data::Dumper;
use JSON;
use CXGN::Collection;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
);

sub _collection_object {
    my ($self, $c) = @_;
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", 'sgn_chado', $sp_person_id);
    return CXGN::Collection->new({ bcs_schema => $schema });
}

sub _require_login {
    my ($self, $c) = @_;
    if (!$c->user()) {
        $c->stash->{rest} = { error => "You must be logged in to do this." };
        $c->detach();
    }
    return $c->user->get_object()->get_sp_person_id();
}

sub _can_modify {
    my ($self, $c, $collection) = @_;
    return 0 unless $c->user();
    return 1 if $c->user->check_roles('curator');
    my $user_id = $c->user->get_object()->get_sp_person_id();
    return 1 if defined $collection->{sp_person_id}
             && defined $user_id
             && $collection->{sp_person_id} == $user_id;
    return 0;
}

# Returns the collection hashref, or detaches with an error.
sub _require_edit_privileges {
    my ($self, $c, $collection_id) = @_;
    $self->_require_login($c);

    my $cobj = $self->_collection_object($c);
    my $collection = $cobj->get_collection($collection_id);
    unless ($collection) {
        $c->stash->{rest} = { error => "Folder was not found." };
        $c->detach();
    }
    unless ($self->_can_modify($c, $collection)) {
        $c->stash->{rest} = {
            error => "Only the folder's creator or a curator can modify it."
        };
        $c->detach();
    }
    return $collection;
}

# Accepts item_ids_json (JSON array), repeated item_ids, or a comma string.
sub _item_ids {
    my ($self, $c, $param_base) = @_;
    $param_base ||= 'item_ids';
    my @ids;

    if (my $json = $c->req->param($param_base . '_json')) {
        my $decoded = eval { decode_json($json) };
        if ($@ || ref($decoded) ne 'ARRAY') {
            $c->stash->{rest} = { error => "${param_base}_json must be a JSON array." };
            $c->detach();
        }
        @ids = @$decoded;
    }
    else {
        my @raw = $c->req->param($param_base);
        @ids = (scalar(@raw) == 1 && defined $raw[0] && $raw[0] =~ /,/)
             ? split(/,/, $raw[0]) : @raw;
    }

    @ids = grep { defined && /^\d+$/ }
           map  { my $v = $_; $v =~ s/\s//g if defined $v; $v } @ids;

    unless (@ids) {
        $c->stash->{rest} = { error => "No valid ids were supplied." };
        $c->detach();
    }
    return \@ids;
}

sub _item_type {
    my ($self, $c) = @_;
    my $type = $c->req->param('item_type') || '';
    unless ($type eq 'image' || $type eq 'file') {
        $c->stash->{rest} = { error => "item_type must be 'image' or 'file'." };
        $c->detach();
    }
    return $type;
}

# ------------------------------------------------------------------- list

sub collections : Path('/ajax/collection/list') : ActionClass('REST') { }

sub collections_GET : Args(0) {
    my ($self, $c) = @_;
    my $cobj = $self->_collection_object($c);

    my %args;
    if (my $project_id = $c->req->param('project_id')) {
        unless ($project_id =~ /^\d+$/) {
            $c->stash->{rest} = { error => "project_id must be numeric." };
            $c->detach();
        }
        $args{project_id} = $project_id;
    }
    elsif ($c->req->param('standalone_only')) {
        $args{standalone_only} = 1;
    }
    if ($c->req->param('mine_only') && $c->user()) {
        $args{sp_person_id} = $c->user->get_object()->get_sp_person_id();
    }

    my $collections = $cobj->get_collections(\%args);
    foreach my $col (@$collections) {
        $col->{user_can_modify} = $self->_can_modify($c, $col);
    }

    $c->stash->{rest} = { success => 1, collections => $collections };
}

# --------------------------------------------------------------- contents

sub contents : Path('/ajax/collection/contents') : ActionClass('REST') { }

sub contents_GET : Args(0) {
    my ($self, $c) = @_;
    my $collection_id = $c->req->param('collection_id');
    my $cobj = $self->_collection_object($c);

    my $collection = $cobj->get_collection($collection_id);
    unless ($collection) {
        $c->stash->{rest} = { error => "Folder was not found.", contents => [] };
        $c->detach();
    }

    $c->stash->{rest} = {
        success         => 1,
        collection      => $collection,
        contents        => $cobj->get_contents($collection_id),
        user_can_modify => $self->_can_modify($c, $collection),
    };
}

# ----------------------------------------------------------------- create

sub create : Path('/ajax/collection/create') : ActionClass('REST') { }

sub create_POST : Args(0) {
    my ($self, $c) = @_;
    my $user_id = $self->_require_login($c);
    my $cobj    = $self->_collection_object($c);

    my $collection_id = eval {
        $cobj->create_collection({
            name         => $c->req->param('name'),
            description  => $c->req->param('description'),
            #project_id   => $c->req->param('project_id'),
            sp_person_id => $user_id,
        });
    };
    if ($@) { my $e = $@; chomp $e; $c->stash->{rest} = { error => $e }; $c->detach(); }

    # Optionally seed the new folder in the same request.
    my $added = 0;
    if ($c->req->param('item_ids') || $c->req->param('item_ids_json')) {
        my $type = $self->_item_type($c);
        my $ids  = $self->_item_ids($c);
        $added = eval {
            $type eq 'image' ? $cobj->add_images($collection_id, $ids)
                             : $cobj->add_files($collection_id, $ids);
        };
        if ($@) {
            my $e = $@; chomp $e;
            $c->stash->{rest} = {
                error => "Folder created, but items could not be added: $e",
                collection_id => $collection_id,
            };
            $c->detach();
        }
    }

    $c->stash->{rest} = {
        success       => 1,
        collection_id => $collection_id,
        items_added   => $added,
    };
}

# ----------------------------------------------------------------- rename

sub rename : Path('/ajax/collection/rename') : ActionClass('REST') { }

sub rename_POST : Args(0) {
    my ($self, $c) = @_;
    my $collection_id = $c->req->param('collection_id');
    $self->_require_edit_privileges($c, $collection_id);

    my $cobj = $self->_collection_object($c);
    eval { $cobj->rename_collection($collection_id, $c->req->param('name')) };
    if ($@) { my $e = $@; chomp $e; $c->stash->{rest} = { error => $e }; $c->detach(); }

    if (defined(my $desc = $c->req->param('description'))) {
        $cobj->set_description($collection_id, $desc);
    }
    $c->stash->{rest} = { success => 1 };
}

# ---------------------------------------------------------- add / remove

sub add_items : Path('/ajax/collection/add_items') : ActionClass('REST') { }

sub add_items_POST : Args(0) {
    my ($self, $c) = @_;
    my $collection_id = $c->req->param('collection_id');
    $self->_require_edit_privileges($c, $collection_id);

    my $type = $self->_item_type($c);
    my $ids  = $self->_item_ids($c);
    my $cobj = $self->_collection_object($c);

    my $added = eval {
        $type eq 'image' ? $cobj->add_images($collection_id, $ids)
                         : $cobj->add_files($collection_id, $ids);
    };
    if ($@) {
        my $e = $@; chomp $e;
        $c->stash->{rest} = { error => "Could not add items: $e" };
        $c->detach();
    }

    $c->stash->{rest} = {
        success     => 1,
        items_added => $added,
        image_count => scalar @{ $cobj->get_image_ids($collection_id) },
        file_count  => scalar @{ $cobj->get_file_ids($collection_id) },
    };
}

sub remove_items : Path('/ajax/collection/remove_items') : ActionClass('REST') { }

sub remove_items_POST : Args(0) {
    my ($self, $c) = @_;
    my $collection_id = $c->req->param('collection_id');
    $self->_require_edit_privileges($c, $collection_id);

    my $type = $self->_item_type($c);
    my $ids  = $self->_item_ids($c);
    my $cobj = $self->_collection_object($c);

    my $removed = eval {
        $type eq 'image' ? $cobj->remove_images($collection_id, $ids)
                         : $cobj->remove_files($collection_id, $ids);
    };
    if ($@) {
        my $e = $@; chomp $e;
        $c->stash->{rest} = { error => "Could not remove items: $e" };
        $c->detach();
    }

    $c->stash->{rest} = {
        success       => 1,
        items_removed => $removed,
        image_count   => scalar @{ $cobj->get_image_ids($collection_id) },
        file_count    => scalar @{ $cobj->get_file_ids($collection_id) },
    };
}

# ------------------------------------------------------------------ order

sub set_order : Path('/ajax/collection/set_order') : ActionClass('REST') { }

sub set_order_POST : Args(0) {
    my ($self, $c) = @_;
    my $collection_id = $c->req->param('collection_id');
    $self->_require_edit_privileges($c, $collection_id);

    my $type = $self->_item_type($c);
    my $ids  = $self->_item_ids($c);
    my $cobj = $self->_collection_object($c);

    my $count = eval { $cobj->set_order($collection_id, $type, $ids) };
    if ($@) { my $e = $@; chomp $e; $c->stash->{rest} = { error => $e }; $c->detach(); }

    $c->stash->{rest} = { success => 1, items_ordered => $count };
}

# ----------------------------------------------------------------- delete

sub delete_collection : Path('/ajax/collection/delete') : ActionClass('REST') { }

sub delete_collection_POST : Args(0) {
    my ($self, $c) = @_;
    my $collection_id = $c->req->param('collection_id');
    $self->_require_edit_privileges($c, $collection_id);

    my $cobj = $self->_collection_object($c);
    eval { $cobj->obsolete_collection($collection_id) };
    if ($@) { my $e = $@; chomp $e; $c->stash->{rest} = { error => $e }; $c->detach(); }

    $c->stash->{rest} = { success => 1 };
}

# ------------------------------------------------- folders for one item

sub for_item : Path('/ajax/collection/for_item') : ActionClass('REST') { }

sub for_item_GET : Args(0) {
    my ($self, $c) = @_;
    my $type    = $self->_item_type($c);
    my $item_id = $c->req->param('item_id');
    unless (defined $item_id && $item_id =~ /^\d+$/) {
        $c->stash->{rest} = { error => "A valid item_id is required." };
        $c->detach();
    }

    my $cobj = $self->_collection_object($c);
    $c->stash->{rest} = {
        success     => 1,
        collections => $type eq 'image'
            ? $cobj->get_collections_for_image($item_id)
            : $cobj->get_collections_for_file($item_id),
    };
}

1;