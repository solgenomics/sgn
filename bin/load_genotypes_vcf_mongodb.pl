#!/usr/bin/perl

=head1
load_genotypes_vcf_mongodb.pl - loading genotypes into mongodb databases, based on the load_cassava_snps.pl script by Naama.

=head1 SYNOPSIS
    perl bin/load_genotypes_vcf_mongodb.pl -H localhost -D fixture -i /home/vagrant/Downloads/cassava_subset_108KSNP_10acc.vcf -p testproject -y 2016 -g testpop -m testprotocol -l testlocation -o testgenus -q testspecies

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



=head1 DESCRIPTION

=head1 AUTHOR
 Nicolas Morales (nm529@cornell.edu) May 2016
 Suzi Barboza (smb528)
=cut

use strict;

use MongoDB;
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

our ($opt_H, $opt_D, $opt_i, $opt_p, $opt_y, $opt_g, $opt_m, $opt_l, $opt_o, $opt_q);

getopts('H:i:D:p:y:g:m:l:o:q:');

if (!$opt_H || !$opt_D || !$opt_i || !$opt_p || !$opt_y || !$opt_g || !$opt_m || !$opt_l || !$opt_o || !$opt_q) {
    die "Must provide -H (localhost) -D (fixture) -i (file.vcf) -p (ProjectName) -y (2016) -g (PopulationName) -m (ProtocolName) -l (LocationName) -o (GenusName) -q (SpeciesName)";
}

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

my $client = MongoDB-> connect($dbhost);
my $db = $client-> get_database($dbname);
my $genotype_collection = $db->get_collection('genotype_collection');
my $protocol_collection = $db->get_collection('protocol_collection');

print STDERR "Reading genotype information...\n";
my $gtio = CXGN::GenotypeIO->new( { file => $file, format => "vcf" });

my %protocolprop_json;
my %genotypeprop_accessions;

my $accessions = $gtio->accessions();

while (my ($marker_info, $values) = $gtio->next_vcf_row() ) {

    #print STDERR Dumper $marker_info;

    #As it goes down the rows, it appends the info from cols 0-8 into the protocolprop json object.
    my %marker = (
        chrom => $marker_info->[0],
        pos => $marker_info->[1],
        ref => $marker_info->[3],
        alt => $marker_info->[4],
        qual => $marker_info->[5],
        filter => $marker_info->[6],
        info => $marker_info->[7],
        format => $marker_info->[8],
    );
    if ($marker_info->[2] eq '.') {
        $protocolprop_json{$marker_info->[0]."_".$marker_info->[1]} = \%marker;
    } else {
        $protocolprop_json{$marker_info->[2]} = \%marker;
    }

    #As it goes down the rows, it contructs a separate json object for each accession column. They are all stored in the %genotypeprop_accessions. Later this hash is iterated over and actually stores the json object in the database.
    for (my $i = 0; $i < scalar(@$accessions); $i++ ) {
        my @format =  split /:/,  $marker_info->[8];
        my @fvalues = split /:/, $values->[$i];

        my %value;
        for (my $fv = 0; $fv < scalar(@format); $fv++ ) {
            $value{@format[$fv]} = @fvalues[$fv];
        }

        if ($marker_info->[2] eq '.') {
            $genotypeprop_accessions{$accessions->[$i]}->{$marker_info->[0]."_".$marker_info->[1]} = \%value;
        } else {
            $genotypeprop_accessions{$accessions->[$i]}->{$marker_info->[2]} = \%value;
        }
    }

}

#Save the protocolprop. This json string contains the details for the maarkers used in the map.
my $json_obj = JSON::Any->new;
my $json_string = $json_obj->encode(\%protocolprop_json);

### CREATE Mongodb Protocol Document
my $result = $protocol_collection->insert_one( {
    "project_name" => $project_name,
    "project_year" => $project_year,
    "project_location" => $location,
    "protocol_name" => $map_protocol_name,
    "markers" => $json_string
});
my $protocol_doc_id = $result->inserted_id;


print "Stored Protocol Document (doc_id: $protocol_doc_id) for $map_protocol_name \n";

my $stock_id = 1;
foreach my $accession_name (@$accessions) {

    my $json_obj = JSON::Any->new;
    my $genotypeprop_json = $genotypeprop_accessions{$accession_name};
    #print STDERR Dumper \%genotypeprop_accessions;
    my $json_string = $json_obj->encode($genotypeprop_json);

    ##CREATE Mongodb Genotye Document
    my $result = $genotype_collection->insert_one( {
        "project_name" => $project_name,
        "project_year" => $project_year,
        "project_location" => $location,
        "protocol_name" => $map_protocol_name,
        "protocol_id" => $protocol_doc_id,
        "population_name" => $population_name,
        "genus" => $organism_genus,
        "species" => $organism_species,
        "stock_id" => $stock_id,
        "accession_name" => $accession_name,
        "marker_scores" => $json_string
    });
    my $genotye_doc_id = $result->inserted_id;
    $stock_id++;
    print "Stored Genotype Document (doc_id: $genotye_doc_id) for $accession_name \n";

}

print "Completed!\n";
