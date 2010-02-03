use strict;
use CXGN::Page;
my $page=CXGN::Page->new('chr10.html','html2pl converter');
$page->header('L. Pennellii Chromosome 10');
print<<END_HEREDOC;

  <img alt="" src="/documents/maps/pennellii_il/Slide10.PNG" />
END_HEREDOC
$page->footer();
