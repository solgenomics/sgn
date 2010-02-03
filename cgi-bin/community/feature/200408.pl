use strict;
use CXGN::Page;
my $page=CXGN::Page->new('200408.html','html2pl converter');
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

$page->header('The Unit of Plant Biology', undef, $stylesheet);
print<<END_HEREDOC;

  <center>
    <h1>The Unit of Plant Biology - Louvain-la-Neuve</h1>
  </center>

  <h2>Research Focus</h2>

  <p>The research interests of the Unit of Plant Biology are
  focused on two main topics: i) investigating a key developmental
  change in plant life cycle, namely flowering (J.-M. Kinet), ii)
  understanding the physiological, genetic and biochemical basis of
  sensing and responding to environmental cues such as drought,
  cold, mineral toxicity and other abiotic signals by which plants
  interact with their surroundings (H. Batoko and S. Lutts). A
  comprehensive set of approaches are currently used including
  whole plant physiology (S. Lutts and J.M. Kinet), biochemistry
  (S. Lutts), histology (J.-M. Kinet), cell and molecular biology
  (H. Batoko). A variety of plant species are investigated
  (Arabidopsis thaliana, rice, xero-halophyte species belonging to
  the genus Atriplex, Fagopyrum esculentum, etc.), the choices
  being driven mostly by conceptual or specific hypotheses-based
  suitability.</p>

  <p>Tomato is among the main model-plants used in the laboratory.
  The main objectives of the ongoing researchs are:</p>

  <ol>
    <li><p>to study the salt tolerance mechanisms in Lycopersicon
    esculentum and its wild relatives (namely L. chesmanii and L.
    pennellii) in relation to the role of the SOS pathway in ion
    homeostasis (Fig. 1)</p>

<center>
        <img src="/static_content/community/feature/200408-1.png" border="0" width="435" height="275"
        alt="Figure 1" /><br />
        Figure 1. Zhu, J.-K., 2003<br />
        Curr.Op. Plant. Biol., 6, 441-445
</center>
    </li>

    <li><p>to characterize the impact of Cd in relation to oxidative
    stress and phytochelatine synthesis.</p></li>

    <li><p>to characterize genes involved in flowering. Up to now, the
    main focus was on uf mutant which initiates single flowers
    instead of multi- flowered inflorescences (Fig. 2). Ongoing
    work has already established that UNIFLORA is a pivotal gene
    that regulates floral transition and the identity of the
    inflorescential meristem in tomato. Other mutations that are
    concomitantly investigated include compound inflorescence,
    jointless, blind, single flower truss and self pruning.</p></li>
  </ol>

<center>
    <img src="/static_content/community/feature/200408-2.jpg" border="0" width="450" height="660"
    alt="solitary, normal and fertile flowers" /> <img src=
    "/static_content/community/feature/200408-3.jpg" border="0" width="414" height="660" alt=
    "SEM views" /><br />
    Figure 2. The reproductive structure of the uf tomato mutant.
    Left: solitary, normal and fertile flowers are consistently
    produced instead of inflorescences. Right: SEM views of a same
    uf-induced floral structure showing that the single-flower
    phenotype results from the inability of the plant to produce an
    inflorescence and not from post-initiation abortion processes
    affecting young flower buds. The isolated flower is seen with
    its 6 sepals (1 to 6) and was initiated after the formation of
    the 12th leaf (A). An axillary bud (AB) bearing three leaves
    (B,C, D) has been initiated at the basis of the flower (Dielen,
    et al., 1998. Plant Growth Regul., <strong>25</strong>,
    149-157).
