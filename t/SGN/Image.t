use lib 't/lib';

use SGN::Test;
use Test::Most tests => 4;
use SGN::Test::WWW::Mechanize;
use Data::Dumper;

use_ok 'SGN::Image';

# The SGN::Image api will probably be changed in the future so that no dbh needs
# to be passed in

my $image = SGN::Image->new(undef, 1);
isa_ok($image, 'SGN::Image');

my $url = $image->get_image_url('medium');
like($url, qr{medium}, 'getting a medium image');

can_ok( $image, qw/get_organisms get_stocks get_experiments get_loci/);
