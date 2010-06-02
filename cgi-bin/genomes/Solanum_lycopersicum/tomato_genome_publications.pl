
use strict;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw | info_section_html |;

my $page = CXGN::Page->new("Tomato Genome Publications", "Lukas");

$page->header("SGN | Tomato Genome Publications", "Tomato Genome Publications");

print info_section_html(title => "Selected Publications related to the tomato genome sequence", contents=><<PUBLICATION_DATA);

<ul>
<li>Lukas A. Mueller,
    Ren&eacute; Klein Lankhorst,
    Steven D. Tanksley,
    James J. Giovannoni,
    Ruth White,
    Julia Vrebalov,
    Zhangjun Fei,
    Joyce van Eck,
    Robert Buels,
    Adri A. Mills,
    Naama Menda,
    Isaak Y. Tecle,
    Aureliano Bombarely,
    Stephen Stack,
    Suzanne M. Royer,
    Song-Bin Chang,
    Lindsay A. Shearer,
    Byung Dong Kim,
    Sung-Hwan Jo,
    Cheol-Goo Hur,
    Doil Choi,
    Chang-Bao Li,
    Jiuhai Zhao,
    Hongling Jiang,
    Yu Geng,
    Yuanyuan Dai,
    Huajie Fan,
    Jinfeng Chen,
    Fei Lu,
    Jinfeng Shi,
    Shouhong Sun,
    Jianjun Chen,
    Xiaohua Yang,
    Chen Lu,
    Mingsheng Chen,
    Zhukuan Cheng,
    Chuanyou Li,
    Hongqing Ling,
    Yongbiao Xue,
    Ying Wang,
    Graham B. Seymour,
    Gerard J. Bishop,
    Glenn Bryan,
    Jane Rogers,
    Sarah Sims,
    Sarah Butcher,
    Daniel Buchan,
    James Abbott,
    Helen Beasley,
    Christine Nicholson,
    Clare Riddle,
    Sean Humphray,
    Karen McLaren,
    Saloni Mathur,
    Shailendra Vyas,
    Amolkumar U. Solanke,
    Rahul Kumar,
    Vikrant Gupta,
    Arun K. Sharma,
    Paramjit Khurana,
    Jitendra P. Khurana,
    Akhilesh Tyagi,
    Sarita,
    Parul Chowdhury,
    Smriti Shridhar,
    Debasis Chattopadhyay,
    Awadhesh Pandit,
    Pradeep Singh,
    Ajay Kumar,
    Rekha Dixit,
    Archana Singh,
    Sumera Praveen,
    Vivek Dalal,
    Mahavir Yadav,
    Irfan Ahmad Ghazi,
    Kishor Gaikwad,
    Tilak Raj Sharma,
    Trilochan Mohapatra,
    Nagendra Kumar Singh,
    Dóra Szinay,
    Hans de Jong,
    Sander Peters,
    Marjo van Staveren,
    Erwin Datema,
    Mark W.E.J. Fiers,
    Roeland C.H.J. van Ham,
    P. Lindhout,
    Murielle Philippot,
    Pierre Frasse,
    Farid Regad,
    Mohamed Zouine,
    Mondher Bouzayen,
    Erika Asamizu,
    Shusei Sato,
    Hiroyuki Fukuoka,
    Satoshi Tabata,
    Daisuke Shibata,
    Miguel A. Botella,
    M. Perez-Alonso,
    V. Fernandez-Pedrosa,
    Sonia Osorio,
    Amparo Mico,
    Antonio Granell,
    Zhonghua Zhang,
    Jun He,
    Sanwen Huang,
    Yongchen Du,
    Dongyu Qu,
    Longfei Liu,
    Dongyuan Liu,
    Jun Wang,
    Zhibiao Ye,
    Wencai Yang,
    Guoping Wang,
    Alessandro Vezzi,
    Sara Todesco,
    Giorgio Valle,
    Giulia Falcone,
    Marco Pietrella,
    Giovanni Giuliano,
    Silvana Grandillo,
    Alessandra Traini,
    Nunzio D\'Agostino,
    Maria Luisa Chiusano,
    Mara Ercolano,
    Amalia Barone,
    Luigi Frusciante,
    Heiko Schoof,
    Anika J&ouml;cker,
    R&eacute;my Bruggmann,
    Manuel Spannagl,
    Klaus X.F. Mayer,
    Roderic Guig&oacute;,
    Francisco Camara,
    Stephane Rombauts,
    Jeffrey A. Fawcett,
    Yves Van de Peer,
    Sandra Knapp,
    Dani Zamir,
    and Willem Stiekema
