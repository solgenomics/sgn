#!/usr/bin/perl

=head1

discard_seedlots.pl - a script to load stock data

=head1 SYNOPSIS

discard_seedlots.pl -H [dbhost] -D [dbname] [-t] [-s species name ] [-p stock population name] -r discard_reason -d discard_date

=head1 COMMAND-LINE OPTIONS

 -H host name
 -D database name
 -i infile
 -u username associated with the discard action
 -t Test run . Rolling back at the end.

=head1 DESCRIPTION

Updated script for loading and adding stock names and synonyms.
The owners of the stock accession are not stored in stockprop, but in phenome.stock_owner

All other stockproperties can be given as additional columns and will be loaded automatically; 
if the corresponding stock_property does not exist in the database it will be added.

File format for infile: a list of seedlot names, one per line

=head1 AUTHORS

Lukas Mueller (lam87@cornell.edu)

=cut


use strict;
use warnings;
use Getopt::Std;
use CXGN::Tools::File::Spreadsheet;

use CXGN::Phenome::Schema;
use CXGN::Stock::Seedlot;
use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;
use Carp qw /croak/ ;

use CXGN::Chado::Dbxref;
use CXGN::Chado::Phenotype;
use CXGN::People::Person;
use Try::Tiny;
use SGN::Model::Cvterm;
use Getopt::Long;
use Time::localtime;

my ( $dbhost, $dbname, $file, $username, $test, $reason, $date );
GetOptions(
    'i=s'        => \$file,
    'u=s'        => \$username,
    't'          => \$test,
    'dbname|D=s' => \$dbname,
    'dbhost|H=s' => \$dbhost,
    'reason|r=s' => \$reason,
    'date|y=s'   => \$date,
);

$reason = 'no reason given' if ! $reason;
my $tm = localtime();
$date = ($tm->year + 1900)."/".$tm->mon."/".$tm->mday if ! $date;

print STDERR "date is $date, dbname is $dbname\n";

my $dbh = CXGN::DB::InsertDBH->new( { dbhost=>$dbhost,
				      dbname=>$dbname,
				      dbargs => {AutoCommit => 1,
						 RaiseError => 1}
				    }
    );
my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } ,  { on_connect_do => ['SET search_path TO  public;'] }
					  );
my $phenome_schema= CXGN::Phenome::Schema->connect( sub { $dbh->get_actual_dbh } , { on_connect_do => ['set search_path to public,phenome;'] }  );


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
	    my $seedlot_obj = CXGN::Stock::Seedlot->new( schema => $schema, seedlot_id => $row->stock_id() );
	    $seedlot_obj->discard($sp_person_id, $date, $reason );
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
