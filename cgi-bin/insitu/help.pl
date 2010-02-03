
use strict;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw / page_title_html blue_section_html /;
use CXGN::Insitu::Toolbar;

my $page = CXGN::Page->new();

$page->header();

print page_title_html( qq{ <a href="/insitu/">Insitu</a> Database } );

display_toolbar("help");

$page->footer();