(2009)
A Snapshot of the Emerging Tomato Genome Sequence
Plant Gen. 2:78-92; doi:10.3835/plantgenome2008.08.0005
<li>Todesco S., Campagna D., Levorin F., D\'Angelo M., Schivaon R., Valle G., Vezzi A.<br />PABS: An online platform to assist BAC-by-BAC sequencing projects. (2008) BioTechniques 44:60-64.</li>
<li>Amalia  Barone, Maria Luisa Chiusano, Maria Raffaella Ercolano, Giovanni  Giuliano, Silvana  Grandillo, and Luigi  Frusciante.<br >Structural and Functional Genomics of Tomato. (2008) International Journal of Plant Genomics, vol. 2008</li>
<li>S.-B. Chang, L.K. Anderson, J.D. Sherman, S.M. Royer, and S.M. Stack. <br /><i>Predicting and testing physical locations of genetically mapped loci on tomato pachytene chromosome</i> (2008) Genetics 176: 2131-2138.</li>
<li>Kahlau S, Aspinall S, Gray JC, Bock R. <br />
<i>Sequence of the tomato chloroplast DNA and evolutionary comparison of solanaceous plastid genomes.</i><br />
J Mol Evol. 2006 Aug;63(2):194-207. Epub 2006 Jul 7. <a href="http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=pubmed&amp;cmd=Retrieve&amp;dopt=AbstractPlus&amp;query_hl=16&amp;itool=pubmed_docsum&amp;list_uids=16830097">PubMed</a></li>
<li>Peters SA, van Haarst JC, Jesse TP, Woltinge D, Jansen K, Hesselink T, van Staveren MJ, Abma-Henkens MH, Klein-Lankhorst RM. (2006)<br />
	<i>TOPAAS, a tomato and potato assembly assistance system for selection and finishing of bacterial artificial chromosomes.</i><br />
Plant Physiol. 2006 Mar;140(3):805-17.
<a href="http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=pubmed&amp;cmd=Retrieve&amp;dopt=AbstractPlus&amp;query_hl=16&amp;itool=pubmed_docsum&amp;list_uids=16524981">PubMed</a></li>
<li>Wang Y, Tang X, Cheng Z, Mueller L, Giovannoni J, Tanksley SD.<br />
<i>Euchromatin and pericentromeric heterochromatin: comparative composition in the tomato genome.</i><br />
Genetics. 2006 Apr;172(4):2529-40. Epub 2006 Feb 19. <a href="http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=pubmed&amp;cmd=Retrieve&amp;dopt=AbstractPlus&amp;query_hl=16&amp;itool=pubmed_docsum&amp;list_uids=16489216">PubMed</a>
</li>
<li>Wang Y, van der Hoeven RS, Nielsen R, Mueller LA, Tanksley SD.<br />
<i>Characteristics of the tomato nuclear genome as determined by sequencing undermethylated EcoRI digested fragments.</i><br />
Theor Appl Genet. 2005 Dec;112(1):72-84. Epub 2005 Oct 6. <a href="http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=pubmed&amp;cmd=Retrieve&amp;dopt=AbstractPlus&amp;query_hl=16&amp;itool=pubmed_docsum&amp;list_uids=16208505">PubMed</a></li>
<li>Mueller LA, Solow TH, Taylor N, Skwarecki B, Buels R, Binns J, Lin C, Wright MH, Ahrens R, Wang Y, Herbst EV, Keyder ER, Menda N, Zamir D, Tanksley SD.<br />
<i>The Sol Genomics Network: a comparative resource for Solanaceae biology and beyond.</i><br />
Plant Physiol. 2005 Jul;138(3):1310-7.
<a href="http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=pubmed&amp;cmd=Retrieve&amp;dopt=AbstractPlus&amp;query_hl=16&amp;itool=pubmed_docsum&amp;list_uids=16010005">PubMed</a></li>
<li>Budiman MA, Mao L, Wood TC, Wing RA.<br />
	<i>A deep-coverage tomato BAC library and prospects toward development of an STC framework for genome sequencing.</i><br />
