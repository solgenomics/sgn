use strict;
use CXGN::Page;
my $page=CXGN::Page->new('200601','Teri Solow');

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
		text-align:center;
		padding: 0px;
		margin: 5px 10px 5px 10px;
	}

	.bibliography {
		text-indent: -20px;
	}
-->
</style>
END_STYLESHEET

$page->header('The Petunia Lab at Radboud University, Nijmegen', undef, $stylesheet);
print<<END_HEREDOC;

<center>
<h1>The Petunia Lab at Radboud University, Nijmegen</h1>
</center>

<p class="footnote"><img src="/static_content/community/feature/200601-1.jpg" border="4" style="border-color: #0000FF" width="800" height="555" alt="The Petunia Lab" /><br />
</p>

<p class="footnote" style="float:right; width:258px; text-align:center; border: 1px solid #000000;"><img src="/static_content/community/feature/200601-2.gif" width="258" height="243" alt="Commercial Petunia line with double mutation." /><br />
Commercial Petunia line with "double" mutation.
</p>

<p style="border-bottom: 0px">
For the nearly four  years  that  we  now  have  been  in  Nijmegen,  The
Netherlands, we  have  primarily  focused  on  two  themes  in  our  Petunia
research: meiosis-related research and MADS-box genes. We  started  on  both
topics when working in Ghent, Belgium in what was originally Prof  Marc  van
Montagu\'s lab. Our group is small; each core subject is carried by a PI  (Dr
Janny Peters and Dr Michiel Vandenbussche respectively) and one or  two  PhD
students (Veena Hedatale with Janny;  Stefan  Royaert  and  Anneke  Rijpkema
with Michiel) and supported by our fabulous technician,  Jan  Zethof,  while
two to five undergraduate students join  the  group  for  short  periods  of
time. We are proud to have visiting scientists  on  sabbatical  leave:  Prof
Dave Clark from Gainesville, Florida
stayed with us for seven months in 2004 and presently Dr Tony  Conner,  from  
the Crop &amp; Food Research/Lincoln University, Christchurch,  New  Zealand  is
with us for a year.
</p>

