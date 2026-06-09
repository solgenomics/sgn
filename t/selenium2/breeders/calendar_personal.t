use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;

my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub {

    # THIS FUNCTIONALITY DOES NOT EXIST IN THE OLD FORM, SIMPLE TEST FOR NEW ONE
    $t->click_ok("navbar_personal_calendar", "id", "find calendar button and click");

    $t->click_ok(
        '(//div[@id = "calendar"]//table//tbody//div[contains(@class, "fc-day-grid-container")]//div[contains(@class, "fc-day-grid")]//div[contains(@class, "fc-row")])[2]//div[contains(@class, "fc-bg")]//table//tbody//td[contains(@class, "fc-day")][3]',
        "xpath",
        "find day in calendar and click");

    $t->click_ok(
        '//select[@id="event_project_select"]', "xpath", "find 'project select' and click");
    $t->click_ok('//select[@id="event_project_select"]/option[contains(text(), "Kasese solgs trial")]',
        "xpath",
        "find 'project Kasese solgs trial' and click");

    $t->click_ok(
        '//select[@id="event_type_select"]', "xpath", "find 'event type select' and click");
    $t->click_ok('//select[@id="event_type_select"]/option[contains(text(), "project_planting_date")]',
        "xpath",
        "find 'event type project_planting_date' and click");

    $t->send_keys_ok('event_description', "id", 'Calendar event description', "find 'event description' and type name");

    $t->send_keys_ok('event_url', "id", 'example.com', "find 'event url' and type url");

    $t->click_ok('add_event_submit', "id", "find 'add event submit' and click");

    $t->accept_alert_ok('accept alert');

    # it can be extended
    }
);

$t->driver()->close();
done_testing();