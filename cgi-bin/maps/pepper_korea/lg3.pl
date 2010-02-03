use strict;
use CXGN::Page;
my $page=CXGN::Page->new('lg3.html','html2pl converter');
$page->header('Pepper Linkage Group 3');
print<<END_HEREDOC;

  <h2>Linkage Group 3</h2>
  <img src="/documents/maps/pepper_korea/Slide3.PNG" border="0" width="370" height="1440" alt=
  "Linkage Group 3" />
END_HEREDOC
$page->footer();
