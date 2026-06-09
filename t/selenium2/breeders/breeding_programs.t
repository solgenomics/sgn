use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;


my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("curator", sub {
    $t->get_ok('/breeders/manage_programs');

    $t->click_ok('new_breeding_program_link', 'id', 'new breeding program link');

    $t->send_keys_ok('store_breeding_program_name', 'id', 'WEBTEST', 'find store breeding program name input');

    $t->send_keys_ok('store_breeding_program_desc', 'id', 'Test description.', 'find store breeding program description input');

    $t->click_ok('store_breeding_program_submit', 'id', 'find store breeding program button');

    $t->accept_alert_ok('accept alert for breeding program creation');

    $t->get_ok('/breeders/manage_programs');

    $t->find_element_ok('delete_breeding_program_link_WEBTEST', 'id', 'find breeding program delete link');

    ok($t->driver->get_page_source() =~ m/WEBTEST/, "breeding program addition successful");

    $t->click_ok('delete_breeding_program_link_WEBTEST', 'id', 'click breeding program delete link');

    $t->accept_alert_ok('accept alert for breeding program deletion');
    sleep(2); # Waiting for backend tasks to complete; no active requests to watch clientside

    $t->get_ok('/breeders/manage_programs');

    # Wait for the table to load by checking for the add link again, then verify WEBTEST is gone
    $t->find_element_ok('new_breeding_program_link', 'id', 'wait for page to load');

    ok($t->driver->get_page_source() !~ m/WEBTEST/, "breeding program deletion successful");
});

$t->driver()->close();
done_testing();
