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
use Try::Tiny;

our ($opt_H, $opt_D, $opt_U, $opt_P);
getopts('H:D:U:P:');

print STDERR "Connecting to database...\n";
my $dsn = 'dbi:Pg:database='.$opt_D.";host=".$opt_H.";port=5432";
my $dbh = DBI->connect($dsn, $opt_U, $opt_P, { RaiseError => 1, AutoCommit=>1 });

my $lock_acquired = 0;

try {
    # Prevent concurrent runs
    my ($got_lock) = $dbh->selectrow_array("SELECT pg_try_advisory_lock(12345)");
    die "Another instance is already running\n" unless $got_lock;
    $lock_acquired = 1;
    
    print STDERR "Refreshing materialized_markerview . . . " . localtime() . "\n";

    my $q = "SELECT public.create_materialized_markerview(true);";
    my $h = $dbh->prepare($q);
    $h->execute();
    
    print STDERR "materialized_markerview refreshed! " . localtime() . "\n";
}
catch {
    print STDERR "Refresh failed: $_";
}
finally {
    $dbh->selectrow_array("SELECT pg_advisory_unlock(12345)") if $lock_acquired;
    $dbh->disconnect();
};

print STDERR "Done, exiting refresh_materialized_markerview.pl \n";
