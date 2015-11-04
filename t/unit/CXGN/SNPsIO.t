
use strict;
use Test::More;

use Data::Dumper;
use CXGN::SNPsIO;
use CXGN::SNPs;

my $io = CXGN::SNPsIO->new( { file => 't/data/test.file' }); #cassava_test.vcf' });

my @lines = ();
while (my $line = $io->next_line()) { 
    push @lines, $line;
}

like($io->header(), qr/header/, "header test");
like($lines[0], qr/1/, "first line test");
like($lines[9], qr/10/, "last line test");

$io->close();

my $io = CXGN::SNPsIO->new( { file => 't/data/test_missing_header.txt' }); 

eval { 
    while (my $snp_data = $io->next_line()) { 
	
    }
};

like($@, qr/Header not seen/, "missing header test");

$io->close();

$io = CXGN::SNPsIO->new( { file => 't/data/cassava_test.vcf' }); #cassava_test.vcf' });

my @lines = ();

my @ids  = qw(
S1_14740
S1_14743
S1_14746
S1_14748
S1_14749
S1_14750
S1_14755
S1_14757
S1_14895
S1_14897
S1_14900
S1_14901
S1_14907
S1_14909
S1_14911
    );

my @depths = (24235,24235,24206,24235,24235,24235,24235,24235,25058,25058,25037,25058,25058,25058,25058);

my $format = "GT:AD:DP:GQ:PL";

my @snp_raw = qw( 
0/0:3,0:3:88:0,9,108
0/0:3,0:3:88:0,9,108
0/0:3,0:3:88:0,9,108
0/0:3,0:3:88:0,9,108
0/0:3,0:3:88:0,9,108
0/0:3,0:3:88:0,9,108
0/0:3,0:3:88:0,9,108
0/0:3,0:3:88:0,9,108
./.:0,0:0:-1:-1,-1,-1
./.:0,0:0:-1:-1,-1,-1
./.:0,0:0:-1:-1,-1,-1
./.:0,0:0:-1:-1,-1,-1
./.:0,0:0:-1:-1,-1,-1
./.:0,0:0:-1:-1,-1,-1
./.:0,0:0:-1:-1,-1,-1
);

my @ref_counts = (3,3,3,3,3,3,3,3,0,0,0,0,0,0,0);
my @alt_counts = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);

my $line = 0;
while (my $snps = $io->next()) { 
    print STDERR "Processing snp ".$snps->id()."\n";
    is($snps->id, $ids[$line], "ID test");
    is($snps->depth, $depths[$line], "depth test");
    is($snps->format, $format, "format test");
    is($snps->snps->{'1002:250060174'}->vcf_string(), $snp_raw[$line], "raw data test line $line");
    is($snps->snps->{'1002:250060174'}->ref_count(), $ref_counts[$line], "ref_count test line $line");
    is($snps->snps->{'1002:250060174'}->alt_count(), $alt_counts[$line], "alt_count test line $line");
    is($snps->snps->{'1002:250060174'}->accession(), '1002:250060174', "accession test");
    my $af = $snps->calculate_allele_frequency_using_counts();
print STDERR " AF = $af\n";
    $snps->calculate_dosages();
#    print STDERR "Calculating Hardy Weinberg filter...\n";
    my %scores = $snps->hardy_weinberg_filter();
   print STDERR Dumper(\%scores);
    

    
    $line++;
}

done_testing();

