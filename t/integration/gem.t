#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 15;
use Test::WWW::Mechanize;
my $base_url = $ENV{SGN_TEST_SERVER};
my $mech = Test::WWW::Mechanize->new;

# TODO: It would be nice if this didn't depend on production data

$mech->get_ok("$base_url/gem/target.pl?name=Atlas%20143.CEL");
$mech->content_like(qr/Expression Target: Atlas 143\.CEL/);
$mech->content_unlike( qr/ERROR PAGE/ );

$mech->get_ok("$base_url/gem/target.pl?id=1");
$mech->content_like(qr/Expression Target: Atlas 143\.CEL/);
$mech->content_unlike( qr/ERROR PAGE/ );

$mech->get_ok("$base_url/gem/experiment.pl?id=1");
$mech->content_unlike( qr/ERROR PAGE/ );
$mech->content_like( qr/Expression Experiment: TobEA cauline leaf/ );

$mech->get_ok("$base_url/gem/experiment.pl?name=TobEA%20cauline%20leaf");
$mech->content_unlike( qr/ERROR PAGE/ );
$mech->content_like( qr/Expression Experiment: TobEA cauline leaf/ );

$mech->get_ok("$base_url/gem/experiment.pl?name=foob");
$mech->content_unlike( qr/ERROR PAGE/ );
$mech->content_like( qr/No experiment data for the specified parameters/);

$mech->get_ok("$base_url/gem/platform.pl?name=Affymetrix%20TobEA");
$mech->content_like(qr/Expression Platform: Affymetrix TobEA/);
$mech->content_unlike( qr/ERROR PAGE/ );

$mech->get_ok("$base_url/gem/platform.pl?id=1");
$mech->content_like(qr/Expression Platform: Affymetrix TobEA/);
$mech->content_unlike( qr/ERROR PAGE/ );


