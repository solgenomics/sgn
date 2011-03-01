use strict;
use warnings;

use Test::More tests=>5;

use lib 't/lib';

use SGN::Test::WWW::Mechanize;
use SGN::Test;


my $m = SGN::Test::WWW::Mechanize->new();

$m->get_ok("/search/direct_search.pl?search=images");

my $form = { form_number=>2,
	     fields => { },
};

$m->submit_form_ok($form);
my $image_id;
if ($m->content()=~/image_id=(\d+)/) { 
    $image_id=$1;
}
		 
$m->get_ok("/image/ajax/fetch_image.pl?image_id=$image_id");

$m->content_contains('html');
$m->content_contains('img src');




