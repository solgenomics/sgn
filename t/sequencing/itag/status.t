use strict;
use warnings;

use CXGN::VHost::Test;
use Test::More tests => 6;

my $base = '/sequencing/itag/status.pl';

my $lp = get('/sequencing/itag/status.pl?op=lp');
like( $lp, qr/^(\d+\n)*$/, 'lp looks OK');

chomp $lp;
my @pipelines = map $_+0, split /\n/,$lp;

SKIP: {
    skip 'no ITAG pipelines found, skipping rest of tests', 5 unless @pipelines;

    my $testpipe = $pipelines[0];
    my $lb = get("$base?op=lb&pipe=$testpipe");
    like( $lb, qr/^(\d+\n)*$/, 'lb looks OK');

    my ($testbatch) = map $_+0, split /\n/, $lb;
  SKIP: {
	skip 'no batches found, skipping rest of tests', 4 unless $testbatch;

	my $la = get("$base?op=la&pipe=$testpipe");
	like( $la, qr/seq\n/, 'la contains the seq analysis');
	like( $la, qr/(\w+\n)+/, 'la looks ok');

	my $astat = get("$base?op=astat&pipe=$testpipe&batch=$testbatch&atag=seq");
	is( $astat, "done\n", 'test astat op');

	my $lbs = get("$base?op=lbs&pipe=$testpipe&batch=$testbatch");
	like( $lbs, qr/([\w\.]+\n){3,}/, 'lbs looks OK');
    }
}


