
package CXGN::Trial::TrialLayout::Analysis;



use Moose;
use namespace::autoclean;

extends 'CXGN::Trial::TrialLayout::AbstractLayout';


sub BUILD {
    my $self = shift;
    $self->set_source_stock_types( [ "analysis_instance" ] );
}

###

__PACKAGE__->meta()->make_immutable();

1;





