#!/usr/bin/perl

=head1
load_genotypes_vcf_cxgn_postgres.pl - loading genotypes into cxgn databases, based on the load_cassava_snps.pl script by Naama.

=head1 SYNOPSIS
    Example for Uploading VCF:
        perl bin/load_genotypes_vcf_cxgn_postgres.pl -H localhost -D fixture -U postgres -c VCF -o /tmp/transposevcf.txt -i /home/vagrant/Documents/cassava_subset_108KSNP_10acc.vcf -r /archive_path/ -R /home/production/cxgn -g "test_pop_01" -p "test_project_01" -d "Diversity study" -y 2016 -l "test_location" -n "IGD" -b "accession" -m "test_protocol_01_new" -k "protocol description" -q "Manihot esculenta" -e "IITA" -z -u nmorales -f "Mesculenta_511_v7" -B /tmp/SQLCOPY.csv -A

    Example for Uploading Tassel HDF5:
        perl bin/load_genotypes_vcf_cxgn_postgres.pl -H breedbase_db -D empty_fixture -U postgres -c VCF -o ~/transposevcf.txt -v ~/convertvcf.vcf -s t/data/genotype_data/testset_GT-AD-DP-GQ-DS-PL.h5 -r /archive_path/ -R /home/production/cxgn -g "test_pop_01" -p "test_genoproject_01" -d "Diversity study" -y 2016 -l "test_location" -n "IGD" -b "accession" -m "test_protocol_01_new" -k "protocol description" -q "Manihot esculenta" -e "Breedbase" -z -u janedoe -f "Mesculenta_511_v7" -B ~/SQLCOPY1.csv -A

    If you are loading a "transposed VCF" use -c transposedVCF otherwise for a normal VCF use -c VCF. When using a normal VCF, give a temporary file using -o for where this script will transpose your VCF. VCF are transposed for speed.
    To use an existing project (not create a new project name entry), use -h project_id
    To use an existing protocol (not create a new nd_protocol name entry), use -j protocol_id

perl bin/load_genotypes_vcf_cxgn_postgres.pl -H localhost -D imagebreedv4 -U postgres -c VCF -o /data/tmp/www-data/SGN-site/tmp/transposevcf.txt -v /data/tmp/www-data/SGN-site/tmp/convertvcf.vcf -s ~/g2f_2017_ZeaGBSv27_Imputed_AGPv4.h5 -r /data/prodv4/archive/41/genotype_tassel_hdf5_upload/tmp/ -R /home/nmorales/cxgn -g "G2F_GBS_2017_population" -p "G2F_Genotyping_2017" -d "https://datacommons.cyverse.org/browse/iplant/home/shared/commons_repo/curated/GenomesToFields_2014_2017_v1/G2F_Planting_Season_2017_v1/d._2017_genotypic_data/g2f_2017_ZeaGBSv27_Imputed_AGPv4.h5" -y 2017 -l "Cornell Biotech" -n "IGD" -b "accession" -m "G2F_GBS_2017" -k "https://datacommons.cyverse.org/browse/iplant/home/shared/commons_repo/curated/GenomesToFields_2014_2017_v1/G2F_Planting_Season_2017_v1/d._2017_genotypic_data/g2f_2017_ZeaGBSv27_Imputed_AGPv4.h5" -q "Zea mays" -e "G2F" -z -u nickmorales -f "ZeaGBSv27_Imputed_AGPv4" -B /data/tmp/www-data/SGN-site/tmp/SQLCOPY.csv -A

