use strict;
use warnings;

use lib 't/lib';

use SGN::Test::Fixture;
use Test::More;

# Parent lookups filter stock_relationship by object_id and type_id together.
# Database patch 00211 adds the index that serves them.

my $fixture = SGN::Test::Fixture->new();
my $dbh = $fixture->dbh();

my ($definition, $valid) = $dbh->selectrow_array(<<'EOSQL');
SELECT pg_get_indexdef(idx.indexrelid), idx.indisvalid AND idx.indisready
FROM pg_index idx
JOIN pg_class ix ON ix.oid = idx.indexrelid
JOIN pg_namespace ns ON ns.oid = ix.relnamespace
WHERE ns.nspname = 'public' AND ix.relname = 'stock_relationship_object_id_type_id_idx'
EOSQL
like($definition // '', qr/ ON public\.stock_relationship USING btree \(object_id, type_id\)$/,
    'stock_relationship has the index on (object_id, type_id)');
ok($valid, 'the index is valid and ready');

done_testing();
