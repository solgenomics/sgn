#!/usr/bin/perl

=head1

load_genotypes.pl - loading genotypes into cxgn databases, based on the load_cassava_snps.pl script by Naama.

=head1 SYNOPSIS

    load_genotypes.pl -H [dbhost] -D [dbname] [-t]

=head1 COMMAND-LINE OPTIONS

 -H host name
 -D database name
 -i infile
 -p project name (e.g. SNP genotyping 2012 Cornell Biotech)
 -y project year [2012]
 -g population name (e.g., NaCRRI training population) Mandatory option
 -x delete old genotypes for accessions that have new genotypes
 -a add accessions that are not in the database
 -s sort markers according to custom sort order (see script source)
 -t Test run . Rolling back at the end.

=head1 DESCRIPTION

This script loads genotype data into the Chado genotype table it encodes the genotype + marker name in a json format in the genotyope.uniquename field for easy parsing by a Perl program. The genotypes are linked to the relevant stock using nd_experiment_genotype. Each column in the spreadsheet, which represents a single accession (stock) is stored as a single genotype entry and linked to the stock via nd_experiment_genotype. Stock names are stored in the stock table if cannot be found, and linked to a population stock with the name supplied in opt_g

=head1 AUTHOR

 Naama Menda (nm249@cornell.edu) - July 2012
 Modified by Lukas, Jan 2015

=cut

use strict;

use Getopt::Std;
use Data::Dumper;
use JSON::Any;
use Carp qw /croak/ ;
use Try::Tiny;
use Pod::Usage;

use Bio::Chado::Schema;
use CXGN::People::Person;
use CXGN::DB::InsertDBH;
use CXGN::Genotype;
use CXGN::GenotypeIO;

our ($opt_H, $opt_D, $opt_i, $opt_t, $opt_p, $opt_y, $opt_g, $opt_a, $opt_x, $opt_s, $opt_m);

getopts('H:i:tD:p:y:g:axsm:');

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $file = $opt_i;
my $population_name = $opt_g;
my $protocol_name = $opt_m || "GBS ApeKI Cassava genome v5";

print STDERR "Input file: $file\n";
print STDERR "DB host: $dbhost\n";
print STDERR "DB name: $dbname\n";
print STDERR "Population name: $population_name\n";
print STDERR "Project year: $opt_y\n";
print STDERR "Add missing accessions: $opt_a\n";
print STDERR "Delete old duplicate phenotypes: $opt_x\n";
print STDERR "Rollback: $opt_t\n";

if (!$opt_H || !$opt_D || !$opt_i || !$opt_g) {
    pod2usage(-verbose => 2, -message => "Must provide options -H (hostname), -D (database name), -i (input file) , and -g (populations name for associating accessions in your SNP file) \n");
}

my $dbh = CXGN::DB::InsertDBH->new( { dbhost=>$dbhost,
				      dbname=>$dbname,
				      dbargs => {AutoCommit => 1,
						 RaiseError => 1}
				    }
    );


my $schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );
$dbh->do('SET search_path TO public,sgn');

# getting the last database ids for resetting at the end in case of rolling back
#
my $last_nd_experiment_id = $schema->resultset('NaturalDiversity::NdExperiment')->get_column('nd_experiment_id')->max;
my $last_cvterm_id = $schema->resultset('Cv::Cvterm')->get_column('cvterm_id')->max;
my $last_nd_experiment_project_id = $schema->resultset('NaturalDiversity::NdExperimentProject')->get_column('nd_experiment_project_id')->max;
my $last_nd_experiment_stock_id = $schema->resultset('NaturalDiversity::NdExperimentStock')->get_column('nd_experiment_stock_id')->max;
my $last_nd_experiment_genotype_id = $schema->resultset('NaturalDiversity::NdExperimentGenotype')->get_column('nd_experiment_genotype_id')->max;
my $last_genotype_id = $schema->resultset('Genetic::Genotype')->get_column('genotype_id')->max;
my $last_project_id = $schema->resultset('Project::Project')->get_column('project_id')->max;

my %seq  = (
    'nd_experiment_nd_experiment_id_seq' => $last_nd_experiment_id,
    'cvterm_cvterm_id_seq' => $last_cvterm_id,
    'nd_experiment_project_nd_experiment_project_id_seq' => $last_nd_experiment_project_id,
    'nd_experiment_stock_nd_experiment_stock_id_seq' => $last_nd_experiment_stock_id,
    'nd_experiment_genotype_nd_experiment_genotype_id_seq' => $last_nd_experiment_genotype_id,
    'genotype_genotype_id_seq' => $last_genotype_id,
    'project_project_id_seq'   => $last_project_id,
    );

my $accession_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
    { name   => 'accession',
      cv     => 'stock type',
      db     => 'null',
      dbxref => 'accession',
    });

my $population_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
      { name   => 'training population',
	cv     => 'stock type',
	db     => 'null',
	dbxref => 'training population',
    });

 #store a project
my $project = $schema->resultset("Project::Project")->find_or_create(
    {
        name => $opt_p,
        description => $opt_p,
    } ) ;
