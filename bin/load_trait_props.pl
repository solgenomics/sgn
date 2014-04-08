#!/usr/bin/env perl

=head1

load_trait_props.pl

=head1 SYNOPSIS

    $load_trait_props.pl -H [dbhost] -D [dbname] -I [input file] -o [ontology] -W

=head1 COMMAND-LINE OPTIONS

 -H  host name
 -D  database name
 -w  overwrite
 -t  Test run . Rolling back at the end.

=head2 DESCRIPTION


=head2 AUTHOR

Jeremy D. Edwards (jde22@cornell.edu)

April 2014

=head2 TODO

Add support for other spreadsheet formats

=cut

use strict;
use warnings;

use lib 'lib';
use Getopt::Std;
use Bio::Chado::Schema;
use CXGN::Tools::File::Spreadsheet;
use CXGN::DB::InsertDBH;
use CXGN::DB::Connection;
use CXGN::Fieldbook::TraitProps;

our ($opt_H, $opt_D, $opt_I, $opt_o, $opt_w, $opt_t);

getopts('H:D:I:o:wt');

sub print_help {
  print STDERR "A script to load trait properties\nUsage: load_trait_props.pl -D [database name] -H [database host, e.g., localhost] -I [input file] -o [ontology namespace, e.g., CO] -w\n\t-w\toverwrite existing trait properties if they exist (optional)\n\t-t\ttest run.  roll back at the end\n";
}

if (!$opt_D || !$opt_H || !$opt_I || !$opt_o) {
  print_help();
  die("Exiting: options missing\n");
}

my $dbh = CXGN::DB::InsertDBH
  ->new({
	 dbname => $opt_D,
	 dbhost => $opt_H,
	 dbargs => {AutoCommit => 1,
		    RaiseError => 1},
	});

my $overwrite_existing_props = 0;

if ($opt_w){
  $overwrite_existing_props = 1;
}

my $is_test_run = 0;

if ($opt_t){
  $is_test_run = 1;
}

my $chado_schema = Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );

my @trait_props_data;

my %trait_props;

$trait_props{'trait_name'}='dry yield';
$trait_props{'trait_details'}='Dry weight of harvested roots derived by multiplying fresh storage root yield by dry matter content expressed in tons per hectares.';
$trait_props{'trait_minimum'}=0;
push @trait_props_data, \%trait_props;

my $db_name = $opt_o;

my $trait_props = CXGN::Fieldbook::TraitProps->new({ chado_schema => $chado_schema, db_name => $db_name, trait_names_and_props => \@trait_props_data, overwrite => $overwrite_existing_props, is_test_run => $is_test_run});

print STDERR "Validating data...\t";
my $validate=$trait_props->validate();

if (!$validate) {
  die("input data is not valid\n");
} else {
  print STDERR "input data is valid\n";
}

print STDERR "Storing data...\t\t";
my $store = $trait_props->store();

if (!$store){
  if (!$is_test_run) {
    die("\n\nerror storing data\n");
  }
} else {
  print STDERR "successfully stored data\n";
}



