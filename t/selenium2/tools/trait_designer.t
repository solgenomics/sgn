use strict;
use warnings;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;
use Selenium::Waiter qw(wait_until);

my $f = SGN::Test::Fixture->new();

my $t = SGN::Test::WWW::WebDriver->new();

# Poll until $cond returns a true value, or return '' after $timeout seconds
sub wait_for {
    my $cond = shift;
    my $timeout = shift || 30;
    return wait_until { $cond->() } timeout => $timeout, interval => 1;
}

# True if the element is rendered, including when it is inside a hidden parent
sub is_visible {
    my $element = shift;
    return $t->driver->execute_script(
        "var e = arguments[0]; return !!(e.offsetWidth || e.offsetHeight || e.getClientRects().length);", $element);
}

# Wait for an alert, check its text and accept it
sub accept_alert_like {
    my ($regex, $test_name) = @_;
    my $text = wait_for(sub { $t->driver->get_alert_text() });
    like($text, $regex, $test_name);
    $t->driver->accept_alert() if $text;
    return $text;
}

sub load_designer {
    $t->get_ok('/traits/design');
    wait_for_designer();
}

sub wait_for_designer {
    ok(wait_for(sub { my $e = $t->find_element('new_trait_name', 'id'); $e && is_visible($e) }), 'trait designer loaded');
}

sub class_of {
    my $xpath = shift;
    return $t->driver->execute_script("return arguments[0].className;", $t->find_element($xpath, 'xpath'));
}

# Replace a field's text, retrying until it holds the text: keys typed while the
# freshly reloaded page is still starting up can be lost
sub type_into {
    my ($id, $text, $test_name) = @_;
    my $typed = wait_for(sub {
        my $field = $t->find_element($id, 'id');
        $field->clear();
        $field->send_keys($text);
        return $field->get_value() eq $text;
    }, 15);
    ok($typed, $test_name);
}