Genome Res. 2000 Jan;10(1):129-36.
<a href="http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=pubmed&amp;cmd=Retrieve&amp;dopt=AbstractPlus&amp;query_hl=16&amp;itool=pubmed_docsum&amp;list_uids=10645957">PubMed</a> </li>
<li>Areshchenkova T, Ganal MW.<br />
	<i>Long tomato microsatellites are predominantly associated with centromeric regions.</i><br />
Genome. 1999 Jun;42(3):536-44.
<a href="http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=pubmed&amp;cmd=Retrieve&amp;dopt=AbstractPlus&amp;query_hl=16&amp;itool=pubmed_docsum&amp;list_uids=10382301">PubMed</a></li>
<li>Peterson DG, Lapitan NL, Stack SM.<br />
	<i>Localization of single- and low-copy sequences on tomato synaptonemal complex spreads using fluorescence in situ hybridization (FISH).</i><br />
Genetics. 1999 May;152(1):427-39.
PMID: 10224272 </li>
<li>Peterson DG, Price HJ, Johnston JS, Stack SM. <br />
<i>DNA content of heterochromatin and euchromatin in tomato (Lycoperiscon esculentum) pachytene chromsosomes.</i><br />
Genome, 1996. 39:299-315.</li>
<li>Xu J, Earle ED. <br />
<i>High resolution physical mapping of 45S (5.8S, 18S and 25S) rDNA gene loci in the tomato genome using a combination of karyotyping and FISH of pachytene chromosomes.</i><br />
Chromosoma. 1996 Jun;104(8):545-50.
<a href="http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=pubmed&amp;cmd=Retrieve&amp;dopt=AbstractPlus&amp;query_hl=16&amp;itool=pubmed_docsum&amp;list_uids=8662247">PubMed</a></li>
<li>Zhong XB, Hans de Jong J, Zabel P.<br />
    <i>Preparation of tomato meiotic pachytene and mitotic metaphase chromosomes suitable for fluorescence in situ hybridization (FISH).</i><br />
Chromosome Res. 1996 Jan;4(1):24-8.
<a href="http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=pubmed&amp;cmd=Retrieve&amp;dopt=AbstractPlus&amp;query_hl=16&amp;itool=pubmed_docsum&amp;list_uids=8653264">PubMed</a></li>
<li>Sherman JD, Stack SM.<br />
    <i>Two-dimensional spreads of synaptonemal complexes from solanaceous plants. VI. High-resolution recombination nodule map for tomato (Lycopersicon esculentum).</i><br />
Genetics. 1995 Oct;141(2):683-708.
<a href="http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=pubmed&amp;cmd=Retrieve&amp;dopt=AbstractPlus&amp;query_hl=16&amp;itool=pubmed_docsum&amp;list_uids=8647403">PubMed</a></li>
<li>Arumuganathan K and Earle E.<br />
<i>Estimation of nuclear DNA content of plants by flow cytometry.</i><br />
Plant Mol Biol Rep. 9:208-218.</li>
</ul>

[<a href="mailto:sgn-feedback\@sgn.cornell.edu">Contact us</a> to add a publication]
PUBLICATION_DATA


$page->footer();
