package Bio::SecreTary::AAComposition;
use strict;
use warnings;

# this module just has some routines to calculate some
# simple parameters characterizing the amino acid composition
# of a peptide, such as aliphatic index, gravy index, number of 
# DRQPEN, number of GASDRQPEN, number of Nitrogen or Oxygen atoms ...
# Molecular weight.


sub AAFrequencies{							# given a aa sequence and a hash of aa/count pairs, add the counts of the aa's in the sequence to the hash.
	my $sequence = shift;
	my $AAFhash = shift;					# ref. to hash with AA chars for keys, number of occurences for values
#	my $aas = shift;
	my %AAFs = ();
#ref to array of 20 amino acids (1 char abbreviations), plus "X" for any other stuff.
	if (!defined $AAFhash) {
		$AAFhash = \%AAFs;
		my @aas =    ("A", "C", "D", "E", "F",
									"G", "H", "I", "K", "L",
									"M", "N", "P", "Q", "R",
									"S", "T", "V", "W", "Y");
		foreach (@aas) {
			$AAFhash->{$_} = 0;
		}
	}
	my $seq_length_a = length $sequence;
	my $seq_length_b = 0;
	while ($sequence) {
		my $AAchar = chop $sequence;
		if (exists $AAFhash->{$AAchar}) {
			$AAFhash->{$AAchar}++;
			#	print "$AAchar \n";
		} else {
			$AAFhash->{"X"}++;
		}
		$seq_length_b++;
	}
	die "in getAAFreqs, seqlength discrepancy: $seq_length_a,  $seq_length_b  \n" unless($seq_length_a == $seq_length_b);
	$AAFhash->{"LENGTH"} = $seq_length_b;
	return $AAFhash;
}



=head2 function AliphaticIndex

Synopsis: AliphaticIndex($sequence);
	Description: Calculates
and returns the aliphatic index of the sequence.

=cut


