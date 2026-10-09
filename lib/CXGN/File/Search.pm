package CXGN::File::Search;

=head1 NAME

CXGN::File::Search - an object to handle searching for stored files
(metadata.md_files) given criteria

=head1 USAGE

 my $file_search = CXGN::File::Search->new({
     bcs_schema              => $schema,
     file_id_list            => \@file_id_list,
     basenames_exact         => 0,
     basename_list           => \@basename_list,
     comments_exact          => 0,
     comment_list            => \@comment_list,
     filetypes_exact         => 0,
     filetype_list           => \@filetype_list,
     uploader_usernames_exact=> 0,
     uploader_username_list  => \@uploader_username_list,
     uploader_id_list        => \@uploader_id_list,
     collection_id_list      => \@collection_id_list,
     include_obsolete_files  => 0,
     limit                   => $limit,
     offset                  => $offset,
 });
 my ($result, $total_count) = $file_search->search();

=head1 DESCRIPTION

Mirrors the shape of CXGN::Image::Search and CXGN::Collection::Search:
list-based Moose attributes, raw SQL built from @where_clause /
@question_mark_values, a window-function total count, and LIMIT/OFFSET for
DataTables server-side pagination.

Files are not part of the chado schema proper, but the search runs on the
same database connection the bcs_schema carries (metadata.* lives alongside
phenome.* there), matching how CXGN::Collection::Search accesses the DB.

Obsolescence is decided by the file's md_metadata row via the shared
CXGN::Collection $FILE_OBSOLETE_SQL predicate so the collection modules and
this one can't drift.

=head1 AUTHORS

=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;
use CXGN::Collection;   # for $FILE_OBSOLETE_SQL

has 'bcs_schema' => (
    isa      => 'Bio::Chado::Schema',
    is       => 'rw',
    required => 1,
);

has 'file_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is  => 'rw',
);

has 'basenames_exact' => (
    isa     => 'Bool|Undef',
    is      => 'rw',
    default => 0,
);

has 'basename_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is  => 'rw',
);

has 'comments_exact' => (
    isa     => 'Bool|Undef',
    is      => 'rw',
    default => 0,
);

has 'comment_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is  => 'rw',
);

has 'filetypes_exact' => (
    isa     => 'Bool|Undef',
    is      => 'rw',
    default => 0,
);

has 'filetype_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is  => 'rw',
);

has 'uploader_usernames_exact' => (
    isa     => 'Bool|Undef',
    is      => 'rw',
    default => 0,
);

has 'uploader_username_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is  => 'rw',
);

has 'uploader_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is  => 'rw',
);

# Only files that are members of these collections.
has 'collection_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is  => 'rw',
);

has 'include_obsolete_files' => (
    isa     => 'Bool|Undef',
    is      => 'rw',
    default => 0,
);

has 'limit' => (
    isa => 'Int|Undef',
    is  => 'rw',
);

has 'offset' => (
    isa => 'Int|Undef',
    is  => 'rw',
);

