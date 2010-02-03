use strict;
use CXGN::Page;
my $page=CXGN::Page->new('index.html','html2pl converter');
$page->header('Sol Genomics Network');
print<<END_HEREDOC;

  
     

     <br />
     <center>
     <table summary="" class="boxbgcolor2" width="100\%">
     <tr>
     <td width="25\%">&nbsp;</td>
     <td width="50\%" class="left">
	  <div class="boxcontent">
	  	    
	    <div class="subheading">
	    <u>SGN Content</u> 
	    </div>
	    <div class="boxsubcontent">
            <a href="/content/unigene_builds/Lycopersicon_Combined.pl">Lycopersicon Combined Unigene Build Series</a> - This unigene build series incorporates ESTs derived from Lycopersicon hirsutum, Lycopersion pennellii, and Lycopersion esculentum cDNA libraries.
	    </div>
              
          </div>
</td>
<td width="25\%">&nbsp;</td>
</tr>
</table>
</center>

END_HEREDOC
$page->footer();