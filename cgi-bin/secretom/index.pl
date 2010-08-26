use strict;
use warnings;
use CXGN::Page;

my $page=CXGN::Page->new('Secretom','john');
$page->header('Secretom');
print<<END_HTML;
<div style="width:100%; color:#303030; font-size: 1.1em; text-align:left;">

<center>
<img style="margin-bottom:10px" src="/documents/img/secretom/secretom_logo_smaller.jpg" alt="secretom logo" />
</center>

<!--
<span style="white-space:nowrap; display:block; padding:3px; background-color: #fff; text-align:center; color: #444; font-size:1.4em">
The proteome of the plant cell wall is <em>critical</em> to our understanding of environmental interaction.
<br />
</span>
-->


<table width="750" style="border-collapse:collapse;">
<tr style="background-color:black">
<td style="text-align:center;border-right:1px solid black">
<img src="/documents/img/secretom/summary_header_thin.jpg" />
</td>
<td style="text-align:center">
<img src="/documents/img/secretom/objectives_header_thin.jpg" /> 
</td>
</tr>

<tr>

<td width="375" style="
	padding:5px;
	padding-right:10px;
	padding-top:16px;
	padding-bottom:15px;
	">


<b>Proteomic analysis of cellular compartments</b> provides essential insight into the subcellular location of a specific protein or protein complex; a valuable step towards understanding protein function and something that cannot be accurately predicted from primary sequence. Localization information also helps in the identification of protein interactions and provides a means to assess targeting, trafficking and residence in multiple compartments.  Moreover, the analysis of a subcellular proteome has the advantage of requiring "biological pre-fractionation," substantially enhancing the detection of lower abundance proteins.

<br /><br />
<b>The purpose of this NSF-funded project</b> is to catalog and study <a href="proteome.pl">the dynamic properties of the cell wall proteome, or secretome</a>, using tomato (<i>Solanum lycopersicum</i>) as a model system.
This will be achieved by coupling isotopic peptide labeling and shotgun mass spectrometry-based sequencing of highly enriched cell wall protein extracts with a range of newly developed functional screens and bioinformatics tools. These approaches will then be applied to characterize quantitative and qualitative changes in the wall proteome during fruit ripening and induction of defense responses. Additionally, a coordinated study will be performed of the tomato fruit secretome using protein expression profiling and microarray-based transcriptomics in wild type and ripening mutant fruit. This study in tomato will lay the foundation for a long-term exploration of the diversity of cell wall proteomes in a range of plant species.

<p><strong>All secretom datasets can be downloaded from the <a href="ftp://ftp.sgn.cornell.edu/secretom/">SGN FTP site</a>.</strong></p>

</td>



<td style="padding-right:15px;border-left:1px solid #999;">
<!--
This project to characterize the plant secretom includes the following goals:-->
<ol>
<li><b>Identify extracellular proteins:</b><ul>
<li><b>Extraction and anlysis of enriched cell wall protein extracts.</b>  Techniques have been developed to isolate extracellular proteins from various plant tissues, whilst minimizing contamination with intracellular proteins.  Post-translational modification (e.g. glycosylation and phosphorylation) of proteins in these extracts will also be studied.
<li><b>Computational prediction of secreted proteins.</b>  <a href="prediction.pl">Bioinformatics tools are under development to allow a more accurate <em>in silico</em> prediction of the secretome.</a>
<li><b>Functional screens for secreted proteins.</b>  We have adopted a number of high throughput functional approaches to identify secreted proteins from a range of eukaryotes, including an enhanced yeast secretion trap (YST) screen and the NIP assay.
</ul>

<li><b>Comparative analysis of the cell wall proteome in ripening tomato fruit and in tomato leaves following defense response elicitation.</b>

<li><b>Integrated cell wall proteome and transcriptome expression profiling.</b> Dynamic changes in the wall proteome will be compared with changes in the cognate transcriptome using micro-array analysis.

