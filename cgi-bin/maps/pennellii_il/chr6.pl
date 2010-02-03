use strict;
use CXGN::Page;
my $page=CXGN::Page->new('chr6.html','html2pl converter');
$page->header('L. Pennellii Chromosome 6');
print<<END_HEREDOC;

  <img alt="" src="/documents/maps/pennellii_il/Slide6.PNG" />
END_HEREDOC
$page->footer();
