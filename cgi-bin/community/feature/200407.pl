use strict;
use CXGN::Page;
my $page=CXGN::Page->new('200407.html','html2pl converter');
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

$page->header('The Kim Lab', undef, $stylesheet);
print<<END_HEREDOC;

  <center>
    <h1>The Kim lab</h1>

    <p class="footnote"><img src="/static_content/community/feature/200407-1.jpg" width="720" height=
    "540" border="0" alt="Members of the Kim lab" /> B. D. Kim Lab
    members in the middle yard of the new CALS building in Seoul
    campus (as of March 16, 2004, from left to right) Top line - D.
    H. Kim (PhD), C. H. Chang, H. J. Noh, W. K. Min, I. Lambein
    (PhD), J. H. Kim Middle line - S. Lee, M. S. Han, J. Y. Lee, B.
    D. Kim (PhD), H. J. Kim, E. Y. Yoo (PhD), O. R. Kim, H. J. Kim,
    J. H. Sung Bottom line - J. S. Shin, J. H. Han (PhD), W. H.
    Kang, H. R. Lee, J. M. Lee, S. I. Yeom, M. G. Park</p>
  </center>

  <h2>Research interests</h2>

  <p>The focus of research in our laboratory is molecular and
  genetic analysis of pepper (Capsicum spp.) for useful traits,
  especially pungency, disease resistance, fruit color, and male
  sterility. Experimental approaches for investigating pepper genes
  are 1) development of high-resolution genetic maps using RFLP,
  SSR and AFLP, 2) BAC library construction for physical mapping
  and map-based cloning, 3) QTL mapping of disease resistance, 4)
  comparative genomics in Solanaceae, 5) identification of genes
  related to pungency, fruit color, fruit quality, and disease
  resistance 6) generation of male sterile plants.</p>

  <p>Dr. Kim is a professor of Dept. Plant Science (<a href=
  "http://plaza.snu.ac.kr/~mglab/ko_frame.htm">http://plaza.snu.ac.kr/~mglab/ko_frame.htm</a>)
  and a director of Center for Plant Molecular Genetics and
  Breeding Research (CPMGBR) (<a href=
  "http://pmgb.snu.ac.kr/">http://pmgb.snu.ac.kr/</a>) at Seoul
  National University. CPMGBR was established in 1999 as one of the
  excellent science research centers designed and funded by the
  Ministry of Science and Technology (MOST) and the Korea Science
  and Engineering Foundation (KOSEF). The objective of the CPMGBR
  is to bridge the science of plant molecular genetics and the
  technology breeding with the goals of advancing science and
  developing new hot pepper plants with better quality and
  resistances to plant pathogens.</p>

  <h2>Selected Publications</h2>

  <p>Lee, J.M., Nahm, S.H., Kim, Y.M., and Kim, B.D. (2004)
  Characterization and molecular genetic mapping of microsatellite
  loci in pepper. Theor. Appl. Genet. 108: 619-627</p>

  <p>Yoo, E.Y., Kim, S., Kim, Y.H., Lee, C.J., and Kim, B.D. (2003)
  Construction of a deep coverage BAC library from Capsicum annuum,
  'CM334'. Theor. Appl. Genet. 107: 540-543</p>

  <p>Huh, J.H., Kang, B.C., Nahm, S.H., Kim, S., Ha, K. S., Lee,
  M.H., and Kim, B.D. (2001) A candidate gene approach identified
  phytoene synthase as the locus for mature fruit color in red
  pepper (Capsicum spp.). Theor. Appl. Genet. 102: 524-530</p>

  <p>Kang, B.C., Nahm, S.H., Huh, J.H., Yoo, H.S., Yu, J.W., Lee,
  M.H., and Kim B.D. (2001) An Interspecific (Capsicum annuum x C.
  chinense) F2 Linkage Map in Pepper Using RFLP and AFLP Markers.
  Theor. Appl. Genet. 102: 531-539</p>

  <p>Kim, M., Kim, S., Kim, S., and Kim B.D. (2001) Isolation of
  cDNA clones differentially accumulated in the placenta of pungent
  pepper by suppression subtractive hybridization. Mol. Cells.
  11:213-219</p>

  <p>Lee, S.J., Suh, M.C., Kim, S., Kwon, J.K., Kim, M., Paek,
  K.H., Choi, D., and Kim, B.D. (2001) Molecular cloning of a novel
  pathogen-inducible cDNA encoding a putative acyl-CoA synthetase
  from Capsicum annuum L. Plant Mol Biol. 46: 661-671</p>

  <p>Cho, H.J., Kim, S., Kim, M., Kim, B.D. (2001) Production of
  transgenic male sterile tobacco plants with the cDNA encoding a
  ribosome inactivating protein in Dianthus sinensis L. Mol Cells.
  11:326-333</p>

  <h2>Contact</h2>

  <p>Byung-Dong KIM<br />
  Professor and Director<br />
  Center for Plant Molecular Genetics and Breeding Research<br />
  Seoul National University<br />
  San 56-1 Shinlim-dong, Gwanak-gu<br />
  Seoul 151-742, Korea<br />
  E-mail: <a href=
  "mailto:kimbd\@snu.ac.kr">kimbd\@snu.ac.kr</a><br />
  Phone: +82-2-880-4933, Fax: +82-2-873-5410<br /></p>
END_HEREDOC
$page->footer();
