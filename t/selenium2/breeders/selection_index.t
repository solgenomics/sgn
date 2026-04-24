use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;
use Selenium::Remote::WDKeys 'KEYS';

my $t = SGN::Test::WWW::WebDriver->new();

my $formula_name = 'test_sin_' . int(rand(9000) + 1000);

$t->while_logged_in_as("submitter", sub {
    sleep(1);

    $t->get_ok('/selection/index');
    sleep(3);

    $t->find_element_ok('selection_index_workflow', 'id', 'workflow container rendered');
    $t->find_element_ok('sin_workflow_create', 'id', '"Create" radio button present');
    $t->find_element_ok('sin_workflow_load', 'id', '"Load" radio button present');
    $t->find_element_ok('trial_dual_wrapper', 'id', 'trial dual-list wrapper present');
    $t->find_element_ok('selection_index_error_dialog', 'id', 'error dialog present in DOM');
    $t->find_element_ok('sin_save_choice_modal', 'id', 'save-choice modal present in DOM');

    my $create_radio = $t->find_element_ok(
        'sin_workflow_create',
        'id',
        '"Create" radio is the default selection'
    );
    ok($create_radio->get_attribute('checked'), '"Create" radio is checked by default');

    $t->find_element_ok(
        '//button[@onclick="chooseActionNext(this);"]',
        'xpath',
        'Step 1 Next button'
    )->click();
    sleep(6);

    $t->find_element_ok('trial_search_input', 'id', 'trial search input present')
        ->send_keys('Kasese solgs trial');
    sleep(2);

    $t->find_element_ok(
        '//*[@id="trial_available_list"]/div[contains(.,"Kasese solgs trial")]/button[contains(@class,"trial-add-btn")]',
        'xpath',
        '"Kasese solgs trial" add-button in available list'
    )->click();
    sleep(3);

    my $selected_html = $t->find_element_ok(
        'trial_selected_list',
        'id',
        'selected-trials container present'
    )->get_attribute('innerHTML');

    ok(
        $selected_html =~ /Kasese solgs trial|165|trial-remove-btn/i,
        '"Kasese solgs trial" appears in the selected-trials list or selected trial entry exists'
    );

    $t->find_element_ok('choose_source_next', 'id', '"Next" button in source step')->click();
    sleep(6);

    $t->find_element_ok('trait_list', 'id', 'trait_list select present')->click();
    sleep(1);

    my $first_trait_opt = $t->find_element_ok(
        '//select[@id="trait_list"]/option[@value != "" and not(@id="select_message")][1]',
        'xpath',
        'first real trait option in dropdown'
    );

    my $trait_display_name = $first_trait_opt->get_text();
    $first_trait_opt->click();
    sleep(1);

    my $trait_html = $t->find_element_ok(
        'trait_table',
        'id',
        'trait_table tbody present'
    )->get_attribute('innerHTML');

    ok($trait_html =~ /\w/, 'selecting a trait adds a row to the trait table');
    ok(
        $trait_html =~ /\Q$trait_display_name\E/i,
        "trait table row shows the selected trait: $trait_display_name"
    );

    my $coeff_input = $t->find_element_ok(
        '//tbody[@id="trait_table"]//tr[1]//input[@type="text"]',
        'xpath',
        'coefficient input in the new trait row'
    );

    $coeff_input->clear();
    $coeff_input->send_keys('2');
    $coeff_input->send_keys(KEYS->{'tab'});
    sleep(1);

    $t->find_element_ok('traits_coeffs_next', 'id', '"Next" button in traits step')->click();
    sleep(1);

    my $formula_text = $t->find_element_ok(
        'ranking_formula',
        'id',
        'ranking_formula element in review step'
    )->get_text();

    ok(
        $formula_text =~ /SIN\s*=|2\s*\*/i,
        'formula element shows SIN equation with coefficient'
    );

    my $calc_btn = $t->find_element_ok(
        'calculate_rankings_button',
        'id',
        'Calculate Rankings button present'
    );

    ok(
        $calc_btn->get_attribute('class') !~ /\bdisabled\b/,
        'Calculate Rankings button is enabled after trait added'
    );

    $calc_btn->click();
    sleep(8);

    $t->find_element_ok(
        'selection_index_results_panel',
        'id',
        'results panel element present'
    );

    $t->find_element_ok(
        '//table[@id="weighted_values_table"]//tbody/tr',
        'xpath',
        'rankings table has at least one result row'
    );

    $t->find_element_ok(
        '//table[@id="raw_avgs_table"]//tbody/tr',
        'xpath',
        'raw averages table has at least one result row'
    );

    $t->find_element_ok('top_number', 'id', '"Save by number" select rendered in results');
    $t->find_element_ok('top_percent', 'id', '"Save by percent" select rendered in results');

    my $sin_name_input = $t->find_element_ok(
        'save_sin_name',
        'id',
        'formula name input present'
    );

    $sin_name_input->clear();
    $sin_name_input->send_keys($formula_name);
    sleep(1);

    my $save_sin_btn = $t->find_element_ok('save_sin', 'id', '"Save" button present');

    ok(
        $save_sin_btn->get_attribute('class') !~ /\bdisabled\b/,
        '"Save" button is enabled after formula built'
    );

    $save_sin_btn->click();
    sleep(1);

    ok(
        $t->driver->get_alert_text() =~ /Saved SIN formula/i,
        'alert confirms formula was saved successfully'
    );

    $t->driver()->accept_alert();
    sleep(1);

    $t->get_ok('/selection/index');
    sleep(3);

    $t->find_element_ok('sin_workflow_load', 'id', '"Load" radio on reload')->click();
    sleep(1);

    $t->find_element_ok(
        '//button[@onclick="chooseActionNext(this);"]',
        'xpath',
        'Step 1 Next button (Load mode)'
    )->click();
    sleep(2);

    $t->find_element_ok(
        "//select[\@id='sin_list_list_select']/option[contains(text(),'$formula_name')]",
        'xpath',
        "saved formula '$formula_name' appears in the formula selector"
    )->click();
    sleep(2);

    $t->find_element_ok(
        'choose_source_next',
        'id',
        '"Next" button in source step (Load mode)'
    )->click();
    sleep(5);

    my $loaded_html = $t->find_element_ok(
        'trait_table',
        'id',
        'trait_table after loading saved formula'
    )->get_attribute('innerHTML');

    ok($loaded_html =~ /\w/, 'trait table is populated from the loaded formula');
    ok(
        $loaded_html =~ /\Q$trait_display_name\E/i,
        "loaded formula contains the expected trait: $trait_display_name"
    );

    my $loaded_formula = $t->find_element_ok(
        'ranking_formula',
        'id',
        'formula text present after loading saved formula'
    )->get_text();

    diag("Loaded formula text: $loaded_formula");

    my $loaded_coeff = $t->find_element_ok(
        '//tbody[@id="trait_table"]//tr[1]//input[@type="text"]',
        'xpath',
        'coefficient input after loading'
    )->get_attribute('value');

    ok(
        ($loaded_formula && $loaded_formula =~ /SIN\s*=/i)
            || (defined $loaded_coeff && $loaded_coeff =~ /2/),
        'loaded formula OR coefficient restored correctly'
    );
});

eval {
    $t->driver()->close();
};

done_testing();