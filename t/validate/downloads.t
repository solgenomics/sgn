use strict;
use warnings;

use FindBin;
use lib 't/lib';
use SGN::Test qw/validate_urls/;
use Test::More;

my %urls = (

        'perlcyc download page'                    => '/downloads/perlcyc.pl',
        'download index'                           => '/downloads/index.pl',
);

validate_urls(\%urls, $ENV{ITERATIONS} || 1 );

done_testing;
