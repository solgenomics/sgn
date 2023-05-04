#!/usr/bin/env perl


=head1 NAME

 SampleDbpatchMoose.pm

=head1 SYNOPSIS

mx-run ThisPackageName [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This is a test dummy patch.
This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 AUTHOR

 Naama Menda<nm249@cornell.edu>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddCascadeDeleteToStockAlleleTable;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
Adds cascade delete to stock_allele linking table

has '+prereq' => (
    default => sub {
        [],
    },
  );

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    $self->dbh->do(<<EOSQL);
--do your SQL here
--

BEGIN;
ALTER TABLE phenome.stock_allele DROP CONSTRAINT IF EXISTS stock_allele_stock_id_fkey;
ALTER TABLE phenome.stock_allele DROP CONSTRAINT IF EXISTS stock_allele_allele_id_fkey;
ALTER TABLE phenome.stock_allele DROP CONSTRAINT IF EXISTS stock_allele_metadata_id_fkey;
ALTER TABLE phenome.stock_allele ADD CONSTRAINT stock_allele_stock_id_fkey
    FOREIGN KEY (stock_id)
    REFERENCES stock(stock_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE phenome.stock_allele ADD CONSTRAINT stock_allele_allele_id_fkey
    FOREIGN KEY (allele_id)
    REFERENCES phenome.allele(allele_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE phenome.stock_allele ADD CONSTRAINT stock_image_metadata_id_fkey
    FOREIGN KEY (metadata_id)
    REFERENCES metadata.md_metadata(metadata_id)
    ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;

COMMIT;

EOSQL

print "You're done!\n";
}


####
1; #
####
