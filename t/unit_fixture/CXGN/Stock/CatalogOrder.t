
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use LWP::UserAgent;
use LWP::UserAgent;
use CXGN::People::Schema;
use CXGN::People::Roles;
use CXGN::List;
use Moose;
use CXGN::Stock::Catalog;
use CXGN::People::Person;
use SGN::Image;



use Data::Dumper;
use JSON;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $people_schema = $f->people_schema;

my $dbh = $f->dbh();

my $mech = Test::WWW::Mechanize->new;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = decode_json $mech->content;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};
print STDERR $sgn_session_id."\n";

#add vendor role for johndoe
my $sp_person_id = CXGN::People::Person->get_person_by_username($dbh, 'johndoe');
my $role_rs = $people_schema->resultset("SpRole")->find( {name => 'vendor'});
my $vendor_id = $role_rs->sp_role_id();
my $person_roles = CXGN::People::Roles->new({ bcs_schema=>$schema });
my $add_role = $person_roles->add_sp_person_role($sp_person_id, $vendor_id);

my $program_rs = $schema->resultset('Project::Project')->find({name => 'test'});
my $program_id = $program_rs->project_id();

#test adding catalog item
my $catalog_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "stock_catalog_json", "stock_property")->cvterm_id();
my $before_adding_catalog_item = $schema->resultset("Stock::Stockprop")->search({ type_id => $catalog_type_id})->count();
my $before_adding_all_stockprop = $schema->resultset("Stock::Stockprop")->search({})->count();

$mech->post_ok('http://localhost:3010/ajax/catalog/add_item', ['item_name' => 'UG120001', 'item_type' => 'single item', 'item_category' => 'released variety', 'item_description' => 'test description', 'item_material_source' => 'Sendusu', 'item_breeding_program' => $program_id, 'item_availability' => 'in stock', 'contact_person' => "johndoe"]);

$response = decode_json $mech->content;
is($response->{'success'}, '1');

my $after_adding_catalog_item = $schema->resultset("Stock::Stockprop")->search({ type_id => $catalog_type_id})->count();
my $after_adding_all_stockprop = $schema->resultset("Stock::Stockprop")->search({})->count();

is($after_adding_catalog_item, $before_adding_catalog_item + 1);
is($after_adding_all_stockprop, $before_adding_all_stockprop + 1);

#test uploading catalog items
my $before_uploading_catalog_items = $schema->resultset("Stock::Stockprop")->search({ type_id => $catalog_type_id})->count();
my $before_uploading_all_stockprop = $schema->resultset("Stock::Stockprop")->search({})->count();

my $file = $f->config->{basepath}."/t/data/stock/catalog_items.xls";
my $ua = LWP::UserAgent->new;
$response = $ua->post(
    'http://localhost:3010/ajax/catalog/upload_items',
    Content_Type => 'form-data',
    Content => [
        "catalog_items_upload_file" => [ $file, 'catalog_items.xls', Content_Type => 'application/vnd.ms-excel', ],
        "sgn_session_id" => $sgn_session_id
    ]
);
ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = decode_json $message;
is_deeply($message_hash, {'success' => 1});

my $after_uploading_catalog_items = $schema->resultset("Stock::Stockprop")->search({ type_id => $catalog_type_id})->count();
my $after_uploading_all_stockprop = $schema->resultset("Stock::Stockprop")->search({})->count();

is($after_uploading_catalog_items, $before_uploading_catalog_items + 2);
is($after_uploading_all_stockprop, $before_uploading_all_stockprop + 2);

#test adding items to shopping cart
#creating shopping cart with 'catalog_items' list type
my $user_id = CXGN::People::Person->get_person_by_username($dbh, 'janedoe');
my $your_cart_id = CXGN::List::create_list($dbh, 'your_cart', 'test shopping cart', $user_id);
my $list = CXGN::List->new( { dbh => $dbh, list_id => $your_cart_id } );
my $your_cart_type = $list->type('catalog_items');





done_testing();
