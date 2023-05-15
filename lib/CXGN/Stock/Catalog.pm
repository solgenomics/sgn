
package CXGN::Stock::Catalog;

use Moose;
use Data::Dumper;

extends 'CXGN::JSONProp';

# a list of representative images, given as image_ids
has 'images' => ( isa => 'Maybe[ArrayRef]', is => 'rw' );

# list of hashrefs like { stock_center => { name => ..., count_available => ..., delivery_time => } }
has 'order_source' => ( isa => 'Maybe[ArrayRef]', is => 'rw');

# item type such as single accession or a set of 10 accessions
has 'item_type' => ( isa => 'Str', is => 'rw');

# material type such as seed or plant
has 'material_type' => ( isa => 'Str', is => 'rw');

# center that generates clones or seed
has 'material_source' => ( isa => 'Maybe[Str]', is => 'rw');

has 'category' => ( isa => 'Str', is => 'rw' );

has 'species' => ( isa => 'Str', is => 'rw' );

has 'variety' => ( isa => 'Maybe[Str]', is => 'rw' );

has 'breeding_program' => ( isa => 'Int', is => 'rw');

has 'additional_info' => ( isa => 'Maybe[Str]', is => 'rw' );

has 'contact_person_id' => ( isa => 'Int', is => 'rw') ;

has 'availability' => ( isa => 'Maybe[Str]', is => 'rw');

# a general human readable description of the stock
#has 'description' => ( isa => 'Str', is => 'rw' );

# availability status: in_stock, delayed, currently_unavailable ...
#has 'availability' => ( isa => 'Str', is => 'rw' );


sub BUILD {
    my $self = shift;
    my $args = shift;

    $self->prop_table('stockprop');
    $self->prop_namespace('Stock::Stockprop');
    $self->prop_primary_key('stockprop_id');
    $self->prop_type('stock_catalog_json');
    $self->cv_name('stock_property');
    $self->allowed_fields( [ qw | item_type species variety material_type category material_source additional_info breeding_program availability contact_person_id images | ] );
    $self->parent_table('stock');
    $self->parent_primary_key('stock_id');

    $self->load();
}

sub get_catalog_items {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my $type = $self->prop_type();
    my $type_id = $self->_prop_type_id();
    my $key_ref = $self->allowed_fields();
    my @fields = @$key_ref;

    my $catalog_rs = $schema->resultset("Stock::Stockprop")->search({type_id => $type_id }, { order_by => {-asc => 'stock_id'} });
    my @catalog_list;
    while (my $r = $catalog_rs->next()){
        my @each_row = ();
        my $catalog_stock_id = $r->stock_id();
        push @each_row, $catalog_stock_id;
        my $item_detail_json = $r->value();
        my $detail_hash = JSON::Any->jsonToObj($item_detail_json);
        foreach my $field (@fields){
            push @each_row, $detail_hash->{$field};
        }
        push @catalog_list, [@each_row];
    }
#    print STDERR "CATALOG LIST =".Dumper(\@catalog_list)."\n";

    return \@catalog_list;
}


sub get_item_details {
    my $self = shift;
    my $args = shift;
    my $schema = $self->bcs_schema();
    my $item_id = $self->parent_id();
    my $type = $self->prop_type();
    my $type_id = $self->_prop_type_id();
    my $key_ref = $self->allowed_fields();
    my @fields = @$key_ref;
    my @item_details;
    my $item_details_rs = $schema->resultset("Stock::Stockprop")->find({stock_id => $item_id, type_id => $type_id});
    my $details_json = $item_details_rs->value();
    my $detail_hash = JSON::Any->jsonToObj($details_json);
    foreach my $field (@fields){
        push @item_details, $detail_hash->{$field};
    }

    return \@item_details;
}

1;
