use strict;
use warnings;
use Test::More;

use lib 't/lib';

use Catalyst::Test 'SGN';

use_ok 'SGN::Controller::Bulk';
use aliased 'SGN::Test::WWW::Mechanize' => 'Mech';

my $mech = Mech->new;

$mech->with_test_level( local => sub {
    my $r = request('/bulk/feature');
    is( $r->code, 200, $r->content );
});

done_testing();
