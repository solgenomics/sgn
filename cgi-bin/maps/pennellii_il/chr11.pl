use strict;
use CXGN::Page;
my $page=CXGN::Page->new('chr11.html','html2pl converter');
$page->header('L. Pennellii Chromosome 11');
print<<END_HEREDOC;

  <img alt="" src="/documents/maps/pennellii_il/Slide11.PNG" />
END_HEREDOC
$page->footer();
