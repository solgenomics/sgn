use strict;
use CXGN::Page;
my $page=CXGN::Page->new('chr5.html','html2pl converter');
$page->header('L. Pennellii Chromosome 5');
print<<END_HEREDOC;

  <img alt="" src="/documents/maps/pennellii_il/Slide5.PNG" />
END_HEREDOC
$page->footer();
