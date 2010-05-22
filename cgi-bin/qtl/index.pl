use strict;
use CXGN::Page;

my $page = CXGN::Page->new("SGN", "Isaak");

my $redir = $page->client_redirect("../search/direct_search.pl?search=cvterm_name");

$c->forward_to_mason_view('/qtl/index.mas', $redir);
