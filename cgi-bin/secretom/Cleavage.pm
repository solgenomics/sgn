#!/usr/bin/perl

#the Genentech alignment program:
#reads in a bunch of sequences from the given filename, figures out where their three regions are,
#aligns N regions at left, Cs at right and Hs at right, and prints to stdout

#notes on signal peptide composition, from von Heijne etc.:
#regions from N-terminus are N (positively charged), H (hydrophobic), C (polar)
#total length is approx 15 to 33 in eukaryotes; a disproportionate number are 18 to 20 long--but they can be longer than 70
#approx N length 1 - 5; H 7 - 15; C 3 - 7 but almost always 5 or 6
#H region shouldn't be longer than 20; N region can be 20 with little effect (makes it more like a signal anchor)
#most single-acid replacements resulting in uselessness were in the H region
#charge of N region is almost always slightly positive, regardless of its length
#the shorter the sequence, the more hydrophobic the H region
#positions -1 and -3: MUST be small, neutral acids--absolutely no exceptions
#hydrophobics mostly in -6 and after, few in -1 to -4, bad in -5
#large aromatic acids in -2; small neutral ones bad

#a few systems of classification of amino acids:
#hydrophobic - ACFGHIKLMTVWY    AFGILMPVW
#hydrophilic - DENPQRS          REDNQH(P)(K)
#charged - DEHKR                DEHKR
  #negative - DE                DE
  #positive - HKR               HKR
#uncharged - ACFGILMNPQSTVWY    CNQSTY
#small - ACDGNPSTV
#large - EFHIKLMQRWY
#polar - CDEHKNQRSTWY           CDEHKNQRSTY
#nonpolar - ACFGILMPV
#aromatic - FHWY
#aliphatic - ILV

#A - hydrophobic, small & uncharged
#C - cysteine, hydrophobic, polar
#D - negative, polar
#E - negative, large, polar
#F - hydrophobic, large & aromatic
#G - hydrophobic, small & uncharged
#H - hydrophobic, positive, large & aromatic, polar
#I - hydrophobic
#K - hydrophobic, positive, polar
#L - hydrophobic
#M - hydrophobic
#N - small & uncharged, polar
#P - small & uncharged
#Q - polar
#R - positive,polar
#S - small & uncharged,polar
#T - hydrophobic, small & uncharged, polar
#V - hydrophobic, small & uncharged
#W - hydrophobic, large & aromatic, polar
#Y - hydrophobic, large & aromatic, polar

#########################################################################################################################
# truncate sequences to lengths determined by a rather simple algorithm, convolving with a position-frequency matrix
#########################################################################################################################
#one argument: input fasta file

use strict;

package Cleavage;

my@weightmatrix =	#columns are positions -13 to +2, rows are residues,
(							#values are total numbers of such residues in such positions
	[101, 112, 106, 100, 158, 128, 107, 149, 146, 107, 258, 80, 458, 141, 55],
	[36, 32, 34, 31, 42, 66, 57, 39, 30, 34, 68, 21, 50, 23, 27],
	[2, 0, 3, 0, 3, 2, 4, 5, 25, 14, 4, 44, 6, 68, 66],
	[1, 2, 4, 5, 4, 6, 13, 9, 28, 27, 7, 66, 6, 92, 88],
	[75, 67, 80, 81, 65, 58, 92, 67, 25, 34, 7, 46, 6, 34, 28],
	[39, 24, 26, 34, 36, 50, 40, 29, 108, 125, 74, 38, 184, 52, 57],
	[5, 3, 4, 2, 4, 10, 14, 7, 23, 12, 5, 53, 2, 23, 22],
	[73, 67, 82, 59, 52, 52, 47, 69, 22, 43, 41, 18, 4, 37, 34],
	[4, 1, 1, 2, 0, 3, 3, 3, 20, 19, 7, 24, 4, 52, 40],
	[376, 432, 397, 449, 386, 329, 333, 280, 98, 147, 65, 165, 21, 60, 51],
	[26, 15, 21, 19, 11, 30, 20, 11, 5, 12, 9, 14, 3, 14, 12],
	[2, 4, 4, 6, 7, 7, 8, 7, 25, 14, 9, 37, 9, 26, 53],
	[23, 13, 17, 9, 12, 13, 24, 60, 98, 74, 7, 17, 27, 11, 166],
	[3, 6, 4, 9, 11, 19, 18, 13, 55, 40, 5, 72, 15, 135, 42],
	[7, 4, 4, 2, 3, 7, 9, 6, 34, 38, 5, 56, 20, 33, 40],
	[57, 47, 40, 44, 65, 76, 67, 66, 117, 97, 142, 112, 141, 91, 88],
	[32, 39, 30, 38, 38, 49, 42, 35, 70, 70, 103, 44, 43, 39, 57],
	[112, 124, 127, 100, 99, 86, 79, 129, 60, 72, 191, 45, 8, 50, 56],
	[16, 13, 20, 11, 9, 13, 24, 21, 13, 13, 2, 33, 2, 9, 6],
	[17, 3, 6, 9, 6, 7, 10, 6, 8, 19, 2, 26, 2, 21, 23],
);

