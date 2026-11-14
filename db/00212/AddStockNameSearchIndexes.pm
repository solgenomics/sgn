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
        'SELECT cvterm_id FROM public.cvterm JOIN public.cv USING (cv_id) WHERE cvterm.name = ? AND cv.name = ?',
        undef, 'stock_synonym', 'stock_property',
    );
    die "Expected exactly one stock_synonym cvterm in stock_property\n" if @$ids != 1;
    my $synonym_id = $ids->[0];
    die "Invalid stock_synonym cvterm ID\n" if $synonym_id !~ /\A[0-9]+\z/;

    $dbh->do(<<EOSQL);
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX IF NOT EXISTS stock_name_trgm_idx ON public.stock USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS stock_uniquename_trgm_idx ON public.stock USING gin (uniquename gin_trgm_ops);
CREATE INDEX IF NOT EXISTS stock_description_trgm_idx ON public.stock USING gin (description gin_trgm_ops);
CREATE INDEX IF NOT EXISTS stockprop_synonym_value_trgm_idx ON public.stockprop USING gin (value gin_trgm_ops) WHERE type_id = $synonym_id;
EOSQL

    print "You're done!\n";
}

####
1; #
####
