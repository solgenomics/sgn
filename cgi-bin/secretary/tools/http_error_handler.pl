#!/usr/bin/perl
use strict;
use CXGN::Page::Secretary;
use CXGN::VHost;

my $page=CXGN::Page::Secretary->new("Secretary","Chris");
$page->client_redirect('../index.pl?error404=1');
