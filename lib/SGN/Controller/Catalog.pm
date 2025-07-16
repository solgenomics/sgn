package SGN::Controller::Catalog;

use Moose;
use URI::FromHash 'uri';
use SGN::Model::Cvterm;
use CXGN::People::Person;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller'; }


sub stock_catalog :Path('/catalog/view') :Args(0) {
    my $self = shift;
    my $c = shift;

    if (! $c->user()) {
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    if ($c->user) {
        my $check_vendor_role = $c->user->check_roles('vendor');
        $c->stash->{check_vendor_role} = $check_vendor_role;
    }

    my $ordering_service_name = $c->config->{ordering_service_name};
    $c->stash->{ordering_service_name} = $ordering_service_name;

    my $additional_order_info = $c->config->{additional_order_info};
    $c->stash->{additional_order_info} = $additional_order_info;

    my $ordering_type = $c->config->{ordering_type};
    $c->stash->{ordering_type} = $ordering_type;

    my $order_properties = $c->config->{order_properties};
    my $order_properties_dialog = $c->config->{order_properties_dialog};

    $c->stash->{order_properties} = $order_properties;
    $c->stash->{order_properties_dialog} = $order_properties_dialog;

    $c->stash->{template} = '/order/catalog.mas';

}

sub catalog_item_details : Path('/catalog/item_details') Args(1) {
    my $self = shift;
    my $c = shift;
    my $dbh = $c->dbc->dbh;

    if (! $c->user()) {
	$c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        return;
    }

    if ($c->user) {
        my $check_vendor_role = $c->user->check_roles('vendor');
        $c->stash->{check_vendor_role} = $check_vendor_role;
    }

    my $item_id = shift;
#    print STDERR "CATALOG STOCK ID =".Dumper($item_id)."\n";
    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado', $sp_person_id);
    my $stock_catalog_type_id = SGN::Model::Cvterm->get_cvterm_row($c->dbic_schema("Bio::Chado::Schema", undef, $sp_person_id), 'stock_catalog_json', 'stock_property')->cvterm_id();

    my $stock_catalog_info = $schema->resultset("Stock::Stockprop")->find({stock_id => $item_id, type_id => $stock_catalog_type_id});

    my $item_prop_id;
    if (!$stock_catalog_info){
        $c->stash->{template} = '/generic_message.mas';
        $c->stash->{message} = 'The requested catalog item does not exist.';
        return;
    } else {
        $item_prop_id = $stock_catalog_info->stockprop_id();
    }

    my $stock_catalog_item = $schema->resultset("Stock::Stock")->find({stock_id => $item_id});
    my $item_name = $stock_catalog_item->uniquename();
    my $organism_id = $stock_catalog_item->organism_id();
    my $organism = $schema->resultset("Organism::Organism")->find({organism_id => $organism_id});
    my $species = $organism->species();

    my $item_obj = CXGN::Stock::Catalog->new({ bcs_schema => $schema, parent_id => $item_id});
    my $details_ref = $item_obj->get_item_details();
    my @item_details = @$details_ref;
    print STDERR "ITEM DETAILS =".Dumper(\@item_details)."\n";
    my $item_type = $item_details[0];
    my $species = $item_details[1];
    my $variety = $item_details[2];
    my $material_type = $item_details[3];
    my $category = $item_details[4];
    my $material_source = $item_details[5];
    my $additional_info = $item_details[6];
    my $program_id = $item_details[7];
    my $availability = $item_details[8];
    if (!$availability) {
        $availability = 'available';
    }
    my $contact_person_id = $item_details[9];
    my $images = $item_details[10];
    my $image_id = $images->[0];
    my $image_obj = SGN::Image->new($dbh, $image_id);
    my $medium_image  = $image_obj->get_image_url("medium");

    my $person = CXGN::People::Person->new($dbh, $contact_person_id);
    my $contact_person_username = $person->get_username;

    my $program_rs = $schema->resultset('Project::Project')->find({project_id => $program_id});
    my $program_name = $program_rs->name();

#    print STDERR "CONTACT PERSON NAME=".Dumper($contact_person_username)."\n";
    $c->stash->{item_id} = $item_id;
    $c->stash->{item_name} = $item_name;
    $c->stash->{item_type} = $item_type;
    $c->stash->{species} = $species;
    $c->stash->{variety} = $variety;
    $c->stash->{material_type} = $material_type;
    $c->stash->{category} = $category;
    $c->stash->{material_source} = $material_source;
    $c->stash->{additional_info} = $additional_info;
    $c->stash->{program_id} = $program_id;
    $c->stash->{breeding_program} = $program_name;
    $c->stash->{availability} = $availability;
    $c->stash->{contact_person_username} = $contact_person_username;
    $c->stash->{item_prop_id} = $item_prop_id;
    $c->stash->{image} = qq|<a href="$medium_image" class="stock_image_group" rel="gallery-figures"><img src="$medium_image"/></a> |,
    $c->stash->{selected_image_id} = $image_id;
    $c->stash->{main_page} = qq{<a href="/stock/$item_id/view">$item_name</a>};

    $c->stash->{template} = '/order/catalog_item_details.mas';
}

1;
