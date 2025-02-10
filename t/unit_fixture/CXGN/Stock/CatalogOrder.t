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

#add vendor role for johndoe
my $johndoe_id = CXGN::People::Person->get_person_by_username($dbh, 'johndoe');
my $role_rs = $people_schema->resultset("SpRole")->find({ name => 'vendor' });
my $vendor_id = $role_rs->sp_role_id();
my $person_roles = CXGN::People::Roles->new({ people_schema => $people_schema });
my $add_role = $person_roles->add_sp_person_role($johndoe_id, $vendor_id);

#test adding catalog item
my $catalog_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "stock_catalog_json", "stock_property")->cvterm_id();
my $before_adding_catalog_item = $schema->resultset("Stock::Stockprop")->search({ type_id => $catalog_type_id })->count();
my $all_stockprop_before_adding = $schema->resultset("Stock::Stockprop")->search({})->count();

my $program_id = $schema->resultset('Project::Project')->find({ name => 'test' })->project_id();

$mech->post_ok('http://localhost:3010/ajax/catalog/add_item', [ 'name' => 'UG120001', 'category' => 'released variety', 'additional_info' => 'test', 'material_source' => 'BTI', 'breeding_program_id' => $program_id, 'contact_person' => 'johndoe' ]);

$response = decode_json $mech->content;
is($response->{'success'}, '1');

my $after_adding_catalog_item = $schema->resultset("Stock::Stockprop")->search({ type_id => $catalog_type_id })->count();
my $after_adding_all_stockprop = $schema->resultset("Stock::Stockprop")->search({})->count();

is($after_adding_catalog_item, $before_adding_catalog_item + 1);
is($after_adding_all_stockprop, $all_stockprop_before_adding + 1);


#test uploading catalog items
my $extension = "xls";

my $before_uploading_catalog_items = $schema->resultset("Stock::Stockprop")->search({ type_id => $catalog_type_id })->count();
my $before_uploading_all_stockprop = $schema->resultset("Stock::Stockprop")->search({})->count();

my $file = $f->config->{basepath} . "/t/data/stock/catalog_items.$extension";
my $ua = LWP::UserAgent->new;
$response = $ua->post(
    'http://localhost:3010/ajax/catalog/upload_items',
    Content_Type => 'form-data',
    Content => [
        "catalog_items_upload_file" => [
            $file,
            "catalog_items.$extension",
            Content_Type => ($extension eq "xls") ? 'application/vnd.ms-excel' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ],
        "sgn_session_id" => $sgn_session_id
    ]
);
ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = decode_json $message;
is_deeply($message_hash, { 'success' => 1 });

my $after_uploading_catalog_items = $schema->resultset("Stock::Stockprop")->search({ type_id => $catalog_type_id })->count();
my $after_uploading_all_stockprop = $schema->resultset("Stock::Stockprop")->search({})->count();

is($after_uploading_catalog_items, $before_uploading_catalog_items + 2);
is($after_uploading_all_stockprop, $before_uploading_all_stockprop + 2);

#test adding catalog items using list
my $list_id = CXGN::List::create_list($schema->storage->dbh(), 'accessions_for_catalog', 'test', $johndoe_id );
my $list = CXGN::List->new( { dbh => $schema->storage->dbh(), list_id => $list_id });
$list->type('accessions');
$list->add_bulk( [ 'UG120005', 'UG120006', 'UG120007']);

my $before_adding_catalog_list = $schema->resultset("Stock::Stockprop")->search({ type_id => $catalog_type_id })->count();
my $before_adding_catalog_list_all_stockprop = $schema->resultset("Stock::Stockprop")->search({})->count();

$mech->post_ok('http://localhost:3010/ajax/catalog/add_item_list', [ 'list_type' => 'accessions', 'catalog_list' => $list_id, 'category' => 'released variety', 'additional_info' => 'test', 'material_source' => 'BTI', 'breeding_program_id' => $program_id, 'contact_person' => 'johndoe' ]);

$response = decode_json $mech->content;
is($response->{'success'}, '1');

