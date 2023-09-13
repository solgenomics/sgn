use lib 't/lib';

use Test::More 'tests' => 12;

use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub {
    sleep(2);

    $t->get_ok('stock/38879/view');
    sleep(2);

    my $images_onswitch = $t->find_element_ok("stock_images_section_onswitch",  "id",  "click to open image panel");
    $images_onswitch->click();
    sleep(3);

    $t->find_element_ok("add_new_image_button", "id", "find add image button and click")->click();
    sleep(1);

    # Add new image
    my $upload_input = $t->find_element_ok("file", "name", "find image input");
    my $filename = $f->config->{basepath}."/t/data/tv_test_1.png";

    $t->driver()->upload_file($filename);
    $upload_input->send_keys($filename);
    sleep(1);

    $t->find_element_ok("upload_image_submit", "id", "submit image upload")->click();
    sleep(2);

    $t->find_element_ok("store_image_submit", "id", "store image upload")->click();
    sleep(3);

    # check image redirected page for image content
    my $page_title = $t->find_element_ok(
        'pagetitle',
        'id',
        "find content of image name")->get_attribute('innerHTML');

    ok($page_title =~ /tv_test_1.png/, "Verify page title name: tv_test_1.png");

    # check image content on base page for stock view in image section
    $t->get_ok('stock/38879/view');
    sleep(3);

    $images_onswitch = $t->find_element_ok("stock_images_section_onswitch",  "id",  "click to open image panel");
    $images_onswitch->click();
    sleep(3);

    my $image_section = $t->find_element_ok(
        'stock_images_section_content',
        'id',
        "find content of image section")->get_attribute('innerHTML');

    ok($image_section =~ /tv_test_1.png/, "Verify image file name in image section: tv_test_1.png");

    }
);

$t->driver->close();
done_testing();
