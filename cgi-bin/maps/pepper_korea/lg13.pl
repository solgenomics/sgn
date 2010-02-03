use strict;
use CXGN::Page;
my $page=CXGN::Page->new('lg13.html','html2pl converter');
$page->header('Pepper Linkage Group 13');
print<<END_HEREDOC;

  <h2>Linkage Group 13</h2>
  <img src="/documents/maps/pepper_korea/Slide13.PNG" border="0" width="428" height="1124" alt=
  "Linkage Group 13" />
END_HEREDOC
$page->footer();
