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
 -s species name - must be in the database. Can also be read from the input file 
 -p population name - will create a new stock of type 'population' if doesn't exist. 
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


#my %seq  = (
#    'db_db_id_seq' => $last_db_id,
#    'dbxref_dbxref_id_seq' => $last_dbxref_id,
#    'cv_cv_id_seq' => $last_cv_id,
#    'cvterm_cvterm_id_seq' => $last_cvterm_id,
#    'stock_stock_id_seq' => $last_stock_id,
#    'stockprop_stockprop_id_seq' => $last_stockprop_id,
#    'stock_relationship_stock_relationship_id_seq' => $last_stockrel_id,
#    );

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
#my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type');
my $vector_construct_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'vector_construct', 'stock_type');
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
    foreach my $accession (@rows ) {
	#remove spaces from accession name 
	$accession=~s/\s+//g;
	
	my $species_name  =  $spreadsheet->value_at($accession, "species");
	if (!$species) { 
	    my $organism = $schema->resultset("Organism::Organism")->find( {
		species => $species_name } );
	    $organism_id = $organism->organism_id();
	    warn "Species $species_name does not exist in the database! " if !$organism_id;
	}
	
	my $population_name  =  $spreadsheet->value_at($accession, "population_name");
        my $synonym_string   =  $spreadsheet->value_at($accession, "synonyms");
	my @synonyms = split /\|/ , $synonym_string;

	print "Creating a stock for population $population_name (cvterm = " . $population_cvterm->name . ")\n";

	my $population;
	if ($population_name) { 
	    $population = $stock_rs->find_or_create(
		{
		    'me.name'        => $population_name,
			'me.uniquename'  => $population_name,
			'me.organism_id' => $organism_id,
			type_id          => $population_cvterm->cvterm_id,
		},
		{ join => 'type' }
		);
	}
	
	print "Find or create stock for vector $accession\n";
	my $stock = $schema->resultset("Stock::Stock")->find_or_create(
	    { organism_id => $organism_id,
	      name  => $accession,
	      uniquename => $accession,
	      type_id => $vector_construct_cvterm->cvterm_id(),
	    });
        my $stock_id = $stock->stock_id;
        print "Adding owner $sp_person_id \n";
	#add the owner for this stock
        $phenome_schema->resultset("StockOwner")->find_or_create(
            {
                stock_id     => $stock->stock_id,
                sp_person_id => $sp_person_id,
            });
        #####################

	#the stock belongs to the population:
        #add new stock_relationship
	print "Accession $accession is member_of population $population_name \n";
	$population->find_or_create_related('stock_relationship_objects', {
	    type_id => $member_of->cvterm_id(),
	    subject_id => $stock->stock_id(),
					    } );
        if ($synonym_string) {print "Adding synonyms #" . scalar(@synonyms) . "\n"; }
	foreach my $syn (@synonyms) {
	    if ($syn && defined($syn) && ($syn ne $accession) ) {
		my $existing_synonym = $stock->search_related(
                    'stockprops' , {
                        'me.value'   => $syn,
                        'type.name'  => { ilike => '%synonym%' }
                    },
                    { join =>  'type' }
		    )->single;
                if (!$existing_synonym) {
		    $syn_count++;
		    print STDOUT "Adding synonym: $syn \n"  ;
                    #add the synonym as a stockprop
                    $stock->create_stockprops({ stock_synonym => $syn},
                                              {autocreate => 0,
					       allow_duplicate_values=> 1,
					      });
                }
            }
        }
    }
    #########
    
    if ($test) {
        die "TEST RUN! rolling back\n";
    }
};


try {
    $schema->txn_do($coderef);
    if (!$test) { print "Transaction succeeded! Commiting stocks and their properties! \n\n"; }
}

catch {
#    # Transaction failed
#    foreach my $value ( keys %seq ) {
#         my $maxval= $seq{$value} || 0;
#         if ($maxval) { $dbh->do("SELECT setval ('$value', $maxval, true)") ;  }
#         else {  $dbh->do("SELECT setval ('$value', 1, false)");  }
#     }
    die "An error occured! Rolling back  and reseting database sequences!" . $_ . "\n";
};
