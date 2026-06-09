use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub {
    $t->get_ok('stock/38879/view');

    $t->wait_for_network_idle();
    my $images_onswitch = $t->find_element_ok("stock_images_section_onswitch",  "id",  "click to open image panel");
    $images_onswitch->click();

    $t->click_ok("add_new_image_button", "id", "find add image button and click");

    # Add new image
    my $filename = $f->config->{basepath}."/t/data/cassava_image.jpg";
    $t->send_keys_ok("file", "name", $filename, "input image filename");
    $t->driver()->upload_file($filename);

    $t->click_ok("upload_image_submit", "id", "submit image upload");
    $t->wait_for_network_idle();
    $t->click_ok("store_image_submit", "id", "store image upload");
    $t->wait_for_network_idle();

    # check image redirected page for image content
    my $page_title = $t->get_attribute_ok(
        'pagetitle',
        'id',
        'innerHTML',
        "find content of image name");

    ok($page_title =~ /cassava_image.jpg/, "Verify page title name: cassava_image.jpg");

    # check image content on base page for stock view in image section
    $t->get_ok('stock/38879/view');

    $t->wait_for_network_idle();
    $t->click_ok("stock_images_section_onswitch",  "id",  "click to open image panel");
    $t->wait_for_network_idle();

    my $image_section = $t->get_attribute_ok(
        'stock_images_section_content',
        'id',
        'innerHTML',
        "find content of image section");

    ok($image_section =~ /cassava_image.jpg/, "Verify image file name in image section: cassava_image.jpg");

    }
);

$t->driver->close();
done_testing();
