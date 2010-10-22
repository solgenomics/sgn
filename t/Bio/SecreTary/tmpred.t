#!/usr/bin/perl -w
use strict;
use warnings FATAL => 'all';

# tests for TMpred Module
use Test::More tests=> 5;
use Bio::SecreTary::TMpred;
use Bio::SecreTary::Helix;

$ENV{PATH} .= ':programs'; #< XXX TODO: obviate the need for this

my $limits = [500, 17, 40, 0, 40];
my $id = "AT1G50920.1";
my $sequence = "MVQYNFKRITVVPNGKEFVDIILSRTQRQTPTVVHKGYKINRLRQFYMRKVKYTQTNFHAKLSAIIDEFPRLEQIHPFYGDLLHVLYNKDHYKLALGQVNTARNLISKISKDYVKLLKYGDSLYRCKCLKVAALGRMCTVLKRITPSLAYLEQIRQHMARLPSIDPNTRTVLICGYPNVGKSSFMNKVTRADVDVQPYAFTTKSLFVGHTDYKYLRYQVIDTPGILDRPFEDRNIIEMCSITALAHLRAAVLFFLDISGSCGYTIAQQAALFHS*";

my $TMpred_obj = Bio::SecreTary::TMpred->new( $limits, $sequence, $id );
ok( defined $TMpred_obj, 'new() returned something.');
isa_ok( $TMpred_obj, 'Bio::SecreTary::TMpred' );

#is( $TMpred_obj->get_sequence(), $sequence, "sequence is ok");
#is( $TMpred_obj->get_sequence_id(), $id, "id is ok");

my ($raw_out, $good_solutions) = $TMpred_obj->run_tmpred($sequence, $id, 'pascal');


is( $good_solutions, "(-10000,0,0)", "tmpred solutions ok"); # this is a summary of the most useful bits of the tmpred output
#print $TMpred_obj->get_solutions(), "\n";

#-----------------------------------------------------------------

$id = "AT1G75120.1";
$sequence = "MAVRKEKVQPFRECGIAIAVLVGIFIGCVCTILIPNDFVNFRSSKVASASCESPERVKMFKAEFAIISEKNGELRKQVS
DLTEKVRLAEQKEVIKAGPFGTVTGLQTNPTVAPDESANPRLAKLLEKVAVNKEIIVVLANNNVKPMLEVQIASVKRVG
IQNYLVVPLDDSLESFCKSNEVAYYKRDPDNAIDVVGKSRRSSDVSGLKFRVLREFLQLGYGVLLSDVDIVFLQNPFGH
LYRDSDVESMSDGHDNNTAYGFNDVFDDPTMTRSRTVYTNRIWVFNSGFFY";

$TMpred_obj = Bio::SecreTary::TMpred->new( $limits );
#ok( defined $TMpred_obj, 'new() returned something.');
#isa_ok ($TMpred_obj, 'Bio::SecreTary::TMpred' );

#is( $TMpred_obj->get_sequence(), $sequence, "sequence is ok" );
#is( $TMpred_obj->get_sequence_id(), $id, "id is ok" );

# the raw output we should get from tmpred for this input:
my $tmpred_out1 = 'TMpred prediction output for : /home/tomfy/fastafiles/MAVRKEK.fasta
 
Sequence: MAV...NNT   length:     255
Prediction parameters: TM-helix length between 17 and 40
 
 
1.) Possible transmembrane helices
==================================
The sequence positions in brackets denominate the core region.
Only scores above  500 are considered significant.
 
Inside to outside helices :   2 found
      from        to    score center
  17 (  17)  35 (  35)   2479     25
 217 ( 220) 238 ( 236)    338    228

Outside to inside helices :   2 found
      from        to    score center
  15 (  15)  33 (  33)   2512     25
 217 ( 221) 239 ( 237)     29    229


 
2.) Table of correspondences
============================
Here is shown, which of the inside->outside helices correspond
to which of the outside->inside helices.
  Helices shown in brackets are considered insignificant.
  A "+"  symbol indicates a preference of this orientation.
  A "++" symbol indicates a strong preference of this orientation.
 
           inside->outside | outside->inside
    17-  35 (19) 2479      |    15-  33 (19) 2512      
(  217- 238 (22)  338 ++ ) |(  217- 239 (23)   29    ) 


3.) Suggested models for transmembrane topology
===============================================
These suggestions are purely speculative and should be used with
EXTREME CAUTION since they are based on the assumption that
all transmembrane helices have been found.
In most cases, the Correspondence Table shown above or the
prediction plot that is also created should be used for the
topology assignment of unknown proteins.

2 possible models considered, only significant TM-segments used

-----> slightly prefered model: N-terminus outside
 1 strong transmembrane helices, total score : 2512
 # from   to length score orientation
 1   15   33 (19)    2512 o-i

------> alternative model
 1 strong transmembrane helices, total score : 2479
 # from   to length score orientation
 1   17   35 (19)    2479 i-o';


$tmpred_out1 =~ s/^.*\n\s*//; #delete first line and whitespace (has temp file name - changes each time tmpred is run.)
$tmpred_out1 =~ s/\s*$//;
#print "tmpred_out1 [", $tmpred_out1, "]\n";
#print "length: ", length $sequence, "\n";
my ($tmpred_out2, $good_solns) = $TMpred_obj->run_tmpred($sequence, $id, 'pascal');
$tmpred_out2 =~ s/^.*\n\s*//; #delete first line and whitespace
$tmpred_out2 =~ s/\s*$//;
#$tmpred_out1 .= "x";


#comp($tmpred_out1, $tmpred_out2);

#print "tmpred_out2[", $tmpred_out2, "]\n";

is($tmpred_out1, $tmpred_out2, "tmpred raw output is ok");

is( $good_solns, "(2479,17,35)  (2512,15,33)", "tmpred solutions ok"); # summary of tmpred output

my ($iohs, $oihs) = $TMpred_obj->run_tmpred($sequence, $id, 'perl');
my @helices = (@$iohs, @$oihs);
my $s = "";
foreach (@helices){
	$s .= $_->get_descriptor_string() . "\n";
}
print $s;
#print $TMpred_obj->get_solutions(), "\n";





sub comp {
    my $str1 = shift;
    my $str2 = shift;
    $str1 .= "\n";
    $str2 .= "\n";
    my $OK          = 1;
    my $line_number = 0;
    while ( $str1 or $str2 ) {
        $str1 =~ s/(.*\n)//;
        my $line1 = $1;
        $str2 =~ s/(.*\n)//;
        my $line2 = $1;
        if ( $line1 ne $line2 ) {
            print "line number:  ", $line_number+1, "; not equal\n",
              "1>$line1", "2>$line2", "\n";
	$OK = 0;            
last;
        }else{
        $line_number++;
}
    }
    if ($OK) {
        print "$line_number lines agree.\n";
    }
}