<li><b>Education, Training, and Outreach.</b> A number of <a href="training.pl">education and training opportunities</a> in plant proteomics and cell wall biology have been established.  <a href="outreach.pl">Internships are available</a>

</ol>
</td>
</tr>


<tr style="background-color:black">
<td width="375" style="text-align:center">
<img src="/documents/img/secretom/news_header_thin.jpg" />
</td>
<td style="text-align:center">
<img src="/documents/img/secretom/people_header_thin.jpg" />
</td>
</tr>

<tr>

<td rowspan="3" style="
		padding:10px;
		padding-left:15px;
		vertical-align:middle;
		border-right:1px solid #999">

<b>Upcoming Meetings</b><br />
<a href="http://www.sol2009.org/">Solanaceae 2009</a> Dehli, India, Nov 8-13<br />
<br />
<b>Past Meetings</b><br />

<a href="http://www.biotech.kth.se/woodbiotechnology/PPW">2008 Plant Polysaccharide Workshop</a> Aug 3-5, Sigtuna, Sweden<br />
<a href="http://www.aspb.org/">ASPB 2008</a> June 26-July 1, Merida, Mexico<br />
<a href="http://www.asms.org/">ASMS meeting</a> June 1-5, Denver, CO<br />
<br />

<br />
<b>Jobs</b><br />
The Rose lab is currently seeking a postdoctoral research associate with 
an interest in plant proteomics, or fruit development and ripening. 
Experience in mass spectrometry and plant molecular biology would 
be an advantage, and good communication skills are critical. 
Please contact Joss Rose if interested: 
<a href="mailto:jr286\@cornell.edu">jr286\@cornell.edu</a><br />
<br />
<!-- b>Workshop</b><br />
The annual summer proteomics workshop will be held in July 2008. 
Please contact Joss Rose if interested : 
<a href="mailto:jr286\@cornell.edu">jr286\@cornell.edu</a><br / -->

</td>

<td>
<ul>
<li>Joss Rose <a href="http://labs.plantbio.cornell.edu/rose/index.htm">[Lab]</a>
<li>Ted Thannhauser <a href="http://www.ars.usda.gov/PandP/docs.htm?docid=9634">[USDA Personal]</a>
<li>Jim Giovannoni <a href="http://www.bti.cornell.edu/page.php?id=308">[BTI Personal]</a>
<li>Lukas Mueller <a href="http://www.sgn.cornell.edu/about">[SGN]</a>
</ul>
</td>
</tr>
<tr>
<td style="background-color:black;
		text-align:center;
		padding:0px;">
<span style="font-size:1.8em;color:#fff">
External Links</span></td>
</tr>
<tr>
<td>
<ul>
<li><a href="http://www.ccrc.uga.edu/~mao/cellwall/main.htm">Plant Cell Wall Overview</a>
<li><a href="http://cell.ccrc.uga.edu/~mao/wallmab/Home/Home.php">Cell Wall Antibodies</a>
<li><a href="http://xyloglucan.prl.msu.edu">WallBioNet</a>
<li><a href="http://cellwall.genomics.purdue.edu/">Cell Wall Genomics</a>
</ul>
</td>

</tr>
</table>

<div style='height:3px; font-size:1px; background-color:#c0c0c0'>&nbsp;</div>
<br />


<table>
<tr>
<td width="650" style="padding-left:10px; padding-right:15px">
<span style="font-size:1.2em">
<b>Funding Summary</b>
</span><br /><br /> This project and database are funded by National Science Foundation Grant 
<a href="http://nsf.gov/awardsearch/showAward.do?AwardNumber=0606595">0606595</a>.
<br /><br />
For questions and comments regarding the SecreTom project, please contact Jocelyn Rose at <a href="mailto:jr286\@cornell.edu">jr286\@cornell.edu</a>
</td>
<td>
<a style="padding:0px" href="http://www.nsf.gov"><img border="0" src="/documents/img/secretom/NSF_Logo.jpg" width="100" height="100"/></a>
</td></tr></table>
</div>

END_HTML

$page->footer();
