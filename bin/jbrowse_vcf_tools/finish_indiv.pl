#!/usr/bin/perl

use warnings;
use strict;
use Getopt::Std;

our ($opt_v, $opt_d, $opt_f);

getopts('v:d:f:');

my $raw_vcf_file = $opt_v;
my $dosage_file = $opt_d;
my $starting_file = $opt_f;
my $imputed_file;
my $filtered_file;
my @genotypes;
my $placeholder;
my $num_seen = 1;
my $this_rep = $starting_file;
$this_rep =~ s/^.+rep(\d+).vcf.+$/$1/;
print STDERR "this rep = $this_rep \n";
if (length($this_rep) != 1) {
    $this_rep = 1;
}
print STDERR "this rep = $this_rep \n";

#-----------------------------------------------------------------------
# finish indiv vcf file
#-----------------------------------------------------------------------

my $vcf_file = $starting_file;
$vcf_file =~ s/^(.+)_(\d+)$/$1/;
print STDERR "finished filename = $vcf_file \n";

my $accession_name = $starting_file; 
$accession_name =~ s:^output/(.+)_2015_V6.+:$1:;
print STDERR "accession name = $accession_name \n";

my $column_number = $starting_file;
$column_number =~ s/^(.+)_(\d+)$/$2/;
print STDERR "column number = $column_number \n";

system ("cut -f 1-9,$column_number $raw_vcf_file | tail -n +15761 >> $starting_file");
system ("mv $starting_file $vcf_file");
print "$vcf_file finished!\n";

#-----------------------------------------------------------------------
# extract imputed SNP data pertaining to this accession from dosage file 
#-----------------------------------------------------------------------

open (IMPS, "<", $dosage_file) || die "Can't open $dosage_file!\n"; 
while (<IMPS>) {
	chomp;
	($placeholder, @genotypes) = split /\t/;
	unless ($placeholder eq $accession_name) {
		    next;
	}
	if ($this_rep > 1) {
	    if ($num_seen < $this_rep) {
		$num_seen++;
		next;
	    }
	}
	open (VCF, "<", $vcf_file) || die "Can't open $vcf_file!\n";
	$imputed_file = $vcf_file; 
	$imputed_file =~ s/.vcf/_imputed.vcf/;
	$filtered_file = $vcf_file;
	$filtered_file =~ s/.vcf/_filtered.vcf/;

	open (OUTFILE, ">", $imputed_file) || die "Can't open $imputed_file!\n";
	open (OUTFILE2, ">", $filtered_file) || die "Can't open $filtered_file!\n";
	
	LINE: while (<VCF>) {
	    if (m/^#/) {
		print OUTFILE $_;
		print OUTFILE2 $_;
	    } else {
		chomp;
		my ($CHROM, $POS, $ID, $REF, $ALT, $QUAL, $FILTER, $INFO, $FORMAT, $DATA) = split /\t/;
		if (length($ALT) > 1) {
		    shift @genotypes;
		    next LINE;
		} else {
       		    $_ = $DATA;
		    if (m/(^0|^1)/) {
			print OUTFILE join "\t", $CHROM, $POS, $ID, $REF, $ALT, $QUAL, $FILTER, $INFO, $FORMAT, $DATA;
			print OUTFILE "\n";
			print OUTFILE2 join "\t", $CHROM, $POS, $ID, $REF, $ALT, $QUAL, $FILTER, $INFO, $FORMAT, $DATA;
			print OUTFILE2 "\n";
			shift @genotypes;
		    } else {
			$_ = shift @genotypes;
			if ($_ <= 0.10) {
			    $DATA =~ s/\.\/\./0\/0/;
			} elsif ($_ >= 0.90 && $_ <= 1.10) {
			    $DATA =~ s/\.\/\./0\/1/;
			} elsif ($_ >= 1.90) {
			    $DATA =~ s/\.\/\./1\/1/;
			} else {
			    next LINE;
			}
			print OUTFILE join "\t", $CHROM, $POS, $ID, $REF, $ALT, $QUAL, $FILTER, $INFO, $FORMAT, $DATA;
			print OUTFILE "\n";
		    }
		}
	    }
	    next;
	}
	last;
}
close VCF;
close OUTFILE;
close OUTFILE2;

#----------------------------------------------------
# Report a completed accession and compress files
#----------------------------------------------------

print STDERR "$vcf_file filtered and imputed files finished\n";
system ( "bgzip $vcf_file" );
system ( "bgzip $imputed_file" );
system ( "bgzip $filtered_file" );
system ( "tabix -p vcf $vcf_file.gz" );
system ( "tabix -p vcf $imputed_file.gz" );
system ( "tabix -p vcf $filtered_file.gz" );



    
       