=head1 COMMAND-LINE OPTIONS
  ARGUMENTS
 -H host name (required) e.g. "localhost"
 -D database name (required) e.g. "cxgn_cassava"
 -U database username (required)
 -c VCF file type. transposedVCF or VCF (when uploading Tassel HDF5, this should be VCF)
 -o temporary file for transposing a VCF. whenever a VCF is used, it is transposed for speed (unless option w is flagged).
 -v temporary file for converting Tassel HDF5 to VCF. whenever a Tassel HDF5 (-s) file is uploaded it is coverted to a VCF.
 -i path to infile VCF (either i or s is required)
 -s path to infile Tassel HDF5 (either i or s is required)
 -r archive path (required)
 -R root path (required) (e.g. /home/production/cxgn)
 -u username in database (required)
 -p project name (required) e.g. "SNP genotyping 2012 Cornell Biotech".  Will be found or created in Project table.
 -y project year (required) e.g. "2012".  Will be saved as a Projectprop.
 -d project description (required) e.g. "Diversity study"
 -n genotype facility name (required) e.g. "igd"
 -g population name (required) e.g. "NaCRRI training population"
 -b observation unit type name (required) e.g. "tissue_sample" or "accession" or "stocks"
 -e breeding program name (required) e.g. "IITA"
 -m protocol name (required) e.g. "GBS ApeKI Cassava genome v6"
 -k protocol description (required)
 -l location name (required) e.g. "Cornell Biotech".  Will be found or created in NdGeolocation table.
 -q organism species name (required) e.g. "Manihot esculenta".
 -f reference genome name (required) e.g. "Mesculenta_511_v7"
 -B temporary file where the SQL COPY file is written. make sure this is a fresh file between loadings.

 -h project_id (Will associate genotype data to an existing project_id)
 -j protocol_id (Will associate genotype data to an existing nd_protocol_id)
 -T cvterm for genotype data in the vcf file (either 'vcf_snp_genotypying'' or 'vcf_phg_genotyping''). Default is vcf_snp_genotyping. vcf_phg_genotyping refers to Practical Haplotype Graph (PHG) type of genotype vcf data file.

  FLAGS
 -x delete old genotypes for accessions that have new genotypes
 -a add accessions that are not in the database
 -z if sample names include an IGD number. sample names are in format 'sample_name:IGD_number'. The IGD number will be parsed and stored as a genotypeprop.
 -t Test run . Rolling back at the end. NOT IMPLEMENTED
 -w in the case that you have uploaded a normal VCF and you do not want to transpose it (because the transposition is memory intensive), use this flag
 -A accept warnings and continue with the storing. warnings are whether the samples already have genotype scores for a specific protocol/project

=head1 DESCRIPTION
This script loads genotype data into the Chado genotype table it encodes the genotype + marker name in a json format in the genotyope.uniquename field for easy parsing by a Perl program. The genotypes are linked to the relevant stock using nd_experiment_genotype. Each column in the spreadsheet, which represents a single accession (stock) is stored as a single genotype entry and linked to the stock via nd_experiment_genotype. Stock names are stored in the stock table if cannot be found, and linked to a population stock with the name supplied in opt_g. Map details (chromosome, position, ref, alt, qual, filter, info, and format) are stored in json format in the protocolprop table.

This script mimics exactly the "online process" in SGN::Controller::AJAX::GenotypesVCFUpload->upload_genotype_verify

Can use a transposedVCF or normal VCF

=head1 AUTHOR
 Nicolas Morales (nm529@cornell.edu)
 Lukas Mueller <lam87@cornell.edu>
=cut

use strict;
use warnings;

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
use Sort::Versions;
use SGN::Model::Cvterm;
use CXGN::Genotype::StoreVCFGenotypes;
use DateTime;
use CXGN::UploadFile;
use File::Basename qw | basename dirname|;
use CXGN::Genotype::Protocol;
use CXGN::Genotype::ParseUpload;

our ($opt_H, $opt_D, $opt_U, $opt_c, $opt_o, $opt_v, $opt_r, $opt_R, $opt_i, $opt_s, $opt_t, $opt_p, $opf_f, $opt_y, $opt_g, $opt_a, $opt_x, $opt_m, $opt_k, $opt_l, $opt_q, $opt_z, $opt_u, $opt_b, $opt_n, $opt_e, $opt_f, $opt_d, $opt_h, $opt_j, $opt_w, $opt_A, $opt_B, $opt_T);

getopts('H:U:i:s:r:R:u:c:o:v:tD:p:y:g:axsm:k:l:q:zf:d:b:n:e:h:j:wAB:T:');

