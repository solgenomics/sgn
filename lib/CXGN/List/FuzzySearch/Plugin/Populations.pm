
package CXGN::List::FuzzySearch::Plugin::Populations;

use Moose;

use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::BreedersToolbox::StocksFuzzySearch;

sub name { 
    return "populations";
}

sub fuzzysearch {
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    my $max_distance = 0.2;
    my $fuzzy_search = CXGN::BreedersToolbox::StocksFuzzySearch->new({schema => $schema});
    my $fuzzy_search_result = $fuzzy_search->get_matches($list, $max_distance, 'population');

    my $found = $fuzzy_search_result->{'found'};
    my $fuzzy = $fuzzy_search_result->{'fuzzy'};
    my $absent = $fuzzy_search_result->{'absent'};

    return {
        success => "1",
        absent => $absent,
        fuzzy => $fuzzy,
        found => $found,
    };

}

1;
