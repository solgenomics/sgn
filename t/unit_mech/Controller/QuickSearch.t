use strict;
use warnings;

use Test::More;

use lib 't/lib';

use Test::WWW::Mechanize;

my $mech = Test::WWW::Mechanize->new();

print STDERR "Fetching URL...\n";
$mech->get_ok('http://localhost:3010/search/quick?term=test_accession1', 'check accession quicksearch');

print STDERR "Checking content...\n";
$mech->content_contains('0 EST identifiers');
$mech->content_contains('1 accession');

$mech->get_ok('http://localhost:3010/search/quick?term=TestPopulation1', 'check population quicksearch');
$mech->content_contains('1 population', 'check if population found.');

$mech->get_ok('http://localhost:3010/search/quick?term=Kasese+solgs+trial', 'check trial quicksearch');
$mech->content_contains('0 EST identifiers', 'should not find ESTs');
$mech->content_contains('0 accession', 'should not find accessions');
$mech->content_contains('1 trial', 'check if trial found');

$mech->get_ok('http://localhost:3010/search/quick?term=root+yield', 'check trait quicksearch');
$mech->content_contains('1 trait', 'check if trait found');

$mech->get_ok('http://localhost:3010/search/quick?term=Cornell+biotech', 'check locations quicksearch');
$mech->content_contains('1 location', 'check if location found');

$mech->get_ok('http://localhost:3010/search/quick?term=test', 'check breeding program quicksearch');
$mech->content_contains('1 breeding program');

done_testing;
