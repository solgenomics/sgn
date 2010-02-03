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
	  <br />
	    
	    <div class="subheading">
	    <u>SGN Markers</u> 
	    </div>
	    <div class="boxsubcontent">
            <a href="/markers/cos_markers.pl">Conserved Ortholog Set (COS) Markers</a> - In this section of SGN, you will find sequence and clone information for each of these COS markers as well as their matching counterpart in the arabidopsis genome. We have surveyed these COS markers and mapped some of these COS markers on the tomato genome to provide a tomato: arabidopsis comparative map. This mapping information is available on SGN now.
	    </div>
	    <div class="boxsubcontent">
	    <a href="/markers/cosii_markers.pl">Conserved Ortholog Set II (CosII) Markers</a> - In this section of SGN, you will find sequence information of each COSII gene as well as the mapping information of those mapped COSII genes (so called COSII markers). We've mapped more than 100 COSII markers in tomato and will map more in the future, up to at least 500, and in the meanwhile, these COSII markers will be mapped in major solanaceous species (e.g. eggplant, pepper, Nicotiana, etc.). All the information in this section will be updated as new data are generated, so please come back and check from time to time.
	    </div>
	    <div class="boxsubcontent">
	    <a href="/markers/microsats.pl">Microsatellites (SSRs)</a> - While microsatellites or simple sequence repeats (SSRs) normally occur in non-coding regions of the genome, they can also occur in either 3' or 5' UTRs of ESTs or even in coding regions (usually triplet repeats). See this page for more information.
	    </div> 
              
          </div>
</td>
<td width="25\%">&nbsp;</td>
</tr>
</table>
</center>

END_HEREDOC
$page->footer();