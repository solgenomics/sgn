use strict;

use Test::More tests=>6;
use Test::WWW::Mechanize;

my $server = $ENV{SGN_TEST_SERVER} || die "need a SGN_TEST_SERVER environment variable";

my $m = Test::WWW::Mechanize->new();

$m->get_ok($server."/search/direct_search.pl?search=images");

my $form = { form_number=>2,
	     fields => { },
};

$m->submit_form_ok($form);
my $image_id;
if ($m->content()=~/image_id=(\d+)/) { 
    $image_id=$1;
}
		 
$m->get_ok($server."/image/ajax/fetch_image.pl?image_id=$image_id");

$m->content_contains('html');
$m->content_contains('img src');
$m->content_contains("image_files/$image_id");



