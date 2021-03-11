package SGN::Controller::Catalog;

use Moose;
use URI::FromHash 'uri';
use SGN::Model::Cvterm;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller'; }


sub stock_catalog :Path('/catalog/view') :Args(0) {
    my $self = shift;
    my $c = shift;

    if (! $c->user()) {
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    $c->stash->{template} = '/order/catalog.mas';

}

sub catalog_item_details : Path('/catalog/item_details') Args(1) {
    my $self = shift;
    my $c = shift;
    my $item_id = shift;
#    print STDERR "CATALOG STOCK ID =".Dumper($item_id)."\n";
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $stock_catalog_type_id = SGN::Model::Cvterm->get_cvterm_row($c->dbic_schema("Bio::Chado::Schema"), 'stock_catalog_json', 'stock_property')->cvterm_id();

    my $stock_catalog_info = $schema->resultset("Stock::Stockprop")->find({stock_id => $item_id, type_id => $stock_catalog_type_id});

    if (!$stock_catalog_info){
        $c->stash->{template} = '/generic_message.mas';
        $c->stash->{message} = 'The requested catalog item does not exist.';
        return;
    }

    my $stock_catalog_item = $schema->resultset("Stock::Stock")->find({stock_id => $item_id});
    my $item_name = $stock_catalog_item->uniquename();
    my $organism_id = $stock_catalog_item->organism_id();
    my $organism = $schema->resultset("Organism::Organism")->find({organism_id => $organism_id});
    my $species = $organism->species();
    my $identifier_prefix = 'SGN';

    my $item_obj = CXGN::Stock::Catalog->new({ bcs_schema => $schema, parent_id => $item_id});
    my $details_ref = $item_obj->get_item_details();
    my @item_details = @$details_ref;
    my $item_type = $item_details[0];
    my $category = $item_details[1];
    my $description = $item_details[2];
    my $material_source = $item_details[3];
    my $breeding_program = $item_details[4];
    my $availability = $item_details[5];
    my $comment = $item_details[6];

    $c->stash->{item_id} = $item_id;
    $c->stash->{item_name} = $item_name;
    $c->stash->{species} = $species;
    $c->stash->{item_type} = $item_type;
    $c->stash->{category} = $category;
    $c->stash->{description} = $description;
    $c->stash->{material_source} = $material_source;
    $c->stash->{breeding_program} = $breeding_program;
    $c->stash->{availability} = $availability;
    $c->stash->{comment} = $comment;
    $c->stash->{identifier_prefix} = $identifier_prefix;

    $c->stash->{template} = '/order/catalog_item_details.mas';
}

1;
