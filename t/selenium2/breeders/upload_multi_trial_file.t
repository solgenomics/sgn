use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();


$t->while_logged_in_as("submitter", sub {

    my %trail_3_data = (
        year               => "2017",
        name               => "test_trial_3",
        planting_date      => "[No Planting Date]",
        transplanting_date => "[No Transplanting Date]",
        harvest_date       => "[No Harvest Date]",
        file_name          => "upload_multi_trail.xlsx"

    );

    my %trail_6_data = (
        year               => "2017",
        name               => "test_trial_6",
        planting_date      => "2017-May-01",
        transplanting_date => "2017-September-10",
        harvest_date       => "2018-February-01",
        file_name          => "upload_multi_trail_full.xlsx"
    );

    for my $trail (\%trail_3_data,  \%trail_6_data) {
        sleep(1);

        $t->get_ok('/breeders/trials');
        sleep(3);

        $t->find_element_ok("refresh_jstree_html", "name", "click on refresh_jstree_html ")->click();
        sleep(5);

        $t->find_element_ok("upload_trial_link", "name", "click on upload_trial_link ")->click();
        sleep(2);

        # SCREEN 1 /Intro/
        $t->find_element_ok("next_step_upload_intro_button", "id", "click on next_step_upload_intro_button ")->click();
        sleep(1);

        # SCREEN 2 /File formating and upload/
        $t->find_element_ok("upload_multiple_trial_designs_tab", "id", "choose a multiple trial design tab")->click();
        sleep(1);


        my $upload_input = $t->find_element_ok("multiple_trial_designs_upload_file", "id", "find multi trial file input");
        my $filename = $f->config->{basepath} . "/t/data/trial/$trail->{file_name}";

        $t->driver()->upload_file($filename);
        $upload_input->send_keys($filename);
        sleep(1);

        # SUBMIT
        $t->find_element_ok("multiple_trial_designs_upload_submit", "id", "submit upload file")->click();
        sleep(20);

        # CHECK IF SUBMIT SUCCESSFUL
        $t->find_element_ok("upload_multiple_trials_success_messages", "id", "find success info");

        $t->find_element_ok("upload_multiple_trials_success_button", "id", "find and clock success button")->click();
        sleep(7);

        # Check if added do db and if successfully
        $t->find_element_ok("test", "partial_link_text", "check program in tree")->click();
        sleep(3);

        $t->find_element_ok("jstree-icon", "class", "view drop down for program")->click();
        sleep(5);

        $t->find_element_ok("$trail->{name}", "partial_link_text", "check program in tree")->click();
        my $href_to_trial = $t->find_element_ok("//li[\@role='treeitem']//a[contains(text(),'$trail->{name}')]", 'xpath', 'find trail created and take link href')->get_attribute('href');
        sleep(7);

        $t->get_ok($href_to_trial);
        sleep(5);

        my $table_content = $t->find_element_ok('trial_year', 'id', 'find cell of table with year information')->get_attribute('innerHTML');
        ok($table_content =~ /$trail->{year}/, "Verify info in the table trial year: $trail->{year}");

        $table_content = $t->find_element_ok('trial_name', 'id', 'find cell of table with trial name information')->get_attribute('innerHTML');
        ok($table_content =~ /$trail->{name}/, "Verify info in the table trial name: $trail->{name}");

        $table_content = $t->find_element_ok('planting_date', 'id', 'find cell of table with planting date information')->get_attribute('innerHTML');
        ok($table_content =~ /$trail->{planting_date}/, "Verify info in the table trail planting date: $trail->{planting_date}");

        $table_content = $t->find_element_ok('harvest_date', 'id', 'find cell of table with trial harvest date information')->get_attribute('innerHTML');
        ok($table_content =~ /$trail->{harvest_date}/, "Verify info in the table trail harvest date: $trail->{harvest_date}");

        $table_content = $t->find_element_ok('transplanting_date', 'id', 'find cell of table with trial transplanting date information')->get_attribute('innerHTML');
        ok($table_content =~ /$trail->{transplanting_date}/, "Verify info in the table trail transplanting date: $trail->{transplanting_date}");

        $f->clean_up_db();
    }
});

$t->driver->close();
done_testing();
