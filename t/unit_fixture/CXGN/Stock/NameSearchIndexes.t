use strict;
use warnings;

use lib 't/lib';

use JSON qw(decode_json);
use Test::More;
use SGN::Test::Fixture;

my $fixture = SGN::Test::Fixture->new();
my $dbh = $fixture->dbh();
my $ids = $dbh->selectcol_arrayref(
    'SELECT cvterm_id FROM public.cvterm JOIN public.cv USING (cv_id) WHERE cvterm.name = ? AND cv.name = ?',
    undef, 'stock_synonym', 'stock_property',
);
is(scalar @$ids, 1, 'fixture has exactly one stock synonym cvterm');

my $index_sql = <<'SQL';
SELECT tbl.relname AS table_name, am.amname AS method,
       pg_get_indexdef(idx.indexrelid, 1, true) AS column_name,
       opc.opcname AS opclass, idx.indnatts AS column_count,
       idx.indisvalid AS valid, idx.indisready AS ready,
       pg_get_expr(idx.indpred, idx.indrelid) AS predicate
FROM pg_index idx
JOIN pg_class ix ON ix.oid = idx.indexrelid
JOIN pg_namespace ns ON ns.oid = ix.relnamespace
JOIN pg_class tbl ON tbl.oid = idx.indrelid
JOIN pg_namespace tbl_ns ON tbl_ns.oid = tbl.relnamespace
JOIN pg_am am ON am.oid = ix.relam
JOIN pg_opclass opc ON opc.oid = idx.indclass[0]
WHERE ns.nspname = 'public' AND tbl_ns.nspname = 'public' AND ix.relname = ?
SQL

my @indexes = (
    ['stock_name_trgm_idx', 'stock', 'name'],
    ['stock_uniquename_trgm_idx', 'stock', 'uniquename'],
    ['stock_description_trgm_idx', 'stock', 'description'],
    ['stockprop_synonym_value_trgm_idx', 'stockprop', 'value'],
);
for my $expected (@indexes) {
    my ($name, $table, $column) = @$expected;
    my $index = $dbh->selectrow_hashref($index_sql, undef, $name);
    ok($index, "$name exists");
    next if !$index;
    is($index->{table_name}, $table, "$name indexes the correct table");
    is($index->{method}, 'gin', "$name uses GIN");
    is($index->{column_name}, $column, "$name indexes the correct column");
    is($index->{opclass}, 'gin_trgm_ops', "$name uses trigram operations");
    is($index->{column_count}, 1, "$name has one column");
    ok($index->{valid} && $index->{ready}, "$name is valid and ready");
    if ($table eq 'stockprop') {
        my $predicate = $index->{predicate};
        is($predicate, defined $ids->[0] ? "(type_id = $ids->[0])" : undef,
            "$name is partial on the synonym cvterm");
    }
    else {
        is($index->{predicate}, undef, "$name is not partial");
    }
}

sub has_index_scan {
    my ($node, $name) = @_;
    return 1 if $node->{'Node Type'} eq 'Bitmap Index Scan'
        && ($node->{'Index Name'} // '') eq $name;
    for my $child (@{ $node->{Plans} || [] }) {
        return 1 if has_index_scan($child, $name);
    }
    return 0;
}

# Planner settings only for this transaction.
$dbh->begin_work();
$dbh->do('SET LOCAL enable_seqscan = off');
my ($plan) = $dbh->selectrow_array(
    q{EXPLAIN (FORMAT JSON) SELECT stock_id FROM stock WHERE uniquename ILIKE '%test_accession%'}
);
$dbh->rollback();
my $decoded = decode_json($plan);
ok(has_index_scan($decoded->[0]{Plan}, 'stock_uniquename_trgm_idx'),
    'uniquename search uses the trigram bitmap index');

done_testing();