# Click a term type pill until it is the active one (a click before the page scripts are ready is lost)
sub select_pill {
    my ($index, $test_name) = @_;
    my $xpath = qq{//ul[\@id="new_trait_term_type_tabs"]/li[$index]};
    ok(wait_for(sub {
        $t->find_element("$xpath/a", 'xpath')->click();
        return class_of($xpath) =~ m/active/;
    }, 10), $test_name);
}

# Submit the form, check the alert, then wait for the page reload the designer does after a term is stored
sub submit_and_reload {
    my ($regex, $test_name) = @_;
    $t->driver->execute_script("window.designer_test_marker = 1;");
    $t->find_element_ok('new_trait_submit_btn', 'id', "submit: $test_name")->click();
    accept_alert_like($regex, $test_name);
    ok(wait_for(sub {
        my $reloaded = $t->driver->execute_script("return document.readyState === 'complete' && window.designer_test_marker === undefined ? 1 : 0;");
        return defined($reloaded) && $reloaded == 1;
    }), "page reloaded after: $test_name");
    wait_for_designer();
}

sub fill_name_and_definition {
    my ($name, $definition) = @_;
    type_into('new_trait_name', $name, "fill trait name field for '$name'");
    type_into('new_trait_definition', $definition, "fill trait definition field for '$name'");
    $t->find_element_ok('new_trait_ontology_select', 'id', 'open trait ontology select')->click();
    $t->driver->find_element('//select[@id="new_trait_ontology_select"]/option[@value="CO_334"]', 'xpath')->click();
}

sub add_synonym {
    my $synonym = shift;
    $t->find_element_ok('new_trait_synonym', 'id', "type synonym '$synonym'")->send_keys($synonym);
    $t->find_element_ok('new_trait_add_synonym_btn', 'id', "add synonym '$synonym'")->click();
}

sub synonyms_of {
    my $name = shift;
    my $cvterm = $f->bcs_schema->resultset('Cv::Cvterm')->find({ name => $name });
    return if !$cvterm;
    return [ sort map { $_->synonym() } $cvterm->cvtermsynonyms()->all() ];
}

$t->while_logged_in_as("curator", sub {

    load_designer();

    # trait term pill is selected by default, with the format select and synonyms shown
    like(class_of('//ul[@id="new_trait_term_type_tabs"]/li[1]'), qr/active/, 'new trait term pill is active by default');
    ok(is_visible($t->find_element('new_trait_format_select', 'id')), 'trait format select is shown for a trait term');
    ok(is_visible($t->find_element('new_trait_synonyms_container', 'id')), 'synonyms section is shown for a trait term');

    # grouping term pill hides the format select and synonyms
    select_pill(2, 'select new ontology (grouping) term pill');
    ok(wait_for(sub { !is_visible($t->find_element('new_trait_format_select', 'id')) }, 5), 'trait format select is hidden for a grouping term');
    ok(!is_visible($t->find_element('new_trait_synonyms_container', 'id')), 'synonyms section is hidden for a grouping term');
    ok(!is_visible($t->find_element('new_trait_repeat_select_container', 'id')), 'measurement type is hidden for a grouping term');
    ok(is_visible($t->find_element('//ul[@id="new_trait_term_type_tabs"]/li[1]/a', 'xpath')), 'new trait term pill is still shown after switching pills');

    # store a grouping term
    fill_name_and_definition("test trait group", "A fake grouping term to see if the trait designer can make new ontology terms during selenium tests.");
    submit_and_reload(qr/New trait saved/, 'new grouping term was saved');
    my $group = $f->bcs_schema->resultset('Cv::Cvterm')->find({ name => "test trait group" });
    ok($group, 'grouping term is in the database');
    my $group_format = $group ? $group->search_related('cvtermprops', { 'type.name' => 'trait_format' }, { join => 'type' })->first() : undef;
    is($group_format ? $group_format->value() : undef, 'ontology', 'grouping term was stored with the ontology format');

    # store a categorical trait with synonyms
    select_pill(1, 'select new trait term pill');
    ok(wait_for(sub { is_visible($t->find_element('new_trait_format_select', 'id')) }, 5), 'trait format select is shown again');

    fill_name_and_definition("test trait", "A fake test trait to see if the trait designer can make new traits during selenium tests.");

    $t->find_element_ok('new_trait_format_select', 'id', 'select categorical trait format')->click();
    $t->driver->find_element('//select[@id="new_trait_format_select"]/option[@value="categorical"]', 'xpath')->click();
    ok(wait_for(sub { is_visible($t->find_element('new_trait_add_categories_container', 'id')) }, 5), 'categories section is shown for a categorical trait');

    $t->find_element_ok('new_trait_add_category', 'id', 'name first category')->send_keys("control");
    $t->find_element_ok('new_trait_category_ordinal', 'id', 'assign first category as 0')->send_keys("0");
    $t->find_element_ok('new_trait_add_category_btn', 'id', 'create first category')->click();

    $t->find_element_ok('new_trait_add_category', 'id', 'name second category')->send_keys("high");
    $t->find_element_ok('new_trait_category_ordinal', 'id', 'assign second category as 1')->send_keys("1");
    $t->find_element_ok('new_trait_add_category_btn', 'id', 'create second category')->click();

    $t->find_element_ok('new_trait_add_category', 'id', 'name bad category')->send_keys("testtesttest");
    $t->find_element_ok('new_trait_category_ordinal', 'id', 'assign bad category as 33')->send_keys("33");
    $t->find_element_ok('new_trait_add_category_btn', 'id', 'create bad category')->click();
    $t->find_element_ok('new_trait_remove_category_btn', 'id', 'delete bad category')->click();

    add_synonym("test trait synonym one");
    add_synonym("test trait synonym two");
    add_synonym("test trait bad synonym");
    $t->find_element_ok('new_trait_remove_synonym_btn', 'id', 'delete bad synonym')->click();
    is(scalar(@{$t->driver->find_elements('//ul[@id="new_trait_synonyms"]/li', 'xpath')}), 2, 'two synonyms are listed');

    submit_and_reload(qr/New trait saved/, 'new trait with synonyms was saved');
    is_deeply(synonyms_of("test trait"), ["test trait synonym one", "test trait synonym two"], 'new trait has its synonyms');

    # a second trait reusing a synonym (in a different case) is still stored, but without synonyms
    fill_name_and_definition("test trait reused synonym", "A second fake test trait that tries to reuse a synonym that is already in the database.");
    add_synonym("TEST TRAIT SYNONYM ONE");
    add_synonym("test trait synonym three");

    submit_and_reload(qr/was saved, but its synonyms could not be stored.*test trait synonym one.*already exist/is, 'reused synonym is reported as an error');
    is_deeply(synonyms_of("test trait reused synonym"), [], 'trait with a reused synonym was stored without synonyms');
    is_deeply(synonyms_of("test trait"), ["test trait synonym one", "test trait synonym two"], 'first trait synonyms are unchanged');
});

$t->driver->close();
$f->clean_up_db();
done_testing();
