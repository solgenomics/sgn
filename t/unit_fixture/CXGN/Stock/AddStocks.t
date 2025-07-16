## A test for adding stocks
## Jeremy D. Edwards (jde22@cornell.edu) 2015
##CXGN::Stock::AddStocks is DEPRECATED. Please use CXGN::Stock::Accession->store, which inherits from CXGN::Stock

use strict;
use warnings;

use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use CXGN::People::Person;

use Data::Dumper;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();
my $phenome_schema = $f->phenome_schema();
my $dbh = $f->dbh();

$f->get_db_stats();

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

my $owner_sp_person_id = CXGN::People::Person->get_person_by_username($dbh, $owner_name);

my $owner_search = $phenome_schema->resultset("StockOwner")
    ->find({
	stock_id     => $stock_search->first()->stock_id(),
	   });
is($owner_search->sp_person_id(), $owner_sp_person_id, "Stock owner attached to added stock");

is($stock_add->validate_organism(), 1, "Species name validation"); 

is($stock_add->validate_owner(), 1, "Stock owner name validation"); 

$stock_add->set_species("wrongname");

is($stock_add->validate_stocks(), undef, "Incorrect species should not validate"); 

$stock_add->set_owner_name("wrongowner");

is($stock_add->validate_owner(), undef, "Stock owner names that do not exist should not validate"); 

# Create a population
my $population_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
    { name   => 'population',
      cv     => 'stock_type',
     
    });

my $population_name = "test_1_population";

my @populations_to_add = ( $population_name );

ok(my $add_population = CXGN::Stock::AddStocks
   ->new({
       schema => $schema,
       phenome_schema => $phenome_schema,
       dbh => $dbh,
       stocks => \@populations_to_add,
       species => $species,
       owner_name => $owner_name,
	 }),"Create AddStocks object to add population");

ok($add_population->add_population(), "Add new population");

my @stocks_in_population = qw( GroupTestAddStock1 GroupTestAddStock2 );
ok(my $stock_add_in_population = CXGN::Stock::AddStocks
   ->new({
       schema => $schema,
       phenome_schema => $phenome_schema,
       dbh => $dbh,
       stocks => \@stocks_in_population,
       species => $species,
       population_name => $population_name,
       owner_name => $owner_name,
	 }),"Create AddStocks object");

is($stock_add_in_population->validate_population(), 1, "Stock population validation"); 

ok($stock_add_in_population->add_accessions(), "Add new stocks to a population");

my $accession_population_find = $schema->resultset("Stock::Stock")
      ->find({
	  uniquename => $population_name,
	  type_id => $population_cvterm->cvterm_id(),
	       } );

my $population_member_cvterm = $schema->resultset("Cv::Cvterm")
    ->create_with({
	name   => 'member_of',
	cv     => 'stock_relationship',

		  });

my $population_member = $schema->resultset("Stock::Stock")
    ->find({
	uniquename => $stocks_in_population[0],
	'object.uniquename'=> $population_name,
	'stock_relationship_subjects.type_id' => $population_member_cvterm->cvterm_id()
	   }, {join => {'stock_relationship_subjects' => 'object'}});

is($population_member->uniquename(), $stocks_in_population[0], "Find members of population"); 

$f->clean_up_db();

done_testing();
