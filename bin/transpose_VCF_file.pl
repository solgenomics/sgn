#!/usr/bin/perl

=head1
transpose_VCF_file.pl - script for transposing a VCF.

=head1 SYNOPSIS
    perl bin/transpose_VCF_file.pl -i /home/vagrant/Documents/cassava_subset_108KSNP_10acc.vcf -o /home/vagrant/Documents/cassava_subset_108KSNP_10acc_transposed.txt

=head1 COMMAND-LINE OPTIONS
  ARGUMENTS
 -i input path vcf file
 -o output transposed file


=head1 DESCRIPTION
This script transposes a VCF file

=head1 AUTHOR
 Nicolas Morales (nm529@cornell.edu)
 Guillaume Bauchet (gjb99@cornell.edu)
 Lukas Mueller <lam87@cornell.edu>
=cut

use strict;

use Getopt::Std;
use Data::Dumper;
use JSON::Any;
use JSON::PP;
use Carp qw /croak/ ;
use Try::Tiny;
use Pod::Usage;

our ($opt_i, $opt_o);

getopts('i:o:');

if (!$opt_i || !$opt_o) {
    pod2usage(-verbose => 2, -message => "Must provide options -i (input vcf), -o (output vcf)\n");
}

my $F;
open($F, "<", $opt_i) || die "Can't open file $opt_i\n";

my $Fout;
open($Fout, ">", $opt_o) || die "Can't open file $opt_o\n";

my @header_lines;
my $oldlastcol = 0;
my $lastcol = 0;
my @outline;
while (my $line = <$F>) {
    if ($line =~ m/^\##/) {
        print $Fout $line;
    } else {
        chomp $line;
        my @line = split /\t/, $line;
        $lastcol = $#line if $#line > $lastcol;
        for (my $i=$oldlastcol; $i < $lastcol; $i++) {
            $outline[$i] = "\t" x $oldlastcol;
        }
        for (my $i=0; $i <=$lastcol; $i++) {
            $outline[$i] .= "$line[$i]\t"
        }
    }
}
close($F);

for (my $i=0; $i <= $lastcol; $i++) {
    $outline[$i] =~ s/\s*$//g;
    print $Fout $outline[$i]."\n";
}
close($Fout);

print "Complete!\n";
