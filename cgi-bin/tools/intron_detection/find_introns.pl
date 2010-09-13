#!/usr/bin/perl -w

#######################################################
#
#page to display the intron search form
#
#######################################################

use strict;
use warnings;
use CXGN::Page;

our $page = CXGN::Page->new( "Intron Finder", "Emil Keyder");

$page->header("Intron Finder For Tomato EST sequences",'Intron finder for Solanaceae ESTs');

print <<ENDINTRO;
The SGN Intron Finder works by doing a blast search for Arabidopsis Thaliana
proteins that are similar to the translated protein sequence of the DNA input.
The gene models of the Arabidopsis proteins are then looked up, and the intron
positions are mapped back to the input sequence.  The numbers displayed under 
the alignments correspond to DNA sequence numbers.<br/><br/>  

<b>Note</b>: A <a href="http://int-citrusgenomics.org/usa/ucr/Files.php">similar tool</a>, developed independently, is available from the Citrus Genomics Project at the University of California.<br/><br/>

Please enter your query in FASTA format.<br/><br/>
ENDINTRO

print <<EOF;

<form method="post" action="display_introns.pl" name="findintrons">

<textarea name="genes" rows="10" cols="100"></textarea> <br/><br/>

<table summary="" width="98%">
<tr>
    <td>
    Enter an e-value for blast: <input type="text" name="blast_e_value" value="1e-50" />
    </td>
   <td align="right">
    <input type="submit" name="submit" value="Find introns" />
   </td>
</tr>
</table>

</form>

EOF

$page->footer();
