=head1 NAME

CXGN::File - a class to do functions with archived files

=head1 DESCRIPTION

CXGN::File is a class for managing the behaviors of archived files. Archived files are stored in the database with a unique ID 
and a file path. Not to be confused with CXGN::UploadFile, which is used when saving a file for the first time. 

=head1 SYNOPSIS

my $file = CXGN::File->new({
    file_id => $file_id
});

my $file_type = $file->type();

$file->type("multi_trial_upload");

$file->store();

=head1 AUTHOR

Ryan Preble <rsp98@cornell.edu>

=cut 

package CXGN::File;

use Moose;
use Moose::Util::TypeConstraints;
use DateTime;
use DateTime::Format::ISO8601;
use Data::Dumper;
use File::Slurp qw( write_file read_file );
use File::Path qw( make_path );
use JSON::Any;
use Try::Tiny;
use CXGN::Metadata::Schema;

use strict;
use warnings;

=head1 ACCESSORS

=head2 metadata_schema()

Accessor for metadata schema

=cut 

has 'metadata_schema' => (
    isa => 'CXGN::Metadata::Schema',
    is => 'rw',
    required => 1
);

=head2 file_id()

Database ID for file

=cut 

has 'file_id' => (
    isa => 'Int',
    is => 'ro',
    required => 1
);

=head2 archive_path()

Server configuration - path to the file archive

=cut

has 'archive_path' => (
    isa => 'Str',
    is => 'ro',
    required => 1
);

=head2 basename()

Database file basename. Concatenation of timestamp and file name. 

=cut 

has 'basename' => (
    isa => 'Maybe[Str]',
    is => 'rw'
);

=head2 timestamp()

The time at which the file was archived. Used to differentiate it from files with the same name. 

=cut

has 'timestamp' => (
    isa => 'Maybe[Str]',
    is => 'rw'
);

=head2 filename()

The name of the file.

=cut

has 'filename' => (
    isa => 'Maybe[Str]',
    is => 'rw'
);

=head2 dirname()

Parent directories of archived file. Should be combined with the archive path config key ($file->archive_path or $c->config->{archive_path}) for a complete path to a file.
Ideally, $c->config->{archive_path} should NOT be found in the dirname of a given file. The dirname should have only the user ID folder and the subdirectory, such that the 
complete file path on the system is $archive_path/$dirname/$basename. 

=cut

has 'dirname' => (
    isa => 'Maybe[Str]',
    is => 'rw'
);

=head2 subdirectory()

The archive subdirectory holding this file. This loosely corresponds to what type of file it is or where it was uploaded from. However, there is no enforcement of this at all.
This is a substring of dirname.

=cut

has 'subdirectory' => (
    isa => 'Maybe[Str]',
    is => 'rw'
);

=head2 user_id()

The ID of the user that uploaded this file. Generally, this will also be part of the dirname. 

=cut

has 'user_id' => (
    isa => 'Int',
    is => 'rw'
);

=head2 filetype()

Optional file type. Used for determining upload/parse type for archived files. Loosely correlates to background job types. 

=cut

has 'filetype' => (
    isa => 'Maybe[Str]',
    is => 'rw'
);

=head2 alt_filename()

md_files.alt_filename

=cut

has 'alt_filename' => (
    isa => 'Maybe[Str]',
    is => 'rw'
);

=head2 comments()

md_files.comment (comments portion)

md_files.comment is stored as a single JSON string in the database that holds both
the comments list and the tags hash described below. This accessor exposes just the
comments half: a list of comment strings left on this file.

This accessor is read-only from outside the module: use add_comment() and
clear_comments() to modify its contents. This prevents other modules from storing
arbitrary structures in this column; only a plain list of strings is allowed.

=cut

has 'comments' => (
    isa => 'ArrayRef',
    is => 'ro',
    writer => '_set_comments',
    default => sub { [] }
);

=head2 tags()

md_files.comment (tags portion)

md_files.comment is stored as a single JSON string in the database that holds both
the comments list described above and the tags hash. This accessor exposes just the
tags half: a hash of unique attribute tags applied to this file, keyed by tag name
and pointing to 1 (e.g. tags => { tag_1 => 1 }), so that a given tag can only be
applied to a file once.

This accessor is read-only from outside the module: use add_tag(), clear_tags(),
and delete_tag() to modify its contents. This prevents other modules from storing
arbitrary structures in this column; only the tag_name => 1 shape is allowed.

=cut

has 'tags' => (
    isa => 'HashRef',
    is => 'ro',
    writer => '_set_tags',
    default => sub { {} }
);

=head2 md5checksum()

md_files.md5checksum

=cut

has 'md5checksum' => (
    isa => 'Maybe[Str]',
    is => 'rw'
);

=head2 metadata_id()

ID linking to metadata table

=cut

has 'metadata_id' => (
    isa => 'Maybe[Int]',
    is => 'rw'
);

=head2 urlsource

md_files.urlsource

=cut

has 'urlsource' => (
    isa => 'Maybe[Str]',
    is => 'rw'
);

