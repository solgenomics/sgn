#!/usr/bin/env perl


=head1 NAME

AddCascadeDeletes.pm

=head1 SYNOPSIS

mx-run AddCascadeDeletes [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

Adds missing cascade deletes to linking tables

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

Bryan Ellerbrock<bje24@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddCascadeDeletes;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Adds missing cascade deletes to the following linking tables: phenome.stock_image, phenome.locus_owner, phenome.nd_experiment_md_files, phenome.nd_experiment_md_json, phenome.nd_experiment_md_images, phenome.project_md_image, phenome.project_owner, phenome.stock_owner, metadata.md_image_cvterm
has '+prereq' => (
    default => sub {
        [''],
    },
  );

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
--do your SQL here

BEGIN;

ALTER TABLE phenome.stock_image DROP CONSTRAINT IF EXISTS stock_image_image_id_fkey;
ALTER TABLE phenome.stock_image DROP CONSTRAINT IF EXISTS stock_image_metadata_id_fkey;
ALTER TABLE phenome.stock_image DROP CONSTRAINT IF EXISTS stock_image_stock_id_fkey;
ALTER TABLE phenome.stock_image ADD CONSTRAINT stock_image_image_id_fkey
    FOREIGN KEY (image_id)
    REFERENCES metadata.md_image(image_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE phenome.stock_image ADD CONSTRAINT stock_image_metadata_id_fkey
    FOREIGN KEY (metadata_id)
    REFERENCES metadata.md_metadata(metadata_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE phenome.stock_image ADD CONSTRAINT stock_image_stock_id_fkey
    FOREIGN KEY (stock_id)
    REFERENCES stock(stock_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE phenome.locus_owner DROP CONSTRAINT IF EXISTS locus_owner_granted_by_fkey;
ALTER TABLE phenome.locus_owner DROP CONSTRAINT IF EXISTS locus_owner_locus_id_fkey;
ALTER TABLE phenome.locus_owner DROP CONSTRAINT IF EXISTS locus_owner_sp_person_id_fkey;
ALTER TABLE phenome.locus_owner ADD CONSTRAINT locus_owner_granted_by_fkey
    FOREIGN KEY (granted_by)
    REFERENCES sgn_people.sp_person(sp_person_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE phenome.locus_owner ADD CONSTRAINT locus_owner_locus_id_fkey
    FOREIGN KEY (locus_id)
    REFERENCES phenome.locus(locus_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE phenome.locus_owner ADD CONSTRAINT locus_owner_sp_person_id_fkey
    FOREIGN KEY (sp_person_id)
    REFERENCES sgn_people.sp_person(sp_person_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE phenome.nd_experiment_md_files DROP CONSTRAINT IF EXISTS nd_experiment_md_files_file_id_fkey;
ALTER TABLE phenome.nd_experiment_md_files DROP CONSTRAINT IF EXISTS nd_experiment_md_files_nd_experiment_id_fkey;
ALTER TABLE phenome.nd_experiment_md_files ADD CONSTRAINT nd_experiment_md_files_file_id_fkey
    FOREIGN KEY (file_id)
    REFERENCES metadata.md_files(file_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE phenome.nd_experiment_md_files ADD CONSTRAINT nd_experiment_md_files_nd_experiment_id_fkey
    FOREIGN KEY (nd_experiment_id)
    REFERENCES nd_experiment(nd_experiment_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE phenome.nd_experiment_md_json DROP CONSTRAINT IF EXISTS nd_experiment_md_json_json_id_fkey;
ALTER TABLE phenome.nd_experiment_md_json DROP CONSTRAINT IF EXISTS nd_experiment_md_json_nd_experiment_id_fkey;
ALTER TABLE phenome.nd_experiment_md_json ADD CONSTRAINT nd_experiment_md_json_json_id_fkey
    FOREIGN KEY (json_id)
    REFERENCES metadata.md_json(json_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE phenome.nd_experiment_md_json ADD CONSTRAINT nd_experiment_md_json_nd_experiment_id_fkey
    FOREIGN KEY (nd_experiment_id)
    REFERENCES nd_experiment(nd_experiment_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE phenome.nd_experiment_md_images DROP CONSTRAINT IF EXISTS nd_experiment_md_images_image_id_fkey;
ALTER TABLE phenome.nd_experiment_md_images DROP CONSTRAINT IF EXISTS nd_experiment_md_images_nd_experiment_id_fkey;
ALTER TABLE phenome.nd_experiment_md_images ADD CONSTRAINT nd_experiment_md_images_image_id_fkey
    FOREIGN KEY (image_id)
    REFERENCES metadata.md_image(image_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE phenome.nd_experiment_md_images ADD CONSTRAINT nd_experiment_md_images_nd_experiment_id_fkey
    FOREIGN KEY (nd_experiment_id)
    REFERENCES nd_experiment(nd_experiment_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE phenome.project_md_image DROP CONSTRAINT IF EXISTS project_md_image_image_id_fkey;
ALTER TABLE phenome.project_md_image DROP CONSTRAINT IF EXISTS project_md_image_project_id_fkey;
ALTER TABLE phenome.project_md_image DROP CONSTRAINT IF EXISTS project_md_image_type_id_fkey;
ALTER TABLE phenome.project_md_image ADD CONSTRAINT project_md_image_image_id_fkey
    FOREIGN KEY (image_id)
    REFERENCES metadata.md_image(image_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE phenome.project_md_image ADD CONSTRAINT project_md_image_project_id_fkey
    FOREIGN KEY (project_id)
    REFERENCES project(project_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE phenome.project_md_image ADD CONSTRAINT project_md_image_type_id_fkey
    FOREIGN KEY (type_id)
    REFERENCES cvterm(cvterm_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE phenome.project_owner DROP CONSTRAINT IF EXISTS project_owner_project_id_fkey;
ALTER TABLE phenome.project_owner DROP CONSTRAINT IF EXISTS project_owner_sp_person_id_fkey;
ALTER TABLE phenome.project_owner ADD CONSTRAINT project_owner_project_id_fkey
    FOREIGN KEY (project_id)
    REFERENCES project(project_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE phenome.project_owner ADD CONSTRAINT project_owner_sp_person_id_fkey
    FOREIGN KEY (sp_person_id)
    REFERENCES sgn_people.sp_person(sp_person_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE phenome.stock_owner DROP CONSTRAINT IF EXISTS stock_owner_metadata_id_fkey;
ALTER TABLE phenome.stock_owner DROP CONSTRAINT IF EXISTS stock_owner_sp_person_id_fkey;
ALTER TABLE phenome.stock_owner DROP CONSTRAINT IF EXISTS stock_owner_stock_id_fkey;
ALTER TABLE phenome.stock_owner ADD CONSTRAINT stock_owner_metadata_id_fkey
    FOREIGN KEY (metadata_id)
    REFERENCES metadata.md_metadata(metadata_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE phenome.stock_owner ADD CONSTRAINT stock_owner_sp_person_id_fkey
    FOREIGN KEY (sp_person_id)
    REFERENCES sgn_people.sp_person(sp_person_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE phenome.stock_owner ADD CONSTRAINT stock_owner_stock_id_fkey
    FOREIGN KEY (stock_id)
    REFERENCES stock(stock_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE metadata.md_image_cvterm DROP CONSTRAINT IF EXISTS md_image_cvterm_cvterm_id_fkey;
ALTER TABLE metadata.md_image_cvterm DROP CONSTRAINT IF EXISTS md_image_cvterm_image_id_fkey;
ALTER TABLE metadata.md_image_cvterm DROP CONSTRAINT IF EXISTS md_image_cvterm_sp_person_id_fkey;
ALTER TABLE metadata.md_image_cvterm ADD CONSTRAINT md_image_cvterm_cvterm_id_fkey
    FOREIGN KEY (cvterm_id)
    REFERENCES cvterm(cvterm_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE metadata.md_image_cvterm ADD CONSTRAINT md_image_cvterm_image_id_fkey
    FOREIGN KEY (image_id)
    REFERENCES metadata.md_image(image_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE metadata.md_image_cvterm ADD CONSTRAINT md_image_cvterm_sp_person_id_fkey
    FOREIGN KEY (sp_person_id)
    REFERENCES sgn_people.sp_person(sp_person_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

COMMIT;


EOSQL

print "You're done!\n";
}


####
1; #
####
