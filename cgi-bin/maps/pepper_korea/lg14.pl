use strict;
use CXGN::Page;
my $page=CXGN::Page->new('lg14.html','html2pl converter');
$page->header('Pepper Linkage Group 14');
print<<END_HEREDOC;

  <h2>Linkage Group 14</h2>
  <img src="/documents/maps/pepper_korea/Slide14.PNG" border="0" width="440" height="1072" alt=
  "Linkage Group 14" />
END_HEREDOC
$page->footer();
