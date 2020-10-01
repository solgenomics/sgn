
package CXGN::List::FuzzySearch::Plugin::TissueSamples;

use Moose;

use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::BreedersToolbox::StocksFuzzySearch;

sub name {
    return "tissue_samples";
}

sub fuzzysearch {
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    my $max_distance = 0.2;
    my $fuzzy_search = CXGN::BreedersToolbox::StocksFuzzySearch->new({schema => $schema});
    my $fuzzy_search_result = $fuzzy_search->get_matches($list, $max_distance, 'tissue_sample');

    my $found = $fuzzy_search_result->{'found'};
    my $fuzzy = $fuzzy_search_result->{'fuzzy'};
    my $absent = $fuzzy_search_result->{'absent'};

    my %return = (
        success => "1",
        absent => $absent,
        fuzzy => $fuzzy,
        found => $found,
    );

    if ($fuzzy_search_result->{'error'}){
        $return{error} = $fuzzy_search_result->{'error'};
    }

    return \%return;
}

1;
