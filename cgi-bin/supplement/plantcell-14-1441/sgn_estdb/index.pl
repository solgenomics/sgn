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
	    <u>Plantcell Supplement</u> 
	    </div>
	    <div class="boxsubcontent">
            <a href="/supplement/plantcell-14-1441/bac_annotation.pl">Annotation of 6 Tomato BAC sequences</a> - This page links to files that represent the data analysis and annotation results of the six BACs mentioned in this paper. The Artmenis files summarize the annotation of the BACs and are viewable with the DNA sequence viewer Artemis [1] available from the Sanger center. [Download] These files may also be viewed as plain text. The BLAST files are BLAST outputs of sequence similarity analyses against various databases available at SGN. [2]
	    </div>
              
          </div>
</td>
<td width="25\%">&nbsp;</td>
</tr>
</table>
</center>

END_HEREDOC
$page->footer();