#!/usr/bin/perl

=head1

remove_whitespace_from_names.pl - Find any stock, synonym, project, or location that is saved with leading or trailing whitespace. If opt s, update the names with the whitespace removed.

=head1 SYNOPSIS

    remove_whitespace_from_names.pl -H localhost -D cxgn -s

=head1 COMMAND-LINE OPTIONS
  ARGUMENTS
  -H localhost
  -D database
  -s save changes

=head1 DESCRIPTION


=head1 AUTHOR

Bryan Ellerbrock bje24@cornell.edu

=cut

use strict;

use Getopt::Std;
use Data::Dumper;
use Carp qw /croak/ ;
use Pod::Usage;
use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;
use SGN::Model::Cvterm;

our ($opt_H, $opt_D, $opt_s);

getopts('H:D:s');

if (!$opt_H || !$opt_D) {
    pod2usage(-verbose => 2, -message => "Must provide options -H and -D\n");
}

my $dbhost = $opt_H;
my $dbname = $opt_D;

my $dbh = CXGN::DB::InsertDBH->new({
	dbhost=>$dbhost,
	dbname=>$dbname,
	dbargs => {AutoCommit => 1, RaiseError => 1}
});

my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );
$dbh->do('SET search_path TO public,sgn');

print STDERR "Found the following entries with leading or trailing whitespace:\n";
print STDERR "Name:\tType:\n";

#stocks
my $stock_query = 'SELECT format( '"\%s"', uniquename ) AS name, cvterm.name AS type FROM stock JOIN cvterm ON(type_id = cvterm_id) WHERE trim(uniquename) != uniquename';
my $stocks = $dbh->prepare($stock_query);
$stocks->execute();

while (my ($name, $type) = $stocks->fetchrow_array()) {
    print STDERR $name . "\t" . $type ."\n";
}

#synonyms
my $synonym_query = 'SELECT format( '"\%s"', value ) AS name, cvterm.name AS type FROM stockprop JOIN cvterm ON(type_id = cvterm_id) WHERE cvterm.name = 'stock_synonym' AND trim(value) != value';
my $synonyms = $dbh->prepare($synonym_query);
$synonyms->execute();

while (my ($name, $type) = $synonyms->fetchrow_array()) {
    print STDERR $name . "\t" . $type ."\n";
}

#projects
my $project_query = 'SELECT format( '"\%s"', name ) AS name FROM project WHERE trim(name) != name';
my $projects = $dbh->prepare($project_query);
$projects->execute();

while (my $name = $projects->fetchrow_array()) {
    print STDERR $name . "\tproject\n";
}

#locations
my $location_query = 'SELECT format( '"\%s"', description) AS name FROM nd_geolocation WHERE trim(description) != description';
my $locations = $dbh->prepare($location_query);
$locations->execute();

while (my $name = $locations->fetchrow_array()) {
    print STDERR $name . "\tlocation\n";
}

    if ($opt_s){
        
        my $stock_query = 'UPDATE stock SET uniquename = trim(uniquename) WHERE trim(uniquename) != uniquename';
        my $stocks = $dbh->prepare($stock_query);
        $stocks->execute();
        
        my $synonym_query = 'UPDATE stockprop SET value = trim(value) WHERE type_id = (SELECT cvterm_id from cvterm where cvterm.name = 'stock_synonym') AND trim(value) != value';
        my $synonyms = $dbh->prepare($synonym_query);
        $synonyms->execute();
        
        my $project_query = 'UPDATE project SET name = trim(name) WHERE trim(name) != name';
        my $projects = $dbh->prepare($project_query);
        $projects->execute();
        
        my $location_query = 'UPDATE nd_geolocation SET description = trim(description) WHERE trim(description) != description';
        my $locations = $dbh->prepare($location_query);
        $locations->execute();

    }
}

close($F);
