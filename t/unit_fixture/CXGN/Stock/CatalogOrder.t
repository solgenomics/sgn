use strict;
use warnings;
use lib 't/lib';

use Test::More;
use Data::Dumper;
use SGN::Test::Fixture;
use CXGN::People::Schema;
use CXGN::People::Roles;
use CXGN::List;
use CXGN::Stock::Catalog;
use CXGN::People::Person;
use CXGN::Stock::Order;
use CXGN::Stock::OrderBatch;
use CXGN::UploadFile;
use CXGN::Stock::ParseUpload;
use CXGN::List;
use Test::WWW::Mechanize;
use DateTime;

use Data::Dumper;
use JSON;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();
my $people_schema = $f->people_schema;
my $dbh = $f->dbh();

my $mech = Test::WWW::Mechanize->new;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username" => "janedoe", "password" => "secretpw", "grant_type" => "password" ]);
my $response = decode_json $mech->content;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};
print STDERR $sgn_session_id . "\n";

#add vendor role for johndoe
my $johndoe_id = CXGN::People::Person->get_person_by_username($dbh, 'johndoe');
my $role_rs = $people_schema->resultset("SpRole")->find({ name => 'vendor' });
my $vendor_id = $role_rs->sp_role_id();
my $person_roles = CXGN::People::Roles->new({ bcs_schema => $schema });
my $add_role = $person_roles->add_sp_person_role($johndoe_id, $vendor_id);

#test adding catalog item
my $catalog_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "stock_catalog_json", "stock_property")->cvterm_id();
my $before_adding_catalog_item = $schema->resultset("Stock::Stockprop")->search({ type_id => $catalog_type_id })->count();
my $all_stockprop_before_adding = $schema->resultset("Stock::Stockprop")->search({})->count();

my $program_id = $schema->resultset('Project::Project')->find({ name => 'test' })->project_id();

my $item_rs = $schema->resultset("Stock::Stock")->find({ name => 'UG120001' });
my $item_id = $item_rs->stock_id();
my $stock_catalog = CXGN::Stock::Catalog->new({
    bcs_schema => $schema,
    parent_id  => $item_id,
});

my $variety_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'variety', 'stock_property')->cvterm_id();
my $organism_id = $item_rs->organism_id();
my $organism = $schema->resultset("Organism::Organism")->find({organism_id => $organism_id});
my $item_species = $organism->species();
my $item_variety;
my $item_stockprop = $schema->resultset("Stock::Stockprop")->find({stock_id => $item_id, type_id => $variety_type_id});
if ($item_stockprop) {
    $item_variety = $item_stockprop->value();
} else {
    $item_variety = 'NA';
}

$stock_catalog->item_type('single item');
$stock_catalog->material_type('plant');
$stock_catalog->material_source('BTI');
$stock_catalog->category('released variety');
$stock_catalog->species($item_species);
$stock_catalog->variety($item_variety);
$stock_catalog->breeding_program($program_id);
$stock_catalog->additional_info('test adding info');
$stock_catalog->contact_person_id($johndoe_id);

ok($stock_catalog->store(), "check adding catalog");

my $after_adding_catalog_item = $schema->resultset("Stock::Stockprop")->search({ type_id => $catalog_type_id })->count();
my $after_adding_all_stockprop = $schema->resultset("Stock::Stockprop")->search({})->count();

is($after_adding_catalog_item, $before_adding_catalog_item + 1);
is($after_adding_all_stockprop, $all_stockprop_before_adding + 1);

for my $extension ("xls", "xlsx") {

    #test uploading catalog items
    my $before_uploading_catalog_items = $schema->resultset("Stock::Stockprop")->search({ type_id => $catalog_type_id })->count();
    my $before_uploading_all_stockprop = $schema->resultset("Stock::Stockprop")->search({})->count();

    my $file_name = "t/data/stock/catalog_items.$extension";
    my $time = DateTime->now();
    my $timestamp = $time->ymd() . "_" . $time->hms();

    #Test archive upload file
    my $uploader = CXGN::UploadFile->new({
        tempfile         => $file_name,
        subdirectory     => 'temp_catalog_upload',
        archive_path     => '/tmp',
        archive_filename => "catalog_items.$extension",
        timestamp        => $timestamp,
        user_id          => $johndoe_id,
        user_role        => 'curator'
    });

    ## Store uploaded temporary file in archive
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    ok($archived_filename_with_path);
    ok($md5);

    my @stock_props = ('stock_catalog_json');
    my $parser = CXGN::Stock::ParseUpload->new(chado_schema => $schema, filename => $archived_filename_with_path, editable_stock_props => \@stock_props);
    $parser->load_plugin('CatalogXLS');
    my $parsed_data = $parser->parse();
    ok($parsed_data, "Check if parse validate excel file works");
    ok(!$parser->has_parse_errors(), "Check that parse returns no errors");
    #print STDERR "PARSED DATA =".Dumper($parsed_data)."\n";

    my %catalog_info = %{$parsed_data};
    foreach my $item_name (keys %catalog_info) {
        my $stock_id = $schema->resultset("Stock::Stock")->find({ uniquename => $item_name })->stock_id();
        my %catalog_info_hash = %{$catalog_info{$item_name}};

        my $stock_catalog = CXGN::Stock::Catalog->new({
            bcs_schema        => $schema,
            item_type         => $catalog_info_hash{item_type},
            category          => $catalog_info_hash{category},
            material_type       => $catalog_info_hash{material_type},
            material_source   => $catalog_info_hash{material_source},
            breeding_program  => $catalog_info_hash{breeding_program},
            additional_info      => $catalog_info_hash{additional_info},
            contact_person_id => $catalog_info_hash{contact_person_id},
            parent_id         => $stock_id
        });

        ok($stock_catalog->store(), "check uploading catalog item");
    }

    my $after_uploading_catalog_items = $schema->resultset("Stock::Stockprop")->search({ type_id => $catalog_type_id })->count();
    my $after_uploading_all_stockprop = $schema->resultset("Stock::Stockprop")->search({})->count();

    is($after_uploading_catalog_items, $before_uploading_catalog_items + 2);
    is($after_uploading_all_stockprop, $before_uploading_all_stockprop + 2);
}

