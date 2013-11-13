package CXGN::String::FuzzyMatch;

=head1 NAME

CXGN::String::FuzzMatch - an object to find approximate matches to a query string in an array of strings.

=head1 USAGE

 my $fuzzy_string_search = CXGN::String::FuzzyMatch->new();
 my @string_matches = $fuzzy_string_search->get_matches($query_string, \@string_array, $max_distance);

=head1 DESCRIPTION


=head1 AUTHORS

 Jeremy D. Edwards (jde22@cornell.edu)

=cut

use strict;
use warnings;
use String::Approx;

sub get_matches {
    my $self = shift;
    my $query_string = shift;
    my $string_array_ref = shift;
    my $max_distance = shift;
    my @matches;
    my @string_array = @{$string_array_ref};
    return @matches;
}

###
1;
###
