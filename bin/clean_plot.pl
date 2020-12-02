#!/usr/bin/perl

=head1 NAME

clean_plot.pl - delete plots not linked to a project

=head1 DESCRIPTION

perl clean_plots.pl -H [host] -D [dbname] -t (for testing)


=head1 AUTHOR

chris simoes <ccs263@cornell.edu>

=cut

use strict;
use warnings;
use Getopt::Std;
use DBI;
use Try::Tiny;
use DBIx::Class;
use Bio::Chado::Schema;

our ($opt_H, $opt_D, $opt_t);
getopts('H:D:t');

# my $file = shift;

print "Password for $opt_H / $opt_D: \n";
my $pw = <>;
chomp($pw);


my $schema = Bio::Chado::Schema->connect($opt_H, "postgres", $pw);

print STDERR "Connecting to database...\n";
my $dsn = 'dbi:Pg:database='.$opt_D.";host=".$opt_H.";port=5432";

my $dbh = DBI->connect($dsn, "postgres", $pw);

print STDERR "Connecting to DBI schema...\n";
    

my @plot_ids = ();

my $sql = "BEGIN; select uniquename, stock_id from stock left join nd_experiment_stock using (stock_id) where nd_experiment_id  is null and stock.type_id = 76393;";
my $sth = $dbh->prepare($sql);
$sth->execute();
while (my @row = $sth->fetchrow_array) {
	push @plot_ids, $row[1];
	print "Plot id is: $row[1]\n";
}

foreach my $plot_id (@plot_ids) { 
	my $sql2 = "delete from stock where stock_id in (select stock_id from stock left join nd_experiment_stock using (stock_id) where stock_id = ? and stock.type_id = 76393);";
	my $sth2 = $dbh->prepare($sql2);
	try { $schema->txn_do($sth2->execute($plot_id)); }  catch { print STDOUT $_ ; next () ; } ;
	print("deleting plot id $plot_id ...");
	
}


print "done\n";
