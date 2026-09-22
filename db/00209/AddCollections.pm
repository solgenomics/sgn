package AddCollections;

=head1 NAME

AddCollections.pm

=head1 SYNOPSIS

mx-run AddCollections [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Adds tables supporting named collections ("folders") of images and files.

A collection is a container in metadata.md_collection. Membership is held in
two typed join tables rather than one polymorphic table, so that both sides
keep real foreign keys and can diverge later.

Collections are standalone by default. A row in phenome.project_md_collection
scopes a collection to a project (trial), mirroring phenome.project_md_image.

No cvterms are added by this patch, so no cvterm_id sequence values shift and
no existing test fixtures are invalidated.

=head1 AUTHOR

=cut

use strict;
use warnings;

use Moose;
extends 'CXGN::Metadata::Dbpatch';

has '+description' => (
    default => 'Add tables for named collections (folders) of images and files'
);

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<'EOSQL');

--- do your sql here
CREATE TABLE metadata.md_collection (
    collection_id  serial PRIMARY KEY,
    name           varchar(255) NOT NULL,
    description    text,
    sp_person_id   bigint REFERENCES sgn_people.sp_person (sp_person_id),
    create_date    timestamp without time zone DEFAULT now(),
    modified_date  timestamp without time zone,
    obsolete       boolean NOT NULL DEFAULT false
);

COMMENT ON TABLE metadata.md_collection IS
  'A named collection (folder) of images and/or files.';

-- Name uniqueness is enforced in CXGN::Collection, not here: names must be
-- unique per context (per project, or among standalone collections), which a
-- single partial index cannot express across the project_md_collection join.
CREATE INDEX md_collection_name_idx        ON metadata.md_collection (lower(name));
CREATE INDEX md_collection_sp_person_idx   ON metadata.md_collection (sp_person_id);

CREATE TABLE metadata.md_collection_image (
    collection_image_id serial PRIMARY KEY,
    collection_id integer NOT NULL
        REFERENCES metadata.md_collection (collection_id) ON DELETE CASCADE,
    image_id      bigint NOT NULL
        REFERENCES metadata.md_image (image_id) ON DELETE CASCADE,
    rank          integer NOT NULL DEFAULT 0,
    create_date   timestamp without time zone DEFAULT now(),
    UNIQUE (collection_id, image_id)
);

CREATE INDEX md_collection_image_image_idx
    ON metadata.md_collection_image (image_id);

CREATE TABLE metadata.md_collection_file (
    collection_file_id serial PRIMARY KEY,
    collection_id integer NOT NULL
        REFERENCES metadata.md_collection (collection_id) ON DELETE CASCADE,
    file_id       bigint NOT NULL
        REFERENCES metadata.md_files (file_id) ON DELETE CASCADE,
    rank          integer NOT NULL DEFAULT 0,
    create_date   timestamp without time zone DEFAULT now(),
    UNIQUE (collection_id, file_id)
);

CREATE INDEX md_collection_file_file_idx
    ON metadata.md_collection_file (file_id);

-- Optional project (trial) scoping. Most collections have no row here.
CREATE TABLE phenome.project_md_collection (
    project_md_collection_id serial PRIMARY KEY,
    project_id    integer NOT NULL
        REFERENCES project (project_id) ON DELETE CASCADE,
    collection_id integer NOT NULL
        REFERENCES metadata.md_collection (collection_id) ON DELETE CASCADE,
    create_date   timestamp without time zone DEFAULT now(),
    UNIQUE (project_id, collection_id)
);

CREATE INDEX project_md_collection_collection_idx
    ON phenome.project_md_collection (collection_id);

EOSQL

    print "You're done!\n";
}

1;