$project->create_projectprops( { 'project year' => $opt_y }, { autocreate => 1 } );

# find the cvterm for a genotyping experiment
my $geno_cvterm = $schema->resultset('Cv::Cvterm')->create_with(
    { name   => 'genotyping experiment',
      cv     => 'experiment type',
      db     => 'null',
      dbxref => 'genotyping experiment',
    });

my $protocol_row = $schema->resultset("NaturalDiversity::NdProtocol")->find_or_create( 
    { name => $protocol_name,
      type_id => $geno_cvterm->cvterm_id
    });

my $protocol_id = $protocol_row->nd_protocol_id();

# find the cvterm for the SNP calling experiment
my $snp_genotype = $schema->resultset('Cv::Cvterm')->create_with(
    { name   => 'snp genotyping',
      cv     => 'local',
      db     => 'null',
      dbxref => 'snp genotyping',
    });

my $geolocation = $schema->resultset("NaturalDiversity::NdGeolocation")->find_or_create(
    {
        description => 'Cornell Biotech', #add this as an option
    } ) ;


my $organism = $schema->resultset("Organism::Organism")->find_or_create(
    {
	genus   => 'Manihot',
	species => 'Manihot esculenta',
    } );

my $population_members = $schema->resultset("Cv::Cvterm")->create_with(
    { name   => 'members of',
      cv     => 'stock relationship',
      db     => 'null',
      dbxref => 'members of',
    });

my $organism_id = $organism->organism_id();
########################

#new spreadsheet,
#my $spreadsheet=CXGN::Tools::File::Spreadsheet->new($file);

print STDERR "Reading genotype information...\n";
my $gtio = CXGN::GenotypeIO->new( { file => $file, format => "dosage_transposed" });

#my @rows = $spreadsheet->row_labels();
#my @columns = $spreadsheet->column_labels();

my $json_obj = JSON::Any->new;

