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
	    <u>SGN Miscellaneous</u> 
	    </div>
	    <div class="boxsubcontent">
            <a href="/misc/codon_usage/codon_usage.pl">Comparative Codon Usage Analysis</a> - Codon usage for tomato (L. esculentum) and potato (S. tuberosum) genes and comparison with codon usage in other organisms.
	    </div>                
    
	  </div>
</td>
<td width="25\%">&nbsp;</td>
</tr>
</table>
</center>

END_HEREDOC
$page->footer();