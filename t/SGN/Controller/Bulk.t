use strict;
use warnings;
use Test::More;

use lib 't/lib';

use Catalyst::Test 'SGN';

use_ok 'SGN::Controller::Bulk';

use SGN::Test qw/ request /;

ok( request('/bulk')->is_success, 'Request should succeed' );
done_testing();
