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
use SGN::Image;
use CXGN::Stock::Order;
use CXGN::Stock::OrderBatch;
use CXGN::UploadFile;
use CXGN::Stock::ParseUpload;
use CXGN::List;

use DateTime;

use Data::Dumper;
use JSON;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();
my $people_schema = $f->people_schema;
my $dbh = $f->dbh();

#add vendor role for johndoe
my $johndoe_id = CXGN::People::Person->get_person_by_username($dbh, 'johndoe');
my $role_rs = $people_schema->resultset("SpRole")->find( {name => 'vendor'});
my $vendor_id = $role_rs->sp_role_id();
my $person_roles = CXGN::People::Roles->new({ bcs_schema=>$schema });
my $add_role = $person_roles->add_sp_person_role($johndoe_id, $vendor_id);

#test adding catalog item
my $catalog_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "stock_catalog_json", "stock_property")->cvterm_id();
my $before_adding_catalog_item = $schema->resultset("Stock::Stockprop")->search({ type_id => $catalog_type_id})->count();
my $before_adding_all_stockprop = $schema->resultset("Stock::Stockprop")->search({})->count();

my $program_id = $schema->resultset('Project::Project')->find({name => 'test'})->project_id();

my $item_id = $schema->resultset("Stock::Stock")->find({ name => 'UG120001'})->stock_id();
my $stock_catalog = CXGN::Stock::Catalog->new({
    bcs_schema => $schema,
    parent_id => $item_id,
});

$stock_catalog->item_type('single item');
$stock_catalog->category('released variety');
$stock_catalog->description('test item');
$stock_catalog->material_source('Arusha');
$stock_catalog->breeding_program($program_id);
$stock_catalog->availability('in stock');
$stock_catalog->contact_person_id($johndoe_id);

ok($stock_catalog->store(), "check adding catalog");

my $after_adding_catalog_item = $schema->resultset("Stock::Stockprop")->search({ type_id => $catalog_type_id})->count();
my $after_adding_all_stockprop = $schema->resultset("Stock::Stockprop")->search({})->count();

is($after_adding_catalog_item, $before_adding_catalog_item + 1);
is($after_adding_all_stockprop, $before_adding_all_stockprop + 1);

#test uploading catalog items
my $before_uploading_catalog_items = $schema->resultset("Stock::Stockprop")->search({ type_id => $catalog_type_id})->count();
my $before_uploading_all_stockprop = $schema->resultset("Stock::Stockprop")->search({})->count();

my $file_name = "t/data/stock/catalog_items.xls";
my $time = DateTime->now();
my $timestamp = $time->ymd()."_".$time->hms();

#Test archive upload file
my $uploader = CXGN::UploadFile->new({
  tempfile => $file_name,
  subdirectory => 'temp_catalog_upload',
  archive_path => '/tmp',
  archive_filename => 'catalog_items',
  timestamp => $timestamp,
  user_id => $johndoe_id,
  user_role => 'curator'
});

## Store uploaded temporary file in archive
my $archived_filename_with_path = $uploader->archive();
my $md5 = $uploader->get_md5($archived_filename_with_path);
ok($archived_filename_with_path);
ok($md5);

my @stock_props = ('stock_catalog_json');
my $parser = CXGN::Stock::ParseUpload->new(chado_schema => $schema, filename => $archived_filename_with_path, editable_stock_props=>\@stock_props);
$parser->load_plugin('CatalogXLS');
my $parsed_data = $parser->parse();
ok($parsed_data, "Check if parse validate excel file works");
ok(!$parser->has_parse_errors(), "Check that parse returns no errors");
#print STDERR "PARSED DATA =".Dumper($parsed_data)."\n";

my %catalog_info = %{$parsed_data};
foreach my $item_name (keys %catalog_info) {
    my $stock_id = $schema->resultset("Stock::Stock")->find({uniquename => $item_name})->stock_id();
    my %catalog_info_hash = %{$catalog_info{$item_name}};

    my $stock_catalog = CXGN::Stock::Catalog->new({
        bcs_schema => $schema,
        item_type => $catalog_info_hash{item_type},
        category => $catalog_info_hash{category},
        description => $catalog_info_hash{description},
        material_source => $catalog_info_hash{material_source},
        breeding_program => $catalog_info_hash{breeding_program},
        availability => $catalog_info_hash{availability},
        contact_person_id => $catalog_info_hash{contact_person_id},
        parent_id => $stock_id
    });

    ok($stock_catalog->store(), "check uploading catalog item");
}

my $after_uploading_catalog_items = $schema->resultset("Stock::Stockprop")->search({ type_id => $catalog_type_id})->count();
my $after_uploading_all_stockprop = $schema->resultset("Stock::Stockprop")->search({})->count();

is($after_uploading_catalog_items, $before_uploading_catalog_items + 2);
is($after_uploading_all_stockprop, $before_uploading_all_stockprop + 2);

#test creating shopping cart with 'catalog_items' list type
my $janedoe_id = CXGN::People::Person->get_person_by_username($dbh, 'janedoe');
my $your_cart_id = CXGN::List::create_list($dbh, 'your_cart', 'test shopping cart', $janedoe_id);
my $list = CXGN::List->new( { dbh => $dbh, list_id => $your_cart_id } );
my $your_cart_type = $list->type('catalog_items');
my $add_item_response = $list->add_bulk(['UG120001, Quantity: 2', 'UG120002, Quantity: 3']);
is($add_item_response->{'count'}, 2);

#test storing an order from janedoe, to johndoe
my $new_order = CXGN::Stock::Order->new( { people_schema => $people_schema, dbh => $dbh});
$new_order->order_from_id($janedoe_id);
$new_order->order_to_id($johndoe_id);
$new_order->order_status("submitted");
$new_order->create_date($timestamp);
ok(my $order_id = $new_order->store(), "check storing order");

#test storing orderprop
my $your_cart = CXGN::List->new( { dbh=>$dbh, list_id=>$your_cart_id });
my $items = $list->elements();
my @all_items = @$items;
my $ordered_item_info = {};

foreach my $ordered_item (@all_items) {
    $ordered_item_info->{$ordered_item} = 'single item';
}
my $order_list = encode_json $ordered_item_info;

my @history;
my $history_info = {};
$history_info ->{'submitted'} = $timestamp;
push @history, $history_info;

my $order_prop = CXGN::Stock::OrderBatch->new({ bcs_schema => $schema, people_schema => $people_schema});
$order_prop->clone_list($order_list);
$order_prop->parent_id($order_id);
$order_prop->history(\@history);
ok(my $order_prop_id = $order_prop->store_sp_orderprop(), "check storing orderprop");





done_testing();
