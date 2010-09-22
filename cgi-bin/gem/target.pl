#!/usr/bin/perl

=head1 NAME

  target.pl
  Controller to show the web_page for target information using MASON.

=cut

=head1 SYNOPSIS

 
=head1 DESCRIPTION

  This is a controller script to show the web_page using MASON

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
use CXGN::GEM::Schema;
use CXGN::GEM::Target;

## Call the mason object

my $m = CXGN::MasonFactory->new();


## Create the schema object for gem (and gem related searches)

my $psqlv = `psql --version`;
chomp($psqlv);

my @schema_list = ('gem','biosource','metadata','public');
if ($psqlv =~ /8\.1/) {
    push @schema_list, 'tsearch2';
}

my $schema = CXGN::DB::DBICFactory->open_schema( 'CXGN::GEM::Schema', search_path => \@schema_list, );


## Use of CXGN::Page to take the arguments from the URL

my %args = CXGN::Page->new()
                     ->get_all_encoded_arguments();


## Create the target object (by default it will create an empty object)

my $target = CXGN::GEM::Target->new($schema);

if (exists $args{'id'} && $args{'id'} =~ m/^\d+$/) {
   $target = CXGN::GEM::Target->new($schema, $args{'id'});
} elsif (exists $args{'name'}) {
   $target = CXGN::GEM::Target->new_by_name($schema, $args{'name'});
}


## There are two ways to access to the page, using id=int or name=something. If use other combinations give an error message 

if (defined $target->get_target_id or defined $target->get_target_name ) {
    $m->exec('/gem/target_detail.mas',
             schema => $schema,
             target => $target );
} else {
    $m->exec('/gem/gem_page_error.mas', 
             schema => $schema, 
             object => $target );
}



