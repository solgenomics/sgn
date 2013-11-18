## A test for fuzzy searching of accessions (stocks of type 'accession')
## Jeremy D. Edwards (jde22@cornell.edu) 2013

use strict;
use warnings;

use lib 't/lib';
use Test::More tests=>6;
use SGN::Test::WWW::Mechanize;

BEGIN {use_ok('CXGN::BreedersToolbox::AccessionsFuzzySearch');}
BEGIN {use_ok('CXGN::DB::Connection');}
BEGIN {require_ok('Moose');}

my $test = SGN::Test::WWW::Mechanize->new();
my $schema = $test->context->dbic_schema('Bio::Chado::Schema');
my $accession_name = "testing";
my $max_distance = 1;
my @accession_list;
push (@accession_list, $accession_name);

ok(my $fuzzy_accession_search = CXGN::BreedersToolbox::AccessionsFuzzySearch->new({schema => $schema}),"Create AccessionsFuzzySearch object");
ok(my $fuzzy_search_result = $fuzzy_accession_search->get_matches(\@accession_list, $max_distance),"Do a fuzzy accession search");
isa_ok($fuzzy_search_result,'ARRAY',"Result is an array reference");
