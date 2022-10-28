#!/usr/bin/perl

=head1

load_stock_data.pl - a script to load stock data

=head1 SYNOPSIS

load_stock_data.pl -H [dbhost] -D [dbname] [-t] [-s species name ] [-p stock population name]

=head1 COMMAND-LINE OPTIONS

 -H  host name
 -D  database name
 -i infile
 -u username for associating the new stocks 
 -t  Test run . Rolling back at the end.

=head1 DESCRIPTION

Updated script for loading and adding stock names and synonyms.
The owners of the stock accession are not stored in stockprop, but in phenome.stock_owner.

File format for infile (tab delimited):

accession genus species population_name synonyms

=head1 AUTHOR

Naama Menda (nm249@cornell.edu)

April 2013

=cut


use strict;
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

my ( $dbhost, $dbname, $file, $population_name, $species,  $username, $test );
GetOptions(
    'i=s'        => \$file,
    'p=s'        => \$population_name,
    's=s'        => \$species,
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


#getting the last database ids for resetting at the end in case of rolling back
my $last_stockprop_id= $schema->resultset('Stock::Stockprop')->get_column('stockprop_id')->max;
my $last_stock_id= $schema->resultset('Stock::Stock')->get_column('stock_id')->max;
my $last_stockrel_id= $schema->resultset('Stock::StockRelationship')->get_column('stock_relationship_id')->max;
my $last_cvterm_id= $schema->resultset('Cv::Cvterm')->get_column('cvterm_id')->max;
my $last_cv_id= $schema->resultset('Cv::Cv')->get_column('cv_id')->max;
my $last_db_id= $schema->resultset('General::Db')->get_column('db_id')->max;
my $last_dbxref_id= $schema->resultset('General::Dbxref')->get_column('dbxref_id')->max;



#new spreadsheet
my $spreadsheet=CXGN::Tools::File::Spreadsheet->new($file);

##############
##parse first the file with the clone names and synonyms. Load into stock, and stockprop
#############
# population for grouping the clones


my $sp_person_id = CXGN::People::Person->get_person_by_username($dbh, $username); 
die "Need to have a user pre-loaded in the database! " if !$sp_person_id;

my $organism_id ;

if ($species) { ## can also read species name from the input file 
    my $organism = $schema->resultset("Organism::Organism")->find( {
	species => $species } );
    $organism_id = $organism->organism_id();
    die "Species $species does not exist in the database! " if !$organism_id;
} #check this again if species name is provided in the file 

my $stock_rs = $schema->resultset("Stock::Stock");

#the cvterm for the population
print "Finding/creating cvterm for population\n";
my $population_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'population', 'stock_type');



#the cvterm for the accession 
my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type');

#the cvterm for the relationship type
my $member_of =  SGN::Model::Cvterm->get_cvterm_row($schema, 'member_of', 'stock_relationship');

## For the stock module
################################

print "parsing spreadsheet... \n";
my @rows = $spreadsheet->row_labels();
my @columns = $spreadsheet->column_labels();

my $syn_count;
#accession genus species population_name synonyms
my $coderef= sub  {
    my $update_count = 0;
    foreach my $accession (@rows ) {
	#remove spaces from accession name 
	##$accession=~s/\s+//g;
	
	my $species_name  =  $spreadsheet->value_at($accession, "species");
	my $organism = $schema->resultset("Organism::Organism")->find( {
	    species => $species_name } );
	if ($organism) { 
	    $organism_id = $organism->organism_id();
	}
	else {
	    die "Species $species_name does not exist in the database! ";
	}

	my $stock = $schema->resultset("Stock::Stock")->find( {
	    uniquename => $accession });

	my $old_organism_id = $stock->organism_id();
	
	if ($old_organism_id != $organism_id) {

	    print STDERR "FOR ".$stock->uniquename()." update organism from $old_organism_id TO $organism_id.\n";
	    $stock->organism_id($organism_id);
	    $stock->update();
	    $update_count++;

	    
	}

    }

    print STDERR "UPDATED ORGANISMS: $update_count\n";
    #########
    
    if ($test) {
        die "TEST RUN! rolling back\n";
    }
};


try {
    $schema->txn_do($coderef);
    if (!$test) { print "Transaction succeeded! Commiting stocks and their properties! \n\n"; }
} catch {
    # Transaction failed
#    foreach my $value ( keys %seq ) {
#         my $maxval= $seq{$value} || 0;
#         if ($maxval) { $dbh->do("SELECT setval ('$value', $maxval, true)") ;  #}
#         else {  $dbh->do("SELECT setval ('$value', 1, false)");  }
 #    }
    die "An error occured! Rolling back  and reseting database sequences!" . $_ . "\n";
};
