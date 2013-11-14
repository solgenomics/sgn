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
    my %synonym_uniquename_lookup;
    my @stock_names;
    my @matches;

    while ($stock = $stock_rs->next()) {
      print STDERR "1\n";
    }
    return \@matches;
}

###
1;
###
