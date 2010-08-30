use strict;
use warnings;

use FindBin;
use lib 't/lib';
use SGN::Test qw/validate_urls/;
use Test::More;

my %urls = (
        "marker search page"                       => "/search/direct_search.pl?search=markers",
        "marker search"                            => "/search/markers/markersearch.pl?w822_nametype=starts+with&w822_marker_name=&w822_mapped=on&w822_species=Any&w822_protos=Any&w822_colls=Any&w822_chromos=Any&w822_pos_start=&w822_pos_end=&w822_confs=-1&w822_maps=Any&w822_submit=Search",
        "marker detail rflp"                       => "/search/markers/markerinfo.pl?marker_id=109",
        "marker view rflp"                         => "/search/markers/view_rflp.pl?marker_id=538",
        "marker detail ssr"                        => "/search/markers/markerinfo.pl?marker_id=1151",
        "marker detail caps"                       => "/search/markers/markerinfo.pl?marker_id=6469",
);

validate_urls(\%urls, $ENV{ITERATIONS} || 1 );

done_testing;
