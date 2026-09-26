
# Tests the hardening of the Manage Locations map and table:
#  * user-entered location fields are escaped everywhere they reach the DOM as
#    HTML: table (Name, Abbreviation, Country, NOAA station id columns), map
#    marker label (Abbreviation) and the DataTables "Print" export (which
#    re-decodes the display value before writing it into a new document)
#  * locations without coordinates do not become a pin at 0,0 on the map
#  * an empty filter result does not throw from fitBounds
#  * the "GIS Day Events" demo geocoder provider is gone
#  * add_from_map declares its variables and clears the NOAA station id
#
# Runs against the fixture test server with a real browser, as the other
# selenium tests do. The relevant code is client-side, so the assertions are
# made with execute_script against the loaded page.
#
# Program and Type are not covered here: CXGN::Location::store_location
# validates location_type against a fixed enum and breeding_programs against
# existing project names, so a direct POST cannot inject markup through
# those two fields today (they are still escaped on render, for defense in
# depth and because that validation is not this template's job).
#
# The "GIS Day Events" removal is still checked via page source (not
# behaviour): the only DOM-visible difference is in the geocoder's search
# suggestion dropdown, which only renders after a live query against the
# ArcGIS Online service. The fixture network has no route to that service,
# so a behavioural check would require mocking it - out of scope here.

use strict;
use warnings;

use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;

my $t = SGN::Test::WWW::WebDriver->new();

