
use strict;

use CXGN::Page;

my $page = CXGN::Page->new();

my $marker_id = $page->get_arguments("marker_id");

$c->forward_to_mason_view('/markers/index.mas', marker_id=>"marker_id");
