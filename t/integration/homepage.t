#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 10;
use Test::WWW::Mechanize;
use lib 't/lib';
my $base_url = $ENV{SGN_TEST_SERVER};
my $mech = Test::WWW::Mechanize->new;
my @sections =  ("News", "Events", "Locus of the week", "Featured publication", "Image of the week", "Featured lab", "SGN Links", "External Links", "Affiliated Sites", "Mirror Site");


$mech->get($base_url);
for my $section (@sections) {
    $mech->content_like( qr/$section/ , "homepage includes $section");
}
