#!/usr/bin/perl -w
use strict;

use Cleavage;

my $sigfa = $ARGV[0];
open (IN, "<$sigfa") || die "Cannot open file $sigfa : $!";

my $id;
my $seq;
my $cleavageSite;
my $atypical = 0;
#my $seqnotaligned = 0;
while ($id = <IN>) #descriptor line
{
    chomp $id;
    last if(!defined $id  or  $id =~ /^\s*$/);
	chomp($seq = <IN>); #sequence string
	chop($seq) if(substr($seq, length($seq) - 1, 1) eq "*"); #don't want to count the * as an acid
	my $sp_length = Cleavage::cleavage($seq);
#	print "id: $id \n";
    $seq = substr($seq, 0, $sp_length);
	my ($typical, $hstart, $cstart) = Cleavage::subdomain($seq); #use this to print an alignment
    $id =~ s/^>(\S+).*/$1/;
    print "$id   $typical  $hstart  $cstart  $sp_length \n";
}
close(IN);

print STDERR "$atypical atypical sequences are ignored.\n";
#print STDERR "$seqnotaligned sequences are discarded because they are not well subdivided.\n";

############
