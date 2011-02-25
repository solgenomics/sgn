#!/usr/bin/perl 
use strict;
use warnings;

use lib '/home/tomfy/cxgn/sgn/lib';
use Bio::SecreTary::TMpred;
use Bio::SecreTary::TMpred_pascal;
use Bio::SecreTary::Table;
use Bio::SecreTary::Helix;
use constant SCORE_TOLERANCE => 2;


my $tmpred = Bio::SecreTary::TMpred->new();
my $tmpred_pascal = Bio::SecreTary::TMpred_pascal->new();

my $verbose = shift || 0;
my ($count_good, $count_almost_good, $count_bad) = (0,0,0);
while (<>) {
    if (/^>/x) {
        my $idline   = $_;
        my $sequence = <>;
        if ( $idline =~ /^>(\S+)/x ) {
            my $id = $1;
            my $trunc_sequence = substr( $sequence, 0, 70 );
            my ($pascal_good_solutions, $long_output_pascal) =
              $tmpred_pascal->run_tmpred( $trunc_sequence, {'sequence_id' => $id, 'do_long_output' => 1} );
 

           my ($perl_good_solutions, $long_output_perl) =
              $tmpred->run_tmpred( $trunc_sequence, {'sequence_id' => $id, 'do_long_output' => 1 } );

# print "perl good solns: [[$perl_good_solutions]]\n";	            
# print "pascal good solns: [[$pascal_good_solutions]]\n";

my $cmpstr = pp_compare( $pascal_good_solutions, $perl_good_solutions );
            if($cmpstr eq '1111'){ 
$count_good++; 
} 
elsif($cmpstr eq '1101'){
  $count_almost_good++;
}
else { $count_bad++; }
if ($verbose) { print "$cmpstr $id [$pascal_good_solutions][$perl_good_solutions]\n"; }

            #	print "good solutions: $good_solutions \n";
        }
        else {
            warn "line $idline has no identifier\n";
        }

    }
}
print "good/almostgood/bad: $count_good, $count_almost_good, $count_bad \n";


sub pp_compare {
    my $pags = shift;
    my $pegs = shift;
    $pags =~ s/[()]/ /g;
    $pegs =~ s/[()]/ /g;
    my @pagsa = split( " ", $pags );
    my @pegsa = split( " ", $pegs );
    my $nsol_agree = ( scalar @pagsa == scalar @pegsa );
    my ( $pos_agree, $score_agree, $score_almost_agree ) = ( 1, 1, 1 );

    for ( my $i = 0 ; $i < scalar @pagsa and $i < scalar @pegsa ; $i++ ) {
#        print $pagsa[$i], "  ", $pegsa[$i], "\n";
	my ( $ascore, $abeg, $aend ) = split( ',', $pagsa[$i] );
        my ( $escore, $ebeg, $eend ) = split( ',', $pegsa[$i] );
#	print "$ascore, $abeg, $aend \n";
# print "perl: $escore, $ebeg, $eend  pasc: $ascore, $abeg, $aend\n";        
$pos_agree &&= ( $abeg == $ebeg and $aend == $eend );
        $score_agree &&= ( $ascore == $escore );
#	print "$ascore  $escore  $score_agree \n";

        $score_almost_agree &&=
          ( abs( $ascore - $escore ) <= SCORE_TOLERANCE );
    }
	my $str = ($nsol_agree)? '1': '0';
$str .= ($pos_agree)? '1': '0';
$str .= ($score_agree)? '1': '0';
$str .= ($score_almost_agree)? '1': '0';
    return $str;  #( $nsol_agree, $pos_agree, $score_agree, $score_almost_agree );
}
