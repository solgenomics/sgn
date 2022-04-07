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
Adds missing cascade deletes to linking tables
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

ALTER TABLE phenome.stock_image
DROP CONSTRAINT stock_image_image_id_fkey
DROP CONSTRAINT stock_image_metadata_id_fkey
DROP CONSTRAINT stock_image_stock_id_fkey
ADD CONSTRAINT stock_image_image_id_fkey
    FOREIGN KEY (image_id)
    REFERENCES metadata.md_image(image_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED
ADD CONSTRAINT stock_image_metadata_id_fkey
    FOREIGN KEY (metadata_id)
    REFERENCES metadata.md_metadata(metadata_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED
ADD CONSTRAINT stock_image_stock_id_fkey
    FOREIGN KEY (stock_id)
    REFERENCES stock(stock_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED

ALTER TABLE phenome.locus_owner
DROP CONSTRAINT locus_owner_granted_by_fkey
DROP CONSTRAINT locus_owner_locus_id_fkey
DROP CONSTRAINT locus_owner_sp_person_id_fkey
ADD CONSTRAINT locus_owner_granted_by_fkey
    FOREIGN KEY (granted_by)
    REFERENCES sgn_people.sp_person(sp_person_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED
ADD CONSTRAINT locus_owner_locus_id_fkey
    FOREIGN KEY (locus_id)
    REFERENCES phenome.locus(locus_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED
ADD CONSTRAINT locus_owner_sp_person_id_fkey
    FOREIGN KEY (sp_person_id)
    REFERENCES sgn_people.sp_person(sp_person_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED

COMMIT;


EOSQL

print "You're done!\n";
}


####
1; #
####
