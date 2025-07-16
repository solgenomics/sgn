
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
use Data::Dumper;


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


sub get_discard_details {
    my $self = shift;
    my $args = shift;
    my $schema = $self->bcs_schema();
    my $seedlot_id = $self->parent_id();
    my $type = $self->prop_type();
    my $type_id = $self->_prop_type_id();
    my $key_ref = $self->allowed_fields();
    my @fields = @$key_ref;
    my @discard_details;
    my $discard_details_rs = $schema->resultset("Stock::Stockprop")->find({stock_id => $seedlot_id, type_id => $type_id});
    if ($discard_details_rs) {
        my $details_json = $discard_details_rs->value();
        my $detail_hash = JSON::Any->jsonToObj($details_json);
        foreach my $field (@fields){
            push @discard_details, $detail_hash->{$field};
        }
        print STDERR "DISCARDED DETAILS =".Dumper(\@discard_details)."\n";
    }

    return \@discard_details;
}



1;
