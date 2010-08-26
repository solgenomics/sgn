#!/usr/bin/perl
use strict;
use warnings;
use CXGN::Page::Secretary;

my $page=CXGN::Page::Secretary->new("Secretary","Chris");
$page->client_redirect('../index.pl?error404=1');
