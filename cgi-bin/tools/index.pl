use strict;
use CXGN::Page;
use CXGN::Page::Toolbar::SGN;
my $page=CXGN::Page->new("Tools","john");
$page->header();
my $tb=CXGN::Page::Toolbar::SGN->new();
print $tb->index_page('tools');
$page->footer();
