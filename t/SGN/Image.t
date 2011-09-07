use lib 't/lib';

use SGN::Test;
use Test::Most tests => 3;
use SGN::Test::WWW::Mechanize;
use Data::Dumper;

use_ok 'SGN::Image';

my $image = SGN::Image->new(undef, 1);
isa_ok($image, 'SGN::Image');

my $url = $image->get_image_url('medium');
like($url, qr{medium}, 'getting a medium image');
