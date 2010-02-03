use strict;
use CXGN::Page;
my $page=CXGN::Page->new('lg1.html','html2pl converter');
$page->header('Pepper Linkage Group 1');
print<<END_HEREDOC;

  <h2>Linkage Group 1</h2>
  <img src="/documents/maps/pepper_korea/Slide1.PNG" border="0" width="394" height="1440" alt=
  "Linkage Group 1" />
END_HEREDOC
$page->footer();
