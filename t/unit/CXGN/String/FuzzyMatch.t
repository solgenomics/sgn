
use strict;
use Test::More;
use Data::Dumper;
use CXGN::String::FuzzyMatch;

my $fm = CXGN::String::FuzzyMatch->new();

my $matches = $fm->get_matches("ABCD", [ "ABCE", "XBCD" ], 0.3);
#print STDERR Dumper($matches);

is_deeply( [
          {
            'distance' => '0.25',
            'string' => 'ABCE'
          },
          {
            'distance' => '0.25',
            'string' => 'XBCD'
          }
	   ], $matches, "get_matches_test");


$fm->case_insensitive(1);

$matches = $fm->get_matches("abcd", [ "ABCE", "XBCD" ], 0.3);

is_deeply( [
          {
            'distance' => '0.25',
            'string' => 'ABCE'
          },
          {
            'distance' => '0.25',
            'string' => 'XBCD'
          }
	   ], $matches, "get_matches_test")
;

#print STDERR Dumper($matches); 

$matches = $fm->get_matches("ABCD", [ "abce", "xbcd" ], 0.3);

is_deeply( [
          {
            'distance' => '0.25',
            'string' => 'ABCE'
          },
          {
            'distance' => '0.25',
            'string' => 'XBCD'
          }
	   ], $matches, "get_matches_test");

#print STDERR Dumper($matches);

$fm->case_insensitive(0);

$matches = $fm->get_matches("abcd", [ "ABCD", "ABCE" ], 0.3);

#print STDERR Dumper($matches);

is_deeply( [], $matches);

done_testing();
