use strict;
use CXGN::Page;
my $page=CXGN::Page->new('lg7.html','html2pl converter');
$page->header('Pepper Linkage Group 7');
print<<END_HEREDOC;

  <h2>Linkage Group 7</h2>
  <img src="/documents/maps/pepper_korea/Slide7.PNG" border="0" width="607" height="1440" alt=
  "Linkage Group 7" />
END_HEREDOC
$page->footer();
