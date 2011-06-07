use Modern::Perl;
use lib 't/lib';
use SGN::Test;
use Test::Most;


BEGIN { use_ok 'Catalyst::Test', 'SGN' }
BEGIN { use_ok 'SGN::Controller::Search' }

ok( request('/search/')->is_success, 'Request should succeed' );
done_testing();
