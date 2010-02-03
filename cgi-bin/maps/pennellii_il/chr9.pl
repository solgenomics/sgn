use strict;
use CXGN::Page;
my $page=CXGN::Page->new('chr9.html','html2pl converter');
$page->header('L. Pennellii Chromosome 9');
print<<END_HEREDOC;

  <img alt="" src="/documents/maps/pennellii_il/Slide9.PNG" />
END_HEREDOC
$page->footer();
