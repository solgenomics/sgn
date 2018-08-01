
package CXGN::List::FuzzySearch::Plugin::Accessions;

use Moose;

use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::BreedersToolbox::StocksFuzzySearch;

sub name {
    return "accessions";
}

sub fuzzysearch {
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    my $max_distance = 0.2;
    my $fuzzy_accession_search = CXGN::BreedersToolbox::StocksFuzzySearch->new({schema => $schema});
    my $fuzzy_search_result = $fuzzy_accession_search->get_matches($list, $max_distance, 'accession');

    my $found_accessions = $fuzzy_search_result->{'found'};
    my $fuzzy_accessions = $fuzzy_search_result->{'fuzzy'};
    my $absent_accessions = $fuzzy_search_result->{'absent'};

    my %return = (
        success => "1",
        absent => $absent_accessions,
        fuzzy => $fuzzy_accessions,
        found => $found_accessions,
    );

    if ($fuzzy_search_result->{'error'}){
        $return{error} = $fuzzy_search_result->{'error'};
    }

    return \%return;
}

1;
