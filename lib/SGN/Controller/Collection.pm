package SGN::Controller::Collection;

use Moose;
use CXGN::Collection;

BEGIN { extends 'Catalyst::Controller' }

sub _collection_object {
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    return CXGN::Collection->new({ bcs_schema => $schema });
}

sub collections_list : Path('/collections') : Args(0) {
    my ($self, $c) = @_;
    $c->stash->{template} = '/collection/collection.mas';
}

sub collection_detail : Path('/collection') : Args(1) {
    my ($self, $c, $collection_id) = @_;
    my $cobj       = $self->_collection_object($c);
    my $collection = $cobj->get_collection($collection_id);

    if (!$collection) {
        $c->stash->{template} = 'generic_message.mas';
        $c->stash->{message}  = "Folder $collection_id was not found.";
        return;
    }

    my $user_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $can_modify = $c->user()
        && ($c->user->check_roles('curator')
            || (defined $collection->{sp_person_id}
                && defined $user_id
                && $collection->{sp_person_id} == $user_id))
        ? 1 : 0;

    $c->stash->{collection_id}   = $collection_id;
    $c->stash->{collection_name} = $collection->{name};
    $c->stash->{description}     = $collection->{description};
    $c->stash->{owner_username}  = $collection->{username};
    $c->stash->{projects}        = $collection->{projects};
    $c->stash->{user_can_modify} = $can_modify;
    $c->stash->{template}        = '/collection/collection_details.mas';
}

1;