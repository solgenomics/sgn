package CXGN::BreedersToolbox::StocksFuzzySearch;

=head1 NAME

CXGN::BreedersToolbox::StocksFuzzySearch - an object to find approximate matches in the database to a query list of stock names.

=head1 USAGE

 my $fuzzy_stock_search = CXGN::BreedersToolbox::StocksFuzzySearch->new({schema => $schema});
 my $fuzzy_search_result = $fuzzy_stock_search->get_matches(\@stock_list, $max_distance, $stock_type);

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
use Data::Dumper;

has 'schema' => (
    is       => 'rw',
    isa      => 'DBIx::Class::Schema',
    required => 1,
);


sub get_matches {
    my $self = shift;
    my $stock_list_ref = shift;
    my $max_distance = shift;
    my $stock_type = shift;
    my $schema = $self->get_schema();
    my @stock_list = @{$stock_list_ref};
    my %synonym_uniquename_lookup;
    my $fuzzy_string_search = CXGN::String::FuzzyMatch->new( { case_insensitive => 0} );
    my @fuzzy_stocks;
    my @absent_stocks;
    my @found_stocks;
    my %results;
    print STDERR "FuzzySearch 1".localtime()."\n";

    my $synonym_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();
    my $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $stock_type, 'stock_type')->cvterm_id();
    my $q = "SELECT stock.uniquename, stockprop.value, stockprop.type_id FROM stock LEFT JOIN stockprop USING(stock_id) WHERE stock.type_id=$stock_type_id";
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

    foreach my $stock_name (@stock_list) {

        if (exists($uniquename_hash{$stock_name}) && $uniquename_hash{$stock_name} > 1){
            die "More than one uniquename match for $stock_name of type $stock_type. This should not happen!\n";
        }

        if (exists($uniquename_hash{$stock_name})){
            push @found_stocks, {matched_string => $stock_name, unique_name => $stock_name};
            next;
        }

        if (exists($synonym_uniquename_lookup{$stock_name})){
            my %match_info = ( name => $stock_name, distance => 0 );
            if (scalar(@{$synonym_uniquename_lookup{$stock_name}}) > 1){
                my $synonym_lookup_uniquename = join ',', @{$synonym_uniquename_lookup{$stock_name}};
                die "This synonym $stock_name has more than one uniquename $synonym_lookup_uniquename. This should not happen!\n";
            } elsif (scalar(@{$synonym_uniquename_lookup{$stock_name}}) == 1){
                $match_info{'unique_names'} = [$stock_name];
                $match_info{'is_synonym'} = 1;
                $match_info{'synonym_of'} = $synonym_uniquename_lookup{$stock_name}->[0];
            }
            push @fuzzy_stocks, {
                name => $stock_name,
                matches => [\%match_info]
            };
            next;
        }

        my @search_stock_names;
        foreach (@stock_names){
            if (abs(length($_) - length($stock_name)) <= 10){
                push @search_stock_names, $_;
            }
        }

        my @stock_matches = @{$fuzzy_string_search->get_matches($stock_name, \@search_stock_names, $max_distance)};

        if (scalar(@stock_matches) == 0) {
            push (@absent_stocks, $stock_name);
        } else {
            my @matches;
            foreach (@stock_matches){
                my %match_info;
                my $matched_name = $_->{string};
                $match_info{'name'} = $matched_name;
                $match_info{'distance'} = $_->{distance};
                my $synonym_lookup_of_matched_string = $synonym_uniquename_lookup{$matched_name} || [];
                if (scalar(@$synonym_lookup_of_matched_string) > 1){
                    my $synonym_lookup_uniquename = join ',', @$synonym_lookup_of_matched_string;
                    die "This synonym $matched_name has more than one uniquename $synonym_lookup_uniquename. This should not happen!\n";
                } elsif (scalar(@$synonym_lookup_of_matched_string) == 1){
                    $match_info{'unique_names'} = [$matched_name];
                    $match_info{'is_synonym'} = 1;
                    $match_info{'synonym_of'} = $synonym_lookup_of_matched_string->[0];
                } else {
                    $match_info{'unique_names'} = [$matched_name];
                }
                push @matches, \%match_info;
            }
            push @fuzzy_stocks, {
                name => $stock_name,
                matches => \@matches
            };
        }
    }

    $results{'found'} = \@found_stocks;
    $results{'fuzzy'} = \@fuzzy_stocks;
    $results{'absent'} = \@absent_stocks;
    return \%results;
}

###
1;
###
