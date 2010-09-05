use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'SGN' }
BEGIN { use_ok 'SGN::Controller::Project::Secretom' }

ok( request('/project/secretom')->is_success, 'Request should succeed' );
done_testing();
