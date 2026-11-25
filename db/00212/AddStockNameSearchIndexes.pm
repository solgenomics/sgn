#!/usr/bin/env perl


=head1 NAME

 AddStockNameSearchIndexes

=head1 SYNOPSIS

mx-run AddStockNameSearchIndexes [options] -H hostname -D dbname -u username [-F]

this is a subclass of L<CXGN::Metadata::Dbpatch>
see the perldoc of parent class for more details.

=head1 DESCRIPTION

This patch adds trigram indexes for stock names, descriptions and synonyms.
The indexes alone do not help the current OR predicate in accession name search.

On a large database, build the same indexes beforehand with CREATE INDEX
CONCURRENTLY; IF NOT EXISTS then skips them. The stockprop index must use
the stock_synonym cvterm ID from the stock_property vocabulary.
Check first that the prebuilt indexes are valid (pg_index.indisvalid): an
interrupted concurrent build leaves an invalid index with the same name, and
IF NOT EXISTS skips that one too.

This subclass uses L<Moose>. The parent class uses L<MooseX::Runnable>

=head1 COPYRIGHT & LICENSE

Copyright 2026 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut


package AddStockNameSearchIndexes;

use Moose;
extends 'CXGN::Metadata::Dbpatch';


has '+description' => ( default => <<'' );
This patch adds trigram indexes for stock names, descriptions and synonyms.

has '+prereq' => (
    default => sub {
        ['CreateFuzzyExtensionAndIndexes'],
    },
  );

sub patch {
    my $self=shift;

    print STDOUT "Executing the patch:\n " .   $self->name . ".\n\nDescription:\n  ".  $self->description . ".\n\nExecuted by:\n " .  $self->username . " .";

    print STDOUT "\nChecking if this db_patch was executed before or if previous db_patches have been executed.\n";

    print STDOUT "\nExecuting the SQL commands.\n";

    my $dbh = $self->dbh;
    my $ids = $dbh->selectcol_arrayref(
        'SELECT cvterm_id FROM public.cvterm JOIN public.cv USING (cv_id) WHERE cvterm.name = ? AND cv.name = ? AND cvterm.is_obsolete = 0',
        undef, 'stock_synonym', 'stock_property',
    );
    die "Expected exactly one non-obsolete stock_synonym cvterm in stock_property\n" if @$ids != 1;
    my $synonym_id = $ids->[0];
    die "Invalid stock_synonym cvterm ID\n" if $synonym_id !~ /\A[0-9]+\z/;

    # The patch framework runs with AutoCommit on, so without this transaction a trial run would keep the indexes.
    # Stop at a failed statement, so a failure is never recorded as applied.
    local $dbh->{RaiseError} = 1;
    $dbh->begin_work();
    $dbh->do(<<EOSQL);
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX IF NOT EXISTS stock_name_trgm_idx ON public.stock USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS stock_uniquename_trgm_idx ON public.stock USING gin (uniquename gin_trgm_ops);
CREATE INDEX IF NOT EXISTS stock_description_trgm_idx ON public.stock USING gin (description gin_trgm_ops);
CREATE INDEX IF NOT EXISTS stockprop_synonym_value_trgm_idx ON public.stockprop USING gin (value gin_trgm_ops) WHERE type_id = $synonym_id;
EOSQL
    # IF NOT EXISTS skips any object of the same name, even if it cannot serve these queries.
    my $index_definition = <<'SQL';
SELECT 1
FROM pg_index idx
JOIN pg_class ix ON ix.oid = idx.indexrelid
JOIN pg_am am ON am.oid = ix.relam
JOIN pg_opclass opc ON opc.oid = idx.indclass[0]
WHERE idx.indexrelid = to_regclass(?)
  AND idx.indrelid = to_regclass(?)
  AND am.amname = 'gin' AND opc.opcname = 'gin_trgm_ops'
  AND idx.indisvalid AND idx.indisready AND idx.indnatts = 1
  AND pg_get_indexdef(idx.indexrelid, 1, true) = ?
  AND pg_get_expr(idx.indpred, idx.indrelid) IS NOT DISTINCT FROM ?
SQL
    my @expected = (
        ['stock_name_trgm_idx', 'stock', 'name', undef],
        ['stock_uniquename_trgm_idx', 'stock', 'uniquename', undef],
        ['stock_description_trgm_idx', 'stock', 'description', undef],
        ['stockprop_synonym_value_trgm_idx', 'stockprop', 'value', "(type_id = $synonym_id)"],
    );
    my @invalid;
    for my $index (@expected) {
        my ($name, $table, $column, $predicate) = @$index;
        my ($matches) = $dbh->selectrow_array($index_definition, undef, "public.$name", "public.$table", $column, $predicate);
        push @invalid, $name if !$matches;
    }
    if (@invalid) {
        $dbh->rollback();
        die "Invalid or incompatible trigram indexes: @invalid. Drop them and run this patch again.\n";
    }
    if ($self->trial) {
        $dbh->rollback();
        print "Trial mode: the indexes were built and rolled back.\n";
    }
    else {
        $dbh->commit();
    }

    print "You're done!\n";
}

####
1; #
####
