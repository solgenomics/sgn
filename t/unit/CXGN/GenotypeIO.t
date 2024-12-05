
use strict;
use Test::More;
use Data::Dumper;
use CXGN::GenotypeIO;

my $gtio = CXGN::GenotypeIO->new( { file => "t/data/cassava_test.vcf", format => 'vcf'});

is(scalar(@{$gtio->markers}), 14, "vcf marker count 1");
is($gtio->markers->[0], "S1_14740", "vcf first marker name");
is($gtio->markers->[-1], "S1_14909", "vcf last marker name");
is($gtio->accessions->[0], "1002:250060174", "vcf first accession name");
is($gtio->accessions->[-1], "Ug120191:250144197", "vcf last accession name");
is(scalar(@{$gtio->accessions}), 9990, "vcf accession count");
if (my $gt = $gtio->next()) { 
    #print STDERR Dumper($gt->markers());
    is(scalar(@{$gt->markers()}), 14, "marker count in genotype");
}

my $gtio2 = CXGN::GenotypeIO->new( { file => "t/data/dosage_transposed.csv", format=>'dosage_transposed' } );

#print STDERR "Markers: ".(Dumper($gtio->markers()))."\n";
is(scalar(@{$gtio2->accessions()}), 9, "dosage_transposed accession count");
is(scalar(@{$gtio2->markers()}), 3839, "dosage_transposed marker count");

is($gtio2->markers()->[0], "S10_14045", "dosage_transposed first marker");
is($gtio2->markers()->[-1], "S10_23448593", "dosage_transposed last marker");
is($gtio2->accessions()->[0], "1002.250060174", "dosage_transposed first accession");
is($gtio2->accessions()->[-1], "1024.250060172", "dosage_transposed last accession");

my @gts;
while(my $gt = $gtio2->next()) { 
    print STDERR $gt->name()."\n";
    push @gts, $gt;
}

is($gts[0]->name(), "1002.250060174", "genotype object accession name");
is($gts[1]->rawscores()->{S10_131712}, 0.06, "genotype object markerscore 1");
is($gts[7]->rawscores()->{S10_14045}, 0.2, "genotype object markerscore 2");

my $gtio3 = CXGN::GenotypeIO->new( { file => "t/data/dosage_transposed.csv", format=>'blablabla' });

done_testing();
