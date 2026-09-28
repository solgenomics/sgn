use strict;
use warnings;

use lib 't/lib';

use Test::More;
use Data::Dumper;
use JSON;
use LWP::UserAgent;
use Test::WWW::Mechanize;

use SGN::Test::Fixture;
use SGN::Test::WWW::WebDriver;

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();

my $base_url = $ENV{SGN_TEST_SERVER} || 'http://localhost:3010';
my $basepath = $f->config->{basepath};

my $schema = $f->bcs_schema();

# The genotype-data upload step needs a genotyping-data project and an existing protocol 
# from a table -- there's no way to create a new one from that dialog. So create one here, 
# the same way the other tests do.
my $mech = Test::WWW::Mechanize->new;
$mech->post_ok("$base_url/brapi/v1/token", [ "username" => "janedoe", "password" => "secretpw", "grant_type" => "password" ], "brapi login for prerequisite setup");
my $token_response = decode_json $mech->content;
is($token_response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull', "brapi login succeeded");
my $sgn_session_id = $token_response->{access_token};

my $location_id = $schema->resultset('NaturalDiversity::NdGeolocation')->search({ description => 'Cornell Biotech' })->first->nd_geolocation_id();
my $breeding_program_id = $schema->resultset('Project::Project')->search({ name => 'test' })->first->project_id();

my $intertek_project_name = "Selenium Upload Factory Intertek Project";
my $intertek_protocol_name = "Selenium Upload Factory Intertek Protocol";
my $intertek_grid_file = "$basepath/t/data/genotype_data/Intertek_SNP_grid.csv";
my $intertek_info_file = "$basepath/t/data/genotype_data/Intertek_SNP_info.csv";

my $ua = LWP::UserAgent->new;
my $intertek_setup_response = $ua->post(
    "$base_url/ajax/genotype/upload",
    Content_Type => 'form-data',
    Content => [
        upload_genotype_intertek_file_input => [ $intertek_grid_file, 'genotype_intertek_grid_data_upload' ],
        upload_genotype_intertek_snp_file_input => [ $intertek_info_file, 'genotype_intertek_snp_info_data_upload' ],
        "sgn_session_id" => $sgn_session_id,
        "upload_genotypes_species_name_input" => "Manihot esculenta",
        "upload_genotype_vcf_project_name" => $intertek_project_name,
        "upload_genotype_location_select" => $location_id,
        "upload_genotype_year_select" => "2018",
        "upload_genotype_breeding_program_select" => $breeding_program_id,
        "upload_genotype_vcf_observation_type" => "accession",
        "upload_genotype_vcf_facility_select" => "IGD",
        "upload_genotype_vcf_project_description" => "Selenium upload factory prerequisite",
        "upload_genotype_vcf_protocol_name" => $intertek_protocol_name,
        "upload_genotype_vcf_reference_genome_name" => "Mesculenta_511_v7",
        "upload_genotype_add_new_accessions" => 1,
    ]
);
ok($intertek_setup_response->is_success, "prerequisite intertek genotype data request succeeded");
my $intertek_setup_message = decode_json $intertek_setup_response->decoded_content;
ok($intertek_setup_message->{success}, "prerequisite intertek project/protocol created")
    or diag(Dumper $intertek_setup_message);

#
# Selenium helpers
#

sub archive_file {
    my ($relative_path) = @_;
    my $filename = "$basepath/$relative_path";

    # The archive file input has the "multiple" attribute, and repeated send_keys() calls append
    # to its selection rather than replacing it, so clear it first to avoid re-archiving every
    # file from earlier steps each time.
    $t->driver()->execute_script("document.getElementById('upload_factory_archive_new_file').value = '';");
    sleep(1);

    $t->driver()->upload_file($filename);
    my $file_input = $t->find_element_ok("upload_factory_archive_new_file", "id", "find archive file input for $relative_path");
    $file_input->send_keys($filename);
    sleep(1);
    my $archive_btn = $t->find_element_ok("upload_factory_new_file_btn", "id", "click archive button for $relative_path");
    # By the second archive_file() call, prior interactions elsewhere on the page (report
    # dialogs, table refreshes, etc.) have left the page scrolled away from the top, so a plain
    # click() scrolls this button up under the fixed top navbar and Selenium reports it as
    # obscured. Scroll it into view and back off the navbar's height first, as done elsewhere
    # in the selenium suite (e.g. t/selenium2/solgs/genetic_gain.t).
    $t->driver()->execute_script("arguments[0].scrollIntoView(true);window.scrollBy(0,-70);", $archive_btn);
    sleep(1);
    $archive_btn->click();
    sleep(10);
}

sub find_archived_file_id {
    my ($basename) = @_;
    my $select = $t->find_element_ok(
        "//tr[.//a[contains(text(),'$basename')]]//select[contains(\@id,'upload_select_type_')]",
        "xpath",
        "find upload-type select for $basename"
    );
    my $id_attr = $select->get_attribute('id');
    my ($file_id) = $id_attr =~ /upload_select_type_(\d+)/;
    ok($file_id, "extracted archived file id for $basename");
    return $file_id;
}

sub set_upload_type_and_process {
    my ($file_id, $upload_type) = @_;
    $t->find_element_ok("upload_select_type_$file_id", "id", "click upload type select for file $file_id")->click();
    sleep(1);
    $t->find_element_ok("//select[\@id='upload_select_type_$file_id']/option[\@value='$upload_type']", "xpath", "select upload type $upload_type")->click();
    sleep(2);
    $t->find_element_ok("process_file_$file_id", "id", "click process button for file $file_id")->click();
    sleep(3);
}

sub refresh_tables {
    # refresh_upload_tables() takes the logged-in user's sp_person_id; calling it bare would
    # request .../undefined and leave the tables (and job_dict) empty. manage_upload.mas's own
    # fire_refresh() closes over the real id, so use that instead.
    $t->driver()->execute_script('fire_refresh();');
    sleep(3);
}

sub confirm_and_submit {
    $t->find_element_ok("submit_validate_upload", "id", "click submit on confirm-submission modal")->click();
    sleep(5);
    refresh_tables();
}

# Polls the given table's first (most-recently-created) row until its status column reaches a
# terminal state, forcing a table refresh each time rather than waiting on the page's own 60s
# auto-refresh. Returns whatever text was last read, terminal or not, so the caller's ok() can
# fail if the job never finishes.
sub wait_for_first_row_status {
    my ($table_id, $max_wait) = @_;
    $max_wait ||= 120;
    my $waited = 0;
    my $text = '';
    while ($waited < $max_wait) {
        sleep(8);
        $waited += 8;
        refresh_tables();
        my $rows = $t->driver()->find_elements("//table[\@id='$table_id']/tbody/tr[1]", "xpath");
        if (scalar(@$rows) > 0) {
            # These tables live inside a collapsible section that starts collapsed, so get_text()
            # (which only returns rendered text) can read empty even once the row exists.
            # textContent isn't affected by visibility.
            $text = $rows->[0]->get_attribute('textContent');
            last if $text =~ /finished|failed|timed_out|canceled/;
        }
    }
    return $text;
}

sub view_report_text_for_first_row {
    my ($table_id) = @_;
    $t->find_element_ok("//table[\@id='$table_id']/tbody/tr[1]//button[contains(\@id,'job_report_')]", "xpath", "click view-report button for first row of $table_id")->click();
    sleep(3);
    my $report_div = $t->find_element_ok("report_content_div", "id", "find report content div");
    my $report_html = $report_div->get_attribute('innerHTML');
    $t->find_element_ok("close_report_dialog_btn", "id", "close view-report dialog")->click();
    sleep(1);
    return $report_html;
}

sub commit_first_row {
    $t->find_element_ok("//table[\@id='upload_factory_validated_files_table']/tbody/tr[1]//button[contains(\@id,'validation_commit_')]", "xpath", "click commit-to-database button for first validated row")->click();
    sleep(5);
    refresh_tables();
}

sub click_select_option {
    my ($select_id, $option_xpath, $test_name) = @_;
    $t->find_element_ok($select_id, "id", "click $test_name select")->click();
    sleep(1);
    $t->find_element_ok($option_xpath, "xpath", "choose $test_name")->click();
    sleep(1);
}

$t->while_logged_in_as("curator", sub {
    sleep(2);

    # Create a genotyping project via the UI first, since the genotyping-plate upload step in the
    # Upload Factory requires an existing genotyping project to attach the plate layout to.
    my $genotyping_project_name = "NEXTGENCASSAVA";

    $t->get_ok('/breeders/genotyping_projects');
    sleep(2);

    $t->find_element_ok("create_genotyping_project_link", "name", "find create genotyping project link")->click();
    sleep(1);

    $t->find_element_ok('next_step_add_new_genotyping_project', 'id', 'go to next screen from Intro')->click();
    sleep(2);

    $t->find_element_ok('new_genotyping_project_name', 'id', 'find genotyping project name field')->send_keys($genotyping_project_name);
    sleep(1);

    click_select_option('genotyping_project_facility_select', '//select[@id="genotyping_project_facility_select"]/option[@value="None"]', "genotyping project facility");
    click_select_option('data_type', '//select[@id="data_type"]/option[@value="snp"]', "genotyping project data type");
    click_select_option('genotyping_project_breeding_program_select', '//select[@id="genotyping_project_breeding_program_select"]/option[@title="test"]', "genotyping project breeding program");
    click_select_option('genotyping_project_year_select', '//select[@id="genotyping_project_year_select"]/option[@title="2018"]', "genotyping project year");
    click_select_option('genotyping_project_location_select', '//select[@id="genotyping_project_location_select"]/option[@title="test_location"]', "genotyping project location");

    $t->find_element_ok('genotyping_project_description', 'id', 'find genotyping project description field')->send_keys("Selenium upload factory test genotyping project");

    $t->find_element_ok('add_new_genotyping_project_submit', 'id', 'submit new genotyping project')->click();
    sleep(4);

    $t->find_element_ok('add_new_genotyping_project_close_modal', 'id', 'close new genotyping project modal')->click();
    sleep(1);

    #
    # Upload Factory
    #

    $t->get_ok('/breeders/upload');
    sleep(5);

    ###################
    # 1) Trial upload
    ###################

    archive_file("t/data/trial/demo_multiple_trial_design.csv");
    my $trial_file_id = find_archived_file_id("demo_multiple_trial_design.csv");
    set_upload_type_and_process($trial_file_id, "trials");

    confirm_and_submit();

    my $trial_status = wait_for_first_row_status("upload_factory_completed_uploads_table");
    ok($trial_status =~ /finished/, "trial upload job finished")
        or diag("trial upload status row was: $trial_status");
    ok($trial_status =~ /Multiple Trial Upload/, "trial upload job is labeled as a trial upload");

    my $trial_report = view_report_text_for_first_row("upload_factory_completed_uploads_table");
    unlike($trial_report, qr/list-group-item-danger/, "trial upload report has no error text")
        or diag("trial upload report was: $trial_report");

    sleep(20);

    ######################
    # 2) Genotyping trial 
    ######################

    archive_file("t/data/genotype_trial_upload/NEW_CASSAVA_GS_74Template_selenium.xlsx");
    my $plate_file_id = find_archived_file_id("NEW_CASSAVA_GS_74Template_selenium.xlsx");
    set_upload_type_and_process($plate_file_id, "genotyping_plate");

    click_select_option('genotype_plate_upload_type_choice_select', '//select[@id="genotype_plate_upload_type_choice_select"]/option[@value="genotyping_plate_excel"]', "genotyping plate file format");

    sleep(5); # genotype_plate_upload_project_select_div is populated by an async get_select_box call

    click_select_option('genotype_plate_upload_project_id', "//select[\@id='genotype_plate_upload_project_id']/option[\@title='$genotyping_project_name']", "genotyping plate project");

    $t->find_element_ok('genotype_plate_upload_name', 'id', 'find genotyping plate ID field')->send_keys("SeleniumUploadFactoryPlate1");

    $t->find_element_ok('genotype_plate_upload_choices_next_btn', 'id', 'click next on genotyping plate choices')->click();
    sleep(2);

    confirm_and_submit();

    my $plate_validation_status = wait_for_first_row_status("upload_factory_validated_files_table");
    ok($plate_validation_status =~ /finished/, "genotyping plate validation job finished")
        or diag("genotyping plate validation status row was: $plate_validation_status");

    my $plate_validation_report = view_report_text_for_first_row("upload_factory_validated_files_table");
    unlike($plate_validation_report, qr/list-group-item-danger/, "genotyping plate validation report has no error text")
        or diag("genotyping plate validation report was: $plate_validation_report");
    like($plate_validation_report, qr/list-group-item-success/, "genotyping plate validation report shows success text")
        or diag("genotyping plate validation report was: $plate_validation_report");

    commit_first_row();

    my $plate_commit_status = wait_for_first_row_status("upload_factory_completed_uploads_table");
    ok($plate_commit_status =~ /finished/, "genotyping plate commit job finished")
        or diag("genotyping plate commit status row was: $plate_commit_status");
    ok($plate_commit_status =~ /Genotyping plate design made in Excel/, "genotyping plate job is labeled as a genotyping plate upload");

    my $plate_commit_report = view_report_text_for_first_row("upload_factory_completed_uploads_table");
    unlike($plate_commit_report, qr/list-group-item-danger/, "genotyping plate commit report has no error text")
        or diag("genotyping plate commit report was: $plate_commit_report");
    like($plate_commit_report, qr/list-group-item-success/, "genotyping plate commit report shows success text")
        or diag("genotyping plate commit report was: $plate_commit_report");

    sleep(20);

    #####################
    # 3) Genotyping data 
    #####################

    archive_file("t/data/genotype_data/Intertek_SNP_info.csv");
    sleep(3);
    archive_file("t/data/genotype_data/Intertek_SNP_grid.csv");

    my $intertek_file_id = find_archived_file_id("Intertek_SNP_grid.csv");
    set_upload_type_and_process($intertek_file_id, "genotyping_data");

    sleep(8); # genotype_data_project_select / genotype_data_protocol_select are async DataTables

    click_select_option('genotype_data_upload_type_choice_select', '//select[@id="genotype_data_upload_type_choice_select"]/option[@value="genotype_data_intertek"]', "genotype data file format");

    $t->find_element_ok(
        "//table[\@id='genotype_data_project_select']//tr[.//a[contains(text(),'$intertek_project_name')]]//input[\@type='checkbox']",
        "xpath",
        "check genotype data project checkbox"
    )->click();
    sleep(1);

    $t->find_element_ok(
        "//table[\@id='genotype_data_protocol_select']//tr[.//a[contains(text(),'$intertek_protocol_name')]]//input[\@type='checkbox']",
        "xpath",
        "check genotype data protocol checkbox"
    )->click();
    sleep(1);

    click_select_option('upload_genotype_location_select', '//select[@id="upload_genotype_location_select"]/option[@title="Cornell Biotech"]', "genotype data location");

    $t->find_element_ok(
        "//select[\@id='genotype_data_intertek_info_select']/option[contains(text(),'Intertek_SNP_info.csv')]",
        "xpath",
        "select intertek marker info file"
    )->click();
    sleep(1);

    $t->find_element_ok('genotype_data_upload_choices_next_btn', 'id', 'click next on genotype data choices')->click();
    sleep(2);

    confirm_and_submit();

    my $intertek_status = wait_for_first_row_status("upload_factory_completed_uploads_table");
    ok($intertek_status =~ /finished/, "genotype data (Intertek) upload job finished")
        or diag("genotype data upload status row was: $intertek_status");
    ok($intertek_status =~ /Intertek genotyping data/, "genotype data job is labeled as Intertek genotyping data");

    my $intertek_report = view_report_text_for_first_row("upload_factory_completed_uploads_table");
    unlike($intertek_report, qr/list-group-item-danger/, "genotype data upload report has no error text")
        or diag("genotype data upload report was: $intertek_report");
    like($intertek_report, qr/list-group-item-success/, "genotype data upload report shows success text")
        or diag("genotype data upload report was: $intertek_report");

    sleep(20);

    ##################################################################
    # 4) Image upload, expect to fail bc prerequisite trait not there
    ##################################################################

    archive_file("t/data/images/fieldbook/test_image_for_exif.jpg");
    my $image_file_id = find_archived_file_id("test_image_for_exif.jpg");
    set_upload_type_and_process($image_file_id, "images");

    click_select_option('upload_images_type', '//select[@id="upload_images_type"]/option[@value="images"]', "image upload type");

    $t->find_element_ok('image_upload_next_btn', 'id', 'click next on image choices')->click();
    sleep(2);

    confirm_and_submit();

    my $image_validation_status = wait_for_first_row_status("upload_factory_validated_files_table");
    ok($image_validation_status !~ /finished/, "image EXIF validation job failed as expected")
        or diag("image validation status row was: $image_validation_status");

    my $image_validation_report = view_report_text_for_first_row("upload_factory_validated_files_table");
    like($image_validation_report, qr/associated trait Test Image\|Timepoint 1\|image\|COMP:0000034 does not exist in the database/, "image validation report explains the associated trait was not found")
        or diag("image commit report was: $image_validation_report");

});

$f->clean_up_db();
$t->driver()->close();
done_testing();
