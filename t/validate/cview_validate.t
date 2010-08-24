use strict;
use warnings;

use FindBin;
use lib 't/lib';
use SGN::Test qw/validate_urls/;
use Test::More;

my %urls = (
        "cview index page"                         => "/cview/index.pl",
        "map overview F2-2000"                     => "/cview/map.pl?map_id=9",
        "comparative mapviewer"                    => "/cview/view_chromosome.pl?map_version_id=39",
        "map overview FISH map"                    => "/cview/map.pl?map_id=13",
        "physical map overview"                    => "/cview/map.pl?map_id=p9",
        "agp map overview"                         => "/cview/map.pl?map_id=agp",
);

my $iteration_count;

plan( tests => scalar(keys %urls)*3*($iteration_count = $ENV{ITERATIONS} || 1));

validate_urls(\%urls, $iteration_count);

