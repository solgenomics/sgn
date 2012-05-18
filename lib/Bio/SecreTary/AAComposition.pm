package Bio::SecreTary::AAComposition;
use strict;
use warnings;

# this module just has some routines to calculate some
# simple parameters characterizing the amino acid composition
# of a peptide, such as aliphatic index, gravy index, number of
# DRQPEN, number of GASDRQPEN, number of Nitrogen or Oxygen atoms ...
# Molecular weight.

my %total_beta_strand_values = (A => 0.369, # Ala
		C => 0.539, # Cys
		D => 0.057, # Asp
		E => 0.149, # Glu
		F => 0.603, # Phe
		G => 0.149, # Gly
		H => 0.376, # His
		I => 1.000, # Ile
		K => 0.213, # Lys
		L => 0.638, # Leu
		M => 0.560, # Met
		N => 0.142, # Asn
		P => 0.000, # Pro
		Q => 0.390, # Gln
		R => 0.376, # Arg
		S => 0.298, # Ser
		T => 0.511, # Thr
		V => 1.000, # Val
		W => 0.809, # Trp
		Y => 0.801, # Tyr
		X => 0.449 # unknown
		);

my %beta_sheet_values = (A => 0.220, # Ala
		C => 0.520, # Cys
		D => 0.116, # Asp
		E => 0.132, # Glu
		F => 0.645, # Phe
		G => 0.188, # Gly
		H => 0.316, # His
		I => 0.897, # Ile
		K => 0.228, # Lys
		L => 0.563, # Leu
		M => 0.531, # Met
		N => 0.155, # Asn
		P => 0.000, # Pro
		Q => 0.302, # Gln
		R => 0.351, # Arg
		S => 0.356, # Ser
		T => 0.538, # Thr
		V => 1.000, # Val
		W => 0.591, # Trp
		Y => 0.566,  # Tyr
		X => 0.411 # unknown
		);

# Deleage & Roux ... beta turn
my %beta_turn_values = (A => 0.338, # Ala
		C => 0.448, # Cys
		D => 0.591, # Asp
		E => 0.561, # Glu
		F => 0.237, # Phe
		G => 1.000, # Gly
		H => 0.451, # His
		I => 0.000, # Ile
		K => 0.656, # Lys
		L => 0.265, # Leu
		M => 0.121, # Met
		N => 0.822, # Asn
		P => 0.725, # Pro
		Q => 0.467, # Gln
		R => 0.415, # Arg
		S => 0.664, # Ser
		T => 0.308, # Thr
		V => 0.091, # Val
		W => 0.189, # Trp
		Y => 0.343,  # Tyr
		X => 0.435 # unknown	
	);


sub aa_frequencies
{ # given a aa sequence and a hash of aa/count pairs, add the counts of the aa's in the sequence to the hash.
	my $sequence = shift;
	my $AAFhash  = shift
		;  # ref. to hash with AA chars for keys, number of occurences for values

		my %AAFs = ();

#ref to array of 20 amino acids (1 char abbreviations), plus "X" for any other stuff.
	if ( !defined $AAFhash ) {
		$AAFhash = \%AAFs;
		my @aas = (
				"A", "C", "D", "E", "F", "G", "H", "I", "K", "L",
				"M", "N", "P", "Q", "R", "S", "T", "V", "W", "Y"
			  );

		map { $AAFhash->{$_} = 0; } @aas;
	}
	my $seq_length_a = length $sequence;
	my $seq_length_b = 0;
	while ($sequence) {
		my $AAchar = chop $sequence;
		if ( exists $AAFhash->{$AAchar} ) {
			$AAFhash->{$AAchar}++;
		}
		else {
			$AAFhash->{"X"}++;
		}
		$seq_length_b++;
	}
	die
		"in aa_frequencies, seqlength discrepancy: $seq_length_a,  $seq_length_b  \n"
		unless ( $seq_length_a == $seq_length_b );
	$AAFhash->{"LENGTH"} = $seq_length_b;
	return $AAFhash;
}

