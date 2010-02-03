use strict;
use CXGN::Page;
my $page=CXGN::Page->new('200507.html','html2pl converter');
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

$page->header('Coffee Biotechnology Lab', undef, $stylesheet);
print<<END_HEREDOC;

<center>
<h1>Coffee Biotechnology Lab</h1>
</center>

<p class="footnote"><img src="/static_content/community/feature/200507-1.jpg" border="0" width="800" height="572" alt="Coffee Lab" /><br />
<u>Coffee Biotech Group</u> - <strong>Front row:</strong> Adalgisa Soares, Julieta Almeida, Milene Silvestrini, Fernanda Pinto, Crisitana Pezzopane and
<br />Mirian Maluf.  <strong>Back row:</strong> Bernadete Silvarolla, Julio Mistro, Marcos Brandalise, Ant&ocirc;nio Bai&atilde;o.</p>

<p class="footnote" style="float:right; width:375px; text-align:center;"><img src="/static_content/community/feature/200507-2.jpg" border="0" width="350" height="263" alt="Coffea arabica cultivars exhibiting red fruits" /><br />
Coffea arabica cultivars exhibiting red fruits
</p>

<p>
The Coffee Biotechnology Lab is a small (but increasing) group interested
in functional analysis of coffee genes related to agronomic
characteristics.  The group works in a close association with the IAC
Coffee Breeding Program.  During the past seventy years, this program has
been responsible for the development of several Coffea arabica and Coffea
canephora cultivars, which are planted extensively over Brazilian coffee
regions.  In addition to coffee cultivars, there are numerous populations
under selection segregating for important agronomic traits, such as
resistance to abiotic and biotic stress, flowering and fruit development
timing, biochemical composition of fruits and seeds, and cup quality.
Also, the IAC has a comprehensive in situ Germplasm Collection, which
includes 22 different Coffea species.
</p>

<p>
The main limitation for coffee breeding is the very narrow genetic base
of the species C. arabica.  Major efforts concentrate on developing
reliable tools for improving selection methods and also for introducing
novel traits into coffee cultivars.
</p>

<p class="footnote" style="float:left; width:375px; text-align:center;"><img src="/static_content/community/feature/200507-3.jpg" border="0" width="350" height="263" alt="Coffea arabica cultivars exhibiting yellow fruits" /><br />
Coffea arabica cultivars exhibiting yellow fruits
</p>

<p>
The Coffee Biotechnology Lab is responsible for the identification of
molecular markers suitable for marker-assisted selection.  RAPD, AFLP and
microsattelites methods are used both to identify markers associated with
agronomic traits and to evaluate overall genetic variability of the Coffea
Germplasm Collection.
</p>

<p>
 Recently, with the conclusion of the Coffee ESTs Genome sequencing, we
have initiated functional analysis of specific genes related mainly to
pathogen defense, flower development and caffeine biosynthesis.  We use
methodologies that integrate expression profile analysis, such as RT-PCR,
differential display and microarrays, and traditional breeding methods.  In
collaboration with the Biology Institute/UNESP, we have a project to
isolate
tissue-specific promoters from roots, leaves, and fruits.  Also, in
collaboration with the IAC Cytogenetic Lab, we are mapping selected
microsattelites markers through FISH analysis.
</p>

<p>
 Genomic research in coffee species is still very modest. However, due to
the economic and social importance of coffee culture and to the increasing
interest of research groups on coffee issues, we believe (and hope) that in
a short period this gap of genomic knowledge will be overcome.
</p><br clear="all" />

<div style="float:left; width:250; text-align:left;">
<h2>Contact Information</h2>
<p>
Dr. Mirian Perez Maluf<br />
Scientific Researcher / Embrapa<br />
Coffee Center &quot;Alcides Carvalho&quot;<br />
Agronomic Institute<br />
Campinas - SP<br />
Brazil<br />
<a href= "mailto:maluf\@iac.sp.gov.br">maluf\@iac.sp.gov.br</a><br />
</p>
</div>

