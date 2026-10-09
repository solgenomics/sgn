use strict;
use warnings;

use lib 't/lib';

use Test::More;

use SGN::Test::Fixture;
use SGN::Test::WWW::WebDriver;
use Selenium::Remote::WDKeys 'KEYS';
use Selenium::Waiter qw(wait_until);

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();

my $stock_id = 38879;
my $stock_url = "/stock/$stock_id/view";

# The edit form test changes the stock's name, type, organism and description.
# clean_up_db() only removes added rows, so save the original values to restore them.
my $stock_row = $f->bcs_schema->resultset('Stock::Stock')->find({ stock_id => $stock_id });
my %original_stock = map { $_ => $stock_row->get_column($_) } qw(name uniquename type_id organism_id description);

sub restore_stock {
    $f->bcs_schema->resultset('Stock::Stock')->find({ stock_id => $stock_id })->update(\%original_stock);
}

# Poll until $cond returns a true value, or return '' after $timeout seconds
sub wait_for {
    my $cond = shift;
    my $timeout = shift || 30;
    return wait_until { $cond->() } timeout => $timeout, interval => 1;
}

# Wait for an element to be displayed, then return it
sub wait_for_element_ok {
    my ($locator, $method, $test_name) = @_;
    my $element = wait_for(sub {
        my $e = $t->find_element($locator, $method);
        return $e->is_displayed() ? $e : undef;
    });
    ok($element, $test_name);
    die "Element '$locator' not found\n" if !$element;
    return $element;
}

# Wait for an alert, check its text and accept it
sub accept_alert_like {
    my ($regex, $test_name) = @_;
    my $text = wait_for(sub { $t->driver->get_alert_text() });
    like($text, $regex, $test_name);
    $t->driver->accept_alert() if $text;
    return $text;
}

sub clear_and_type {
    my ($element, $text) = @_;
    $element->send_keys(KEYS->{'control'}, 'a');
    $element->send_keys(KEYS->{'backspace'});
    $element->send_keys($text);
}

sub body_text {
    return $t->find_element('body', 'tag_name')->get_text();
}

sub open_stock_page {
    $t->get_ok($stock_url);
    wait_for_element_ok('//div[@id="stock_details_buttons"]/a[contains(text(), "Edit")]', 'xpath', 'stock page loaded');
}

sub open_pedigree_section {
    my $pedigree_section = wait_for_element_ok('stock_pedigree_section_onswitch', 'id', 'find pedigree section');
    $t->driver->execute_script("arguments[0].scrollIntoView(true);window.scrollBy(0,-100)", $pedigree_section);
    $pedigree_section->click();
    wait_for_element_ok('add_parent_link', 'id', 'pedigree section is open');
}

# Fill in and submit the add parent dialog, opening it first if needed
sub add_parent {
    my ($parent_name, $parent_type, $cross_type, $expected_alert, $test_name) = @_;
    my $dialog_open = eval { $t->find_element('stock_autocomplete', 'id')->is_displayed() };
    wait_for_element_ok('add_parent_link', 'id', 'find add parent link')->click() if !$dialog_open;
    my $stock_name = wait_for_element_ok('stock_autocomplete', 'id', 'find add parent input');
    $t->find_element_ok($parent_type, 'id', "select $parent_type parent type")->click();
    if ($cross_type) {
        wait_for_element_ok("//select[\@id='add_parent_cross_type']/option[\@value='$cross_type']", 'xpath', "select $cross_type cross type")->click();
    }
    clear_and_type($stock_name, $parent_name);
    $t->find_element_ok('add_parent_submit', 'id', 'submit add parent')->click();
    accept_alert_like($expected_alert, $test_name);
}

sub remove_first_parent {
    wait_for_element_ok('remove_parent_link', 'id', 'find remove parent button')->click();
    wait_for_element_ok('//div[@id="remove_parent_list"]/a[1]', 'xpath', 'find delete parent link')->click();
    accept_alert_like(qr/Are you sure you want to remove this parent/, 'confirm remove parent');
    accept_alert_like(qr/The parent has been removed/, 'parent removed');
    # remove_parents() reloads the stock page on success
    wait_for_element_ok('stock_pedigree_section_onswitch', 'id', 'stock page reloaded after removing parent');
}

