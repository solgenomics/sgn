# A test for getting stock synonyms
use strict;
use warnings;

use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;

use Data::Dumper;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();
my $phenome_schema = $f->phenome_schema();
my $dbh = $f->dbh();
$schema->storage->debug(1);

BEGIN {use_ok('CXGN::Stock::StockLookup');}
BEGIN {require_ok('Moose');}

my $slookup = CXGN::Stock::StockLookup->new({ schema => $schema});

ok(my $resultsA = $slookup
  ->get_stock_synonyms('stock_id',['38857','38840','38863']),
  "Find synonyms by ID");
print STDERR Dumper $resultsA;

ok(my $resultsB = $slookup
  ->get_stock_synonyms('uniquename',['new_test_crossP005','new_test_crossP009','test_accession2']),
  "Find synonyms by uniquename");
print STDERR Dumper $resultsB;

ok(my $resultsC = $slookup
  ->get_stock_synonyms('any_name',['test_accession2_synonym1','new_test_crossP009','test_accession1','test_accession2','test_accession3_synonym1']),
  "Find synonyms by any name (unique or syn)");
print STDERR Dumper $resultsC;

done_testing();
