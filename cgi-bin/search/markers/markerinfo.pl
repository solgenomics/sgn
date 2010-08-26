use CatalystX::GlobalContext qw( $c );

use strict;

use CXGN::Page;
use CXGN::DB::Connection;

my $page = CXGN::Page->new();
my $dbh = CXGN::DB::Connection->new();

my $marker_id = $page->get_arguments("marker_id");

$c->forward_to_mason_view('/markers/index.mas', marker_id=>$marker_id, dbh=>$dbh);
