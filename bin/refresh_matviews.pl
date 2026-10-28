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

unless ($mode =~ m/^(fullview|stockprop|phenotypes|all_but_genoview)$/ ) { die "Option -m must be fullview, stockprop, phenotypes, or all_but_genoview. -m  = $mode\n"; }

print STDERR "Connecting to database...\n";
my $dsn = 'dbi:Pg:database='.$dbname.";host=".$dbhost.";port=5432";
my $dbh = DBI->connect($dsn, $username, $password, { RaiseError => 1, AutoCommit=>0 });
my $auto_dbh = DBI->connect($dsn, $username, $password, { RaiseError => 1, AutoCommit=>1 });

my $cur_refreshing_q =  "UPDATE public.matviews SET currently_refreshing=?";
if ($mode eq 'stockprop'){
    $cur_refreshing_q .= " WHERE mv_name = 'materialized_stockprop'";
}
if ($mode eq 'phenotypes') {
    $cur_refreshing_q .= " WHERE mv_name = 'materialized_phenotype_jsonb_table' or mv_name = 'materialized_phenoview' ";
}
if ($mode eq 'all_but_genoview') {
    $cur_refreshing_q .= " WHERE mv_name = 'materialized_stockprop' or mv_name = 'materialized_phenoview' or mv_name= 'materialized_phenotype_jsonb_table' ";
}
    
#set TRUE before the transaction begins
my $refresh_failed = 0;
my $lock_acquired = 0;
my $status;

try {
    my ($got_lock) = $dbh->selectrow_array("SELECT pg_try_advisory_lock(67895)");
    print STDERR "Another instance is already running\n" unless $got_lock;
    die "Another instance is already running\n" unless $got_lock;
    $lock_acquired = 1;

    print STDERR "*Setting currently_refreshing = TRUE\n";
    my $cur_refreshing_h = $dbh->prepare($cur_refreshing_q);
    $cur_refreshing_h->execute('TRUE');
    $dbh->commit();

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
    if ($mode eq 'all_but_genoview') {
       @mv_names = ("materialized_stockprop", "materialized_phenoview", "materialized_phenotype_jsonb_table");
    }
    if ($test) {
	$status = test_mvs($dbh, \@mv_names);
	print STDERR "TEST MODE - rolling back refresh work.\n";
        $dbh->rollback();
    } else {
        $status = refresh_mvs($dbh, $auto_dbh, \@mv_names, $concurrent);
    }
}
catch {
    $refresh_failed = 1;
    warn "Refresh failed: $_";
    if ($test) { print STDERR "TEST MODE - rolling back.\n"; }
    $dbh->rollback();
}
finally {
    if ($lock_acquired) {
        my $done_h = $dbh->prepare($cur_refreshing_q);
        print STDERR "*Setting currently_refreshing = FALSE\n";
        $done_h->execute('FALSE');
        $dbh->commit();
        $dbh->selectrow_array("SELECT pg_advisory_unlock(67895)");
    }
    if ($refresh_failed) {
	print STDERR "Refresh did not complete cleanly.\n";
    } else {
        print STDERR "COMMITTING\n";
    }
};

sub refresh_mvs {
    my $dbh = shift;
    my $auto_dbh = shift;
    my $mv_names_ref = shift;
    my $concurrent = shift;
    my $end_h;
    my $start_q = "UPDATE matviews SET refresh_start = statement_timestamp() where mv_name = ?";
    my $end_q =   "UPDATE matviews SET  last_refresh = statement_timestamp() where mv_name = ? ";
    my $refresh_q = "REFRESH MATERIALIZED VIEW ";
    my $refresh_h;
    if ($concurrent) { $refresh_q .= " CONCURRENTLY "; }
    my $status;

    # increase work_mem to avoid out of space error while refreshing
    # $auto_dbh->prepare("SET work_mem = '256MB'")->execute();
    foreach my $name ( @$mv_names_ref ) {
        print STDERR "**Refreshing view $name ". localtime() . " \n";
        print STDERR "**QUERY = " . $refresh_q . $name . "\n";
	if ($concurrent) {
	    my $start_h = $dbh->prepare($start_q);
            $start_h->execute($name);
	    $dbh->commit();
	    $refresh_h = $auto_dbh->prepare($refresh_q . $name);
	    $status = $refresh_h->execute();
	    $end_h = $dbh->prepare($end_q);
	    $end_h->execute($name);
	    $dbh->commit();
        } else {
	    my $start_h = $dbh->prepare($start_q);
            $start_h->execute($name);
	    $refresh_h = $auto_dbh->prepare($refresh_q . $name) ;
	    $status = $refresh_h->execute();
	    $end_h = $dbh->prepare($end_q);
	    $end_h->execute($name);
	    $dbh->commit();
	}
        print STDERR "Materialized view $name refreshed! Status: $status " . localtime() . "\n\n";
    }
    return $status;
}

sub test_mvs {
    my $dbh = shift;
    my $mv_names_ref = shift;
    my $end_h;
    my $start_q = "UPDATE matviews SET refresh_start = statement_timestamp() where mv_name = ?";
    my $end_q =   "UPDATE matviews SET  last_refresh = statement_timestamp() where mv_name = ? ";
    my $refresh_q = "REFRESH MATERIALIZED VIEW ";
    my $refresh_h;
    my $status;

    foreach my $name ( @$mv_names_ref ) {
        print STDERR "**Refreshing view $name ". localtime() . " \n";
        print STDERR "**QUERY = " . $refresh_q . $name . "\n";
        my $start_h = $dbh->prepare($start_q);
        $start_h->execute($name);
        $refresh_h = $dbh->prepare($refresh_q . $name) ;
        $status = $refresh_h->execute();
        $end_h = $dbh->prepare($end_q);
        $end_h->execute($name);
        print STDERR "Materialized view $name refreshed! Status: $status " . localtime() . "\n\n";
    }
    return $status;
}