if ($opt_j && !$opt_h && (!$opt_H || !$opt_U || !$opt_D || !$opt_c || (!$opt_i && !$opt_s) || !$opt_p || !$opt_y || !$opt_l || !$opt_q || !$opt_r || !$opt_R || !$opt_u || !$opt_f || !$opt_d || !$opt_b || !$opt_n || !$opt_e || !$opt_B) ) {
    pod2usage(-verbose => 2, -message => "When a protocol id is given (-j) you must provide options -H (hostname), -D (database name), -U (database username), -c VCF file type (transposedVCF or VCF), -i (input file VCF) or -s (input file Tassel HDF5), -r (archive path), -R (root path), -p (project name), -y (project year), -l (location name of project), -q (organism species), -u (database username), -f (reference genome name), -d (project description), -b (observation unit type name), -n (genotype facility name), -e (breeding program name), -B (temp file where SQL COPY is written. make sure thi file is a fresh file between loadings.)\n");
}
elsif ($opt_h && !$opt_j && (!$opt_H || !$opt_U || !$opt_D || !$opt_c || (!$opt_i && !$opt_s) || !$opt_m || !$opt_k || !$opt_l || !$opt_q || !$opt_r || !$opt_R || !$opt_u || !$opt_f || !$opt_b || !$opt_n || !$opt_e || !$opt_B) ) {
    pod2usage(-verbose => 2, -message => "When a project id is given (-h) you must provide options -H (hostname), -D (database name), -U (database username), -c VCF file type (transposedVCF or VCF), -i (input file VCF) or -s (input file Tassel HDF5), -r (archive path), -R (root path), -l (location name of project), -m (protocol name), -k (protocol description), -q (organism species), -u (database username), -f (reference genome name), -b (observation unit type name), -n (genotype facility name), -e (breeding program name), -B (temp file where SQL COPY is written. make sure this is a fresh file between loadings.)\n");
}
elsif ($opt_j && $opt_h && (!$opt_H || !$opt_U || !$opt_D || !$opt_c || (!$opt_i && !$opt_s) || !$opt_l || !$opt_q || !$opt_r || !$opt_R || !$opt_u || !$opt_f || !$opt_b || !$opt_n || !$opt_e || !$opt_B) ) {
    pod2usage(-verbose => 2, -message => "When a protocol id is given (-j) And a project id is given (-h) you must provide options -H (hostname), -D (database name), -U (database username), -c VCF file type (transposedVCF or VCF), -i (input file VCF) or -s (input file Tassel HDF5), -r (archive path), -R (root path), -l (location name of project), -q (organism species), -u (database username), -f (reference genome name), -b (observation unit type name), -n (genotype facility name), -e (breeding program name), -B (temp file where SQL COPY is written. make sure thi file is a fresh file between loadings.)\n");
}
elsif (!$opt_j && !$opt_h && (!$opt_H || !$opt_U || !$opt_D || !$opt_c || (!$opt_i && !$opt_s) || !$opt_p || !$opt_y || !$opt_m || !$opt_k || !$opt_l || !$opt_q || !$opt_r || !$opt_R || !$opt_u || !$opt_f || !$opt_d || !$opt_b || !$opt_n || !$opt_e || !$opt_B) ){
    pod2usage(-verbose => 2, -message => "Must provide options -H (hostname), -D (database name), -U (database username), -c VCF file type (transposedVCF or VCF), -i (input file VCF) or -s (input file Tassel HDF5), -r (archive path), -R (root path), -p (project name), -y (project year), -l (location name of project), -m (protocol name), -k (protocol description), -q (organism species), -u (database username), -f (reference genome name), -d (project description), -b (observation unit type name), -n (genotype facility name), -e (breeding program name), -B (temp file where SQL COPY is written. make sure this is a fresh file between loadings.)\n");
}

if ($opt_s && !$opt_v) {
    pod2usage(-verbose => 2, -message => "If a Tassel HDF5 file is uploaded (-s), then a temporary file for coverting to VCF is required (-v)\n");
}

if ($opt_c ne 'transposedVCF' && $opt_c ne 'VCF') {
    die "Not a valid option c\n";
}

if ($opt_c eq 'VCF '&& !$opt_o) {
    die "When uploading a VCF e.g. option c is VCF, you must give a temporary file using option o, so that this script can transpose your file before loading. All VCF are transposed for speed of loading.\n";
}

