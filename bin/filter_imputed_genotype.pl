#!/usr/bin/perl


=head1
filter_imputed_genotype.pl - filters SNPs based on DR2 and MAF cutoffs from genotype data file.

=head1 SYNOPSIS
perl filter_imputed_genotype.pl -i unfiltered.vcf -o filtered.vcf -d 0.75 -f 0.005 -h 1e-20

=head1 COMMAND-LINE OPTIONS
-i vcf file with imputed (using beagle 5.0 or later) genotype data. Required.
-o vcf file to write filtered output to. Optional. By default it writes to [unfiltered]_filtered.vcf
-d DR2 (dosage R-squared) threshold.  SNPs with greater than the threshold will be kept. Defaults to 0.75.
-f MAF (minor allele frequency) threshold. SNPs with greater than the threshold will be kept. Defaults to 0.005. Optional. 
-h HWE (Hardy Weinberg Equilibrium) threshold. NOT used for now.

=head1 DESCRITPION
Filters SNPs based on DR2 and MAF cutoffs from genotype data. 
Requires that the file is a vcf file and in the INFO column there are DR2 and AF.
It generates two files, one with SNPs that have DR2 and MAF above the cutoffs and another file
with the ones below the thresholds of either DR2 or MAF.

=head1 AUTHOR
Isaak Y Tecle <iyt2@cornell.edu>

=cut

use strict;

use Getopt::Std;
use File::Slurp qw /read_file write_file/;


our($opt_i, $opt_o,$opt_d, $opt_f, $opt_h);

getopts('i:d:f:h:o:');

if (!$opt_i || -s $opt_i < 1 ) {
die "Either the imputed genotype file is not provided or is empty.";
}

my $maf_cutoff = $opt_f ? $opt_f : 0.005;
my $dr2_cutoff = $opt_d ? $opt_d : 0.75;

my $file_prefix = $opt_i =~ s/\.vcf//r;

if (!$opt_o) {   
    $opt_o = $file_prefix . "_filtered.vcf";
}

my $kept_snps_file = $opt_o;
my $removed_snps_file = $file_prefix . "_removed.vcf";

open(my $I, "<", $opt_i) || die "Can't open imputed vcf_file: $opt_i\n";

my $info_idx = 7;
my $format_idx = 8;

my $removed_snp_cnt = 0;
my $kept_snp_cnt = 0;
my $total_snp_cnt = 0;
my $removed_snps;
my $kept_snps;

while (<$I>) {
   if ($_ =~ /#/) {
        $removed_snps .= $_;
        $kept_snps .= $_;  
    } else {
        $total_snp_cnt++;
        my @cols = split(/\t/, $_);
        my $info_col = $cols[$info_idx];
        # my $format_col = $cols[$format_idx];

        my ($dr2, $alt_freq, $imp) = split(/;/, $info_col);
        $dr2 =~ s/DR2=//;
        $alt_freq =~ s/AF=//;

        my $maf = $alt_freq < 0.5 ? $alt_freq : 1 - $alt_freq;
        
        if ($dr2 < $dr2_cutoff || $maf < $maf_cutoff) {
            print STDERR "\nREMOVING SNP $cols[1] --info: $info_col --DR2: $dr2 --MAF: $maf --alt-freq(AF): $alt_freq";
            $removed_snp_cnt++;
            $removed_snps .= $_;
        } else {
            print STDERR "\nKEEPING SNP $cols[1] --info: $info_col --DR2: $dr2 --MAF: $maf --alt-freq(AF): $alt_freq";
            $kept_snp_cnt++;
            $kept_snps .= $_;  
        }
        
    }
}

print STDERR "\n\nFiltering criteria: Remove SNPs with DR2 < $dr2_cutoff or MAF < $maf_cutoff";
print STDERR "\n\nRemoved $removed_snp_cnt SNPs out of $total_snp_cnt.";
print STDERR "\nKept $kept_snp_cnt SNPs out of $total_snp_cnt.";

write_file($kept_snps_file, $kept_snps);
write_file($removed_snps_file, $removed_snps);
print STDERR"\n\nWrote filtered (kept) SNPs to $kept_snps_file";
print STDERR"\nWrote removed SNPs to $removed_snps_file";
print STDERR"\nDone!\n\n";