<p class="footnote" style="float:right; width:400px; text-align:center;"><img src="/static_content/community/feature/200507-4.jpg" border="0" width="375" height="166" alt="IAC Coffee cultivars planted at the Experimental Station" /><br />
IAC Coffee cultivars planted at the Experimental Station
</p><br clear="all" />

<h2>Selected Publications</h2>

<p class="bibliography">
Mondego, J.M.C.,  Guerreiro  Filho,  O.,  Bengtson,  M.H.,  Drummond,  R.D.,
Felix, J. M., Duarte,  M.P.,  Ramiro,  D.A.,  Maluf,  M.P.,  Sogayar,  M.C.,
Menossi, M. (2005) "Isolation and characterization of Coffea  genes  induced
during  leaf  coffee  miner  (Leucoptera  coffeella)  infestation  ",  Plant
Science, in press.
</p>

<p class="bibliography">
Maluf, M.P., Silvestrini, Ruggiero, M., L. M. de C., Guerreiro-Filho, O.,
Colombo, C. A.  (2005) &quot;Genetic diversity of cultivated Coffea arabica lines
assessed by RAPD, AFLP and SSR marker systems&quot;, Scientia Agricola, in
press.
</p>

<p class="bibliography">
Silvarolla,  M.B.,  Mazzafera,  P.,  Fazuoli,  L.C.   (2004)   A   naturally
decaffeinated arabica coffee. Nature, Inglaterra, v. 429, p. 826-826.
</p>

<p class="bibliography">
Mistro, J.C.; Fazuoli, L.C. ; Gon&ccedil;alves, P.S. ; Guerreiro-Filho, O.  (2004).
Estimatives of genetic parameters and expected genetic gains with  selection
in robust coffee. Crop Breeding And Applied Biotechnology, Vi&ccedil;osa  (MG),  v.
4, n. 1, p. 86-91.
</p>

<p class="bibliography">
Guerreiro Filho, O.;  Mazzafera,  P.  (2003).  Caffeine  and  resistance  of
coffee to the berry  borer  Hypothenemus  hampei  (Coleoptera:  Scolytidae).
Journal of Agricultural and Food Chemistry, Davis, Calif&oacute;rnia, EUA,  v.  51,
n. 24, p. 6987-6991.
</p>

<p class="bibliography">
Aguiar, A.T.,  Maluf,  M.P.,  Gallo,  P.B.,  Fazuoli,  L.C.,  Mori,  E.E.M.,
Guerreiro-Filho, O.  Technological  and  morphological  characterization  of
coffee Commercial lines developed by IAC - Brazil  (2001).  In:  Association
Scientifique International du Caf&eacute; - 19 &eacute;me Colloque,  Trieste.  Association
Scientifique International du Caf&eacute;. 2001. v. CD-ROM
</p>

<p class="bibliography">
Orsi, C. H.; Colombo, Carlos A;  Guerreiro-Filho,  Oliveiro;  Maluf,  Mirian
Perez.  Putative  NBS-LRR  resistance  genes  analogs  (RGA)  identified  in
different species of the genera Coffea. (2001) In: 47o.  Congresso  nacional
de Gen&eacute;tica, &Aacute;guas de Lind&oacute;ia. Sociedade Brasileira de  Gen&eacute;tica  /Anais  do
47o. Congresso Nacional de Gen&eacute;tica.
</p>

<p class="bibliography">
Pinto-Maglio, C.A.F; Barbosa, RL; Cuellar, T.; Maluf, M.P.; Pierozzi,  N.I.;
Silvarolla, M.B.; Orsi, C.H. (2001) Chromosome  characterization  in  Coffea
arabica  L.  using  cytomolecular   techniques.   In:   14th   International
Chromosome Conference, Wurzburg, Germany. Chromosome Research. v. 9, p. 100-
100.
</p>

END_HEREDOC
$page->footer();
