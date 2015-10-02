=head1

load_stock_data.pl

=head1 SYNOPSIS

    $load_stock_data.pl -H [dbhost] -D [dbname] [-t]

=head1 COMMAND-LINE OPTIONS

 -H  host name
 -D  database name
 -i infile
 -t  Test run . Rolling back at the end.


=head2 DESCRIPTION

Updated script for loading and adding banana accession names and synonyms.
The owners of the stock accession are not stored in stockprop, but in phenome.stock_owner.

Naama Menda (nm249@cornell.edu)
Guillaume Bauchet (gjb99@cornell.edu)

    July 2015

  

=cut


#!/usr/bin/perl
use strict;
use Getopt::Std;
use CXGN::Tools::File::Spreadsheet;

use CXGN::Phenome::Schema;
use CXGN::BreedersToolbox::Projects;
use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;
use Carp qw /croak/ ;

use CXGN::Chado::Dbxref;
use CXGN::Chado::Phenotype;
use CXGN::People::Person;
use Try::Tiny;

our ($opt_H, $opt_D, $opt_i, $opt_t);

getopts('H:i:tD:');

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $file = $opt_i;

my $dbh = CXGN::DB::InsertDBH->new( { dbhost=>$dbhost,
                      dbname=>$dbname,
                      dbargs => {AutoCommit => 0,
                         RaiseError => 1}
                    }
    );
my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } ,  { on_connect_do => ['SET search_path TO  public;'] }
                      );
my $phenome_schema= CXGN::Phenome::Schema->connect( sub { $dbh->get_actual_dbh } , { on_connect_do => ['set search_path to public,phenome;'] }  );


#getting the last database ids for resetting at the end in case of rolling back
# my $last_stockprop_id= $schema->resultset('Stock::Stockprop')->get_column('stockprop_id')->max;
# my $last_stock_id= $schema->resultset('Stock::Stock')->get_column('stock_id')->max;
# my $last_stockrel_id= $schema->resultset('Stock::StockRelationship')->get_column('stock_relationship_id')->max;
# my $last_cvterm_id= $schema->resultset('Cv::Cvterm')->get_column('cvterm_id')->max;
# my $last_cv_id= $schema->resultset('Cv::Cv')->get_column('cv_id')->max;
# my $last_db_id= $schema->resultset('General::Db')->get_column('db_id')->max;
# my $last_dbxref_id= $schema->resultset('General::Dbxref')->get_column('dbxref_id')->max;
# my $last_organism_id = $schema->resultset('Organism::Organism')->get_column('organism_id')->max;

# my %seq  = (
#         'db_db_id_seq' => $last_db_id,
#         'dbxref_dbxref_id_seq' => $last_dbxref_id,
#         'cv_cv_id_seq' => $last_cv_id,
#         'cvterm_cvterm_id_seq' => $last_cvterm_id,
#         'stock_stock_id_seq' => $last_stock_id,
#         'stockprop_stockprop_id_seq' => $last_stockprop_id,
#         'stock_relationship_stock_relationship_id_seq' => $last_stockrel_id,
#         'organism_organism_id_seq' => $last_organism_id,
#         );

#new spreadsheet, skip  first column
my $spreadsheet=CXGN::Tools::File::Spreadsheet->new($file); # 0 or 1

##############
##parse first the file with the clone names and synonyms. Load is into stock, and stockprop
#############
# population for grouping the clones

my $population_name = 'Banana accessions';

my $species = 'Musa';

my $organism = $schema->resultset("Organism::Organism")->find_or_create( {
    species => $species } );
my $organism_id = $organism->organism_id();

my $stock_rs = $schema->resultset("Stock::Stock");



#the cvterm for the accession
print "Finding/creating cvterm for 'stock type' \n";
my $accession_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
    { name   => 'accession',
      cv     => 'stock type',
      db     => 'null',
      dbxref => 'accession',
    });

#the cvterm for the relationship type
print "Finding/creating cvterm for stock relationship 'member_of' \n";

my $member_of = $schema->resultset("Cv::Cvterm")->create_with(
    { name   => 'member_of',
      cv     => 'stock relationship',
      db     => 'null',
      dbxref => 'member_of',
    });
   
#the cvterm for the population
print "Finding/creating cvterm for population\n";
my $population_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
    { name   => 'population',
      cv     => 'stock type',
      db     => 'null',
      dbxref => 'population',
    });

print "Creating a stock for population $population_name (cvterm = " . $population_cvterm->name . ")\n";

my $population = $stock_rs->find_or_create(
    {
        'me.name'        => $population_name,
        'me.uniquename'        => $population_name,
        'me.organism_id' => $organism_id,
        type_id          => $population_cvterm->cvterm_id,
    },
    { join => 'type' }
    );

# link to MGIS database
my $mg_dbid;
my $mg_row = $schema->resultset("General::Db")->find( { name=>'MGIS' });
if (!$mg_row) { 
	my $new_mg_row = $schema->resultset("General::Db")->create( { 
		name => "MGIS"
	});
	
	$mg_dbid = $new_mg_row->db_id();
}
else { 
	$mg_dbid = $mg_row->db_id();
}




