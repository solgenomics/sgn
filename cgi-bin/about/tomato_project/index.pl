use strict;
use CXGN::Page;
my $page=CXGN::Page->new('index.html','html2pl converter');
$page->header('NSF_SPONSORED TOMATO GENOMICS PROJECT');
print<<END_HEREDOC;

<center>


<table summary="" width="720" align="center">
<tr>
<td>
<center>
<h2>Welcome to the NSF-Funded Tomato Genomics Project</h2>
<a href=
"https://www.fastlane.nsf.gov/servlet/showaward?award=0116076">NSF
#0116076</a></center><br />

<p>Welcome to the information pages for the Tomato Genomics Project
(#0116076). This project is funded by the <a href=
"http://www.nsf.gov/funding/pgm_summ.jsp?pims_id=5338">National Science
Foundation Plant Genome Research Program</a>.
The purpose of these pages is to provide information on the goals
of the project, the P.I's involved in the project and public
resources developed as part of this project. If you have
suggestions/comments about this site or the Tomato Genomics Project
please e-mail <a href=
"mailto:sdt4\@cornell.edu">Steve Tanklsley</a>. For more details,
click on any of the topics below.</p>

<h3>PROJECT SUMMARY</h3>

<p>This project is the continuation and expansion of our previous tomato genome project <a href=
"nsf_9872617/index.pl">(NSF#9872617)</a> with an emphasis on physical, evolutionary and
functional genomics of the Solanaceae. In the first part of the
project a physical map, comprised of a set of overlapping BAC
clones, is being constructed for the tomato genome and anchored
against the genetic maps of tomato, other solanaceous species, and
the arabidopsis genome. This will be accomplished by using a set of
1000 conserved ortholog (COS) markers shared between the
arabidopsis and solanaceous genomes. The anchored BAC physical map
will: 1) facilitate positional cloning; 2) elucidate the
organization/distribution of genes with respect to centromeres,
heterchromatin, euchromatin and meiotic recombination; 3) provide a
new method for precise mapping; 4) provide the foundation and clone
resource for eventual tomato genome sequencing; and 5) shed light
on the nature of genome evolution in higher plants and help
establish a syntenic network though which genomic information can
be shared and compared among plants. To further investigate genome
organization and to determine the level of microsynteny among the
Solanaceae, a set of orthologous BAC clones from solanaceous
species will be sequenced and compared with each other and to
corresponding portions of the arabidopsis genome.</p>

<p>In the second part of the project, we apply two virus-induced
gene-silencing (VIGS) approaches as a means of associating gene
sequence with function. We continue to focus on defense responses
and fruit development - processes for which tomato is an excellent
model. In the first approach, we are developing a normalized,
elicitor-induced cDNA library of Nicotiana benthamiana in a potato
virus X (PVX) vector and use it for VIGS of orthologs to a set of
differentially-expressed tomato genes and also a set of 5,000
random genes. The plants so derived are screened for a variety of
defense responses including alterations in ethylene-regulated
phenotypes. In the second approach, we will use PVX constructs to
develop stable tomato transformants. These lines will contain
promising defense and ethylene response genes from the transient
VIGS analysis as well as genes specifically implicated in fruit
development/ripening. Results from these studies will provide new
information on the feasibility of large scale gene silencing for
tomato functional genomics and will result in the targeted
development of a comprehensive set of heritable gene repression
lines focused on two biological processes for which tomato is an
optimal model.</p>

<p>Finally, we are developing and distributing new resources for
genetic/genomic research in solanaceous species, including: 1) a
tomato non-redundant unigene set; 2) tomato cDNA microarrays; 3)
DNA, plantlets, and associated data sets from an F2 synteny mapping
population and seeds from a permanent RI mapping population; 4) 200
stable gene silenced tomato lines, 5) VIGs libraries (for transient
silencing); 6) set of tiled tomato BAC clones; and 7) new
solanaceous BAC libraries. To facilitate distribution of genomic
information for tomato in particular and for solanaceous species in
a comparative genomic context, we continue development of the
Solanaceae Genome Network database - a genomics database that ties
together information on sequence and genetic/physical maps among
solanaceous species and anchors this information against the
arabidopsis genome sequence. We will also develop a tomato gene
expression profiling database to curate and deliver cDNA microarray
data to the research public.</p>

<p>Implementation of this comprehensive tomato genomics project
will result in development of additional functional and structural
genomics tools built upon those developed in our previous proposal
and with extended applicability from tomato to the broader
Solanaceae. Functional genomics applications and the resulting
public databases will allow us and others to expand knowledge in
the areas of defense response, fruit development and genome
evolution.</p>

<h3>PRINCIPAL INVESTIGATORS</h3>
<table summary="">
<tr>
<td width="100"><u>Project P.I.s</u></td>
<td width="150"><u>Contact</u></td>
<td><u>Organization</u></td>
</tr>
<tr>
<td>S. Tanksley</td>
<td><a href="mailto:sdt4\@cornell.edu">sdt4\@cornell.edu</a></td>
<td>Cornell University</td>
</tr>
<tr>
<td>J. Giovannoni</td>
<td><a href="mailto:jjg33\@cornell.edu">jjg33\@cornell.edu</a></td>
<td>Texas A&amp;M</td>
</tr>
<tr>
<td>G. Martin</td>
<td><a href="mailto:gbm7\@cornell.edu">gbm7\@cornell.edu</a></td>
<td>Boyce Thompson Institute for Plant Research (BTI)</td>
</tr>
<tr>
<td>R. Wing</td>
<td><a href=
"mailto:rwing\@ag.arizona.edu">rwing\@ag.arizona.edu</a></td>
<td>Arizona Genome Initiative</td>
</tr>
</table>

<div style="text-align:left; float:left">
<h3>MEMBERS OF ADVISORY GROUP</h3>
Harry Klee, U. Florida, chair<br />
Sue Rhee, Carnegie Institution of Washington<br />
Dani Zamir, Hebrew U., Israel<br />
Danesh Kumar, Yale U.<br /></div>
<div style="text-align:center; float: right;"><img src=
"/documents/help/about/tomato_project/nsf-logo3.gif" width="91" height="100" border="0" alt="" /></div>
<div style="clear: both"></div>

</td>
</tr>
</table>

</center>
END_HEREDOC
$page->footer();