use strict;
use CXGN::Page;
my $page=CXGN::Page->new('chr2.html','html2pl converter');
$page->header('L. Pennellii Chromosome 2');
print<<END_HEREDOC;

  <img alt="" src="/documents/maps/pennellii_il/Slide2.PNG" />
END_HEREDOC
$page->footer();
