use strict;
use CXGN::Page;
my $page=CXGN::Page->new('lg9.html','html2pl converter');
$page->header('Pepper Linkage Group 9');
print<<END_HEREDOC;

  <h2>Linkage Group 9</h2>
  <img src="/documents/maps/pepper_korea/Slide9.PNG" border="0" width="509" height="1440" alt=
  "Linkage Group 9" />
END_HEREDOC
$page->footer();
