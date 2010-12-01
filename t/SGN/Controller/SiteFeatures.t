use strict;
use warnings;
use Test::More;

use lib 't/lib';
use SGN::Test 'request';
BEGIN { use_ok 'SGN::Controller::SiteFeatures' }

ok( request('/api/v1/feature_xrefs?q=Solyc05g005010')->is_success, 'feature_xrefs requestssss should succeed' );
done_testing();
