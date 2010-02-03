use strict;
use CXGN::Page;
my $page=CXGN::Page->new('lg11.html','html2pl converter');
$page->header('Pepper Linkage Group 11');
print<<END_HEREDOC;

  <h2>Linkage Group 11</h2>
  <img src="/documents/maps/pepper_korea/Slide11.PNG" border="0" width="792" height="1272" alt=
  "Linkage Group 11" />
END_HEREDOC
$page->footer();
