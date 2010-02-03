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
	    <u>SGN EST Libraries</u> 
	    </div>
	    <div class="boxsubcontent">
              <a class="creativitylinks" href="/about/tomato_project/nsf_9872617/progress.pl">Progress of EST Sequencing</a><br />
            </div>
          </div>
</td>
<td width="33\%">&nbsp;</td>
</tr>
</table>
</center>

END_HEREDOC
$page->footer();
