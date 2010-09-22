#!/usr/bin/perl

=head1 NAME

  experiment.pl
  Controller for experiment page.

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
use CXGN::GEM::Experiment;


my $m = CXGN::MasonFactory->new();

## Create the schema object

my $psqlv = `psql --version`;
chomp($psqlv);

my @schema_list = ('gem', 'biosource', 'metadata', 'public');
if ($psqlv =~ /8\.1/) {
    push @schema_list, 'tsearch2';
}

my $schema = CXGN::DB::DBICFactory->open_schema( 'CXGN::GEM::Schema', search_path => \@schema_list, );

## Also it will create a dbi-connection object ($dbh) for all the methods that do not use schemas
## (as CXGN::People::Person) to not interfiere with them

my $dbh = CXGN::DB::Connection->new();

## Use of CXGN::Page to take the arguments from the URL

my %args = CXGN::Page->new()
                     ->get_all_encoded_arguments();


## Get the experiment object (by default it will create an empty object without any id)

my $experiment = CXGN::GEM::Experiment->new($schema);;
if (exists $args{'id'} && $args{'id'} =~ m/^\d+$/) {
   $experiment = CXGN::GEM::Experiment->new($schema, $args{'id'});
} elsif (exists $args{'name'}) {
   $experiment = CXGN::GEM::Experiment->new_by_name($schema, $args{'name'});
}

my @target_list;
if (defined $experiment->get_experiment_id() ) {
    @target_list = $experiment->get_target_list();
}


## There are two ways to access to the page, using id=int or name=something. If use other combinations give an error message 

if (defined $experiment->get_experiment_id or defined $experiment->get_experiment_name) {
    $m->exec('/gem/experiment_detail.mas',
	     dbh         => $dbh,
             schema      => $schema, 
             experiment  => $experiment, 
             target_list => \@target_list );
} else {
    $m->exec('/gem/gem_page_error.mas', 
             schema => $schema, 
             object => $experiment );
}



