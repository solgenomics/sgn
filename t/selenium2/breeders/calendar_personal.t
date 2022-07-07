use lib 't/lib';

use Test::More 'tests' => 9;

use SGN::Test::WWW::WebDriver;

my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub {
    sleep(2);

    # THIS FUNCTIONALITY DOES NOT EXIST IN THE OLD FORM, SIMPLE TEST FOR NEW ONE
    $t->find_element_ok("navbar_personal_calendar", "id", "find calendar button and click")->click();
    sleep(2);

    $t->find_element_ok(
        '(//div[@id = "calendar"]//table//tbody//div[contains(@class, "fc-day-grid-container")]//div[contains(@class, "fc-day-grid")]//div[contains(@class, "fc-row")])[2]//div[contains(@class, "fc-bg")]//table//tbody//td[contains(@class, "fc-day")][3]',
        "xpath",
        "find day in calendar and click")->click();

    sleep(1);

    $t->find_element_ok(
        '//select[@id="event_project_select"]', "xpath", "find 'project select' and click")->click();
    sleep(1);
    $t->find_element_ok('//select[@id="event_project_select"]/option[contains(text(), "Kasese solgs trial")]',
        "xpath",
        "find 'project Kasese solgs trial' and click")->click();

    $t->find_element_ok(
        '//select[@id="event_type_select"]', "xpath", "find 'event type select' and click")->click();
    sleep(1);
    $t->find_element_ok('//select[@id="event_type_select"]/option[contains(text(), "project_planting_date")]',
        "xpath",
        "find 'event type project_planting_date' and click")->click();

    $t->find_element_ok('event_description', "id", "find 'event description' and type name")->send_keys('Calendar event description');

    $t->find_element_ok('event_url', "id", "find 'event url' and type url")->send_keys('example.com');

    $t->find_element_ok('add_event_submit', "id", "find 'add event submit' and click")->click();
    sleep(2);

    $t->driver()->accept_alert();

    # it can be extended
    }
);

$t->driver()->close();
done_testing();