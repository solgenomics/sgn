use strict;
use CXGN::Page;
my $page=CXGN::Page->new('200510','Teri Solow');

my $stylesheet=<<END_STYLESHEET;
<style type="text/css">
<!--
	body {
		color: #000000;
		background-color: #ffffff;
	}

	p {
		margin-left: 40px;
		text-align: justify;
	}

	.footnote {
		font-size: small;
		/*width: 700px;*/
		text-align:center;
	}

	.bibliography {
		text-indent: -20px;
	}
-->
</style>
END_STYLESHEET

$page->header('The Jahn Lab', undef, $stylesheet);
print<<END_HEREDOC;

<center>
<h1>The Jahn Lab</h1>
</center>

<p class="footnote"><img src="/static_content/community/feature/200510-1.jpg" border="4" style="border-color: #000000" width="800" height="600" alt="Jahn Lab" /><br />
</p>

<p style="border-bottom: 0px">The research in our group focuses on gene discovery, the analysis of
genome structure and function and the relevance of this information for the
improvement of useful plants.  Work in our program includes fundamental
studies of the relationship between model species and less well-
characterized crop species, the release of varieties and advanced breeding
lines, development of improved selection strategies, and research on the
genetics of disease resistance and fruit quality.  Specifically, a major
effort in the lab is to demonstrate the extent to which results from a
leading plant model, tomato, are relevant to the related, but much less
well-characterized genus, <em>Capsicum</em>, the garden pepper. Towards this end we
have developed a detailed comparative genetic map for the Solanaceae now
defining the broadest comparative genetic system in the dicots. We have
used this tool to identify candidates for traits with simple and
quantitative inheritance and to assess the relationships between genes in
tomato and pepper that affect similar or related traits. Further studies
are focusing on traits considered distinctive</p>

<p class="footnote" style="float:right; width:375px; text-align:center;"><img src="/static_content/community/feature/200510-2.gif" border="4" style="border-color: darkgreen" width="333" height="229" alt="Different species and varieties of pepper" /><br />
Different species and varieties of pepper for a genus, e.g., pungency.
</p>

<p style="border-top:0px">Finally, the Solanaceae have afforded a unique
glimpse of the organization of resistance genes in plant genomes.  We have
shown that despite co-evolutionary forces in host/pathogen interactions,
disease resistance genes represent ancient lineages in plants and that
resistance pathways may be very highly conserved. We also have extensive
gene discovery and breeding activities that integrate classical and
molecular methods for generating and selecting desirable genetic
variability, primarily focused on the identification of new sources of
biotic and abiotic stress resistance from wild accessions and related
species in cucurbits, <em>Phaseolus</em> and pepper. The Public Seed Initiative is
an outreach activity based on an alliance of public sector researchers and
non-profit groups interested in improving the dissemination and utilization
of public plant varieties and crop genetic diversity.</p>

<p>Pungency in pepper pods is a consequence of accumulation of the alkaloid
capsaicin (shown below) and its analogs. The biosynthesis of capsaicin is
restricted to the genus <em>Capsicum</em> and results from the acylation of an
aromatic moiety, vanillylamine, by a branched chain fatty acid. Apart from
portions of the biosynthetic pathway common to other primary metabolic
pathways, the remainder of the pathway remains unknown. One of the major
projects within our group focuses on capsaicin biosynthesis and the genes
that define and regulate the pathway.</p>

<p class="footnote" style="float:right; width:440px; text-align:center;"><img src="/static_content/community/feature/200510-3.gif" border="0" width="398" height="103" alt="Molecular structure of capsaicin" /><br />
Molecular structure of capsaicin
</p>

