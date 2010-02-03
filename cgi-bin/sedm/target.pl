#!/usr/bin/perl

=head1 NAME

  target.pl
  Code to show the web_page for target information using MASON.

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


## Use of CXGN::Page to take the arguments from the URL

my $page = CXGN::Page->new();
my %args = $page->get_all_encoded_arguments();

## It get the hostname to create the right links in the MASON pages

my $hostname = $page->get_hostname();

my $m = CXGN::MasonFactory->new;

## There are two ways to access to the page, using id=int or
## name=something. If use other combinations give an error message

if (exists $args{'id'} && defined $args{'id'} && $args{'id'} =~ m/^\d+$/) {
    $m->exec( '/sedm/target_detail.mas',
              hostname => $hostname,
              id => $args{'id'},
            );
} elsif (exists $args{'name'} && defined $args{'name'}) {
    $m->exec( '/sedm/target_detail.mas',
              hostname => $hostname,
              name => $args{'name'},
            );
} else {
    $m->exec( '/sedm/sedm_page_error.mas',
              hostname => $hostname,
              object => 'target',
            );
}


