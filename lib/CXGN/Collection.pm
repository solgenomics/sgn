package CXGN::Collection;

=head1 NAME

CXGN::Collection - named collections ("folders") of images and files

=head1 USAGE

 my $collection = CXGN::Collection->new({ bcs_schema => $schema });

 my $id = $collection->create_collection({
     name         => 'Gel Images 2026',
     description  => 'Gels from the June extraction',
     sp_person_id => $sp_person_id,
     project_id   => $trial_id,      # optional; omit for a standalone folder
 });

 $collection->add_images($id, \@image_ids);
 $collection->add_files($id, \@file_ids);
 my $contents = $collection->get_contents($id);

=head1 DESCRIPTION

A collection is a row in metadata.md_collection. Membership lives in
metadata.md_collection_image and metadata.md_collection_file. A collection may
be scoped to a project via phenome.project_md_collection, or standalone.

Name uniqueness is enforced here rather than in the schema, because names must
be unique per context, not globally.

=head1 AUTHORS

=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;

has 'bcs_schema' => (
    isa      => 'Bio::Chado::Schema',
    is       => 'rw',
    required => 1,
);

our $MAX_NAME_LENGTH = 255;

# VERIFY: metadata.md_files has no obsolete column of its own; obsolescence is
# expected to live on the md_metadata row it points at. If md_metadata.obsolete
# is boolean rather than integer, change this to "file_metadata.obsolete = 'f'".
# If md_files does carry its own obsolete, change it to "files.obsolete = 'f'".
# This is the ONLY place that predicate appears.
our $FILE_OBSOLETE_SQL = "COALESCE(file_metadata.obsolete, 0) = 0";

# VERIFY: the column to show as a file's label.
our $FILE_LABEL_COLUMN = 'files.basename';

sub _dbh { 
    return $_[0]->bcs_schema->storage->dbh(); 
}

# ------------------------------------------------------------------ helpers

sub _clean_name {
    my ($self, $name) = @_;
    $name = '' unless defined $name;
    $name =~ s/^\s+|\s+$//g;
    $name =~ s/[\r\n\t]+/ /g;

    die "A folder name is required.\n" unless length $name;
    die "Folder names must be $MAX_NAME_LENGTH characters or fewer.\n"
        if length($name) > $MAX_NAME_LENGTH;
    return $name;
}

sub _clean_ids {
    my ($self, $ids) = @_;
    return [] unless $ids && ref($ids) eq 'ARRAY';
    my %seen;
    return [ grep { !$seen{$_}++ }
             grep { defined $_ && $_ =~ /^\d+$/ } @$ids ];
}

# Returns the collection_id of a live collection with this name in this
# context, or undef. $project_id undef means "among standalone collections".
sub _find_by_name {
    my ($self, $name, $project_id) = @_;

    my ($sql, @vals);
    if ($project_id) {
        $sql = "SELECT c.collection_id
                  FROM metadata.md_collection AS c
                  JOIN phenome.project_md_collection AS pc
                    ON (pc.collection_id = c.collection_id)
                 WHERE lower(c.name) = lower(?)
                   AND c.obsolete = 'f'
                   AND pc.project_id = ?
                 LIMIT 1";
        @vals = ($name, $project_id);
    }
    else {
        $sql = "SELECT c.collection_id
                  FROM metadata.md_collection AS c
                 WHERE lower(c.name) = lower(?)
                   AND c.obsolete = 'f'
                   AND NOT EXISTS (
                       SELECT 1 FROM phenome.project_md_collection AS pc
                        WHERE pc.collection_id = c.collection_id
                   )
                 LIMIT 1";
        @vals = ($name);
    }

    my $h = $self->_dbh->prepare($sql);
    $h->execute(@vals);
    my ($id) = $h->fetchrow_array();
    return $id;
}

