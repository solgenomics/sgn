#!/usr/bin/perl

=head1
load_genotypes_vcf.pl - loading genotypes into cxgn databases, based on the load_cassava_snps.pl script by Naama.

=head1 SYNOPSIS
    load_genotypes_vcf.pl -H [dbhost] -D [dbname] -i [infile] -p [project name] -y [year] -g [population name] -m [protocol name] -t

=head1 COMMAND-LINE OPTIONS
  ARGUMENTS
 -H host name (required) e.g. "localhost"
 -D database name (required) e.g. "cxgn_cassava"
 -i path to infile (required)
 -p project name (required) e.g. "SNP genotyping 2012 Cornell Biotech".  Will be found or created in Project table.
 -y project year (required) e.g. "2012".  Will be saved as a Projectprop.
 -g population name (required) e.g. "NaCRRI training population"
 -m protocol name (required) e.g. "GBS ApeKI Cassava genome v6"
 -l location name (required) e.g. "Cornell Biotech".  Will be found or created in NdGeolocation table.
 -o organism genus name (required) e.g. "Manihot".  Along with organism species name, this will be found or created in Organism table.
 -q organism species name (required) e.g. "Manihot esculenta".
 
  FLAGS
 -x delete old genotypes for accessions that have new genotypes
 -a add accessions that are not in the database
 -z if accession names include an IGD number. Accession names are in format 'accession_name:IGD_number'. The IGD number will be parsed and stored as a genotypeprop. 
 -t Test run . Rolling back at the end.
  

=head1 DESCRIPTION
This script loads genotype data into the Chado genotype table it encodes the genotype + marker name in a json format in the genotyope.uniquename field for easy parsing by a Perl program. The genotypes are linked to the relevant stock using nd_experiment_genotype. Each column in the spreadsheet, which represents a single accession (stock) is stored as a single genotype entry and linked to the stock via nd_experiment_genotype. Stock names are stored in the stock table if cannot be found, and linked to a population stock with the name supplied in opt_g. Map details (chromosome, position, ref, alt, qual, filter, info, and format) are stored in json format in the protocolprop table. 

=head1 AUTHOR
 Nicolas Morales (nm529@cornell.edu) May 2016
=cut

use strict;

use Getopt::Std;
use Data::Dumper;
use JSON::Any;
use JSON::PP;
use Carp qw /croak/ ;
use Try::Tiny;
use Pod::Usage;

use Bio::Chado::Schema;
use CXGN::People::Person;
use CXGN::DB::InsertDBH;
use CXGN::Genotype;
use CXGN::GenotypeIO;
use Sort::Versions;
use SGN::Model::Cvterm;

our ($opt_H, $opt_D, $opt_i, $opt_t, $opt_p, $opt_y, $opt_g, $opt_a, $opt_x, $opt_v, $opt_s, $opt_m, $opt_l, $opt_o, $opt_q, $opt_z);

getopts('H:i:tD:p:y:g:axsm:l:o:q:z');

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $file = $opt_i;
my $project_name = $opt_p;
my $project_year = $opt_y;
my $population_name = $opt_g;
my $map_protocol_name = $opt_m;
my $location = $opt_l;
my $organism_genus = $opt_o;
my $organism_species = $opt_q;


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

my $dbh = CXGN::DB::InsertDBH->new({ 
    dbhost=>$dbhost,
    dbname=>$dbname,
    dbargs => {AutoCommit => 1, RaiseError => 1}
});

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

my $accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type');
my $population_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema, 'training population', 'stock_type');
my $igd_number_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'igd number', 'genotype_property');
my $geno_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_experiment', 'experiment_type');
my $snp_genotype = SGN::Model::Cvterm->get_cvterm_row($schema, 'snp genotyping', 'genotype_property');
my $population_members = SGN::Model::Cvterm->get_cvterm_row($schema, 'member_of', 'stock_relationship');

my $vcf_map_details = $schema->resultset("Cv::Cvterm")->create_with({
    name => 'vcf_map_details',
    cv   => 'protocol_property',
});
    
#store a project
my $project = $schema->resultset("Project::Project")->find_or_create({
    name => $opt_p,
    description => $opt_p,
});
$project->create_projectprops( { 'project year' => $opt_y }, { autocreate => 1 } );

