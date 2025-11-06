use strict;

use lib 't/lib';

use Test::More 'tests' => 126;

use SGN::Test::WWW::WebDriver;
use Selenium::Remote::WDKeys 'KEYS';
use SGN::Test::Fixture;

my $t = SGN::Test::WWW::WebDriver->new();
my $f = SGN::Test::Fixture->new();

$t->while_logged_in_as("submitter", sub {
    sleep(1);

    $t->get_ok('/breeders/search');
    sleep(2);

    # COLUMN 1 WIZARD SEARCH - test list select / search - select trials
    $t->find_element_ok('(//div[@class="panel-heading"]/select)[1]', 'xpath', 'find select column type in first column')->click();
    sleep(1);
    $t->find_element_ok('(//div[@class="panel-heading"]/select)[1]//option[@value="trials"]', 'xpath', 'find and select "trials" in first column')->click();
    sleep(1);
    my $search_column = $t->find_element_ok('(//div[contains(@class, "wizard-column")])[1]//textarea', 'xpath', 'find a search box');
    $search_column->send_keys('Kasese solgs trial');
    sleep(2);

    # COLUMN 1 WIZARD SEARCH - check if only "Kasese solgs trial" is in unselect panel field
    my $search_unselected = $t->find_element_ok(
        '(//div[@class="panel-body"])[1]//ul[contains(@class, "wizard-list-unselected")]',
        'xpath',
        'find a content of "unselected trials panel" to test searchbox in first column')->get_attribute('innerHTML');

    ok($search_unselected =~ /Kasese solgs trial/, "Verify if unselected panel after search contain: 'Kasese solgs trial'");
    ok($search_unselected !~ /CASS_6Genotypes_Sampling_2015/, "Verify if unselected panel after search NOT contain: 'CASS_6Genotypes_Sampling_2015'");
    ok($search_unselected !~ /trial2 NaCRRI/, "Verify if unselected panel after search NOT contain: 'trial2 NaCRRI'");

    # ADD A SECOND FILTER ITEM
    $search_column->send_keys(KEYS->{'return'});
    $search_column->send_keys('trial2 NaCRRI');
    sleep(2);

    # check if both "Kasese solgs trial" and "trial2 NaCRRI" are in the unselect panel field
    $search_unselected = $t->find_element_ok(
        '(//div[@class="panel-body"])[1]//ul[contains(@class, "wizard-list-unselected")]',
        'xpath',
        'find a content of "unselected trials panel" to test searchbox in first column')->get_attribute('innerHTML');

    ok($search_unselected =~ /Kasese solgs trial/, "Verify if unselected panel after search contain: 'Kasese solgs trial'");
    ok($search_unselected !~ /CASS_6Genotypes_Sampling_2015/, "Verify if unselected panel after search NOT contain: 'CASS_6Genotypes_Sampling_2015'");
    ok($search_unselected =~ /trial2 NaCRRI/, "Verify if unselected panel after search contain: 'trial2 NaCRRI'");

    sleep(1);
    $t->find_element_ok('(//div[@class="panel-body"])[1]//a[contains(text(), "Kasese solgs trial")]//preceding-sibling::button' , 'xpath', 'find and add "Kasese solgs trial" trial in first column with search filter active')->click();

    # COLUMN 2 WIZARD SEARCH - test list select / search - select trials
    $t->find_element_ok('(//div[@class="panel-heading"])[2]/select', 'xpath', 'find select column type in second column')->click();
    sleep(1);
    $t->find_element_ok('(//div[@class="panel-heading"])[2]/select//option[@value="traits"]', 'xpath', 'find and select "traits" in second column')->click();
    sleep(1);
    $t->find_element_ok('(//div[@class="panel-body"])[2]//a[contains(text(), "dry matter content percentage|CO_334:0000092")]//preceding-sibling::button' , 'xpath', 'find and add "dry matter content percentage|CO_334:0000092" trait in second column')->click();
    sleep(1);

    # COLUMN 1 AND 2 - test for all / any / default values / check if numbers off possible combinations are changing
    my $active_union_button = $t->find_element_ok('(//div[@class="panel-body"])[1]//div[contains(@class, "wizard-union-toggle")]/div[contains(@class, "wizard-union-toggle-btn-group")]/button[contains(@class, "active")]' , 'xpath', 'find active union button in first column');
    ok(lc($active_union_button->get_attribute('innerHTML')) eq "any", "default active union button for selection shall be ANY");

    my $button_count_all_second_column_xpath = '(//div[@class="panel-body"])[2]//div[@class="btn-group"]//span[contains(@class, "wizard-count-all")]';

    my $button_count_all_second_column = $t->find_element_ok($button_count_all_second_column_xpath , 'xpath', 'find count traits field pointer');
    ok($button_count_all_second_column->get_text() eq "3", "number of traits with 'ANY button' in second panel from 'Kasese solgs trial' should be 3");

    $t->find_element_ok('(//div[contains(@class, "wizard-column")])[1]//button[contains(@class, "wizard-search-options-clear")]' , 'xpath', 'clear search input in first column, for union test')->click();
    sleep(2);

    $t->find_element_ok('(//div[@class="panel-body"])[1]//a[contains(text(), "trial2 NaCRRI")]//preceding-sibling::button' , 'xpath', 'find and select "trial2 NaCRRI" in first column')->click();
    sleep(1);

    my $unselected_traits_second_column_xpath = '(//div[@class="panel-body"])[2]//ul[contains(@class, "wizard-list-unselected")]';

    my $unselected_traits_content = $t->find_element_ok($unselected_traits_second_column_xpath, 'xpath', 'find content of unselected list from second column')->get_attribute('innerHTML');
    ok($unselected_traits_content =~ /harvest index variable|CO_334:0000015/, 'find new trait for two trials and ANY union "harvest index variable|CO_334:0000015"');

    $button_count_all_second_column = $t->find_element_ok($button_count_all_second_column_xpath , 'xpath', 'find count traits field pointer');
    ok($button_count_all_second_column->get_text() eq "4", "number of traits with 'ANY button' in second panel from 'Kasese solgs trial' and 'trial2 NaCRRI' should be 4");

    my $all_union_button = $t->find_element_ok('(//div[@class="panel-body"])[1]//div[contains(@class, "wizard-union-toggle")]/div[contains(@class, "wizard-union-toggle-btn-group")]/button[contains(text(), "ALL")]' , 'xpath', 'find "ALL" button');
    my $any_union_button = $t->find_element_ok('(//div[@class="panel-body"])[1]//div[contains(@class, "wizard-union-toggle")]/div[contains(@class, "wizard-union-toggle-btn-group")]/button[contains(text(), "ANY")]' , 'xpath', 'find "ANY" button');

    $all_union_button->click();
    sleep(1);
    $button_count_all_second_column = $t->find_element_ok($button_count_all_second_column_xpath , 'xpath', 'find count traits field pointer');
    ok($button_count_all_second_column->get_text() eq "3", "ALL traits in second panel from 'Kasese solgs trial' and 'trial2 NaCRRI' should be 3");

    $unselected_traits_content = $t->find_element_ok($unselected_traits_second_column_xpath, 'xpath', 'find content of unselected list from second column"')->get_attribute('innerHTML');
    ok($unselected_traits_content !~ /harvest index variable|CO_334:0000015/, '"harvest index variable|CO_334:0000015" trait for two trials and ALL union cannot be displayed in unselected traits');

    $any_union_button->click();
    sleep(1);
    $button_count_all_second_column = $t->find_element_ok($button_count_all_second_column_xpath , 'xpath', 'find count traits field pointer');
    ok($button_count_all_second_column->get_text() eq "4", "ANY traits in second panel from 'Kasese solgs trial' and 'trial2 NaCRRI' should be 4");

    $unselected_traits_content = $t->find_element_ok($unselected_traits_second_column_xpath, 'xpath', 'find content of unselected list from second column"')->get_attribute('innerHTML');
    ok($unselected_traits_content =~ /harvest index variable|CO_334:0000015/, '"harvest index variable|CO_334:0000015" trait for two trials and ANY union shall be displayed in unselected traits');

    $t->find_element_ok('(//div[@class="panel-body"])[1]//ul[contains(@class, "wizard-list-selected wizard-list")]//a[contains(text(), "trial2 NaCRRI")]//preceding-sibling::button' , 'xpath', 'first select')->click();
    sleep(1);
    $unselected_traits_content = $t->find_element_ok($unselected_traits_second_column_xpath, 'xpath', 'find content of unselected list from second column"')->get_attribute('innerHTML');
    ok($unselected_traits_content !~ /harvest index variable|CO_334:0000015/, '"harvest index variable|CO_334:0000015" trait for one trial after "trial2 NaCRRI" removed should not be displayed in unselected traits');

    # COLUMN 3 WIZARD SEARCH - select years and save first dataset with 3 list
    $t->find_element_ok('(//div[@class="panel-heading"]/select)[3]', 'xpath', 'find select column type in third column')->click();
    sleep(1);
    $t->find_element_ok('(//div[@class="panel-heading"]/select)[3]//option[@value="years"]', 'xpath', 'find and select "years" in third column')->click();
    sleep(1);
    $t->find_element_ok('(//div[@class="panel-body"])[3]//a[contains(text(), "2014")]//preceding-sibling::button' , 'xpath', 'find and add "2014" year in third column')->click();
    sleep(1);

    my $dataset_name_input = $t->find_element_ok('input[placeholder="Create New Dataset"]', 'css', 'find dataset name input field');
    $dataset_name_input->send_keys(KEYS->{'control'}, 'a');
    $dataset_name_input->send_keys(KEYS->{'backspace'});
    sleep(1);

    my $dataset_name_1 = "another_dataset_3_columns";
    $dataset_name_input->send_keys($dataset_name_1);
    $t->find_element_ok('//input[@placeholder="Create New Dataset"]/parent::div//button[contains(text(), "Create")]', 'xpath', "find 'create' button and create dataset $dataset_name_1")->click;
    sleep(2);
    $t->driver()->accept_alert();
    sleep(1);


    # COLUMN 4 WIZARD SEARCH - select accessions and save second dataset
    my $type_column_4 = $t->find_element_ok('(//div[@class="panel-heading"]/select)[4]', 'xpath', 'find select column type in fourth column');
    $t->driver->execute_script( "arguments[0].scrollIntoView(true);window.scrollBy(0,-50);", $type_column_4);
    $type_column_4->click();
    sleep(1);
    $t->find_element_ok('(//div[@class="panel-heading"]/select)[4]//option[@value="accessions"]', 'xpath', 'find and select "accessions" in fourth column')->click();
    sleep(1);
    $t->find_element_ok('(//div[@class="panel-body"])[4]//a[contains(text(), "UG120001")]//preceding-sibling::button' , 'xpath', 'find and add "UG120001" year in fourth column')->click();
    sleep(1);

    $dataset_name_input = $t->find_element_ok('input[placeholder="Create New Dataset"]', 'css', 'find dataset name input field and clear content');
    $dataset_name_input->send_keys(KEYS->{'control'}, 'a');
    $dataset_name_input->send_keys(KEYS->{'backspace'});
    sleep(1);

    my $dataset_name_2 = "another_dataset_4_columns";
    $dataset_name_input->send_keys($dataset_name_2);
    $t->find_element_ok('//input[@placeholder="Create New Dataset"]/parent::div//button[contains(text(), "Create")]', 'xpath', "find 'create' button and create dataset $dataset_name_2")->click();
    sleep(1);
    ok($t->driver->get_alert_text() =~ m/Dataset another_dataset_4_columns created/i, 'Created dataset another_dataset_4_columns');
    sleep(1);
    $t->driver()->accept_alert();
    sleep(1);

    # SAVE A LIST FROM COLUMN 1
    my $first_list_name = "trials_list";
    $t->find_element_ok(
        '(//table[contains(@class, "wizard-save-to-list")])[1]//input[contains(@class, "wizard-create-list-name")]',
        'xpath',
        'find a "list name" for first column and fill a name')->click();

    $t->find_element_ok(
        '(//table[contains(@class, "wizard-save-to-list")])[1]//input[contains(@class, "wizard-create-list-name")]',
        'xpath',
        "fill '$first_list_name' as list name in first column")->send_keys($first_list_name);

    $t->find_element_ok(
        '(//table[contains(@class, "wizard-save-to-list")])[1]//button[contains(text(), "Create")]',
        'xpath',
        "find a 'create list' in first columns button and click")->click();
    sleep(1);
    ok($t->driver->get_alert_text() =~ m/1 items added to list trials_list/i, 'Add 1 item to trials_list');
    $t->driver()->accept_alert();

    # SAVE A LIST FROM COLUMN 2
    my $second_list_name = "traits_list";
    $t->find_element_ok(
        '(//table[contains(@class, "wizard-save-to-list")])[2]//input[contains(@class, "wizard-create-list-name")]',
        'xpath',
        'find a "list name" for second column and fill a name')->click();

    $t->find_element_ok(
        '(//table[contains(@class, "wizard-save-to-list")])[2]//input[contains(@class, "wizard-create-list-name")]',
        'xpath',
        "fill '$second_list_name' as list name in second column")->send_keys($second_list_name);

    $t->find_element_ok(
        '(//table[contains(@class, "wizard-save-to-list")])[2]//button[contains(text(), "Create")]',
        'xpath',
        "find a 'create list' in second columns button and click")->click();
    sleep(1);
    ok($t->driver->get_alert_text() =~ m/1 items added to list traits_list/i, 'Add 1 item to traits_list');
    $t->driver()->accept_alert();

    # SAVE A LIST FROM COLUMN 3
    my $third_list_name = "years_list";

    $t->find_element_ok(
        '(//table[contains(@class, "wizard-save-to-list")])[3]//input[contains(@class, "wizard-create-list-name")]',
        'xpath',
        'find a "list name" for third column and fill a name')->click();

    $t->find_element_ok(
        '(//table[contains(@class, "wizard-save-to-list")])[3]//input[contains(@class, "wizard-create-list-name")]',
        'xpath',
        "fill '$third_list_name' as list name in third column")->send_keys($third_list_name);

    $t->find_element_ok(
        '(//table[contains(@class, "wizard-save-to-list")])[3]//button[contains(text(), "Create")]',
        'xpath',
        "find a 'create list' in third columns button and click")->click();
    sleep(1);
    ok($t->driver->get_alert_text() =~ m/1 items added to list years_list/i, 'added 1 item to years_list');
    $t->driver()->accept_alert();

    # SAVE A LIST FROM COLUMN 4
    my $fourth_list_name = "acc_list";
    $t->find_element_ok(
        '(//table[contains(@class, "wizard-save-to-list")])[4]//input[contains(@class, "wizard-create-list-name")]',
        'xpath',
        'find a "list name" for fourth column and fill a name')->click();

    $t->find_element_ok(
        '(//table[contains(@class, "wizard-save-to-list")])[4]//input[contains(@class, "wizard-create-list-name")]',
        'xpath',
        "fill '$fourth_list_name' as list name in fourth column")->send_keys($fourth_list_name);

    $t->find_element_ok(
        '(//table[contains(@class, "wizard-save-to-list")])[4]//button[contains(text(), "Create")]',
        'xpath',
        "find a 'create list' in fourth columns button and click")->click();
    sleep(1);
    ok($t->driver->get_alert_text() =~ m/1 items added to list acc_list/i, 'added 1 item to acc_list');
    $t->driver()->accept_alert();

    # RELOAD PAGE AND LOAD DATASET_3_COLUMNS
    $t->get_ok('/breeders/search');
    sleep(2);

    $t->find_element_ok(
        '//select[contains(@class, "wizard-dataset-select")]',
        'xpath',
        'find a "select input" for datasets to load and click')->click();
    sleep(1);

    $t->find_element_ok(
        "//select[contains(\@class, 'wizard-dataset-select')]/optgroup/option[contains(text(), '$dataset_name_1')]",
        'xpath',
        "find a dataset name: $dataset_name_1 in select input and click")->click();

    $t->find_element_ok(
        '//div[contains(@class, "wizard-datasets")]//button[contains(@class, "wizard-dataset-load")]',
        'xpath',
        'find a load button for selected dataset and click')->click();
    sleep(2);

    # unselected 1 column
    my $unselected_reloaded_elements = $t->find_element_ok(
        '(//div[@class="panel-body"])[1]//ul[contains(@class, "wizard-list-unselected")]',
        'xpath',
        "find content of unselected list from first column")->get_attribute('innerHTML');

    ok($unselected_reloaded_elements =~ /CASS_6Genotypes_Sampling_2015/, "Verify first column wizard, unselected after load $dataset_name_1: CASS_6Genotypes_Sampling_2015");
    ok($unselected_reloaded_elements =~ /trial2 NaCRRI/, "Verify first column wizard, unselected after load $dataset_name_1: trial2 NaCRRI");

    # selected 1 column
    my $selected_reloaded_elements = $t->find_element_ok(
        '(//div[@class="panel-body"])[1]//ul[contains(@class, "wizard-list-selected wizard-list")]',
        'xpath',
        "find content of selected list from first column")->get_attribute('innerHTML');

    ok($selected_reloaded_elements =~ /Kasese solgs trial/, "Verify first column wizard, selected after load $dataset_name_1: Kasese solgs trial");

    # unselected 2 column
    my $unselected_reloaded_elements = $t->find_element_ok(
        '(//div[@class="panel-body"])[2]//ul[contains(@class, "wizard-list-unselected")]',
        'xpath',
        "find content of unselected list from second column")->get_attribute('innerHTML');

    ok($unselected_reloaded_elements =~ /fresh root weight|CO_334:0000012/, "Verify second column wizard, unselected after load $dataset_name_1: fresh root weight|CO_334:0000012");
    ok($unselected_reloaded_elements =~ /fresh shoot weight measurement in kg|CO_334:0000016/, "Verify second column wizard, unselected after load $dataset_name_1: fresh shoot weight measurement in kg|CO_334:0000016");

    # selected 2 column
    my $selected_reloaded_elements = $t->find_element_ok(
        '(//div[@class="panel-body"])[2]//ul[contains(@class, "wizard-list-selected wizard-list")]',
        'xpath',
        "find content of selected list from second column")->get_attribute('innerHTML');

    ok($selected_reloaded_elements =~ /dry matter content percentage|CO_334:0000092/, "Verify second column wizard, selected after load $dataset_name_1: dry matter content percentage|CO_334:0000092");

    # selected 3 column
    my $selected_reloaded_elements = $t->find_element_ok(
        '(//div[@class="panel-body"])[3]//ul[contains(@class, "wizard-list-selected wizard-list")]',
        'xpath',
        "find content of selected list from third column")->get_attribute('innerHTML');

    ok($selected_reloaded_elements =~ /2014/, "Verify third column wizard, selected after load $dataset_name_1: 2014");

    # RELOAD PAGE AND LOAD DATASET_4_COLUMNS
    $t->get_ok('/breeders/search');
    sleep(2);

    $t->find_element_ok(
        '//select[contains(@class, "wizard-dataset-select")]',
        'xpath',
        'find a select input for datasets to load and click')->click();
    sleep(1);

    $t->find_element_ok(
        "//select[contains(\@class, 'wizard-dataset-select')]/optgroup/option[text()='$dataset_name_2']",
        'xpath',
        "find a dataset name: $dataset_name_2 in select input and click")->click();
    sleep(1);

    $t->find_element_ok(
        '//div[contains(@class, "wizard-datasets")]//button[contains(@class, "wizard-dataset-load")]',
        'xpath',
        'find a load button for selected dataset and click')->click();
    sleep(5);

    # unselected 4 column
    my $unselected_reloaded_elements = $t->find_element_ok(
        '(//div[@class="panel-body"])[4]//ul[contains(@class, "wizard-list-unselected")]',
        'xpath',
        "find content of unselected list from fourth column")->get_attribute('innerHTML');

    ok($unselected_reloaded_elements =~ /UG120002/, "Verify last column wizard, unselected after load $dataset_name_2: UG120002");
    ok($unselected_reloaded_elements =~ /UG120003/, "Verify last column wizard, unselected after load $dataset_name_2: UG120003");
    ok($unselected_reloaded_elements =~ /UG120007/, "Verify last column wizard, unselected after load $dataset_name_2: UG120007");

    # selected 4 column
    my $selected_reloaded_elements = $t->find_element_ok(
        '(//div[@class="panel-body"])[4]//ul[contains(@class, "wizard-list-selected wizard-list")]',
        'xpath',
        "find content of selected list from fourth column")->get_attribute('innerHTML');

    ok($selected_reloaded_elements =~ /UG120001/, "Verify last column wizard, selected after load $dataset_name_2: UG120001");

    # RELOAD PAGE AND LOAD A LIST OF TRAILS
    $t->get_ok('/breeders/search');
    sleep(2);

    # RELOAD PAGE AND LOAD A LIST OF TRAILS
    $t->find_element_ok('(//div[@class="panel-heading"]/select)[1]', 'xpath', 'find select column type in first column')->click();
    sleep(1);

    $t->find_element_ok(
        "(//div[\@class='panel-heading']/select)[1]/optgroup/option[text()='$fourth_list_name']",
        'xpath',
        "find and select '$fourth_list_name' in first column")->click();
    sleep(1);

    # selected 1 column - 2 new accessions and 1 old
    $selected_reloaded_elements = $t->find_element_ok(
        '(//div[@class="panel-body"])[1]//ul[contains(@class, "wizard-list-selected wizard-list")]',
        'xpath',
        "find content of selected list from first column")->get_attribute('innerHTML');

    ok($selected_reloaded_elements =~ /UG120001/, "Verify first column wizard, selected after load $fourth_list_name: accession UG120001");

    # ADD TO LIST FUNCTIONALITY
    $t->find_element_ok('(//div[@class="panel-heading"]/select)[1]', 'xpath', 'find select column type in first column')->click();
    sleep(1);

    $t->find_element_ok(
        "(//div[\@class='panel-heading']/select)[1]//option[\@value='accessions']", 'xpath', 'find and select "accessions" in first column')->click();
    sleep(1);

    $t->find_element_ok('(//div[@class="panel-body"])[1]//a[contains(text(), "IITA-TMS-IBA011412")]//preceding-sibling::button' , 'xpath', 'find and add "IITA-TMS-IBA011412" accessions in first column')->click();
    $t->find_element_ok('(//div[@class="panel-body"])[1]//a[contains(text(), "IITA-TMS-IBA30572")]//preceding-sibling::button' , 'xpath', 'find and add "IITA-TMS-IBA30572" accessions in first column')->click();
    sleep(1);

    $t->find_element_ok(
        '(//table[contains(@class, "wizard-save-to-list")])[1]//select[contains(@class, "wizard-add-to-list")]',
        'xpath',
        'find a add to list select for first column')->click();
    sleep(1);

    $t->find_element_ok(
        "(//table[contains(\@class, 'wizard-save-to-list')])[1]//select[contains(\@class, 'wizard-add-to-list')]/optgroup/option[text()='$fourth_list_name']",
        'xpath',
        "find a $fourth_list_name on lists name and select")->click();

    $t->find_element_ok(
        '(//table[contains(@class, "wizard-save-to-list")])[1]//button[contains(@class, "wizard-add-to-list")]',
        'xpath',
        'find a button "add to list" and click')->click();
    sleep(1);
    ok($t->driver->get_alert_text() =~ m/The following items are already in the list and were not added: UG120001/i, 'UG120001 already exists in list');
    $t->driver()->accept_alert();
    sleep(1);
    ok($t->driver->get_alert_text() =~ m/2 items added to list/i, '2 items added to list');
    $t->driver()->accept_alert();

    # reload to check a new acc_list with two extra accessions
    $t->get_ok('/breeders/search');
    sleep(3);

    # COLUMN 1 WIZARD SEARCH - load saved list with accessions acc_list
    $t->find_element_ok('(//div[@class="panel-heading"]/select)[1]', 'xpath', 'find select column type in first column')->click();
    sleep(1);

    $t->find_element_ok(
        "(//div[\@class='panel-heading']/select)[1]/optgroup/option[text()='$fourth_list_name']",
        'xpath',
        "find and select '$fourth_list_name' in first column")->click();
    sleep(1);

    # selected 1 column
    $selected_reloaded_elements = $t->find_element_ok(
        '(//div[@class="panel-body"])[1]//ul[contains(@class, "wizard-list-selected wizard-list")]',
        'xpath',
        "find content of selected list from first column")->get_attribute('innerHTML');

    ok($selected_reloaded_elements =~ /UG120001/, "Verify first column wizard, selected elements, after merging $fourth_list_name and two new elements: accession UG120001");
    ok($selected_reloaded_elements =~ /IITA-TMS-IBA011412/, "Verify first column wizard, selected elements, after merging $fourth_list_name and two new elements: accession IITA-TMS-IBA011412");
    ok($selected_reloaded_elements =~ /IITA-TMS-IBA30572/, "Verify first column wizard, selected elements, after merging $fourth_list_name and two new elements: accession IITA-TMS-IBA30572");

    #  TEST WORKING DETAILS PAGE FOR DATASET 1
    $t->get_ok('/search/datasets');
    sleep(1);
    
    $t->find_element_ok("//a[text()='$dataset_name_1']",'xpath','Checking for created dataset on dataset overview page')->click();
    sleep(10);

    my $child_analyses = $t->find_element('dataset_analysis_usage', 'id')->get_text();
    ok($child_analyses eq "(none)", 'Checking initial analysis usage');
    sleep(1);

    #  DELETE DATASET
    $t->get_ok('/breeders/search');
    sleep(3);

    $t->find_element_ok(
        '//select[contains(@class, "wizard-dataset-select")]',
        'xpath',
        'find a select input for datasets to delete and click')->click();
    sleep(1);

    $t->find_element_ok(
        "//select[contains(\@class, 'wizard-dataset-select')]/optgroup/option[contains(text(), '$dataset_name_1')]",
        'xpath',
        "find a dataset name: $dataset_name_1 in select input and click")->click();

    $t->find_element_ok(
        '//div[contains(@class, "wizard-datasets")]//button[contains(@class, "wizard-dataset-delete")]',
        'xpath',
        'find a "delete" dataset button for selected dataset and click')->click();
    sleep(1);
    ok($t->driver->get_alert_text() =~ m/Are you sure you would like to delete it/i, 'Confirm dataset deletion');
    sleep(1);
    $t->driver()->accept_alert();
    sleep(1);
    ok($t->driver->get_alert_text() =~ m/The dataset has been deleted/i, 'Dataset deleted');
    sleep(1);
    $t->driver()->accept_alert();

    # TEST DATASET WAS DELETED
    $t->get_ok('/breeders/search');
    sleep(2);

    my $datasets_list = $t->find_element_ok(
        '//select[contains(@class, "wizard-dataset-select")]',
        'xpath',
        'find a select input for datasets to delete and click')->get_attribute('innerHTML');
    sleep(1);

    ok($datasets_list =~ /$dataset_name_2/, "Verify if datasets list after 'delete' contain $dataset_name_2");
    ok($datasets_list !~ /$dataset_name_1/, "Verify if datasets list after 'delete' NOT contain $dataset_name_1");
    sleep(1);

    # DONE TESTING
    }
);

$t->driver()->close();
done_testing();