</center>

  <h2>Some Publications</h2>

  <div style="margin-left: 40px">
    <p class="bibliography">Bajji, M., Kinet, J.M. and Lutts, S.
    1998. Salt stress effects on roots and leaves of Atriplex
    halimus L. and their corresponding callus cultures. Plant Sci.,
    137, 131-142.</p>

    <p class="bibliography">Lutts, S., Majerus, V. and Kinet, J.M.
    1999. NaCl effects on proline metabolism in rice (Oryza sativa
    ) seedlings. Physiol. Plant., 105, 450- 458.</p>

    <p class="bibliography">Batoko, H., Zheng, H.-Q., Hawes, C. and
    Moore, I. 2000. A Rab1 GTPase is required for transport between
    the endoplasmic reticulum and Golgi apparatus and for normal
    Golgi movement in plants. Plant Cell, 12, 2201-2217</p>

    <p class="bibliography">Dielen, V., Lecouvet, V., Dupont, S.
    and Kinet, J.M. 2001. In vitro control of floral transition in
    tomato (Lycopersicon esculentum Mill.), the model for
    autonomously flowering plants, using the late flowering
    uniflora mutant. J. Exp. Bot., 52, 715-723.</p>

    <p class="bibliography">Geelen, D., Leyman, B., Batoko, H., Di
    Sansebastiano, G.-P., Moore, I. and Blatt, M.R. 2002. The
    abscissic acid-related SNARE homolog NtSyr1 contributes to
    secretion and growth: evidence from competition with its
    cytosolic domain Plant Cell, 14, 387-406.</p>

    <p class="bibliography">Martinez, J.P., Ledent, J.F., Bajji,
    M., Kinet, J.M. and Lutts, S. 2003. Effect of water stress on
    growth, Na+ and K+ accumulation and water use efficiency in
    relation to osmotic adjustment in two populations of Atriplex
    halimus L. Plant Growth Regul., 41, 63-73.</p>

    <p class="bibliography">Dielen, V., Quinet, M., Chao, J.,
    Batoko, H., Havelange, A. and Kinet, J.M. 2004. UNIFLORA, a
    pivotal gene that regulates floral transition and meristem
    identity in tomato (Lycopersicon esculentum Mill.). New
    Phytol., 161, 393-400.</p>

    <p class="bibliography">Quinet, M., Cawoy, V., Lef\350vre, I.,
    Van Miegroet, F., Jacquemart, A.L. and Kinet, J.M. 2004.
    Inflorescence structure and control of flowering time and
    duration by light in buckwheat (Fagopyrum esculentum Moench.).
    J. Exp. Bot., 55, 1509-1517.</p>

    <p class="bibliography">Lutts, S., Lef\350vre, I.,
    Delp&eacute;r&eacute;e, C., Kivits, S., Dechamps, C., Robledo,
    A. and Correal, E. 2004. Heavy metal accumulation by the
    halophyte species Atriplex halimus, a promising species for
    phytoremediation purposes. J. Environm. Qual., 33, in
    press.</p>
  </div>

  <h2>Contact</h2>

  <p>Jean-Marie Kinet - Stanley Lutts - Henri Batoko<br />
  Universit&eacute; catholique de Louvain<br />
  Unit&eacute; de Biologie v&eacute;g&eacute;tale<br />
  D&eacute;partement de Biologie et Institut des Sciences de la Vie
  (ISV)<br />
  Croix du Sud, 5 (bte 13)<br />
  B-1348 Louvain-la-Neuve<br />
  Belgium<br />
  Fax : +32 10 47 34 35<br />
  <br />
  JMK : Tel : +32 10 47 20 50 - Email : <a href=
  "mailto:kinet\@bota.ucl.ac.be">kinet\@bota.ucl.ac.be</a><br />
  SL : Tel : +32 10 47 20 37 - Email : <a href=
  "mailto:lutts\@bota.ucl.ac.be">lutts\@bota.ucl.ac.be</a><br />
  HB : Tel : +32 10 47 92 65 - Email : <a href=
  "mailto:batoko\@bota.ucl.ac.be">batoko\@bota.ucl.ac.be</a><br />
  <br />
  For more information, please visit the lab's website at<br />
  <a href=
  "http://www.bota.ucl.ac.be/Acces.html">http://www.bota.ucl.ac.be/Acces.html</a><br />

  <br />
  (note that an english version of the site will be launched
  soon).</p>
END_HEREDOC
$page->footer();
