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
	    <u>SGN Seedbac Tools</u> 
	    </div>
	    <div class="boxsubcontent">
              <a href="/tools/seedbac/chr_sbfinder.pl">Chromosome Seedbac Finder</a> - This tool lists all anchored bacs for a given chromosome to help identify seed bacs.
            </div> 
            <div class="boxsubcontent"> 
              <a href="/tools/seedbac/sbfinder.pl">Seedbac Finder</a> - This tool will suggest a seed bac given a marker name.
            </div>
	   
          </div>
</td>
<td width="25%">&nbsp;</td>
</tr>
</table>
</center>


END_HEREDOC


$page->footer();
