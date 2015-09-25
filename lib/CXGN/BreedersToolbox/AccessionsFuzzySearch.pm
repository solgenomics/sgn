package CXGN::BreedersToolbox::AccessionsFuzzySearch;

=head1 NAME

CXGN::BreedersToolbox::AccessionsFuzzySearch - an object to find approximate matches in the database to a query accession name.

=head1 USAGE

 my $fuzzy_accession_search = CXGN::BreedersToolbox::AccessionsFuzzySearch->new({schema => $schema});
 my $fuzzy_search_result = $fuzzy_accession_search->get_matches(\@accession_list, $max_distance)};

=head1 DESCRIPTION


=head1 AUTHORS

 Jeremy D. Edwards (jde22@cornell.edu)

=cut

use strict;
use warnings;
use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use CXGN::String::FuzzyMatch;
#use Data::Dumper;

has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 required => 1,
		);


sub get_matches {
  my $self = shift;
  my $accession_list_ref = shift;
  my $max_distance = shift;
  my $schema = $self->get_schema();
  my $type_id = $schema->resultset("Cv::Cvterm")->search({ name=>"accession" })->first->cvterm_id();
  my $stock_rs = $schema->resultset("Stock::Stock")->search({type_id=>$type_id,});
  my @accession_list = @{$accession_list_ref};
  my $stock;
  my $synonym_prop;
  my %synonym_uniquename_lookup;
  my @stock_names;
  my @synonym_names;
  my $fuzzy_string_search = CXGN::String::FuzzyMatch->new( { case_insensitive => 1} );
  my @fuzzy_accessions;
  my @absent_accessions;
  my @found_accessions;
  my %results;


  while ($stock = $stock_rs->next()) {
    my $unique_name = $stock->uniquename();
    my $synonym_rs =$schema->resultset("Stock::Stockprop")
      ->search({
		stock_id => $stock->stock_id(),
		'lower(type.name)'       => { like => '%synonym%' },
	       },{join => 'type' });
    push (@stock_names, $unique_name);
    while ($synonym_prop = $synonym_rs->next()) {
      my $synonym_name = $synonym_prop->value();
      if ($synonym_uniquename_lookup{$synonym_name}) {
	push (@{$synonym_uniquename_lookup{$synonym_name}},$unique_name);
      } else {
	my @unique_names = [$unique_name];
	$synonym_uniquename_lookup{$synonym_name} = \@unique_names;
      }
    }
  }

  @synonym_names = keys %synonym_uniquename_lookup;
  push (@stock_names, @synonym_names);

  foreach my $accession_name (@accession_list) {
    my @matches;
    my @accession_matches = @{$fuzzy_string_search->get_matches($accession_name, \@stock_names, $max_distance)};
    my $more_than_one_perfect_match = 0;
    my $more_than_one_unique_name_for_synonym = 0;
    my $has_one_unique_match = 0;

    if (scalar @accession_matches eq 0) {
      push (@absent_accessions, $accession_name);
    } else {
      my $matched_string = $accession_matches[0]->{'string'};
      my $synonym_lookup_of_matched_string = $synonym_uniquename_lookup{$matched_string};

      #Make sure that there isn't more than one perfect match
      if ($accession_matches[1]) {
	my $next_matched_string = $accession_matches[1]->{'string'};
	if ($next_matched_string eq $accession_name) {
	  $more_than_one_perfect_match = 1;
	}
      }

      #Make sure that there isn't more than one unique name for the searched string if synonym
      if ($synonym_lookup_of_matched_string) {
	if (scalar @{$synonym_lookup_of_matched_string} > 1) {
	  $more_than_one_unique_name_for_synonym = 1;
	}
      }

      #Store accession name to found list if there is one unique match
      if ( $matched_string eq $accession_name && !$more_than_one_perfect_match && !$more_than_one_unique_name_for_synonym) {
	my %found_accession_and_uniquename;
	$found_accession_and_uniquename{'matched_string'} = $accession_name;

	#when there is a synonym, store the unique name and the searched string
	if ($synonym_lookup_of_matched_string) {
	  my @unique_names_of_synonym;
	  @unique_names_of_synonym = @{$synonym_lookup_of_matched_string};
	  #should not be more than one unique name for synonym because checked array length earlier
	  $found_accession_and_uniquename{'unique_name'} = $unique_names_of_synonym[0];
	} else {
	  $found_accession_and_uniquename{'unique_name'} = $accession_name;
	}
	push (@found_accessions, \%found_accession_and_uniquename);
	$has_one_unique_match = 1;
      }

      if (!$has_one_unique_match) {
	foreach my $match (@accession_matches) {
	  my $matched_name = $match->{'string'};
	  my $distance = $match->{'distance'};
	  my %match_info;
	  $match_info{'name'} = $matched_name;
	  $match_info{'distance'} = $distance;
	  if ($synonym_uniquename_lookup{$matched_name}) {
	    $match_info{'unique_names'} = $synonym_uniquename_lookup{$matched_name};
	  } else {
	    my @unique_names_array = [$matched_name];
	    $match_info{'unique_names'} = \@unique_names_array;
	  }
	  push (@matches, \%match_info);
	}
	my %accession_and_fuzzy_matches;
	$accession_and_fuzzy_matches{'name'} = $accession_name;
	$accession_and_fuzzy_matches{'matches'} = \@matches;
	push (@fuzzy_accessions, \%accession_and_fuzzy_matches);
      }
    }
  }
  $results{'found'} = \@found_accessions;
  $results{'fuzzy'} = \@fuzzy_accessions;
  $results{'absent'} = \@absent_accessions;
  return \%results;
}
###
1;
###
