# A test for fuzzy searching of an array of strings with a query string
## Jeremy D. Edwards (jde22@cornell.edu) 2013

use strict;
use warnings;

use Test::More tests=>8;

BEGIN {use_ok('CXGN::String::FuzzyMatch');}
BEGIN {require_ok('Moose');}
BEGIN {require_ok('String::Approx');}

my $query_string = "testing";
my @string_array = qw(test testing texting testing123 testingtesting123 Testing different);
my $max_distance = 1;
my $fuzzy_string_search;
my @string_matches;
my %string_distance_expected;
my %string_distance_result;

ok($fuzzy_string_search = CXGN::String::FuzzyMatch->new(),"Create FuzzyMatch object");
isa_ok($fuzzy_string_search->get_matches($query_string, \@string_array, $max_distance),'ARRAY', "Fuzzy string match returns an array reference");
ok(@string_matches= @{$fuzzy_string_search->get_matches($query_string, \@string_array, $max_distance)},"Get fuzzy string matches");
isa_ok($string_matches[0],'HASH','Match is a hash reference');
$string_distance_expected{'string'}='testing';
$string_distance_expected{'distance'}=0;
is_deeply($string_matches[0], \%string_distance_expected, 'String match returns perfect match');


