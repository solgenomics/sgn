## A test for adding stocks
## Jeremy D. Edwards (jde22@cornell.edu) 2015

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

# Create a group
my $accession_group_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
    { name   => 'accession_group',
      cv     => 'stock type',
      db     => 'null',
      dbxref => 'accession_group',
    });

my $accession_group_name = "test_1_accession_group";

my @groups_to_add = ( $accession_group_name );

ok(my $add_group = CXGN::Stock::AddStocks
   ->new({
       schema => $schema,
       phenome_schema => $phenome_schema,
       dbh => $dbh,
       stocks => \@groups_to_add,
       species => $species,
       owner_name => $owner_name,
	 }),"Create AddStocks object to add accession_group");

ok($add_group->add_accession_group(), "Add new accession_group");

my @stocks_in_group = qw( GroupTestAddStock1 GroupTestAddStock2 );
ok(my $stock_add_in_group = CXGN::Stock::AddStocks
   ->new({
       schema => $schema,
       phenome_schema => $phenome_schema,
       dbh => $dbh,
       stocks => \@stocks_in_group,
       species => $species,
       accession_group => $accession_group_name,
       owner_name => $owner_name,
	 }),"Create AddStocks object");

is($stock_add_in_group->validate_accession_group(), 1, "Stock accession group validation"); 

ok($stock_add_in_group->add_accessions(), "Add new stocks to a group");

my $accession_group_find = $schema->resultset("Stock::Stock")
      ->find({
	  uniquename => $accession_group_name,
	  type_id => $accession_group_cvterm->cvterm_id(),
	       } );

my $accession_group_member_cvterm = $schema->resultset("Cv::Cvterm")
    ->create_with({
	name   => 'accession_group_member_of',
	cv     => 'stock relationship',
	db     => 'null',
	dbxref => 'accession_group_member_of',
		  });

my $group_member = $schema->resultset("Stock::Stock")
    ->find({
	uniquename => $stocks_in_group[0],
	'object.uniquename'=> $accession_group_name,
	'stock_relationship_subjects.type_id' => $accession_group_member_cvterm->cvterm_id()
	   }, {join => {'stock_relationship_subjects' => 'object'}});

is($group_member->uniquename(), $stocks_in_group[0], "Find members of accession group"); 

done_testing();
