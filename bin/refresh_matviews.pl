#!/usr/bin/perl

=head1 NAME

refresh_matviews.pl - run PL/pgSQL functions to do a basic or concurrent refresh of all database materialized views

=head1 DESCRIPTION

refresh_matviews.pl -D [database handle]  -c [ to run concurrent refresh ]

Options:

 -D the database handle
 -c flag; if present, run concurrent refresh

All materialized views that are included in the refresh function will be refreshed
If -c is used, the refresh will be done concurrently, a process that takes longer than a standard refresh but that is completed without locking the views.

=head1 AUTHOR

Bryan Ellerbrock <bje24@cornell.edu>

=cut

use strict;
use warnings;

use Getopt::Std;
use Try::Tiny;
use CXGN::Tools::Run;
use CXGN::DB::InsertDBH;
use CXGN::DB::Connection;

our ($opt_D, $opt_c);
getopts('Dc');

my $dbh = $opt_D;

sub print_help {
  print STDERR "A script to refresh materialized views\nUsage: refresh_matviews.pl -D [database handle]\n-w\trun refresh concurrently (optional)\n";
}


if (!$opt_D) {
  print_help();
  die("Exiting: Database handle option missing\n");
}

  my $q = "UPDATE public.matviews SET currently_refreshing=?";
  my $state = 'TRUE';
  my $h = $self->dbh->prepare($q);
  $h->execute($state);

  print STDERR "Refreshing materialized views . . ." . localtime() . "\n";

  my $refresh = 'SELECT refresh_materialized_views()';
  my $h = $self->dbh->prepare($refresh);
  my $status = $h->execute();

  print STDERR "Materialized views refreshed! Status: $status" . localtime() . "\n";

  $q = "UPDATE public.matviews SET currently_refreshing=?";
  $state = 'FALSE';
  my $h = $self->dbh->prepare($q);
  $h->execute($state);

  print STDERR "Done, exiting refresh_matviews.pl \n";