sub _assert_name_available {
    my ($self, $name, $project_id, $ignore_collection_id) = @_;
    my $existing = $self->_find_by_name($name, $project_id);
    return 1 unless $existing;
    return 1 if $ignore_collection_id && $existing == $ignore_collection_id;

    my $where = $project_id ? "in this trial" : "here";
    die "A folder named '$name' already exists $where.\n";
}

sub _assert_exists {
    my ($self, $collection_id) = @_;
    die "A valid folder id is required.\n"
        unless defined $collection_id && $collection_id =~ /^\d+$/;
    my $h = $self->_dbh->prepare(
        "SELECT 1 FROM metadata.md_collection
          WHERE collection_id = ? AND obsolete = 'f'"
    );
    $h->execute($collection_id);
    my ($found) = $h->fetchrow_array();
    die "Folder $collection_id was not found.\n" unless $found;
    return 1;
}

# ------------------------------------------------------------------- create

sub create_collection {
    my ($self, $args) = @_;
    my $name       = $self->_clean_name($args->{name});
    my $project_id = $args->{project_id};

    #if (defined $project_id && $project_id !~ /^\d+$/) {
     #   return "project_id must be numeric";
    #};


    $self->_assert_name_available($name, $project_id);

    my $collection_id;
    $self->bcs_schema->txn_do(sub {
        my $h = $self->_dbh->prepare(
            "INSERT INTO metadata.md_collection
                    (name, description, sp_person_id, obsolete)
             VALUES (?, ?, ?, 'f')
             RETURNING collection_id"
        );
        $h->execute($name, $args->{description}, $args->{sp_person_id});
        ($collection_id) = $h->fetchrow_array();

        if ($project_id) {
            $self->_dbh->prepare(
                "INSERT INTO phenome.project_md_collection (project_id, collection_id)
                 VALUES (?, ?)"
            )->execute($project_id, $collection_id);
        }
    });

    return $collection_id;
}

# --------------------------------------------------------------------- read

sub get_collection {
    my ($self, $collection_id) = @_;
    return undef unless defined $collection_id && $collection_id =~ /^\d+$/;

    my $h = $self->_dbh->prepare(
        "SELECT c.collection_id, c.name, c.description, c.sp_person_id,
                person.username,
                to_char(c.create_date,   'YYYY-MM-DD') AS create_date,
                to_char(c.modified_date, 'YYYY-MM-DD') AS modified_date
           FROM metadata.md_collection AS c
           LEFT JOIN sgn_people.sp_person AS person
                  ON (person.sp_person_id = c.sp_person_id)
          WHERE c.collection_id = ? AND c.obsolete = 'f'"
    );
    $h->execute($collection_id);
    my $row = $h->fetchrow_hashref();
    return undef unless $row;

    $row->{projects}    = $self->get_projects($collection_id);
    $row->{image_count} = scalar @{ $self->get_image_ids($collection_id) };
    $row->{file_count}  = scalar @{ $self->get_file_ids($collection_id) };
    return $row;
}

=head2 get_collections

 Args: { project_id => $id, sp_person_id => $id, standalone_only => 1 }

 project_id      - only collections scoped to that project
 standalone_only - only collections with no project scope
 sp_person_id    - only collections created by that person

=cut

