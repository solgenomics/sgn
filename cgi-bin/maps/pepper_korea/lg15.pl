use strict;
use CXGN::Page;
my $page=CXGN::Page->new('lg15.html','html2pl converter');
$page->header('Pepper Linkage Group 15');
print<<END_HEREDOC;

  <h2>Linkage Group 15</h2>
  <img src="/documents/maps/pepper_korea/Slide15.PNG" border="0" width="588" height="848" alt=
  "Linkage Group 15" />
END_HEREDOC
$page->footer();