my $file = $opt_i;
my $protocol_id = $opt_j;
my $organism_species = $opt_q;
my $reference_genome_name = $opt_f;
my $obs_type = $opt_b;
my $add_accessions = 0;
if ($opt_a){
    $add_accessions = 1;
}
my $include_igd_numbers = 0;
if ($opt_z){
    $include_igd_numbers = 1;
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

if ($opt_s) {
    my $cmd = "perl ".$opt_R."/tassel-5-standalone/run_pipeline.pl -Xmx12g -h5 ".$opt_s." -export ".$opt_v." -exportType VCF";
    print STDERR Dumper $cmd;
    my $status = system($cmd);
    $file = $opt_v;
}

if ($opt_c eq 'VCF' && !$opt_w) {
    open (my $Fout, ">", $opt_o) || die "Can't open file $opt_o\n";
    open (my $F, "<", $file) or die "Can't open file $file \n";
    my @outline;
    my $lastcol = 0;
    while (<$F>) {
        if ($_ =~ m/^\##/) {
            print $Fout $_;
        } else {
            chomp;
            my @line = split /\t/;
            my $oldlastcol = $lastcol;
            $lastcol = $#line if $#line > $lastcol;
            for (my $i=$oldlastcol; $i < $lastcol; $i++) {
                $outline[$i] = "\t" x $oldlastcol;
            }
            for (my $i=0; $i <=$lastcol; $i++) {
                $outline[$i] .= "$line[$i]\t"
            }
        }
    }
    for (my $i=0; $i <= $lastcol; $i++) {
        $outline[$i] =~ s/\s*$//g;
        print $Fout $outline[$i]."\n";
    }
    close($F);
    close($Fout);
    $file = $opt_o;
    $opt_c = 'transposedVCF';
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

#if protocol_id provided, a new one will not be created
if ($protocol_id){
    my $protocol = CXGN::Genotype::Protocol->new({
        bcs_schema => $schema,
        nd_protocol_id => $protocol_id
    });
    $organism_species = $protocol->species_name;
    $obs_type = $protocol->sample_observation_unit_type_name if !$obs_type;
}

my $organism_q = "SELECT organism_id FROM organism WHERE species = ?";
my @found_organisms;
$h = $schema->storage->dbh()->prepare($organism_q);
$h->execute($organism_species);
while (my ($organism_id) = $h->fetchrow_array()){
    push @found_organisms, $organism_id;
}
if (scalar(@found_organisms) == 0){
    print STDERR "The organism species you provided is not in the database! Please contact us.\n";
    die;
}
if (scalar(@found_organisms) > 1){
    print STDERR "The organism species you provided is not unique in the database! Please contact us.\n";
    die;
}
my $organism_id = $found_organisms[0];

my $parser = CXGN::Genotype::ParseUpload->new({
    chado_schema => $schema,
    filename => $archived_filename_with_path,
    observation_unit_type_name => $obs_type,
    organism_id => $organism_id,
    create_missing_observation_units_as_accessions => $add_accessions,
    igd_numbers_included => $include_igd_numbers
});

$parser->load_plugin($opt_c);
my $parser_return = $parser->parse_with_iterator();
if ($parser->get_parse_errors()) {
    my $parse_errors = $parser->get_parse_errors();
    print STDERR Dumper $parse_errors;
    die("parse errors");
}

my $project_id;
my $protocol = $parser->protocol_data();
my $observation_unit_names_all = $parser->observation_unit_names();
$protocol->{'reference_genome_name'} = $reference_genome_name;
$protocol->{'species_name'} = $organism_species;

my $vcf_genotyping_type = $opt_T ? $opt_T : 'vcf_snp_genotyping';
# my $genotyping_type;
my $genotype_data_type;

if ($vcf_genotyping_type =~ /vcf_phg_genotyping/) {
    $genotype_data_type = 'PHG';
} else {
    $genotype_data_type = 'SNP';
}

my $store_args = {
    bcs_schema=>$schema,
    metadata_schema=>$metadata_schema,
    phenome_schema=>$phenome_schema,
    observation_unit_type_name=>$obs_type,
    observation_unit_uniquenames=> $observation_unit_names_all,
    accession_population_name=>$opt_g,
    project_id=>$opt_h,
    genotyping_facility=>$opt_n, #projectprop
    breeding_program_id=>$breeding_program_id, #project_rel
    project_year=>$opt_y, #projectprop
    project_location_id=>$location_id, #ndexperiment and projectprop
    project_name=>$opt_p, #project_attr
    project_description=>$opt_d, #project_attr
    protocol_id => $protocol_id,
    protocol_name=>$opt_m,
    protocol_description=>$opt_k,
    protocol_name => $opt_m,
    organism_id=>$organism_id,
    igd_numbers_included=>$include_igd_numbers,
    user_id=>$sp_person_id,
    archived_filename=>$archived_filename_with_path,
    archived_file_type=>'genotype_vcf', #can be 'genotype_vcf' or 'genotype_dosage' to disntiguish genotyprop between old dosage only format and more info vcf format
    temp_file_sql_copy=>$opt_B,
    genotyping_data_type=> $genotype_data_type,
    vcf_genotyping_type => $vcf_genotyping_type,
};

if ($opt_c eq 'VCF') {
    $store_args->{marker_by_marker_storage} = 1;
}

my $store_genotypes;
my ($observation_unit_names, $genotype_info) = $parser->next();
if (scalar(keys %$genotype_info) > 0) {
    print STDERR "Parsing first genotype and extracting protocol info... \n";

    $store_args->{protocol_info} = $protocol;
    $store_args->{genotype_info} = $genotype_info;

    $store_genotypes = CXGN::Genotype::StoreVCFGenotypes->new($store_args);
    my $verified_errors = $store_genotypes->validate();
    if (scalar(@{$verified_errors->{error_messages}}) > 0){
        print STDERR Dumper $verified_errors;
        print STDERR Dumper "There exist errors in your file. Not storing!\n";
        die;
    }
    if (scalar(@{$verified_errors->{warning_messages}}) > 0){
        my $warning_string = join "\n", @{$verified_errors->{warning_messages}};
        if (!$opt_A){
            print STDERR Dumper $warning_string;
            print STDERR "You can accept these warnings and continue with store if you use -A\n";
            die;
        }
    }

    my @protocol_match_errors;
    if ($protocol_id) {
        my $new_marker_data = $protocol->{markers};
        my $stored_protocol = CXGN::Genotype::Protocol->new({
            bcs_schema => $schema,
            nd_protocol_id => $protocol_id
        });
        my $stored_markers = $stored_protocol->markers();

        my @all_stored_markers = keys %$stored_markers;
        my %compare_marker_names = map {$_ => 1} @all_stored_markers;
        my @mismatch_marker_names;
        while (my ($chrom, $new_marker_data_1) = each %$new_marker_data) {
            while (my ($marker_name, $new_marker_details) = each %$new_marker_data_1) {
                if (exists($compare_marker_names{$marker_name})) {
                    while (my ($key, $value) = each %$new_marker_details) {
                        if ($value ne ($stored_markers->{$marker_name}->{$key})) {
                            push @protocol_match_errors, "Marker $marker_name in your file has $value for $key, but in the previously stored protocol shows ".$stored_markers->{$marker_name}->{$key};
                        }
                    }
                } else {
                    push @mismatch_marker_names, $marker_name;
                }
            }
        }

        if (scalar(@mismatch_marker_names) > 0){
            foreach my $error ( sort @mismatch_marker_names) {
                print STDERR "$error\n";
	    }
	    print STDERR "These marker names in your file are not in the selected protocol.\n";
            die; 
        }

        if (scalar(@protocol_match_errors) > 0){
            my $protocol_warning;
            foreach my $match_error (@protocol_match_errors) {
                $protocol_warning .= "$match_error\n";
            }
            if (!$opt_A){
                print STDERR Dumper $protocol_warning;
		print STDERR "Protocol match error\n";
                die;
            }
        }
    }

    $store_genotypes->store_metadata();
    my $result = $store_genotypes->store_identifiers();
    $protocol_id = $result->{nd_protocol_id};
    $project_id = $result->{project_id};

    # Rebuild and refresh the materialized_markerview table
    my $basepath = dirname(__FILE__);
    my $async_refresh = CXGN::Tools::Run->new();
    $async_refresh->run_async("perl $basepath/refresh_materialized_markerview.pl -H $opt_H -D $opt_D -U $opt_U -P $pw");
}

print STDERR "Done loading first sample, moving on...\n";    

my $continue_iterate = 1;
while ($continue_iterate == 1) {
    my ($observation_unit_names, $genotype_info) = $parser->next();
    if (scalar(keys %$genotype_info) > 0) {
        print STDERR "parsing next... ";

        $store_genotypes->genotype_info($genotype_info);
        $store_genotypes->observation_unit_uniquenames($observation_unit_names);
        $store_genotypes->store_identifiers();
        print STDERR "Successfully stored genotype.\n";
    } else {
        $continue_iterate = 0;
        last;
    }
}
my $return = $store_genotypes->store_genotypeprop_table();

print STDERR "Complete!\n";
