use strict;
use CXGN::Page;
my $page=CXGN::Page->new('200409.html','html2pl converter');
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
$page->header('The Seymour Lab', undef, $stylesheet);
print<<END_HEREDOC;

  <center>
    <h1>The Seymour Lab</h1>
  </center>

  <p class="footnote" style="text-align:center"><img src=
  "/static_content/community/feature/200409-1.jpg" border="0" width="570" height="300" alt=
  "The Seymour Lab" /><br />
  Kavita Kulkarni, Mervin Poole, Ken Manning, Graham B. Seymour,
  Alex Popovich and Peter G. Walley</p>

  <p>Fleshy fruits are economically highly valuable and provide a
  substantial part of the daily intake of vitamins and minerals
  whether they are consumed in a fresh or processed condition.
  There is evidence emerging that the genes that regulate ripening
  in fruits have been conserved during evolution. In our laboratory
  the aim is to isolate key members of this class of regulatory
  genes and investigate their role in ripening. There are three
  strands to our work in this area:</p>

  <p>One approach is to clone the wild type allele of the gene
  responsible for the Colourless non-ripening (Cnr ) mutation of
  tomato. In tomato a small number of single gene mutations exist,
  such as rin, nor and Cnr which have pleiotropic effects resulting
  in the reduction or almost complete abolition of ripening. These
  probably represent lesions in ripening-regulatory genes. For
  instance Cnr results in a non-ripening phenotype with two
  distinct characteristics: (1) firm fruit with reduced
  cell-to-cell adhesion and (2) complete abolition of carotenoid
  biosynthesis in the pericarp (see Thompson et al. Plant
  Physiology 120: 383-389, 1999: Orfila et al. Plant Physiology,
  126: 210-221, 2001). We have used a genetic map-based approach to
  isolate a candidate for the gene at the Cnr locus (T&ouml;r et
  al, 104: 165-170; 2002; Manning et al, manuscript in preparation)
  and want to understand its role in juiciness and colour
  development.</p>

  <p>In collaboration with Jim Giovannoni at Cornell we are
  investigating whether strawberry orthologues of the tomato genes
  RIN and NOR can modulate ripening in this non-climacteric fruit.
  Mutant alleles of these genes have previously been used in
  conventional breeding to enhance texture and shelf- life in
  commercial tomato.</p>

  <p>We are utilizing information from an advanced genetic
  framework in the dry fruited Arabidopsis to unravel the control
  of cell separation and softening in fleshy fruits. One of the
  tomato genes, TDR4, is a likely orthologue of the Arabidopsis
  gene FRUITFULL. In Arabidopsis this MADS-box gene is involved in
  the control of valve cell differentiation (the cells
  corresponding to the tomato pericarp). In ful mutants, valve
  cells adopt the fate of dehiscence zone cells, which are normally
  programmed to undergo cell separation when the fruit matures.
  (Ferr&aacute;ndiz, Liljegren and Yanofsky, 2000. Science 289,
  436-438). We are testing whether TDR4 can substitute for
  FRUITFULL in Arabidopsis and investigating its role in tomato
  fruit ripening.</p>

  <p>Other projects on-going in the lab include the identification
  and resolution of QTL for mechanical properties in tomato fruits
  and isolation of novel mutants affecting fruit quality.</p>

  <p>Additionally GBS is spearheading, in collaboration with Gerard
  Bishop at Imperial College and Glenn Bryan at Scottish Crop
  Research Institute, the UK Solanaceae Research Community
  contribution to the International effort to sequence the tomato
  genome.</p>

  <p class="footnote"><img src="/static_content/community/feature/200409-2.jpg" border="0" width=
  "645" height="445" alt="Fleshy fruits" /><br />
  <b>Redrawn and modified from The Evolution of Plants and Flowers,
  B. Thomas, Eurobook Ltd, Wallingford, UK</b></p>

  <p>Fleshy fruits are likely to have evolved from dry forms. Have
  genes controlling cell separation in ripening fruits been
  conserved during evolution.</p>

  <p class="footnote"><img src="/static_content/community/feature/200409-3.jpg" border="0" width=
  "698" height="562" alt="Colourless non-ripening" /><br />
  <b>Colourless non-ripening (Cnr)</b></p>

  <p>Cnr fruits show a non-ripening phenotype with significant loss
  of cell adhesion in the pericarp</p>

  <h2>Contact Information</h2>

  <p>Dr Graham B. Seymour<br />
  Warwick HRI<br />
  University of Warwick, Wellesbourne, Warwick CV35 9EF, UK.<br />
  Tel: 44 24 7657 4455<br />
  Fax 24 7657 4500<br />
  <a href=
  "mailto:graham.seymour\@warwick.ac.uk">graham.seymour\@warwick.ac.uk</a></p>

  <h2>Selected Recent Publications</h2>

  <p class="bibliography">Eriksson, E.M., Bovy, A., Manning, K.,
  Harrison, L., Andrews, J., De Silva, J., Tucker, G.A. and
  Seymour, G.B. (2004). Effects of the Colourless non-ripening
  (Cnr) mutation on gene expression and cell wall biochemistry
  during tomato fruit development and ripening. Plant Physiology
  (submitted for publication).</p>

  <p class="bibliography">Marin, C., Smith, D., Manning, K.,
  Orchard, J. and Seymour, G.B. (2003). Pectate lyase gene
  expression and enzyme activity in ripening banana fruit. Plant
  Molecular Biology 51, 851-857.</p>

  <p class="bibliography">Tor, M., Manning, K., King, G.J.,
  Thompson, A.J., Jones, G.H., Seymour, G.B. and Armstrong, S. J.
  (2002). Genetic analysis and FISH mapping of the Colourless
  non-ripening locus of tomato. Theoretical and Applied Genetics
  40, 165-170.</p>

  <p class="bibliography">Fraser, P.D., Bramley, P. and Seymour,
  G.B. (2001). Effect of the Cnr mutation on carotenoid formation
  during tomato fruit ripening. Phytochemistry 58, 75-79.</p>

  <p class="bibliography">King, G.J., Lynn, J.R., Dover, C.J.,
  Evans, K.M. and Seymour, G.B. (2001). Resolution of quantitative
  trait loci for mechanical measures accounting for genetic
  variation in fruit texture of apple (Malus pumila Mill).
  Theoretical and Applied Genetics 102, 1227-1235.</p>

  <p class="bibliography">Orfila, C., Seymour, G.B., Willats,
  W.G.T., Huxham, I.M., Jarvis, M.C., Dover, C.J., Thompson, A.J.
  and Knox, J.P. (2001). Altered middle lamella homogalacturonan
  and disrupted deposition of (1-5)-(-L- arabinan in the pericarp
  of Cnr, a ripening mutant of tomato. Plant Physiology 126,
  210-221.</p>

  <p class="bibliography">Drury, R., Hortensteiner, S., Donnison,
  I., Bird, C.R. and Seymour, G.B. (1999). Gene expression and
  chlorophyll catabolism in the peel of ripening banana fruits.
  Physiologia Plantarum 107, 32-38.</p>

  <p class="bibliography">Huxham, I.M., Jarvis, M.C., Shakespeare,
  L., Dover, C.J., Juhnson,D., Knox, J.P. and Seymour, G.B. (1999).
  Electron energy loss spectroscopic imaging of calcium and
  nitrogen in the cell walls of apple fruits. Planta 208,
  438-443.</p>

  <p class="bibliography">Thompson, A.J., Tor, M., Barry, C.S.,
  Vrebalov, J., Orfila, C., Jarvis, M.C., GiovannoniI, J.J.,
  Grierson, D. and Seymour, G.B. (1999). Molecular and genetic
  characterisation of a novel pleiotropic tomato ripening mutant.
  Plant Physiology 120, 383-389.</p>
END_HEREDOC
$page->footer();
