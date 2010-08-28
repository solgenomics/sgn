use strict;
use warnings;

use FindBin;
use lib 't/lib';
use SGN::Test qw/validate_urls/;
use Test::More;

my %urls = (
        "secretom"            => "/secretom/",
        "secretom outreach"   => "/secretom/outreach.pl",
        "secretom prediction" => "/secretom/prediction.pl",
        "secretom proteome"   => "/secretom/proteome.pl",
        "secretom search"     => "/secretom/search.pl",
        "secretom training"   => "/secretom/training.pl",
);

my $iteration_count;

plan( tests => scalar(keys %urls)*4*($iteration_count = $ENV{ITERATIONS} || 1));

validate_urls(\%urls, $iteration_count);

