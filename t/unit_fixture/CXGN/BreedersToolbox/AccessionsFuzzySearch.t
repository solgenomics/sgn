## A test for fuzzy searching of accessions (stocks of type 'accession')
## Jeremy D. Edwards (jde22@cornell.edu) 2013

use strict;
use warnings;

use lib 't/lib';
use Test::More tests=>12;
use SGN::Test::Fixture;

BEGIN {use_ok('CXGN::BreedersToolbox::StocksFuzzySearch');}
BEGIN {use_ok('CXGN::DB::Connection');}
BEGIN {require_ok('Moose');}

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();
my $accession_name = "testing";
my $max_distance = 1;
my @accession_list;
push (@accession_list, $accession_name);

ok(my $fuzzy_accession_search = CXGN::BreedersToolbox::StocksFuzzySearch->new({schema => $schema}),"Create StocksFuzzySearch object");
ok(my $fuzzy_search_result = $fuzzy_accession_search->get_matches(\@accession_list, $max_distance, 'accession'),"Do a fuzzy accession search");
isa_ok($fuzzy_search_result,'HASH',"Result is a hash reference");
ok(my $found_results = $fuzzy_search_result->{'found'});
isa_ok($found_results, 'ARRAY', "Result is an array reference");
ok(my $fuzzy_results = $fuzzy_search_result->{'fuzzy'});
isa_ok($found_results, 'ARRAY', "Result is an array reference");
ok(my $absent_results = $fuzzy_search_result->{'absent'});
isa_ok($found_results, 'ARRAY', "Result is an array reference");
