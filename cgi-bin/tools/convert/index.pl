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
	    <u>SGN Conversion Tools</u> 
	    </div>
	    <div class="boxsubcontent">
              <a href="/tools/convert/input.pl">ID Converter</a> - The Institute for Genomic Research and SGN maintain independent unigene databases, entries in which tend to have common member ESTs, although they tend not to correspond completely. This tool uses common members to convert back and forth between the two identifier sets. 
            </div>
	          
          </div>
</td>
<td width="25%">&nbsp;</td>
</tr>
</table>
</center>


END_HEREDOC


$page->footer();
