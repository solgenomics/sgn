#!/usr/bin/perl

=head1
load_genotypes_vcf_cxgn_postgres.pl - loading genotypes into cxgn databases, based on the load_cassava_snps.pl script by Naama.

=head1 SYNOPSIS
    perl bin/load_genotypes_vcf_cxgn_postgres.pl -H localhost -D fixture -U postgres -i /home/vagrant/Documents/cassava_subset_108KSNP_10acc.vcf -r /archive_path/ -g "test_pop_01" -p "test_project_01" -d "Diversity study" -y 2016 -l "BTI" -n "IGD" -b "accession" -m "test_protocol_01_new" -o "Manihot" -q "Manihot esculenta" -e "IITA" -s -u nmorales -f "Mesculenta_511_v7"
    
    To use an existing project (not create a new project name entry), use -h project_id
    To use an existing protocol (not create a new nd_protocol name entry), use -j protocol_id

=head1 COMMAND-LINE OPTIONS
  ARGUMENTS
 -H host name (required) e.g. "localhost"
 -D database name (required) e.g. "cxgn_cassava"
 -U database username (required)
 -i path to infile (required)
 -r archive path (required)
 -u username in database (required)
 -p project name (required) e.g. "SNP genotyping 2012 Cornell Biotech".  Will be found or created in Project table.
 -y project year (required) e.g. "2012".  Will be saved as a Projectprop.
 -d project description (required) e.g. "Diversity study"
 -n genotype facility name (required) e.g. "igd"
 -g population name (required) e.g. "NaCRRI training population"
 -b observation unit name (required) e.g. "tissue_sample" or "accession"
 -e breeding program name (required) e.g. "IITA"
 -s include igd numbers in sample names
 -m protocol name (required) e.g. "GBS ApeKI Cassava genome v6"
 -l location name (required) e.g. "Cornell Biotech".  Will be found or created in NdGeolocation table.
 -o organism genus name (required) e.g. "Manihot".  Along with organism species name, this will be found or created in Organism table.
 -q organism species name (required) e.g. "Manihot esculenta".
 -f reference genome name (required) e.g. "Mesculenta_511_v7"

 -h project_id (Will associate genotype data to an existing project_id)
 -j protocol_id (Will associate genotype data to an existing nd_protocol_id)

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
use File::Basename qw | basename dirname|;

our ($opt_H, $opt_D, $opt_U, $opt_r, $opt_i, $opt_t, $opt_p, $opf_f, $opt_y, $opt_g, $opt_a, $opt_x, $opt_v, $opt_s, $opt_m, $opt_l, $opt_o, $opt_q, $opt_z, $opt_u, $opt_b, $opt_n, $opt_s, $opt_e, $opt_f, $opt_d, $opt_h, $opt_j);

getopts('H:U:i:r:u:tD:p:y:g:axsm:l:o:q:zf:d:b:n:se:h:j:');

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $file = $opt_i;

if (!$opt_H || !$opt_U || !$opt_D || !$opt_i || !$opt_p || !$opt_y || !$opt_m || !$opt_l || !$opt_o || !$opt_q || !$opt_r || !$opt_u || !$opt_f || !$opt_d || !$opt_b || !$opt_n || !$opt_e) {
    pod2usage(-verbose => 2, -message => "Must provide options -H (hostname), -D (database name), -U (database username), -i (input file), -r (archive path), -p (project name), -y (project year), -l (location name of project), -m (protocol name), -o (organism genus), -q (organism species), -u (database username), -f (reference genome name), -d (project description), -b (observation unit name), -n (genotype facility name), -e (breeding program name)\n");
}

print "Password for $opt_H / $opt_D: \n";
my $pw = <>;
chomp($pw);

print STDERR "Connecting to database...\n";
my $dsn = 'dbi:Pg:database='.$opt_D.";host=".$opt_H.";port=5432";

my $schema = Bio::Chado::Schema->connect($dsn, $opt_U, $pw);
$schema->storage->dbh->do('SET search_path TO public,sgn');
my $dbh = $schema->storage->dbh;
my $metadata_schema = CXGN::Metadata::Schema->connect($dsn, $opt_U, $pw);
$metadata_schema->storage->dbh->do('SET search_path TO metadata');
my $phenome_schema = CXGN::Phenome::Schema->connect($dsn, $opt_U, $pw);
$phenome_schema->storage->dbh->do('SET search_path TO phenome');

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
   archive_path => $opt_r,
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

my $location_rs = $schema->resultset('NaturalDiversity::NdGeolocation')->search({description => $opt_l});
my $location_id;
if ($location_rs->count != 1){
    print STDERR "Location not valid in database\n";
    die;
} else {
    $location_id = $location_rs->first->nd_geolocation_id;
}

my $bp_rs = $schema->resultset('Project::Project')->search({name => $opt_e});
my $breeding_program_id;
if ($bp_rs->count != 1){
    print STDERR "Breeding program not valid in database\n";
    die;
} else {
    $breeding_program_id = $bp_rs->first->project_id;
}

my $store_genotypes = CXGN::Genotype::StoreVCFGenotypes->new({
    bcs_schema=>$schema,
    metadata_schema=>$metadata_schema,
    phenome_schema=>$phenome_schema,
    vcf_input_file=>$archived_filename_with_path,
    observation_unit_type_name=>$opt_b,
    genotyping_facility=>$opt_n,
    breeding_program_id=>$breeding_program_id,
    project_year=>$opt_y,
    project_location_id=>$location_id,
    project_name=>$opt_p,
    project_description=>$opt_d,
    protocol_name=>$opt_m,
    organism_genus=>$opt_o,
    organism_species=>$opt_q,
    create_missing_observation_units_as_accessions=>$opt_a,
    accession_population_name=>$opt_g,
    igd_numbers_included=>$opt_s,
    reference_genome_name=>$opt_f,
    user_id=>$sp_person_id,
    project_id=>$opt_h,
    protocol_id=>$opt_j
});
my $verified_errors = $store_genotypes->validate();
if (scalar(@{$verified_errors->{error_messages}}) > 0){
    print STDERR Dumper $verified_errors->{error_messages};
} else {
    my $return = $store_genotypes->store();
}

print STDERR "Complete!\n";
