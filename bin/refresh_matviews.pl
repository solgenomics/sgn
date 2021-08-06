#!/usr/bin/perl

=head1 NAME

refresh_matviews.pl - run PL/pgSQL functions to do a basic or concurrent refresh of all database materialized views

=head1 DESCRIPTION

refresh_matviews.pl -H [database handle] -D [database name]  -c [to run concurrent refresh] -m [materialized view select]

Options:

 -H the database host
 -D the database name
 -U username
 -P password
 -c flag; if present, run concurrent refresh
 -m materialized view select. can be either 'fullview' or 'stockprop' or 'phenotypes'
 -t test mode

All materialized views that are included in the refresh function will be refreshed
If -c is used, the refresh will be done concurrently, a process that takes longer than a standard refresh but that is completed without locking the views.

=head1 AUTHOR

Bryan Ellerbrock <bje24@cornell.edu>
Naama Menda <nm249@cornell.edu>

=cut

use strict;
use warnings;
use DBI;
use Try::Tiny;
use Getopt::Long;

my ( $dbhost, $dbname, $username, $password, $mode, $concurrent, $test);
GetOptions(
    'm=s'        => \$mode,
    'c'          => \$concurrent,
    'P=s'        => \$password,
    'U=s'        => \$username,
    't'          => \$test,
    'dbname|D=s' => \$dbname,
    'dbhost|H=s' => \$dbhost,
);


unless ($mode =~ m/^(fullview|stockprop|phenotypes)$/ ) { die "Option -m must be fullview, stockprop, or phenotypes. -m  = $mode\n"; }

print STDERR "Connecting to database...\n";
my $dsn = 'dbi:Pg:database='.$dbname.";host=".$dbhost.";port=5432";
my $dbh = DBI->connect($dsn, $username, $password, { RaiseError => 1, AutoCommit=>0 });

my $cur_refreshing_q =  "UPDATE public.matviews SET currently_refreshing=?";
if ($mode eq 'stockprop'){
    $cur_refreshing_q .= " WHERE mv_name = 'materialized_stockprop'";
}
if ($mode eq 'phenotypes') {
    $cur_refreshing_q .= " WHERE mv_name = 'materialized_phenotype_jsonb_table'";
}

#set TRUE before the transaction begins
my $state = 'TRUE';
print STDERR "*Setting currently_refreshing = TRUE\n";
my $cur_refreshing_h = $dbh->prepare($cur_refreshing_q);
$cur_refreshing_h->execute($state);
$dbh->commit();

try {
    print STDERR "Refreshing materialized views . . ." . localtime() . "\n";
    my @mv_names = ();

    if ($mode eq 'fullview') {
        @mv_names = ('materialized_phenoview','materialized_genoview');
    }
    if ($mode eq 'stockprop'){
       @mv_names = ('materialized_stockprop');
    }
    if ($mode eq 'phenotypes') {
       @mv_names = ("materialized_phenoview", "materialized_phenotype_jsonb_table");
    }

    my $status = refresh_mvs($dbh, \@mv_names, $concurrent);

    #rollback if running in test mode
    if ($test) { die ; }
}
catch {
    warn "Refresh failed: @_";
    if ($test ) { print STDERR "TEST MODE\n" ; }
    $dbh->rollback()
}
finally {
    if (@_) {
        print "The try block died. Rolling back.\n";
    } else {
        print STDERR "COMMITTING\n";
        $dbh->commit();
    }
    #always set the refreshing status to FALSE at the end
    $state = 'FALSE';
    my $done_h = $dbh->prepare($cur_refreshing_q);
    print STDERR "*Setting currently_refreshing = FALSE \n";
    $done_h->execute($state);
    $dbh->commit();
};

sub refresh_mvs {
    my $dbh = shift;
    my $mv_names_ref = shift;
    $concurrent = shift;
    my $start_q = "UPDATE matviews SET refresh_start = statement_timestamp() where mv_name = ?";
    my $end_q =   "UPDATE matviews SET  last_refresh = statement_timestamp() where mv_name = ? ";
    my $refresh_q = "REFRESH MATERIALIZED VIEW ";
    if ($concurrent) { $refresh_q .= " CONCURRENTLY "; }
    my $status;

    foreach my $name ( @$mv_names_ref ) {
        print STDERR "**Refreshing view $name ". localtime() . " \n";
        my $start_h = $dbh->prepare($start_q);
        $start_h->execute($name);
        print STDERR "**QUERY = " . $refresh_q . $name . "\n";
        my $refresh_h = $dbh->prepare($refresh_q . $name) ;
        $status = $refresh_h->execute();

        print STDERR "Materialized view $name refreshed! Status: $status " . localtime() . "\n\n";

        my $end_h = $dbh->prepare($end_q);
        $end_h->execute($name);
    }
    return $status;
}
