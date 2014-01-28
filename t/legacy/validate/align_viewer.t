use strict;
use warnings;

use FindBin;
use lib 't/lib';
use SGN::Test qw/validate_urls/;
use Test::More;

my %urls = (
        "alignment viewer input page"              => "/tools/align_viewer/",
);

validate_urls(\%urls, $ENV{ITERATIONS} || 1);

done_testing;
