#!/usr/bin/env perl
use strict;
use warnings;
use Test::Most;

use lib 't/lib';
use SGN::Test;

BEGIN { use_ok 'Catalyst::Test', 'SGN' }

ok( request('/')->is_success, 'Request should succeed' );

done_testing();
