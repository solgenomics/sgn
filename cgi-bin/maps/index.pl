use strict;
use CXGN::Page;
my $page=CXGN::Page->new('index.html','html2pl converter');
$page->header('Maps');
print<<END_HEREDOC;

    


     <br />
     <center>
     <table summary="" class="boxbgcolor2" width="100\%">
     <tr>
     <td width="25\%">&nbsp;</td>
     <td width="50\%" class="left">
	  <div class="boxcontent">
	    
	    <div class="subheading">
    <u>Tomato maps</u>
             </div>
	    <div class="boxsubcontent">
    <p><em>L. esculentum x L. pennellii</em> maps:</p>
    <ul style="list-style-type:none">
    <li><p><a href="/maps/tomato_arabidopsis/index.pl">Tomato - Arabidopsis synteny map</a></p></li>
    <li><p><a href="/maps/pennellii_il/index.pl">Isogenic Line (IL) map</a></p></li>
    </ul>
    <p><em>L. pimpinellifolium</em> inbred backcross lines map:</p>
    <ul style="list-style-type:none">
    <li><p><a href="lpimp_ibl/index.pl">IBL map</a></p></li>
    </ul>
           </div>


	    <div class="subheading">
    <u>Markers</u>
             </div>

	    <div class="boxsubcontent">
       <p><a href="/markers/cos_markers.pl">COS-markers</a></p>
       <p><a href="/markers/microsats.pl">Microsatellites (SSRs)</a></p>
             </div>
             </div>

</td>
<td width="25\%">&nbsp;</td>
</tr>
</table>
</center>
    
END_HEREDOC
$page->footer();