sub get_collections {
    my ($self, $args) = @_;
    $args ||= {};

    my @where = ("c.obsolete = 'f'");
    my @vals;

    if ($args->{project_id}) {
        push @where, "EXISTS (SELECT 1 FROM phenome.project_md_collection AS pc
                               WHERE pc.collection_id = c.collection_id
                                 AND pc.project_id = ?)";
        push @vals, $args->{project_id};
    }
    elsif ($args->{standalone_only}) {
        push @where, "NOT EXISTS (SELECT 1 FROM phenome.project_md_collection AS pc
                                   WHERE pc.collection_id = c.collection_id)";
    }

    if ($args->{sp_person_id}) {
        push @where, "c.sp_person_id = ?";
        push @vals, $args->{sp_person_id};
    }

    if ($args->{collection_type}) {
        unless ($args->{collection_type} =~ /^(image|file|mixed)$/) {
            die "collection_type must be image, file, or mixed.\n";
        }
        push @where, "c.collection_type = ?";
        push @vals, $args->{collection_type};
    }

    my $where = join(' AND ', @where);

    # Counts come from correlated subqueries rather than joins: two LEFT JOINs
    # onto the membership tables would multiply rows and inflate both counts.
    my $h = $self->_dbh->prepare(
        "SELECT c.collection_id, c.name, c.description, c.sp_person_id,
                person.username,
                to_char(c.create_date,   'YYYY-MM-DD') AS create_date,
                to_char(c.modified_date, 'YYYY-MM-DD') AS modified_date,
                (SELECT count(*)
                   FROM metadata.md_collection_image AS ci
                   JOIN metadata.md_image AS i ON (i.image_id = ci.image_id)
                  WHERE ci.collection_id = c.collection_id
                    AND i.obsolete = 'f') AS image_count,
                (SELECT count(*)
                   FROM metadata.md_collection_file AS cf
                   JOIN metadata.md_files AS files ON (files.file_id = cf.file_id)
                   LEFT JOIN metadata.md_metadata AS file_metadata
                          ON (file_metadata.metadata_id = files.metadata_id)
                  WHERE cf.collection_id = c.collection_id
                    AND $FILE_OBSOLETE_SQL) AS file_count
           FROM metadata.md_collection AS c
           LEFT JOIN sgn_people.sp_person AS person
                  ON (person.sp_person_id = c.sp_person_id)
          WHERE $where
          ORDER BY lower(c.name)"
    );
    $h->execute(@vals);

    my @collections;
    while (my $row = $h->fetchrow_hashref()) { push @collections, { %$row }; }
    return \@collections;
}

=head2 get_contents

Returns an arrayref of { item_type, item_id, label, description, rank },
images first then files, each ordered by rank then label.

=cut

sub get_contents {
    my ($self, $collection_id) = @_;

    my $h = $self->_dbh->prepare(
        "SELECT 'image' AS item_type, i.image_id AS item_id,
                COALESCE(NULLIF(i.original_filename, ''), i.name) AS label,
                i.description, ci.rank
           FROM metadata.md_collection_image AS ci
           JOIN metadata.md_image AS i ON (i.image_id = ci.image_id)
          WHERE ci.collection_id = ? AND i.obsolete = 'f'
         UNION ALL
         SELECT 'file' AS item_type, files.file_id AS item_id,
                $FILE_LABEL_COLUMN AS label,
                files.comment AS description, cf.rank
           FROM metadata.md_collection_file AS cf
           JOIN metadata.md_files AS files ON (files.file_id = cf.file_id)
           LEFT JOIN metadata.md_metadata AS file_metadata
                  ON (file_metadata.metadata_id = files.metadata_id)
          WHERE cf.collection_id = ? AND $FILE_OBSOLETE_SQL
         ORDER BY item_type DESC, rank, label"
    );
    $h->execute($collection_id, $collection_id);

    my @contents;
    while (my $row = $h->fetchrow_hashref()) { push @contents, { %$row }; }
    return \@contents;
}

sub get_image_ids {
    my ($self, $collection_id) = @_;
    my $h = $self->_dbh->prepare(
        "SELECT ci.image_id
           FROM metadata.md_collection_image AS ci
           JOIN metadata.md_image AS i ON (i.image_id = ci.image_id)
          WHERE ci.collection_id = ? AND i.obsolete = 'f'
          ORDER BY ci.rank, ci.image_id"
    );
    $h->execute($collection_id);
    my @ids;
    while (my ($id) = $h->fetchrow_array()) { push @ids, $id; }
    return \@ids;
}