=head2 urlsource_md5checksum()

md_files.urlsource_md5checksum

=cut

has 'urlsource_md5checksum' => (
    isa => 'Maybe[Str]',
    is => 'rw'
);

=head1 INSTANCE METHODS

=cut

=head2 _prepare_metadata_schema($metadata_schema)

Internal helper. metadata_schema() (and often schema()/people_schema()/phenome_schema())
is frequently constructed by callers sharing one physical database handle across all four
DBIx::Class schema objects, each with its own C<on_connect_do> that sets the search path for
its own schema. DBIx::Class only runs a schema's on_connect_do the first time that particular
schema object issues a query, so if any of the other schema objects sharing the connection
gets queried for the first time after metadata_schema has already connected, it silently
overwrites the shared connection's search path with its own, leaving metadata off of it. Every
MdFiles query after that then fails with "relation md_files does not exist", even though
metadata_schema itself was configured correctly. Call this immediately before any MdFiles
query to force metadata back onto the search path regardless of what else has touched the
shared connection since.

=cut

sub _prepare_metadata_schema {
    my $metadata_schema = shift;
    $metadata_schema->storage->dbh->do('SET search_path TO public, sgn, metadata');
    return $metadata_schema;
}

sub BUILD {
    my $self = shift;
    my $args = shift;

    my $metadata_schema = _prepare_metadata_schema($self->metadata_schema());
    my $file_id = $self->file_id();

    if (!$file_id) {
        die "Need a file ID. Creating new file entries is handled with CXGN::UploadFile.\n";
    }

    my $file_rs = $metadata_schema->resultset("MdFiles")->search(
        {'me.file_id' => $file_id},
        {
            join => 'metadata_id',
            '+select' => ['metadata_id.create_person_id'],
            '+as' => ['create_person_id']
        }
    )->single;

    if (!$file_rs) {
        die "File not found. Is the file ID valid?";
    }

    my $basename = $file_rs->get_column('basename');
    $basename =~ m/(?<TIMESTAMP>\d+-\d+-\d+_\d+:\d+:\d+)_(?<FILENAME>.*)$/;
    $self->basename($basename);
    $self->filename($+{FILENAME});
    $self->timestamp($+{TIMESTAMP});
    $self->dirname($file_rs->get_column('dirname'));
    my $dirname = $file_rs->get_column('dirname');
    $dirname =~ m/(?<USER_DIR>\d+)\/(?<SUBDIR>\w+)/;
    $self->subdirectory($+{SUBDIR});
    $self->user_id($file_rs->get_column('create_person_id'));
    $self->filetype($file_rs->get_column('filetype'));

    my $comment_json = $file_rs->get_column('comment');
    my $comment = $comment_json ? JSON::Any->decode($comment_json) : {};
    $self->_set_comments($comment->{comments} || []);
    $self->_set_tags($comment->{tags} || {});

    $self->alt_filename($file_rs->get_column('alt_filename'));
    $self->md5checksum($file_rs->get_column('md5checksum'));
    $self->metadata_id($file_rs->get_column('metadata_id'));
    $self->urlsource($file_rs->get_column('urlsource'));
    $self->urlsource_md5checksum($file_rs->get_column('urlsource_md5checksum'));
}

sub store {
    my $self = shift;
    my $metadata_schema = _prepare_metadata_schema($self->metadata_schema());

    try {
        my $mdfile_rs = $metadata_schema->resultset("MdFiles")->find({file_id => $self->file_id()});
        $mdfile_rs->update({
            basename => $self->basename(),
            dirname => $self->dirname(),
            filetype => $self->filetype(),
            alt_filename => $self->alt_filename(),
            comment => JSON::Any->encode({ comments => $self->comments(), tags => $self->tags() }),
            md5checksum => $self->md5checksum(),
            metadata_id => $self->metadata_id(),
            urlsource => $self->urlsource(),
            urlsource_md5checksum => $self->urlsource_md5checksum()
        });
    } catch {
        die "An error occurred trying to update file information: $_\n";
    };
}

=head2 set_file_type($type)

Save a new file type in association with the file

=cut

sub set_file_type {
    my $self = shift;
    my $new_type = shift;

    $self->filetype($new_type);
    $self->store();
}

=head2 add_comment($comment)

Appends $comment (a string) to the list of comments stored on this file, and saves
the change to the database.

=cut

sub add_comment {
    my $self = shift;
    my $comment_text = shift;

    my $comments = $self->comments();
    push @$comments, $comment_text;
    $self->_set_comments($comments);
    $self->store();
}

=head2 add_tag($tag)

Adds $tag (a string) as a key in the tags hash stored on this file, and saves the
change to the database. Since tags are stored as hash keys, adding the same tag
more than once has no additional effect and will not die.

=cut

sub add_tag {
    my $self = shift;
    my $tag = shift;

    my $tags = $self->tags();
    $tags->{$tag} = 1;
    $self->_set_tags($tags);
    $self->store();
}

=head2 clear_comments()

Deletes ALL comments stored on this file, indiscriminately, and saves the change
to the database.

