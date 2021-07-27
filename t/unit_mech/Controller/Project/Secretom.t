use strict;
use warnings;
use Test::More;

use lib 't/lib';
use SGN::Test qw/ request /;
BEGIN { use_ok 'SGN::Controller::Project::Secretom' }

ok( request('/secretom')->is_success, 'Request should succeed' );
done_testing();
