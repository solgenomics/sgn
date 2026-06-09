
use lib 't/lib';

use Test::More 'tests'=>24;

use SGN::Test::WWW::WebDriver;

my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub {
    sleep(1);
    
    $t->get_ok('/breeders/locations');
    sleep(1); # FIXME Need to wait for button click handler to be registered

    $t->click_ok("location_map", "id", "find location map on page add location link as submitter");

    $t->click_ok('a[onclick*="add_from_map"]', "css", "find longitude input test");

    # fill a form for location and store values in variables to compare after upload to database
    my $location_name = "yet_another_test_location";
    $t->send_keys_ok("location_name", "id", $location_name, "input location name");

    my $location_abbr = "YATL";
    $t->send_keys_ok("location_abbreviation", "id", $location_abbr, "input location abbreviation");

    my $location_country = "PER";

    $t->click_ok("location_country", "id", "find location country input");

    $t->click_ok("option[value=\"$location_country\"]", "css", "find location PERU country value");

    $t->click_ok("breeding_program_select", "id", "find breeding program select and clear");

    my $location_program = "test";
    $t->send_keys_ok("breeding_program_select", "id", $location_program, "find breeding program select and choose test");

    my $location_type = "Other";
    $t->send_keys_ok("location_type", "id", $location_type, "input location type");

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

    $t->click_ok("store_location_submit", "id", "find location submit and click");

    ok($t->get_alert_text() =~ m/location $location_name added successfully/i, 'new location was saved');
    $t->accept_alert();

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

