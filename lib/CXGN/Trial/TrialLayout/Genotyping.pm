
package CXGN::Trial::TrialLayout::Genotyping;

use Moose;
use namespace::autoclean;

extends 'CXGN::Trial::TrialLayout::AbstractLayout';


sub BUILD {
    my $self = shift;
    $self->set_source_stock_types( [ "accession", "tissue_sample", "seedlot", "plot", "training population" ] );
    $self->set_relationship_types( [ "collection_of", "tissue_sample_of", "member_of", "plot_of"] );
    $self->set_target_stock_types( [ "tissue_sample" ] );
    $self->convert_source_stock_types_to_ids();
    
        # probably better to lazy load the action design...
    #
    
    $self->_lookup_trial_id();

}


after 'retrieve_plot_info' => sub {
    $design_info{genotyping_user_id} = $genotyping_user_id;
    print STDERR "RETRIEVED: genotyping_user_id: $design{genotyping_user_id}\n";
    $design_info{genotyping_project_name} = $genotyping_project_name;
    print STDERR "RETRIEVED: genotyping_project_name: $design{genotyping_project_name}\n";
}

###

__PACKAGE__->meta()->make_immutable();

1;
