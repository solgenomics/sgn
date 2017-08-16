
package CXGN::List::FuzzySearch::Plugin::Accessions;

use Moose;

use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::BreedersToolbox::AccessionsFuzzySearch;

sub name { 
    return "accessions";
}

sub fuzzysearch {
    my $self = shift;
    my $schema = shift;
    my $list = shift;

    my $max_distance = 0.2;
    my $fuzzy_accession_search = CXGN::BreedersToolbox::AccessionsFuzzySearch->new({schema => $schema});
    my $fuzzy_search_result = $fuzzy_accession_search->get_matches($list, $max_distance);

    my $found_accessions = $fuzzy_search_result->{'found'};
    my $fuzzy_accessions = $fuzzy_search_result->{'fuzzy'};
    my $absent_accessions = $fuzzy_search_result->{'absent'};

    if (scalar(@$fuzzy_accessions)>0){
        my %synonym_hash;
        my $synonym_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id;
        my $synonym_rs = $schema->resultset('Stock::Stock')->search({'stockprops.type_id'=>$synonym_type_id}, {join=>'stockprops', '+select'=>['stockprops.value'], '+as'=>['value']});
        while (my $r = $synonym_rs->next()){
            $synonym_hash{$r->get_column('value')} = $r->uniquename;
        }

        foreach (@$fuzzy_accessions){
            my $matches = $_->{matches};
            foreach my $m (@$matches){
                my $name = $m->{name};
                if (exists($synonym_hash{$name})){
                    $m->{is_synonym} = 1;
                    $m->{synonym_of} = $synonym_hash{$name};
                }
            }
        }
    }

    return {
        success => "1",
        absent => $absent_accessions,
        fuzzy => $fuzzy_accessions,
        found => $found_accessions,
    };

}

1;