my $after_adding_catalog_list = $schema->resultset("Stock::Stockprop")->search({ type_id => $catalog_type_id })->count();
my $after_adding_catalog_list_all_stockprop = $schema->resultset("Stock::Stockprop")->search({})->count();

is($after_adding_catalog_list, $before_adding_catalog_list + 3);
is($after_adding_catalog_list_all_stockprop, $before_adding_catalog_list_all_stockprop + 3);

#delete list after testing
CXGN::List::delete_list($dbh, $list_id);

#check catalog items
$mech->post_ok("http://localhost:3010/ajax/catalog/items");
$response = decode_json $mech->content;
my $catalog_info = $response->{'data'};
my $total_number_of_items = scalar @$catalog_info;
is($total_number_of_items, 6 );

#creating shopping cart with 'catalog_items' list type
my $janedoe_id = CXGN::People::Person->get_person_by_username($dbh, 'janedoe');
my $your_cart_id = CXGN::List::create_list($dbh, 'your_cart', 'test shopping cart', $janedoe_id);
my $list = CXGN::List->new({ dbh => $dbh, list_id => $your_cart_id });
my $your_cart_type = $list->type('catalog_items');
my $item1 = $list->add_element('{"Item Name":"UG120001","Quantity":"2","Comments":""}');
my $item2 = $list->add_element('{"Item Name":"UG120002","Quantity":"3","Comments":""}');

my $list_items = $list->elements();

#test storing an order from janedoe, to johndoe

my $before_adding_an_order = $people_schema->resultset('SpOrder')->search( { order_to_id => $johndoe_id })->count();

$mech->post_ok('http://localhost:3010/ajax/order/submit', ['list_id' => $your_cart_id,]);
$response = decode_json $mech->content;
is($response->{'success'}, 'Your order has been submitted successfully and the vendor has been notified.');

my $after_adding_an_order = $people_schema->resultset('SpOrder')->search( { order_to_id => $johndoe_id })->count();
is($after_adding_an_order, $before_adding_an_order + 1);

#delete your cart
CXGN::List::delete_list($dbh, $your_cart_id);

#test retrieving order from janedoe
my $buyer_order_obj = CXGN::Stock::Order->new({ dbh => $dbh, bcs_schema => $schema, people_schema => $people_schema, order_from_id => $janedoe_id });
my $buyer_orders = $buyer_order_obj->get_orders_from_person_id();
my $first_order_info = $buyer_orders->[0];
is($first_order_info->{'order_id'}, '1');
is($first_order_info->{'order_status'}, 'submitted');
is($first_order_info->{'order_to_name'}, 'John Doe');

my $items = $first_order_info->{'clone_list'};
my $buyer_num_items = @$items;
is($buyer_num_items, '2');

#test retrieving order to johndoe
my $vendor_order_obj = CXGN::Stock::Order->new({ dbh => $dbh, bcs_schema => $schema, people_schema => $people_schema, order_to_id => $johndoe_id });
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

#test updating order status by johndoe
my $time = DateTime->now();
my $timestamp = $time->ymd()."_".$time->hms();
my $order_obj = CXGN::Stock::Order->new({ dbh => $dbh, bcs_schema => $schema, people_schema => $people_schema, sp_order_id => '1', order_to_id => $johndoe_id, order_status => 'completed', completion_date => $timestamp, comments => 'updated by johndoe'});
my $updated_order = $order_obj->store();
my $after_updating_an_order = $people_schema->resultset('SpOrder')->search( { order_to_id => $johndoe_id })->count();
is($after_updating_an_order, $after_adding_an_order);

#test re-opening an order by janedoe
$mech->post_ok('http://localhost:3010/ajax/order/update', ['order_id' => '1', 'new_status' => 're-opened', 'contact_person_comments' => 'test re-opening an order' ]);
$response = decode_json $mech->content;
is($response->{'success'}, '1');

my $re_opened_order = CXGN::Stock::Order->new({ dbh => $dbh, bcs_schema => $schema, people_schema => $people_schema, sp_order_id => '1' });
my $order_result = $re_opened_order->get_order_details();
my $order_status = $order_result->[5];
is($order_status, 're-opened by Jane Doe');

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
