use strict;

use CXGN::Page;

my $page = CXGN::Page->new("SGN Featured Lab: The Plant Molecular Genetics Lab, Corpoica, Colombia", "Adri");

$page->header("The Plant Molecular Genetics Lab, Corpoica, Colombia", "The Plant Molecular Genetics Lab, Corpoica, Colombia");

print <<HTML;

<br />

<center><img src="/static_content/community/feature/200810-group.jpg" /></center>

<br />

<p>Our lab is at the core of the Biotechnology and Bioindustry Center (CBB) at the Colombian Corporation for Agricultural Research (<a href="http://www.corpoica.org.co">CORPOICA</a>) in Bogot&aacute;, Colombia, strategically located in the Andean region.</p>

<p>The research in our group is focused on the molecular characterization of germplasm collections, the identification of markers or genes associated with traits of agronomic interest, and the support of national breeding programs. Our efforts in Solanaceae crops have been devoted to fruited species of Andean origin including <em>Solanum quitoense</em> (lulo), <em>S. betaceum</em> (tree tomato) and more recently <em>Physalis peruviana</em> (goldenberry). In addition to native tuber bearing species (<em>Solanum phureja</em> or golden potato), all are economically and socially important crops for local and export markets.</p>

<p>We have established national and international collaborations that include Universidad de los Andes, Universidad Nacional de Colombia, Cenicafe, Cornell University, Georgia Institute of Technology and the National Institute of Health.  We are using COSII markers for genetic map construction in golden potato and to assess the diversity of germplasm collections and identification of hybrids in lulo and tree tomato. We are also working on the isolation and characterization of polyphenol oxidases responsible for fruit browning and Mi-like genes associated with nematode resistance in lulo. In addition, we are mapping candidate genes for induced resistance and growth promotion by the biocontroller <em>Trichoderma</em> in <em>S. lycopersicum</em> (tomato).</p>

<p>The recent Solanacae focus of our group is goldenberry and potato. In this regard, we have initiated projects on goldenberry related to the generation of haploids and double haploid lines and the identification of genes associated with <em>Fusarium</em> resistance, the main constraint for production in Colombia.</p>

<p>To face current and future challenges, we have begun to build a computational biology and bioinformatics platform to strengthen the lab for omics research in native Solanaceae by recent hires from Cenicafe and the National Center for Biotechnology Information (NCBI).</p>

<br />

<center>
<img src="/static_content/community/feature/200810-potato.jpg" />
<img src="/static_content/community/feature/200810-tomato.jpg"><br />
<img src="/static_content/community/feature/200810-golden.jpg" />
<img src="/static_content/community/feature/200810-lulo.jpg" />

<p>From left to right and top to bottom: Golden potato, tree tomato, goldenberry, and lulo<br />
(courtesy of M. Lobo, CORPOICA)</p>
</center>

<br />

<hr>

<h4>Selected Publications</h4>

<p>Pratt R.C., Francis D.A., Barrero L.S. (2008) Genomics of Tropical Solanaceous species: Established and emerging crops. In: Plant Genetics and Genomics: Crops and Models, Volume 1. P.H. Moore, R. Ming (editors); Genomics of tropical Crop Plants, Springer, New York, USA, p. 453-467</p>

<p>Cong B., Barrero L., Tanksley S. (2008) Regulatory Change in YABBY-like transcription Factor Led to Evolution of Extreme Fruit Size during Tomato Domestication. Nature genetics. 40: 800-804</p>

<p>Barrero L.S., Cong B., Wu F., Tanksley S.D. (2006). Developmental characterization of the fasciated locus and mapping of candidate genes involved in the control of floral meristem size and carpel number in tomato. Genome. 49: 991-1006</p>

<p>Barrero, L.S., Tanksley, S.D. (2004) Evaluating the genetic basis of multiple locule fruit in a broad cross section of tomato cultivars. Theoretical and Applied Genetics. 109: 669-679</p>

<p>Chaves-Bedoya, G., Nu&ntilde;ez, V (2007) A SCAR marker for the sex types determination in Colombian genotypes of Carica papaya. Euphytica. 153: 215-220</p>

<p>Nu&ntilde;ez, V. M., Pe&ntilde;a P. A., Valbuena I., Cer&oacute;n M. del S. (2007)  Estudio sobre cruzabilidad entre papas cultivadas y silvestres y entre papas cultivadas y malezas relacionadas. Tomo I. p. 52-68. En: Hodson de Jaramillo, E. y Carrizosa P., M.S. (comp.). Desarrollo de capacidades para evaluaci&oacute;n y gesti&oacute;n de riesgos y monitoreo de organismos gen&eacute;ticamente modificados (OGM). Resultados de proyectos espec&iacute;ficos. Instituto de Investigaci&oacute;n de Recursos Biol&oacute;gicos Alexander Von Humboldt. Bogot&aacute;, D.C. Colombia. 99 p.</p>

<p>Villa, A. l., Jimenez, P.E., Valbuena, R.I., Bastidas, s., Nu&ntilde;ez, V.M. (2007)  Preliminary study for the establishment of a cryoconservation protocol for oil palm Elaeis guineensis Jacq.  Agronom&iacute;a Colombiana. 52: 215-223</p>

<p>Tharakaraman K, Bodenreider O, Landsman D, Spouge JL, Mari&ntilde;o-Ram&iacute;rez L. (2008) The biological function of some human transcription factor binding motifs varies with position relative to the transcription start site. Nucleic Acids Res. 36: 2777-2786</p>

<p>Kim NK, Tharakaraman K, Mari&ntilde;o-Ram&iacute;rez L, Spouge JL. (2008)  Finding sequence motifs with Bayesian models incorporating positional information: an application to transcription factor binding sites. BMC Bioinformatics. 9: 262</p>

<p>Mari&ntilde;o-Ram&iacute;rez L, Jordan IK, Landsman D. (2006) Multiple independent evolutionary solutions to core histone gene regulation. Genome Biol. 7(12): R122</p>

<h4>Contact Information</h4>

Luz Stella Barrero Meneses<br />
Ph.D. Research Scientist<br />
Laboratory of Plant Molecular Genetics<br />
Center of Biotechnology and Bioindustry<br />
Colombian Corporation for Agricultural Research<br /> 
CORPOICA<br />
Colombia<br />
Phone: 57-1-4227329<br />
email: lbarrero\@corpoica.org.co<br />

HTML

    $page->footer();