<p>Due to the popularity and familiarity of products containing capsaicin
there is rapidly growing economic significance in a wide array of food
products, in medicine, industry, law enforcement, and pest control (it has
become a leading insect protectant in organic agriculture and is the active
ingredient in many of the most effective deer and rodent repellents). Considering the importance of this pathway, it
is surprising that relatively little is known, particularly at the
molecular level, concerning the molecular genetics, biosynthesis,
subcellular localization and cellular structures required for pungency
accumulation in peppers. The recent cloning and initial characterization of
<em>Pun 1</em> (formerly known as <em>C</em>) allows for new insight into capsaicin
biosynthesis and accumulation. <em>pun 1</em> was first reported nearly 100 years
ago and was shown to be epistatic to all other pungency-related genes
(Webber, 1911). At present, the <em>pun1</em> allele is the only confirmed mutation
that has a qualitative affect on the presence/absence of capsaicinoids
(Blum et al., 2002 and references therein).  Further characterization of
<em>Pun 1</em>, as well as other candidates implicated in pungency is currently
underway.</p>

<p>Another area of research in our lab is potyvirus resistance.  Mutations
in the eIF4E homolog, encoded at the <em>pvr1</em> locus, result in broad-spectrum
potyvirus resistance conferred by <em>pvr1</em> resistance allele in Capsicum, a
gene widely deployed in agriculture. Point mutations in recessive
resistance genes, <em>pvr1</em>, <em>pvr1<sup>1</sup></em> and <em>pvr1<sup>2</sup></em>, grouped to similar regions of the
<em>eIF4E</em> gene and were predicted by protein homology models to cause
conformational shifts in the encoded proteins. While the protein encoded by
<em>pvr1<sup>+</sup></em> interacts strongly, proteins translated from all three resistance
alleles (<em>pvr1</em>, <em>pvr1<sup>1</sup></em> and <em>pvr1<sup>2</sup></em>) failed to bind VPg from either strain of
TEV in a yeast two hybrid assay.  This failure to bind correlates with
resistance, suggesting that interruption of the interaction between VPg and
this eIF4E paralog may be necessary, but is not sufficient for potyvirus
resistance <em>in vivo</em>.  Among the three resistance alleles, only the <em>pvr1</em>
gene product fails to bind m<sup>7</sup>-GTP cap-analog columns, suggesting that
disrupted cap-binding is not required for potyvirus resistance.</p>

<p class="footnote" style="float:left; width:350px; text-align:center;">
<img src="/static_content/community/feature/200510-5.gif" border="4" style="border-color: #000000" width="281" height="215" alt="Pepper infected with Tobacco Etch Virus" />
<br />
Uninfected pepper plant
</p>

<p class="footnote" style="float:right; width:350px; text-align:center;">
<img src="/static_content/community/feature/200510-4.gif" border="4" style="border-color: #000000" width="280" height="215" alt="Uninfected pepper plant" />
<br />
Pepper infected with Tobacco Etch Virus
</p>

<br clear="all" />

<div style="float:left; width:250; text-align:left;">
<h2>Contact Information</h2>
<p>
Molly Jahn<br />
Professor<br />
313 Bradfield Hall<br />
Plant Breeding and Genetics<br />
Cornell University<br />
Ithaca, NY 14853<br />
<a href="mailto:mmj9\@cornell.edu">mmj9\@cornell.edu</a><br />
607.255.8147<br />
607.255.6683 (fax)<br />
</p>
</div>

<p class="footnote" style="float:right; width:400px; text-align:center;"><img src="/static_content/community/feature/200510-6.gif" border="0" width="179" height="164" alt="Swirly image" /><br />
</p><br clear="all" />

<h2>Selected Publications</h2>

<p class="bibliography">
Kang, B.-C., I.H. Yeam, J.D. Frantz, and M.M. Jahn.  2005. Mutations in
    translation initiation factor eIF4E that confer resistance to potyvirus
    infection abolish interaction with Tobacco etch virus VPg in a non-
    specific manner.  Plant J. 42:392-405.
</p>

<p class="bibliography">
Stewart, C. Jr., B.-C. Kang, K. Liu, M. Mazourek, S. Moore, M.M. and Jahn.
    2005. The Pun1 gene for pungency in pepper encodes a putative
    acyltransferase. Plant J. 42:675-688.
