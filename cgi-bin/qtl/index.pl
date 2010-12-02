use CatalystX::GlobalContext qw( $c );
use strict;
use CXGN::Page;

my $page = CXGN::Page->new("SGN", "Isaak");

my $redir = $page->client_redirect("../search/direct_search.pl?search=qtl");

$c->forward_to_mason_view('/qtl/index.mas', $redir);
