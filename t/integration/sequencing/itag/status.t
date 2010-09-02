use strict;
use warnings;

use lib  "t/lib";
use SGN::Test::WWW::Mechanize;
use Test::More;

my $base = '/sequencing/itag/status.pl';
my $mech = SGN::Test::WWW::Mechanize->new;

#also, just make sure the status_html.pl page doesn't crash
$mech->get('/sequencing/itag/status_html.pl');
$mech->content_like(qr/ITAG feature not enabled|Pipeline Status/, 'status_html.pl does not crash' );

SKIP: {
    skip 'ITAG web feature not enabled, skipping tests', 6 if $mech->content =~ /ITAG feature not enabled/;

    $mech->get('/sequencing/itag/status.pl?op=lp');
    $mech->content_like( qr/^(\d+\n)*$/, 'lp looks OK');
    chomp(my $lp = $mech->content);
    my @pipelines = map $_+0, split /\n/,$lp;

    skip 'no ITAG pipelines found, skipping rest of tests', 5 unless @pipelines;

    my $testpipe = $pipelines[0];
    $mech->get("$base?op=lb&pipe=$testpipe");
    $mech->content_like( qr/^(\d+\n)*$/, 'lb looks OK');

    my ($testbatch) = map $_+0, split /\n/, $mech->content;
  SKIP: {
	skip 'no batches found, skipping rest of tests', 4 unless $testbatch;

    $mech->get("$base?op=la&pipe=$testpipe");
    $mech->content_like( qr/seq\n/, 'la contains the seq analysis');
    $mech->content_like( qr/(\w+\n)+/, 'la looks ok');

    $mech->get("$base?op=astat&pipe=$testpipe&batch=$testbatch&atag=seq");
    $mech->content_is( "done\n", 'test astat op');

    $mech->get("$base?op=lbs&pipe=$testpipe&batch=$testbatch");
    $mech->content_like( qr/([\w\.]+\n){3,}/, 'lbs looks OK');
    }
}

done_testing;
