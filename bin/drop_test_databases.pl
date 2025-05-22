
=head1 NAME

drop_test_databases.pl - a script to remove test databases from the postgres instance

=head1 SYNOPSYS

perl drop_test_databases.pl -h dbhost

=head1 DESCRIPTION

When using t/test_fixture.pl with the --nocleanup option, a lot of test databases (named test_db_* ) can accumulate in the postgres instance. 

drop_dest_databases.pl will remove all databases whose names start with test_db_. 

It will ask for a postgres username (default postgres) and a password and then proceed to deletion immediately.

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

April 14, 2020

=cut


use strict;
use Getopt::Std;

use CXGN::DB::InsertDBH;

our($opt_h);

getopts('h:');

print STDERR "Deleting test databases (test_db_%) from $opt_h...\n";
my $dbh = CXGN::DB::InsertDBH->new( { dbhost => $opt_h, dbname => 'postgres', dbargs => { AutoCommit => 1 } } );

    
my $q = "SELECT datname FROM pg_database WHERE datname ilike 'test_db_%'";

my $h = $dbh->prepare($q);

$h->execute();

my @dbs;
while (my ($dbname) = $h->fetchrow_array()) {
    push @dbs, $dbname;
}

foreach my $dbname (@dbs) {  
   print STDERR "Dropping database $dbname...\n";
    my $d = "DROP DATABASE $dbname";
    my $h = $dbh->prepare($d);
    $h->execute();
}

print STDERR "Done.\n";


