use strict;
use warnings;

use FindBin;
use lib 't/lib';
use SGN::Test qw/validate_urls/;
use Test::More;

my %urls = (
        "marker search page"                       => "/search/direct_search.pl?search=markers",
        "marker search"                            => "/search/markers/markersearch.pl?w822_nametype=starts+with&w822_marker_name=&w822_mapped=on&w822_species=Any&w822_protos=Any&w822_colls=Any&w822_chromos=Any&w822_pos_start=&w822_pos_end=&w822_confs=-1&w822_maps=Any&w822_submit=Search",
        "marker detail rflp"                       => "/marker/SGN-M109/details",
        "marker view rflp"                         => "/marker/SGN-M538/rflp_image/view",
        "marker detail ssr"                        => "/marker/SGN-M1151/details",
        "marker detail caps"                       => "/marker/SGN-M6469/details",
);

validate_urls(\%urls, $ENV{ITERATIONS} || 1 );

done_testing;
