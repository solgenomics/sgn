use strict;
use warnings;
use Test::More;

use lib 't/lib';

use Catalyst::Test 'SGN';

use_ok 'SGN::Controller::Bulk';
use aliased 'SGN::Test::WWW::Mechanize' => 'Mech';

my $mech = Mech->new;

$mech->with_test_level( local => sub {
    $mech->get_ok('/bulk/feature');

    $mech->post_ok('/bulk/feature/download');
});

done_testing();
