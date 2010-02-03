use strict;
use CXGN::Page;
my $page=CXGN::Page->new('lg12.html','html2pl converter');
$page->header('Pepper Linkage Group 12');
print<<END_HEREDOC;
  
<h2>Linkage Group 12</h2>
  <img src="/documents/maps/pepper_korea/Slide12.PNG" border="0" width="568" height="1167" alt=
  "Linkage Group 12" />
END_HEREDOC
$page->footer();
