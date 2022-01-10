
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use SGN::Test::WWW::WebDriver;
use CXGN::List;
use SimulateC;

my $d = SGN::Test::WWW::WebDriver->new();

my $f = SGN::Test::Fixture->new();
my $c = SimulateC->new( { dbh => $f->dbh(), 
			  bcs_schema => $f->bcs_schema(), 
			  metadata_schema => $f->metadata_schema(),
			  phenome_schema => $f->phenome_schema(),
			  sp_person_id => 41 });

$d->login_as("submitter");

$d->get_ok("/search", "get root url test");

my $out = $d->find_element_ok("lists_link", "name", "find lists_link")->click();

print "Adding new list...\n";

$d->find_element_ok("add_list_input", "id", "find add list input");

sleep(1);

my $add_list_input = $d->find_element_ok("add_list_input", "id", "find add list input test");

sleep(1);

$add_list_input->send_keys("new_test_list");

$d->find_element_ok("add_list_button", "id", "find add list button test")->click();

$d->find_element_ok("view_list_new_test_list", "id", "view list test")->click();

sleep(1);

$d->find_element_ok("dialog_add_list_item", "id", "add test list")->send_keys("element1\nelement2\nelement3\n");

sleep(1);

$d->find_element_ok("dialog_add_list_item_button", "id", "find dialog_add_list_item_button test")->click();

my $edit_list_name = $d->find_element_ok("updateNameField", "id", "edit list name");

$edit_list_name->clear();
$edit_list_name->send_keys("update_list_name");

sleep(1);

$d->find_element_ok("updateNameButton", "id", "submit edit list name")->click();

sleep(1);
$d->accept_alert_ok();
sleep(1);
#$d->accept_alert_ok();
sleep(1);

$d->find_element_ok("close_list_item_dialog", "id", "find close_list_item_dialog button test")->click();

sleep(1);

#my %test_lists = ('accessions'=>"test_accession1\ntest_accession2\ntest_accession3\n", 'plots'=>"test_trial1\ntest_trial21\ntest_trial22\n", 'locations'=>"test_location\nCornell Biotech\n", 'trials'=>"test\ntest_trial\ntest_genotyping_project\n", 'traits'=>"fresh shoot weight|CO_334:0000016\ndry matter content|CO_334:0000092\nharvest index|CO_334:0000015\n");

my %test_lists = ('accessions'=>"test_accession1\ntest_accession2\ntest_accession3\n", 'plots'=>"test_trial1\ntest_trial21\ntest_trial22\n", 'locations'=>"test_location\nCornell Biotech\n",
		  #'traits'=>"fresh shoot weight|CO_334:0000016\ndry matter content|CO_334:0000092\nharvest index|CO_334:0000015\n"
    );

foreach my $list_type ( keys %test_lists ) {

    print STDERR "NOW TESTING $list_type...\n";
    
    sleep(3);
    $d->find_element_ok("view_list_update_list_name", "id", "view list dialog test");

    sleep(1);

    $d->find_element_ok("add_list_input", "id", "find add list input");

    $d->find_element_ok("add_list_input", "id", "find add list input test")->send_keys($list_type);

    $d->find_element_ok("add_list_button", "id", "find add list button test")->click();

    $d->find_element_ok("view_list_".$list_type, "id", "view list dialog test")->click();

    sleep(1);

    $d->find_element_ok("dialog_add_list_item", "id", "add list items")->send_keys($test_lists{$list_type});

    my @list_items = split /\n/, $test_lists{$list_type};

    $d->find_element_ok("dialog_add_list_item_button", "id", "find dialog_add_list_item_button test")->click();

    $d->find_element_ok("type_select", "id", "validate list select")->send_keys($list_type);

    $d->find_element_ok("list_item_dialog_validate", "id", "submit list validate")->click();

    sleep(1);
    my $alert_text = $d->driver->get_alert_text;
    if ($alert_text eq 'This list passed validation.'){
       $d->accept_alert_ok();
    } else {
       print STDERR "\n\n<ERROR>: list not validated: ".$list_type."\n\n";
       $d->accept_alert_ok();
    }
    sleep(1);

    $d->find_element_ok("close_list_item_dialog", "id", "find close list dialog button")->click();

    $d->find_element_ok("view_list_".$list_type, "id", "view accession list dialog test");
}

$d->find_element_ok("view_public_lists_button", "id", "find public list button")->click();

sleep(3);

$d->find_element_ok("view_public_list_johndoe_1_public", "id", "view johndoe1public list")->click();

sleep(1);

$d->find_element_ok("close_list_item_dialog", "id", "close public list item dialog")->click();

sleep(1);

$d->find_element_ok("copy_public_list_johndoe_1_public", "id", "copy johndoe public list")->click();

sleep(1);

$d->accept_alert_ok();

sleep(1);

$d->find_element_ok("copy_public_list_janedoe_1_public", "id", "copy janedoe public list")->click();

sleep(1);

$d->accept_alert_ok();

sleep(1);

$d->find_element_ok("close_public_list_item_dialog", "id", "close public list dialog")->click();

sleep(1);

$d->find_element_ok("share_list_johndoe_1_private", "id", "make private list public")->click();

sleep(1);

$d->accept_alert_ok();

sleep(1);

$d->find_element_ok("view_public_lists_button", "id", "view public lists")->click();

sleep(2);

$d->find_element_ok("view_public_list_johndoe_1_private", "id", "view new public list")->click();

sleep(1);

$d->find_element_ok("close_list_item_dialog", "id", "close new public list item dialog")->click();

sleep(1);

$d->find_element_ok("close_public_list_item_dialog", "id", "close new public list dialog")->click();

sleep(1);

$d->find_element_ok("view_list_janedoe_1_public", "id", "view new public list")->click();

#sleep(100);

#my $list_id = 16;
#my $q = "SELECT list_item_id from sgn_people.list join sgn_people.list_item using(list_id) WHERE list_id=?";
#my $h = $c->dbh->prepare($q);
#$h->execute($list_id);
#my @list = ();
#while (my ($content) = $h->fetchrow_array()) { 
#      push @list, $content;
#}

#$d->find_element_ok($list[0], "id", "delete item from list")->click();
#$d->find_element_ok($list[1], "id", "delete item from list")->click();

sleep(1);

$d->find_element_ok("close_list_item_dialog", "id", "close new public list item dialog")->click();

sleep(1);

print "Delete test list...\n";

$d->find_element_ok("delete_list_update_list_name", "id", "find delete test list button")->click();

sleep(1);

$d->accept_alert_ok();

sleep(1);

$d->accept_alert_ok();

print "Deleted the list\n";

$d->find_element_ok("close_list_dialog_button", "id", "find close dialog button")->click();

$d->logout_ok();

done_testing();

$d->driver->close();

