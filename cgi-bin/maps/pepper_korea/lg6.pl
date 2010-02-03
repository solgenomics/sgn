use strict;
use CXGN::Page;
my $page=CXGN::Page->new('lg6.html','html2pl converter');
$page->header('Pepper Linkage Group 6');
print<<END_HEREDOC;

  <h2>Linkage Group 6</h2>
  <img src="/documents/maps/pepper_korea/Slide6.PNG" border="0" width="601" height="1440" alt=
  "Linkage Group 6" />
END_HEREDOC
$page->footer();
