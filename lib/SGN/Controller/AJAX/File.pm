package SGN::Controller::AJAX::File;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

use Data::Dumper;
use JSON::Any;
use CXGN::File;
use Try::Tiny;

use strict;
use warnings;

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
    );

has 'schema' => (
        is       => 'rw',
        isa      => 'DBIx::Class::Schema',
        lazy_build => 1,
    );

=head2 file_autocomplete

Public Path: /ajax/file/autocomplete

Autocomplete for archived files. Takes a 'term' parameter (as sent by jQuery UI autocomplete)
and returns a list of strings of the form "<basename> (ID: <file_id>)", where basename is the
archived file basename as defined in CXGN::File (timestamp_filename). The file ID suffix lets
the client recover the file ID from the selected string.

Curators can search all archived files; other users can only search their own. Obsolete files
are excluded. There is no date restriction.

Optional parameters:
    extensions      - comma-separated list of file extensions to restrict to (e.g. "xlsx,xls")
    exclude_file_id - a file ID to leave out of the results (e.g. the file being processed)

=cut

sub file_autocomplete : Path('/ajax/file/autocomplete') : ActionClass('REST') { }

sub file_autocomplete_GET : Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {
        $c->stash->{rest} = {error => "You must be logged in to search archived files."};
        return;
    }

    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $is_curator = $c->user()->check_roles('curator');

    my $term = $c->req->param('term') // '';
    $term =~ s/\s*\(ID:\s*\d+\)\s*$//; # allow searching with a previously autocompleted value
    $term =~ s/^\s+|\s+$//g;
    $term =~ s/([\\%_])/\\$1/g; # escape LIKE wildcards so they match literally

    my $exclude_file_id = $c->req->param('exclude_file_id');
    my @extensions = grep { $_ ne '' } map { my $e = $_; $e =~ s/^\s*\.?|\s*$//g; $e =~ s/([\\%_])/\\$1/g; $e } split(/,/, $c->req->param('extensions') // '');

    my $q = "SELECT md_files.file_id, md_files.basename FROM metadata.md_files
        JOIN metadata.md_metadata ON (md_files.metadata_id=md_metadata.metadata_id)
        WHERE md_files.basename != 'none'
        AND COALESCE(md_metadata.obsolete::int, 0) = 0
        AND md_files.basename ILIKE ?";
    my @q_params = ('%'.$term.'%');

    if (!$is_curator) {
        $q .= " AND md_metadata.create_person_id = ?";
        push @q_params, $user_id;
    }

    if ($exclude_file_id && $exclude_file_id =~ /^\d+$/) {
        $q .= " AND md_files.file_id != ?";
        push @q_params, $exclude_file_id;
    }

    if (@extensions) {
        $q .= " AND (" . join(" OR ", map { "md_files.basename ILIKE ?" } @extensions) . ")";
        push @q_params, map { '%.'.$_ } @extensions;
    }

    $q .= " ORDER BY md_files.file_id DESC LIMIT 50";

    my $dbh = $c->dbc->dbh();
    my $h = $dbh->prepare($q);
    $h->execute(@q_params);

    my @response_list;
    while (my ($file_id, $basename) = $h->fetchrow_array()) {
        push @response_list, "$basename (ID: $file_id)";
    }

    $c->stash->{rest} = \@response_list;
}

sub file : Chained('/') PathPart('ajax/file/') CaptureArgs(1) {
    my $self = shift;
    my $c = shift;
    my $file_id = shift;

    my $user_id = $c->user()->get_object()->get_sp_person_id();

    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema', undef, $user_id);

    my $archive_path = $c->config->{archive_path};

    my $file = CXGN::File->new({
        metadata_schema => $metadata_schema,
        file_id => $file_id,
        archive_path => $archive_path
    });

    $c->stash->{archived_file} = $file;
    $c->stash->{metadata_schema} = $metadata_schema;
    $c->stash->{file_id} = $file_id;

    if (!$c->stash->{archived_file}) {
        $c->stash->{rest} = {error => "The file with ID $file_id does not exist."};
        return;
    }
}

sub set_file_type : Chained('file') PathPart('set_file_type') Args(1) {
    my $self = shift;
    my $c = shift;
    my $file_type = shift;
    my $file = $c->stash->{archived_file};
    my $user_id = $c->user()->get_object()->get_sp_person_id();

    if (!($c->user()->check_roles('curator') || $user_id == $file->user_id())) {
        $c->stash->{rest} = {error => "You do not have permission to modify this file entry. You must either be the uploader or a curator."};
        return;
    }

    try {
        $file->set_file_type($file_type);
    } catch {
        $c->stash->{rest} = {error => "Could not save file type: $_"};
        return;
    };
    
    $c->stash->{rest} = {success => 1};
}

sub obsolete_file : Chained('file') PathPart('obsolete') Args(0) {
    my $self = shift;
    my $c = shift;
    my $file = $c->stash->{archived_file};
    my $note = $c->req->param('note');
    my $user_id = $c->user()->get_object()->get_sp_person_id();

    if (!($c->user()->check_roles('curator') || $user_id == $file->user_id())) {
        $c->stash->{rest} = {error => "You do not have permission to obsolete this file. You must either be the uploader or a curator."};
        return;
    }

    my $error;
    try {
        $file->obsolete_file($note);
    } catch {
        $error = $_;
    };

    if ($error) {
        $c->stash->{rest} = {error => "Could not obsolete file: $error"};
        return;
    }

    $c->stash->{rest} = {success => 1};
}

1;