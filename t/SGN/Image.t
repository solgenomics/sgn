use lib 't/lib';

use SGN::Test;
use SGN::Context;
use SGN::Test::Data qw/create_test/;
use Test::Most tests => 5;
use SGN::Test::WWW::Mechanize;
use Data::Dumper;

use_ok 'SGN::Image';

my $organism = create_test('Organism::Organism',{ } );

my $image = SGN::Image->new(undef, $organism->organism_id);

# The SGN::Image api will probably be changed in the future so that no dbh needs
# to be passed in

isa_ok($image, 'SGN::Image');

lives_ok( sub { $image->process_image("t/data/plant.jpg", "organism", $organism->organism_id) }, 'process_image lives' );

my $url = $image->get_image_url('medium');
like($url, qr{medium}, 'getting a medium image');

can_ok( $image, qw/get_organisms get_stocks get_experiments get_loci process_image config associate_experiment/);

# we can't use $image->hard_delete because that connects as web_usr which doesn't
# have permissions to delete images

my $dbh = SGN::Context->new->dbc('sgn_test')->dbh;
my $oid = $organism->organism_id;
my $iid = $image->get_image_id;
$dbh->do("delete from metadata.md_image_organism where organism_id = $oid");
$dbh->do("delete from metadata.md_image where image_id = $iid");
