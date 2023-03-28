
use lib 't/lib';

use Test::More 'tests'=>24;

use SGN::Test::WWW::WebDriver;

my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub {
    sleep(1);
    
    $t->get_ok('/breeders/locations');
    sleep(5);

    my $add_location_link = $t->find_element_ok(
	"location_map",
	"id",
	"find location map on page add location link as submitter"
	);

    $add_location_link->click();

    $t->find_element_ok(
        'a[onclick*="add_from_map"]',
        "css",
        "find longitude input test")->click();

    # fill a form for location and store values in variables to compare after upload to database
    my $location_name = "yet_another_test_location";
    my $location_desc_input = $t->find_element_ok(
        "location_name",
        "id",
        "find location name input");
    $location_desc_input->send_keys($location_name);

    my $location_abbr = "YATL";
    my $location_abbr_input = $t->find_element_ok(
        "location_abbreviation",
        "id",
        "find location abbreviation input");
    $location_abbr_input->send_keys($location_abbr);


    my $location_country = "PER";

    $t->find_element_ok(
        "location_country",
        "id",
        "find location country input")
        ->click();

    $t->find_element_ok(
        "option[value=\"$location_country\"]",
        "css",
        "find location PERU country value")
        ->click();

    $t->find_element_ok(
        "breeding_program_select",
        "id",
        "find breeding program select and clear")
        ->click();

    my $location_program = "test";
    $t->find_element_ok(
        "breeding_program_select",
        "id",
        "find breeding program select and choose test")
        ->send_keys($location_program);

    my $location_type = "Other";
    my $location_type_select = $t->find_element_ok(
        "location_type",
        "id",
        "find location type input");
    $location_type_select->send_keys($location_type);

    # Here are two options -> first to test if the leaflet correctly picks long and lat form a map - and later compare
    # it to stored values, but it can be sometimes problematic if some settings are off or the internet doesn't work?
    # We put fixed values for inputs on the safe side, but there is an alternative to the test leaflet.

    my $location_latitude = "-15.8468";
    my $location_latitude_input = $t->find_element_ok(
        "location_latitude",
        "id",
        "find location latitude input");

    $location_latitude_input->clear();
    $location_latitude_input->send_keys($location_latitude);

    my $location_longitude = "-70.0338";
    my $location_longitude_input = $t->find_element_ok(
        "location_longitude",
        "id",
        "find location longitude input");

    $location_longitude_input->clear();
    $location_longitude_input->send_keys($location_longitude);

    my $location_altitude = "826";
    my $location_altitude_input = $t->find_element_ok(
        "location_altitude",
        "id",
        "find location altitude input");

    $location_altitude_input->clear();
    $location_altitude_input->send_keys($location_altitude);

    $t->find_element_ok(
        "store_location_submit",
        "id",
        "find location submit and click")
        ->click();
    sleep(2);

    ok($t->driver->get_alert_text() =~ m/location $location_name added successfully/i, 'new location was saved');
    $t->driver->accept_alert();

    $t->get_ok('/breeders/locations');
    sleep(2);

    my $page_source = $t->driver->get_page_source();
    ok($page_source =~ m/$location_name/, "location name loaded on page");
    ok($page_source =~ m/$location_abbr/, "location abbreviation loaded on page");
    ok($page_source =~ m/$location_country/, "location country loaded on page");
    ok($page_source =~ m/$location_program/, "location program loaded on page");
    ok($page_source =~ m/$location_type/, "location type loaded on page");
    ok($page_source =~ m/$location_latitude/, "location latitude loaded on page");
    ok($page_source =~ m/$location_longitude/, "location longitude loaded on page");
    ok($page_source =~ m/$location_altitude/, "location altitude loaded on page");

});

$t->driver->quit();
done_testing();

