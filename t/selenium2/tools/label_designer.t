use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;
use Data::Dumper;

my $f = SGN::Test::Fixture->new();

my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub {
    $t->get_ok('/tools/label_designer');

    sleep(3);

    $t->driver->find_element("//button[\@title='Select a data source']")->click();

    sleep(1);

    $t->driver->find_element("//li[\@data-original-index='5']")->click();

    sleep(12);

    $t->find_element_ok("page_format", "id", "select a page format")->send_keys('US Letter PDF');

    sleep(1);

    $t->find_element_ok("label_format", "id", "select a label format")->send_keys('1" x 2 5/8"');

    sleep(1);

    #add text

    $t->find_element_ok("d3-add-type-input", "id", "select a text element type")->send_keys('Text (PDF)');

    sleep(1);

    $t->driver->find_element("//select[\@id='d3-add-field-input']")->click();

    sleep(1);

    $t->find_element_ok("d3-add-field-input", "id", "select a text element field")->send_keys('accession_name');

    sleep(1);

    $t->find_element_ok("d3-add-size-input", "id", "clear size field")->clear();

    sleep(1);

    $t->find_element_ok("d3-add-size-input", "id", "select a text element size")->send_keys('64');

    sleep(1);

    $t->find_element_ok("d3-add-font-input", "id", "select a text element font")->send_keys('Times-Bold');

    sleep(1);

    $t->find_element_ok("d3-add", "id", "add text")->click();

    sleep(1);

    #add barcode

    $t->find_element_ok("d3-add-type-input", "id", "select a QRcode element type")->send_keys('2D Barcode (QRCode)');

    sleep(1);

    $t->driver->find_element("//select[\@id='d3-add-field-input']")->click();

    sleep(1);

    $t->find_element_ok("d3-add-field-input", "id", "select a QRcode element field")->send_keys('plot_name');

    sleep(1);

    $t->find_element_ok("d3-add-size-input", "id", "select a QRcode element size")->send_keys('Six');

    sleep(1);

    $t->find_element_ok("d3-add", "id", "add QRcode")->click();

    sleep(2);

    $t->find_element_ok("element1", "id", "click on new QRcode element")->click();

    sleep(1);

    # add custom text

    $t->find_element_ok("d3-add-type-input", "id", "select a  custom element type")->send_keys('Text (PDF)');

    sleep(1);

    $t->find_element_ok("d3-custom-field", "id", "add custom element")->click();

    sleep(1);

    $t->find_element_ok("d3-custom-input", "id", "add custom element text")->send_keys('Plot: ');

    sleep(1);

    $t->driver->find_element("//select[\@id='d3-custom-add-field-input']")->click();

    sleep(1);

    $t->find_element_ok("d3-custom-add-field-input", "id", "add custom element field")->send_keys('plot_number');

    sleep(2);

    $t->find_element_ok("d3-custom-field-save", "id", "add custom element save")->click();

    sleep(1);

    $t->find_element_ok("d3-add-size-input", "id", "clear size field again")->clear();

    sleep(1);

    $t->find_element_ok("d3-add-size-input", "id", "select a custom text element size")->send_keys('48');

    sleep(1);

    $t->find_element_ok("d3-add-font-input", "id", "select a custom element font")->send_keys('Times');

    sleep(1);

    $t->find_element_ok("d3-add", "id", "add custom element")->click();

    sleep(2);

    $t->find_element_ok("element2", "id", "click on new custom element")->click();

    sleep(1);

    #save to list, reload page

    $t->find_element_ok("save_design_name", "id", "enter list name")->send_keys('test_label');

    sleep(1);

    $t->find_element_ok("d3-save-button", "id", "save test label")->click();

    sleep(1);

    $t->driver->accept_alert();

    #load design from saved list, check to make sure elements exist

    $t->get_ok('/tools/label_designer');

    sleep(3);

    $t->driver->find_element("//button[\@title='Select a data source']")->click();

    sleep(1);

    $t->driver->find_element("//li[\@data-original-index='5']")->click();

    sleep(12);

    $t->find_element_ok("design_list_list_select", "id", "select saved list")->send_keys('test_label');

    sleep(3);


    $t->find_element_ok("element0", "id", "check for first element")->click();

    sleep(1);

    $t->find_element_ok("element1", "id", "check for second element")->click();

    sleep(1);

    }

);

done_testing();
