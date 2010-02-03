use strict;
use CXGN::Page;
my $page=CXGN::Page->new('chr8.html','html2pl converter');
$page->header('L. Pennellii Chromosome 8');
print<<END_HEREDOC;

  <img alt="" src="/documents/maps/pennellii_il/Slide8.PNG" />
END_HEREDOC
$page->footer();
