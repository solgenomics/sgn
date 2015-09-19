package CXGN::String::FuzzyMatch;

=head1 NAME

CXGN::String::FuzzyMatch - an object to find approximate matches to a query string in an array of strings.

=head1 USAGE

 my $fuzzy_string_search = CXGN::String::FuzzyMatch->new();
 my @string_matches = @{$fuzzy_string_search->get_matches($query_string, \@string_array, $max_distance)};

=head1 DESCRIPTION


=head1 AUTHORS

 Jeremy D. Edwards (jde22@cornell.edu)

=cut

use strict;
use warnings;
use String::Approx 'adistr';
use Moose;
use Data::Dumper;

has 'case_insensitive' => ( isa => 'Bool',
			    is => 'rw',
    );

sub get_matches {
    my $self = shift;
    my $query_string = shift;
    my $string_array_ref = shift;
    my $max_distance = shift;
    my @matches;
    my @string_array = @{$string_array_ref};
    my @distances;
    my %string_distance_lookup;
    my %string_length_difference_lookup;
    my @strings_sorted_distance;
    my @strings_sorted_length;
    my $query_length = length $query_string;

    if ($self->case_insensitive()) { 
	$query_string = uc($query_string);
	@string_array = map { uc($_) } @string_array;
    }

    #no fuzzy search if max distance is 0
    if ($max_distance == 0) {
      for my $i (0 .. $#string_array) {
	my $string_match = $string_array[$i];
	if ($query_string eq $string_match) {
	  $string_length_difference_lookup{$string_match} = 0;
	}
      }
    } else {

      @distances = adistr($query_string, @string_array);

      for my $i (0 .. $#string_array) {
	my $distance = $distances[$i];
	my $string_match = $string_array[$i];
	if ($distance == 0) {
	  $string_length_difference_lookup{$string_match} = (length $string_match) - $query_length;
	} elsif (abs($distance) <= $max_distance) {
	  $string_distance_lookup{$string_match}=$distance;
	}
      }

    }


    #get a list of strings sorted by their difference in length from the query
    @strings_sorted_length = sort { abs($string_length_difference_lookup{$a}) <=> abs($string_length_difference_lookup{$b}) } keys(%string_length_difference_lookup);

    #get a list of strings sorted by their distance from the query
    @strings_sorted_distance = sort { abs($string_distance_lookup{$a}) <=> abs($string_distance_lookup{$b}) } keys(%string_distance_lookup);

    foreach my $sorted_string (@strings_sorted_length) {
      my %string_distance_result;
      $string_distance_result{'string'} = $sorted_string;
      $string_distance_result{'distance'} = 0;
      push (@matches, \%string_distance_result);
    };

    foreach my $sorted_string (@strings_sorted_distance) {
      my %string_distance_result;
      $string_distance_result{'string'} = $sorted_string;
      $string_distance_result{'distance'} = $string_distance_lookup{$sorted_string};
      push (@matches, \%string_distance_result);
    };


    return \@matches;

}

###
1;
###
