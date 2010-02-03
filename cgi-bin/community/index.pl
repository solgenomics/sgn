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
	    <u>SGN Community</u> 
	    </div>
	    
            <div class="boxsubcontent">  
	    <a href="/static_content/community/genomics_forum/dec17_latex.pdf"><i>Latex, Bibtex, and Friends</i></a> - A report on latex and bibtex.
	    </div>
	    <div class="boxsubcontent">
	    <a href="/static_content/community/genomics_forum/slides/repeat_analysis.pdf"><i>Approaches to Repeat Finding</i></a> - A report on repeat finding.
	    </div>
            <div class="boxsubcontent">  
	    <a href="/community/links/genefinding.pl">Gene Finding Links</a> - Provides links to genefinding tools, primer design, and promoter predictions.
	    </div>
            <div class="boxsubcontent">  
	    <a href="/community/links/journals.pl">Online Journal Links</a> - Provides links to journals on the web.
	    </div>
	    <div class="boxsubcontent">  
	    <a href="/community/links/related_sites.pl">Solanaceae Resources Links</a> - Provides links to Solanaceae systematics, descriptions, and images. Also links to tomato, potato, pepper, petunia, coffee, germplasm, and other sequence resources.  
	    </div>
	    <div class="boxsubcontent">  
	    <a href="/community/links/seed_companies.pl">Seed Companies Links</a> - Provides links to a list of Solanceae Seed companies. 
	    </div>
	    <div class="boxsubcontent">  
	    <a href="/static_content/community/meetings/TBRT_brochure.pdf">TBRT Brochure</a> - Brochure on the Tomato Breeders Roundtable.
	    </div>
                  
          </div>
</td>
<td width="25\%">&nbsp;</td>
</tr>
</table>
</center>

END_HEREDOC
$page->footer();
