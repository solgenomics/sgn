use CatalystX::GlobalContext qw( $c );


use strict;

$c->forward_to_mason_view('/about/outreach/index.mas');


# use CXGN::Page;
# use CXGN::Page::FormattingHelpers qw/ blue_section_html page_title_html /;

# my $page=CXGN::Page->new('SGN Educational Outreach','Joyce van Eck');

# $page->header('SGN Educational Outreach');

# my $title = page_title_html("SOL Outreach Activities and Materials");

# my $overview = blue_section_html("Overview", <<OVERVIEW);

# LINKS

# print $title;
# print $overview;
# print $activities;
# print $links;

# $page->footer();
