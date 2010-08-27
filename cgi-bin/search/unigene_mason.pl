#!/usr/bin/perl

=head1 NAME

  unigene_mason.pl
  Code to show the web_page for unigene using MASON.

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

use CXGN::Page;

## Use of CXGN::Page to take the arguments from the URL

my $page = CXGN::Page->new();
my %args = $page->get_all_encoded_arguments();

## There are two ways to access to the page, using id as integer or as
## SGN-U+int. If use other combinations give an error message

my $m = CXGN::MasonFactory->new;

if (exists $args{'id'} && defined $args{'id'}) {
    $m->exec( '/transcript/unigene_detail.mas',
              id          => $args{'id'},
              highlight   => $args{'highlight'},
              force_image => $args{'force_image'}
            );
} else {
    $m->exec( '/transcript/transcript_page_error.mas',
              object => 'unigene'
            );
}
