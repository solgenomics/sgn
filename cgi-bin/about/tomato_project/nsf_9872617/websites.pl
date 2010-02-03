use strict;
use CXGN::Page;
my $page=CXGN::Page->new('websites.html','html2pl converter');
$page->header('New Document');
print<<END_HEREDOC;

  <h1>Links to related Websites</h1>

  <h2>Search the Databases:</h2>

  <ul>
    <li><a href="http://www.tigr.org/tigr-scripts/tgi/T_index.cgi?species=tomato">The Institute for
    Genomic Research's (TIGR) Tomato Gene Index</a></li>

    <li><a href="http://www.ncbi.nlm.nih.gov/">National Center for
    Biotechnology Information (NCBI)</a></li>

    <li><a href="/index.pl">The Solanaceae Genome Network
    (SGN)</a></li>
  </ul>

  <h2>Related Cornell University Sites:</h2>

  <ul>
    <li><a href="http://www.tc.cornell.edu/">Supercomputing at
    Cornell</a></li>

    <li><a href="http://www.genomics.cornell.edu/">Cornell Genomics
    Initiative</a></li>

    <li><a href="http://bti.cornell.edu/CGEP/CGEP.html">Boyce
    Thompson Institue Microarray Facility (CGEP)</a></li>
  </ul>

  <p>If you would like to add to this page please e-mail <a href=
  "mailto:dci1\@cornell.edu">dci1\@cornell.edu</a>. We appreciate
  your suggestions.</p>

    

END_HEREDOC
$page->footer();