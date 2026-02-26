use strict;
use warnings;

use File::Temp;

use lib 't/lib';

use SGN::Test;
#use SGN::Context;
use SGN::Test::Data qw/create_test/;
use Test::Most tests => 5;
use Data::Dumper;
use SGN::Test::Fixture;
use Test::MockObject;

use_ok 'SGN::Image';

my $tempdir = File::Temp->newdir;
my $context = SGN::Context->new;

# make a mock context to munge the configuration for stuff to go into a tempdir
my $mock_context = Test::MockObject->new;
my $config = {
    static_datasets_path => "$tempdir",
    image_dir => 'images',
    basepath => "$tempdir",
    tempfiles_subdir => 'temp',
    static_datasets_url => 'fake_static_datasets_url',
};
$mock_context->mock( 'get_conf', sub { $config->{$_[1]} or die "$_[1] conf var not mocked" } );
$mock_context->mock( 'config', sub { $config } );
$mock_context->mock( 'dbc', sub { $context->dbc } );
$mock_context->mock( 'test_mode', sub {1} );

my $organism = create_test( 'Organism::Organism', {} );
my $image = SGN::Image->new(undef, $organism->organism_id, $mock_context );

# The SGN::Image api will probably be changed in the future so that no dbh needs
# to be passed in

isa_ok($image, 'SGN::Image');

lives_ok( sub { $image->process_image("t/data/tv_test_1.png", "organism", $organism->organism_id) }, 'process_image lives' );

my $url = $image->get_image_url('medium');
like($url, qr!^/fake_static_datasets_url/images/[a-f\d\/]+/medium\.jpg$!, 'getting a medium image');

can_ok( $image, qw/get_organisms get_stocks get_trials get_experiments get_loci process_image config associate_experiment/);

# we can't use $image->hard_delete because that connects as web_usr which doesn't
# have permissions to delete images

END {
    #my $dbh = SGN::Context->new->dbc('sgn_test')->dbh;
    my $dbh = SGN::Test::Fixture->new()->dbh();
    my $oid = $organism->organism_id;
    my $iid = $image->get_image_id;
    $dbh->do("delete from metadata.md_image_organism where organism_id = ?", undef, $organism->organism_id ) if $organism;
    $dbh->do("delete from metadata.md_image where image_id = ?",undef,$image->get_image_id) if $image;
}
