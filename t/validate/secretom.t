use strict;
use warnings;

use lib 't/lib';
BEGIN { $ENV{SGN_SKIP_CGI}=1 }
use SGN::Test qw/validate_urls/;
use Test::More;

my %urls = (
        "secretom main page"  => "/secretom",
        "secretom outreach"   => "/secretom/outreach",
        "secretom secretary"  => "/secretom/secretary",
        "secretom training"   => "/secretom/training",
        ( map { ("secretom $_" => "/secretom/detail/$_") }
          ( qw(
             cell_wall
             cuticle
             functional_screens
             glycoproteome
             phytophthora_interaction
             prediction
             profiling
             proteomics
             secretion_path
             spinoffs
            )
           )
         ),
);

validate_urls(\%urls, $ENV{ITERATIONS} || 1 );

done_testing;
