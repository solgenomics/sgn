
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;



my $d = SGN::Test::WWW::WebDriver->new();

my $download_dir = $d->download_dir();


$d->while_logged_in_as("submitter", sub {
    # sleep(1);

    $d->get_ok("/about/index.pl", "get root url test");
    sleep(2);

    my $out = $d->find_element_ok("lists_link", "name", "find lists_link")->click();

    sleep(2);

    # Revert to original sorting: by list name, ascending
    $d->find_element_ok("(//table[\@id='private_list_data_table']/thead/tr/th)[1]", "xpath", "Sort table by List Name")->click();

    sleep(1);

    $d->find_element_ok("list_select_checkbox_808", "id", "checkbox select list")->click();

    sleep(1);

    $d->find_element_ok("list_select_checkbox_810", "id", "checkbox select list")->click();

    sleep(1);

    $d->find_element_ok("make_public_selected_list_group", "id", "make public selected list group")->click();

    sleep(1);

    $d->accept_alert_ok();

    sleep(1);

    $d->find_element_ok("view_public_lists_button", "id", "view public lists")->click();

    sleep(1);

    $d->find_element_ok("view_public_list_johndoe_1_private", "id", "check view public lists");

    sleep(1);

    $d->find_element_ok("close_public_list_item_dialog", "id", "close public lists")->click();

    sleep(1);

    $d->find_element_ok("list_select_checkbox_808", "id", "checkbox select list")->click();

    sleep(1);

    $d->find_element_ok("list_select_checkbox_810", "id", "checkbox select list")->click();

    sleep(1);

    $d->find_element_ok("make_private_selected_list_group", "id", "make private selected list group")->click();

    sleep(1);

    $d->accept_alert_ok();

    sleep(1);

    ## Combine two lists using union

    $d->find_element_ok("list_select_checkbox_808", "id", "checkbox select list 808")->click();

    sleep(1);

    $d->find_element_ok("list_select_checkbox_810", "id", "checkbox select list 810")->click();

    sleep(1);

    $d->find_element_ok("new_combined_list_name", "id", "name selected list group - union")->send_keys("combined_list_union");

    $d->find_element_ok("combine_selected_list_group_union", "id", "combine selected list group - union")->click();

    sleep(1);

    $d->accept_alert_ok();

    sleep(1);

    ok($d->driver->get_alert_text() =~ m/Added 4 items to the new List combined_list_union/i, 'created selected list group - union');
    $d->accept_alert_ok();

    sleep(1);

    $d->find_element_ok("view_list_combined_list_union", "id", "check view combined list - union");

    sleep(1);

    ## Combine two lists using intersection

    $d->find_element_ok("list_select_checkbox_808", "id", "checkbox select list 808")->click();

    sleep(1);

    $d->find_element_ok("list_select_checkbox_4", "id", "checkbox select list 4")->click();

    sleep(1);

    $d->find_element_ok("new_combined_list_name", "id", "name selected list group - intersection")->send_keys("combined_list_intersection");

    $d->find_element_ok("combine_selected_list_group_intersection", "id", "combine selected list group - intersection")->click();

    sleep(1);

    $d->accept_alert_ok();

    sleep(1);

    # Accept alert about mismatched list types (one list doesn't have it's type set)
    $d->accept_alert_ok();

    sleep(1);

    ok($d->driver->get_alert_text() =~ m/Added 2 items to the new List combined_list_intersection/i, 'created selected list group - intersection');
    $d->accept_alert_ok();

    sleep(1);

    $d->find_element_ok("view_list_combined_list_intersection", "id", "check view combined list - intersection");

    sleep(1);

    # Compare two lists

    unlink glob("$download_dir/*");

    $d->find_element_ok("list_select_checkbox_808", "id", "checkbox select list 808")->click();

    sleep(1);

    $d->find_element_ok("list_select_checkbox_810", "id", "checkbox select list 810")->click();

    sleep(1);

    $d->find_element_ok("compare_selected_list_group", "id", "compare selected list group")->click();

    sleep(1);

    $d->find_element_ok("download_comparison_column", "id", "find download comparison column button")->click();

    sleep(1);

    $d->find_element_ok("close_list_comparison_modal", "id", "find close comparison dialog button")->click();

    sleep(1);

=head2 download
    my @files = glob("$download_dir/*");

    ok(@files, "File downloaded to tmp directory");

    my $downloaded_file = "$download_dir/Only in johndoe_1_private.txt";

    ok(-f $downloaded_file, "Found downloaded file: $downloaded_file");

    open my $fh, '<', $downloaded_file or die "Could not open $downloaded_file: $!";
    my $contents = do {local $/; <$fh> };
    close $fh;

    my $expected = "test1\ntest2";
    like($contents, qr/\Q$expected\E/, "Downloaded file contains expected content");
=cut

    ## Delete list group

    $d->find_element_ok("delete_selected_list_group", "id", "delete selected list group")->click();

    sleep(1);

    $d->accept_alert_ok();

    sleep(1);


    $d->find_element_ok("close_list_dialog_button", "id", "find close dialog button")->click();

});

$d->driver->close();
done_testing();

