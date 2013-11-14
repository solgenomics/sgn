package CXGN::BreedersToolbox::AccessionsFuzzySearch;

=head1 NAME

CXGN::BreedersToolbox::AccessionsFuzzySearch - an object to find approximate matches in the database to a query accession name.

=head1 USAGE

 my $fuzzy_accession_search = CXGN::BreedersToolbox::AccessionsFuzzySearch->new({schema => $schema});
 my $fuzzy_search_result = $fuzzy_accession_search->get_matches($accession_name, $max_distance)};

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
    my $accession_name = shift;
    my $max_distance = shift;
    my $schema = $self->get_schema();
    my $type_id = $schema->resultset("Cv::Cvterm")->search({ name=>"accession" })->first->cvterm_id();
    my $stock_rs = $schema->resultset("Stock::Stock")->search({type_id=>$type_id,});
    my $stock;
    my $synonym_prop;
    my %synonym_uniquename_lookup;
    my @stock_names;
    my @synonym_names;
    my @matches;
    my $fuzzy_string_search = CXGN::String::FuzzyMatch->new();
    my @uniquename_matches;
    my @synonym_matches;

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
	#push (@synonym_names, $synonym_name);
	if ($synonym_uniquename_lookup{$synonym_name}) {
	  push (@{$synonym_uniquename_lookup{$synonym_name}},$unique_name);
	}
	else {
	  my @unique_names = [$unique_name];
	  $synonym_uniquename_lookup{$synonym_name} = \@unique_names;
	}
      }
    }
    @synonym_names = keys %synonym_uniquename_lookup;
    @uniquename_matches = @{$fuzzy_string_search->get_matches($accession_name, \@stock_names, $max_distance)};
    @synonym_matches = @{$fuzzy_string_search->get_matches($accession_name, \@synonym_names, $max_distance)};


    #@matches = @accession_matches;
    return \@matches;
}

###
1;
###
