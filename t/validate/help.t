use strict;
use warnings;

use FindBin;
use lib 't/lib';
use SGN::Test qw/validate_urls/;
use Test::More;

my %urls = (
        "gbrowse help page"                       => '/help/gbrowse.pl',
);

validate_urls(\%urls, $ENV{ITERATIONS} || 1 );

done_testing;
