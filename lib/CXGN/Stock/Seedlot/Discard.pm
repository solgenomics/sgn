
package CXGN::Stock::Seedlot::Discard;

=head1 NAME

CXGN::Stock::Seedlot::Discard

=head1 DESCRIPTION

Store and manage discarded seedlot metadata

=head1 USAGE


=head1 AUTHOR

Titima Tantikanjana <tt15@cornell.edu>

=cut


use Moose;

extends 'CXGN::JSONProp';

has 'person_id' => (isa => 'Int', is => 'rw');
has 'discard_date' => (isa => 'Str', is => 'rw');
has 'reason' => (isa => 'Str', is => 'rw');


sub BUILD {
    my $self = shift;
    my $args = shift;

    $self->prop_table('stockprop');
    $self->prop_namespace('Stock::Stockprop');
    $self->prop_primary_key('stockprop_id');
    $self->prop_type('discarded_metadata');
    $self->cv_name('stock_property');
    $self->allowed_fields([ qw | person_id discard_date reason | ]);
    $self->parent_table('stock');
    $self->parent_primary_key('stock_id');

    $self->load();
}


1;
