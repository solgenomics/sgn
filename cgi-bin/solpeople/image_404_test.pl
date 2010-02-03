#!/usr/bin/perl -w
use strict;
use CXGN::Page;
my $page=CXGN::Page->new("image_404_test.pl","john binns");
$page->header();
print"<img src=\"image_that_doesnt_exist.png\" alt=\"\" />";
$page->footer();
