#!/usr/bin/perl

=head1
load_genotypes_vcf_cxgn_postgres.pl - loading genotypes into cxgn databases, based on the load_cassava_snps.pl script by Naama.

=head1 SYNOPSIS
    perl bin/load_genotypes_vcf_cxgn_postgres.pl -H localhost -D fixture -i /home/vagrant/Documents/cassava_subset_108KSNP_10acc.vcf -r /archive_path/ -g "test_pop_01" -p "test_project_01" -y 2016 -l "BTI" -m "test_protocol_01_new" -o "Manihot" -q "Manihot esculenta" -u nmorales

=head1 COMMAND-LINE OPTIONS
  ARGUMENTS
 -H host name (required) e.g. "localhost"
 -D database name (required) e.g. "cxgn_cassava"
 -i path to infile (required)
 -r archive path (required)
 -u username in database (required)
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
use CXGN::Metadata::Schema;
use CXGN::Phenome::Schema;
use CXGN::People::Person;
use CXGN::DB::InsertDBH;
use CXGN::Genotype;
use CXGN::GenotypeIO;
use Sort::Versions;
use SGN::Model::Cvterm;
use CXGN::Genotype::StoreVCFGenotypes;
use DateTime;
use CXGN::UploadFile;

our ($opt_H, $opt_D, $opt_r, $opt_i, $opt_t, $opt_p, $opt_y, $opt_g, $opt_a, $opt_x, $opt_v, $opt_s, $opt_m, $opt_l, $opt_o, $opt_q, $opt_z, $opt_u);

getopts('H:i:r:u:tD:p:y:g:axsm:l:o:q:z');

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

if (!$opt_H || !$opt_D || !$opt_i || !$opt_g || !$opt_p || !$opt_y || !$opt_m || !$opt_l || !$opt_o || !$opt_q || !$opt_r || !$opt_u) {
    pod2usage(-verbose => 2, -message => "Must provide options -H (hostname), -D (database name), -i (input file) , -r (archive path), -g (populations name for associating accessions in your SNP file), -p (project name), -y (project year), -l (location of project), -m (map protocol name), -o (organism genus), -q (organism species) -u (database username)\n");
}

#print "Password for $opt_H / $opt_D: \n";
#my $pw = <>;
#chomp($pw);
my $pw='postgres';

print STDERR "Connecting to database...\n";
my $dsn = 'dbi:Pg:database='.$opt_D.";host=".$opt_H.";port=5432";

my $schema = Bio::Chado::Schema->connect($dsn, "postgres", $pw);
my $dbh = DBI->connect($dsn, "postgres", $pw);
$dbh->do('SET search_path TO public,sgn');
my $metadata_schema = CXGN::Metadata::Schema->connect($dsn, "postgres", $pw);
my $phenome_schema = CXGN::Phenome::Schema->connect($dsn, "postgres", $pw);

my $time = DateTime->now();
my $timestamp = $time->ymd()."_".$time->hms();

my $q = "SELECT sp_person_id from sgn_people.sp_person where username = '$opt_u';";
my $h = $dbh->prepare($q);
$h->execute();
my ($sp_person_id) = $h->fetchrow_array();
if (!$sp_person_id){
    die "Not a valid -u\n";
}

my $uploader = CXGN::UploadFile->new({
   tempfile => $file,
   subdirectory => "genotype_vcf_upload",
   archive_path => $opt_a,
   archive_filename => basename($file),
   timestamp => $timestamp,
   user_id => $sp_person_id,
   user_role => 'curator'
});
my $archived_filename_with_path = $uploader->archive();
my $md5 = $uploader->get_md5($archived_filename_with_path);
if (!$archived_filename_with_path) {
    die "Could not archive file!\n";
} else {
    print STDERR "File saved in archive.\n";
}

my $store_genotypes = CXGN::Genotype::StoreVCFGenotypes->new({
    bcs_schema=>$schema,
    metadata_schema=>$metadata_schema,
    phenome_schema=>$phenome_schema,
    vcf_input_file=>$archived_filename_with_path,
    observation_unit_type_name=>$obs_type,
    genotyping_facility=>$genotyping_facility,
    breeding_program_id=>$breeding_program_id,
    project_year=>$year,
    project_location_id=>$location_id,
    project_name=>$project_name,
    project_description=>$description,
    protocol_name=>$protocol_name,
    organism_genus=>$organism_genus,
    organism_species=>$organism_species,
    create_missing_observation_units_as_accessions=>$add_accessions,
    igd_numbers_included=>$include_igd_numbers,
    reference_genome_name=>$reference_genome_name
});
my $verified_errors = $store_genotypes->validate();
if (scalar(@{$verified_errors->{error_messages}}) > 0){
    print STDERR Dumper $verified_errors->{error_messages};
} else {
    my ($stored_genotype_error, $stored_genotype_success) = $store_genotypes->store();
}

print STDERR "Complete!\n";
