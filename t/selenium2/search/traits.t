use strict;
use warnings;
use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;

my $d = SGN::Test::WWW::WebDriver->new();

# Helper to set the checked state of an ontology database checkbox
sub set_checkbox_state {
    my ($driver_obj, $label_text, $should_be_checked) = @_;
    my $xpath = "//div[\@id='trait_search_ontology_select']//text()[contains(., '$label_text')]/preceding-sibling::input[1]";
    my $elem = $driver_obj->find_element($xpath, 'xpath');
    
    # Determine current checked state using is_selected() or the 'checked' attribute
    my $is_checked = $elem->is_selected() || ($elem->get_attribute('checked') ? 1 : 0);
    
    if ($should_be_checked && !$is_checked) {
        $elem->click();
    } elsif (!$should_be_checked && $is_checked) {
        $elem->click();
    }
}

# Helper function to run a structured trait search test
sub run_trait_search_test {
    my %args = @_;
    my $inputs = $args{inputs} || {};
    my $submit_btn_id = $args{submit_btn_id} || 'submit_trait_search';
    my $reset_btn_id = $args{reset_btn_id} || 'reset_trait_search';
    my $assertions = $args{assertions} || [];

    if ($args{reset_first}) {
        $d->click_ok($reset_btn_id, "id", "Click reset button");
    }

    if ($args{checkboxes}) {
        while (my ($label_text, $state) = each %{$args{checkboxes}}) {
            set_checkbox_state($d, $label_text, $state);
        }
    }

    while (my ($id, $val) = each %$inputs) {
        $d->clear_ok($id, "id", "Clear input '$id'");
        $d->send_keys_ok($id, "id", $val, "Input '$val' in $id");
    }

    $d->click_ok($submit_btn_id, "id", "Submit search");
    $d->wait_for_network_idle();

    my $source = $d->driver()->get_page_source();
    foreach my $assertion (@$assertions) {
        my $pattern = $assertion->{pattern};
        my $expected = $assertion->{expected};
        my $desc = $assertion->{desc};
        if ($expected) {
            ok($source =~ /$pattern/i, $desc);
        } else {
            ok($source !~ /$pattern/i, $desc);
        }
    }

    # Refresh page and verify search persistence
    $d->get_ok($d->driver->get_current_url(), "Refresh page to verify search state persistence");
    $d->wait_for_network_idle();

    my $source_after = $d->driver()->get_page_source();
    foreach my $assertion (@$assertions) {
        my $pattern = $assertion->{pattern};
        my $expected = $assertion->{expected};
        my $desc = $assertion->{desc} . " (after refresh)";
        if ($expected) {
            ok($source_after =~ /$pattern/i, $desc);
        } else {
            ok($source_after !~ /$pattern/i, $desc);
        }
    }
}

# Load the trait search page
$d->get_ok('/search/traits');
$d->wait_for_network_idle();

# Search by Trait Name
run_trait_search_test(
    inputs     => { 'trait_search_name' => 'fresh root weight' },
    assertions  => [
        { pattern => qr/fresh root weight/, expected => 1, desc => "Search results contain 'fresh root weight'" },
        { pattern => qr/CO_334:0000012/, expected => 1, desc => "Search results contain DBxref CO_334:0000012" },
        { pattern => qr/COMP:0000013/, expected => 0, desc => "Search results do not contain unrelated 'COMP:0000013'" }
    ]
);

# Test Reset button
$d->click_ok("reset_trait_search", "id", "Click reset button");
$d->wait_for_network_idle();

my $name_val = $d->find_element("trait_search_name", "id")->get_attribute('value');
is($name_val, '', "Trait Name input is empty after reset");

# Search by Trait ID (CO_334:0000092)
run_trait_search_test(
    reset_first => 1,
    inputs      => { 'trait_search_id' => '0000092' },
    assertions  => [
        { pattern => qr/dry matter content percentage/, expected => 1, desc => "Search results contain 'dry matter content percentage'" },
        { pattern => qr/fresh root weight/, expected => 0, desc => "Search results do not contain 'fresh root weight'" }
    ]
);

# Search by Definition (3-phosphoglyceric acid)
run_trait_search_test(
    reset_first => 1,
    inputs      => { 'trait_search_definition' => 'mineral salts' },
    assertions  => [
        { pattern => qr/ash content in percentage/, expected => 1, desc => "Search results contain trait match 'ash content in percentage' from definition search" }
    ]
);

# Search with multiple fields (Name + ID)
run_trait_search_test(
    reset_first => 1,
    inputs      => { 'trait_search_name' => 'amylose', 'trait_search_id' => '000012' },
    assertions  => [
        { pattern => qr/amylose amylopectin root content ratio/, expected => 1, desc => "Search with Name + ID matches 'amylose amylopectin root content ratio'" },
        { pattern => qr/amylose content in ug\/g percentage/, expected => 0, desc => "Search with Name + ID does not match other 'amylose' trait outside ID filter" }
    ]
);

# Search with conflicting fields (yielding empty results)
run_trait_search_test(
    reset_first => 1,
    inputs      => { 'trait_search_name' => 'fresh root weight', 'trait_search_id' => '0000121' },
    assertions  => [
        { pattern => qr/fresh root weight/, expected => 0, desc => "Conflicting search does not show 'fresh root weight'" },
        { pattern => qr/amylopectin content ug\/g in percentage/, expected => 0, desc => "Conflicting search does not show 'CO_334:0000121' because of name filter" },
        { pattern => qr/No data available in table/i, expected => 1, desc => "Conflicting search returns 'No data available in table' message" }
    ]
);

