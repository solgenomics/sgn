package CXGN::Image::Search;

=head1 NAME

CXGN::Image::Search - an object to handle searching for images given criteria

=head1 USAGE

my $image_search = CXGN::Image::Search->new({
    bcs_schema=>$schema,
    image_id_list=>\@image_id_list,
    image_names_exact=>0,
    image_name_list=>\@image_name_list,
    include_obsolete_images=>0,
    original_filenames_exact=>0,
    original_filename_list=>\@original_filename_list,
    descriptions_exact=>0,
    description_list=>\@description_list,
    tag_list_exact=>0,
    tag_list=>\@tag_list,
    include_obsolete_tags=>0,
    include_obsolete_image_tags=>0,
    submitter_usernames_exact=>0,
    submitter_username_list=>\@submitter_username_list,
    submitter_first_names_exact=>0,
    submitter_first_name_list=>\@submitter_first_name_list,
    submitter_last_names_exact=>0,
    submitter_last_name_list=>\@submitter_last_name_list,
    submitter_id_list=>\@submitter_id_list,
    stock_type=>$stock_type,
    stock_id_list=>\@stock_id_list,
    stock_names_exact=>0,
    stock_name_list=>\@stock_name_list,
    project_id_list=>\@project_id_list,
    project_names_exact=>0,
    project_name_list=>\@project_name_list,
    project_md_image_type_name_list=>\@project_md_image_type_name_list,
    limit=>$limit,
    offset=>$offset
});
my ($result, $total_count) = $image_search->search();

=head1 DESCRIPTION


=head1 AUTHORS


=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;
use SGN::Model::Cvterm;
use JSON;

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'image_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'image_names_exact' => (
    isa => 'Bool|Undef',
    is => 'rw',
    default => 0
);

has 'image_name_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'include_obsolete_images' => (
    isa => 'Bool|Undef',
    is => 'rw',
    default => 0
);

has 'original_filenames_exact' => (
    isa => 'Bool|Undef',
    is => 'rw',
    default => 0
);

has 'original_filename_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'descriptions_exact' => (
    isa => 'Bool|Undef',
    is => 'rw',
    default => 0
);

has 'description_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'tag_list_exact' => (
    isa => 'Bool|Undef',
    is => 'rw',
    default => 0
);

has 'tag_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'include_obsolete_tags' => (
    isa => 'Bool|Undef',
    is => 'rw',
    default => 0
);

has 'include_obsolete_image_tags' => (
    isa => 'Bool|Undef',
    is => 'rw',
    default => 0
);

has 'submitter_usernames_exact' => (
    isa => 'Bool|Undef',
    is => 'rw',
    default => 0
);

has 'submitter_username_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'submitter_first_names_exact' => (
    isa => 'Bool|Undef',
    is => 'rw',
    default => 0
);

has 'submitter_first_name_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'submitter_last_names_exact' => (
    isa => 'Bool|Undef',
    is => 'rw',
    default => 0
);

has 'submitter_last_name_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'submitter_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'stock_type' => (
    isa => 'Str|Undef',
    is => 'rw',
);

has 'stock_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'stock_names_exact' => (
    isa => 'Bool|Undef',
    is => 'rw',
    default => 0
);

has 'stock_name_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'related_stock_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'project_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'project_names_exact' => (
    isa => 'Bool|Undef',
    is => 'rw',
    default => 0
);

has 'project_name_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'project_md_image_type_names_exact' => (
    isa => 'Bool|Undef',
    is => 'rw',
    default => 0
);

has 'project_md_image_type_name_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'collection_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is  => 'rw',
);

has 'limit' => (
    isa => 'Int|Undef',
    is => 'rw'
);

has 'offset' => (
    isa => 'Int|Undef',
    is => 'rw'
);

