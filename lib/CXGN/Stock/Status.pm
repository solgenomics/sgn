
package CXGN::Stock::Status;

=head1 NAME

CXGN::Stock::Status

=head1 DESCRIPTION

Store and manage stock status metadata

=head1 USAGE


=head1 AUTHOR

Titima Tantikanjana <tt15@cornell.edu>

=cut


use Moose;
use Data::Dumper;


extends 'CXGN::JSONProp';

has 'person_id' => (isa => 'Int', is => 'rw');
has 'update_date' => (isa => 'Str', is => 'rw');
has 'comments' => (isa => 'Str', is => 'rw');
has 'completed_metadata' => (isa => 'Bool', is => 'rw', default => 0 );
has 'terminated_metadata' => (isa => 'Bool', is => 'rw', default => 0 );


sub BUILD {
    my $self = shift;
    my $args = shift;
    my $completed_metadata = $self->completed_metadata();
    my $terminated_metadata = $self->terminated_metadata();

    $self->prop_table('stockprop');
    $self->prop_namespace('Stock::Stockprop');
    $self->prop_primary_key('stockprop_id');
    if ($completed_metadata) {
        $self->prop_type('completed_metadata');
    } elsif ($terminated_metadata) {
        $self->prop_type('terminated_metadata');
    }
    $self->cv_name('stock_property');
    $self->allowed_fields([ qw | person_id update_date comments | ]);
    $self->parent_table('stock');
    $self->parent_primary_key('stock_id');

    $self->load();
}


sub get_status_details {
    my $self = shift;
    my $args = shift;
    my $schema = $self->bcs_schema();
    my $stock_id = $self->parent_id();
    my $type = $self->prop_type();
    my $type_id = $self->_prop_type_id();
    my $key_ref = $self->allowed_fields();
    my @fields = @$key_ref;
    my @status_details;
    my $status_details_rs = $schema->resultset("Stock::Stockprop")->find({stock_id => $stock_id, type_id => $type_id});
    if ($status_details_rs) {
        my $details_json = $status_details_rs->value();
        my $detail_hash = JSON::Any->jsonToObj($details_json);
        foreach my $field (@fields){
            push @status_details, $detail_hash->{$field};
        }
    }

    return \@status_details;
}



1;