my $coderef = sub {
    while (my $gt = $gtio->next())  {
	my $accession_name = $gt->name();
	
	my $db_name = $accession_name;

	$db_name =~ s/(.*?)\.(.*)/$1/;
	
	if ($accession_name eq "marker" || $accession_name =~ /BLANK/i ) {next;}

	#print Dumper($gt->rawscores);

        print STDERR "Looking for accession $accession_name ($db_name)\n";
        my %json;
        my $cassava_stock;
        my $stock_name;
        my $stock_rs = $schema->resultset("Stock::Stock")->search(
            {
                -or => [
                     'lower(me.uniquename)' => { like => lc($db_name) },
                     -and => [
                         'lower(type.name)'       => { like => '%synonym%' },
                         'lower(stockprops.value)' => { like => lc($db_name) },
                     ],
                    ],
            },
            { join => { 'stockprops' => 'type'} ,
              distinct => 1
            }
            );
        if ($stock_rs->count >1 ) {
            print STDERR "ERROR: found multiple accessions for name $accession_name! \n";
            while ( my $st = $stock_rs->next) {
                print STDERR "stock name = " . $st->uniquename . "\n";
            }
	    next;
            # die;
        } elsif ($stock_rs->count == 1) {
	    print STDERR "Accession $db_name found !\n";
            $cassava_stock = $stock_rs->first;	    
            $stock_name = $cassava_stock->uniquename;
        } else {
	    
	    print STDERR "The accession $db_name was not found in the database. Use option -a to add automatically.\n";
            #store the plant accession in the stock table if $opt_a
	    #
	    if ($opt_a) { 

		$cassava_stock = $schema->resultset("Stock::Stock")->create(
		    { organism_id => $organism_id,
		      name       => $db_name,
		      uniquename => $db_name,
		      type_id     => $accession_cvterm->cvterm_id,
		    } );
		
	    }
	    else { 
		print STDERR "WARNING! Accession $accession_name (using: $db_name) not found.\n";
		next();
	    }
        }
	my $population_stock = $schema->resultset("Stock::Stock")->find_or_create(
            { organism_id => $organism_id,
	      name       => $population_name,
	      uniquename => $population_name,
	      type_id => $population_cvterm->cvterm_id,
            } );

	my $has_rel_rs = $schema->resultset("Stock::StockRelationship")->search(
	    {
		type_id => $population_members->cvterm_id(),
		subject_id => $cassava_stock->stock_id(),
		object_id => $population_stock->stock_id(),
	    });

	if ($has_rel_rs->count() == 0) { 
	    $cassava_stock->find_or_create_related('stock_relationship_objects', {
		type_id => $population_members->cvterm_id(),
		subject_id => $cassava_stock->stock_id(),
		object_id => $population_stock->stock_id(),
						   } );
	}
	    ###############
        print STDERR "cassava stock name = " . $cassava_stock->name . "\n";
        my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')->create(
            {
                nd_geolocation_id => $geolocation->nd_geolocation_id(),
                type_id => $geno_cvterm->cvterm_id(),
            } );

	print STDERR "Linking to protocol...\n";
	my $nd_experiment_protocol = $schema->resultset('NaturalDiversity::NdExperimentProtocol')->create( 
	    {
		nd_experiment_id => $experiment->nd_experiment_id(),
		nd_protocol_id => $protocol_id,
	    });
	

        #link to the project
        $experiment->find_or_create_related('nd_experiment_projects', {
            project_id => $project->project_id()
                                            } );
        #link the experiment to the stock
        $experiment->find_or_create_related('nd_experiment_stocks' , {
            stock_id => $cassava_stock->stock_id(),
            type_id  =>  $geno_cvterm->cvterm_id(),
                                            });
	if ($opt_x) { 
	    print STDERR "OPTION -x: REMOVING OLD GENOTYPE... \n";
	    my $has_genotype_rs =  $schema->resultset('NaturalDiversity::NdExperimentStock')->search_related('nd_experiment')->search_related('nd_experiment_genotypes')->search_related('genotype')->search_related('genotypeprops')->search( { 'me.stock_id' => $cassava_stock->stock_id() }); 

	    while (my $has_genotype = $has_genotype_rs->next()) { 
		print STDERR "Note: -x option: removing already present genotype for $db_name.\n";
		my $genotypeprop_rs = $schema->resultset('Genetic::Genotypeprop')->search(  
		    { genotype_id => $has_genotype->genotype_id() } );
		while (my $genotypeprop = $genotypeprop_rs->next()) { 
		    print STDERR "DELETING GENOTYPE PROP ".$genotypeprop->genotypeprop_id()."\n";		
		    $genotypeprop->delete();
		}
		my $genotype = $schema->resultset('Genetic::Genotypeprop')->search(
		    { 'me.genotype_id' => $has_genotype->genotype_id(),  } );
		
		print STDERR "DELETING GENOTYPE: ".$has_genotype->genotype_id()."\n";
		$genotype->delete();

		#my $nd_experiment_genotypes = $schema->resultset('Genetic::NdExperimentGenotypes')->search( { nd_experiment_id => $has_genotype_rs->nd_experiment_id(), });

	    }
	}
	
	my @markers = @{$gtio->markers()};

	if ($opt_s) { 
	    @markers = sort bychr @{$gtio->markers()};
	}
	foreach my $marker_name (@markers) {
	    #print STDERR "markername: $marker_name\n";
	    #print STDERR Dumper($gt->rawscores);
            my $base_calls = $gt->rawscores->{$marker_name}; #($marker_namefg, $accession_name);
	    #print STDERR "BASE CALL: $base_calls\n";
	    $base_calls =~ s/\s+//g;
	    if ($base_calls !~/[0-9.]+|NA/i) { 
		print STDERR "SKIPPING BASECALL $base_calls\n";
	    }

	    $json{$marker_name} = $base_calls;
        }

        my $json_string = $json_obj->encode(\%json);
	#print STDERR Dumper($json_string);
        print "Storing new genotype for stock " . $cassava_stock->name . " \n\n";
        my $genotype = $schema->resultset("Genetic::Genotype")->find_or_create(
            {
                name        => $cassava_stock->name . "|" . $experiment->nd_experiment_id,
                uniquename  => $cassava_stock->name . "|" . $experiment->nd_experiment_id,
                description => "Cassava SNP genotypes for stock $ (name = " . $cassava_stock->name . ", id = " . $cassava_stock->stock_id . ")",
                type_id     => $snp_genotype->cvterm_id,
            }
            );
        $genotype->create_genotypeprops( { 'snp genotyping' => $json_string } , {autocreate =>1 , allow_duplicate_values => 1 } );
        #link the genotype to the nd_experiment
        my $nd_experiment_genotype = $experiment->find_or_create_related('nd_experiment_genotypes', { genotype_id => $genotype->genotype_id() } );
    }
};

try {
    $schema->txn_do($coderef);
    if (!$opt_t) { print "Transaction succeeded! Commiting genotyping experiments! \n\n"; }
} catch {
    # Transaction failed
    foreach my $value ( keys %seq ) {
        my $maxval= $seq{$value} || 0;
        if ($maxval) { $dbh->do("SELECT setval ('$value', $maxval, true)") ;  }
        else {  $dbh->do("SELECT setval ('$value', 1, false)");  }
    }
    die "An error occured! Rolling back  and reseting database sequences!" . $_ . "\n";
};

sub bychr { 
my @a = split "\t", $a;
    my @b = split "\t", $b;
    
    my $a_chr;
    my $a_coord;
    my $b_chr;
    my $b_coord;
    
    if ($a[1] =~ /^[A-Za-z]+(\d+)[_-](\d+)$/) {
	$a_chr = $1;
	$a_coord = $2;
    }
    
    if ($b[1] =~ /[A-Za-z]+(\d+)[_-](\d+)/) { 
	$b_chr = $1;
	$b_coord = $2;
    }
    
    if ($a_chr eq $b_chr) { 
	return $a_coord <=> $b_coord;
    }
    else { 
	return $a_chr <=> $b_chr;
    }
}
