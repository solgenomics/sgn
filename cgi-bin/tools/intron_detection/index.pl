use strict;
use CXGN::Page;
my $page=CXGN::Page->new("Sol Genomics Network","Tyler");
$page->header();
print <<END_HEREDOC;

     <br />
     <center>
     <table class="boxbgcolor2" width="100%" summary="">
     <tr>
     <td width="25%">&nbsp;</td>
     <td width="50%" class="left">
	  <div class="boxcontent">
	  	    
	    <div class="subheading">
	    <u>SGN Intron Detection Tools</u> 
	    </div>
	    <div class="boxsubcontent">
              <a href="/tools/intron_detection/find_introns.pl">Intron Finder for Solanceae ESTs</a> - The SGN Intron Finder works by doing a blast search for Arabidopsis Thaliana proteins that are similar to the translated protein sequence of the DNA input.
            </div>
          </div>
</td>
<td width="25%">&nbsp;</td>
</tr>
</table>
</center>


END_HEREDOC


$page->footer();
