#!/usr/bin/perl

=head1

load_stock_data.pl - a script to load stock data

=head1 SYNOPSIS

load_stock_data.pl -H [dbhost] -D [dbname] [-t] [-s species name ] [-p stock population name]

=head1 COMMAND-LINE OPTIONS

 -H host name
 -D database name
 -i infile
 -u username for associating the new stocks 
 -s species name - must be in the database. Can also be read from the input file 
 -p population name - will create a new stock of type 'population' if doesn't exist. 
 -t Test run . Rolling back at the end.

=head1 DESCRIPTION

Updated script for loading and adding stock names and synonyms.
The owners of the stock accession are not stored in stockprop, but in phenome.stock_owner

All other stockproperties can be given as additional columns and will be loaded automatically; 
if the corresponding stock_property does not exist in the database it will be added.

File format for infile (tab delimited):

accession species_name population_name synonyms description other_stock_props ...

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

my ( $dbhost, $dbname, $file, $population_name, $species,  $username, $password, $test );
GetOptions(
    'i=s'        => \$file,
    'p=s'        => \$population_name,
    's=s'        => \$species,
    'u=s'        => \$username,
    'P=s'        => \$password,
    't'          => \$test,
    'dbname|D=s' => \$dbname,
    'dbhost|H=s' => \$dbhost,
);


my $dbh = CXGN::DB::Connection->new( { dbhost=>$dbhost,
				      dbname=>$dbname,
				      dbuser=>'postgres',
				      dbpass=>$password,
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

my $organism_id ;

if ($species) { ## can also read species name from the input file 
    my $organism = $schema->resultset("Organism::Organism")->find( {
	species => $species } );
    $organism_id = $organism->organism_id();
    die "Species $species does not exist in the database! " if !$organism_id;
} #check this again if species name is provided in the file 

my $stock_rs = $schema->resultset("Stock::Stock");

my $stock_property_cv_id = $schema->resultset("Cv::Cv")->find( { name => 'stock_property' })->cv_id();

print STDERR "Stock property CV ID = $stock_property_cv_id\n";


# the cvterm for the population
#
print "Finding/creating cvterm for population\n";
my $population_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'population', 'stock_type');

# the cvterm for the accession
#
my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type');

# the cvterm for the relationship type
#
my $member_of =  SGN::Model::Cvterm->get_cvterm_row($schema, 'member_of', 'stock_relationship');

# for the stock module
#
print "parsing spreadsheet... \n";
my @rows = $spreadsheet->row_labels();
my @columns = $spreadsheet->column_labels();

my $syn_count;

print STDERR "COLUMN LABELS = ".join(", ", @columns)."\n";

# accession species population_name synonyms
#
my $coderef= sub  {
    foreach my $accession (@rows ) {
	# remove spaces from accession name 
	$accession=~s/\s+//g;
	
	my $species_name  =  $spreadsheet->value_at($accession, "species_name");
	if (!$species) { 
	    my $organism = $schema->resultset("Organism::Organism")->find( {
		species => $species_name } );
	    $organism_id = $organism->organism_id();
	    die "Species $species_name does not exist in the database! " if !$organism_id;
	}
	
	my $population_names  =  $spreadsheet->value_at($accession, "population_name"); # new: can be more than one, | separated
        my $synonym_string   =  $spreadsheet->value_at($accession, "synonyms");
	my $description      =  $spreadsheet->value_at($accession, "description");
	
	my @synonyms = split /\|/ , $synonym_string;

	my @population_rows;
	if ($population_names) {
	    my @populations = split /\|/, $population_names;

	    foreach my $name (@populations) { 
		print "Creating a stock for population $population_name (cvterm = " . $population_cvterm->name . ")\n";
		my $row = $stock_rs->find_or_create( {
		    'me.name'        => $name,
		    'me.uniquename'  => $name,
		    'me.organism_id' => $organism_id,
		    type_id          => $population_cvterm->cvterm_id, }, { join => 'type' }
		    );
		push @population_rows, $row;
	    }
	}
	
	print "Find or create stock for accesssion $accession\n";
	my $stock = $schema->resultset("Stock::Stock")->find_or_create(
	    { organism_id => $organism_id,
	      name  => $accession,
	      description => $description,
	      uniquename => $accession,
	      type_id => $accession_cvterm->cvterm_id(),
	    });
        my $stock_id = $stock->stock_id;
        print "Adding owner $sp_person_id \n";
	
	# add the owner for this stock
	#
        $phenome_schema->resultset("StockOwner")->find_or_create(
            {
                stock_id     => $stock->stock_id,
                sp_person_id => $sp_person_id,
            });

	# the stock belongs to population(s):
        # add new stock_relationship(s)
	#
	if ($population_names) {
	    foreach my $row (@population_rows) { 
		print "Accession $accession is member_of population ".$row->uniquename();
		$row->find_or_create_related('stock_relationship_objects', {
		    type_id => $member_of->cvterm_id(),
		    subject_id => $stock->stock_id(),
                } );
	    }
	}
	
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
		    
                    # add the synonym as a stockprop
		    #
                    $stock->create_stockprops({ stock_synonym => $syn},
                                              {autocreate => 0,
					       allow_duplicate_values=> 1,
					      });
                }
            }
        }

	print STDERR "Parsing ".scalar(@columns)." columns...\n";
	
	for(my $n = 5; $n<@columns; $n++) {
	    print STDERR "Retrieving value at $accession / $columns[$n]...\n";
	    my $value = $spreadsheet->value_at($accession, $columns[$n]);
	    print STDERR "value is $value\n";
	    if ($value) { 
		my $type_rs = $schema->resultset("Cv::Cvterm")->find_or_create(
		    {
			name => $columns[$n],
			cv_id => $stock_property_cv_id
		    });
		print STDERR "TYPE ID IS ".$type_rs->cvterm_id."\n";
		my $stockprop = $schema->resultset("Stock::Stockprop")->find_or_create(
		    {
			stock_id => $stock->stock_id,
			value => $value,
			type_id => $type_rs->cvterm_id,
		    });
	    }
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
