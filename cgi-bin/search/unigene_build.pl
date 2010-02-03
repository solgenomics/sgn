#!/usr/bin/perl

=head1 NAME

  unigene_build.pl
  Code to show the web_page for unigene build using MASON.

=cut

=head1 SYNOPSIS

 
=head1 DESCRIPTION

  This is the script to show the web_page using MASON

=cut

=head1 AUTHORS

 Aureliano Bombarely Gomez
 (ab782@cornell.edu)

=cut


use strict;
use warnings;

use CXGN::VHost;
use CXGN::Page;

use CXGN::MasonFactory;

## Use of CXGN::Page to take the arguments from the URL

my $page = CXGN::Page->new();
my %args = $page->get_all_encoded_arguments();

## It create a MASON path and transmite it to let the dependient MASON
## code access to the MASON components (using the only mason dir give
## problems)

## There are one way to access to the page using id as integer. If use
## other combinations give an error message

my $m = CXGN::MasonFactory->new;

if (exists $args{'id'} && defined $args{'id'}) {
    $m->exec( '/transcript/unigene_build_detail.mas',
              path => $masonpath,
              id   => $args{'id'}
            );
} else {
    $m->exec( '/transcript/transcript_page_error.mas',
              path   => $masonpath,
              object => 'unigene build'
            );
}
