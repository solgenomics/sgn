#!/usr/bin/perl
use strict;
use warnings;
use English;
use FindBin;

use CXGN::Tools::Run;

use Test::More tests => 4 ;

BEGIN {
  use_ok( 'SGN::IntronFinder::Homology' );
}

my $ests_file = "t/data/ests.seq";
open my $ests, '<', $ests_file
  or die "$! opening $ests_file";


my $if_out;
open my $if_fh, '>', \$if_out or die "$! opening filehandle to string";
SGN::IntronFinder::Homology::find_introns_txt( $ests, $if_fh, 1e-50, "t/data/feature_file.txt", File::Spec->tmpdir, 't/data/ath_prots');


#print $if_out;
like $if_out, qr/1 results returned for query SGN-E708292/;
like $if_out, qr/1 results returned for query SGN-E703230/;
like $if_out, qr/SGN-E\d+:\s+\d\|[A-Z]{30,}/;

