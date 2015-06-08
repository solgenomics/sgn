
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

while (my $line = $io->next_line()) { 
    my $snps = CXGN::SNPs->new( { accessions => $io->lines() });
    $snps->from_vcf_line($line);
    my $af = $snps->calculate_allele_frequency();
    
    $snps->calculate_dosages();
    $snps->hardy_weinberg_filter();
    

}

done_testing();

