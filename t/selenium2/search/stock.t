
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;

my $d = SGN::Test::WWW::WebDriver->new();
$d->driver->set_timeout('implicit', 5000);

# Set up the DB connection
my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

# -------------------------------------------------------------------------
# Data Setup

# Create some stock properties for us to search for ('country of origin', 'state')
my $test_accession1_stock_id = $schema->resultset("Stock::Stock")->find({uniquename => "test_accession1"})->stock_id();
my $test_accession2_stock_id = $schema->resultset("Stock::Stock")->find({uniquename => "test_accession2"})->stock_id();

my $country_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, "country of origin", "stock_property")->cvterm_id();
my $state_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, "state", "stock_property")->cvterm_id();

my $test_accession1_country = $schema->resultset("Stock::Stockprop")->find_or_create({stock_id => $test_accession1_stock_id, type_id => $country_cvterm, value => 'test_country_1'});
my $test_accession2_country = $schema->resultset("Stock::Stockprop")->find_or_create({stock_id => $test_accession2_stock_id, type_id => $country_cvterm, value => 'test_country_2'});
my $test_accession1_state = $schema->resultset("Stock::Stockprop")->find_or_create({stock_id => $test_accession1_stock_id, type_id => $state_cvterm, value => 'test_state_1'});
my $test_accession2_state = $schema->resultset("Stock::Stockprop")->find_or_create({stock_id => $test_accession2_stock_id, type_id => $state_cvterm, value => 'test_state_2'});

$d->while_logged_in_as("user", sub {

    # -------------------------------------------------------------------------
    # Simple Search

    $d->get_ok('/search/stocks');
    my $page_source = lc($d->driver()->get_page_source());

    ok($page_source =~ /search accessions/, "Search page title presence");

    ok($page_source =~ /project location/, "Search options present");

    $d->send_keys_ok("any_name", "id", "test_accession1", "find any_name html input element");

    $d->click_ok("//select[\@id=\"stock_type_select\"]/option[text()='accession']", "xpath","select stock type");

    $d->click_ok("submit_stock_search", "id", "submit search");
    $d->click_ok("test_accession1", "partial_link_text", "verify search");

    $d->find_element_ok("Solanum lycopersicum", "link_text", "verify organism");
    $d->wait_for_network_idle();

    # -------------------------------------------------------------------------
    # Search by Stock Properties

    $d->get_ok('/search/stocks');
    $d->click_ok("advanced_search_panel_onswitch", "id", "open advanced search");
    $d->click_ok("stock_search_properties_panel_onswitch", "id", "open properties search");

    my $search_results;

    # Search for single property ('test_state_1') that only matches only 1 accession
    $d->click_ok("//select[\@id=\"editable_stockprop_search_term\"]/option[text()='state']", "xpath","select state property");
    $d->click_ok("editable_stockprop_search_add", "id", "add state property");
    $d->send_keys_ok("state_input_id", "id", "test_state_1", "enter state property");
    $d->click_ok("submit_stock_search", "id", "submit search");
    $search_results = $d->get_attribute_ok("stock_search_results", "id", "innerHTML", "get search results content");
    ok($search_results =~ /test_accession1/, "verify test_accession1 is in results");
    ok($search_results !~ /test_accession2/, "verify test_accession2 is not in results");

    # Search for single property ('test_state') that only matches 2 accessions
    $d->clear_ok("state_input_id", "id", "clear state property");
    $d->send_keys_ok("state_input_id", "id", "test_state", "enter state property");
    $d->click_ok("submit_stock_search", "id", "submit search");
    $search_results = $d->get_attribute_ok("stock_search_results", "id", "innerHTML", "get search results content");
    ok($search_results =~ /test_accession1/, "verify test_accession1 is in results");
    ok($search_results =~ /test_accession2/, "verify test_accession2 is in results");

    # Search for multiple properties (state, country of origin ) that only matches 1 accession
    $d->clear_ok("state_input_id", "id", "clear state property");
    $d->send_keys_ok("state_input_id", "id", "test_state_1", "enter state property");
    $d->click_ok("//select[\@id=\"editable_stockprop_search_term\"]/option[text()='country of origin']", "xpath","select country property");
    $d->click_ok("editable_stockprop_search_add", "id", "add country property");
    $d->send_keys_ok("country_of_origin_input_id", "id", "test_country_1", "enter country property");
    $d->click_ok("submit_stock_search", "id", "submit search");
    $search_results = $d->get_attribute_ok("stock_search_results", "id", "innerHTML", "get search results content");
    ok($search_results =~ /test_accession1/, "verify test_accession1 is in results");
    ok($search_results !~ /test_accession2/, "verify test_accession2 is not in results");

    # Search for multiple properties (state, country of origin ) that only matches 2 accessions
    $d->clear_ok("state_input_id", "id", "clear state property");
    $d->send_keys_ok("state_input_id", "id", "test_state", "enter state property");
    $d->clear_ok("country_of_origin_input_id", "id", "clear country property");
    $d->send_keys_ok("country_of_origin_input_id", "id", "test_country", "enter country property");
    $d->click_ok("submit_stock_search", "id", "submit search");
    $search_results = $d->get_attribute_ok("stock_search_results", "id", "innerHTML", "get search results content");
    ok($search_results =~ /test_accession1/, "verify test_accession1 is in results");
    ok($search_results =~ /test_accession2/, "verify test_accession2 is in results");

    # Search for one of
    $d->click_ok("reset_stock_search", "id", "reset search");
    $d->click_ok("//select[\@id=\"editable_stockprop_search_term\"]/option[text()='state']", "xpath","select state property");
    $d->click_ok("editable_stockprop_search_add", "id", "add state property");
    $d->click_ok("//select[\@id=\"editable_stockprop_matchtype\"]/option[\@value='one of']", "xpath","select one of match type");
    $d->send_keys_ok("state_input_id", "id", "test_state_1,test_state_2", "enter state properties");
    $d->click_ok("submit_stock_search", "id", "submit search");
    $search_results = $d->get_attribute_ok("stock_search_results", "id", "innerHTML", "get search results content");
    ok($search_results =~ /test_accession1/, "verify test_accession1 is in results");
    ok($search_results =~ /test_accession2/, "verify test_accession2 is in results");


});

# Cleanup
$test_accession1_country->delete() if defined $test_accession1_country;
$test_accession2_country->delete() if defined $test_accession2_country;
$test_accession1_state->delete() if defined $test_accession1_state;
$test_accession2_state->delete() if defined $test_accession2_state;

$d->wait_for_network_idle();
$d->driver->quit();
done_testing();
