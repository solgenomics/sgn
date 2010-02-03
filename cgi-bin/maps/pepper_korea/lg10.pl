use strict;
use CXGN::Page;
my $page=CXGN::Page->new('lg10.html','html2pl converter');
$page->header('Pepper Linkage Group 10');
print<<END_HEREDOC;

  <h2>Linkage Group 10</h2>
  <img src="/documents/maps/pepper_korea/Slide10.PNG" border="0" width="440" height="704" alt=
  "Linkage Group 10" />
END_HEREDOC
$page->footer();