#creating shopping cart with 'catalog_items' list type
my $janedoe_id = CXGN::People::Person->get_person_by_username($dbh, 'janedoe');
my $your_cart_id = CXGN::List::create_list($dbh, 'your_cart', 'test shopping cart', $janedoe_id);
my $list = CXGN::List->new({ dbh => $dbh, list_id => $your_cart_id });
my $your_cart_type = $list->type('catalog_items');
my $item1 = $list->add_element('{"Item Name":"UG120001","Quantity":"2","Comments":""}');
my $item2 = $list->add_element('{"Item Name":"UG120002","Quantity":"3","Comments":""}');

my $list_items = $list->elements();

#test storing an order from janedoe, to johndoe

$mech->post_ok('http://localhost:3010/ajax/order/submit', ['list_id' => $your_cart_id,]);
$response = decode_json $mech->content;
is($response->{'success'}, 'Your order has been submitted successfully and the vendor has been notified.');

#delete your cart
CXGN::List::delete_list($dbh, $your_cart_id);

#test retrieving order from janedoe
my $buyer_order_obj = CXGN::Stock::Order->new({ dbh => $dbh, people_schema => $people_schema, order_from_id => $janedoe_id });
my $buyer_orders = $buyer_order_obj->get_orders_from_person_id();
my $first_order_info = $buyer_orders->[0];
is($first_order_info->{'order_id'}, '1');
is($first_order_info->{'order_status'}, 'submitted');
is($first_order_info->{'order_to_name'}, 'John Doe');

my $items = $first_order_info->{'clone_list'};
my $buyer_num_items = @$items;
is($buyer_num_items, '2');

#test retrieving order to johndoe
my $vendor_order_obj = CXGN::Stock::Order->new({ dbh => $dbh, people_schema => $people_schema, order_to_id => $johndoe_id });
my $vendor_orders = $vendor_order_obj->get_orders_to_person_id();

my $order = $vendor_orders->[0];
is($order->{'order_id'}, '1');
is($order->{'order_status'}, 'submitted');
is($order->{'order_from_name'}, 'Jane Doe');
is($order->{'completion_date'}, undef);
is($order->{'contact_person_comments'}, undef);

my $clone_list = $order->{'clone_list'};
my $vendor_num_items = @$clone_list;
is($vendor_num_items, '2');

#test_single_step_submission
$mech->post_ok('http://localhost:3010/ajax/order/single_step_submission', ['item_name' => 'UG120001', 'order_details' => '{"Quantity":"2","Comments":""}']);
$response = decode_json $mech->content;
is($response->{'success'}, 'Your request has been submitted successfully and the vendor has been notified.');

#test deleting catalog
my $catalog_rs = $schema->resultset("Stock::Stockprop")->search({ type_id => $catalog_type_id });

while (my $catalog = $catalog_rs->next()) {
    my $catalog_stockprop_id = $catalog->stockprop_id();
    my $catalog_obj = CXGN::Stock::Catalog->new({ bcs_schema => $schema, prop_id => $catalog_stockprop_id });
    $catalog_obj->delete();
}

my $after_deleting_catalog_items = $schema->resultset("Stock::Stockprop")->search({ type_id => $catalog_type_id })->count();
my $all_stockprop_after_deleting_catalog = $schema->resultset("Stock::Stockprop")->search({})->count();

is($after_deleting_catalog_items, $before_adding_catalog_item);
is($all_stockprop_after_deleting_catalog, $all_stockprop_before_adding);


done_testing();
