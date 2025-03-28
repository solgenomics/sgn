
package CXGN::Trial::TrialLayout::Analysis;



use Moose;
use namespace::autoclean;

extends 'CXGN::Trial::TrialLayout::AbstractLayout';


sub BUILD {
    my $self = shift;

    print STDERR "BUILD CXGN::Trial::TrialLayout::Analysis...\n";
    $self->set_source_primary_stock_types( [ "accession", "analysis_result" ] );
    $self->set_source_stock_types( [ "accession", "analysis_result", "tissue_sample" ] );
    $self->set_relationship_types( [ "analysis_of" ]);
    $self->set_target_stock_types( [ "analysis_instance" ]);
    $self->convert_source_stock_types_to_ids();

    # probably better to lazy load the action design...
    $self->_lookup_trial_id();

}

###

__PACKAGE__->meta()->make_immutable();

1;
