
use strict;

use Test::More qw | no_plan |;

use lib 't/lib';

use SGN::Test::Fixture;

my $fix = SGN::Test::Fixture->new();

is(ref($fix->config()), "HASH", 'hashref check');