sub search {
    my $self = shift;
    my $schema = $self->bcs_schema();

    my $file_id_list                   = $self->file_id_list;
    my $basename_list                  = $self->basename_list;
    my $basenames_exact                = $self->basenames_exact;
    my $comment_list                   = $self->comment_list;
    my $comments_exact                 = $self->comments_exact;
    my $filetype_list                  = $self->filetype_list;
    my $filetypes_exact                = $self->filetypes_exact;
    my $uploader_username_list         = $self->uploader_username_list;
    my $uploader_usernames_exact       = $self->uploader_usernames_exact;
    my $uploader_id_list               = $self->uploader_id_list;
    my $collection_id_list             = $self->collection_id_list;
    my $include_obsolete_files         = $self->include_obsolete_files;

    my @where_clause;
    my @and_clause;
    my @basename_or_clause;
    my @comment_or_clause;
    my @question_mark_values;

    if ($file_id_list && scalar(@$file_id_list) > 0) {
        my $placeholders = join(",", ("?") x scalar(@$file_id_list));
        push @where_clause, "files.file_id in ($placeholders)";
        push @question_mark_values, @$file_id_list;
    }

    if ($basename_list && scalar(@$basename_list) > 0) {
        if ($basenames_exact) {
            my $placeholders = join(",", ("?") x scalar(@$basename_list));
            push @where_clause, "files.basename in ($placeholders)";
            push @question_mark_values, @$basename_list;
        } else {
            foreach (@$basename_list) {
                push @basename_or_clause, "files.basename ilike ?";
                push @question_mark_values, '%' . $_ . '%';
            }
        }
    }

    if ($comment_list && scalar(@$comment_list) > 0) {
        if ($comments_exact) {
            my $placeholders = join(",", ("?") x scalar(@$comment_list));
            push @where_clause, "files.comment in ($placeholders)";
            push @question_mark_values, @$comment_list;
        } else {
            foreach (@$comment_list) {
                push @comment_or_clause, "files.comment ilike ?";
                push @question_mark_values, '%' . $_ . '%';
            }
        }
    }

    if ($filetype_list && scalar(@$filetype_list) > 0) {
        if ($filetypes_exact) {
            my $placeholders = join(",", ("?") x scalar(@$filetype_list));
            push @where_clause, "files.filetype in ($placeholders)";
            push @question_mark_values, @$filetype_list;
        } else {
            foreach (@$filetype_list) {
                push @and_clause, "files.filetype ilike ?";
                push @question_mark_values, '%' . $_ . '%';
            }
        }
    }

    if ($uploader_username_list && scalar(@$uploader_username_list) > 0) {
        if ($uploader_usernames_exact) {
            my $placeholders = join(",", ("?") x scalar(@$uploader_username_list));
            push @where_clause, "uploader.username in ($placeholders)";
            push @question_mark_values, @$uploader_username_list;
        } else {
            foreach (@$uploader_username_list) {
                push @and_clause, "uploader.username ilike ?";
                push @question_mark_values, '%' . $_ . '%';
            }
        }
    }

    if ($uploader_id_list && scalar(@$uploader_id_list) > 0) {
        my $placeholders = join(",", ("?") x scalar(@$uploader_id_list));
        push @where_clause, "file_metadata.create_person_id in ($placeholders)";
        push @question_mark_values, @$uploader_id_list;
    }

    if ($collection_id_list && scalar(@$collection_id_list) > 0) {
        my $placeholders = join(",", ("?") x scalar(@$collection_id_list));
        push @where_clause,
            "EXISTS (SELECT 1 FROM metadata.md_collection_file AS collection_membership
                     WHERE collection_membership.file_id = files.file_id
                       AND collection_membership.collection_id IN ($placeholders))";
        push @question_mark_values, @$collection_id_list;
    }

    if (!$include_obsolete_files) {
        push @where_clause, $CXGN::Collection::FILE_OBSOLETE_SQL;
    }

    if (scalar(@basename_or_clause) > 0) {
        my $w = " ( " . (join (" OR ", @basename_or_clause)) . " ) ";
        push @where_clause, $w;
    }

    if (scalar(@comment_or_clause) > 0) {
        my $w = " ( " . (join (" OR ", @comment_or_clause)) . " ) ";
        push @where_clause, $w;
    }

    if (scalar(@and_clause) > 0) {
        my $w = " ( " . (join (" AND ", @and_clause)) . " ) ";
        push @where_clause, $w;
    }

    my $where_clause = scalar(@where_clause) > 0
        ? " WHERE " . (join(" AND ", @where_clause))
        : '';

    my $limit_clause  = $self->limit  ? " LIMIT " . $self->limit   : '';
    my $offset_clause = $self->offset ? " OFFSET " . $self->offset : '';

    my $q = "SELECT files.file_id, files.basename, files.dirname, files.filetype,
        files.comment, files.md5checksum, files.metadata_id,
        file_metadata.create_person_id AS sp_person_id, uploader.username,
        to_char (file_metadata.create_date::timestamp at time zone current_setting('TIMEZONE'), 'YYYY-MM-DD') as create_date,
        to_char (file_metadata.modified_date::timestamp at time zone current_setting('TIMEZONE'), 'YYYY-MM-DD') as modified_date,
        file_metadata.obsolete,
        count(files.file_id) OVER() AS full_count
        FROM metadata.md_files AS files
        LEFT JOIN metadata.md_metadata AS file_metadata
               ON (file_metadata.metadata_id = files.metadata_id)
        LEFT JOIN sgn_people.sp_person AS uploader
               ON (uploader.sp_person_id = file_metadata.create_person_id)
        $where_clause
        ORDER BY files.file_id DESC
        $limit_clause
        $offset_clause;";

    # print STDERR Dumper $q;
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute(@question_mark_values);

    my @result;
    my $total_count = 0;
    while (my ($file_id, $basename, $dirname, $filetype, $comment, $md5checksum,
               $metadata_id, $sp_person_id, $username, $create_date,
               $modified_date, $obsolete, $full_count) = $h->fetchrow_array()) {
        push @result, {
            file_id     => $file_id,
            basename    => $basename,
            dirname     => $dirname,
            filetype    => $filetype,
            comment     => $comment,
            md5checksum => $md5checksum,
            metadata_id => $metadata_id,
            sp_person_id => $sp_person_id,
            username    => $username,
            create_date => $create_date,
            modified_date => $modified_date,
            obsolete    => $obsolete,
        };
        $total_count = $full_count;
    }

    return (\@result, $total_count);
}

1;