NOTE: This function should be used sparingly, if at all. There are very few cases
where deleting a comment is appropriate, and even fewer where deleting every
comment on a file is appropriate. Prefer leaving the comment history intact unless
you have a specific reason to purge it.

=cut

sub clear_comments {
    my $self = shift;

    $self->_set_comments([]);
    $self->store();
}

=head2 clear_tags()

Deletes ALL tags stored on this file, indiscriminately, and saves the change to
the database.

NOTE: Prefer removing individual tags with delete_tag() unless you have a 
specific reason to purge them all.

=cut

sub clear_tags {
    my $self = shift;

    $self->_set_tags({});
    $self->store();
}

=head2 delete_tag($tag)

Deletes $tag (a string) from the tags hash stored on this file, and saves the
change to the database.

=cut

sub delete_tag {
    my $self = shift;
    my $tag = shift;

    my $tags = $self->tags();
    delete $tags->{$tag};
    $self->_set_tags($tags);
    $self->store();
}

=head2 get_path()

Get the full filepath and name for this file.

=cut

sub get_path {
    my $self = shift;
    return $self->archive_path()."/".$self->dirname()."/".$self->basename();
}

=head2 delete_file()

Deletes the file and unlinks file in archive, but does not delete metadata row. 
Useful for some uploads (like images) that don't need to be clogging the database 
after they have been parsed.

=cut

sub delete_file {
    my $self = shift;
    my $metadata_schema = _prepare_metadata_schema($self->metadata_schema());
    my $file_id = $self->file_id();

    try {
        my $mdfile_rs = $metadata_schema->resultset("MdFiles")->find({file_id => $file_id});
        if (!$mdfile_rs) {
            die "No md_file row found with file ID $file_id!\n";
        }
        my $filepath = $self->get_path();
        if (-e $filepath) {
            unlink($filepath) or die "Could not delete file $filepath: $!\n";
        }
        $mdfile_rs->delete();
    } catch {
        die "Error deleting file: $_";
    };
}

=head1 CLASS METHODS

=head2 get_user_archived_files($bcs_schema, $user_id)

Retrieves all files uploaded by a user.

=cut

sub get_user_archived_files {
    my $class = shift;
    my $schema = shift;
    my $user_id = shift;

    my $q = "SELECT file_id, basename, filetype, comment FROM metadata.md_files
        JOIN metadata.md_metadata ON (md_files.metadata_id=md_metadata.metadata_id)
        JOIN sgn_people.sp_person ON (sp_person.sp_person_id=md_metadata.create_person_id)
        WHERE sp_person_id=? AND basename != 'none'";

    my $h = $schema->storage()->dbh()->prepare($q);
    $h->execute($user_id);

    my @data;

    while (my ($file_id, $file_name, $filetype, $comment_json) = $h->fetchrow_array()){
        $file_name =~ m/(?<TIMESTAMP>\d+-\d+-\d+_\d+:\d+:\d+)_(?<FILENAME>.*)$/;
        push @data, {
            file_id => $file_id,
            timestamp => $+{TIMESTAMP},
            filename => $+{FILENAME},
            type => $filetype,
            tags => _parse_tags_string($comment_json)
        };
    }

    return \@data;
}

=head2 get_all_archived_files($bcs_schema)

Retrieves all archived files. Typically used by a curator. 

=cut

sub get_all_archived_files {
    my $class = shift;
    my $schema = shift;

    my $q = "SELECT file_id, basename, sp_person_id, first_name, last_name, filetype, comment FROM metadata.md_files
        JOIN metadata.md_metadata ON (md_files.metadata_id=md_metadata.metadata_id)
        JOIN sgn_people.sp_person ON (sp_person.sp_person_id=md_metadata.create_person_id)
        WHERE basename != 'none'";

    my $h = $schema->storage()->dbh()->prepare($q);
    $h->execute();

    my @data;

    while (my ($file_id, $file_name, $user_id, $first_name, $last_name, $filetype, $comment_json) = $h->fetchrow_array()){
        $file_name =~ m/(?<TIMESTAMP>\d+-\d+-\d+_\d+:\d+:\d+)_(?<FILENAME>.*)$/;
        push @data, {
            file_id => $file_id,
            timestamp => $+{TIMESTAMP},
            filename => $+{FILENAME},
            user_id => $user_id,
            user_name => "$first_name $last_name",
            type => $filetype,
            tags => _parse_tags_string($comment_json)
        };
    }

    return \@data;
}

=head2 _parse_tags_string($comment_json)

Given the raw JSON string stored in a md_files row's comment column, returns
a comma-separated string of the tags applied to that file (or an empty string
if there are none). Used by get_user_archived_files and get_all_archived_files
so callers don't need to know about the {comments=>[], tags=>{}} JSON shape.

=cut

sub _parse_tags_string {
    my $comment_json = shift;

    return '' unless $comment_json;

    my $comment = JSON::Any->decode($comment_json);
    my $tags = $comment->{tags} || {};

    return join(', ', sort keys %$tags);
}

1;