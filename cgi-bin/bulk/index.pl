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
            <u>SGN Bulk</u> 
            </div>
            <div class="boxsubcontent">
              <a href="/bulk/input.pl">Bulk Download</a> - Download information for a list of identifiers, or for complete datasets with FTP.
            </div>
       
          </div>
</td>
<td width="25%">&nbsp;</td>
</tr>
</table>
</center>

END_HEREDOC

$page->footer();
