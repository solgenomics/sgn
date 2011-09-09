use strict;
use warnings;
use Test::More;

use lib 't/lib';

use Catalyst::Test 'SGN';

use_ok 'SGN::Controller::Bulk';

use SGN::Test qw/ request /;

my $r = request('/bulk/feature');

is( $r->code, 200, 'Request should succeed' ) or diag $r->content;

done_testing();
