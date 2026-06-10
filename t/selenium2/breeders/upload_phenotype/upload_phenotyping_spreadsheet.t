use strict;
use warnings;
use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;
use Selenium::Remote::WDKeys 'KEYS';

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("curator", sub {

    for my $extension ("xls", "xlsx") {
        $t->get_ok('/breeders/trial/137');

        $t->wait_for_working_dialog();

        $t->click_ok("trial_upload_files_onswitch", "id", "find and open 'trial upload files onswitch' and click");

        $t->click_ok("upload_spreadsheet_phenotypes_link", "id", "click on upload_spreadsheet_link ");
        $t->click_ok("upload_spreadsheet_phenotype_file_format", "id", "click on spreadsheet phenotype file format (detailed / simple) ");
        $t->click_ok('//select[@id="upload_spreadsheet_phenotype_file_format"]/option[@value="detailed"]', 'xpath', "Select 'detailed' as phenotype file format");

        my $timestamp_checkbox = $t->find_element_ok("upload_spreadsheet_phenotype_timestamp_checkbox", "id", "click on checkbox phenotype timestamp if was unchecked before");
        unless ($timestamp_checkbox->get_attribute('checked')) {
            $timestamp_checkbox->click();
        };

        $t->click_ok("upload_spreadsheet_phenotype_data_level", "id", "find phenotype spreadsheet data level select");
        $t->click_ok('//select[@id="upload_spreadsheet_phenotype_data_level"]/option[@value="plots"]', 'xpath', "Select 'plots' as value of phenotype spreadsheet data level");

        my $filename = $f->config->{basepath} . "/t/data/trial/upload_phenotypin_spreadsheet.$extension";
        $t->driver()->upload_file($filename);
        $t->send_keys_ok("upload_spreadsheet_phenotype_file_input", "id", $filename, "input file name");

        $t->click_ok("upload_spreadsheet_phenotype_submit_verify", "id", "submit spreadsheet file for verification");

        my $verify_status = $t->get_attribute_ok("upload_phenotype_spreadsheet_verify_status", "id", "innerHTML", "verify the verification");

        ok($verify_status =~ /File upload_phenotypin_spreadsheet.${extension} saved in archive/, "Verify the positive validation");
        ok($verify_status =~ /File valid: upload_phenotypin_spreadsheet.$extension/, "Verify the positive validation");
        ok($verify_status =~ /File data successfully parsed/, "Verify the positive validation");
        ok($verify_status =~ /File data verified. Plot names and trait names are valid/, "Verify the positive validation");

        # UPLOAD_PHENOTYPE_SPREADSHEET_VERIFY_STATUS

        $t->click_ok("upload_spreadsheet_phenotype_submit_store", "id", "submit spreadsheet file for storage");
        $t->wait_for_working_dialog();

        my $verify_status = $t->get_attribute_ok("upload_phenotype_spreadsheet_verify_status", "id", "innerHTML", "verify the verification");

        ok($verify_status =~ /Metadata saved for archived file/, "Verify the positive validation");
        ok($verify_status =~ /Upload Successful/, "Verify the positive validation");

        #TRY VERIFYING AND UPLOADING THE SAME FILE AGAIN.

        $t->get_ok('/breeders/trial/137');
        $t->wait_for_working_dialog();

        $t->click_ok("trial_upload_files_onswitch", "id", "find and open 'trial upload files onswitch' and click");

        $t->click_ok("upload_spreadsheet_phenotypes_link", "id", "click on upload_spreadsheet_link ");

        $t->click_ok("upload_spreadsheet_phenotype_file_format", "id", "click on spreadsheet phenotype file format (detailed / simple) ");
        $t->click_ok('//select[@id="upload_spreadsheet_phenotype_file_format"]/option[@value="detailed"]', 'xpath', "Select 'detailed' as phenotype file format");

        $timestamp_checkbox = $t->find_element_ok("upload_spreadsheet_phenotype_timestamp_checkbox", "id", "click on checkbox phenotype timestamp if was unchecked before");
        unless ($timestamp_checkbox->get_attribute('checked')) {
            $timestamp_checkbox->click();
        };

        $t->click_ok("upload_spreadsheet_phenotype_data_level", "id", "find phenotype spreadsheet data level select");
        $t->click_ok('//select[@id="upload_spreadsheet_phenotype_data_level"]/option[@value="plots"]', 'xpath', "Select 'plots' as value of phenotype spreadsheet data level");

        $filename = $f->config->{basepath} . "/t/data/trial/upload_phenotypin_spreadsheet.$extension";
        $t->driver()->upload_file($filename);
        $t->send_keys_ok("upload_spreadsheet_phenotype_file_input", "id", $filename, "input file name");

        $t->click_ok("upload_spreadsheet_phenotype_submit_verify", "id", "submit spreadsheet file for verification");

        $verify_status = $t->get_attribute_ok("upload_phenotype_spreadsheet_verify_status", "id", "innerHTML", "verify the verification");

	    print STDERR "VERIFY STATUS 1 = $verify_status\n";
        ok($verify_status =~ /File data successfully parsed/, "Verify warnings after store validation 1");
        ok($verify_status =~ /File data verified. Plot names and trait names are valid./, "Verify warnings after store validation 2");
        ok($verify_status =~ /Warnings are shown in yellow. Either fix the file and try again/, "Verify warnings after store validation 3");
        ok($verify_status =~ /To overwrite previously stored values instead/, "Verify warnings after store validation 4");
        ok($verify_status =~ /There are 60 values in your file that are the same as values already stored in the database./, "Verify warnings after store validation 5");


        $t->click_ok("upload_spreadsheet_phenotype_submit_store", "id", "submit spreadsheet file for storage");
        $t->wait_for_working_dialog();

        $verify_status = $t->get_attribute_ok("upload_phenotype_spreadsheet_verify_status", "id", "innerHTML", "verify the verification");

	    print STDERR "VERIFY STATUS 2: $verify_status\n";
        ok($verify_status =~ /0 new values stored/, "Verify warnings after store validation 6");
        ok($verify_status =~ /60 previously stored values skipped/, "Verify warnings after store validation 7");
        ok($verify_status =~ /0 previously stored values overwritten/, "Verify warnings after store validation 8");
        ok($verify_status =~ /0 previously stored values removed/, "Verify warnings after store validation 9");
        ok($verify_status =~ /Upload Successful!/, "Verify warnings after store validation 10");

        #TRY VERIFYING AND UPLOADING THE SAME FILE AGAIN FROM THE /BREEDERS/PHENOTYPING PAGE.

        $t->get_ok('/breeders/phenotyping');
        $t->click_ok("upload_spreadsheet_phenotypes_link", "id", "click on upload_spreadsheet_link ");

        $t->click_ok("upload_spreadsheet_phenotype_file_format", "id", "click on spreadsheet phenotype file format (detailed / simple) ");
        $t->click_ok('//select[@id="upload_spreadsheet_phenotype_file_format"]/option[@value="detailed"]', 'xpath', "Select 'detailed' as phenotype file format");

        $timestamp_checkbox = $t->find_element_ok("upload_spreadsheet_phenotype_timestamp_checkbox", "id", "click on checkbox phenotype timestamp if was unchecked before");
        unless ($timestamp_checkbox->get_attribute('checked')) {
            $timestamp_checkbox->click();
        };

        $t->click_ok("upload_spreadsheet_phenotype_data_level", "id", "find phenotype spreadsheet data level select");
        $t->click_ok('//select[@id="upload_spreadsheet_phenotype_data_level"]/option[@value="plots"]', 'xpath', "Select 'plots' as value of phenotype spreadsheet data level");

        $filename = $f->config->{basepath} . "/t/data/trial/upload_phenotypin_spreadsheet.$extension";
        $t->driver()->upload_file($filename);
        $t->send_keys_ok("upload_spreadsheet_phenotype_file_input", "id", $filename, "input file name");

        $t->click_ok("upload_spreadsheet_phenotype_submit_verify", "id", "submit spreadsheet file for verification");
        $t->wait_for_network_idle();

        $verify_status = $t->get_attribute_ok("upload_phenotype_spreadsheet_verify_status", "id", "innerHTML", "verify the verification");

	    print STDERR "VERIFY STATUS 3: $verify_status\n";
        ok($verify_status =~ /File data successfully parsed/, "Verify warnings after store validation 11");
        ok($verify_status =~ /File data verified. Plot names and trait names are valid./, "Verify warnings after store validation 12");
        ok($verify_status =~ /Warnings are shown in yellow. Either fix the file and try again/, "Verify warnings after store validation 13");
        ok($verify_status =~ /To overwrite previously stored values instead/, "Verify warnings after store validation 14");
        ok($verify_status =~ /There are 60 values in your file that are the same as values already stored in the database./, "Verify warnings after store validation 15");

        $t->click_ok("upload_spreadsheet_phenotype_submit_store", "id", "submit spreadsheet file for storage");
        $t->wait_for_working_dialog();
        $t->wait_for_network_idle();

        $verify_status = $t->get_attribute_ok("upload_phenotype_spreadsheet_verify_status", "id", "innerHTML", "verify the verification");

	    print STDERR "VERIFY STATUS 4: $verify_status\n";
        ok($verify_status =~ /0 new values stored/, "Verify warnings after store validation 16");
        ok($verify_status =~ /60 previously stored values skipped/, "Verify warnings after store validation 17");
        ok($verify_status =~ /0 previously stored values overwritten/, "Verify warnings after store validation 18");
        ok($verify_status =~ /0 previously stored values removed/, "Verify warnings after store validation 19");
        ok($verify_status =~ /Upload Successful!/, "Verify warnings after store validation 20");

        if ($extension eq "xlsx") { # this test only needs to be run once. We will verify that the phenotype raw data section looks good and is editable.
            $t->get_ok('/breeders/trial/137');

            $t->click_ok("trial_raw_data_onswitch", "id", "Find phenotype raw data section");
            $t->click_ok("raw_data_trait_select_button", "id", "Request raw phenotype data");
            $t->wait_for_working_dialog();

            # Find and store the observation ID of the first row
            my $obs_id = $t->find_element_ok(
                '//table[@id="raw_trait_data_table"]//tbody/tr[1]/td[1]',
                'xpath',
                'Find observation ID of first row in raw data table'
            )->get_text();
            $obs_id =~ s/^\s+|\s+$//g;
            print STDERR "OBSERVATION ID OF FIRST ROW: $obs_id\n";
            ok($obs_id =~ /^\d+$/, "Observation ID is numeric");

            # Store original value display for later comparison
            my $original_value_display = $t->find_element_ok(
                '//table[@id="raw_trait_data_table"]//tbody/tr[1]/td[4]',
                'xpath',
                'Get original value from first row before any edits'
            )->get_text();
            $original_value_display =~ s/^\s+|\s+$//g;
            print STDERR "ORIGINAL VALUE DISPLAY: $original_value_display\n";

            # Click edit button, make trivial edits to value and timestamp
            $t->click_ok("${obs_id}_edit_btn", "id", "Click edit button for first row");

            $t->send_keys_ok("${obs_id}_value_input", "id", [KEYS->{'control'}, 'a'], "enter value input");
            $t->send_keys_ok("${obs_id}_value_input", "id", "999", "enter value input");

            $t->send_keys_ok("${obs_id}_timestamp_input", "id", [KEYS->{'control'}, 'a'], "enter timestamp input");
            $t->send_keys_ok("${obs_id}_timestamp_input", "id", "2020-01-01 00:00:00+0000", "enter timestamp input");

            # Click discard and verify values are unchanged
            $t->click_ok("${obs_id}_discard_changes_btn", "id", "Click discard button for first row");

            my $value_after_discard = $t->get_text_ok(
                '//table[@id="raw_trait_data_table"]//tbody/tr[1]/td[4]',
                'xpath',
                'Get value from first row after discarding edits'
            );
            $value_after_discard =~ s/^\s+|\s+$//g;
            ok($value_after_discard eq $original_value_display, "Value is unchanged after discarding edits");

            # Click edit again, edit only the value, click save
            $t->click_ok("${obs_id}_edit_btn", "id", "Click edit button again for first row");

            my $new_value = "888";
            $t->send_keys_ok("${obs_id}_value_input", "id", [KEYS->{'control'}, 'a'], "input value");
            $t->send_keys_ok("${obs_id}_value_input", "id", $new_value, "input value");

            $t->click_ok("${obs_id}_save_changes_btn", "id", "Click save button for first row");
            $t->wait_for_network_idle();

            # Refresh page and return to raw data section
            $t->get_ok('/breeders/trial/137');

            $t->click_ok("trial_raw_data_onswitch", "id", "Find raw data section after page refresh");

            $t->click_ok("raw_data_trait_select_button", "id", "Request raw phenotype data after page refresh");
            $t->wait_for_working_dialog();

            # Find the row by stored observation ID and verify the edit was retained
            my $updated_value_display = $t->get_text_ok(
                "//table[\@id='raw_trait_data_table']//tbody/tr[td[1][normalize-space()='$obs_id']]/td[4]",
                'xpath',
                'Find updated value cell for stored observation ID after page refresh'
            );
            $updated_value_display =~ s/^\s+|\s+$//g;
            print STDERR "UPDATED VALUE AFTER REFRESH: $updated_value_display\n";
            ok($updated_value_display =~ /^$new_value/, "Edited value was retained after page refresh");
        }

        $f->clean_up_db();
    }
});

$t->driver()->close();
$f->clean_up_db();
done_testing();
