
use strict;

use Test::More qw | no_plan |;

use lib 't/lib';

use SGN::Test::Fixture;

my $fix = SGN::Test::Fixture->new();

is(ref($fix->config()), "HASH", 'hashref check');

my $q = "SELECT count(*) FROM stock";
my $h = $fix->dbh()->prepare($q);
$h->execute();
my $stock_count = $h->fetchrow_array();
ok($stock_count, "dbh test");

my $rs = $fix->bcs_schema->resultset("Stock::Stock")->search( {} );
ok($rs->count(), "bcs schema test");
