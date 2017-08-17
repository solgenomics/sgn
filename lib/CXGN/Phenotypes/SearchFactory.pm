package CXGN::Phenotypes::SearchFactory;

=head1 NAME

CXGN::Phenotypes::SearchFactory - an object factory to handle searching phenotypes across database. factory delegates between cxgn schema search and mat-view search

=head1 USAGE

my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
    'Native',    #can be either 'MaterializedView', or 'Native'
    {
        bcs_schema=>$schema,
        data_level=>$data_level,
        trait_list=>$trait_list,
        trait_component_list=>$trait_component_list,
        trial_list=>$trial_list,
        year_list=>$year_list,
        location_list=>$location_list,
        accession_list=>$accession_list,
        plot_list=>$plot_list,
        plant_list=>$plant_list,
        include_timestamp=>$include_timestamp,
        trait_contains=>$trait_contains,
        phenotype_min_value=>$phenotype_min_value,
        phenotype_max_value=>$phenotype_max_value,
        limit=>$limit,
        offset=>$offset
    }
);
my @data = $phenotypes_search->search();

=head1 DESCRIPTION


=head1 AUTHORS

 Nicolas Morales <nm529@cornell.edu>
 With code moved from CXGN::BreederSearch
 Lukas Mueller <lam87@cornell.edu>
 Aimin Yan <ay247@cornell.edu>

=cut

use strict;
use warnings;

sub instantiate {
    my $class = shift;
    my $type = shift;
    my $location = "CXGN/Phenotypes/Search/$type.pm";
    my $obj_class = "CXGN::Phenotypes::Search::$type";
    require $location;
    return $obj_class->new(@_);
}

1;
