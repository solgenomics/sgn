#!/usr/bin/perl                                                                                                                                                                         

use warnings;
use strict;
use Getopt::Std;

our ($opt_v, $opt_o);

getopts('v:o:');

my $raw_vcf_file = $opt_v;
my $output_dir = $opt_o;
my @header;
my $vcf_file;
my %already_seen;
my $rep;
my $rep_num = '';
my $accession_name;

open (SNPS, "<", $raw_vcf_file) || die "Can't open $raw_vcf_file!\n";

while (<SNPS>) {

#------------------------------------------------------------------                                                                                                                     
# Save header info that should be present in all files into an array                                                                                                                    
#-------------------------------------------------------------------                                                                                                                    

    if ($. <= 10) {
	print $. . "\n";
	push @header, $_;

    } elsif (m/^#CHROM/) {
	last;
    } else {

#--------------------------------------------------------------------------------------------------                                                                                     
# Take line with individual accession name and extract that name. Use name to create output vcf file                                                                                    
#---------------------------------------------------------------------------------------------------         

	my $full_line = $_;
	chomp ($accession_name = $full_line);
	print "Working on accession $accession_name\n";
	if (exists $already_seen{$accession_name}) {     # check to see if this is a repetition                                                                                         
	    print STDERR "Rep found for $accession_name !\n";
	    $rep_num = $already_seen{$accession_name};
	    $rep_num++;
	    $already_seen{$accession_name} = $rep_num;
	    $rep = "_rep" . $rep_num;
	} else {
	    $already_seen{$accession_name} = 1;
	}

	my $column_number = $.;
        $column_number--;

	$vcf_file = $output_dir . "/" . $accession_name . "_2015_V6" . $rep . ".vcf_" . $column_number;
	$rep='';

	print $vcf_file . "\n";
	open (OUT, ">", $vcf_file) || die "Can't open $vcf_file\n";

#--------------------------------------------------------------                                                                                                                         
# Print header and info about a single accession to output file                                                                                                                         
#--------------------------------------------------------------                                                                                                                         

	foreach my $line (@header) {
	    print OUT $line;
	}
    }
}
