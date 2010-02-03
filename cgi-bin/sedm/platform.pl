#!/usr/bin/perl

=head1 NAME

  platform.pl
  Code to show the web_page for platform using MASON.

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


my $m = CXGN::MasonFactory->new;

## Use of CXGN::Page to take the arguments from the URL

my $page = CXGN::Page->new();
my %args = $page->get_all_encoded_arguments();

## There are two ways to access to the page, using id=int or name=something. If use other combinations give an error message 

if (exists $args{'id'} && defined $args{'id'} && $args{'id'} =~ m/^\d+$/) {
    $m->exec( '/sedm/platform_detail.mas',
              id => $args{'id'},
            );
} elsif (exists $args{'name'} && defined $args{'name'}) {
    $m->exec( '/sedm/platform_detail.mas',
              name => $args{'name'},
            );
} else {
    $m->exec( '/sedm/sedm_page_error.mas',
              object => 'platform',
            );
}
