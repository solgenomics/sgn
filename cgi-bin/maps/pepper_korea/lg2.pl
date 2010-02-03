use strict;
use CXGN::Page;
my $page=CXGN::Page->new('lg2.html','html2pl converter');
$page->header('Pepper Linkage Group 2');
print<<END_HEREDOC;

  <h2>Linkage Group 2</h2>
  <img src="/documents/maps/pepper_korea/Slide2.PNG" border="0" width="541" height="1440" alt=
  "Linkage Group 2" />
END_HEREDOC
$page->footer();
