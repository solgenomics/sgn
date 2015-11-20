use lib 't/lib';

use Test::More;

use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;

my $f = SGN::Test::Fixture->new();
my $t = SGN::Test::WWW::WebDriver->new();

$t->while_logged_in_as("submitter", sub { 
    $t->get_ok('stock/38879/view');

    $t->find_element_ok("Add new image", "partial_link_text", "find add image link")->click();

    sleep(1);
    
    my $filename = $f->config->{basepath}."/t/data/cassava_image.jpg";

    $t->find_element_ok("file", "name", "image input")->send_keys($filename);

    sleep(1);

    $t->find_element_ok("upload_image_submit", "id", "submit image upload")->click();

    sleep(1);

    $t->find_element_ok("store_image_submit", "id", "store image upload")->click();

    sleep(3);

    $t->find_element_ok("Stock name: UG120002.", "partial_link_text", "find stock image link")->click();

    sleep(3);

    $t->find_element_ok("Images", "partial_link_text", "see stock images")->click();

    sleep(2);


    }

);

done_testing();
