package SGN::Controller::Collection;

use Moose;
use CXGN::Collection;
use SGN::Image;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use File::Spec;
use File::Temp qw( tempfile );

BEGIN { extends 'Catalyst::Controller' }

sub _collection_object {
    my ($self, $c) = @_;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    return CXGN::Collection->new({ bcs_schema => $schema });
}

# Image and file collections each have their own page. The old combined page
# redirects to one of them, keeping links like /collections?collection_type=file.
sub collections_list : Path('/collections') : Args(0) {
    my ($self, $c) = @_;
    my $type = $c->req->param('collection_type') || '';
    $c->res->redirect($c->uri_for($type eq 'file' ? '/collections/files' : '/collections/images'));
    $c->detach();
}

sub image_collections : Path('/collections/images') : Args(0) {
    my ($self, $c) = @_;
    $c->stash->{collection_type} = 'image';
    $c->stash->{template}        = '/collection/collection.mas';
}

sub file_collections : Path('/collections/files') : Args(0) {
    my ($self, $c) = @_;
    $c->stash->{collection_type} = 'file';
    $c->stash->{template}        = '/collection/collection.mas';
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

    $c->stash->{collection_id}    = $collection_id;
    $c->stash->{collection_name}  = $collection->{name};
    $c->stash->{description}      = $collection->{description};
    $c->stash->{owner_username}   = $collection->{username};
    $c->stash->{collection_type}  = $collection->{collection_type};
    $c->stash->{projects}         = $collection->{projects};
    $c->stash->{user_can_modify}  = $can_modify;
    $c->stash->{template}         = '/collection/collection_details.mas';
}

=head2 collection_download

Public path: /collection/download/<collection_id>

Downloads the images and files in a collection as a zip. With item_type
('image' or 'file') and item_ids (comma separated), only those items are
included, and only if they are members of the collection, so this cannot be
used to fetch items from outside it. Items whose file is missing on disk are
listed in missing_files.txt inside the zip.

=cut

sub collection_download : Path('/collection/download') : Args(1) {
    my ($self, $c, $collection_id) = @_;

    my $cobj       = $self->_collection_object($c);
    my $collection = $collection_id =~ /^\d+$/ ? $cobj->get_collection($collection_id) : undef;
    if (!$collection) {
        $c->stash->{template} = 'generic_message.mas';
        $c->stash->{message}  = "Collection $collection_id was not found.";
        return;
    }

    my $image_ids = $cobj->get_image_ids($collection_id);
    my $file_ids  = $cobj->get_file_ids($collection_id);

    # restrict to the selected items, keeping only those in the collection
    my $item_type = $c->req->param('item_type') || '';
    my $item_ids  = $c->req->param('item_ids')  || '';
    if ($item_ids) {
        my %selected = map { $_ => 1 } grep { /^\d+$/ } split /,/, $item_ids;
        $image_ids = $item_type eq 'image' ? [ grep { $selected{$_} } @$image_ids ] : [];
        $file_ids  = $item_type eq 'file'  ? [ grep { $selected{$_} } @$file_ids ]  : [];
    }

    if (!@$image_ids && !@$file_ids) {
        $c->stash->{template} = 'generic_message.mas';
        $c->stash->{message}  = "There is nothing to download from collection $collection->{name}.";
        return;
    }

    my $zip = Archive::Zip->new();
    my %used_names;
    my @missing;

    # zip entry names must be unique, so a repeated name gets the item id prepended
    my $unique_name = sub {
        my ($name, $id) = @_;
        $name = "${id}_$name" if $used_names{$name};
        $used_names{$name} = 1;
        return $name;
    };

    my $dbh = $c->dbc->dbh;
    foreach my $image_id (@$image_ids) {
        my $image = SGN::Image->new($dbh, $image_id, $c);
        my $path  = $image->get_filename('original');
        $path = $image->get_filename('original_converted') unless -e $path;
        my $name = ($image->get_original_filename() || "image_$image_id") . ($image->get_file_ext() || '');
        if (!-e $path) {
            push @missing, "image $image_id: $name";
            next;
        }
        # images are already compressed, so store them as they are
        my $member = $zip->addFile($path, $unique_name->($name, $image_id));
        $member->desiredCompressionMethod(COMPRESSION_STORED);
    }

    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema');
    foreach my $file_id (@$file_ids) {
        my $file_row = $metadata_schema->resultset('MdFiles')->find({ file_id => $file_id });
        my $name = $file_row ? $file_row->basename : "file_$file_id";
        my $path = $file_row ? File::Spec->catfile($file_row->dirname, $file_row->basename) : '';
        if (!$path || !-e $path) {
            push @missing, "file $file_id: $name";
            next;
        }
        $zip->addFile($path, $unique_name->($name, $file_id));
    }

    if (@missing) {
        $zip->addString(
            "These items are in the collection but their files could not be found:\n\n"
                . join("\n", @missing) . "\n",
            'missing_files.txt'
        );
    }

    # write the zip to a temporary file and stream it, since image collections
    # can be too large to build in memory. The file is unlinked once opened;
    # the open handle still reads it until the response is sent.
    my ($tmp_fh, $tmp_filename) = tempfile(SUFFIX => '.zip');
    close $tmp_fh;
    unless ($zip->writeToFileNamed($tmp_filename) == AZ_OK) {
        unlink $tmp_filename;
        $c->stash->{template} = 'generic_message.mas';
        $c->stash->{message}  = "An error occurred creating the zip file for collection $collection->{name}.";
        return;
    }
    open my $zip_fh, '<:raw', $tmp_filename or die "Could not read $tmp_filename: $!";
    unlink $tmp_filename;

    (my $zip_name = $collection->{name}) =~ s/[^\w.-]+/_/g;
    $zip_name .= $item_ids ? '_selected.zip' : '.zip';

    $c->res->content_type('application/zip');
    $c->res->header('Content-Disposition' => qq[attachment; filename="$zip_name"]);
    $c->res->content_length(-s $zip_fh);
    $c->res->body($zip_fh);
}

1;