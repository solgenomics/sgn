#!/usr/bin/perl


=head1 NAME

remove_duplicate_samples_vcf.pl - renames and removes duplicate samples in a vcf file. 
keeps one copy of the samples.

=head1 DESCRIPTION

 perl remove_duplicate_samples_vcf.pl -i [vcf_input_file] -o [vcf_output_file]

 requires vcftools. Generates 3 files: a text file with the duplicated samples to remove, 
 a vcf files with the duplicates renamed and a vcf file with out the duplicates.

=head1 AUTHOR

Isaak Y Tecle <iyt2@cornell.edu>

=cut

use strict;
use Getopt::Std;
use File::Slurp qw /read_file write_file/;


our($opt_i, $opt_o);

getopts('i:o:');

open(my $V, "<", $opt_i) || die "Can't open vcf_file: $opt_i\n";

my $lines;
my @dupl_samples;

while (<$V>) {
    chomp();

    if ($_ =~ m/^\#CHROM/) {
        print STDERR "Parsing ids in vcf file...\n";
        my @orig_fields = split /\t/;
        my @modified_fields;
        for (my $i=0; $i <= $#orig_fields; $i++) {
            my $field = $orig_fields[$i];
            if ($i < 9) {
                print "\nkeeping the first 9 columns: $field\n";
                push @modified_fields, $field;
            } else {
                if (grep{$field eq $_} @modified_fields) {
                    $field = "${field}_dupl_${i}";
                    print "$orig_fields[$i] at col $i is a duplicate -- modified its name to $field\n";     
                    push @dupl_samples, $field;

                } else {
                    print STDERR "\n$field at col $i is a unique sample\n";
                }

                push @modified_fields, $field;
            }
        }

        my $line = join("\t", @modified_fields);
        $lines .= $line . "\n";
    }
    else {
        $lines .= $_ ."\n";
    }

}

my $dupl_samples = join("\n", @dupl_samples);
my $out_file = $opt_o =~ s/\.vcf//r;
my $remove_samples_file = "${out_file}_dupl_samples.txt";
my $removed_vcf = "${out_file}_removed.vcf";
my $renamed_vcf = "${out_file}_renamed.vcf";

print STDERR "Now writing to $remove_samples_file duplicate samples:\n$dupl_samples";
write_file($remove_samples_file, $dupl_samples);

print STDERR "Now writing to $renamed_vcf duplicate samples:\n$dupl_samples";
write_file($renamed_vcf, $lines);

print STDERR "Now removing duplicate samples:\n$dupl_samples";
`vcftools --remove $remove_samples_file --vcf $renamed_vcf --recode --out $removed_vcf`;
my $recode_file = "${removed_vcf}.recode.vcf";

print STDERR "Renaming $recode_file to $removed_vcf\n";
`mv $recode_file $removed_vcf`;
print STDERR"\nCleaned vcf file without the duplicates is $removed_vcf\n";

print STDERR "\nDone.";