#gives the row index in the above matrix denoted by the given residue code; handles upper- and lowercase
my %letter2index =
(
	"a" => 0, "A" => 0,		"c" => 1, "C" => 1,		"d" => 2, "D" => 2,		"e" => 3, "E" => 3,
	"f" => 4, "F" => 4,		"g" => 5, "G" => 5,		"h" => 6, "H" => 6,		"i" => 7, "I" => 7,
	"k" => 8, "K" => 8,		"l" => 9, "L" => 9,		"m" => 10, "M" => 10,	"n" => 11, "N" => 11,
	"p" => 12, "P" => 12,	"q" => 13, "Q" => 13,	"r" => 14, "R" => 14,	"s" => 15, "S" => 15,
	"t" => 16, "T" => 16,	"v" => 17, "V" => 17,	"w" => 18, "W" => 18,	"y" => 19, "Y" => 19
);

####################################################################################################################

sub min
{
	return $_[0] unless $_[1] < $_[0];
	return $_[1];
}

#return a positive score for the given cleavage site in the given sequence
sub scoreCleavageSite #expects parameters SEQUENCE, CLEAVAGE_SITE
{
	my $score = 0;
	for(my $i = $_[1] - 13; $i < $_[1] + 2; $i++)
	{
		$score += $weightmatrix[$letter2index{substr($_[0], $i, 1)}]->[$i - $_[1] + 13];
	}
	return $score;
}

