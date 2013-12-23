
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test qw/ validate_urls /;

validate_urls( { 'vigs input page' => '/tools/vigs' });

done_testing;
