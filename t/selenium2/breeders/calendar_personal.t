use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;

my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub { 

    $t->get_ok('/calendar/personal');

    $t->find_element_ok("fc-day", "class", "find day")->click();

    sleep(3);

    my $event_project_select = $t->find_element_ok("event_project_select", "id", "find event project select");

    $event_project_select->send_keys('test');
    
    my $event_type_select = $t->find_element_ok("event_type_select", "id", "find event type select");

    $event_type_select->send_keys('Planning Event');
    
    $t->find_element_ok("event_start", "id", "find event start")->click();

    my $event_start_calendar = $t->find_element_ok(".day.active", "css", "find active day on calendar select");

    $event_start_calendar->click();

    sleep(1);

    my $event_desc = $t->find_element_ok("event_description", "id", "find event description input");

    $event_desc->click();

    $event_desc->send_keys('test event description');

    my $event_url = $t->find_element_ok("event_url", "id", "find event url input");

    $event_url->send_keys('test.com');

    $t->find_element_ok("add_event_submit", "id", "submit event")->click();
    
    sleep(1);

    $t->driver->accept_alert();

    sleep(1);

    my $cal_event = $t->find_element_ok("test", "partial_link_text", "find test event");

    $cal_event->click();

    sleep(1);

    $t->find_element_ok("test", "partial_link_text", "find test in event details");

    $t->find_element_ok("Planning Event", "partial_link_text", "find event type in event details");

    $t->find_element_ok("http://www.test.com", "partial_link_text", "find event url in event details");

    $t->find_element_ok("event_edit_display", "id", "find event details edit")->click();

    my $edit_event_project_select = $t->find_element_ok("edit_event_project_select", "id", "find edit event project select");

    $edit_event_project_select->send_keys('test_trial');
    
    my $edit_event_type_select = $t->find_element_ok("edit_event_type_select", "id", "find edit event type select");

    $edit_event_type_select->send_keys('project_harvest_date');
    
    $t->find_element_ok("edit_event_start", "id", "find edit event start")->click();

    my $edit_event_desc = $t->find_element_ok("edit_event_description", "id", "find edit event description input");

    $edit_event_desc->send_keys('test edit event description');

    my $edit_event_url = $t->find_element_ok("edit_event_url", "id", "find edit event url input");

    $edit_event_url->clear();

    $edit_event_url->send_keys('http://www.testedit.com');

    $t->find_element_ok("edit_event_submit", "id", "submit edit event")->click();
    
    sleep(2);

    $t->driver->accept_alert();

    sleep(2);

    my $cal_editted_event = $t->find_element_ok("test_trial", "partial_link_text", "find test event");

    $cal_editted_event->click();

    sleep(1);

    $t->find_element_ok("test_trial", "partial_link_text", "find program in editted event details");

    $t->find_element_ok("Harvest_date", "partial_link_text", "find event type in editted event details");

    $t->find_element_ok("http://www.testedit.com", "partial_link_text", "find event url in editted event details");

    $t->find_element_ok("event_dialog_dismiss", "id", "dismiss event dialog")->click();

    sleep(2);

    my $cal_editted_event_location = $cal_editted_event->get_element_location();

    $cal_editted_event->drag($cal_editted_event_location{'x'}+30, $cal_editted_event_location{'y'});

    sleep(2);

    $t->find_element_ok("fc-next-button", "class", "click next month arrow")->click();

    sleep(1);

    $t->find_element_ok("fc-nextYear-button", "class", "click next year arrow")->click();

    sleep(1);

    $t->find_element_ok("fc-prev-button", "class", "click prev month arrow")->click();

    sleep(1);

    $t->find_element_ok("fc-prevYear-button", "class", "click prev year arrow")->click();

    sleep(1);

    $t->find_element_ok("fc-today-button", "class", "click today button")->click();

    sleep(1);

    $t->find_element_ok("fc-day", "class", "find day")->click();

    my $event_project_select = $t->find_element_ok("event_project_select", "id", "find event project select");

    $event_project_select->send_keys('test_trial');
    
    my $event_type_select = $t->find_element_ok("event_type_select", "id", "find event type select");

    $event_type_select->send_keys('project_harvest_date');
    
    $t->find_element_ok("event_start", "id", "find event start")->click();

    my $event_start_calendar = $t->find_element_ok(".day.active", "css", "find active day on calendar select");

    $event_start_calendar->click();

    sleep(1);

    my $event_desc = $t->find_element_ok("event_description", "id", "find event description input");

    $event_desc->click();

    $event_desc->send_keys('test repeat event type description');

    my $event_url = $t->find_element_ok("event_url", "id", "find event url input");

    $event_url->send_keys('test.com');

    $t->find_element_ok("add_event_submit", "id", "submit event")->click();
    
    sleep(1);

    $t->driver->accept_alert();

    sleep(1);

    $t->get_ok('/calendar/personal');

    sleep(2);

    $t->find_element_ok("test", "partial_link_text", "find test event")->click();

    sleep(1);

    $t->find_element_ok("delete_event_submit", "id", "delete event")->click();

    sleep(1);

    $t->driver->accept_alert();

    sleep(1);

    }

);

done_testing();