sub search {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my $image_id_list = $self->image_id_list;
    my $image_name_list = $self->image_name_list;
    my $image_names_exact = $self->image_names_exact;
    my $original_filename_list = $self->original_filename_list;
    my $original_filenames_exact = $self->original_filenames_exact;
    my $description_list = $self->description_list;
    my $descriptions_exact = $self->descriptions_exact;
    my $tag_list = $self->tag_list;
    my $tag_list_exact = $self->tag_list_exact;
    my $submitter_username_list = $self->submitter_username_list;
    my $submitter_usernames_exact = $self->submitter_usernames_exact;
    my $submitter_first_name_list = $self->submitter_first_name_list;
    my $submitter_first_names_exact = $self->submitter_first_names_exact;
    my $submitter_last_name_list = $self->submitter_last_name_list;
    my $submitter_last_names_exact = $self->submitter_last_names_exact;
    my $submitter_id_list = $self->submitter_id_list;
    my $stock_type = $self->stock_type;
    my $stock_id_list = $self->stock_id_list;
    my $stock_name_list = $self->stock_name_list;
    my $related_stock_list = $self->related_stock_list;
    my $stock_names_exact = $self->stock_names_exact;
    my $project_id_list = $self->project_id_list;
    my $project_name_list = $self->project_name_list;
    my $project_names_exact = $self->project_names_exact;
    my $project_md_image_type_name_list = $self->project_md_image_type_name_list;
    my $project_md_image_type_names_exact = $self->project_md_image_type_names_exact;
    my $collection_id_list = $self->collection_id_list;
    my $include_obsolete_images = $self->include_obsolete_images;
    my $include_obsolete_tags = $self->include_obsolete_tags;
    my $include_obsolete_image_tags = $self->include_obsolete_image_tags;

    my @where_clause;
    my @and_clause;
    my @image_descriptors_or_clause;

    # bind values are kept per clause group so they line up with the order the
    # groups are appended to the final WHERE: where, then or, then and
    my @where_values;
    my @or_values;
    my @and_values;

    my $in_clause = sub {
        my ($column, $list) = @_;
        push @where_clause, "$column IN (" . join(",", ("?") x scalar(@$list)) . ")";
        push @where_values, @$list;
    };

    # tags can be many per image, so filter with EXISTS rather than joining them
    my $tag_exists = sub {
        my ($condition) = @_;
        my $obsolete = '';
        $obsolete .= " AND image_tag.obsolete = 'f'" if !$include_obsolete_tags;
        $obsolete .= " AND tags.obsolete = 'f'" if !$include_obsolete_image_tags;
        return "EXISTS (SELECT 1 FROM metadata.md_tag_image AS image_tag JOIN metadata.md_tag AS tags ON (image_tag.tag_id=tags.tag_id) WHERE image_tag.image_id=image.image_id AND $condition$obsolete)";
    };

    if ($stock_type){
        my $stock_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, $stock_type, 'stock_type')->cvterm_id();
        push @where_clause, "stock.type_id = ?";
        push @where_values, $stock_type_cvterm_id;
    }

    if ($image_id_list && scalar(@$image_id_list)>0) {
        $in_clause->("image.image_id", $image_id_list);
    }
    if ($image_name_list && scalar(@$image_name_list)>0) {
        if ($image_names_exact) {
            $in_clause->("image.name", $image_name_list);
        } else {
            foreach (@$image_name_list) {
                push @image_descriptors_or_clause, "image.name ilike ?";
                push @or_values, '%' . $_ . '%';
            }
        }
    }
    if ($original_filename_list && scalar(@$original_filename_list)>0) {
        if ($original_filenames_exact) {
            $in_clause->("image.original_filename", $original_filename_list);
        } else {
            foreach (@$original_filename_list) {
                push @image_descriptors_or_clause, "image.original_filename ilike ?";
                push @or_values, '%' . $_ . '%';
            }
        }
    }
    if ($description_list && scalar(@$description_list)>0) {
        if ($descriptions_exact) {
            $in_clause->("image.description", $description_list);
        } else {
            foreach (@$description_list) {
                push @image_descriptors_or_clause, "image.description ilike ?";
                push @or_values, '%' . $_ . '%';
            }
        }
    }
    if ($tag_list && scalar(@$tag_list)>0) {
        if ($tag_list_exact) {
            push @where_clause, $tag_exists->("tags.name IN (" . join(",", ("?") x scalar(@$tag_list)) . ")");
            push @where_values, @$tag_list;
        } else {
            foreach (@$tag_list) {
                push @where_clause, $tag_exists->("tags.name ilike ?");
                push @where_values, '%' . $_ . '%';
            }
        }
    }
    if ($submitter_username_list && scalar(@$submitter_username_list)>0) {
        if ($submitter_usernames_exact) {
            $in_clause->("submitter.username", $submitter_username_list);
        } else {
            foreach (@$submitter_username_list) {
                push @and_clause, "submitter.username ilike ?";
                push @and_values, '%' . $_ . '%';
            }
        }
    }
    if ($submitter_first_name_list && scalar(@$submitter_first_name_list)>0) {
        if ($submitter_first_names_exact) {
            $in_clause->("submitter.first_name", $submitter_first_name_list);
        } else {
            foreach (@$submitter_first_name_list) {
                push @and_clause, "submitter.first_name ilike ?";
                push @and_values, '%' . $_ . '%';
            }
        }
    }
    if ($submitter_last_name_list && scalar(@$submitter_last_name_list)>0) {
        if ($submitter_last_names_exact) {
            $in_clause->("submitter.last_name", $submitter_last_name_list);
        } else {
            foreach (@$submitter_last_name_list) {
                push @and_clause, "submitter.last_name ilike ?";
                push @and_values, '%' . $_ . '%';
            }
        }
    }
    if ($submitter_id_list && scalar(@$submitter_id_list)>0) {
        $in_clause->("submitter.sp_person_id", $submitter_id_list);
    }
    if ($stock_id_list && scalar(@$stock_id_list) > 0) {
        $in_clause->("stock.stock_id", $stock_id_list);
    }
    if ($stock_name_list && scalar(@$stock_name_list) > 0) {
        if ($stock_names_exact) {
            $in_clause->("stock.uniquename", $stock_name_list);
        } else {
            foreach (@$stock_name_list) {
                push @and_clause, "stock.uniquename ilike ?";
                push @and_values, '%' . $_ . '%';
            }
        }
    }
    if ($related_stock_list && scalar(@$related_stock_list)>0) {
        my $placeholders = join(",", ("?") x scalar(@$related_stock_list));
        push @where_clause, "EXISTS (
            SELECT 1 FROM stock AS related_stock
            WHERE related_stock.uniquename IN ($placeholders)
            AND related_stock.stock_id IN (
                SELECT sr.subject_id FROM stock_relationship AS sr WHERE sr.object_id = stock.stock_id
                UNION ALL
                SELECT sr.object_id FROM stock_relationship AS sr WHERE sr.subject_id = stock.stock_id
            )
        )";
        push @where_values, @$related_stock_list;
    }
    if ($project_id_list && scalar(@$project_id_list)>0) {
        $in_clause->("project.project_id", $project_id_list);
    }
    if ($project_name_list && scalar(@$project_name_list) > 0) {
        if ($project_names_exact) {
            my $placeholders = join(",", ("?") x scalar(@$project_name_list));

            push @where_clause, "(
                project.name IN ($placeholders)
                OR EXISTS (
                    SELECT 1
                    FROM nd_experiment_stock nes_f
                    JOIN nd_experiment ne_f ON ne_f.nd_experiment_id = nes_f.nd_experiment_id
                        AND ne_f.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'field_layout' LIMIT 1)
                    JOIN nd_experiment_project nep_f ON nep_f.nd_experiment_id = ne_f.nd_experiment_id
                    JOIN project p_f ON p_f.project_id = nep_f.project_id
                    WHERE nes_f.stock_id = stock.stock_id
                    AND p_f.name IN ($placeholders)
                )
            )";
            push @where_values, @$project_name_list;
            push @where_values, @$project_name_list;
        } else {
            my @project_name_or;
            foreach my $name (@$project_name_list) {
                push @project_name_or, "(
                    project.name ILIKE ?
                    OR EXISTS (
                        SELECT 1
                        FROM nd_experiment_stock nes_f
                        JOIN nd_experiment ne_f ON ne_f.nd_experiment_id = nes_f.nd_experiment_id
                            AND ne_f.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'field_layout' LIMIT 1)
                        JOIN nd_experiment_project nep_f ON nep_f.nd_experiment_id = ne_f.nd_experiment_id
                        JOIN project p_f ON p_f.project_id = nep_f.project_id
                        WHERE nes_f.stock_id = stock.stock_id
                        AND p_f.name ILIKE ?
                    )
                )";
                push @where_values, '%' . $name . '%';
                push @where_values, '%' . $name . '%';
            }
            if (scalar(@project_name_or) > 0) {
                push @where_clause, " ( " . join(" OR ", @project_name_or) . " ) ";
            }
        }
    }
    if ($project_md_image_type_name_list && scalar(@$project_md_image_type_name_list)>0) {
        if ($project_md_image_type_names_exact) {
            $in_clause->("project_image_type.name", $project_md_image_type_name_list);
        } else {
            foreach (@$project_md_image_type_name_list) {
                push @and_clause, "project_image_type.name ilike ?";
                push @and_values, '%' . $_ . '%';
            }
        }
    }
    if ($collection_id_list && scalar(@$collection_id_list) > 0) {
        my $placeholders = join(",", ("?") x scalar(@$collection_id_list));
        push @where_clause,
            "EXISTS (SELECT 1 FROM metadata.md_collection_image AS collection_membership
                    WHERE collection_membership.image_id = image.image_id
                        AND collection_membership.collection_id IN ($placeholders))";
        push @question_mark_values, @$collection_id_list;
    }
    if (!$include_obsolete_images) {
        push @where_clause, "image.obsolete = 'f'";
    }

    if (scalar(@image_descriptors_or_clause)>0) {
        my $w = " ( ".(join (" OR ", @image_descriptors_or_clause) )." ) ";
        push @where_clause, $w;
    }

    if (scalar(@and_clause)>0) {
        my $w = " ( ".(join (" AND ", @and_clause) )." ) ";
        push @where_clause, $w;
    }

    my @question_mark_values = (@where_values, @or_values, @and_values);

    my $where_clause = scalar(@where_clause)>0 ? " WHERE " . (join (" AND " , @where_clause)) : '';

    my $offset_clause = '';
    my $limit_clause = '';
    if ($self->limit){
        $limit_clause = " LIMIT ".int($self->limit);
    }
    if ($self->offset){
        $offset_clause = " OFFSET ".int($self->offset);
    }

    # The inner query filters, counts and paginates the image/stock/project rows
    # without any aggregation. Tags, related stocks, observations, accession and
    # field trial are then looked up per row of the page only.
    my $q = "SELECT b.image_id, b.image_name, b.description, b.original_filename, b.file_ext, b.sp_person_id, b.username,
        b.create_date, b.modified_date, b.obsolete, b.md5sum, b.stock_id, b.stock_uniquename, b.stock_type_name,
        b.project_id, b.project_name, b.project_md_image_id, b.project_image_type_name,
        field_trial.project_id AS field_trial_id,
        field_trial.name AS field_trial_name,
        (SELECT COALESCE(json_agg(jsonb_build_object('stock_id', related_stock.stock_id, 'uniquename', related_stock.uniquename)), '[]')
            FROM (
                SELECT sr.subject_id AS related_id FROM stock_relationship AS sr WHERE sr.object_id = b.stock_id
                UNION ALL
                SELECT sr.object_id AS related_id FROM stock_relationship AS sr WHERE sr.subject_id = b.stock_id
            ) AS related
            JOIN stock AS related_stock ON (related_stock.stock_id = related.related_id)
        ) AS related_stocks,
        (SELECT COALESCE(json_agg(json_build_object('tag_id', tags.tag_id, 'name', tags.name, 'description', tags.description, 'sp_person_id', tags.sp_person_id, 'modified_date', tags.modified_date, 'create_date', tags.create_date, 'obsolete', tags.obsolete)), '[]')
            FROM metadata.md_tag_image AS image_tag
            JOIN metadata.md_tag AS tags ON (image_tag.tag_id=tags.tag_id)
            WHERE image_tag.image_id = b.image_id
        ) AS tags,
        (SELECT COALESCE(json_agg(json_build_object('phenotype_id', phenotype.phenotype_id, 'value', phenotype.value, 'observationvariable_name', phenotype_variable.name)), '[]')
            FROM phenome.nd_experiment_md_images AS nd_experiment_md_images
            JOIN nd_experiment_phenotype ON (nd_experiment_phenotype.nd_experiment_id = nd_experiment_md_images.nd_experiment_id)
            JOIN phenotype ON (nd_experiment_phenotype.phenotype_id = phenotype.phenotype_id)
            LEFT JOIN cvterm AS phenotype_variable ON (phenotype.cvalue_id=phenotype_variable.cvterm_id)
            WHERE nd_experiment_md_images.image_id = b.image_id
        ) AS observations,
        accession.stock_id AS accession_id,
        accession.uniquename AS accession_uniquename,
        b.full_count
        FROM (
            SELECT image.image_id, image.name AS image_name, image.description, image.original_filename, image.file_ext, image.sp_person_id, submitter.username,
                to_char (image.create_date::timestamp at time zone current_setting('TIMEZONE'), 'YYYY-MM-DD\"T\"HH24:MI:SSOF:00') AS create_date,
                to_char (image.modified_date::timestamp at time zone current_setting('TIMEZONE'), 'YYYY-MM-DD\"T\"HH24:MI:SSOF:00') AS modified_date,
                image.obsolete, image.md5sum, stock.stock_id, stock.uniquename AS stock_uniquename, stock_type.name AS stock_type_name,
                project.project_id, project.name AS project_name, project_image.project_md_image_id, project_image_type.name AS project_image_type_name,
                count(*) OVER() AS full_count
            FROM metadata.md_image AS image
            JOIN sgn_people.sp_person AS submitter ON (submitter.sp_person_id=image.sp_person_id)
            LEFT JOIN phenome.stock_image AS stock_image ON (image.image_id=stock_image.image_id)
            LEFT JOIN stock ON (stock_image.stock_id = stock.stock_id)
            LEFT JOIN cvterm AS stock_type ON (stock.type_id=stock_type.cvterm_id)
            LEFT JOIN phenome.project_md_image AS project_image ON(project_image.image_id=image.image_id)
            LEFT JOIN cvterm AS project_image_type ON(project_image.type_id=project_image_type.cvterm_id)
            LEFT JOIN project ON(project_image.project_id=project.project_id)
            $where_clause
            ORDER BY image.image_id, stock.stock_id, project.project_id
            $limit_clause
            $offset_clause
        ) AS b
        LEFT JOIN LATERAL (
            SELECT p.project_id, p.name
            FROM nd_experiment_stock nes
            JOIN nd_experiment ne ON ne.nd_experiment_id = nes.nd_experiment_id
                AND ne.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'field_layout' LIMIT 1)
            JOIN nd_experiment_project ftp ON ftp.nd_experiment_id = ne.nd_experiment_id
            JOIN project p ON p.project_id = ftp.project_id
            WHERE nes.stock_id = b.stock_id
            LIMIT 1
        ) AS field_trial ON true
        LEFT JOIN LATERAL (
            SELECT acc.stock_id, acc.uniquename
            FROM stock_relationship AS plot_rel
            JOIN cvterm AS plot_rel_type ON (plot_rel_type.cvterm_id = plot_rel.type_id AND plot_rel_type.name = 'plot_of')
            JOIN stock AS acc ON (acc.stock_id = plot_rel.object_id)
            WHERE plot_rel.subject_id = b.stock_id
            LIMIT 1
        ) AS accession ON true
        ORDER BY b.image_id, b.stock_id, b.project_id;";

    # print STDERR Dumper $q;
    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute(@question_mark_values);

    my @result;
    my $total_count = 0;
    while (my ($image_id, $image_name, $image_description, $image_original_filename, $image_file_ext, $image_sp_person_id, $image_username, $image_create_date, $image_modified_date, $image_obsolete, $image_md5sum, $stock_id, $stock_uniquename, $stock_type_name, $project_id, $project_name, $project_md_image_id, $project_image_type_name, $field_trial_id, $field_trial_name, $related_stocks, $tags, $observations, $accession_id, $accession_uniquename, $full_count) = $h->fetchrow_array()) {
        push @result, {
            image_id => $image_id,
            image_name => $image_name,
            image_description => $image_description,
            image_original_filename => $image_original_filename,
            image_file_ext => $image_file_ext,
            image_sp_person_id => $image_sp_person_id,
            image_username => $image_username,
            image_create_date => $image_create_date,
            image_modified_date => $image_modified_date,
            image_obsolete => $image_obsolete,
            image_md5sum => $image_md5sum,
            stock_id => $stock_id,
            stock_uniquename => $stock_uniquename,
            stock_type_name => $stock_type_name,
            project_id => $project_id,
            project_name => $project_name,
            project_md_image_id => $project_md_image_id,
            project_image_type_name => $project_image_type_name,
            field_trial_id => $field_trial_id,
            field_trial_name => $field_trial_name,
            accession_id => $accession_id,
            accession_uniquename => $accession_uniquename,
            tags_array => decode_json $tags,
            observations_array => decode_json $observations,
            related_stocks_array =>decode_json $related_stocks,
        };
        $total_count = $full_count;
    }
    #print STDERR Dumper \@result;
    return (\@result, $total_count);
}

1;
