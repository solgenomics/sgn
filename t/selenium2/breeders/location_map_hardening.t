
# Tests the hardening of the Manage Locations map and table:
#  * location names/fields are escaped (stored XSS)
#  * locations without coordinates are skipped
#  * an empty filter result does not throw from fitBounds
#  * the "GIS Day Events" demo geocoder provider is gone
#  * add_from_map declares its variables and clears the NOAA station id
#
# Runs against the fixture test server with a real browser, as the other
# selenium tests do. The relevant code is client-side, so the assertions
# are made with execute_script against the loaded page.

use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;

my $t = SGN::Test::WWW::WebDriver->new();

# a name that, if inserted into the page as HTML instead of text, adds a
# detectable element and fires an inline event handler
my $xss_name = '<img src=x class="xss-probe" onerror="window.__xss_fired=true;">';

$t->while_logged_in_as("submitter", sub {
    sleep(1);

    $t->get_ok('/breeders/locations');
    sleep(5);

    $t->find_element_ok("location_map", "id", "location map is on the page");

    # store a location whose name contains markup, using the page's own
    # session and the same endpoint the store dialog uses
    my $store = $t->driver->execute_script(<<"JS", $xss_name);
        var name = arguments[0];
        var result;
        jQuery.ajax({
            type: 'POST',
            url: '/ajax/location/store',
            async: false,
            data: {
                name: name,
                abbreviation: 'XSSPROBE',
                country_name: 'United States',
                country_code: 'USA',
                programs: 'test',
                type: 'Other',
                latitude: 10,
                longitude: 20,
                altitude: 5
            },
            success: function(r) { result = r; },
            error: function() { result = { error: 'ajax error' }; }
        });
        return result;
JS
    ok($store && !$store->{error}, "stored a location with markup in its name")
        or diag(explain($store));

    # reload so the table and map are rebuilt from the stored data
    $t->get_ok('/breeders/locations');
    sleep(5);

    # --- stored XSS (security) ---
    my $injected = $t->driver->execute_script(
        "return document.querySelectorAll('img.xss-probe').length;"
    );
    is($injected, 0, "location name is not rendered as HTML (no injected element)");

    my $fired = $t->driver->execute_script("return window.__xss_fired ? 1 : 0;");
    is($fired, 0, "inline event handler in the location name did not run");

    my $shown_as_text = $t->driver->execute_script(<<'JS');
        var cells = document.querySelectorAll('#location_table td');
        for (var i = 0; i < cells.length; i++) {
            if (cells[i].textContent.indexOf('<img src=x class="xss-probe"') !== -1) return 1;
        }
        return 0;
JS
    is($shown_as_text, 1, "the location name is shown as escaped text in the table");

    # --- skip locations without coordinates ---
    my $has_coordinates = $t->driver->execute_script(<<'JS');
        try {
            if (typeof has_coordinates !== 'function') return 'missing';
            var good = has_coordinates({ geometry: { coordinates: [20, 10] } });
            var nullish = has_coordinates({ geometry: { coordinates: [null, null] } });
            return (good === true && nullish === false) ? 'ok' : 'wrong';
        } catch (e) { return 'error'; }
JS
    is($has_coordinates, 'ok', "locations without coordinates are filtered out");

    # --- empty filter must not throw from fitBounds ---
    my $empty_filter = $t->driver->execute_script(<<'JS');
        try {
            var table = jQuery('#location_table').DataTable();
            table.search('zzz_no_such_location_zzz').draw();
            table.search('').draw();
            return 'ok';
        } catch (e) {
            return 'throw:' + (e && e.message ? e.message : e);
        }
JS
    is($empty_filter, 'ok', "filtering to zero rows does not throw (guarded fitBounds)");

    # --- demo geocoder provider removed ---
    my $source = $t->driver->get_page_source();
    ok($source !~ /gisday/i, "the 'GIS Day Events' demo geocoder provider is gone");

    # --- add_from_map: no implicit globals, NOAA station cleared ---
    my $add = $t->driver->execute_script(<<'JS');
        window.latitude = undefined;
        window.longitude = undefined;
        jQuery('#location_noaa_station_id').val('GHCND:PROBE');
        add_from_map('11,22');
        return {
            latitude_type: typeof window.latitude,
            longitude_type: typeof window.longitude,
            noaa: jQuery('#location_noaa_station_id').val()
        };
JS
    is($add->{latitude_type},  'undefined', "add_from_map does not leak a global latitude");
    is($add->{longitude_type}, 'undefined', "add_from_map does not leak a global longitude");
    is($add->{noaa}, '', "add_from_map clears the NOAA station id");
});

$t->driver->quit();
done_testing();
