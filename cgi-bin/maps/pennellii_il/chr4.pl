use strict;
use CXGN::Page;
my $page=CXGN::Page->new('chr4.html','html2pl converter');
$page->header('L. Pennellii Chromosome 4');
print<<END_HEREDOC;

  <img alt="" src="/documents/maps/pennellii_il/Slide4.PNG" />
END_HEREDOC
$page->footer();
