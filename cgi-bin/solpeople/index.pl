use strict;
use CXGN::Page;
my $page=CXGN::Page->new("Sol Genomics Network","Tyler");
$page->header();
print <<END_HEREDOC;

     <br />
     <center>
     <table class="boxbgcolor2" width="100%" summary="">
     <tr>
     <td width="33%">&nbsp;</td>
     <td width="33%" class="left">
	  <div class="boxcontent">
	  <br />
	    
	    <div class="subheading">
	    <u>SGN Info</u> 
	    </div>
	    <div class="boxsubcontent">
              <a class="creativitylinks" href="/content/sgn_data.pl">SGN data overview</a><br />
              <a class="creativitylinks" href="/about">More about SGN</a><br />
              <a class="creativitylinks" href="/solanaceae-project/">SOL project</a><br />
              <a class="creativitylinks" href="/solanaceae-project/#SOL_news">SOL newsletter</a><br />
              <a class="creativitylinks" href="/about/tomato_sequencing.pl">International tomato project</a><br />
            </div>
	   
            <div class="subheading">
            <u>Solanaceous Species</u>
            </div>
	    <div class="boxsubcontent">
	      <a class="creativitylinks" href="/content/sgn_data.pl#Solanumlycopersicum(formerlyLycopersiconesculentum)">Tomato</a><br /> 
              <a class="creativitylinks" href="/content/sgn_data.pl#Capsicumannuum">Pepper</a><br />
	      <a class="creativitylinks" href="/content/sgn_data.pl#Solanumtuberosum">Potato</a><br />
	      <a class="creativitylinks" href="/content/sgn_data.pl#Solanummelongena">Eggplant</a><br />
	      <a class="creativitylinks" href="/content/sgn_data.pl#Petuniahybrida">Petunia</a><br />
	      <a class="creativitylinks" href="/about/solanum_nomenclature.pl">Solanum nomenclature</a>
            </div>
	    
	    <div class="subheading">
            <u>Tomato Genome</u>
            </div>
            <div class="boxsubcontent">
              <a class="creativitylinks" href="/about/tomato_sequencing.pl">Sequencing progress</a><br />
              <a class="creativitylinks" href="/search/direct_search.pl?search=BACs">Search BACS</a><br />
              <a class="creativitylinks" href="/maps/physical/overgo_process_explained.pl">Overgo plating process</a>
            </div>
	    
            <div class="subheading">
            <u>Maps and Markers</u>
            </div>
	    <div class="boxsubcontent">
              <a class="creativitylinks" href="/cview/index.pl">Available maps</a><br />
              <a class="creativitylinks" href="/search/direct_search.pl?search=Markers">Search markers</a><br />
	      <a class="creativitylinks" href="/markers/cosii_markers.pl">About COSII markers</a><br />
	      <a class="creativitylinks" href="/markers/cosii.xls">New COSII data available now</a><br />
            </div>
	    
	    <div class="subheading">
            <u>Sequences</u>
            </div>
            <div class="boxsubcontent">
              <a class="creativitylinks" href="/search/direct_search.pl?search=EST">Search ESTs</a><br />
              <a class="creativitylinks" href="/search/direct_search.pl?search=Unigene">Search unigenes</a><br />
              <a class="creativitylinks" href="/search/library_search.pl?term=">cDNA libraries</a>
            </div>

            <div class="subheading">
            <u>Tools</u>
            </div>
            <div class="boxsubcontent">
              <a class="creativitylinks" href="/tools/blast/">BLAST</a><br />
              <a class="creativitylinks" href="/tools/intron_detection/find_introns.pl">Intron finder</a><br />
            </div>

            <div class="subheading">
            <u>Phenotypes and Mutants</u>
            </div>
            <div class="boxsubcontent">
              <a class="creativitylinks" href="/mutants/mutants_main.pl">Mutants page</a>
            </div>

            <div class="subheading">
            <u>Order cDNA clones</u>
            </div>
            <div class="boxsubcontent">
              <a class="creativitylinks" href="/help/ordering/">Ordering page</a>
            </div>
          </div>
</td>
<td width="33%">&nbsp;</td>
</tr>
</table>
</center>

END_HEREDOC

$page->footer();