#store Map name using protocol
my $protocol_row = $schema->resultset("NaturalDiversity::NdProtocol")->find_or_create({
    name => $map_protocol_name,
    type_id => $geno_cvterm->cvterm_id
});
my $protocol_id = $protocol_row->nd_protocol_id();

#store location info
my $geolocation = $schema->resultset("NaturalDiversity::NdGeolocation")->find_or_create({
    description =>$location,
});

#store organism info
my $organism = $schema->resultset("Organism::Organism")->find_or_create({
    genus   => $organism_genus,
    species => $organism_species,
});
my $organism_id = $organism->organism_id();


print STDERR "Reading genotype information...\n";
my $gtio = CXGN::GenotypeIO->new( { file => $file, format => "vcf" });

my $coderef = sub {
    
    my %protocolprop_json;
    my %genotypeprop_accessions;
    
    my $accessions = $gtio->accessions();
    
    while (my ($marker_info, $values) = $gtio->next_vcf_row() ) {
        
        #print STDERR Dumper $marker_info;
        
        #As it goes down the rows, it appends the info from cols 0-8 into the protocolprop json object.
        my %marker = (
            chromosome => $marker_info->[0],
            position => $marker_info->[1],
            ref => $marker_info->[3],
            alt => $marker_info->[4],
            qual => $marker_info->[5],
            filter => $marker_info->[6],
            info => $marker_info->[7],
            format => $marker_info->[8],
        );
        $protocolprop_json{$marker_info->[2]} = \%marker;
        
        #As it goes down the rows, it contructs a separate json object for each accession column. They are all stored in the %genotypeprop_accessions. Later this hash is iterated over and actually stores the json object in the database. 
        for (my $i = 0; $i < scalar(@$accessions); $i++ ) {
            my @format =  split /:/,  $marker_info->[8];
            my @fvalues = split /:/, $values->[$i];
            
            my %value;
            for (my $fv = 0; $fv < scalar(@format); $fv++ ) {
                $value{@format[$fv]} = @fvalues[$fv]; 
            }
            $genotypeprop_accessions{$accessions->[$i]}->{$marker_info->[2]} = \%value;
        }
    
    }
    
    #Save the protocolprop. This json string contains the details for the maarkers used in the map.
    my $json_obj = JSON::Any->new;
    my $json_string = $json_obj->encode(\%protocolprop_json);
    my $add_protocolprop = $schema->resultset("NaturalDiversity::NdProtocolprop")->create({ nd_protocol_id => $protocol_id, type_id => $vcf_map_details->cvterm_id(), value => $json_string });
    
    foreach (@$accessions) {
        
        my ($accession_name, $igd_number) = split(/:/, $_);
        
        print STDERR "Looking for accession $accession_name\n";
        my $stock;
        my $stock_name;
        my $stock_rs = $schema->resultset("Stock::Stock")->search({ 'lower(me.uniquename)' => { like => lc($accession_name) } });
    
        if ($stock_rs->count() == 0) {
        
            print STDERR "No uniquename found for $accession_name, checking synonyms...\n";
            $stock_rs = $schema->resultset("Stock::Stock")->search({
                -and => [
                    'lower(type.name)'       => { like => '%synonym%' },
                    'lower(stockprops.value)' => { like => lc($accession_name) },
                ],
            },
            {   join => { 'stockprops' => 'type'} ,
                distinct => 1
            });
        }

        if ($stock_rs->count() >1 ) {
            print STDERR "ERROR: found multiple accession synonyms found for that accession name, skipping $accession_name! \n";
            while ( my $st = $stock_rs->next) {
                print STDERR "stock name = " . $st->uniquename . "\n";
            }
            next();
        }

        if ($stock_rs->count() == 1) { 
            $stock = $stock_rs->first();
            $stock_name = $stock->uniquename();   
        }

        if ($stock_rs->count ==0)  {
            print STDERR "No synonym was found for $accession_name\n";

            #store the plant accession in the stock table if $opt_a
            if (!$opt_a) {
                print STDERR "WARNING! Accession $accession_name (using: $accession_name) not found.\n";
                print STDERR "Use option -a to add automatically.\n";
                next();
            } else {
                $stock = $schema->resultset("Stock::Stock")->create({
                    organism_id => $organism_id,
                    name       => $accession_name,
                    uniquename => $accession_name,
                    type_id     => $accession_cvterm->cvterm_id,
                });
            }
        }

        my $population_stock = $schema->resultset("Stock::Stock")->find_or_create({
            organism_id => $organism_id,
            name       => $population_name,
            uniquename => $population_name,
            type_id => $population_cvterm->cvterm_id,
        });

        my $has_rel_rs = $schema->resultset("Stock::StockRelationship")->search({
            type_id => $population_members->cvterm_id(),
            subject_id => $stock->stock_id(),
            object_id => $population_stock->stock_id(),
        });

        if ($has_rel_rs->count() == 0) { 
            $stock->find_or_create_related('stock_relationship_objects', {
                type_id => $population_members->cvterm_id(),
                subject_id => $stock->stock_id(),
                object_id => $population_stock->stock_id(),
            });
        }

        print STDERR "Stock name = " . $stock->name . "\n";
        my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')->create({
            nd_geolocation_id => $geolocation->nd_geolocation_id(),
            type_id => $geno_cvterm->cvterm_id(),
        });

        print STDERR "Linking to protocol...\n";
        my $nd_experiment_protocol = $schema->resultset('NaturalDiversity::NdExperimentProtocol')->create({
            nd_experiment_id => $experiment->nd_experiment_id(),
            nd_protocol_id => $protocol_id,
        });

        #link to the project
        $experiment->find_or_create_related('nd_experiment_projects', {
            project_id => $project->project_id()
        });
        
        #link the experiment to the stock
        $experiment->find_or_create_related('nd_experiment_stocks' , {
            stock_id => $stock->stock_id(),
            type_id  =>  $geno_cvterm->cvterm_id(),
        });


        if ($opt_x) { 
            print STDERR "OPTION -x: REMOVING OLD GENOTYPE... \n";
            my $has_genotype_rs =  $schema->resultset('NaturalDiversity::NdExperimentStock')->search_related('nd_experiment')->search_related('nd_experiment_genotypes')->search_related('genotype')->search_related('genotypeprops')->search( { 'me.stock_id' => $stock->stock_id() }); 
        
            while (my $has_genotype = $has_genotype_rs->next()) { 
                print STDERR "Note: -x option: removing already present genotype for $accession_name.\n";
                my $genotypeprop_rs = $schema->resultset('Genetic::Genotypeprop')->search({ genotype_id => $has_genotype->genotype_id() });
                
                while (my $genotypeprop = $genotypeprop_rs->next()) { 
                    print STDERR "DELETING GENOTYPE PROP ".$genotypeprop->genotypeprop_id()."\n";		
                    $genotypeprop->delete();
                }
                
                my $genotype = $schema->resultset('Genetic::Genotypeprop')->search({ 'me.genotype_id' => $has_genotype->genotype_id(),  });

                print STDERR "DELETING GENOTYPE: ".$has_genotype->genotype_id()."\n";
                $genotype->delete();
        
            }
        }
        
        print STDERR "Storing new genotype for stock " . $stock->name . " \n\n";
        my $genotype = $schema->resultset("Genetic::Genotype")->find_or_create({
                name        => $stock->name . "|" . $experiment->nd_experiment_id,
                uniquename  => $stock->name . "|" . $experiment->nd_experiment_id,
                description => "SNP genotypes for stock " . "(name = " . $stock->name . ", id = " . $stock->stock_id . ")",
                type_id     => $snp_genotype->cvterm_id,
        });
        
        my $json_obj = JSON::Any->new;
        my $genotypeprop_json = $genotypeprop_accessions{$_};
        #print STDERR Dumper \%genotypeprop_accessions;
        my $json_string = $json_obj->encode($genotypeprop_json);
        
        #Store json for genotype. Has all markers and scores for this stock.
        $genotype->create_genotypeprops( { 'snp genotyping' => $json_string } , {autocreate =>1 , allow_duplicate_values => 1 } );
        
        #Store IGD number if the option is given.
        if ($opt_z) {
            $genotype->create_genotypeprops( { 'igd number' => $igd_number } , {autocreate =>1 , allow_duplicate_values => 1 } );
        }
        
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
    
    
    