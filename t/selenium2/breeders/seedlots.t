use lib 't/lib';

use Test::More 'tests' => 2;

use SGN::Test::WWW::WebDriver;
use Selenium::Remote::WDKeys 'KEYS';
use SGN::Test::Fixture;

my $t = SGN::Test::WWW::WebDriver->new();
my $f = SGN::Test::Fixture->new();

$t->while_logged_in_as("curator", sub {
    sleep(2);

    #Navigate to seedlot site
    $t->get_ok('/breeders/seedlots');
    sleep(2);

    #Create Seedlot
    #below not working b/c can't find element...
    $t->find_element_ok('//button[text()="Search"]', "xpath", "find and click on Create Seedlot(s) link")->click();
    sleep(2);
    # $t->find_element_ok("add_seedlot_button", "name", "add seedlot")->click();
    #Try to make sure seedlot is there if you try to create it again
    #check that seedlot is there w/ search
    #Click on seedlot
    #Edit Seedlot details
    #Make sure seedlot details have been edited
    #Add New Transaction
    #Add New Transaction using a list
        #Make list
        #Add transaction
    #Edit Transaction
    #Delete Transaction
    #Mark Seedlot as discarded
    #Undo discarding seedlot
    #Mark seedlot as discarded using a list
        #Make list
        #Mark as discarded
    #Make new seedlot
    #Delete seedlot
    #Make sure seedlot was deleted (with search?)
    #Delete seedlots using a list
});

#Same tests as submitter except for marking seedlots as discarded
# $t->while_logged_in_as("submitter", sub {
#     sleep(2);
#
#     $t->get_ok('/breeders/seedlots');
#     sleep(2);
#
# });


$t->driver->close();
$f->clean_up_db();
done_testing();