my $ok = eval { $t->while_logged_in_as("submitter", sub {

    # Test edit / cancel button for stock / accession
    open_stock_page();

    $t->find_element_ok('//div[@id="stock_details_buttons"]/a[contains(text(), "Edit")]', "xpath", "find edit link")->click();
    wait_for_element_ok('//div[@id="stock_details_buttons"]/a[contains(text(), "Cancel")]', "xpath", "find cancel link")->click();
    wait_for_element_ok('//div[@id="stock_details_buttons"]/a[contains(text(), "Edit")]', "xpath", "edit link shown after cancel")->click();

    # Test reset button restores the original form values
    my $species_name_input = wait_for_element_ok("species_name", "id", "find stock organism input");
    my $original_species = $species_name_input->get_attribute('value');
    clear_and_type($species_name_input, 'Manihot esculenta');
    is($species_name_input->get_attribute('value'), 'Manihot esculenta', 'organism input changed');

    $t->find_element_ok("stockForm_reset_button", "id", "find reset edit button")->click();
    # reset re-renders the form, so wait for a fresh input holding the original value
    ok(wait_for(sub { $t->find_element("species_name", "id")->get_attribute('value') eq $original_species }),
       "reset restores organism to '$original_species'");

    # Test edit form for stock / accession
    clear_and_type($t->find_element_ok("species_name", "id", "find stock organism input"), 'Manihot esculenta');
    $t->find_element_ok('//select[@name="type_id"]/option[text()="tissue_sample"]', "xpath", "select stock type as 'tissue_sample'")->click();
    clear_and_type($t->find_element_ok("uniquename", "name", "find stock uniquename input"), 'UG120001_Testedit');
    clear_and_type($t->find_element_ok("description", "name", "find stock description input"), 'Test description edit.');

    $t->find_element_ok("stockForm_submit_button", "id", "find submit edit button")->click();
    # store() only alerts on error
    my $store_error = wait_for(sub { $t->driver->get_alert_text() }, 5);
    ok(!$store_error, 'stock edit stored without error') or diag($store_error);
    $t->driver->accept_alert() if $store_error;

    my $edited = wait_for(sub {
        my $s = $f->bcs_schema->resultset('Stock::Stock')->find({ stock_id => $stock_id });
        return $s->uniquename eq 'UG120001_Testedit' ? $s : undef;
    });
    ok($edited, 'stock uniquename updated in database');
    is($edited && $edited->description, 'Test description edit.', 'stock description updated in database');
    is($edited && $edited->type->name, 'tissue_sample', 'stock type updated in database');

    open_stock_page();
    my $body = body_text();
    like($body, qr/UG120001_Testedit/, 'stock uniquename was updated');
    like($body, qr/tissue_sample/i, 'stock type was updated');
    like($body, qr/Test description edit\./, 'stock description was updated');

    restore_stock();
    open_stock_page();
    like(body_text(), qr/\Q$original_stock{uniquename}\E/, 'stock restored to original values');

    # Test adding and removing synonyms from stock additional info section
    wait_for_element_ok("stock_add_synonym", "id", "find add synonym button")->click();
    wait_for_element_ok('//select[@id="synonyms_select"]/option[@title="stock_synonym"]', "xpath", "select 'stock_synonym' as value")->click();
    $t->find_element_ok("synonyms_prop", "id", "find add synonym input")->send_keys('test_synonym');
    $t->find_element_ok("synonyms_addProp_submit", "id", "add synonym submit")->click();

    accept_alert_like(qr/Successfully added property: test_synonym/, 'synonym added');
    ok(wait_for(sub { $t->find_element('synonyms_content', 'id')->get_text() =~ /test_synonym/ }), 'synonym shown in additional info');

    my $delete_synonym_xpath = q{//div[@id="synonyms_content"]/a[contains(@href, "'test_synonym'")]};
    wait_for_element_ok($delete_synonym_xpath, "xpath", "find delete synonym link")->click();
    accept_alert_like(qr/Delete stockprop test_synonym/, 'confirm delete synonym');
    accept_alert_like(qr/The element was removed from the database/, 'synonym deleted');
    ok(wait_for(sub { $t->find_element('synonyms_content', 'id')->get_text() !~ /test_synonym/ }), 'synonym no longer shown');

    # Test adding parents from pedigree info section
    open_stock_page();
    open_pedigree_section();

    add_parent('test_wrong_stock_name', 'female', 'biparental', qr/Stock with uniquename test_wrong_stock_name was not found/, 'unknown parent name is rejected');
    # the dialog stays open after an error, so correct the name and resubmit
    add_parent('test_accession1', 'female', 'biparental', qr/The parent has been added/, 'female parent test_accession1 added');

    open_stock_page();
    open_pedigree_section();
    add_parent('test_accession2', 'male', undef, qr/The parent has been added/, 'male parent test_accession2 added');

    # Test if parents were added to database and now in a view
    open_stock_page();
    open_pedigree_section();

    my $pedigree_view = wait_for_element_ok('//div[@id="pdgv-wrap"]', 'xpath', 'find a content of pedigree view');
    ok(wait_for(sub { $pedigree_view->get_attribute('innerHTML') =~ /test_accession2/ }), 'pedigree view rendered');
    my $pedigree_html = $pedigree_view->get_attribute('innerHTML');
    like($pedigree_html, qr/test_accession1/, "Verify if test_accession1 on pedigree panel");
    like($pedigree_html, qr/test_accession2/, "Verify if test_accession2 on pedigree panel");

    my $pedigree_string = $t->find_element_ok("pedigree_string", "id", "verify pedigree string")->get_text();
    like($pedigree_string, qr/test_accession1\/test_accession2/, "Verify if pedigree string contain 'test_accession1/test_accession2'");

    # Test removing parents from pedigree info section (section is already open)
    remove_first_parent();
    open_pedigree_section();
    remove_first_parent();

    open_stock_page();
    open_pedigree_section();
    wait_for_element_ok('remove_parent_link', 'id', 'find remove parent button')->click();
    ok(wait_for(sub { $t->find_element('remove_parent_list', 'id')->get_text() !~ /loading/ }), 'parent list loaded');
    my $remaining_parents = $t->find_element('remove_parent_list', 'id')->get_text();
    unlike($remaining_parents, qr/test_accession1/, 'test_accession1 removed from parents');
    unlike($remaining_parents, qr/test_accession2/, 'test_accession2 removed from parents');
}); 1 };
fail("stock detail test died: $@") if !$ok;

# Always restore the stock and clean up, even if the test died part way
restore_stock();
$f->clean_up_db();
eval { $t->driver->close(); };
done_testing();
