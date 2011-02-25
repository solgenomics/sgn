package Bio::SecreTary::AAComposition;
use strict;
use warnings;

# this module just has some routines to calculate some
# simple parameters characterizing the amino acid composition
# of a peptide, such as aliphatic index, gravy index, number of 
# DRQPEN, number of GASDRQPEN, number of Nitrogen or Oxygen atoms ...


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

1;
