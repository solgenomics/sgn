use strict;
use CXGN::Page;
my $page=CXGN::Page->new('lg5.html','html2pl converter');
$page->header('Pepper Linkage Group 5');
print<<END_HEREDOC;

  <h2>Linkage Group 5</h2>
  <img src="/documents/maps/pepper_korea/Slide5.PNG" border="0" width="466" height="1440" alt=
  "Linkage Group 5" />
END_HEREDOC
$page->footer();