=head2 function aliphatic_index

Synopsis: aliphatic_index($sequence);
Description: Calculates and returns the aliphatic index of the sequence.
(See http://expasy.org/tools/protparam-doc.html for definition of aliphatic index.)


=cut

sub aliphatic_index {
	my $sequence = shift;
	my $nA       = ( $sequence =~ tr/A// );
	my $nV       = ( $sequence =~ tr/V// );
	my $nL       = ( $sequence =~ tr/L// );
	my $nI       = ( $sequence =~ tr/I// );
	my $nX       = ( $sequence =~ tr/X// );
	my $L        = length($sequence) - $nX;
	if ( $L <= 0 ) {
		warn "In aliphatic_index. ", length $sequence, "  $nX $sequence \n";
	}
	else {
		return 100.0 * ( 1.0 * $nA + 2.9 * $nV + 3.9 * ( $nL + $nI ) ) / $L;
	}
	return;
}

=head2 function gravy

Synopsis: gravy($sequence);
Description: Calculates
and returns the "gravy" index of the sequence.
(See http://expasy.org/tools/protparam-doc.html for definition of
 gravy index.)

=cut

sub gravy {
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
		if ( defined $Hydropaths{$char} )
		{    # standard 20 aa's. Others (incl. X) not counted
			$sum_h += $Hydropaths{$char};
			$count++;
		}
	}

	if ( $count > 0 ) {
		return $sum_h / $count;
	}
	else {
		return;    #  -10000.0;
	}
}

=head2 function nDRQPEN

Synopsis: nDRQPEN($sequence);
Description: Calculates
and returns the number of amino acids in the sequence which are DRQPE or N.

=cut

sub nDRQPEN {
	my $sequence = shift;
	my $count    = 0;
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
	my $sequence = shift;
	my $count    = 0;
	while ($sequence) {
		my $c = chop $sequence;
		$count++ if ( $c =~ /[GASDRQPEN]/ );
	}
	return $count;
}

sub total_beta_strand{
	my $sequence = shift;
	my $window_size = shift || 9;
	my $normalize = shift || 1;
	return window_average(\%total_beta_strand_values, $sequence, $window_size, $normalize);
}	

sub beta_sheet{
	my $sequence = shift;
	my $window_size = shift || 9;
	my $normalize = shift || 1;
	return window_average(\%beta_sheet_values, $sequence, $window_size, $normalize);
}

sub beta_turn{
	my $sequence = shift;
	my $window_size = shift || 9;
	my $normalize = shift || 1;
	return window_average(\%beta_turn_values, $sequence, $window_size, $normalize);
}

sub window_average{
	my $aavals = shift; # ref to hash giving the values associated with each aa
		my $sequence = shift;
	my $window_size = shift || 9;
	my $normalize = shift || 1;
	my $normalize_factor = ($normalize)? 1.0/$window_size: 1.0; 
	my $hws = int($window_size/2);
	my @val_array = ( (0) x length $sequence);
	my ($minval, $maxval) = (0, 0);
	if(length $sequence >= $window_size){
		my $val = 0;
		foreach (0..$window_size-1){
			$val += $aavals->{substr($sequence, $_, 1)};
		}
	($minval, $maxval) = ($val, $val);
		$val_array[$hws] = $val * $normalize_factor;
		my $i = 0;
		while($i + $window_size < length $sequence){
			$val -= $aavals->{substr($sequence, $i, 1)};
			$val += $aavals->{substr($sequence, $i + $window_size, 1)};
		$minval = $val if($val < $minval);
	$maxval = $val if($val > $maxval);		
	$i++;
			$val_array[$i + $hws] = $val * $normalize_factor;	
		}
	}
	return (\@val_array, $minval*$normalize_factor, $maxval*$normalize_factor); # return reference to val array
}



=head2 function nVIL

Synopsis: nVIL($sequence);
Description: Calculates
and returns the number of amino acids in the sequence which are VI or L.
as well as total (not counting X)
=cut

sub nVIL {
	my $sequence = shift;
	my ($count, $count_vil)    = (0, 0);
	while ($sequence) {
		my $c = chop $sequence;
		$count++ if( $c =~ /[ACDEFGHIKLMNPQRSTVWY]/ );
		$count_vil++ if ( $c =~ /[VIL]/ );
	}
	warn "count is 0. sequence: $sequence \n" if($count == 0);
	return ($count, $count_vil);
}



=head2 function nNitrogen

Synopsis: nNitrogen($sequence);
Description: Calculates
and returns the number of Nitrogen atoms in this sequence.

=cut

sub nNitrogen {
	my $sequence = shift;
	my $count    = 0;
	while ($sequence) {
		my $c = chop $sequence;
		$count += _N_in_aa($c);
	}
	return $count;
}

=head2 function nOxygen

Synopsis: nOxygen($sequence);
Description: Calculates
and returns the number of Oxygen atoms in the sequence. If the
sequence which is analyzed includes a C-terminus then there would
be one more O than the result here, but we are counting O's 
in a part of the protein at the N-terminus, so this function doesn't count
that extra C-terminal O.

=cut

sub nOxygen {
	my $sequence = shift;
	my $count    = 0;
	while ($sequence) {
		my $c = chop $sequence;
		$count += _O_in_aa($c);
	}
	return $count;
}

sub _N_in_aa {    # number of Nitrogen atoms in each kind of amino acid

# (see e.g. Wikipedia "proteinogenic amino acids")
	my $aa    = shift;
	my %Nhref = (        # these are the aa's with > 1 Nitrogen
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
		return 1;    # all others have 1 nitrogen.
	}
}

sub _O_in_aa {       # Number of Oxygen atoms in each kind of amino acid

# (see e.g. Wikipedia "proteinogenic amino acids")
# Only 1 Oxygen in COOH group counted.
	my $aa    = shift;
	my %Ohref = (
			"D"  => 3,
			"E", => 3,
			"N"  => 2,
			"O"  => 3,    # pyrrolysine
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

sub molecular_weight {
	my $AAFhash    = shift;
	my %MolWeights = (
# (see e.g. Wikipedia "proteinogenic amino acids")
			"A" => 89.09,
			"C" => 121.16,
			"D" => 133.10,
			"E" => 147.13,
			"F" => 165.19,
			"G" => 75.07,
			"H" => 155.16,
			"I" => 131.18,
			"K" => 146.19,
			"L" => 131.18,
			"M" => 149.21,
			"N" => 132.12,
			"P" => 115.13,
			"Q" => 146.15,
			"R" => 174.20,
			"S" => 105.09,
			"T" => 119.12,
			"V" => 117.15,
			"W" => 204.23,
			"Y" => 181.19,
			);



#     "A" => 89,
#     "R" => 174,
#     "N" => 132,
#     "D" => 133,
#     "C" => 121,
#     "E" => 147,
#     "Q" => 146,
#     "G" => 75,
#     "H" => 155,
#     "I" => 131,
#     "L" => 131,
#     "K" => 146,
#     "M" => 149,
#     "F" => 165,
#     "P" => 115,
#     "S" => 105,
#     "T" => 119,
#     "W" => 204,
#     "Y" => 181,
#     "V" => 117
# );

	my $sum_wf = 0;
	my $sum_f  = 0;
	my $length = $AAFhash->{"LENGTH"};
	foreach ( keys %$AAFhash ) {
		next unless ( defined $MolWeights{$_} );
		my $f = $AAFhash->{$_};    #frequency of this aa in this seq.
#	print "$_,  $w  \n";
			$sum_wf += $MolWeights{$_} * $f;
		$sum_f  += $f;
	}
	if ( $sum_f > 0 ) {

# if there are X chars, consider them to have MW equal to avg of others.
		$sum_wf *= $AAFhash->{"LENGTH"} / $sum_f;
	}
	$sum_wf -= 18 * ( $length - 1 )
		;    # subtract for the H2O molecules removed in forming peptide bonds.
		return $sum_wf;
}

sub charge
{    # get the electric charge at given pH of the set of aa's stored in aa_hash
# for pKa's (3.90, 4.07, etc.) see e.g.  Wikipedia "proteinogenic amino acids"
# this does not include the charges of the terminal groups
	my $aa_hash = shift
		; # ref to hash storing the numbers in the segment analyzed of each of the charged aa's (DECY & HKR)
		my $pH = shift;
	my $Q  = 0;
	$Q -= $aa_hash->{"D"} / ( 1.0 + 10**( 3.90 - $pH ) );
	$Q -= $aa_hash->{"E"} / ( 1.0 + 10**( 4.07 - $pH ) );
	$Q -= $aa_hash->{"C"} / ( 1.0 + 10**( 8.18 - $pH ) );
	$Q -= $aa_hash->{"Y"} / ( 1.0 + 10**( 10.48 - $pH ) );

	$Q += $aa_hash->{"H"} / ( 1.0 + 10**( $pH - 6.04 ) );
	$Q += $aa_hash->{"K"} / ( 1.0 + 10**( $pH - 10.54 ) );
	$Q += $aa_hash->{"R"} / ( 1.0 + 10**( $pH - 12.48 ) );
	return $Q;
}

sub isoelectric_point
{ # finds the isoelectric point pI, i.e. the pH at which the avg. net electric charge of the sequence is 0.
# it might be interesting to get the derivative of Q wrt pH also.
	my $aa_hash = shift;
	my $pI      = shift;
	$pI ||= 7.0;    # initial guess for pH
		my ( $pI_LB, $pI_UB ) = ( 0, 14.0 );    # initial bounds on the pI
		my $q_tolerance =
		0.0001;  # close enough if either -$q_tolerance < charge < $q_tolerance or
		my $pI_tolerance = 0.001;    # pI_UB - pI_LB < $pI_tolerance
		my $nNeg =
		$aa_hash->{"D"} + $aa_hash->{"E"} + $aa_hash->{"C"} + $aa_hash->{"Y"};
	my $nPos = $aa_hash->{"H"} + $aa_hash->{"K"} + $aa_hash->{"R"};

	if ( $nNeg > 0 ) {
		if ( $nPos > 0 ) {
			while (1) {
				my $Q = charge( $aa_hash, $pI );
				if ( $Q < -$q_tolerance )
				{    #charge is negative - pI must be less than pH; lower the pH
					$pI_UB = $pI;
				}
				elsif ( $Q > $q_tolerance )
				{ #charge is positive - pI must be greater than pH; raise the pH
					$pI_LB = $pI;
				}
				else {    # close enough to neutral - done
					return $pI;
				}
				$pI = 0.5 * ( $pI_UB + $pI_LB );
				if ( $pI_UB - $pI_LB < $pI_tolerance ) {
					return $pI;
				}
			}
		}
		else {    # negative aa's but no positive aa's -> always negative
			return $pI_LB;
		}
	}
	else {        #no negative aa's
		if ( $nPos > 0 ) {
			return $pI_UB;
		}
		else {    # no negative or positive aa's, return 7.0
			return 7.0;
		}
	}
	return;
}

sub extinction_coefficient{

	my $sequence = uc (shift);
	my $result = 0;
	while($sequence){
		my $char = chop $sequence;
		if($char eq 'W'){ $result += 5690; }
		elsif($char eq 'Y'){ $result += 1280; }
		elsif($char eq 'C'){ $result += 120; }
	}
	return $result;
}

1;