<p style="border-bottom: 0px">
A large part of our research is funded by the  Institute  for  Water  and
Wetland Research (IWWR). The IWWR aims to boost  its  competitive  force  by
stimulating interdisciplinary co-operation  between  those  engaged  in  the
scientific fields of microbiology,  ecology  and  plant-  and  environmental
sciences (see <a href="http://www.iwwr.science.ru.nl/">http://www.iwwr.science.ru.nl/</a>). Further funding  is  obtained
from various national and  international  agencies.  As  one  of  the 'old'
petunia labs we are part of  the  growing  Petunia  community  and  as  such
promote  the  use  of  this  nice  model  system  wherever  we   can   (see:
<a href="http://www.pg.science.ru.nl/">http://www.pg.science.ru.nl/</a> and <a href="http://www.petuniaplatform.net/">http://www.petuniaplatform.net/</a>  ).  We  do
touch upon other organisms, like Arabidopsis if and when useful. One of  the
activities we are  undertaking  in  compliance  with  the  IWWR  integrative
research strategy is to initiate in-situ studies in
Southern America to research upon the activity of (endogenous)  transposable
elements in natural Petunia axillaris accessions; a  second  activity  under
development is a study on the molecular genetics and ecology of  the  clonal
propagation capacity of  Petunia  altiplana,  seeds  of  which  were  kindly
provided by Prof. Toshio Ando of Chiba University, Japan.
</p>

<p class="footnote" style="float:left; width:227px; text-align:center; border: 1px solid #000000;"><img src="/static_content/community/feature/200601-3.gif" width="227" height="221" alt="Transposon line W138" /><br />
Transposon line W138
</p>

<p style="border-bottom: 0px">
Now then, to describe in a few words our core research, I need  to  go  a
bit into Petunia as a system to work with; for details  I  refer  to  Gerats
and Vandenbussche (2005), for now it suffices to state that Petunia  has  an
easy  and  fast  growth  cycle,  donates  prolific  material,  is  easy   to
transform, but  maybe  is  most  outstanding  in  its  transposable  element
system, for which efficient forward and reverse strategies have been  worked
out.
</p>

<p style="border-bottom: 0px">
MADS box research in Petunia  is  flourishing;  in  fact  the  D-  and  E
functions were added to the classical ABC model,  based  on  Petunia  mutant
analysis (the work of Gerco  Angenents  group).  Meanwhile  we  are  finally
making progress in  re-defining  the  A-function.  One  of  the  outstanding
results of our group has been the development of the
frameshift theory that states that 3\' frameshift  mutations  may  contribute
structurally to the evolution of protein functions  (Vandenbussche  et  al.,
2003a). Presently we are finalizing the analysis of the  B  function  genes.
While Antirrhinum and Arabidopsis both have only one Glo/Pi and one  Def/Ap3
gene, Petunia has two representatives  of  each  lineage.  A  nice  case  of
subfunctionalization  and  divergence.  We  are  working  on  a   systematic
analysis of B function gene development within  the  Solanaceae  (thanks  to
the marvellous Nijmegen collection we  can  sample  a  great  range  of  SOL
species: <a href="http://www.bgard.science.ru.nl/">http://www.bgard.science.ru.nl/</a>).
</p>

<p style="border-bottom: 0px">
Finally, on the meiosis-related research, we  have  performed  a  partial
cDNA-AFLP transcript analysis on developing Petunia  Mitchell  anthers  from
single flower buds that  have  been  staged  cytologically.  Among  the  480
meiosis-modulated gene  fragments  identified  in  this  screen,  there  are
around 65 that have a peak in expression in the  early  stages  of  meiosis,
when the process of homologous recombination takes  place.  And  that\'s  the
process in which we are most interested. Together with Prof  Hans  de  Jong,
Wageningen, we are analyzing SALK line insertants in genes, homologous to  a  
number of the identified petunia genes. We have also joined forces  on  this
subject with Keygene, the company that invented the AFLP procedures.
</p>

<br clear="all" />

<div style="float:left; width:250; height: 240px; margin-left: 100px; vertial-align: middle; padding-top: 50px; text-align:left;">
<h2>Contact Information</h2>
<p>
Dr. Tom Gerats<br />
Radboud University, Nijmegen<br />
The Netherlands<br />
E-mail: <a href="mailto:T.Gerats\@science.ru.n">T.Gerats\@science.ru.nl</a>
</p>
</div>

<p class="footnote" style="float:right; width:220px; margin-right: 100px; border: 1px solid #000000; text-align:center;"><img src="/static_content/community/feature/200601-4.gif" border="0" width="220" height="207" alt="Seppallata mutant" /><br />
Seppallata mutant
</p><br clear="all" />

<h2>Recent Publications</h2>

<p class="bibliography">
Petunia Ap2-like genes and their role in flower and seed development (2001). Maes T, Van de Steene N, Zethof J, Karimi M, D'Hauw M, Mares G, Van Montagu M, Gerats T. The Plant Cell 13 (2): 229-244 
</p>

<p class="bibliography">
Analysis by Transposon Display of the behavior of the dTph1 element family during ontogeny and inbreeding of Petunia hybrida (2001). De Keukeleire P, Maes T, Sauer M, Zethof J, Van Montagu M, Gerats T. Mol Gen and Gen 265 (1): 72-81 
</p>

<p class="bibliography">
A physical amplified fragment-length polymorphism map of Arabidopsis (2001).
Peters JL, Constandt H, Neyt P, Cnops G, Zethof J, Zabeau M, Gerats T Plant Phys 127 (4): 1579-1589
</p>

<p class="bibliography">
AFLP maps of Petunia hybrida: building maps when markers cluster (2002).
Strommer J, Peters J, Zethof J, de Keukeleire P, Gerats T. Theor and Appl Gen 105 (6-7): 1000-1009 
</p>

<p class="bibliography">
Transcript profiling on developing Petunia hybrida floral organs (2003). Cnudde F, Moretti C, Porceddu A, Pezzotti M, Gerats T. Sex Plant Rep 16 (2): 77-85 
</p>

<p class="bibliography">
Structural diversification and neo-functionalization during floral MADS-box gene evolution by C-terminal frameshift mutations (2003a). Vandenbussche M, Theissen G, Van de Peer Y, Gerats T. Nucl Acids Res 31 (15): 4401-4409 
</p>

<p class="bibliography">
In silico identification of putative regulatory sequence elements in the 5 '-untranslated region of genes that are expressed during male gametogenesis (2003).
Hulzink RJM, Weerdesteyn H, Croes AF, Gerats T, van Herpen MMA, van Helden J
Plant Phys 132 (1): 75-83 
</p>

<p class="bibliography">
Forward genetics and map-based cloning approaches (2003). Peters JL, Cnudde F, Gerats T. Trends in Plant Sci 8 (10): 484-491 
</p>

<p class="bibliography">
Toward the analysis of the petunia MADS box gene family by reverse and forward transposon insertion mutagenesis approaches: B, C, and D floral organ identity functions require SEPALLATA-like MADS box genes in petunia (2003).
Vandenbussche M, Zethof J, Souer E, Koes R, Tornielli GB, Pezzotti M, Ferrario S, Angenent GC, Gerats T. The Plant Cell 15 (11): 2680-2693 
</p>

<p class="bibliography">
An AFLP-based genome-wide mapping strategy (2004). Peters JL, Cnops G, Neyt P, Zethof J, Cornelis K, Van Lijsebettens M, Gerats T. Theor and Appl Gen 108 (2): 321-327 
</p>

<p class="bibliography">
A PCR-based assay to detect hAT-like transposon sequences in plants (2004). De Keukeleire P, De Schepper S, Gielis J, Gerats T. Chrom Res 12 (2): 117-123 2004
</p>

<p class="bibliography">
The Rg-1 encoded regeneration capacity of tomato is not related to an altered cytokinin homeostasis (2004). Boiten H, Azmi A, Dillen W, De Schepper S, Debergh P, Gerats T, Van Onckelen H, Prinsen E New Phyt 161 (3): 761-771 
</p>

<p class="bibliography">
The duplicated B-class heterodimer model: Whorl-specific effects and complex genetic interactions in Petunia hybrida flower development (2004). Vandenbussche M, Zethof J, Royaert S, Weterings K, Gerats T. The Plant Cell 16 (3): 741-754 
</p>

<p class="bibliography">
Ectopic expression of the petunia MADS box gene UNSHAVEN accelerates flowering and confers leaf-like characteristics to floral organs in a dominant-negative manner (2004). Ferrario S, Busscher J, Franken J, Gerats T, Vandenbussche M, Angenent GC, Immink RGH The Plant Cell 16 (6): 1490-1505 
</p>

<p class="bibliography">
The rotunda2 mutants identify a role for the LEUNIG gene in vegetative leaf morphogenesis (2004). Cnops G, Jover-Gil S, Peters JL, Neyt P, De Block S, Robles P, Ponce MR, Gerats T, Van Lijsebettens M Journ of Exp Bot 55 (402): 1529-1539 
</p>

<p class="bibliography">
STIG1 controls exudate secretion in the pistil of petunia and tobacco (2005).  Verhoeven T et al. Plant Phys 138 (1): 153-160 
</p>

<p class="bibliography">
A model system for comparative research: Petunia (2005). Gerats T, Vandenbussche M Trends in Plant Sci 10 (5): 251-256 
</p>

<p class="bibliography">
Meiosis: Inducing variation by reduction (2005). Cnudde F, Gerats T Plant Biology 7 (4): 321-341 Quantitative Trait Locus (QTL) Isogenic Recombinant Analysis: a method for high-resolution mapping of QTL within a single population (2005). Peleman JD, Wye C, Zethof J, Sørensen AP, Verbakel H, Van Oeveren J, Gerats T, Rouppe van der Voort J. Genetics, 171: 1341-1352.
</p>

END_HEREDOC
$page->footer();
