
use strict;
use Test::More;
use Data::Dumper;
use CXGN::String::FuzzyMatch;

my $fm = CXGN::String::FuzzyMatch->new();

my $matches = $fm->get_matches("ABCD", [ "ABCE", "XBCD" ], 0.3);
my $sorted = sort_matches($matches);
#print STDERR Dumper($sorted);

is_deeply( [
          {
            'distance' => '0.25',
            'string' => 'ABCE'
          },
          {
            'distance' => '0.25',
            'string' => 'XBCD'
          }
	   ], $sorted, "get_matches_test1");


$fm->case_insensitive(1);

$matches = $fm->get_matches("abcd", [ "ABCE", "XBCD" ], 0.3);
my $sorted = sort_matches($matches);

is_deeply( [
          {
            'distance' => '0.25',
            'string' => 'ABCE'
          },
          {
            'distance' => '0.25',
            'string' => 'XBCD'
          }
	   ], $sorted, "get_matches_test2")
;

#print STDERR Dumper($matches); 

$matches = $fm->get_matches("ABCD", [ "abce", "xbcd" ], 0.3);
my $sorted = sort_matches($matches);

is_deeply( [
          {
            'distance' => '0.25',
            'string' => 'ABCE'
          },
          {
            'distance' => '0.25',
            'string' => 'XBCD'
          }
	   ], $sorted, "get_matches_test3");

#print STDERR Dumper($matches);

$fm->case_insensitive(0);

$matches = $fm->get_matches("abcd", [ "ABCD", "ABCE" ], 0.3);

#print STDERR Dumper($matches);

is_deeply( [], $matches);

done_testing();

sub sort_matches {
    my $matches = shift;
    my %keyed_matches;
    foreach (@$matches) { $keyed_matches{$_->{string}} = $_; }
    my @ordered_strings;
    foreach (sort keys %keyed_matches) { push @ordered_strings, $_; }
    my @ordered_matches;
    foreach (@ordered_strings) { push @ordered_matches, $keyed_matches{$_}; }
    return \@ordered_matches;
}
