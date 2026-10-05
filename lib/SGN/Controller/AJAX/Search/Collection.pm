package SGN::Controller::AJAX::Search::Collection;

=head1 NAME

SGN::Controller::AJAX::Search::Collection - AJAX search endpoint for
collections (folders of images and/or files)

=cut

use Moose;
use Data::Dumper;
use JSON;
use CXGN::Collection::Search;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
);

sub collection_search : Path('/ajax/search/collections') : ActionClass('REST') { }

sub collection_search_POST : Args(0) {
    my ($self, $c) = @_;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema("Bio::Chado::Schema", 'sgn_chado', $sp_person_id);
    my $params = $c->req->params() || {};

    my @name_list;
    if (exists($params->{name}) && $params->{name}) {
        if (ref($params->{name}) eq 'ARRAY') { push @name_list, @{ $params->{name} }; }
        else { @name_list = split /,/, $params->{name}; }
    }

    my @description_list;
    if (exists($params->{description}) && $params->{description}) {
        push @description_list, $params->{description};
    }

    my @image_name_list;
    if (exists($params->{image_name}) && $params->{image_name}) {
        push @image_name_list, $params->{image_name};
    }

    my @image_descriptor_list;
    if (exists($params->{image_descriptor}) && $params->{image_descriptor}) {
        push @image_descriptor_list, $params->{image_descriptor};
    }

    my @creator_username_list;
    if (exists($params->{creator_username}) && $params->{creator_username}) {
        push @creator_username_list, $params->{creator_username};
    }

    my @sp_person_id_list;
    if ($params->{mine_only} && $sp_person_id) {
        push @sp_person_id_list, $sp_person_id;
    }

    my @project_id_list;
    if (exists($params->{project_id}) && $params->{project_id}) {
        if (ref($params->{project_id}) eq 'ARRAY') { push @project_id_list, @{ $params->{project_id} }; }
        else { @project_id_list = split /,/, $params->{project_id}; }
    }

    my @project_name_list;
    if (exists($params->{project_name}) && $params->{project_name}) {
        push @project_name_list, $params->{project_name};
    }

    my $standalone_only = $params->{standalone_only} ? 1 : 0;

    my $limit  = $params->{length};
    my $offset = $params->{start};

    my $collection_search = CXGN::Collection::Search->new({
        bcs_schema             => $schema,
        name_list              => \@name_list,
        description_list       => \@description_list,
        image_descriptor_list  => \@image_descriptor_list,
        image_name_list        => \@image_name_list,
        creator_username_list  => \@creator_username_list,
        sp_person_id_list      => \@sp_person_id_list,
        project_id_list        => \@project_id_list,
        project_name_list      => \@project_name_list,
        standalone_only        => $standalone_only,
        limit                  => $limit,
        offset                 => $offset,
    });
    my ($result, $records_total) = eval { $collection_search->search() };
    if ($@) {
        my $e = $@; chomp $e;
        $c->stash->{rest} = { error => "Search failed: $e" };
        $c->detach();
    }

    my $draw = $params->{draw};
    if ($draw) { $draw =~ s/\D//g; }

    # Kept inline rather than pulled from AJAX::Collection to avoid coupling
    # this read-only search controller to the CRUD controller. If the
    # ownership rule in _can_modify there ever changes, this block must be
    # updated to match — consider extracting both to a shared
    # CXGN::Collection->can_modify($user, $collection) method if this drifts.
    my $is_curator = $c->user() ? $c->user->check_roles('curator') : 0;
    foreach my $row (@$result) {
        $row->{user_can_modify} =
            ($is_curator || (defined $sp_person_id
                             && defined $row->{sp_person_id}
                             && $row->{sp_person_id} == $sp_person_id)) ? 1 : 0;
    }

    $c->stash->{rest} = {
        data            => $result,
        draw            => $draw,
        recordsTotal    => $records_total,
        recordsFiltered => $records_total,
    };
}

1;