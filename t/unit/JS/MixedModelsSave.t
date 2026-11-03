use strict;
use warnings;
use Test::More;
my ($node) = grep {-x $_} map {"$_/node"} split /:/, $ENV{PATH};
plan skip_all => 'Node is not installed' unless $node;
is(system($node,'t/unit/JS/MixedModelsSave.cjs'),0,'actual mixed-model save handlers retain executed protocol, dataset and engine');
done_testing;
