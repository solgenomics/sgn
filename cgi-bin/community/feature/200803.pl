
use strict;

use CXGN::Page;

my $page = CXGN::Page->new("SGN Featured Lab: The Thompson Water Use Research Group", "Lukas");

$page->header("The Thompson Water Use Research Group", "The Thompson Water Use Research Group");

print <<HTML;

<center>
<img src="/static_content/community/feature/200803-group.png" width="70%"/>
<p>

Back row: Martin Sergeant, John Andrews, Jean-Charles Deswarte, James Lynn, Howard Hilton.<br />
Front row: Carol Ryder, Andrew Thompson, Liz Harrison
</center>
</p>


<p>
Our research group is part of Warwick HRI, formally a government research institute that included the Glasshouse Crops Research Institute (GCRI), which has a long history of tomato research, from genetics to crop physiology. Warwick HRI has been a department of the University of Warwick, UK since 2004 and is based at Wellesbourne.
</p>
<p>
	Water is the most important factor limiting crop production on a global scale and water resources are increasingly under pressure due to global climate change, competition from diverse users and the desire to protect the environment. Our research is driven by the need to generate crop varieties with improved water-use efficiency (WUE), suited to production with reduced water inputs.
</p>
<p>
	Abscisic acid (ABA) is a phytohormone that mediates plant response to abiotic stress, including water deficit stress. In collaboration with Dr. Ian Taylor (University of Nottingham) we have previously shown that the key rate-limiting step in ABA synthesis is 9-cis-epoxycarotenoid dioxygenase (NCED) and that over-expression of NCED in plants using constitutive promoters causes increased ABA accumulation and a range of physiological changes including improved WUE. We are currently extending this work to explore ways to improve WUE with minimal impact on crop productivity through more subtle manipulations of ABA biosynthesis, involving tissue-specific overproduction of ABA, root-to-shoot signalling, the generation of random alterations in NCED expression, and through exploitation of natural allelic variation in ABA biosynthetic genes.
</p>
<p>
	Continuing from our work on NCED we have initiated a project on the chemical genetics of the broader family of carotenoid cleavage dioxygenases (CCDs), of which NCED is a member. Working with Prof. Tim Bugg at the Warwick Chemistry Dept. we are developing chemical inhibitors of the different classes of CCD.
</p>
	
<p>Another major objective of our research program is to discover quantitative trait loci (QTL) that control traits related to WUE and drought resistance, and then to progress to the identification of the underlying genes. We are using introgression line populations from crosses between tomato and its wild relatives to identify genes that improve rooting depth and ability to penetrate soil. The same traits are being assessed in collections of wild species of tomato and potato. We have also performed field trials to establish the intrinsic WUE of commercial cultivars of potato using a range of physiological assessments, including stable isotope techniques.
</p>
<p>
	Beyond the Solanaceae we are using other genetic systems from the Brassicaceae, including Brassica oleracea and Arabidopsis thaliana to understand the genetic control of WUE.
</p>

<hr>
 
<h4>SELECTED PUBLICATIONS</h4>
<p>
Thompson A J, Andrews J, Mulholland B J, McKee J M T, Hilton H W, Horridge J S, Farquhar G D, Smeeton R C, Smillie I R A, Black C R, Taylor I B (2007a) 'Over-production of abscisic acid in tomato increases water-use efficiency and root hydraulic conductivity and influences leaf expansion' Plant Physiology 143:1905-1917.</p>
<p>Thompson A J, Mulholland B J, Jackson A C, McKee J M T, Hilton H W, Symonds R C, Sonneveld T, Burbidge A, Stevenson P, Taylor I B (2007b) 'Regulation and manipulation of ABA biosynthesis in roots.' Plant Cell and Environment 30:67-78.</p>
<p>Manning K, Tor M, Poole M, Hong Y, Thompson A J, King G J, Giovannoni J J and Seymour G B (2006) 'A naturally occurring epigenetic mutation in an SBP-box transcription factor inhibits tomato fruit ripening' Nature Genetics 38:948-952.</p>
<p>Thompson A J, Thorne E T, Burbidge A, Jackson A C, Sharp R E, Taylor I B (2004) 'Complementation of notabilis, an abscisic acid-deficient mutant of tomato: importance of sequence context and utility of partial complementation', Plant Cell And Environment, 27:459-471.  </p>
<p>Thompson A J, Jackson A C, Symonds R C, Mulholland B J, Dadswell R, Blake P S, Burbidge A and Taylor I B (2000) 'Ectopic expression of a tomato 9-cis-epoxycarotenoid dioxygenase gene causes over-production of abscisic acid', The Plant Journal, 23:363-374.</p>

<h4>Contact Details</h4>

Dr Andrew J. Thompson<br />
Warwick HRI<br />
University of Warwick<br />
Wellesbourne<br />
Warwick<br />
CV35 9EF<br />
UK<br />

<p><a href="http://www2.warwick.ac.uk/fac/sci/whri/research/plantwateruse/">http://www2.warwick.ac.uk/fac/sci/whri/research/plantwateruse/</a></p>
email: a.j.thompson\@warwick.ac.uk<br />

Tel: +44 (0) 24 7657 5090<br />

    <img src="/static_content/community/feature/200803-bbsrc.png" />&nbsp;
<img src="/static_content/community/feature/200803-defra.png" />


<h4>Figures</h4>

<img src="/static_content/community/feature/200803-warick.png" />
<p>
Figure 1: Aerial photograph of Warwick HRI at Wellesbourne, Warwickshire, UK.
</p>
<br />
<br />

<img src="/static_content/community/feature/200803-leaf.png" />
<p>
Figure 2: A tomato leaf showing over-guttating phenotype. This arises from the sequence of events: over-expression of 9-cis-epoxycarotenoid dioxygenase, over-accumulation of ABA, increased root pressure. From Thompson et al 2000.
</p>
<br />
<br />


<img src="/static_content/community/feature/200803-graph.png" />
<p>
Figure 3: Water-use efficiency (WUE) (A) and transpiration (B) in wild-type (WT) and NCED over-expressing tomato plants (sp12 and sp5). WUE was measured by gas-exchange (A, CO2 assimilation; gs, stomatal conductance) and by leaf carbon isotope composition (δ13C). Transpiration was also estimated by leaf oxygen isotope composition (δ18O). Redrawn from Thompson et al 2007a.
</p>
<br />
<br />


<img src="/static_content/community/feature/200803-greenhouse.png" width="60%" />
<img src="/static_content/community/feature/200803-root.png" />
<p>
Figure 4: Tomato plants growing in glass-fronted rhizotrons, and an image of roots taken through the glass.
</p>

HTML

    $page->footer();
