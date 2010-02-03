use strict;
use CXGN::Page;
my $page=CXGN::Page->new('members.html','html2pl converter');
$page->header('Members of the Advisory Group');
print<<END_HEREDOC;

  <h2>The following individuals have served on the Tomato Genomics
  Project Advisory Group:</h2>

  <p>Dr. Ray Bressan (<a href=
  "mailto:bressan\@hort.purdue.edu">bressan\@hort.purdue.edu</a>)<br />

  Department of Horticulture<br />
  Center for Plant Stress Physiology<br />
  Purdue University<br />
  West Lafayette, IN</p>

  <p>Dr. Harry Klee (<a href=
  "mailto:hjklee\@gnv.ifas.ufl.edu">hjklee\@gnv.ifas.ufl.edu</a>)<br />

  Department of Horticultural Science<br />
  1143 Fifield Hall<br />
  University of Florida<br />
  Gainesville, FL 32611-0690<br />
  (352) 392-8249</p>

  <p>Dr. Dani Zamir (<a href=
  "mailto:zamir\@agri.huji.ac.il">zamir\@agri.huji.ac.il</a>)<br />
  Faculty of Agriculture<br />
  Hebrew University of Jerusalem<br />
  Rehovot, Israel</p>

    

END_HEREDOC
$page->footer();