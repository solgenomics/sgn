#!/usr/bin/perl

=head1 NAME

  unigene_build.pl
  Controller to show the web_page for unigene build using MASON.

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


use CXGN::MasonFactory;
use CXGN::Page;


use CXGN::DB::Connection;
use CXGN::DB::DBICFactory;

use SGN::Schema;
use CXGN::Transcript::Unigene;

## Create mason object

my $m = CXGN::MasonFactory->new();

## Use of CXGN::Page to take the arguments from the URL

my $page = CXGN::Page->new();

my %args = $page->get_all_encoded_arguments();

## It create a MASON path and transmite it to let the dependient MASON
## code access to the MASON components (using the only mason dir give
## problems)

## Create the gem schema object (used to get data from expression to samples)



## There are one way to access to the page using id as integer. If use
## other combinations give an error message

my $psqlv = `psql --version`;
chomp($psqlv);

my @schema_list = ('sgn');
if ($psqlv =~ /8\.1/) {
    push @schema_list, 'tsearch2';
}

my $schema = CXGN::DB::DBICFactory->open_schema( 'SGN::Schema', search_path => \@schema_list, );

my @schema_list2 = ('public');
if ($psqlv =~ /8\.1/) {
    push @schema_list2, 'tsearch2';
}

my $bcs = CXGN::DB::DBICFactory->open_schema( 'Bio::Chado::Schema', search_path => \@schema_list2, );

my $dbh = CXGN::DB::Connection->new();

## Get unigene build object

my $unigene_build = CXGN::Transcript::UnigeneBuild->new($dbh);
if (exists $args{'id'} && $args{'id'} =~ m/^\d+$/) {
    $unigene_build = CXGN::Transcript::UnigeneBuild->new($dbh, $args{'id'});
}


## There are one way to access to the page using id as integer. If use other combinations give an error message 

if (defined $unigene_build) {
    $m->exec('/transcript/unigene_build_detail.mas',
	     bcs           => $bcs,
	     schema        => $schema,
             unigene_build => $unigene_build );
} 
else {
    $m->exec('/transcript/transcript_page_error.mas', 
	     object => $unigene_build );
}