sub get_file_ids {
    my ($self, $collection_id) = @_;
    my $h = $self->_dbh->prepare(
        "SELECT cf.file_id
           FROM metadata.md_collection_file AS cf
           JOIN metadata.md_files AS files ON (files.file_id = cf.file_id)
           LEFT JOIN metadata.md_metadata AS file_metadata
                  ON (file_metadata.metadata_id = files.metadata_id)
          WHERE cf.collection_id = ? AND $FILE_OBSOLETE_SQL
          ORDER BY cf.rank, cf.file_id"
    );
    $h->execute($collection_id);
    my @ids;
    while (my ($id) = $h->fetchrow_array()) { push @ids, $id; }
    return \@ids;
}

# ------------------------------------------------------------------- modify

sub rename_collection {
    my ($self, $collection_id, $new_name) = @_;
    $self->_assert_exists($collection_id);
    $new_name = $self->_clean_name($new_name);

    # Uniqueness is checked in each context this collection belongs to.
    my $projects = $self->get_projects($collection_id);
    if (@$projects) {
        foreach my $p (@$projects) {
            $self->_assert_name_available($new_name, $p->{project_id}, $collection_id);
        }
    }
    else {
        $self->_assert_name_available($new_name, undef, $collection_id);
    }

    $self->_dbh->prepare(
        "UPDATE metadata.md_collection
            SET name = ?, modified_date = now()
          WHERE collection_id = ?"
    )->execute($new_name, $collection_id);
    return 1;
}

sub set_description {
    my ($self, $collection_id, $description) = @_;
    $self->_assert_exists($collection_id);
    $self->_dbh->prepare(
        "UPDATE metadata.md_collection
            SET description = ?, modified_date = now()
          WHERE collection_id = ?"
    )->execute($description, $collection_id);
    return 1;
}

sub obsolete_collection {
    my ($self, $collection_id) = @_;
    $self->_assert_exists($collection_id);
    # Membership rows are left intact so un-obsoleting restores the folder.
    $self->_dbh->prepare(
        "UPDATE metadata.md_collection
            SET obsolete = 't', modified_date = now()
          WHERE collection_id = ?"
    )->execute($collection_id);
    return 1;
}

# --------------------------------------------------------------- membership

# $type is 'image' or 'file'
sub _add_items {
    my ($self, $collection_id, $ids, $type) = @_;
    $self->_assert_exists($collection_id);
    my $clean = $self->_clean_ids($ids);
    return 0 unless @$clean;

    my ($table, $column) = $type eq 'image'
        ? ('metadata.md_collection_image', 'image_id')
        : ('metadata.md_collection_file',  'file_id');

    my $added = 0;
    $self->bcs_schema->txn_do(sub {
        my $next_rank_h = $self->_dbh->prepare(
            "SELECT COALESCE(max(rank), -1) + 1 FROM $table WHERE collection_id = ?"
        );
        $next_rank_h->execute($collection_id);
        my ($next_rank) = $next_rank_h->fetchrow_array();

        my $insert = $self->_dbh->prepare(
            "INSERT INTO $table (collection_id, $column, rank)
             VALUES (?, ?, ?)
             ON CONFLICT (collection_id, $column) DO NOTHING"
        );

        foreach my $id (@$clean) {
            $insert->execute($collection_id, $id, $next_rank++);
            $added++;
        }
    });

    return $added;
}

sub _remove_items {
    my ($self, $collection_id, $ids, $type) = @_;
    $self->_assert_exists($collection_id);
    my $clean = $self->_clean_ids($ids);
    return 0 unless @$clean;

    my ($table, $column) = $type eq 'image'
        ? ('metadata.md_collection_image', 'image_id')
        : ('metadata.md_collection_file',  'file_id');

    my $placeholders = join(',', ('?') x scalar(@$clean));
    my $h = $self->_dbh->prepare(
        "DELETE FROM $table WHERE collection_id = ? AND $column IN ($placeholders)"
    );
    my $removed = $h->execute($collection_id, @$clean);
    return ($removed && $removed =~ /^\d+$/) ? $removed : 0;
}

