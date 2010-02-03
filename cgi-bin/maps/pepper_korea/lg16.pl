use strict;
use CXGN::Page;
my $page=CXGN::Page->new('lg16.html','html2pl converter');
$page->header('Pepper Linkage Group 16');
print<<END_HEREDOC;

  <h2>Linkage Group 16</h2>
  <img src="/documents/maps/pepper_korea/Slide16.PNG" border="0" width="512" height="448" alt=
  "Linkage Group 16" />
END_HEREDOC
$page->footer();
