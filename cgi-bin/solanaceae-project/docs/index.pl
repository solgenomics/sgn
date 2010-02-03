use strict;
use CXGN::Page;
my $page=CXGN::Page->new('index.html','html2pl converter');
$page->header('Sol Genomics Network');
print<<END_HEREDOC;

  
     

     <center>
     <table summary="" class="boxbgcolor2" width="100\%">
     <tr>
     <td width="25\%">&nbsp;</td>
     <td width="50\%" class="left">
	  <div class="boxcontent">
	  	    
	    <div class="subheading">
	    <u>SGN Solanaceae Project Documents</u> 
	    </div>
	    <div class="boxsubcontent">
            <a href="/static_content/solanaceae-project/docs/Guideline_v2.pdf">Guideline for Selecting Seed BACs</a> - Includes confirming the hybridization of genetic markers with BAC clones, verifying the location of BACs on chromosome, selecting seed BACS, and selecting the first extension BACs.
            </div>
	    <div class="boxsubcontent">
            <a href="/static_content/solanaceae-project/docs/SOL_newsletter_Nov_04.pdf"><i>SOL Newsletter</i> Issue Number 1</a> - In this issue you will find an introduction into the <i>SOL Newsletter</i>. 
            </div>
	    <div class="boxsubcontent">
            <a href="/static_content/solanaceae-project/docs/SOL_newsletter_Dec_04.pdf"><i>SOL Newsletter</i> Issue Number 2</a> - In this issue you will find brief status reports from each group participating in the tomato genome sequencing effort, items related to SGN and bioinformatics, and a new section called Community News. The purpose of this new section is to provide groups doing research on the various Solanaceous crops with the opportunity to post information. Information can be sent by e-mail to Joyce Van Eck at jv27\@cornell.edu.
            </div>
	    <div class="boxsubcontent">
            <a href="/static_content/solanaceae-project/docs/SOL_newsletter_Mar_05.pdf"><i>SOL Newsletter</i> Issue Number 3</a> - In this issue you will find brief updates from participants in the tomato genome sequencing effort, eggplant related news in the Community News section, the latest on SGN and bioinformatics, plus information on the 2nd Solanaceae Genome Workshop.
	    </div>
	    <div class="boxsubcontent">
            <a href="/static_content/solanaceae-project/docs/SOL_newsletter_May_05.pdf"><i>SOL Newsletter</i> Issue Number 4</a> - In this issue you will find an overview of the second Solanaceae Genome Workshop. There is also an article titled <i>The Solanaceae Collection of the Botanical and Experimental Garden, Radboud University Nijmegen, the Netherlands</i> contributed by Gerard M. van der Weerden.
            </div>
	    <div class="boxsubcontent">
            <a href="/static_content/solanaceae-project/docs/SOL_newsletter_July_05.pdf"><i>SOL Newsletter</i> Issue Number 5</a> - In this issue you will find several tomato sequencing updates and an article titled <i>Towards the Development of a Basic Genomics Platform for Exotic Fruid Solanaceae</i> contributed by Stella Luz Barrero.
            </div>
	    <div class="boxsubcontent">
            <a href="/static_content/solanaceae-project/docs/solanaceae-countries.pdf">Solanaceae Research in Different Countries</a> - Includes the status of research from these countries: Argentina, Brazil, Canada, China, Colombia, European Union (EU), France, Germany, Hungary, India, Israel, Italy, Japan, Korea, Mexico, Palestine, Peru, Poland, Spain, Sweden, Switzerland, The Netherlands, Taiwan, Turkey, United Kingdom, and the United States.
	    </div>
	    <div class="boxsubcontent">
            <a href="/static_content/solanaceae-project/docs/solanaceae-crop.pdf">Status of Solanaceae Crops Research</a> - Includes the status of research on these plants: tomato, potato, pepper, eggplant, petunia, tree tomato, pepino, naranjilla, and coffee.
            </div>
	    <div class="boxsubcontent">
            <a href="/static_content/solanaceae-project/docs/tomato-sequencing.pdf">Tomato Sequencing Rationale</a> - This is a technical document for an international consortium to sequence the tomato genome.
	    </div>
	    <div class="boxsubcontent">
	    <a href="/static_content/solanaceae-project/docs/tomato-standards.pdf">SOL Project Sequencing and Bioinformatics Standards and Guidelines</a> - This report includes: data archiving, standards for BAC closure/finishing, sequence release policy and submission to Genbank, gene nomenclature conventions, guidelines for structural and functional gene annotations, training datasets and quality control, data format standards, and standard MOBY services.
	    </div>

	  </div>
</td>
<td width="25\%">&nbsp;</td>
</tr>
</table>
</center>

END_HEREDOC
$page->footer();