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
use SGN::Model::Cvterm;
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
	my @accession_list = @{$accession_list_ref};
	my %synonym_uniquename_lookup;
	my $fuzzy_string_search = CXGN::String::FuzzyMatch->new( { case_insensitive => 0} );
	my @fuzzy_accessions;
	my @absent_accessions;
	my @found_accessions;
	my %results;
	print STDERR "FuzzySearch 1".localtime()."\n";

	my $synonym_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();
	my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
	my $q = "SELECT stock.uniquename, stockprop.value, stockprop.type_id FROM stock LEFT JOIN stockprop USING(stock_id) WHERE stock.type_id=$accession_type_id";
	my $h = $schema->storage->dbh()->prepare($q);
	$h->execute();
	my %uniquename_hash;
	while (my ($uniquename, $synonym, $type_id) = $h->fetchrow_array()) {
		$uniquename_hash{$uniquename} = 1;
		if ($type_id){
			if ($type_id == $synonym_type_id){
				push @{$synonym_uniquename_lookup{$synonym}}, $uniquename;
			}
		}
	}

	my @stock_names = keys %uniquename_hash;
	my @synonym_names = keys %synonym_uniquename_lookup;
	push (@stock_names, @synonym_names);
	my %stock_names_hash = map {$_ => 1} @stock_names;

	print STDERR "FuzzySearch 2".localtime()."\n";

  foreach my $accession_name (@accession_list) {
	  if (exists($stock_names_hash{$accession_name})){
		  push @found_accessions, {"matched_string" => $accession_name, "unique_name" => $accession_name};
		  next;
	  }
	my @search_stock_names;
	foreach (@stock_names){
		if (length $_ >= length $accession_name){
			push @search_stock_names, $_;
		}
	}
    my @matches;
    my @accession_matches = @{$fuzzy_string_search->get_matches($accession_name, \@search_stock_names, $max_distance)};
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
