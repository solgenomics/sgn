
package CXGN::Trial::TrialLayout::Genotyping;

use Moose;
use namespace::autoclean;

extends 'CXGN::Trial::TrialLayout::AbstractLayout';


sub BUILD {
    my $self = shift;
    $self->set_source_stock_types( [ "tissue_sample" ] );
        # probably better to lazy load the action design...
    #
    $self->_lookup_trial_id();

}




###

__PACKAGE__->meta()->make_immutable();

1;