# Search by partial ID prefix
run_trait_search_test(
    reset_first => 1,
    inputs      => { 'trait_search_id' => '000006' },
    assertions  => [
        { pattern => qr/anther color/, expected => 1, desc => "Search by partial ID matches 'anther color' (CO_334:0000061)" },
        { pattern => qr/ascorbic acid in root percentage/, expected => 1, desc => "Search by partial ID matches 'ascorbic acid in root percentage' (CO_334:0000065)" },
        { pattern => qr/ash content in percentage/, expected => 1, desc => "Search by partial ID matches 'ash content in percentage' (CO_334:0000066)" }
    ]
);

# Search with partial definition term
run_trait_search_test(
    reset_first => 1,
    inputs      => { 'trait_search_definition' => 'percentage' },
    assertions  => [
        { pattern => qr/amylose content in ug\/g percentage/, expected => 1, desc => "Search by definition term matches 'amylose content in ug/g percentage'" },
        { pattern => qr/amylopectin content ug\/g in percentage/, expected => 1, desc => "Search by definition term matches 'amylopectin content ug/g in percentage'" }
    ]
);

# Select only 'COMP'
run_trait_search_test(
    reset_first => 1,
    checkboxes  => { 'COMP' => 1, 'CO_334' => 0 },
    assertions  => [
        { pattern => qr/Showing \d+ to \d+ of 12 entries/i, expected => 1, desc => "COMP ontology filter shows 12 entries" }
    ]
);

# Select only 'CO_334'
run_trait_search_test(
    reset_first => 1,
    checkboxes  => { 'COMP' => 0, 'CO_334' => 1 },
    assertions  => [
        { pattern => qr/Showing \d+ to \d+ of 245 entries/i, expected => 1, desc => "CO_334 ontology filter shows 245 entries" }
    ]
);

# Select both 'COMP' and 'CO_334'
run_trait_search_test(
    reset_first => 1,
    checkboxes  => { 'COMP' => 1, 'CO_334' => 1 },
    assertions  => [
        { pattern => qr/Showing \d+ to \d+ of 257 entries/i, expected => 1, desc => "Both COMP and CO_334 selected shows 257 entries" }
    ]
);

# Search for 'ADP' with only 'COMP' selected
run_trait_search_test(
    reset_first => 1,
    inputs      => { 'trait_search_name' => 'ADP' },
    checkboxes  => { 'COMP' => 1, 'CO_334' => 0 },
    assertions  => [
        { pattern => qr/Showing \d+ to \d+ of 8 entries/i, expected => 1, desc => "Combined search for 'ADP' with COMP-only shows 8 entries" },
        { pattern => qr/cass sink leaf\|ADP\|ug\/g/i, expected => 1, desc => "Found 'cass sink leaf|ADP|ug/g'" }
    ]
);

# Search for 'acid' with only 'CO_334' selected
run_trait_search_test(
    reset_first => 1,
    inputs      => { 'trait_search_name' => 'acid' },
    checkboxes  => { 'COMP' => 0, 'CO_334' => 1 },
    assertions  => [
        { pattern => qr/Showing \d+ to \d+ of 2 entries/i, expected => 1, desc => "Combined search for 'acid' with CO_334-only shows 2 entries" },
        { pattern => qr/abscisic acid content of leaf/i, expected => 1, desc => "Found 'abscisic acid content of leaf'" },
        { pattern => qr/3-phosphoglyceric acid/i, expected => 0, desc => "Did NOT find '3-phosphoglyceric acid' because COMP is unchecked" }
    ]
);

# Search for 'acid' with only 'COMP' selected
run_trait_search_test(
    reset_first => 1,
    inputs      => { 'trait_search_name' => 'acid' },
    checkboxes  => { 'COMP' => 1, 'CO_334' => 0 },
    assertions  => [
        { pattern => qr/Showing \d+ to \d+ of 4 entries/i, expected => 1, desc => "Combined search for 'acid' with COMP-only shows 4 entries" },
        { pattern => qr/3-phosphoglyceric acid/i, expected => 1, desc => "Found '3-phosphoglyceric acid'" },
        { pattern => qr/abscisic acid content of leaf/i, expected => 0, desc => "Did NOT find 'abscisic acid' because CO_334 is unchecked" }
    ]
);

# Search for 'acid' with both selected
run_trait_search_test(
    reset_first => 1,
    inputs      => { 'trait_search_name' => 'acid' },
    checkboxes  => { 'COMP' => 1, 'CO_334' => 1 },
    assertions  => [
        { pattern => qr/Showing \d+ to \d+ of 6 entries/i, expected => 1, desc => "Combined search for 'acid' with both selected shows 6 entries" },
        { pattern => qr/3-phosphoglyceric acid/i, expected => 1, desc => "Found '3-phosphoglyceric acid'" },
        { pattern => qr/abscisic acid content of leaf/i, expected => 1, desc => "Found 'abscisic acid'" }
    ]
);

# Clear, search for 'fresh root weight' again, and navigate to details page
$d->click_ok("reset_trait_search", "id", "Reset search");

$d->clear_ok("trait_search_name", "id", "Clear input trait_search_name");
$d->send_keys_ok("trait_search_name", "id", "fresh root weight", "Input 'fresh root weight' for details page test");
$d->click_ok("submit_trait_search", "id", "Submit search");
$d->wait_for_network_idle();

$d->click_ok('//a[@href="/cvterm/70666/view"]', 'xpath', "Click details link for 'fresh root weight'");
$d->wait_for_network_idle();

my $detail_source = $d->driver()->get_page_source();
ok($detail_source =~ /fresh root weight/i, "Details page shows correct trait title");

$d->driver->quit();
done_testing();
