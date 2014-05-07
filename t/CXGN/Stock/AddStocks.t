# A test for adding a list of stocks (accessions)
## Jeremy D. Edwards (jde22@cornell.edu) 2013

use strict;
use warnings;

use lib 't/lib';
use Test::More tests=>5;
use SGN::Test::WWW::Mechanize;

BEGIN {require_ok('Moose');}
BEGIN {use_ok('CXGN::DB::Connection');}
BEGIN {use_ok('CXGN::Stock::AddStocks');}

my $test = SGN::Test::WWW::Mechanize->new();
my $schema = $test->context->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
my @accession_array = qw(test545563334234 testing3443555233);
my $species = "Manihot esculenta";
ok(my $stock_add = CXGN::Stock::AddStocks->new({ schema => $schema, stocks => \@accession_array, species => $species} ), "Create object for adding stocks");
ok($stock_add->validate_stocks(), "Verify");
ok($stock_add->add_accessions(), "Add");
