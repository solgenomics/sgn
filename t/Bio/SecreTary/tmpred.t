#!/usr/bin/perl -w
use strict;

# tests for TMpred Module
 
use Test::More tests=>11;  # qw / no_plan / ;  
use Bio::SecreTary::TMpred;

use SGN::Context;

$ENV{PATH} .= ':programs';

my $limits = [500, 10, 40, 0, 40];
my $id = "AT1G50920.1";
my $sequence = "MVQYNFKRITVVPNGKEFVDIILSRTQRQTPTVVHKGYKINRLRQFYMRKVKYTQTNFHAKLSAIIDEFPRLEQIHPFYGDLLHVLYNKDHYKLALGQVNTARNLISKISKDYVKLLKYGDSLYRCKCLKVAALGRMCTVLKRITPSLAYLEQIRQHMARLPSIDPNTRTVLICGYPNVGKSSFMNKVTRADVDVQPYAFTTKSLFVGHTDYKYLRYQVIDTPGILDRPFEDRNIIEMCSITALAHLRAAVLFFLDISGSCGYTIAQQAALFHS*";

my $TMpred_obj = Bio::SecreTary::TMpred->new( $limits, $sequence, $id );
ok( defined $TMpred_obj, 'new() returned something.');
ok ($TMpred_obj->isa('Bio::SecreTary::TMpred'), "it belongs to the correct class.");

ok( $TMpred_obj->get_sequence() eq $sequence, "sequence is ok");
ok( $TMpred_obj->get_sequence_id() eq $id, "id is ok");

ok( $TMpred_obj->get_solutions() eq "(-10000,0,0)", "tmpred solutions ok"); # this is a summary of the most useful bits of the tmpred output
#print $TMpred_obj->get_solutions(), "\n";

$id = "AT1G75120.1";
$sequence = "MAVRKEKVQPFRECGIAIAVLVGIFIGCVCTILIPNDFVNFRSSKVASASCESPERVKMFKAEFAIISEKNGELRKQVS
DLTEKVRLAEQKEVIKAGPFGTVTGLQTNPTVAPDESANPRLAKLLEKVAVNKEIIVVLANNNVKPMLEVQIASVKRVG
IQNYLVVPLDDSLESFCKSNEVAYYKRDPDNAIDVVGKSRRSSDVSGLKFRVLREFLQLGYGVLLSDVDIVFLQNPFGH
LYRDSDVESMSDGHDNNTAYGFNDVFDDPTMTRSRTVYTNRIWVFNSGFFY";

$TMpred_obj = Bio::SecreTary::TMpred->new( $limits, $sequence, $id );
ok( defined $TMpred_obj, 'new() returned something.');
ok ($TMpred_obj->isa('Bio::SecreTary::TMpred'), "it belongs to the correct class.");

ok( $TMpred_obj->get_sequence() eq $sequence, "sequence is ok");
ok( $TMpred_obj->get_sequence_id() eq $id, "id is ok");

# the raw output we should get from tmpred for this input:
my $tmpred_out1 = 'TMpred prediction output for : /home/tomfy/tempfiles/tmpred_input_WajeGg
 
Sequence: MAV...FFY   length:     288
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
my $tmpred_out2 = $TMpred_obj->get_tmpred_out();
$tmpred_out2 =~ s/^.*\n\s*//; #delete first line and whitespace
$tmpred_out2 =~ s/\s*$//;
#$tmpred_out1 .= "x";
#print "tmpred_out2[", $tmpred_out2, "]\n";

ok($tmpred_out1 eq $tmpred_out2, "tmpred raw output is ok"); 

ok( $TMpred_obj->get_solutions() eq "(2479,17,35)  (2512,15,33)", "tmpred solutions ok"); # summary of tmpred output
#print $TMpred_obj->get_solutions(), "\n";

