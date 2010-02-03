use strict;
use CXGN::Page;
my $page=CXGN::Page->new('200504.html','html2pl converter');
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

$page->header('Taylor Lab', undef, $stylesheet);
print<<END_HEREDOC;

  <center>
    <h1>Taylor Lab</h1>
  </center>

  <p class="footnote"><img src="/static_content/community/feature/200504-1.jpg" border="0" width=
  "800" height="600" alt="Taylor Lab Lab" /><br />
  <strong>From left to right:</strong> Mark Taylor, Laurence
  Ducreux, Wayne Morris</p>

  <p class="footnote" style=
  "float:right; width:375; text-align:center;"><img src=
  "/static_content/community/feature/200504-2.jpg" border="0" width="350" height="271" alt=
  "Ev-4, Crt B-9" /><br />
  <strong>Figure 1:</strong> Over-expression of a bacterial
  phytoene synthase gene (<em>CrtB</em>) increases the tuber
  carotenoid content and radically changes the types of carotenoid
  that accumulate in tubers (right) compared with controls
  (left).</p>

  <p>The Taylor lab is part of the Scottish Crop Research
  Institute.</p>

  <p>Over the past 16 years we have studied many aspects of potato
  tuber development and tuber quality traits. We have a particular
  interest in the control of the potato tuber life-cycle,
  addressing issues such as tuber initiation, tuber size
  distribution and control of tuber dormancy.</p>

  <p>In recent years we have focused on isoprenoid metabolism in
  potato. Isoprenoids are a large group of metabolites that impact
  directly on nutritional quality (for example carotenoid content)
  and also on plant growth and development (for example
  gibberellins, cytokinins). Understanding the regulation of this
  metabolic network remains a major challenge. Using a transgenic
  approach we have perturbed isoprenoid metabolism in potato tubers
  and obtained several phenotypes of interest &acirc;&euro;&ldquo;
  such as enhanced tuber beta-carotene content (Figure
  1).</p><br clear="all" />

  <p class="footnote" style=
  "float:right; width:375; text-align:center;"><img src=
  "/static_content/community/feature/200504-3.jpg" border="0" width="350" height="274" alt=
  "Over expression of a bacterial DXS gene" /><br />
  <strong>Figure 2:</strong> Over-expression of a bacterial DXS
  gene results in an early sprouting phenotype (right) compared
  with empty vector controls (left).</p>

  <p>Using profiling methodologies in combination with the
  transgenics we hope to learn how the isoprenoid metabolic
  pathways are regulated. In other transgenics we over-expressed a
  bacterial gene encoding 1-deoxy-D-xylulose 5
  &acirc;&euro;&ldquo;phosphate synthase. Although there was only a
  small impact on tuber carotenoid profile, major changes occurred
  in the tuber life-cycle, providing us with clues as to how
  dormancy and sprouting is controlled (Figure 2).</p>

  <p>Although we are a small group, we interact with many
  colleagues at SCRI. We are interested in using VIGS in potato
  tubers to rapidly assess gene function and work with Dr
  Christophe Lacomme&acirc;&euro;&trade;s group in this area. Dr
  Steve Millam provides expertise in potato transformation and
  tissue culture and Dr Pete Hedley collaborates with microarray
  experiments. We are increasingly adopting a genetic approach to
  dissecting potato quality traits and work closely with Drs Gavin
  Ramsay and Glenn Bryan in these areas, benefiting also from the
  Commonwealth Potato Collection at SCRI.</p>

  <p>In the future we shall direct our attention to looking at
  traits of interest to the potato industry such as flavour and
  texture. We shall work closely with colleagues in the Quality,
  Health and Nutrition programme who are developing metabolomic
  approaches, an effort lead by Professor Howard Davies and Dr
  Derek Stewart. The development of genetic, genomic and
  metabolomic resources for potato makes this a very exciting time
  for potato research, with real prospects for finding solutions to
  age-old problems.</p>

  <h2>Contact Information</h2>

  <p>Dr. Mark Taylor<br />
  Quality, Health, Nutrition,<br />
  Scottish Crop Research Institute,<br />
  Invergowrie,<br />
  Dundee,<br />
  DD2 5DA,<br />
  UK.<br />
  Email: <a href=
  "mailto:M.Taylor\@scri.sari.ac.uk">M.Taylor\@scri.sari.ac.uk</a><br />

  Tel: +44 1382 562731<br />
  Website: <a href=
  "http://www.scri.sari.ac.uk/">http://www.scri.sari.ac.uk/</a></p><br clear="all" />


  <h2>Selected Publications</h2>

  <p class="bibliography">Taylor MA, Ramsay G (2005) Carotenoid
  biosynthesis in plant storage organs: recent advances and
  prospects for improving plant food quality. Physiol Plant in
  press</p>

  <p class="bibliography">Ducreux LJ, Morris WL, Hedley PE,
  Shepherd T, Davies HV, Millam S, Taylor MA (2005). Metabolic
  engineering of high carotenoid potato tubers containing enhanced
  levels of {beta}-carotene and lutein. J Exp Bot
  56(409):81-89.</p>

  <p class="bibliography">Ducreux LJ, Morris WL, Taylor MA, Millam
  S (2005). <em>Agrobacterium</em>-mediated transformation of
  <em>Solanum phureja</em>. Plant Cell Reports
  DOI:&Acirc;&nbsp;10.1007/s00299-004-0902-z</p>

  <p class="bibliography">Witte CP, Tiller S, Isidore E, Davies HV,
  Taylor MA (2005) Analysis of two alleles of the urease gene from
  potato: polymorphisms, expression and extensive alternative
  splicing of the corresponding mRNA. J Exp Bot 56:91-99</p>

  <p class="bibliography">Faivre-Rampant O, Gilroy E, Hrubikova K,
  Hein I, Millam S, Loake G, Birch PRJ, Taylor MA, Lacomme C (2004)
  Potato virus X-induced gene silencing in leaves and tubers of
  potato. Plant Physiology 134, 1308-1316</p>

  <p class="bibliography">Morris WL, Ducreux L, Griffiths DW,
  Stewart D, Davies HV, Taylor MA (2004) Carotenogenesis during
  tuber development and storage in potato. J Exp Bot 55,
  975-982</p>

  <p class="bibliography">Faivre-Rampant O, Cardle L, Marshall D,
  Viola R, Taylor MA (2004) Changes in gene expression during
  meristem activation processes in <em>Solanum tuberosum</em> with
  a focus on the regulation of an auxin response factor gene. J Exp
  Bot 55, 613-622</p>

  <p class="bibliography">Faivre-Rampant O, Bryan GJ, Roberts AG,
  Milbourne D, Viola R, Taylor MA (2004) Regulated expression of a
  novel TCP domain transcription factor indicates an involvement in
  the control of meristem activation processes in <em>Solanum
  tuberosum</em> J. Exp Bot 55, 951-953</p>

  <p class="bibliography">Witte C-P, Tiller SA, Taylor MA and
  Davies HV (2002) Leaf urea metabolism in potato: Urease activity
  profile and patterns of recovery and distribution of
  <sup>15</sup>N after foliar urea application in wild-type and
  urease-antisense transgenics. Plant Physiol 128, 1129-1136</p>

  <p class="bibliography">Taylor MA, Ross HA, McRae D, Wright F,
  Viola R and Davies HV (2001) cDNA cloning and characterisation of
  a potato &alpha; glucosidase:expression in <em>E.coli</em> and
  effects of down-regulation in transgenic potato. Planta 213,
  258-264</p>

  <p class="bibliography">Witte CP, Isidore E, Tiller SA, Davies
  HV, Taylor MA (2001) Functional characterisation of urease
  accessory protein G (ureG) from potato. Plant Molecular Biology
  45, 169-179</p>

  <p class="bibliography">Taylor MA, Ross HA, McRae D, Stewart
  D,Roberts I, Duncan G, Wright F, Millam S and Davies HV (2000) A
  potato &alpha; glucosidase gene encodes a glycoprotein processing
  &alpha;-glucosidase II-like activity. Demonstration of enzyme
  activity and effects of down-regulation in transgenic plants.
  Plant Journal 24, 305-316</p>

  <p class="bibliography">Davies PJ, Simko I, Mueller SM, Yencho
  GC, Lewis C, McMurry S, Taylor MA and Ewing EE (1999)
  Quantitative trait loci for polyamine content in an RFLP-mapped
  potato population and their relationship to tuberisation. Physiol
  Plant 106, 210-218</p>

  <p class="bibliography">Rafart Pedros A, MacLeod MR, Ross HA,
  McRae D, Tiburcio AF, Davies HV and Taylor MA (1999) Manipulation
  of the S-adenosylmethionine decarboxylase transcript level in
  potato tubers. Planta 209, 153-160</p>

  <p class="bibliography">Taylor MA, George LA, Ross HA and Davies
  HV (1998) cDNA cloning of a potato alpha-glucosidase gene and
  functional characterisation by complementation of a yeast mutant.
  Plant Journal 13, 419-425</p>

  <p class="bibliography">Kumar A, Taylor MA, Mad Arif SA and
  Davies HV (1996) Potato plants expressing antisense and sense
  S-adenosylmethionine decarboxylase (SAMDC) transgenes show
  altered levels of polyamines and ethylene. Plant Journal 9,
  147-158</p>

  <p class="bibliography">Taylor MA, Ross HA Gardner A and Davies
  HV (1995) Characterisation of the fructokinase gene from potato
  J.Plant Physiol.145, 253-257</p>

  <p class="bibliography">Mad Arif SA, Taylor MA, George LA, Butler
  AR, Burch LR, Davies HV, Stark MJR and Kumar A (1994)
  Characterisation of the S-adenosylmethionine decarboxylase gene
  of potato. Plant Mol. Biol. 26, 327-338</p>

  <p class="bibliography">Taylor MA, Mad Arif SA, Kumar A, Davies
  HV, Scobie LA, Pearce SR and Flavell AJ (1992) Expression and
  sequence analysis of cDNAs induced during the early stages of
  tuberisation in different organs of the potato plant (<em>Solanum
  tuberosum</em> L.). Plant Mol. Biol. 20, 641-651</p>
END_HEREDOC
$page->footer();
