use strict;
use warnings;

use FindBin;
use lib 't/lib';
use SGN::Test qw/validate_urls/;
use Test::More;

my %urls = (
        "alignment viewer input page"              => "/tools/align_viewer/",
);

my $iteration_count;

plan( tests => scalar(keys %urls)*3*($iteration_count = $ENV{ITERATIONS} || 1));

validate_urls(\%urls, $iteration_count);

