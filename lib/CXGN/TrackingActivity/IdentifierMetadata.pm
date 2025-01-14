package CXGN::TrackingActivity::IdentifierMetadata;

use Moose;
use Data::Dumper;

extends 'CXGN::JSONProp';

has 'data_type' => ( isa => 'Str', is => 'rw' );

has 'data_level' => ( isa => 'Str', is => 'rw' );

sub BUILD {
    my $self = shift;
    my $args = shift;

    $self->prop_table('stockprop');
    $self->prop_namespace('Stock::Stockprop');
    $self->prop_primary_key('stockprop_id');
    $self->prop_type('identifier_metadata');
    $self->cv_name('stock_property');
    $self->allowed_fields( [ qw | data_type data_level | ] );
    $self->parent_table('stock');
    $self->parent_primary_key('stock_id');

    $self->load();
}

sub get_identifier_metadata {
    my $self = shift;
    my $args = shift;
    my $schema = $self->bcs_schema();
    my $identifier_id = $self->parent_id();
    my $type = $self->prop_type();
    my $type_id = $self->_prop_type_id();
    my $key_ref = $self->allowed_fields();
    
    my @fields = @$key_ref;
    my @identifier_metadata;
    my $metadata_rs = $schema->resultset("Stock::Stockprop")->find({stock_id => $identifier_id, type_id => $type_id});
    if ($metadata_rs) {
        my $metadata_json = $metadata_rs->value();
        my $metadata_hash = JSON::Any->jsonToObj($metadata_json);
        foreach my $field (@fields){
            push @identifier_metadata, $metadata_hash->{$field};
        }
    }

    return \@identifier_metadata;
}



1;
