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
use SGN::Model::Cvterm;
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

has 'collection_type_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is  => 'rw',
);

# Matches collections that CONTAIN a file whose basename or comment matches —
# mirrors the image_name_list EXISTS behavior above, but against
# metadata.md_files via md_collection_file. Obsolescence predicate uses
# CXGN::Collection's $FILE_OBSOLETE_SQL so the two files can't drift.
has 'file_name_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is  => 'rw',
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
    my $collection_type_list          = $self->collection_type_list;
    my $standalone_only               = $self->standalone_only;
    my $include_obsolete_collections  = $self->include_obsolete_collections;

    my $file_obsolete_sql = $CXGN::Collection::FILE_OBSOLETE_SQL;
    my $file_label_column = $CXGN::Collection::FILE_LABEL_COLUMN;

    my $file_name_list = $self->file_name_list;

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

    if ($collection_type_list && scalar(@$collection_type_list) > 0) {
        my $placeholders = join(",", ("?") x scalar(@$collection_type_list));
        push @where_clause, "collection.collection_type in ($placeholders)";
        push @question_mark_values, @$collection_type_list;
    }

    if ($file_name_list && scalar(@$file_name_list) > 0) {
        foreach my $term (@$file_name_list) {
            push @where_clause,
                "EXISTS (SELECT 1 FROM metadata.md_collection_file AS fname_cf
                          JOIN metadata.md_files AS fname_files
                            ON (fname_files.file_id = fname_cf.file_id)
                          LEFT JOIN metadata.md_metadata AS fname_fm
                                 ON (fname_fm.metadata_id = fname_files.metadata_id)
                         WHERE fname_cf.collection_id = collection.collection_id
                           AND $file_obsolete_sql
                           AND (fname_files.basename ilike ?
                                 OR fname_files.comment ilike ?))";
            push @question_mark_values, ('%' . $term . '%') x 2;
        }
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
        collection.collection_type,
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
    while (my ($collection_id, $name, $description, $collection_type,
               $sp_person_id, $username,
               $create_date, $modified_date, $image_count, $file_count,
               $projects_json, $full_count) = $h->fetchrow_array()) {
        push @result, {
            collection_id  => $collection_id,
            name           => $name,
            description    => $description,
            collection_type => $collection_type,
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

=head2 search_grouped_by_program()

 Returns ( undef, $groups ) where $groups is:

 {
   programs => [
     { program_id, program_name, projects => [
         { project_id, project_name, collections => [ <collection rows> ] }
     ] }
   ],
   no_program => [ { project_id, project_name, collections => [...] } ],
   standalone => [ <collection rows> ],
 }

 A project maps to its breeding program via project_relationship; a project
 that IS a breeding program (direct attach) maps to itself. Projects with no
 program land in no_program; collections with no project land in standalone.

=cut

sub search_grouped_by_program {
    my $self = shift;
    my $schema = $self->bcs_schema();

    my $collection_type_list = $self->collection_type_list;

    my @where_clause = ("collection.obsolete = 'f'");
    my @question_mark_values;

    if ($collection_type_list && scalar(@$collection_type_list) > 0) {
        my $placeholders = join(",", ("?") x scalar(@$collection_type_list));
        push @where_clause, "collection.collection_type in ($placeholders)";
        push @question_mark_values, @$collection_type_list;
    }

    my $where_clause = " WHERE " . (join(" AND ", @where_clause));

    my $file_obsolete_sql = $CXGN::Collection::FILE_OBSOLETE_SQL;

    # Each (collection, project) pair becomes one row: program_id is that
    # project's breeding program (the project itself when it IS a program),
    # NULL when the project has none; collections with no project scope get a
    # single all-NULL row via the LEFT JOINs.
    my $bp_rel_cvterm_sql =
        "(SELECT cvterm_id FROM cvterm JOIN cv USING(cv_id)
          WHERE cv.name = 'project_relationship'
            AND cvterm.name = 'breeding_program_trial_relationship')";
    my $q = "SELECT collection.collection_id, collection.name, collection.description,
        collection.collection_type,
        collection.sp_person_id, creator.username,
        to_char (collection.create_date, 'YYYY-MM-DD') as create_date,
        to_char (collection.modified_date, 'YYYY-MM-DD') as modified_date,
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
        proj.project_id AS linked_project_id,
        proj.name AS linked_project_name,
        COALESCE(pr.object_project_id, proj.project_id) AS program_id,
        COALESCE(bp.name, proj.name) AS program_name
        FROM metadata.md_collection AS collection
        LEFT JOIN sgn_people.sp_person AS creator ON (creator.sp_person_id = collection.sp_person_id)
        LEFT JOIN phenome.project_md_collection AS pc
               ON (pc.collection_id = collection.collection_id)
        LEFT JOIN project AS proj ON (proj.project_id = pc.project_id)
        LEFT JOIN project_relationship AS pr
               ON (pr.subject_project_id = proj.project_id
                   AND pr.type_id = $bp_rel_cvterm_sql)
        LEFT JOIN project AS bp ON (bp.project_id = pr.object_project_id)
        $where_clause
        ORDER BY collection.collection_id
    ";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute(@question_mark_values);

    my $cvterm_id = SGN::Model::Cvterm->get_cvterm_row(
        $schema, 'breeding_program', 'project_property'
    )->cvterm_id();
    my %is_program;
    my $prop_h = $schema->storage->dbh()->prepare(
        "SELECT project_id FROM projectprop WHERE type_id = ?"
    );
    $prop_h->execute($cvterm_id);
    while (my ($pid) = $prop_h->fetchrow_array()) { $is_program{$pid} = 1; }

    my %collection_by_id;
    my %programs;
    my %program_order;
    my %projects_in_program;
    my @no_program;
    my %project_in_no_program;
    my @standalone;
    my %pushed;   # "$cid:$where" guards so a collection appears once per branch

    my $add_collection_row = sub {
        my ($row) = @_;
        my $projects = decode_json($row->{projects_json});
        # Projects that are breeding programs themselves are shown as tree
        # parents, not as trial links on the collection row.
        @$projects = grep { !$is_program{ $_->{project_id} } } @$projects;
        return {
            collection_id   => $row->{collection_id},
            name            => $row->{name},
            description     => $row->{description},
            collection_type => $row->{collection_type},
            sp_person_id    => $row->{sp_person_id},
            username        => $row->{username},
            create_date     => $row->{create_date},
            modified_date   => $row->{modified_date},
            image_count     => $row->{image_count},
            file_count      => $row->{file_count},
            projects        => $projects,
        };
    };

    while (my $row = $h->fetchrow_hashref()) {
        my $cid = $row->{collection_id};

        my $base = $collection_by_id{$cid}
            ||= $add_collection_row->($row);

        my $linked_project_id = $row->{linked_project_id};

        if (!defined $linked_project_id) {
            push @standalone, $base unless $pushed{"$cid:standalone"}++;
            next;
        }

        # Direct program attach: hang the collection straight off the
        # program node, no intermediate project node.
        if ($is_program{$linked_project_id}) {
            my $program = ($programs{ $row->{program_id} } ||= {
                program_id   => $row->{program_id},
                program_name => $row->{program_name},
                projects     => [],
                collections  => [],
            });
            $program_order{ $row->{program_id} } ||= scalar(keys %program_order) + 1;
            push @{ $program->{collections} }, $base unless $pushed{"$cid:program"}++;
            next;
        }

        my $program_id = $row->{program_id};

        if (!defined $program_id) {
            unless ($project_in_no_program{$linked_project_id}++) {
                push @no_program, {
                    project_id   => $linked_project_id,
                    project_name => $row->{linked_project_name},
                    collections  => [],
                };
            }
            push @{ $no_program[-1]->{collections} }, $base
                unless $pushed{"$cid:noprogram"}++;
            next;
        }

        my $program = ($programs{$program_id} ||= {
            program_id   => $program_id,
            program_name => $row->{program_name},
            projects     => [],
            collections  => [],
        });
        $program_order{$program_id} ||= scalar(keys %program_order) + 1;

        my $project_key = $program_id . ':' . $linked_project_id;
        my $project_entry;
        if (exists $projects_in_program{$project_key}) {
            $project_entry = $projects_in_program{$project_key};
        }
        else {
            $project_entry = {
                project_id   => $linked_project_id,
                project_name => $row->{linked_project_name},
                collections  => [],
            };
            $projects_in_program{$project_key} = $project_entry;
            push @{ $program->{projects} }, $project_entry;
        }
        push @{ $project_entry->{collections} }, $base
            unless $pushed{"$cid:$project_key"}++;
    }

    my @programs_sorted = map { $programs{$_} }
        sort { $program_order{$a} <=> $program_order{$b} || $a <=> $b }
        keys %program_order;

    my $groups = {
        programs   => \@programs_sorted,
        no_program => \@no_program,
        standalone => \@standalone,
    };

    return (undef, $groups);
}

1;