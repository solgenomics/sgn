
use strict;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw / page_title_html /;

my $page = CXGN::Page->new();
$page->header();
my $title = page_title_html("Feature: The Litt Lab");

print <<HTML;

$title

<center><img src="/static_content/community/feature/labs/litt_amy/litt_lab_photo.jpg" alt="Litt Lab Photo" width="400" height="300"/>

<p class="tinytype">
Back row, left to right: Hontao Chen, Amy Litt, Natalia Pabon-Mora, Abeer Mohamed
Front row, left to right: Rachel Meyer, Jeff Gordon, Vinson Doyle
</p>
</center>
<table width="100%" cellpadding="10"><tr>
<td>
Our lab is part of the relatively new Genomics Program at The New York Botanical Garden, located in the brand new Pfizer Plant Research Laboratory.  Our interests are in the evolution of flower and fruit morphology, and the underlying changes in molecular processes that are responsible for the origin of new forms.  


We are currently working on a project aimed at identifying genes involved in determining fruit morphology.  Within Solanaceae, capsules appear to be ancestral; with the origin of the Solanoideae clade there was a shift to berry formation.  Our goal is to identify some of the molecular changes that produced this shift by comparing gene expression profiles at key developmental timepoints in Nicotiana sylvestris (flowering tobacco, a capsule-producing species) and tomato.  The project is a collaboration with Vivian Irish (Yale University) and Jim Giovannoni (USDA/BTI).

Capsule development is poorly known so we have undertaken morphological characterization this process to identify stages comparable to those recognized in tomato.  Currently we are also examining Petunia and Datura (a member of the Solanoideae that produces a capsule, and is thus an evolutionary reversion) and Cestrum (an independent origin of a berry) to determine the range of variability in capsules and berries within Solanaceae.  We are also analyzing the function in flowering tobacco of orthologs of genes that are known to play a role in tomato development.
</td>
<td style="text-align:center; vertical-align:middle">
<img src="/static_content/community/feature/labs/litt_amy/developmental_stages.jpg" alt="Developmental Timepoints" width="280" height="214" style=""><br />
Developmental timepoints in <em>Nicotiana</em> capsule development
</td>
</tr>
</table>
<br />
<table width="100%" cellpadding="10">
<tr>
<td style="vertical-align:middle">
<img src="/static_content/community/feature/labs/litt_amy/ara_flower.jpg" alt="Developmental Timepoints" width="305" height="298" align="center" style=""><br />
</td>
<td style="vertical-align:middle">
Our other long-term interest is in the evolution and function of the APETALA1 (AP1) gene lineage.  These genes appear to be required for flower formation, and are confined to the angiosperms, making them attractive candidates for involvement in the origin of the flower.  
A member of the MADS-box gene family, Arabidopsis AP1 is required for the proper transition from inflorescence to floral meristem, and for the formation of sepals and petals.  AP1 provides the A function of the ABC model of flower development, but to date the A mutant phenotype (mis-specified sepals and petals) is known only from Arabidopsis, casting doubt on the universality of this function.  
In addition, this lineage, along with other MADS-box gene lineages, underwent a duplication, accompanied by sequence divergence, that coincided with the origin of the core eudicots.  The Arabidopsis genome contains 
three members of this lineage that are involved in flower development: AP1, CAULIFLOWER (CAL, similar to AP1), and FRUITFULL (FUL), but species outside of the core eudicots only have genes similar in sequence to FUL. We are interested in assessing the function of members of this gene lineage within and outside the core eudicots, in determining the roles of conserved amino acid motifs, and in understanding the role and functional evolution of this gene lineage.
</td></tr></table>


<div style='clear:all;width:100%'>&nbsp;</div>
<p>
<b><u>Contact Information</u></b><br />
Dr. Amy Litt<br />
The New York Botanical Garden<br />
200th St and Southern Blvd. <br />
Bronx, NY 10458 <br />
Phone: 718-817-8161<br />
e-mail: alitt\@nybg.org or amyjlitt\@gmail.com
</p>

<p>
<b><u>Selected Publications</u></b>
<ul style="list-style:none">
<li>Litt, A. 2007. An evaluation of A function: evidence from the APETALA1 and APETALA2 gene lineages.  International Journal of Plant Sciences 168(1): 73-91. 
<li>Litt, A. 2006.  Origins of floral diversity.  Natural History 115(5): 34-40.
<li>Hileman, L. C., S. Drea, G. de Martino, A. Litt, and V.F. Irish. 2005. Virus induced gene silencing is an effective tool to assay gene function in the basal eudicot Papaver somniferum (opium poppy). Plant Journal. 44(2): 334-41
<li>Irish, V. F., and A. Litt.  2005.  Flower development and evolution: gene duplication, diversification, and redeployment.  Current Opinions in Genes and Development 15: 454 60.
<li>Litt, A. and V. F. Irish.  2003.  Duplication and divergence in the APETAL1/FRUITFULL gene lineage: implications for the evolution of floral development programs.  Genetics 165:821-833.
<li>Litt, A. and D. W. Stevenson.  2003.  Floral morphology of Vochysiaceae I.  Position of the single fertile stamen.  American Journal of Botany 90:1533-1547
<li>Litt, A. and D. W. Stevenson. 2003.  Floral morphology of Vochysiaceae II.  Structure of the gynoecium. American Journal of Botany 90:1548-1559.
<li>Litt., A. and M. Cheek.  2002.  Korupodendron songweangum, a new genus and species of Vochysiaceae from West-Central Africa.  Brittonia 54: 13-17.

</ul></p>
HTML


$page->footer();
