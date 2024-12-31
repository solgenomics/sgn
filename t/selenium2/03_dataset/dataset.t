use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use SGN::Test::WWW::WebDriver;
use CXGN::List;

my $d = SGN::Test::WWW::WebDriver->new();

my $f = SGN::Test::Fixture->new();

$d->while_logged_in_as("submitter", sub {

    $d->get_ok("/search/datasets", "get root url test");
    sleep(20);
    $d->logout_ok();
});

$d->driver->close();
done_testing();


