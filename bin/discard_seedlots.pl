#!/usr/bin/perl

=head1

discard_seedlots.pl - a script to load stock data

=head1 SYNOPSIS

discard_seedlots.pl -H [dbhost] -D [dbname] [-t] [-s species name ] [-p stock population name]

=head1 COMMAND-LINE OPTIONS

 -H  host name
 -D  database name
 -i infile
 -u username for associating the new stocks 
 -s species name - must be in the database. Can also be read from the input file 
 -p population name - will create a new stock of type 'population' if doesn't exist. 
 -t  Test run . Rolling back at the end.

=head1 DESCRIPTION

Updated script for loading and adding stock names and synonyms.
The owners of the stock accession are not stored in stockprop, but in phenome.stock_owner

All other stockproperties can be given as additional columns and will be loaded automatically; 
if the corresponding stock_property does not exist in the database it will be added.

File format for infile (tab delimited):

accession genus species_name population_name synonyms other_stock_props ...

Multiple synonyms can be specified, separated by the | symbol

=head1 AUTHORS

Naama Menda (nm249@cornell.edu) - April 2013
Lukas Mueller (lam87@cornell.edu) - minor edits, November 2022

=cut


use strict;
use warnings;
use Getopt::Std;
use CXGN::Tools::File::Spreadsheet;

use CXGN::Phenome::Schema;
use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;
use Carp qw /croak/ ;

use CXGN::Chado::Dbxref;
use CXGN::Chado::Phenotype;
use CXGN::People::Person;
use Try::Tiny;
use SGN::Model::Cvterm;
use Getopt::Long;

my ( $dbhost, $dbname, $file, $username, $test );
GetOptions(
    'i=s'        => \$file,
    'u=s'        => \$username,
    't'          => \$test,
    'dbname|D=s' => \$dbname,
    'dbhost|H=s' => \$dbhost,
);


my $dbh = CXGN::DB::InsertDBH->new( { dbhost=>$dbhost,
				      dbname=>$dbname,
				      dbargs => {AutoCommit => 1,
						 RaiseError => 1}
				    }
    );
my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } ,  { on_connect_do => ['SET search_path TO  public;'] }
					  );
my $phenome_schema= CXGN::Phenome::Schema->connect( sub { $dbh->get_actual_dbh } , { on_connect_do => ['set search_path to public,phenome;'] }  );

# new spreadsheet
#
my $spreadsheet=CXGN::Tools::File::Spreadsheet->new($file);


# parse first the file with the clone names and synonyms. Load into stock,
# and stockprop population for grouping the clones
#
my $sp_person_id = CXGN::People::Person->get_person_by_username($dbh, $username); 
die "Need to have a user pre-loaded in the database! " if !$sp_person_id;

my $stock_rs = $schema->resultset("Stock::Stock");

my $stock_property_cv_id = $schema->resultset("Cv::Cv")->find( { name => 'stock_property' })->cv_id();

print STDERR "Stock property CV ID = $stock_property_cv_id\n";


# the cvterm for 'seedlot'
#
my $seedlot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();

open(my $F, "<", $file) || die "Can't open file $file\n";

# accession genus species population_name synonyms
#
my $coderef= sub  {
    while (<$F>) {
	chomp;
	my $seedlot = $_;
	# remove spaces from seedlot name 
	$seedlot=~s/\s+//g;

	my $row = $schema->resultset("Stock::Stock")->find( { uniquename => $seedlot, type_id => $seedlot_type_id });

	if ($row) { 
	    my $seedlot_obj = CXGN::Stock::Seedlot->new( { schema => $schema, seedlot_id => $row->stock_id() });
	}
	else {
	    print STDERR "Seedlot $seedlot does not exist in the database\n";
	}
    }
	
    if ($test) {
        die "TEST RUN! rolling back\n";
    }
};


try {
    $schema->txn_do($coderef);
    if (!$test) { print "Transaction succeeded! Commiting stocks and their properties! \n\n"; }
} catch {
    die "An error occured! Rolling back  and reseting database sequences!" . $_ . "\n";
};