sub add_images    { return $_[0]->_add_items($_[1], $_[2], 'image'); }
sub add_files     { return $_[0]->_add_items($_[1], $_[2], 'file');  }
sub remove_images { return $_[0]->_remove_items($_[1], $_[2], 'image'); }
sub remove_files  { return $_[0]->_remove_items($_[1], $_[2], 'file');  }

=head2 set_order

 Args: $collection_id, 'image'|'file', \@ordered_ids

Sets rank to match the supplied order. Ids not listed are left alone.

=cut

sub set_order {
    my ($self, $collection_id, $type, $ordered_ids) = @_;
    $self->_assert_exists($collection_id);
    my $clean = $self->_clean_ids($ordered_ids);
    return 0 unless @$clean;

    my ($table, $column) = $type eq 'image'
        ? ('metadata.md_collection_image', 'image_id')
        : ('metadata.md_collection_file',  'file_id');

    $self->bcs_schema->txn_do(sub {
        my $h = $self->_dbh->prepare(
            "UPDATE $table SET rank = ? WHERE collection_id = ? AND $column = ?"
        );
        my $rank = 0;
        foreach my $id (@$clean) { $h->execute($rank++, $collection_id, $id); }
    });
    return scalar @$clean;
}

# ------------------------------------------------------------ project scope

sub get_projects {
    my ($self, $collection_id) = @_;
    my $h = $self->_dbh->prepare(
        "SELECT p.project_id, p.name
           FROM phenome.project_md_collection AS pc
           JOIN project AS p ON (p.project_id = pc.project_id)
          WHERE pc.collection_id = ?
          ORDER BY p.name"
    );
    $h->execute($collection_id);
    my @projects;
    while (my $row = $h->fetchrow_hashref()) { push @projects, { %$row }; }
    return \@projects;
}

sub attach_to_project {
    my ($self, $collection_id, $project_id) = @_;
    $self->_assert_exists($collection_id);
    die "project_id must be numeric.\n"
        unless defined $project_id && $project_id =~ /^\d+$/;

    my $collection = $self->get_collection($collection_id);
    $self->_assert_name_available($collection->{name}, $project_id, $collection_id);

    $self->_dbh->prepare(
        "INSERT INTO phenome.project_md_collection (project_id, collection_id)
         VALUES (?, ?) ON CONFLICT (project_id, collection_id) DO NOTHING"
    )->execute($project_id, $collection_id);
    return 1;
}

sub detach_from_project {
    my ($self, $collection_id, $project_id) = @_;
    $self->_dbh->prepare(
        "DELETE FROM phenome.project_md_collection
          WHERE collection_id = ? AND project_id = ?"
    )->execute($collection_id, $project_id);
    return 1;
}

# ---------------------------------------------- reverse lookups for detail pages

sub get_collections_for_image {
    my ($self, $image_id) = @_;
    return $self->_collections_for_item($image_id, 'image');
}

sub get_collections_for_file {
    my ($self, $file_id) = @_;
    return $self->_collections_for_item($file_id, 'file');
}

sub _collections_for_item {
    my ($self, $item_id, $type) = @_;
    return [] unless defined $item_id && $item_id =~ /^\d+$/;

    my ($table, $column) = $type eq 'image'
        ? ('metadata.md_collection_image', 'image_id')
        : ('metadata.md_collection_file',  'file_id');

    my $h = $self->_dbh->prepare(
        "SELECT c.collection_id, c.name
           FROM metadata.md_collection AS c
           JOIN $table AS m ON (m.collection_id = c.collection_id)
          WHERE m.$column = ? AND c.obsolete = 'f'
          ORDER BY lower(c.name)"
    );
    $h->execute($item_id);
    my @out;
    while (my $row = $h->fetchrow_hashref()) { push @out, { %$row }; }
    return \@out;
}

1;