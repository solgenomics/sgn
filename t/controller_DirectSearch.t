use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'SGN' }
BEGIN { use_ok 'SGN::Controller::DirectSearch' }

ok( request('/directsearch')->is_success, 'Request should succeed' );
done_testing();
