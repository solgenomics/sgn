use strict;
use CXGN::Page;
my $page=CXGN::Page->new('Lycopersicon_Combined.html','html2pl converter');
$page->header('Lycopersicon Combined Unigene Build Series');
print<<END_HEREDOC;
  
  <strong>Lycopersicon Combined Unigene Build Series</strong>

  <p>This unigene build series incorporates ESTs derived from
  Lycopersicon hirsutum, Lycopersion pennellii, and Lycopersion
  esculentum cDNA libraries. No other sequences are incorporated at
  this time. These libraries were constructed at <a href=
  "http://www.cornell.edu/">Cornell University</a> as part of the
  NSF funded <a href="/about/tomato_project/index.pl">Tomato
  Genomics Project (#9872617)</a>, and sequenced predominantly by
  <a href="http://www.tigr.org/">TIGR</a>. In pre-funding stages of
  the project, pilot sequencing was also provided by Cereon and
  Novartis. All sequences are 5' reads, except approximately 1\% of
  the clones, selected at random, were also sequenced from the 3'
  end.</p>

  <p>Summary of new features in this build</p>

  <ul>
    <li>New 5' and 3' sequences from re-arrayed "TUS" library</li>

    <li>New trimming and quality evaluation process</li>

    <li>New chimera screening processes reduce number of chimeric
    sequences introduced to the assembly process</li>

    <li>rRNA and cloning host contamination screened out</li>

    <li>BLAST results against NR and other databases cached and
    displayed automatically</li>
  </ul><strong>New Sequences</strong><br />

  <p>New in the latest iteration of this build is the creation and
  incorporation of a "re-arrayed" library which contains clones
  selected from the set of plates originally sequenced, spanning
  all of our cDNA libraries. Clones were selected to span our
  previous Lycopersicon unigene build as well as all of the clones
  used on the publicly available <a href=
  "http://bti.cornell.edu/CGEP/CGEP.html">Tomato cDNA
  microarray</a>. Efforts are in progress to (re)sequence this set
  of clones from both 5' and 3' ends and incorporate these new,
  paired reads, into our unigene assemblies. While this additional
  sequencing project is not yet complete, the current Lycopersicon
  Combined build incorporates 11732 new 5' reads and 9897 new 3'
  reads.</p>

  <p>Re-sequencing of TOM1 microarray clones was funded by <a href=
  "http://www.inra.fr">INRA</a> (French National Institute of
  Agronomics Research). For further information, contact:</p>
  <pre>
Mondher Bouzayen (bouzayen\@ensat.fr)
Genomics and Fruit Biotechnology Lab.
UMR 990 INRA/INP-ENSAT
Avenue de l'agrobiopole
BP107 Auzeville-Tolosan
F-31326 Castanet Tolosan Cedex, France
</pre>

  <p>Additional funding for 5'/3' sequencing non-array TUS clones
  was provided by the Italian Ministry of Agriculture and Forestry
  (MiPAF) as part of project DM357/7303/01, and performed by
  <a href="http://www.avesthagen.com/">Avesthagen Technologies
  Ltd.</a>, India. For further information, contact:</p>
  <pre>
Chris Bowler (chris\@szn.it)
Stazione Zoologica
Naples, Italy 
</pre>

  <p><strong>New trimming and quality evaluation</strong><br /></p>

  <p>Also new in this build is a completely redesigned raw data
  processing pipeline. All reads currently incorporated into SGN's
  unigenes are processed directly from the original chromatogram
  file. The high-quality portion of the cDNA insert is recovered by
  our own customized insert recovery process. [<font color=
  "gray">Details page under development</font>]<br /></p>

  <p><strong>Chimera Screening</strong><br /></p>

  <p>Incorporated as well in this pipeline are 3 independent
  screens for chimeric sequences. While none of these screens have
  been validated yet in the laboratory, statistics collected during
  EST preclustering show substantial reduction in putative false
  joining of EST clusters. ESTs considered to be putative chimeras
  are censored from the assembly process, reducing the false
  representation of spurious cDNA ligations as novel genes in the
  unigene output. [<font color="gray">Details page under
  development</font>]<br /></p>

  <p><strong>BLAST results stored</strong><br /></p>

  <p>With the current Lycopersicon Combined build and future
  unigene builds, BLASTs against common databases such as the
  genbank non-redundant peptide database (genbank/nr) and the
  Arabidopsis predicted proteome (TAIR) are precomputed and stored
  in SGN's databases. Stored matches can be viewed on unigene
  search result pages as a simple first pass annotation, where
  matches exist. [<a href=
  "/search/unigene.pl?unigene_id=145962&amp;force_image=1">see
  example</a>]<br /></p>

  <p><strong>Using this unigene build</strong><br /></p>

  <p>Utilizing the unigene build is as simple as searching against
  it. The most straight-forward way to search is to use the
  <a href="/tools/blast/">SGN BLAST
  interface</a> and select Lycopersicon Combined as the target
  database. Note that this BLAST database is nucleotide sequence,
  so you must use BLASTN, TBLASTN, or TBLASTX to search it. The
  resulting matches will provide links to detail pages for those
  unigenes.</p>

  <p>Another way to use this unigene build is to <a href=
  "/search/direct_search.pl">search it directly</a> with an
  SGN-U# identifier, or search the EST database with an EST
  identifier. The former requires you to have already identified
  the unigene before and noted its SGN-U#, or to have noted a
  reference somewhere using this identifier. The EST database
  however can be searched with genbank accessions, facility
  assigned identifiers, and clone stock identifiers, in addition to
  SGN's native SGN-E# identifiers.</p>

  <p>Finally, uses of TIGR's tomato gene index may search against
  this and other Lycopersicon builds using TIGR's TC#s. Any current
  TIGR TC# or older numbers from previous releases for which TIGR
  still maintains tracking information can be used to identify SGN
  unigenes which are assemblies of sequences in common those
  assembled in TIGR's tentative consensus assembly. Note that this
  mapping is not one-to-one, but many-to-many. Furthermore, our
  build contains nearly 20,000 sequences not contained in TIGR's
  most recent gene index release for tomato, and their build
  contains input sequences from exogenous sources which we did not
  include in this build.<br /></p>
  
  <br />
  
END_HEREDOC
$page->footer();
