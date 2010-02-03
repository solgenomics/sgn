use strict;
use CXGN::Page;
my $page=CXGN::Page->new('lg4.html','html2pl converter');
$page->header('Pepper Linkage Group 4');
print<<END_HEREDOC;

  <h2>Linkage Group 4</h2>
  <img src="/documents/maps/pepper_korea/Slide4.PNG" border="0" width="580" height="1440" alt=
  "Linkage Group 4" />
END_HEREDOC
$page->footer();