## For the stock module
################################

print "parsing spreadsheet... \n";
my @rows = $spreadsheet->row_labels();
my @columns = $spreadsheet->column_labels();

## LABEL    GENOTYPE    SYNONYM1    SYNONYM2    SYNONYM3    SYNONYM4    PLOIDY    GERMPLASM_GROUP    CATEGORY    INSTITUTE    LOCATION    LOCATION_CODE    CURATOR    NAME    PROJECT_DESCRIPTION    PROJECT_TYPE    YEAR
# LABEL    NAME    UNIQUENAME    GENOTYPE    SYNONYM1    SYNONYM2    PLOIDY    GERMPLASM_GROUP    CATEGORY    INSTITUTE    LOCATION    LOCATION_CODE    CURATOR    PROJECT_NAME    PROJECT_DESCRIPTION    PROJECT_TYPE    YEAR
# 1    Calcutta-4    Calcutta-4_ITC0249_2015_Collection_IITA_SEN    Calcutta-4    ITC0249        2X    AA    Collection    IITA    Sendusu    SEN    mibatte    2015_Collection_IITA_SEN    Collection, IITA-Sendusu, 2015    2015_banana_germplasm    2015


my ($new_count,$existing, $count, $syn_count, $merge);
my $coderef= sub  {
	foreach my $num (@rows ) {
		my $accession = $spreadsheet->value_at($num,'NAME');
		if (!$accession) { next; }
		print "\nBanana accession name is '" . $accession . "'\n";
		$count++;
		my $organization = $spreadsheet->value_at($num, 'INSTITUTE');
        my $location_code = $spreadsheet->value_at($num, 'LOCATION_CODE');
        my $location = $spreadsheet->value_at($num, 'LOCATION');
        my $ITC_name = $spreadsheet->value_at($num, "SYNONYM1");
        #my $original_name = $spreadsheet->value_at($num, "GENOTYPE_NAME_ORIGINAL");
        my $syn1 =  $spreadsheet->value_at($num, "UNIQUENAME");
        my $syn2 =  $spreadsheet->value_at($num, "GENOTYPE");
        my $syn3 =  $spreadsheet->value_at($num, "SYNONYM1");
        #my $syn4 =  $spreadsheet->value_at($num, "SYNONYM4");
        my $ploidy = $spreadsheet->value_at($num, "PLOIDY");
        my $germplasm_group = $spreadsheet->value_at($num, "GERMPLASM_GROUP");
        my $curator = $spreadsheet->value_at($num, "CURATOR");
        my $name = $spreadsheet->value_at($num, "PROJECT_NAME");
        my $category = $spreadsheet->value_at($num, "CATEGORY");
        my $project_type = $spreadsheet->value_at($num, "PROJECT_TYPE");
        my $year = $spreadsheet->value_at($num, "YEAR");
        my $project_description = $spreadsheet->value_at($num, "PROJECT_DESCRIPTION");
        #my $project_description = "$name $project_type ($year) $location";
       
        print"project descr is $project_description /n";
       
        # see if a stock exists with any of the synonyms
        my @stocks = $stock_rs->search( {
            -or => [
                 uniquename => $accession,
                 uniquename => $syn1,
                 uniquename => $syn2,
                 uniquename => $syn3,
                 #uniquename => $syn4,
                ], }, );
               
		my $existing_stock = $stock_rs->search( { uniquename => $accession } )->single;
			foreach my $s(@stocks) {
				print "Looking at accession $accession, Found stock '" . $s->uniquename . "(stock_id = " . $s->stock_id . ")'\n";
				$existing++;
			}
    
    
    ##
        if (!@stocks) {
            print "NEW stock: $accession\n";
            $new_count++;
        }elsif (!$existing_stock)  {
			##
			my %stock_hash = map { $_->stock_id => $_ } @stocks;
			my @keys =   keys %stock_hash;
			my @sorted  = sort { $a <=> $b } @keys;
			print "Existing stock_id  is " . $sorted[0] . " name = " . ($stock_hash{$sorted[0]})->uniquename . "\n";
			$existing_stock = $stock_hash{$sorted[0]};
			$existing_stock->uniquename($accession);
			$existing_stock->name($accession);
			$existing_stock->update;
			##
		}
		if (scalar(@stocks) >1) {
			my @stock_names = map( $_->uniquename , @stocks );
			my @stock_ids = map ($_->stock_id, @stocks);
			print "MERGE: stocks " . join (", " , @stock_names) . "need to be merged\n";
			$merge .= "$accession : merge stock_ids :  " .join (", " , @stock_ids) . "( names: " . join (" | " , @stock_names) . ")\n";
		}
		my $stock = $existing_stock ? $existing_stock :
        $schema->resultset("Stock::Stock")->find_or_create(
        { organism_id => $organism_id,
          name  => $accession,
          uniquename => $accession,
          type_id => $accession_cvterm->cvterm_id(),
          #description => '',
        });
        my $stock_id = $stock->stock_id;
        print "Adding owner $curator\n";
  
        my $curator_person_id =  CXGN::People::Person->get_person_by_username($dbh, $curator); #add person id as an option.
        if (!$curator_person_id) { die "Person $curator does not exist in the database! Please add this user before continuing \n";}
        #add owner for this stock       
        $phenome_schema->resultset("StockOwner")->find_or_create(
            {
                stock_id     => $stock->stock_id,
                sp_person_id => $curator_person_id,

            });
            if ($ITC_name) { 
				my $row = $schema -> resultset("General::Dbxref")->find_or_create(
				{
					accession => $ITC_name, db_id=>$mg_dbid,
				});
				my $link_row = $schema -> resultset("Stock::StockDbxref")->find_or_create(
				{  stock_id => $stock_id,
				dbxref_id  => $row->dbxref_id(),
				});
				$link_row->update();
				print "Creating a MGIS link for accession $accession (stock_id = $stock_id dbxref_id= " . $row->dbxref_id . ")\n";
			}
#          you store the location in nd_geolocation
#        link it with each experiment
#        the nd_experiment table has nd_geolocation_id column

#        you store a project name for your group of phenotyping /genotyping experiments
#        call it something like "2015 phenotyping trials in location ABC..."
#        and link that project with the project_id for the breeding program using project_relationship
#        if you don't have a project_id for the breeding program you create a new one in the project table
#        and add to it a projectprop woth type_id of the "breeding_program" cvterm
# select * from stock join nd_experiment_stock ON nd_experiment_stock.nd_experiment_stock_id = stock.stock_id join nd_experiment on nd_experiment.nd_experiment_id = nd_experiment_stock.nd_experiment_id join nd_experiment_project on nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id ;
        my $banana_project = $schema->resultset("Project::Project")->find_or_create(
        {
        name => "2015_banana_germplasm_IITA_NARO",
        #name => $name,
        description => $project_type,
        } ) ;
       
        my $project_description = "$name $project_type ($year) $location";
       
        #print"project descr is $project_description /n";

        my $project = $schema->resultset("Project::Project")->find_or_create(
        {
        name => $name,
        description => $project_description,
        } ) ;
                
        #associate the new project with breeding program
        my $cxgn_project = CXGN::BreedersToolbox::Projects->new( { schema => $schema } ) ;
        $cxgn_project->associate_breeding_program_with_trial( $banana_project->project_id, $project->project_id);
        #
        print "banana id = " . $banana_project->project_id . " project_id = " . $project->project_id . "\n";
        #store the geolocation data and props:
        my $geo_description = $location;


        #####################
		if ($organization) { $stock->create_stockprops( { organization => $organization }, { autocreate => 1 } ); }
		if ($location_code) { $stock->create_stockprops( { location_code => $location_code }, { autocreate => 1 } ) } ;
		if ($ploidy) { $stock->create_stockprops( { ploidy_level => $ploidy }, { autocreate => 1 }) };
		if ($germplasm_group) { $stock->create_stockprops( { genome_structure => $germplasm_group }, { autocreate=>1})};

		#the stock belongs to the population:
        #add new stock_relationship

		$population->find_or_create_related('stock_relationship_objects', {
			type_id => $member_of->cvterm_id(),
			subject_id => $stock->stock_id(),
		} );
        print "Adding synonyms #\n";
        my @synonyms = ($accession,$syn2, $syn3);
        foreach my $syn (@synonyms) {
			if ($syn && defined($syn) && ($syn ne $accession) ) {
				my $existing_synonym = $stock->search_related(
                    'stockprops' , {
                        'me.value'   => $syn,
                        'type.name'  => 'synonym'
                    },
                    { join =>  'type' }
            )->single;
                if (!$existing_synonym) {
            $syn_count++;
            print STDOUT "Adding synonym: $syn \n"  ;
                    #add the synonym as a stockprop
                    $stock->create_stockprops({ synonym => $syn},
                                              {autocreate => 1,
                                               cv_name => 'local',
                                               allow_duplicate_values=> 1,
                          
                                              });
                }
            }
        }
		my @props = $stock->search_related('stockprops');
		foreach  my $p ( @props )  {
			print "**the prop value for stock " . $stock->name() . " is   " . $p->value() . "\n"  if $p;
		}
		

		   #########
    }
    
   
	

   
    
    print "TOTAL: \n $count rows \n $new_count new accessions \n $existing existing stocks \n $syn_count new synonyms \n MERGE :\n  $merge\n";
    #if ($opt_t) { die "test rolling back";}
};


try {
    $schema->txn_do($coderef);
    if (!$opt_t) {
        print "Transaction succeeded! Commiting stocks and their properties! \n\n";
        $schema->txn_commit();
    }
    else {
        $schema->txn_rollback();
        die "TEST RUN! rolling back\n";     
    }
} catch {
    # Transaction failed
    # foreach my $value ( keys %seq ) {
    #     my $maxval= $seq{$value} || 0;
    #     if ($maxval) { $dbh->do("SELECT setval ('$value', $maxval, true)") ;  }
    #     else {  $dbh->do("SELECT setval ('$value', 1, false)");  }
    # }
    die "An error occured! Rolling back  and reseting database sequences!" . $_ . "\n";
};
