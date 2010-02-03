use strict;
use CXGN::Page;
my $page=CXGN::Page->new('200405.html','html2pl converter');
$page->header('The Choi Lab');
print<<END_HEREDOC;

  <center>
    <h1>Plant Genomics Lab. at KRIBB</h1><img src="/static_content/community/feature/200405-1.jpg"
    width="720" height="540" border="0" alt=
    "Members of the Choi Lab" />
  </center>

  <h2>Research Highlight</h2>

  <p>Our main interest is the application of functional genomics
  tools to understand plant defense mechanism at the molecular
  level. For this object, we have been using the non-host resistant
  interaction between hot pepper (Capsicum annuum L.) and soybean
  pustule pathogen Xag (Xanthomonas axonopodis pv. glycines).</p>

  <p>First approach was the collection of massive hot pepper ESTs
  from divergent cDNA libraries (detail information is shown in
  <a href=
  "http://plant.pdrc.re.kr/ks200201/pepper.html">http://plant.pdrc.re.kr/ks200201/pepper.html</a>
  and <a href=
  "/content/sgn_data.pl">http://www.sgn.cornell.edu/content/sgn_data.pl</a>).
  We have got more than 10,000 unique hot pepper genes (<a href=
  "http://ted.bti.cornell.edu/pepper/">http://ted.bti.cornell.edu/pepper/</a>).</p>

  <p>Next, we made the 5K cDNA microarray using unique hot pepper
  ESTs to monitor the global gene expression response to the
  pathogen inoculation, and finally we could get the candidate
  genes involved plant defense reaction. The pepper gene expression
  profiles were constructed as database and released to public
  (<a href=
  "http://plant.pdrc.re.kr:7777/index.html">http://plant.pdrc.re.kr:7777/index.html</a>).
  Currently we are building 10K cDNA microarray and getting more
  expression data from divergent stress situation, developmental
  stage and specific organs.</p>

  <p>Recently, we established VIGS (Virus Induced Gene Silencing)
  method in hot pepper plant for the functional characterization of
  defense related genes. The identification of functional roles of
  defense related genes will be broaden and deepen our knowledge of
  plant defense mechanism.</p>

  <p class="footnote"><a href="/static_content/community/feature/200405-2.jpg"><img src=
  "/static_content/community/feature/200405-2-small.jpg" width="700" height="694" border="0" alt=
  "Figure 1 - Hot pepper 5K cDNA microarray image" /></a><br />
  <strong>Figure 1.</strong> Hot pepper 5K cDNA microarray image.
  This image was captured by the Axon 4000A scanner after
  hybridization with reference (Cy-3 labeled, 1mM MgCl2) and
  treatment (Cy-5 labeled, Xag infiltration).</p>

  <p class="footnote"><img src="/static_content/community/feature/200405-3.jpg" width="640" height=
  "480" border="0" alt=
  "Figure 2 - Picture of VIGS (Virus Induced Gene Silencing) plant" /><br />

  <strong>Figure 2.</strong> Picture of VIGS (Virus Induced Gene
  Silencing) plant. The partial sequences of PDS (Phytoene
  desaturase) gene was inserted into modified TRV (Tobacco Rattle
  Virus) vector (a kind gift from Dr. Dinesh- Kumar) and then
  inoculated into hot pepper plant with Agrobacterium. The
  distinctive photo-bleaching phenotype was shown after 21 days
  after inoculation.</p>

  <h2>Contact</h2>

  <p><strong>Dr. Doil Choi</strong><br />
  Plant Genomics Laboratory, Genome Research Center,<br />
  Korea Research Institute of Bioscience &amp; Biotechnology
  (KRIBB)<br />
  52 Oun-dong, Yusong-gu, Taejon, 305-333, Korea<br />
  <br />
  Tel : +82-42-860-4340<br />
  Fax : +82-42-860-4309<br />
  e-mail : <a href=
  "mailto:doil\@kribb.re.kr">doil\@kribb.re.kr</a><br />
  relevant web-site :<br />
  <a href=
  "http://plant.pdrc.re.kr:7777/index.html">http://plant.pdrc.re.kr:7777/index.html</a><br />

  <a href=
  "http://plant.pdrc.re.kr/ks200201/pepper.html">http://plant.pdrc.re.kr/ks200201/pepper.html</a><br />

  <a href=
  "http://www.sgn.cornell.edu/content/sgn_data.pl">http://www.sgn.cornell.edu/content/sgn_data.pl</a><br />

  <a href=
  "http://ted.bti.cornell.edu/pepper/">http://ted.bti.cornell.edu/pepper/</a><br />
  </p>
END_HEREDOC
$page->footer();