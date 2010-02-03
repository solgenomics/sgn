use strict;
use CXGN::Page;
my $page=CXGN::Page->new('chr1.html','html2pl converter');
$page->header('L. Pennellii Chromosome 1');
print<<END_HEREDOC;

  <img alt="" src="/documents/maps/pennellii_il/Slide1.PNG" />
END_HEREDOC
$page->footer();
