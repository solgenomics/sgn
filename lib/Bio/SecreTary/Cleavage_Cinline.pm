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

package Bio::SecreTary::Cleavage_Cinline;

#use base qw / Bio::SecreTary::Cleavage /;
use Moose;
extends qw / Bio::SecreTary::Cleavage /;
use namespace::autoclean;

use List::Util qw/min/;

use Inline C => <<'END_C';
double scoreCleavageSiteFast(SV* m, SV* seq_aa_nums, I32 opos){
  if ((!SvROK(m))
                        || (SvTYPE(SvRV(m)) != SVt_PVAV)
                        || ((av_len((AV *)SvRV(m)) + 1) < 0)) {
                return -10000;
        }
    double result = 0;
    I32 length = av_len((AV *)SvRV(seq_aa_nums)) + 1; // length of the sequence
    I32 i;
    I32 pos = opos + 13; // opos: offset position, pos: position
    for(i = 0; i < 15; i++){
        I32 aanum = SvIV(* av_fetch((AV*) SvRV(seq_aa_nums), i + opos, 0 ));
        SV* a = (* av_fetch((AV*) SvRV(m), aanum, 0 ));
        result += SvNV(* av_fetch((AV*) SvRV(a), i, 0 ));
    }
    result *= exp(-0.5*((20.0-pos)*(20.0-pos)/4000));
    return result;
}
END_C

sub cleavage {    # uses Inline::C. faster
    my $self               = shift;
    my $sequence           = shift;
    my $letter2index       = $self->aa_number_hash();
    my @seq_aanumber_array = map { $letter2index->{$_} } split( '', $sequence );
    my $weight_matrix_ref  = $self->weight_matrix();

    my $up = min( 45, length($sequence) - 15 );
    my @cleavageSiteScores = ( (0) x $up );
    $cleavageSiteScores[0] =
      scoreCleavageSiteFast( $weight_matrix_ref, \@seq_aanumber_array, 0 );
    my $ibest = 0;
    for ( my $i = 1 ; $i < $up ; $i++ ) {
        if (
            (
                $cleavageSiteScores[$i] = scoreCleavageSiteFast(
                    $weight_matrix_ref, \@seq_aanumber_array, $i
                )
            ) > $cleavageSiteScores[$ibest]
          )
        {
            $ibest = $i;
        }
    }

    # return the cleavage site, which is also the length of the signal peptide.
    return $ibest + 13;
}

__PACKAGE__->meta->make_immutable;

1;
