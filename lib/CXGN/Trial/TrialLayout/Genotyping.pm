
package CXGN::Trial::TrialLayout::Genotyping;

use Moose;
use namespace::autoclean;

extends 'CXGN::Trial::TrialLayout::AbstractLayout';


sub BUILD {
    my $self = shift;
    $self->set_source_stock_types( [ "tissue_sample" ] );
}




###

__PACKAGE__->meta()->make_immutable();

1;
