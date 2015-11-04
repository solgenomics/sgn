
use strict;

use Test::More;
use CXGN::Genotype::SNP;

my $snp = CXGN::Genotype::SNP->new();

$snp->from_vcf_string("0/0:3,0:3:88:0,9,108");

is($snp->ref_count(), 3, "ref count test");
is($snp->alt_count(), 0, "alt count test");

done_testing();