# Payloads: each adds a distinctly-classed <img> (or, for NOAA, an
# attribute-injection attempt) that is only "live" if the surrounding code
# failed to escape it. onerror fires without any user interaction as soon as
# the element is inserted into a live document, so these also catch fields
# that render on page load (the map marker label) and not just on hover
# (the popup).
my $name_payload    = '<img src=x class="xss-probe" onerror="window.__xss_fired=true;">';
my $abbr_payload    = '<img src=x class="abbr-xss-probe" onerror="window.__abbr_xss_fired=true;">';
my $country_payload = '<img src=x class="country-xss-probe" onerror="window.__country_xss_fired=true;">';
# Attribute-injection attempt against the table's NOAA station link, built as
# "<a href='.../stations/STATION_ID/detail' target=_blank>STATION_ID</a>".
# The trailing // comments out the "/detail" text the template appends, so
# on unpatched code the injected handler is syntactically valid.
my $noaa_payload = q{GHCND:X' onmouseover='window.__noaa_xss_fired=true;//};

my ($probe_id, $nocoord_id);

$t->while_logged_in_as("submitter", sub {
    sleep(1);

    $t->get_ok('/breeders/locations');
    sleep(5);

    $t->find_element_ok("location_map", "id", "location map is on the page");

    # Baseline marker count, before either test location exists.
    my $markers_before = $t->driver->execute_script(
        "return document.querySelectorAll('#location_map .leaflet-marker-icon').length;"
    );

    # store a location whose name, abbreviation, country and NOAA station id
    # all contain an injection attempt, using the page's own session and the
    # same endpoint the store dialog uses
    my $store = $t->driver->execute_script(<<"JS", $name_payload, $abbr_payload, $country_payload, $noaa_payload);
        var name = arguments[0], abbreviation = arguments[1], country_name = arguments[2], noaa_station_id = arguments[3];
        var result;
        jQuery.ajax({
            type: 'POST',
            url: '/ajax/location/store',
            async: false,
            data: {
                name: name,
                abbreviation: abbreviation,
                country_name: country_name,
                country_code: 'USA',
                programs: 'test',
                type: 'Other',
                latitude: 10,
                longitude: 20,
                altitude: 5,
                noaa_station_id: noaa_station_id
            },
            success: function(r) { result = r; },
            error: function() { result = { error: 'ajax error' }; }
        });
        return result;
JS
    ok($store && !$store->{error}, "stored a location with markup in its name/abbreviation/country/NOAA id")
        or diag(explain($store));
    $probe_id = $store->{nd_geolocation_id} if $store;

    # reload so the table and map are rebuilt from the stored data
    $t->get_ok('/breeders/locations');
    sleep(5);

    # the new location has real coordinates, so it must add exactly one marker
    my $markers_after_probe = $t->driver->execute_script(
        "return document.querySelectorAll('#location_map .leaflet-marker-icon').length;"
    );
    is($markers_after_probe, $markers_before + 1, "the located probe adds one marker to the map");

    # --- Name: stored XSS in the table (security) ---
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

    # --- Abbreviation: fires on page load via the marker label innerHTML,
    #     no hover needed (this is the most severe vector on unpatched code) ---
    my $abbr_probe = $t->driver->execute_script(<<'JS');
        return {
            injected: document.querySelectorAll('img.abbr-xss-probe').length,
            fired: window.__abbr_xss_fired ? 1 : 0
        };
JS
    is($abbr_probe->{injected}, 0, "abbreviation is not rendered as HTML in the map marker label");
    is($abbr_probe->{fired}, 0, "inline event handler in the abbreviation did not run on page load");

    my $abbr_shown_as_text = $t->driver->execute_script(<<'JS');
        var cells = document.querySelectorAll('#location_table td');
        for (var i = 0; i < cells.length; i++) {
            if (cells[i].textContent.indexOf('<img src=x class="abbr-xss-probe"') !== -1) return 1;
        }
        return 0;
JS
    is($abbr_shown_as_text, 1, "the abbreviation is shown as escaped text in the table");

    # --- Country: table Code+Country column ---
    my $country_probe = $t->driver->execute_script(<<'JS');
        return {
            injected: document.querySelectorAll('img.country-xss-probe').length,
            fired: window.__country_xss_fired ? 1 : 0
        };
JS
    is($country_probe->{injected}, 0, "country name is not rendered as HTML in the table (no injected element)");
    is($country_probe->{fired}, 0, "inline event handler in the country name did not run");

    # --- NOAA station id: attribute-injection stored XSS on base ---
    my $noaa_probe = $t->driver->execute_script(<<'JS');
        window.__noaa_xss_fired = false;
        var links = document.querySelectorAll('#location_table a');
        var target = null;
        for (var i = 0; i < links.length; i++) {
            if ((links[i].getAttribute('href') || '').indexOf('GHCND:X') !== -1) { target = links[i]; break; }
        }
        if (!target) { return { found: false }; }
        var hasAttr = target.hasAttribute('onmouseover');
        var evt = document.createEvent('MouseEvents');
        evt.initEvent('mouseover', true, true);
        target.dispatchEvent(evt);
        return { found: true, hasAttr: hasAttr, fired: window.__noaa_xss_fired ? 1 : 0 };
JS
    ok($noaa_probe->{found}, "the NOAA station link for the probe location is on the page")
        or diag(explain($noaa_probe));
    is($noaa_probe->{hasAttr} ? 1 : 0, 0, "NOAA station id does not inject a live onmouseover attribute");
    is($noaa_probe->{fired}, 0, "the injected onmouseover handler did not run");

    # --- Print export: DataTables Buttons 1.2.2 decodes entities in the
    #     display value by default, which would turn the escaped text back
    #     into live markup before print-min.js writes it with innerHTML.
    #     Trigger the real print button, intercepting window.open so no
    #     window/print dialog actually opens, and inspect the HTML it
    #     would have written. ---
    my $print_probe = $t->driver->execute_script(<<'JS');
        var fakeDoc = document.implementation.createHTMLDocument('print');
        var fakeWin = { document: fakeDoc, print: function(){}, close: function(){} };
        var realOpen = window.open;
        window.open = function() { return fakeWin; };
        try {
            jQuery('#location_table').DataTable().button('.buttons-print').trigger();
        } finally {
            window.open = realOpen;
        }
        return {
            name_injected: fakeDoc.querySelectorAll('img.xss-probe').length,
            abbr_injected: fakeDoc.querySelectorAll('img.abbr-xss-probe').length,
            country_injected: fakeDoc.querySelectorAll('img.country-xss-probe').length
        };
JS
    is($print_probe->{name_injected}, 0, "Print export does not inject the location name as HTML");
    is($print_probe->{abbr_injected}, 0, "Print export does not inject the abbreviation as HTML");
    is($print_probe->{country_injected}, 0, "Print export does not inject the country name as HTML");

    # --- locations without coordinates must not become a marker at 0,0 ---
    my $store2 = $t->driver->execute_script(<<'JS');
        var result;
        jQuery.ajax({
            type: 'POST',
            url: '/ajax/location/store',
            async: false,
            data: {
                name: 'selenium hardening: no-coordinates probe',
                abbreviation: 'NOCOORD1',
                country_name: 'United States',
                country_code: 'USA',
                programs: 'test',
                type: 'Other',
                altitude: 5
                // no latitude/longitude: CXGN::Location only sets the column
                // when the value has length, so this stores [null, null]
            },
            success: function(r) { result = r; },
            error: function() { result = { error: 'ajax error' }; }
        });
        return result;
JS
    ok($store2 && !$store2->{error}, "stored a location without coordinates")
        or diag(explain($store2));
    $nocoord_id = $store2->{nd_geolocation_id} if $store2;

    $t->get_ok('/breeders/locations');
    sleep(5);

    my $markers_after_nocoord = $t->driver->execute_script(
        "return document.querySelectorAll('#location_map .leaflet-marker-icon').length;"
    );
    is($markers_after_nocoord, $markers_after_probe,
        "a location without coordinates adds no marker to the map (no pin at 0,0)");

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

    # --- demo geocoder provider removed (source check; see header comment) ---
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

    # best-effort cleanup: this test's locations should not linger in the
    # fixture DB for the rest of the t/selenium2/breeders run
    for my $id (grep { defined } ($probe_id, $nocoord_id)) {
        $t->driver->execute_script(<<"JS");
            jQuery.ajax({ type: 'POST', url: '/ajax/location/delete/$id', async: false });
JS
    }
});

$t->driver->quit();
done_testing();