sub AliphaticIndex {
    my $sequence     = shift;
    my $nA = ( $sequence =~ tr/A// );
    my $nV = ( $sequence =~ tr/V// );
    my $nL = ( $sequence =~ tr/L// );
    my $nI = ( $sequence =~ tr/I// );
    my $nX = ( $sequence =~ tr/X// );
    my $L  = length($sequence) - $nX;
if($L <= 0) {
warn "In AliphaticIndex. ", length $sequence, "  $nX $sequence \n";
}else{
    return 100.0 * ( 1.0 * $nA + 2.9 * $nV + 3.9 * ( $nL + $nI ) ) / $L;
}
return;
}

=head2 function Gravy

Synopsis: Gravy($sequence);
	Description: Calculates
and returns the "Gravy" index of the sequence.

=cut

sub Gravy {
    my $sequence = shift;
    # Kyte and Doolittle hydropathy index: (from Wikipedia "Hydropathy index")
    my %Hydropaths = (
        "A" => 1.80,
        "R" => -4.50,
        "N" => -3.50,
        "D" => -3.50,
        "C" => 2.5,
        "E" => -3.50,
        "Q" => -3.50,
        "G" => -0.40,
        "H" => -3.20,
        "I" => 4.50,
        "L" => 3.80,
        "K" => -3.90,
        "M" => 1.90,
        "F" => 2.80,
        "P" => -1.60,
        "S" => -0.80,
        "T" => -0.70,
        "W" => -0.90,
        "Y" => -1.30,
        "V" => 4.20
    );

    my $sum_h = 0;
    my $count = 0;

    while ($sequence) {
        my $char = chop $sequence;
        if ( defined $Hydropaths{$char} ) { # standard 20 aa's. Others (incl. X) not counted
            $sum_h += $Hydropaths{$char};
            $count++;
        }
    }

    if ( $count > 0 ) {
        return $sum_h / $count;
    }
    else {
        return; #  -10000.0;
    }
}

=head2 function nDRQPEN

Synopsis: nDRQPEN($sequence);
	Description: Calculates
and returns the number of amino acids in the sequence which are DRQPE or N.

=cut

sub nDRQPEN {
    my $sequence     = shift;
    my $count = 0;
    while ($sequence) {
        my $c = chop $sequence;
        $count++ if ( $c =~ /[DRQPEN]/ );
    }
    return $count;
}


=head2 function nGASDRQPEN

Synopsis: nGASDRQPEN($sequence);
	Description: Calculates and returns the number of amino acids
        in the sequence which are GASDRQPE or N.

=cut

sub nGASDRQPEN {
    my $sequence     = shift;
    my $count = 0;
    while ($sequence) {
        my $c = chop $sequence;
        $count++ if ( $c =~ /[GASDRQPEN]/ );
    }
    return $count;
}


=head2 function nNitrogen

Synopsis: nNitrogen($sequence);
	Description: Calculates
and returns the number of Nitrogen atoms in this sequence.

=cut

sub nNitrogen {
  my $sequence = shift;
    my $count = 0;
    while ($sequence) {
        my $c = chop $sequence;
        $count += _N_in_aa($c);
    }
    return $count;
}

=head2 function nOxygen

Synopsis: nOxygen($sequence);
	Description: Calculates
and returns the number of Oxygen atoms in the sequence.

=cut

sub nOxygen {
  my $sequence = shift;
    my $count = 0;
    while ($sequence) {
        my $c = chop $sequence;
        $count += _O_in_aa($c);
    }
    return $count;
}

sub _N_in_aa { # number of Nitrogen atoms in each kind of amino acid
    my $aa    = shift;
    my %Nhref = (
        "H" => 3,
        "K" => 2,
        "N" => 2,
        "O" => 3,
        "Q" => 2,
        "R" => 4,
        "W" => 2
    );
    if ( exists $Nhref{$aa} ) {
        return $Nhref{$aa};
    }
    else {
        return 1; # all others have 1 nitrogen.
    }
}

sub _O_in_aa { # Number of Oxygen atoms in each kind of amino acid.
    my $aa    = shift;
    my %Ohref = (
        "D"  => 3,
        "E", => 3,
        "N"  => 2,
        "O"  => 3,
        "Q"  => 2,
        "S"  => 2,
        "T"  => 2,
        "Y"  => 2
    );
    if ( exists $Ohref{$aa} ) {
        return $Ohref{$aa};
    }
    else {
        return 1;
    }
}



sub MolecularWeight{
	my $AAFhash = shift;
	my %MolWeights = ("A" => 89, "R" => 174, "N" => 132, "D" => 133,
										"C" => 121, "E" => 147, "Q" => 146, "G" => 75,
										"H" => 155, "I" => 131, "L" => 131, "K" => 146,
										"M" => 149, "F" => 165, "P" => 115, "S" => 105,
										"T" => 119, "W" => 204, "Y" => 181, "V" => 117);
	my $sum_wf = 0;
	my $sum_f = 0;
	my $length = $AAFhash->{"LENGTH"};
	foreach (keys %$AAFhash) {
		next unless(defined $MolWeights{$_});
		my $f = $AAFhash->{$_};			#frequency of this aa in this seq.
		#	print "$_,  $w  \n";
		$sum_wf += $MolWeights{$_}*$f;
		$sum_f += $f;
	}
	if ($sum_f > 0) {
# if there are X chars, consider them to have MW equal to avg of others.
		$sum_wf *= $AAFhash->{"LENGTH"}/$sum_f;
	}
#	die "in MolecularWeight. Sum of aa counts not equal to seq length:  ", $AAFhash->{"LENGTH"}, 
#		"  ", $sum_f, "\n" unless($AAFhash->{"LENGTH"} == $sum_f);
	$sum_wf -= 18 * ($length-1);	# subtract for the H2O molecules removed in forming peptide bonds.
	return $sum_wf;
}

sub charge{						# get the electric charge at given pH of the set of aa's stored in aa_hash
	my $aa_hash = shift;		# ref to hash storing the numbers in the segment analyzed of each of the charged aa's (DECY & HKR)
	my $pH = shift;
	my $Q = 0;
	$Q -= $aa_hash->{"D"} / (1.0 + 10**(3.90 - $pH));
	$Q -= $aa_hash->{"E"} / (1.0 + 10**(4.07 - $pH));
	$Q -= $aa_hash->{"C"} / (1.0 + 10**(8.18 - $pH));
	$Q -= $aa_hash->{"Y"} / (1.0 + 10**(10.48 - $pH));

	$Q += $aa_hash->{"H"} / (1.0 + 10**($pH - 6.04));
	$Q += $aa_hash->{"K"} / (1.0 + 10**($pH - 10.54));
	$Q += $aa_hash->{"R"} / (1.0 + 10**($pH - 12.48));
}


sub isoelectric_point{					# finds the isoelectric point pI, i.e. the pH at which the avg. net electric charge of the sequence is 0.
	# it might be interesting to get the derivative of Q wrt pH also.
	my $aa_hash = shift;
	my $pI = shift; $pI ||= 7.0;	# initial guess for pH
	my ($pI_LB, $pI_UB) = (0, 14.0); 
	my $nNeg = $aa_hash->{"D"} + $aa_hash->{"E"} + $aa_hash->{"C"} + $aa_hash->{"Y"};
	my $nPos = $aa_hash->{"H"} + $aa_hash->{"K"} + $aa_hash->{"R"};
	if ($nNeg > 0) {
		if ($nPos > 0) {
			while (1) {
				my $Q = charge($aa_hash, $pI);
				if ($Q < -0.001) {			#negative - pI must be less than pH
					$pI_UB = $pI;		
				} elsif ($Q > 0.001) {	#positive - raise the pH
					$pI_LB = $pI;
				} else {								# close enough to neutral - done
					return $pI;
				}
				$pI = 0.5*($pI_UB + $pI_LB);
				if ($pI_UB-$pI_LB < 0.001) {
					return $pI;
				}
			}
		} else {										# negative aa's but no positive aa's -> always negative
			return $pI_LB;
		}
	} else{											#no negative aa's
		if ($nPos > 0) {
			return $pI_UB;
		} else{										# no negative or positive aa's, return 7.0
			return 7.0; 
		}
	}
}


1;
