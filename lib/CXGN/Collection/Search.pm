package CXGN::Collection::Search;

=head1 NAME

CXGN::Collection::Search - an object to handle searching for collections
(folders of images and/or files) given criteria

=head1 USAGE

 my $search = CXGN::Collection::Search->new({
     bcs_schema=>$schema,
     collection_id_list=>\@collection_id_list,
     name_list=>\@name_list,
     names_exact=>0,
     description_list=>\@description_list,
     descriptions_exact=>0,
     image_descriptor_list=>\@image_descriptor_list,
     creator_username_list=>\@creator_username_list,
     creator_usernames_exact=>0,
     sp_person_id_list=>\@sp_person_id_list,
     project_id_list=>\@project_id_list,
     project_name_list=>\@project_name_list,
     project_names_exact=>0,
     standalone_only=>0,
     include_obsolete_collections=>0,
     limit=>$limit,
     offset=>$offset
 });
 my ($result, $total_count) = $search->search();

=head1 DESCRIPTION

Mirrors the shape of CXGN::Image::Search: list-based Moose attributes,
raw SQL built from @where_clause / @question_mark_values, a window-function
total count, and LIMIT/OFFSET for DataTables server-side pagination.

One deliberate difference from CXGN::Image::Search: the "projects" a
collection belongs to are fetched via a correlated scalar subquery
(json_agg inside a subquery), not a LEFT JOIN + GROUP BY. A join here would
multiply collection rows per associated project the same way the field_trial
join once duplicated image rows in CXGN::Image::Search — the subquery avoids
that class of bug rather than reproducing it.

File/obsolete predicates for metadata.md_files are read from
CXGN::Collection's $FILE_OBSOLETE_SQL / $FILE_LABEL_COLUMN package
variables, so the two files can't drift out of sync on that assumption.

=head1 AUTHORS

=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;
use JSON;
use CXGN::Collection;   # for $FILE_OBSOLETE_SQL / $FILE_LABEL_COLUMN

has 'bcs_schema' => (
    isa      => 'Bio::Chado::Schema',
    is       => 'rw',
    required => 1,
);

has 'collection_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is  => 'rw',
);

has 'name_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is  => 'rw',
);

has 'names_exact' => (
    isa     => 'Bool|Undef',
    is      => 'rw',
    default => 0,
);

has 'description_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is  => 'rw',
);

has 'descriptions_exact' => (
    isa     => 'Bool|Undef',
    is      => 'rw',
    default => 0,
);

# Matches collections that CONTAIN an image whose name, description, or
# original_filename matches — mirrors the image_description_filename_composite
# behavior in CXGN::Image::Search, wrapped in EXISTS since we're filtering a
# different table (md_collection) than the one the text matches (md_image).

has 'image_name_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is  => 'rw',
);

has 'image_descriptor_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is  => 'rw',
);

has 'creator_username_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is  => 'rw',
);

has 'creator_usernames_exact' => (
    isa     => 'Bool|Undef',
    is      => 'rw',
    default => 0,
);

# Exact sp_person_id match — used for "mine only" filtering, distinct from
# the free-text creator_username_list above.
has 'sp_person_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is  => 'rw',
);

has 'project_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is  => 'rw',
);

has 'project_name_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is  => 'rw',
);

has 'project_names_exact' => (
    isa     => 'Bool|Undef',
    is      => 'rw',
    default => 0,
);

# Only collections with no project scoping at all.
has 'standalone_only' => (
    isa     => 'Bool|Undef',
    is      => 'rw',
    default => 0,
);

