use strict;
use warnings;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/multilevel_mode_selector_html/;

my $page = CXGN::Page->new('Multilevel Selector Test Page','Robert Buels');


$page->header(('Multilevel Selector Test Page') x 2);

my ($ml_html,@selected_modes) =  multilevel_mode_selector_html(<<EOC,$page->get_encoded_arguments('mode'));
<monkey>
  text Monkey
</monkey>
<dog>
  text Dog
</dog>
<cat>
  text Cat
</cat>
EOC

$page->footer;
