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
	    <u>SGN Methods</u> 
	    </div>
	    <div class="boxsubcontent">
	    <a href="/methods/unigene/unigene-builds.pl">SGN Unigene Builds</a> - The Sol Genomics Network unigene builds represent "minimally redundant" collections of expressed genes in Solanaceous species, constructed from EST/cDNA sequence data present in SGN's databases. 
	    </div>
            <div class="boxsubcontent">
            <a href="/methods/unigene/unigene-methods.pl">Unigene Assembly Process Overview</a> - Gives an overview of SGN's unigene assembly process.
	    </div>
	    <div class="boxsubcontent">
            <a href="/methods/unigene/unigene-precluster.pl">Preclustering and Transitive Closure Clustering</a> - Preclustering is a technique used to partition the input data into groups small enough for the assembly program to process. 
	    </div>
	    <div class="boxsubcontent">
            <a href="/methods/unigene/unigene-validation.pl">Assembly Process Validation</a> - This data attempts to characterize the differences in outputs of two separate processes
	    </div>
	    
	  </div>
</td>
<td width="25\%">&nbsp;</td>
</tr>
</table>
</center>

END_HEREDOC
$page->footer();