

use lib 't/lib';

use Test::More 'tests'=>8;

use SGN::Test::WWW::WebDriver;


my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub { 
    $t->get_ok('/breeders/manage_programs');
    
    my $new_bp_link = $t->find_element_ok('new_breeding_program_link', 'id', 'new breeding program link');

    $new_bp_link->click();

    my $breeding_program_name_input = $t->find_element_ok('new_breeding_program_name', 'id', 'find add breeding program name input');

    $breeding_program_name_input->send_keys('WEBTEST');

    my $breeding_program_desc_input = $t->find_element_ok('new_breeding_program_desc', 'id', 'find add breeding program description input');

    $breeding_program_desc_input->send_keys('Test description.');

    my $ok_button = $t->find_element_ok('new_breeding_program_dialog_ok_button', 'id', 'find add breeding program button');


    $ok_button->click();

    print STDERR "\n\nCLICKED OK... so far so good...\n\n";

    sleep(2); # wait until page is re-loaded

#    $t->get_ok('/breeders/manage_programs');

    #ok($t->driver->get_page_source() =~ m/WEBTEST/, "breeding program addition successful");
    print STDERR "TROUBLE, folks!\n\n";

    my $delete_link = $t->find_element_ok('delete_breeding_program_link_WEBTEST', 'id', 'find breeding program delete link');

    print STDERR "Marker 1\n";

    $delete_link->click();

    print STDERR "Marker 2\n";

    $t->driver()->accept_alert();

    print STDERR "Marker 3\n";
    
    ok($t->get->driver->get_page_source() !~ m/TEST/, "breeding program deletion successful");
		       
		       });
