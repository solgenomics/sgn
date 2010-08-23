#!/usr/bin/perl -w

#######################################################
#
#page to display form to get input to SecreTary 
#
#######################################################

use strict;
use CXGN::Page;

our $page = CXGN::Page->new( "SecreTary predictor", "TomFY");

$page->header("SecreTary",'SecreTary');

 my $wd = `pwd`;
print "wd: $wd \n";
print <<ENDINTRO;
This will be the page for SecreTary.<br/><br/>  

<b>Note</b>: A <a href="http://int-citrusgenomics.org/usa/ucr/Files.php">similar tool</a>, developed independently, is available from the Citrus Genomics Project at the University of California.<br/><br/>

   

Please enter your query in FASTA format.<br/><br/>
ENDINTRO

print <<EOF;

<form method="post" action="run_secretary.pl" name="secretary">

<textarea name="sequence" rows="10" cols="100"></textarea> <br/><br/>

<table summary="" width="98%">
<tr>
    <td>
    </td>
   <td align="right">
    <input type="submit" name="submit" value="Go" />
   </td>
</tr>
</table>

</form>

EOF

#    my $SToutput = `./SecreTary.pl < /home/tomfy/tempfiles/T8_ONE.fasta`;
# print '<pre>', "SecreTary output: [$SToutput] \n",  '</pre>';
$page->footer();