has 'include_obsolete_collections' => (
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

    my $collection_id_list            = $self->collection_id_list;
    my $name_list                     = $self->name_list;
    my $names_exact                   = $self->names_exact;
    my $description_list              = $self->description_list;
    my $descriptions_exact            = $self->descriptions_exact;
    my $image_name_list               = $self->image_name_list;
    my $image_descriptor_list         = $self->image_descriptor_list;
    my $creator_username_list         = $self->creator_username_list;
    my $creator_usernames_exact       = $self->creator_usernames_exact;
    my $sp_person_id_list             = $self->sp_person_id_list;
    my $project_id_list               = $self->project_id_list;
    my $project_name_list             = $self->project_name_list;
    my $project_names_exact           = $self->project_names_exact;
    my $standalone_only               = $self->standalone_only;
    my $include_obsolete_collections  = $self->include_obsolete_collections;

    my @where_clause;
    my @and_clause;
    my @question_mark_values;

    if ($collection_id_list && scalar(@$collection_id_list) > 0) {
        my $placeholders = join(",", ("?") x scalar(@$collection_id_list));
        push @where_clause, "collection.collection_id in ($placeholders)";
        push @question_mark_values, @$collection_id_list;
    }

    if ($name_list && scalar(@$name_list) > 0) {
        if ($names_exact) {
            my $placeholders = join(",", ("?") x scalar(@$name_list));
            push @where_clause, "collection.name in ($placeholders)";
            push @question_mark_values, @$name_list;
        } else {
            foreach (@$name_list) {
                push @and_clause, "collection.name ilike ?";
                push @question_mark_values, '%' . $_ . '%';
            }
        }
    }

    if ($description_list && scalar(@$description_list) > 0) {
        if ($descriptions_exact) {
            my $placeholders = join(",", ("?") x scalar(@$description_list));
            push @where_clause, "collection.description in ($placeholders)";
            push @question_mark_values, @$description_list;
        } else {
            foreach (@$description_list) {
                push @and_clause, "collection.description ilike ?";
                push @question_mark_values, '%' . $_ . '%';
            }
        }
    }

    # Each descriptor term is its own EXISTS clause (ANDed at the top level —
    # a collection must contain a matching image for every term supplied),
    # and within each EXISTS the three image columns are ORed together.

    if ($image_name_list && scalar(@$image_name_list) > 0) {
        foreach my $term (@$image_name_list) {
            push @where_clause,
                "EXISTS (SELECT 1 FROM metadata.md_collection_image AS imgname_ci
                        JOIN metadata.md_image AS imgname_img
                            ON (imgname_img.image_id = imgname_ci.image_id)
                        WHERE imgname_ci.collection_id = collection.collection_id
                        AND imgname_img.obsolete = 'f'
                        AND (imgname_img.name ilike ?
                                OR imgname_img.original_filename ilike ?))";
            push @question_mark_values, ('%' . $term . '%') x 2;
        }
    }

    if ($image_descriptor_list && scalar(@$image_descriptor_list) > 0) {
        foreach my $term (@$image_descriptor_list) {
            push @where_clause,
                "EXISTS (SELECT 1 FROM metadata.md_collection_image AS desc_ci
                          JOIN metadata.md_image AS desc_img
                            ON (desc_img.image_id = desc_ci.image_id)
                         WHERE desc_ci.collection_id = collection.collection_id
                           AND desc_img.obsolete = 'f'
                           AND (desc_img.name ilike ?
                                OR desc_img.description ilike ?
                                OR desc_img.original_filename ilike ?))";
            push @question_mark_values, ('%' . $term . '%') x 3;
        }
    }

    if ($creator_username_list && scalar(@$creator_username_list) > 0) {
        if ($creator_usernames_exact) {
            my $placeholders = join(",", ("?") x scalar(@$creator_username_list));
            push @where_clause, "creator.username in ($placeholders)";
            push @question_mark_values, @$creator_username_list;
        } else {
            foreach (@$creator_username_list) {
                push @and_clause, "creator.username ilike ?";
                push @question_mark_values, '%' . $_ . '%';
            }
        }
    }

    if ($sp_person_id_list && scalar(@$sp_person_id_list) > 0) {
        my $placeholders = join(",", ("?") x scalar(@$sp_person_id_list));
        push @where_clause, "collection.sp_person_id in ($placeholders)";
        push @question_mark_values, @$sp_person_id_list;
    }

    if ($project_id_list && scalar(@$project_id_list) > 0) {
        my $placeholders = join(",", ("?") x scalar(@$project_id_list));
        push @where_clause,
            "EXISTS (SELECT 1 FROM phenome.project_md_collection AS pid_pc
                      WHERE pid_pc.collection_id = collection.collection_id
                        AND pid_pc.project_id IN ($placeholders))";
        push @question_mark_values, @$project_id_list;
    }

    if ($project_name_list && scalar(@$project_name_list) > 0) {
        if ($project_names_exact) {
            my $placeholders = join(",", ("?") x scalar(@$project_name_list));
            push @where_clause,
                "EXISTS (SELECT 1 FROM phenome.project_md_collection AS pname_pc
                          JOIN project AS pname_p ON (pname_p.project_id = pname_pc.project_id)
                         WHERE pname_pc.collection_id = collection.collection_id
                           AND pname_p.name IN ($placeholders))";
            push @question_mark_values, @$project_name_list;
        } else {
            foreach my $name (@$project_name_list) {
                push @where_clause,
                    "EXISTS (SELECT 1 FROM phenome.project_md_collection AS pname_pc
                              JOIN project AS pname_p ON (pname_p.project_id = pname_pc.project_id)
                             WHERE pname_pc.collection_id = collection.collection_id
                               AND pname_p.name ilike ?)";
                push @question_mark_values, '%' . $name . '%';
            }
        }
    }

    if ($standalone_only) {
        push @where_clause,
            "NOT EXISTS (SELECT 1 FROM phenome.project_md_collection AS standalone_pc
                          WHERE standalone_pc.collection_id = collection.collection_id)";
    }

    if (!$include_obsolete_collections) {
        push @where_clause, "collection.obsolete = 'f'";
    }

    if (scalar(@and_clause) > 0) {
        my $w = " ( " . (join(" AND ", @and_clause)) . " ) ";
        push @where_clause, $w;
    }

    my $where_clause = scalar(@where_clause) > 0
        ? " WHERE " . (join(" AND ", @where_clause))
        : '';

    my $limit_clause  = $self->limit  ? " LIMIT " . $self->limit   : '';
    my $offset_clause = $self->offset ? " OFFSET " . $self->offset : '';

    my $file_obsolete_sql = $CXGN::Collection::FILE_OBSOLETE_SQL;
    my $file_label_column = $CXGN::Collection::FILE_LABEL_COLUMN;

    my $q = "SELECT collection.collection_id, collection.name, collection.description,
        collection.sp_person_id, creator.username,
        to_char (collection.create_date::timestamp at time zone current_setting('TIMEZONE'), 'YYYY-MM-DD') as create_date,
        to_char (collection.modified_date::timestamp at time zone current_setting('TIMEZONE'), 'YYYY-MM-DD') as modified_date,
        (SELECT count(*)
           FROM metadata.md_collection_image AS ci
           JOIN metadata.md_image AS i ON (i.image_id = ci.image_id)
          WHERE ci.collection_id = collection.collection_id
            AND i.obsolete = 'f') AS image_count,
        (SELECT count(*)
           FROM metadata.md_collection_file AS cf
           JOIN metadata.md_files AS files ON (files.file_id = cf.file_id)
           LEFT JOIN metadata.md_metadata AS file_metadata
                  ON (file_metadata.metadata_id = files.metadata_id)
          WHERE cf.collection_id = collection.collection_id
            AND $file_obsolete_sql) AS file_count,
        COALESCE(
            (SELECT json_agg(json_build_object('project_id', proj.project_id, 'name', proj.name))
               FROM phenome.project_md_collection AS pc
               JOIN project AS proj ON (proj.project_id = pc.project_id)
              WHERE pc.collection_id = collection.collection_id),
            '[]'
        ) AS projects_json,
        count(collection.collection_id) OVER() AS full_count
        FROM metadata.md_collection AS collection
        LEFT JOIN sgn_people.sp_person AS creator ON (creator.sp_person_id = collection.sp_person_id)
        $where_clause
        ORDER BY lower(collection.name)
        $limit_clause
        $offset_clause;";

    # print STDERR Dumper $q;
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute(@question_mark_values);

    my @result;
    my $total_count = 0;
    while (my ($collection_id, $name, $description, $sp_person_id, $username,
               $create_date, $modified_date, $image_count, $file_count,
               $projects_json, $full_count) = $h->fetchrow_array()) {
        push @result, {
            collection_id  => $collection_id,
            name           => $name,
            description    => $description,
            sp_person_id   => $sp_person_id,
            username       => $username,
            create_date    => $create_date,
            modified_date  => $modified_date,
            image_count    => $image_count,
            file_count     => $file_count,
            projects       => decode_json($projects_json),
        };
        $total_count = $full_count;
    }

    return (\@result, $total_count);
}

1;