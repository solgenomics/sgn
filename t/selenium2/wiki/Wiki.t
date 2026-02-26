
use strict;

use lib 't/lib';

use Test::More qw| no_plan |;
use SGN::Test::Fixture;
use SGN::Test::WWW::WebDriver;

my $d = SGN::Test::WWW::WebDriver->new();

my $f = SGN::Test::Fixture->new();

$d->while_logged_in_as("curator", sub {

    $d->get_ok("/wiki/WikiHome", "get wiki home page");
    sleep(2);

    $d->driver()->accept_alert();

    sleep(2);

    my $wiki_page_content = $d->find_element_ok("wiki_page_content", "id", "find wiki_page_content text area");
    $wiki_page_content->send_keys("#Big Title!\n##Smaller Title\nBla bla bla\n");

    sleep(2);

    my $save_wiki_page_button = $d->find_element_ok("save_wiki_page_button", "id", "find wiki page save button");
    $save_wiki_page_button->click();

    my $contents = $d->driver()->get_body();
    like($contents, qr/Big Title\!/, "check page contents");
    like($contents, qr/Smaller Title/, "check more page contents");
    like($contents, qr/Bla bla bla/, "check even more page contents");

    my $edit_wiki_page_button = $d->find_element_ok("edit_wiki_page_button", "id", "find wiki page edit button");
    $edit_wiki_page_button->click();

    # create a second version of the page
    #
    my $wiki_page_content = $d->find_element_ok("wiki_page_content", "id", "find wiki_page_content text area");
    $wiki_page_content->send_keys("This is the new content of version 2");

    $d->find_element_ok("save_wiki_page_button", "id", "find save wiki page button")->click();

    $contents = $d->driver()->get_body();

    like($contents, qr/This is the new content of version 2/, "check page contents version 2");

    sleep(2);

    # create a new unrelated page
    #
    my $new_wiki_page_button = $d->find_element_ok("new_wiki_page_button", "id", "find new wiki page button");
    $new_wiki_page_button->click();

    sleep(2);

    my $wiki_page_name_input = $d->find_element_ok("wiki_page_name", "id", "find wiki page name input field again");
    $wiki_page_name_input->send_keys("AnotherTestPage");

    my $create_wiki_page_button = $d->find_element_ok("create_wiki_page_button","id", "find create wiki page button again");
    $create_wiki_page_button->click();

    sleep(2);

    $wiki_page_content = $d->find_element_ok("wiki_page_content", "id", "find wiki_page_content text area");
    $wiki_page_content->send_keys("More Stuff");

    $d->find_element_ok("save_wiki_page_button", "id", "find save wiki page button")->click();

    sleep(2);

    $contents = $d->driver()->get_body();
    like($contents, qr/More Stuff/, "check another test page contents");

    sleep(2);

    # check if homepage still exists
    #
    $d->get_ok("/wiki/WikiHome", "get wiki home page");
    sleep(2);

    $contents = $d->driver()->get_body();
    like($contents, qr/Big Title\!/, "check page contents");
    like($contents, qr/Smaller Title/, "check more page contents");
    like($contents, qr/Bla bla bla/, "check even more page contents");

    $d->find_element_ok("delete_wiki_page_button", "id", "find delete wiki page button")->click();

    $d->driver()->accept_alert();
});


done_testing();