sub subdomain #parameters: descriptor line, sequence length, sequence
{
  #  my $id = shift;
    my $thisseq = shift;
    my $totallength = length $thisseq;
;
   my $atypical = 0;
    my $typical = 0;
	my @sigseq;
	my $cfound = 0;
	my $hfound = 0;
	for (my $i=0; $i<$totallength; ++$i) {
		$sigseq[$i] = substr($thisseq, $i, 1);
	}
#	print "  length: $totallength; seq: @sigseq\n";
	# set the start of c-region 3aa upstream of the cleavage site
	my $cstart = $totallength - 3;                                                                  #assumes the given string ends at the -1 position, just before the cleavage site
	# move the pointer toward N-terminus until first occurence of >=2 hydrophobic aa
	# if two hydro aa not found, or it is too close to Met, put in atypical category
	for (my $i=$cstart-1; $i>6; --$i) {
		if (ishydrophobic($sigseq[$i]) && ishydrophobic($sigseq[$i-1])) {
			$cstart = $i+1;
			$cfound = 1;  # this is used as a flag for atypical sequences
			last;
		}
	}
	
	# set the start of the h-region 5 aa upstream of $cstart
	my $hstart = $cstart - 5;
	# set $hstart at the 1st occurrence of either a charged aa or >3 consecutive nonhydrophobic aa
	for (my $i=$hstart-1; $i>0; --$i) {
		if ( ischarged($sigseq[$i]) || (nh($sigseq[$i])&&nh($sigseq[$i-1])&&nh($sigseq[$i-2]))) {
			$hstart = $i+1;
			$hfound = 1;  # this is used as as flag for atypical sequences
			last;
		} 
	}
	
	# If the boundary is not found, then set $hstart at 1 (2nd aa)
	unless ($hfound) { $hstart =1 ; $hfound = 1; }

	# now, move $hstart pointer backwards until a hydrophobic aa is found
	for (my $i=$hstart; $i<$cstart-5; ++$i) {
		if (ishydrophobic($sigseq[$i])) {
			$hstart = $i;
			last;
		}
	}

  #  $atypical_seq = !$cfound;
   if(!$cfound) #$hfound is always 1; see above
	{
	  $atypical++;

   }
	else #if not atypical
	{
	    $typical++;
	# start to select those sequences that pass length selection criteria
	# and format those in the multiple sequence alignment form
	# maximum n-region length: 55
	# maximum h-region length: 40
	# maximum c-region length: 25
	my $alignedseq = "";
#	if(!($hstart <=55) && (($cstart-$hstart) <= 40) && (($totallength-$cstart) <= 25))
#	{
		for (my $i=0; $i<$totallength; ++$i) 
		{
			if ($i==$hstart) 
			{
				for (my $j=0;$j<95-$cstart; ++$j) {$alignedseq .=  "-"; }
			}
			elsif ($i==$cstart) 
			{
				for (my $j=0; $j<25-$totallength+$cstart; ++$j) {$alignedseq .=  "-";  }
			}
			$alignedseq .= $sigseq[$i];
		}
#	print "totallength: $totallength \n";
#	print "h,c start (0 based): $hstart  $cstart \n";
#		printf("%s\n%s\n", $id, $alignedseq);
	}
    return ($typical, $hstart, $cstart);
}

#simple residue evaluation methods
sub ishydrophobic
{
	my $thisaa = $_[0];
	if ($thisaa =~ /[AILMFVW]/i) { return 1; } else { return 0; }
}

sub ischarged
{
	my $thisaa = $_[0];
	if ($thisaa =~ /[RKDE]/i) { return 1; } else { return 0; }
}

sub nh
{
	# subroutine for determine if non-hydrophobic or not
	my $thisaa = $_[0];
	if ($thisaa =~ /[CDEGHKNPQRSTY]/i) { return 1; } else { return 0; }
}


sub cleavage{
    my $sequence = shift;
	my @cleavageSiteScores;
		my $cleavageSite = 0;
    my $ibest = 0;
		for(my $i = 0; $i < min(45, length($sequence) - 15); $i++)
		{
		    my $j = $i + 13; # this will be the cleavage site
		#	$cleavageSiteScores[$i] = scoreCleavageSite($sequence, $i + 13) * exp(-((7 - $i) * (7 - $i)) / 200); #mult by e^( (L - 20)^2 / ~ 14^2 )
	
	$cleavageSiteScores[$i] = scoreCleavageSite($sequence, $j) * exp(-0.5*((20 - $j) * (20 - $j)) / 4000); #mult by e^( (L - 20)^2 / ~ 14^2 )
# Not sure what this was originally. x^2/200 seems to me to cut off to quickly at large lengths. How about 1/2*x^2/400, i.e. a width of ~ 20
	
		
			if($i > 0 && $cleavageSiteScores[$i] > $cleavageSiteScores[$ibest])
			{
			$ibest = $i;#	$cleavageSite = $i;
			}
		    
		}
    $cleavageSite = $ibest + 13;
	#	$seq[1] = $cleavageSite + 13;
		$sequence = substr($sequence, 0, $cleavageSite);
# returns the cleavage site, which is also the length of the signal peptide.
   # print "cleavageSite $cleavageSite \n";
    return $cleavageSite;
}

1;
