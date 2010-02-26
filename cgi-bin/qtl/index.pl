use strict;
use CXGN::Page;

my $page = CXGN::Page->new("SGN", "Isaak");

$page->client_redirect("../search/direct_search.pl?search=cvterm_name");
