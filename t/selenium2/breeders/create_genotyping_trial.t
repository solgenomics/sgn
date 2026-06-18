
use strict;

use lib 't/lib';

use Test::More;

use Data::Dumper;
use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub {
	$t->get_ok('/breeders/genotyping_projects');

	sleep(1); # FIXME Need to wait for click handler to be registered

	# CREATE PROJECT FIRST
	$t->click_ok("create_genotyping_project_link", "name", "find create genotyping project link abd click");

	# SCREEN 1 /Intro/
	$t->click_ok('next_step_add_new_genotyping_project', 'id', 'Next step from Into Screen find and click');

	# SCREEN 2 /Genotyping Project/
	my $project_name = "NEXTGENCASSAVA";
	$t->send_keys_ok('new_genotyping_project_name', 'id', $project_name, 'find "genotyping project name" and click');

	$t->click_ok('genotyping_project_facility_select', 'id', 'find "genotyping project facility select" and click');
	$t->click_ok('//select[@id="genotyping_project_facility_select"]/option[@value="None"]', 'xpath', 'Select "None" as value for genotyping project facility');

	$t->click_ok('data_type', 'id', 'find "genotyping project data_type" and click');
	$t->click_ok('//select[@id="data_type"]/option[@value="snp"]', 'xpath', 'Select "snp" as value for genotyping data type');

	$t->click_ok('genotyping_project_breeding_program_select', 'id', 'find "genotyping breeding program select" and click');
	$t->click_ok('//select[@id="genotyping_project_breeding_program_select"]/option[@title="test"]', 'xpath', 'Select "Breedbase" as title for genotyping data type');

	$t->click_ok('genotyping_project_year_select', 'id', 'find "genotyping project year" select and click');
	$t->click_ok('//select[@id="genotyping_project_year_select"]/option[@title="2018"]', 'xpath', 'Select "2018" as value of project year');

	$t->click_ok('genotyping_project_location_select', 'id', 'find "genotyping project location" select and click');
	$t->click_ok('//select[@id="genotyping_project_location_select"]/option[@title="test_location"]', 'xpath', 'Select "test_location" as value of project location');

	$t->send_keys_ok('genotyping_project_description', 'id', "Selenium test genotyping project description", 'find "genotyping project description" and fill');

	$t->click_ok('add_new_genotyping_project_submit', 'id', 'New genotyping project submit button find and click');
    
    $t->wait_for_working_dialog();

	$t->click_ok('add_new_genotyping_project_close_modal', 'id', 'New genotyping project close modal button find and click');

    #manage genotyping projects
    $t->click_ok("refresh_genotyping_project_jstree_html_button", "id", "find and click 'refresh genotyping project jstree'");
	$t->wait_for_network_idle();

    $t->click_ok('//div[@id="genotyping_project_list"]//i[contains(@class, "jstree-icon")]', 'xpath', 'open a tree with genotyping project list');
	$t->wait_for_network_idle();

    my $href_to_trial = $t->get_attribute_ok("//div[\@id='genotyping_project_list']//a[contains(text(), '$project_name')]", 'xpath', 'href', 'find created project and take link href');

    # Helper function for genotyping plate creation tests
    my $run_create_plate_test = sub {
        my ($excel_file_name, $plate_name, $should_succeed, $error_regex) = @_;

        $t->get_ok('/breeders/genotyping_projects');
        sleep(1);

        # CREATE TRIAL
        $t->click_ok("create_genotyping_trial_link", "name", "find create genotyping trial link and click");
        $t->click_ok('next_step_intro_button', 'id', 'go to screen - Intro');
        $t->click_ok('next_step_creating_genotyping_plates', 'id', 'go to screen - Genotyping Project');

        # SCREEN 3 /Basic Plate Info/
        $t->click_ok('plate_genotyping_project_id', 'id', 'open project select');
        $t->click_ok("//select[\@id=\"plate_genotyping_project_id\"]/option[\@title='$project_name']", 'xpath', "Select $project_name");
        $t->send_keys_ok('genotyping_trial_name', 'id', $plate_name, 'set plate name');
        $t->click_ok('genotyping_trial_plate_format', 'id', 'open format select');
        $t->click_ok('//select[@id="genotyping_trial_plate_format"]/option[@value="96"]', 'xpath', 'select 96 Well');
        $t->click_ok('genotyping_trial_plate_sample_type', 'id', 'open sample type select');
        $t->click_ok('//select[@id="genotyping_trial_plate_sample_type"]/option[@value="DNA"]', 'xpath', 'select DNA');
        $t->send_keys_ok('genotyping_trial_description', 'id', "Selenium test description", 'set description');
        $t->click_ok('plate_info_intro_button', 'id', 'go to screen - Basic Plate Info');

        # SCREEN 4 /Well Info/
        $t->click_ok('genotyping_trial_well_input_option', 'id', 'open input option select');
        $t->click_ok('//select[@id="genotyping_trial_well_input_option"]/option[@value="xlsx"]', 'xpath', 'select xlsx');

        my $filename = $f->config->{basepath} . "/t/data/genotype_trial_upload/$excel_file_name";
        $t->driver()->upload_file($filename);
        $t->send_keys_ok("genotyping_trial_layout_upload", "id", $filename, "upload file");
        $t->click_ok('well_info_intro_button', 'id', 'go to screen - Well Info');

        # SCREEN 5 /Trial Linkage/
        $t->click_ok('trial_linkage_intro_button', 'id', 'go to screen - Linkage');

        # SCREEN 6 /Confirm/
        $t->click_ok('add_geno_trial_submit', 'id', 'submit genotyping trial');

        if ($should_succeed == 1) {
            $t->accept_alert_ok('accept success alert');
            $t->click_ok('close_trial_button', 'id', 'close dialog');
            $t->wait_for_network_idle();
        } else {
            my $alert_text = $t->get_alert_text();
            print STDERR "Result text: $alert_text\n";
            ok($alert_text =~ /$error_regex/, "Verify validation error: $error_regex") if $error_regex;
            $t->accept_alert_ok('accept failure alert');
            $t->click_ok('close_trial_button', 'id', 'close dialog');
        }
    };

    $t->get_ok($href_to_trial);

    # 1. Test uploading genotyping plate for both excel formats xls and xlsx
    my @basic_files = (["NEW_CASSAVA_GS_74Template.xls", "2018TestPlate02"], ["NEW_CASSAVA_GS_74Template_selenium.xlsx", "2018TestPlate03"]);
    for my $file_info (@basic_files) {
        my ($excel_file_name, $plate_name) = @$file_info;
        $run_create_plate_test->($excel_file_name, $plate_name, 1);

        # Verify table content for basic successful uploads
        my $genotyping_plate_id = $f->bcs_schema->resultset('Project::Project')->find({ name => $plate_name })->project_id();
        $t->get_ok('/breeders/trial/' . $genotyping_plate_id);
        my $trial_table_content = $t->get_attribute_ok('trial_plate_view_table', 'id', 'innerHTML', 'find table with created trial data');
        ok($trial_table_content =~ /\Q${plate_name}_F07/, "Verify sample id in a table: ${plate_name}_F07");
        ok($trial_table_content =~ /\Q${plate_name}_B04/, "Verify sample id in a table: ${plate_name}_B04");
        ok($trial_table_content =~ /test_accession1/, "Verify accession id in a table: test_accession1");
        ok($trial_table_content =~ /A01/, "Verify well id in a table: A01");
        ok($trial_table_content =~ /A05/, "Verify well id in a table: A05");
    }

    # 2. Test configurable tissue types
    # plate_tissue_type_invalid.xlsx contains 'bark' which is not in sgn_test.conf
	$run_create_plate_test->("plate_tissue_type_invalid.xlsx", "PlateTissueInvalid", 0, qr/column tissue type and must be one of: leaf, root, stem, seed, fruit, tuber, flower/);
	# plate_tissue_type_valid.xlsx contains 'flower' which IS in sgn_test.conf
	$run_create_plate_test->("plate_tissue_type_valid.xlsx", "PlateTissueValid", 1);
});

$t->driver()->close();
done_testing();
