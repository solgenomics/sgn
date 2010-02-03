use strict;
use CXGN::Page;
my $page=CXGN::Page->new('index.html','html2pl converter');
$page->header('Sol Genomics Network');
print<<END_HEREDOC;

  
     

     <br />
     <center>
     <table summary="" class="boxbgcolor2" width="100\%">
     <tr>
     <td width="33\%">&nbsp;</td>
     <td width="33\%" class="left">
	  <div class="boxcontent">
	  <br />
	    
	    <div class="subheading">
	    <u>Links</u> 
	    </div>
	    <div class="boxsubcontent">
              <a class="creativitylinks" href="genefinding.pl">Genefinding tools<br />Primer Design<br />Promoter Predictions</a><br />
              <a class="creativitylinks" href="journals.pl">Journals on the Web</a><br />
              <a class="creativitylinks" href="seed_companies.pl">List of Solanaceae Seed companies</a><br />
              <a class="creativitylinks" href="related_sites.pl">Solanaceae Resources on the Web	</a><br />
            </div>
          </div>
</td>
<td width="33\%">&nbsp;</td>
</tr>
</table>
</center>

END_HEREDOC
$page->footer();