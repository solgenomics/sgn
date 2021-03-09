package SGN::Controller::AJAX::Catalog;

use Moose;
use CXGN::Stock::Catalog;
use Data::Dumper;
use JSON;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub add_catalog_item : Path('/ajax/catalog/add_item') : ActionClass('REST'){ }

sub add_catalog_item_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $dbh = $c->dbc->dbh;

    my $item_name = $c->req->param('item_name');
    my $item_type = $c->req->param('item_type');
    my $item_category = $c->req->param('item_category');
    my $item_description = $c->req->param('item_description');
    my $item_material_source = $c->req->param('item_material_source');
    my $item_breeding_program = $c->req->param('item_breeding_program');
    my $item_availability = $c->req->param('item_availability');
    my $item_comment = $c->req->param('item_comment');
    my $item_stock_id;

    if (!$c->user()) {
        print STDERR "User not logged in... not adding a catalog item.\n";
        $c->stash->{rest} = {error_string => "You must be logged in to add a catalog item." };
        return;
    }

    my $item_rs = $schema->resultset("Stock::Stock")->find({uniquename => $item_name});
    if (!$item_rs) {
        $c->stash->{rest} = {error_string => "Item name is not in the database!",};
        return;
    } else {
        $item_stock_id = $item_rs->stock_id();
    }

    my $stock_catalog = CXGN::Stock::Catalog->new({
        bcs_schema => $schema,
        item_type => $item_type,
        category => $item_category,
        description => $item_description,
        material_source => $item_material_source,
        breeding_program => $item_breeding_program,
        availability => $item_availability,
        comment => $item_comment,
        parent_id => $item_stock_id
    });

    $stock_catalog->store();

    if (!$stock_catalog->store()){
        $c->stash->{rest} = {error_string => "Error saving catalog item",};
        return;
    }

    $c->stash->{rest} = {success => "1",};

}


1;
