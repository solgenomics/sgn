## A test for adding stocks
## Jeremy D. Edwards (jde22@cornell.edu) 2015

use strict;
use warnings;

use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
#use CXGN::People::Person;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();
my $phenome_schema = $f->phenome_schema();
my $dbh = $f->dbh();

BEGIN {use_ok('CXGN::Stock::AddStocks');}
BEGIN {require_ok('Moose');}

my @stocks = qw( TestAddStock1 TestAddStock2 );
my $species = "Solanum lycopersicum";
my $owner_name = "johndoe"; #johndoe is a test user that exists in the fixture

ok(my $stock_add = CXGN::Stock::AddStocks
   ->new({
       schema => $schema,
       phenome_schema => $phenome_schema,
       dbh => $dbh,
       stocks => \@stocks,
       species => $species,
       owner_name => $owner_name,
	 }),"Create AddStocks object");

is($stock_add->validate_stocks(), 1, "Validate new stocks don't already exist");  #is true when none of the stock names in the array exist in the database. 

ok($stock_add->add_accessions(), "Add new stocks");

my $stock_search = $schema->resultset("Stock::Stock")
    ->search({
	uniquename => $stocks[0],
	     } );
ok($stock_search->first(), "Stock exists after adding");

my $stock_search_2 = $schema->resultset("Stock::Stock")
    ->search({
	uniquename => $stocks[1],
	     } );
ok($stock_search_2->first(), "Multiple stocks added");

my $organism = $schema->resultset("Organism::Organism")
    ->find({
	species => $species,
	   } );
my $organism_id = $organism->organism_id();

is($stock_search->first()->organism_id(), $organism_id, "Organism id on added stocks is correct");

is($stock_add->validate_stocks(), undef, "Stocks should not validate after being added"); 

#my $owner_sp_person_id = CXGN::People::Person->get_person_by_username($dbh, $owner_name);

done_testing();