</p>

<p class="bibliography">
Liu, K., B.-C. Kang, H. Jiang, C.B. Watkins, T.L. Setter and M.M. Jahn.
    2005. Identification and characterization of an auxin-responsive GH3-
    like gene in pepper fruit development. (accepted Plant Mol. Biol.).
</p>

<p class="bibliography">
E. A. Quirin, E. Ogundiwin, J.P. Prince, M. Mazourek, M. O. Briggs, T. S.
    Chlanda, K.T. Kim,  M. Falise, B.-C. Kang, and M.M. Jahn. 2005.
    Development of sequence characterized amplified region (SCAR) primers
    for the detection of Phyto.5.2, a major QTL for resistance to
    Phtophthora capsici Leon. in pepper .Theor. Appl. Genet. 110(4):605-12.
</p>

<p class="bibliography">
Kang, B.-C., and I. H. Yeam, and M.M. Jahn. 2005. Virus resistance genes.
      Ann.  Rev. of Phytopath. E. pub. May 2. 43:581-621.
</p>

<p class="bibliography">
Porch, T.G., M.H. Dickson, M. Long, D.R. Viands, and M.M. Jahn. 2005.
    General combining ability effects for reproductive heat tolerance in
    snap bean. J. Agriculture U. Puerto Rico 88(3-4):x-x.
</p>

<p class="bibliography">
Qian C.T., M.M. Jahn, J.E. Staub, X.-D. Luo and J.F. Chen. 2005.  Meiotic
chromosome
      behavior in an allotriploid derived from an amphidiploid x diploid
    mating in Cucumis. accepted Plant Breeding
</p>

<p class="bibliography">
Henning, M.J, H.M. Munger and M.M. Jahn.  2005.  'Hannah's Choice F1' : A
    new muskmelon hybrid with resistance to powdery mildew, Fusarium race 2
    and potyviruses. HortScience in press.
</p>

<p class="bibliography">
Henning, M.J, H.M. Munger and M.M. Jahn.  2005. 'PMR Delicious 51':  An
    improved open-pollinated melon with resistance to powdery mildew.
    HortScience 40(1):261-262.
</p>

<p class="bibliography">
Paran, I., J. Rouppe van der Voort, V. Lefebvre, M.M. Jahn, L. Landry, R.
    van Wijk, H. Verbakel, B. Tanyolac, C. Caranta, A. Ben Chaim, K.D.
    Livingstone, A. Palloix and J. Peleman.  2004. An integrated genetic
    map of pepper. Molecular Breeding 13:251-261.
</p>

<p class="bibliography">
Chen, J., X. Luo, C. Qian, M.M. Jahn, J.E. Staub, F. Zhuang, Q. Lou and G.
    Ren.  2004. Cucumis monosomic alien addition lines:  morphological,
    cytological and RAPD analysis.  TAG 108:1343-1348.
</p>

<p class="bibliography">
Alba, R., Z. Fei, P. Payton, Y. Liu, S.L. Moore, P. Debbie, J.S. Gordon,
     J.K.C. Rose, G. Martin, S.D. Tanksley, M. Bouzayen, M.M. Jahn and J.
     Giovannoni.  2004.  ESTs, cDNA microarrays and gene expression
     profiling:  tools for dissecting plant physiology and development.
     Plant J. 39:697-714
</p>

<p class="bibliography">
Rose, J.K.C., S. Bashir, JJ Giovannoni, MM Jahn and R.S. Saravanan.  2004.
    Tackling the plant proteome:  practical approaches, hurdles and
    experimental tools.  Plant J 39:715-733.
</p>

<p class="bibliography">
Nelson, R.J., R. Naylor and M.M. Jahn.  2004. The role of genomics research
    in the improvement of orphan crops. Crop Science 44:1901-1904.
</p>

END_HEREDOC
$page->footer();
