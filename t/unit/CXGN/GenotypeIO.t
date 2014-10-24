
use strict;
use Test::More;
use Data::Dumper;
use CXGN::GenotypeIO;

my $gtio = CXGN::GenotypeIO->new( { file => "t/data/cassava_test.vcf", format => 'vcf'});

is($gtio->count(), 9990, "genotype count test");

if (my $gt = $gtio->next()) { 
    #print STDERR Dumper($gt->markers());
    is(scalar(@{$gt->markers()}), 15, "marker count test");
}
done_testing();
