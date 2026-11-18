#!/usr/bin/env perl


=head1 NAME

 AddStockRelationshipObjectTypeIndex

=head1 SYNOPSIS

mx-run AddStockRelationshipObjectTypeIndex [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch adds an index on stock_relationship (object_id, type_id).
Lookups of the parents of an accession join stock_relationship by object_id
and type_id. With only the single-column object_id index, each lookup reads
every link that points to the accession (all its plots, plants and tissue
samples) and discards them.

On a large database the index can be built beforehand without blocking writes:
CREATE INDEX CONCURRENTLY stock_relationship_object_id_type_id_idx
ON public.stock_relationship (object_id, type_id);
This patch then finds the index and does nothing. Check first that the prebuilt
index is valid (pg_index.indisvalid): an interrupted concurrent build leaves an
invalid index with the same name, and IF NOT EXISTS skips that one too.

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 COPYRIGHT & LICENSE

Copyright 2026 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddStockRelationshipObjectTypeIndex;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch adds an index on stock_relationship (object_id, type_id) for parent lookups.

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

    # The patch framework runs with AutoCommit on, so without this transaction a trial run would keep the index.
    # Stop at a failed statement, so a failure is never recorded as applied.
    local $self->dbh->{RaiseError} = 1;
    $self->dbh->begin_work();
    $self->dbh->do(<<EOSQL);
CREATE INDEX IF NOT EXISTS stock_relationship_object_id_type_id_idx ON public.stock_relationship (object_id, type_id);
EOSQL
    # IF NOT EXISTS also skips an invalid or differently defined namesake.
    my ($matches) = $self->dbh->selectrow_array(<<'SQL');
SELECT 1
FROM pg_index idx
JOIN pg_class ix ON ix.oid = idx.indexrelid
JOIN pg_am am ON am.oid = ix.relam
WHERE idx.indexrelid = to_regclass('public.stock_relationship_object_id_type_id_idx')
  AND idx.indrelid = 'public.stock_relationship'::regclass
  AND am.amname = 'btree'
  AND idx.indisvalid AND idx.indisready AND NOT idx.indisunique
  AND idx.indnatts = 2 AND idx.indpred IS NULL
  AND pg_get_indexdef(idx.indexrelid, 1, true) = 'object_id'
  AND pg_get_indexdef(idx.indexrelid, 2, true) = 'type_id'
SQL
    if (!$matches) {
        $self->dbh->rollback();
        die "Index stock_relationship_object_id_type_id_idx must be a valid btree on stock_relationship (object_id, type_id). Drop the incompatible index and run this patch again.\n";
    }
    if ($self->trial) {
        $self->dbh->rollback();
        print "Trial mode: the index was built and rolled back.\n";
    }
    else {
        $self->dbh->commit();
    }

    print "You're done!\n";
}

####
1; #
####
