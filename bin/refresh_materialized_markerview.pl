#!/usr/bin/perl

=head1 NAME

refresh_materialized_markerview.pl - run the create_materialized_markerview postgres function that rebuilds the unified marker materialized view

=head1 DESCRIPTION

refresh_materialized_markerview.pl -H [database host] -D [database name] -U [database username] -P [database password]

Options:

 -H the database host
 -D the database name
 -U the database username
 -P the database password

This script will rebuild the materialized_markerview table and refresh its contents

=head1 AUTHOR

Bryan Ellerbrock <bje24@cornell.edu>
David Waring <djw64@cornell.edu> - modified from refresh_matviews.pl script

=cut

use strict;
use warnings;
use Getopt::Std;
use DBI;

our ($opt_H, $opt_D, $opt_U, $opt_P);
getopts('H:D:U:P:');

print STDERR "Connecting to database...\n";
my $dsn = 'dbi:Pg:database='.$opt_D.";host=".$opt_H.";port=5432";
my $dbh = DBI->connect($dsn, $opt_U, $opt_P);

eval {
    print STDERR "Refreshing materialized_markerview . . . " . localtime() . "\n";

    my $q = "SELECT public.create_materialized_markerview(true);";
    my $h = $dbh->prepare($q);
    $h->execute();
    
    print STDERR "materialized_markerview refreshed! " . localtime() . "\n";
};

if ($@) {
  $dbh->rollback();
  print STDERR $@;
} else {
  print STDERR "Done, exiting refresh_matviews.pl \n";
}
