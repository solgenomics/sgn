
package CXGN::List::FuzzySearch::Plugin::FamilyNames;

use Moose;

use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::BreedersToolbox::StocksFuzzySearch;

sub name {
    return "family_names";
}

sub fuzzysearch {
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    my $max_distance = 0.2;
    my $fuzzy_family_names_search = CXGN::BreedersToolbox::StocksFuzzySearch->new({schema => $schema});
    my $fuzzy_search_result = $fuzzy_family_names_search->get_matches($list, $max_distance, 'family_name');

    my $found_family_names = $fuzzy_search_result->{'found'};
    my $fuzzy_family_names = $fuzzy_search_result->{'fuzzy'};
    my $absent_family_names = $fuzzy_search_result->{'absent'};

    my %return = (
        success => "1",
        absent => $absent_family_names,
        fuzzy => $fuzzy_family_names,
        found => $found_family_names,
    );

    if ($fuzzy_search_result->{'error'}){
        $return{error} = $fuzzy_search_result->{'error'};
    }

    return \%return;
}

1;
