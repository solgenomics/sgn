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
	    <u>SGN Mutants</u> 
	    </div>
	    <div class="boxsubcontent">
            <a href="/mutants/mutants_main.pl">Mutants</a> - This page gives descriptions and links dealing with genes that make tomatoes, real time QTL, and TGRC.</div>
              
          </div>
</td>
<td width="25\%">&nbsp;</td>
</tr>
</table>
</center>

END_HEREDOC
$page->footer();