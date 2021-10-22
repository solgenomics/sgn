
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use LWP::UserAgent;
use CXGN::Dataset;
use CXGN::Dataset::Cache;
use CXGN::Genotype::Protocol;
use CXGN::Genotype::Search;
use Bio::GeneticRelationships::Pedigree;
use CXGN::Pedigree::AddPedigrees;
use Bio::GeneticRelationships::Individual;
use CXGN::List;

#Needed to update IO::Socket::SSL
use Data::Dumper;
use JSON;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $dbh = $schema->storage->dbh;
my $people_schema = $f->people_schema;

my $mech = Test::WWW::Mechanize->new;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};
print STDERR $sgn_session_id."\n";

my $location_rs = $schema->resultset('NaturalDiversity::NdGeolocation')->search({description => 'Cornell Biotech'});
my $location_id = $location_rs->first->nd_geolocation_id;

my $bp_rs = $schema->resultset('Project::Project')->search({name => 'test'});
my $breeding_program_id = $bp_rs->first->project_id;

print STDERR "Uploading VCF Genotypes\n";

my $file = $f->config->{basepath}."/t/data/genotype_data/testset_GT-AD-DP-GQ-DS-PL.vcf";

#test upload with file where sample names are not in the database
my $ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/genotype/upload',
        Content_Type => 'form-data',
        Content => [
            upload_genotype_vcf_file_input => [ $file, 'genotype_vcf_data_upload' ],
            "sgn_session_id"=>$sgn_session_id,
            "upload_genotypes_species_name_input"=>"Manihot esculenta",
            "upload_genotype_vcf_project_name"=>"Test genotype project",
            "upload_genotype_location_select"=>$location_id,
            "upload_genotype_year_select"=>"2018",
            "upload_genotype_breeding_program_select"=>$breeding_program_id,
            "upload_genotype_vcf_observation_type"=>"accession", #IDEALLY THIS IS "tissue_sample"
            "upload_genotype_vcf_facility_select"=>"IGD",
            "upload_genotype_vcf_project_description"=>"Diversity panel genotype study",
            "upload_genotype_vcf_protocol_name"=>"Cassava GBS v7 2018",
            "upload_genotype_vcf_include_igd_numbers"=>1,
            "upload_genotype_vcf_reference_genome_name"=>"Mesculenta_511_v7",
            "upload_genotype_add_new_accessions"=>0, #IDEALLY THIS is set to 0
        ]
    );

print STDERR Dumper $response;
ok($response->is_success);
my $message = $response->decoded_content;

my $message_hash = decode_json $message;
print STDERR Dumper $message_hash;
is_deeply($message_hash, {'missing_stocks' => ['KBH2014_076','KBH2014_1155','KBH2014_124','KBH2014_1241','KBH2014_1463','KBH2014_286','KBH2014_740','KBH2014_968','KBH2015_080','KBH2015_383','KBH2015_BULK','SRLI1_26','SRLI1_52','SRLI1_66','SRLI1_78','SRLI1_90','SRLI2_33','SRLI2_70','UKG1502_022','UKG1503_004','UKG15OP07_038'],'error_string' => 'The following stocks are not in the database: KBH2014_076,KBH2014_1155,KBH2014_124,KBH2014_1241,KBH2014_1463,KBH2014_286,KBH2014_740,KBH2014_968,KBH2015_080,KBH2015_383,KBH2015_BULK,SRLI1_26,SRLI1_52,SRLI1_66,SRLI1_78,SRLI1_90,SRLI2_33,SRLI2_70,UKG1502_022,UKG1503_004,UKG15OP07_038<br>'});

#test upload with file where sample names are added as accessions automatically
$ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/genotype/upload',
        Content_Type => 'form-data',
        Content => [
            upload_genotype_vcf_file_input => [ $file, 'genotype_vcf_data_upload' ],
            "sgn_session_id"=>$sgn_session_id,
            "upload_genotypes_species_name_input"=>"Manihot esculenta",
            "upload_genotype_vcf_project_name"=>"Test genotype project",
            "upload_genotype_location_select"=>$location_id,
            "upload_genotype_year_select"=>"2018",
            "upload_genotype_breeding_program_select"=>$breeding_program_id,
            "upload_genotype_vcf_observation_type"=>"accession", #IDEALLY THIS IS "tissue_sample"
            "upload_genotype_vcf_facility_select"=>"IGD",
            "upload_genotype_vcf_project_description"=>"Diversity panel genotype study",
            "upload_genotype_vcf_protocol_name"=>"Cassava GBS v7 2018",
            "upload_genotype_vcf_include_igd_numbers"=>1,
            "upload_genotype_vcf_reference_genome_name"=>"Mesculenta_511_v7",
            "upload_genotype_add_new_accessions"=>1, #IDEALLY THIS is set to 0
        ]
    );

#print STDERR Dumper $response;
ok($response->is_success);
$message = $response->decoded_content;
print STDERR "MESSAGE: ".$message;
$message_hash = decode_json $message;
print STDERR Dumper $message_hash;
is($message_hash->{success}, 1);
ok($message_hash->{project_id});
ok($message_hash->{nd_protocol_id});

my $protocol_id = $message_hash->{nd_protocol_id};

#adding genotype data using same protocol as before to different project
$ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/genotype/upload',
        Content_Type => 'form-data',
        Content => [
            upload_genotype_vcf_file_input => [ $file, 'genotype_vcf_data_upload' ],
            "sgn_session_id"=>$sgn_session_id,
            "upload_genotype_protocol_id"=>$protocol_id,
            "upload_genotypes_species_name_input"=>"Manihot esculenta",
            "upload_genotype_vcf_project_name"=>"Test genotype project2",
            "upload_genotype_location_select"=>$location_id,
            "upload_genotype_year_select"=>"2018",
            "upload_genotype_breeding_program_select"=>$breeding_program_id,
            "upload_genotype_vcf_observation_type"=>"accession", #IDEALLY THIS IS "tissue_sample"
            "upload_genotype_vcf_facility_select"=>"IGD",
            "upload_genotype_vcf_project_description"=>"Diversity panel genotype study",
            "upload_genotype_vcf_include_igd_numbers"=>1,
            "upload_genotype_add_new_accessions"=>1, #IDEALLY THIS is set to 0
        ]
    );

$message = $response->decoded_content;
$message_hash = decode_json $message;
print STDERR Dumper $message_hash;
is_deeply($message_hash, {'previous_genotypes_exist' => 1,'warning' => 'SRLI1_90 in your file has already has genotype stored using the protocol Cassava GBS v7 2018 in the project Test genotype project., SRLI1_66 in your file has already has genotype stored using the protocol Cassava GBS v7 2018 in the project Test genotype project., SRLI1_52 in your file has already has genotype stored using the protocol Cassava GBS v7 2018 in the project Test genotype project., KBH2015_383 in your file has already has genotype stored using the protocol Cassava GBS v7 2018 in the project Test genotype project., KBH2015_BULK in your file has already has genotype stored using the protocol Cassava GBS v7 2018 in the project Test genotype project., KBH2014_076 in your file has already has genotype stored using the protocol Cassava GBS v7 2018 in the project Test genotype project., SRLI2_33 in your file has already has genotype stored using the protocol Cassava GBS v7 2018 in the project Test genotype project., SRLI1_78 in your file has already has genotype stored using the protocol Cassava GBS v7 2018 in the project Test genotype project., KBH2014_1241 in your file has already has genotype stored using the protocol Cassava GBS v7 2018 in the project Test genotype project., KBH2014_968 in your file has already has genotype stored using the protocol Cassava GBS v7 2018 in the project Test genotype project., KBH2014_1155 in your file has already has genotype stored using the protocol Cassava GBS v7 2018 in the project Test genotype project., UKG1503_004 in your file has already has genotype stored using the protocol Cassava GBS v7 2018 in the project Test genotype project., KBH2014_740 in your file has already has genotype stored using the protocol Cassava GBS v7 2018 in the project Test genotype project., KBH2015_080 in your file has already has genotype stored using the protocol Cassava GBS v7 2018 in the project Test genotype project., KBH2014_1463 in your file has already has genotype stored using the protocol Cassava GBS v7 2018 in the project Test genotype project., UKG1502_022 in your file has already has genotype stored using the protocol Cassava GBS v7 2018 in the project Test genotype project., KBH2014_124 in your file has already has genotype stored using the protocol Cassava GBS v7 2018 in the project Test genotype project., SRLI2_70 in your file has already has genotype stored using the protocol Cassava GBS v7 2018 in the project Test genotype project., SRLI1_26 in your file has already has genotype stored using the protocol Cassava GBS v7 2018 in the project Test genotype project., UKG15OP07_038 in your file has already has genotype stored using the protocol Cassava GBS v7 2018 in the project Test genotype project., KBH2014_286 in your file has already has genotype stored using the protocol Cassava GBS v7 2018 in the project Test genotype project.'} );

#adding genotype data using same protocol as before to different project
$ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/genotype/upload',
        Content_Type => 'form-data',
        Content => [
            upload_genotype_vcf_file_input => [ $file, 'genotype_vcf_data_upload' ],
            "sgn_session_id"=>$sgn_session_id,
            "upload_genotype_protocol_id"=>$protocol_id,
            "upload_genotypes_species_name_input"=>"Manihot esculenta",
            "upload_genotype_vcf_project_name"=>"Test genotype project2",
            "upload_genotype_location_select"=>$location_id,
            "upload_genotype_year_select"=>"2018",
            "upload_genotype_breeding_program_select"=>$breeding_program_id,
            "upload_genotype_vcf_observation_type"=>"accession", #IDEALLY THIS IS "tissue_sample"
            "upload_genotype_vcf_facility_select"=>"IGD",
            "upload_genotype_vcf_project_description"=>"Diversity panel genotype study",
            "upload_genotype_vcf_include_igd_numbers"=>1,
            "upload_genotype_add_new_accessions"=>1, #IDEALLY THIS is set to 0
            "upload_genotype_accept_warnings"=>1
        ]
    );

$message = $response->decoded_content;
$message_hash = decode_json $message;
print STDERR Dumper $message_hash;
is($message_hash->{success}, 1);
is($protocol_id, $message_hash->{nd_protocol_id});
my $project_id = $message_hash->{project_id};

#adding genotype data using same project but different protocol
$ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/genotype/upload',
        Content_Type => 'form-data',
        Content => [
            upload_genotype_vcf_file_input => [ $file, 'genotype_vcf_data_upload' ],
            "sgn_session_id"=>$sgn_session_id,
            "upload_genotype_project_id"=>$project_id,
            "upload_genotypes_species_name_input"=>"Manihot esculenta",
            "upload_genotype_location_select"=>$location_id,
            "upload_genotype_vcf_observation_type"=>"accession", #IDEALLY THIS IS "tissue_sample"
            "upload_genotype_vcf_protocol_name"=>"Cassava GBS v7 2019",
            "upload_genotype_vcf_include_igd_numbers"=>1,
            "upload_genotype_vcf_reference_genome_name"=>"Mesculenta_511_v7",
            "upload_genotype_add_new_accessions"=>1, #IDEALLY THIS is set to 0
            "upload_genotype_accept_warnings"=>1
        ]
    );

$message = $response->decoded_content;
$message_hash = decode_json $message;
print STDERR Dumper $message_hash;
is($message_hash->{success}, 1);
is($project_id, $message_hash->{project_id});

#adding genotype data using same project to same protocol
$ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/genotype/upload',
        Content_Type => 'form-data',
        Content => [
            upload_genotype_vcf_file_input => [ $file, 'genotype_vcf_data_upload' ],
            "sgn_session_id"=>$sgn_session_id,
            "upload_genotype_project_id"=>$project_id,
            "upload_genotype_protocol_id"=>$protocol_id,
            "upload_genotypes_species_name_input"=>"Manihot esculenta",
            "upload_genotype_location_select"=>$location_id,
            "upload_genotype_vcf_observation_type"=>"accession", #IDEALLY THIS IS "tissue_sample"
            "upload_genotype_vcf_include_igd_numbers"=>1,
            "upload_genotype_add_new_accessions"=>1, #IDEALLY THIS is set to 0
            "upload_genotype_accept_warnings"=>1
        ]
    );

$message = $response->decoded_content;
$message_hash = decode_json $message;
print STDERR Dumper $message_hash;
is($message_hash->{success}, 1);
is($project_id, $message_hash->{project_id});
is($protocol_id, $message_hash->{nd_protocol_id});

my $genotypes_search = CXGN::Genotype::Search->new({
    bcs_schema=>$schema,
    people_schema=>$people_schema,
    protocol_id_list=>[$protocol_id],

});
my ($total_count, $data) = $genotypes_search->get_genotype_info();
is($total_count, 63);
print STDERR Dumper "VCF GENOTYPE SEARCH";
print STDERR Dumper $data->[0];
print STDERR Dumper $data->[0]->{germplasmName};
my $accession_name_1 = $data->[0]->{germplasmName};
my $accession_name_2 = $data->[3]->{germplasmName};

is_deeply($data->[0]->{selected_genotype_hash}, {'S1_27739' => {'DP' => '3','GT' => '0/0','GQ' => '88','PL' => '0,9,108','NT' => 'A,A','AD' => '3,0','DS' => '0'},'S1_84628' => {'AD' => '0,0','NT' => '','DS' => '0','GQ' => '.','PL' => '.','DP' => '0','GT' => './.'},'S1_21597' => {'GQ' => '98','PL' => '0,18,216','AD' => '6,0','NT' => 'G,G','DS' => '0','DP' => '6','GT' => '0/0'},'S1_21594' => {'PL' => '.','GQ' => '.','DS' => '1','NT' => '','AD' => '0,0','GT' => './.','DP' => '0'},'S1_26659' => {'DP' => '4','GT' => '0/0','GQ' => '94','PL' => '0,12,144','NT' => 'C,C','DS' => '0','AD' => '4,0'},'S1_75465' => {'GT' => './.','DP' => '0','NT' => '','DS' => '0','AD' => '0,0','PL' => '.','GQ' => '.'},'S1_26674' => {'DP' => '1','GT' => '0/0','NT' => 'A,A','AD' => '1,0','DS' => '0','GQ' => '66','PL' => '0,3,36'},'S1_26662' => {'GT' => '0/0','DP' => '4','NT' => 'C,C','DS' => '0','AD' => '4,0','PL' => '0,12,144','GQ' => '94'},'S1_27746' => {'GQ' => '99','PL' => '0,24,255','NT' => 'A,A','AD' => '8,0','DS' => '0','DP' => '8','GT' => '0/0'},'S1_27720' => {'AD' => '1,0','NT' => 'C,C','DS' => '0','GQ' => '66','PL' => '0,3,36','DP' => '1','GT' => '0/0'},'S1_75644' => {'PL' => '.','GQ' => '.','NT' => '','AD' => '0,0','DS' => '0','GT' => './.','DP' => '0'},'S1_27874' => {'DP' => '0','GT' => './.','GQ' => '.','PL' => '.','NT' => '','DS' => '0','AD' => '0,0'},'S1_75629' => {'DS' => '0','NT' => '','AD' => '0,0','PL' => '.','GQ' => '.','GT' => './.','DP' => '0'},'S1_26646' => {'GT' => '0/0','DP' => '4','PL' => '0,12,144','GQ' => '94','DS' => '0','NT' => 'A,A','AD' => '4,0'},'S1_27724' => {'NT' => 'T,T','DS' => '0','AD' => '3,0','PL' => '0,9,108','GQ' => '88','GT' => '0/0','DP' => '3'},'S1_27861' => {'NT' => 'C,C','AD' => '8,0','DS' => '0','GQ' => '99','PL' => '0,24,255','DP' => '8','GT' => '0/0'},'S1_26576' => {'GQ' => '94','PL' => '0,12,144','NT' => 'A,A','AD' => '4,0','DS' => '0','DP' => '4','GT' => '0/0'},'S1_26624' => {'GQ' => '94','PL' => '0,12,144','DS' => '0','NT' => 'T,T','AD' => '4,0','DP' => '4','GT' => '0/0'}}, 'test genotype search');
is_deeply($data->[0]->{selected_protocol_hash}->{markers_array}, [{'format' => 'GT:AD:DP:GQ:DS:PL','pos' => '21594','filter' => 'PASS','alt' => 'A','ref' => 'G','qual' => '.','name' => 'S1_21594','info' => 'AR2=0.29;DR2=0.342;AF=0.375','chrom' => '1'},{'qual' => '.','ref' => 'G','filter' => 'PASS','alt' => 'A','chrom' => '1','info' => 'AR2=0;DR2=0.065;AF=0.001','name' => 'S1_21597','format' => 'GT:AD:DP:GQ:DS:PL','pos' => '21597'},{'format' => 'GT:AD:DP:GQ:DS:PL','pos' => '26576','name' => 'S1_26576','chrom' => '1','info' => 'AR2=0.833;DR2=0.852;AF=0.009','filter' => 'PASS','alt' => 'C','ref' => 'A','qual' => '.'},{'pos' => '26624','format' => 'GT:AD:DP:GQ:DS:PL','chrom' => '1','info' => 'AR2=0.93;DR2=0.948;AF=0.022','name' => 'S1_26624','ref' => 'T','qual' => '.','filter' => 'PASS','alt' => 'C'},{'qual' => '.','ref' => 'A','filter' => 'PASS','alt' => 'G','info' => 'AR2=0;DR2=0;AF=0','chrom' => '1','name' => 'S1_26646','format' => 'GT:AD:DP:GQ:DS:PL','pos' => '26646'},{'pos' => '26659','format' => 'GT:AD:DP:GQ:DS:PL','name' => 'S1_26659','info' => 'AR2=0.93;DR2=0.948;AF=0.022','chrom' => '1','filter' => 'PASS','alt' => 'G','qual' => '.','ref' => 'C'},{'pos' => '26662','format' => 'GT:AD:DP:GQ:DS:PL','name' => 'S1_26662','chrom' => '1','info' => 'AR2=0.94;DR2=0.953;AF=0.023','filter' => 'PASS','alt' => 'T','ref' => 'C','qual' => '.'},{'format' => 'GT:AD:DP:GQ:DS:PL','pos' => '26674','qual' => '.','ref' => 'A','filter' => 'PASS','alt' => 'G','info' => 'AR2=0;DR2=0;AF=0','chrom' => '1','name' => 'S1_26674'},{'name' => 'S1_27720','chrom' => '1','info' => 'AR2=0.753;DR2=0.807;AF=0.019','filter' => 'PASS','alt' => 'A','ref' => 'C','qual' => '.','format' => 'GT:AD:DP:GQ:DS:PL','pos' => '27720'},{'pos' => '27724','format' => 'GT:AD:DP:GQ:DS:PL','name' => 'S1_27724','chrom' => '1','info' => 'AR2=0.251;DR2=0.367;AF=0.002','filter' => 'PASS','alt' => 'A','ref' => 'T','qual' => '.'},{'ref' => 'A','qual' => '.','filter' => 'PASS','alt' => 'G','info' => 'AR2=0.205;DR2=0.229;AF=0','chrom' => '1','name' => 'S1_27739','pos' => '27739','format' => 'GT:AD:DP:GQ:DS:PL'},{'pos' => '27746','format' => 'GT:AD:DP:GQ:DS:PL','chrom' => '1','info' => 'AR2=0.976;DR2=0.98;AF=0.026','name' => 'S1_27746','qual' => '.','ref' => 'A','filter' => 'PASS','alt' => 'G'},{'info' => 'AR2=0.876;DR2=0.897;AF=0.003','chrom' => '1','name' => 'S1_27861','ref' => 'C','qual' => '.','filter' => 'PASS','alt' => 'T','format' => 'GT:AD:DP:GQ:DS:PL','pos' => '27861'},{'name' => 'S1_27874','chrom' => '1','info' => 'AR2=0.965;DR2=0.971;AF=0.029','alt' => 'A','filter' => 'PASS','ref' => 'G','qual' => '.','format' => 'GT:AD:DP:GQ:DS:PL','pos' => '27874'},{'filter' => 'PASS','alt' => 'T','qual' => '.','ref' => 'C','name' => 'S1_75465','info' => 'AR2=0.752;DR2=0.778;AF=0.361','chrom' => '1','pos' => '75465','format' => 'GT:AD:DP:GQ:DS:PL'},{'name' => 'S1_75629','info' => 'AR2=0.799;DR2=0.817;AF=0.377','chrom' => '1','alt' => 'A','filter' => 'PASS','ref' => 'T','qual' => '.','pos' => '75629','format' => 'GT:AD:DP:GQ:DS:PL'},{'format' => 'GT:AD:DP:GQ:DS:PL','pos' => '75644','qual' => '.','ref' => 'C','alt' => 'T','filter' => 'PASS','chrom' => '1','info' => 'AR2=0.816;DR2=0.834;AF=0.023','name' => 'S1_75644'},{'qual' => '.','ref' => 'C','filter' => 'PASS','alt' => 'A','chrom' => '1','info' => 'AR2=0;DR2=0;AF=0','name' => 'S1_84628','pos' => '84628','format' => 'GT:AD:DP:GQ:DS:PL'}], 'test genotype search');


$mech->get_ok('http://localhost:3010/ajax/genotyping_protocol/markers_search?protocol_id='.$protocol_id.'&marker_names=S1_27861,S1_75644');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'recordsFiltered' => 18,'recordsTotal' => 18,'data' => [['S1_27861','1','27861','T','C','.','PASS','AR2=0.876;DR2=0.897;AF=0.003','GT:AD:DP:GQ:DS:PL'],['S1_75644','1','75644','T','C','.','PASS','AR2=0.816;DR2=0.834;AF=0.023','GT:AD:DP:GQ:DS:PL']]});

my $stock_id = $schema->resultset("Stock::Stock")->find({uniquename => 'SRLI1_90'})->stock_id();
$mech->get_ok('http://localhost:3010/stock/'.$stock_id.'/datatables/genotype_data');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is(scalar(@{$response->{data}}), 4);


my $file = $f->config->{basepath}."/t/data/genotype_data/10acc_200Ksnps.transposedVCF.hd.txt";

#test upload with file where sample names are not in the database
my $ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/genotype/upload',
        Content_Type => 'form-data',
        Content => [
            upload_genotype_transposed_vcf_file_input => [ $file, 'genotype_transposed_vcf_data_upload' ],
            "sgn_session_id"=>$sgn_session_id,
            "upload_genotypes_species_name_input"=>"Manihot esculenta",
            "upload_genotype_vcf_project_name"=>"Transposed VCF project 1",
            "upload_genotype_location_select"=>$location_id,
            "upload_genotype_year_select"=>"2018",
            "upload_genotype_breeding_program_select"=>$breeding_program_id,
            "upload_genotype_vcf_observation_type"=>"accession", #IDEALLY THIS IS "tissue_sample"
            "upload_genotype_vcf_facility_select"=>"IGD",
            "upload_genotype_vcf_project_description"=>"Transposed VCF project 1",
            "upload_genotype_vcf_protocol_name"=>"Transposed VCF protocol 1",
            "upload_genotype_vcf_include_igd_numbers"=>1,
            "upload_genotype_vcf_reference_genome_name"=>"Mesculenta_511_v7",
            "upload_genotype_add_new_accessions"=>1, #IDEALLY THIS is set to 0
        ]
    );

$message = $response->decoded_content;
$message_hash = decode_json $message;
print STDERR Dumper $message_hash;
is($message_hash->{success}, 1);
ok($message_hash->{project_id});
ok($message_hash->{nd_protocol_id});

my $genotypes_search = CXGN::Genotype::Search->new({
    bcs_schema=>$schema,
    people_schema=>$people_schema,
    protocol_id_list=>[$message_hash->{nd_protocol_id}],
});
my ($total_count, $data) = $genotypes_search->get_genotype_info();
is($total_count, 91);
print STDERR Dumper $data->[0];
is_deeply($data->[0]->{selected_genotype_hash}, {'S1_26674' => {'DS' => '0','NT' => 'A|A','AD' => '6,0','GT' => '0|0','DP' => '6','PL' => '0,18,216','GQ' => '98'},'S1_26662' => {'DS' => '0','NT' => 'C|C','AD' => '6,0','GT' => '0|0','GQ' => '98','PL' => '0,18,216','DP' => '6'},'S1_27724' => {'DS' => '0','NT' => 'T|T','AD' => '1,0','GT' => '0|0','PL' => '0,3,36','DP' => '1','GQ' => '66'},'S1_27720' => {'NT' => 'C|C','DS' => '0','DP' => '6','PL' => '0,18,216','GQ' => '98','AD' => '6,0','GT' => '0|0'},'S1_27739' => {'GT' => '0|0','AD' => '1,0','DP' => '1','PL' => '0,3,36','GQ' => '66','DS' => '0','NT' => 'A|A'},'S1_26646' => {'GQ' => '98','DP' => '6','PL' => '0,18,216','AD' => '6,0','GT' => '0|0','NT' => 'A|A','DS' => '0'},'S1_21594' => {'DS' => '0','NT' => 'G|G','GT' => '0|0','AD' => '0,0','GQ' => '.','PL' => '.','DP' => '0'},'S1_26624' => {'GQ' => '99','PL' => '0,27,255','DP' => '9','GT' => '0|0','AD' => '9,0','NT' => 'T|T','DS' => '0'},'S1_26659' => {'AD' => '6,0','GT' => '0|0','GQ' => '98','DP' => '6','PL' => '0,18,216','DS' => '0','NT' => 'C|C'},'S1_26576' => {'PL' => '.','DP' => '0','GQ' => '.','GT' => '0|0','AD' => '0','NT' => 'A|A','DS' => '0'}});

my $file = $f->config->{basepath}."/t/data/genotype_data/Intertek_SNP_grid.csv";
my $snp_info_file = $f->config->{basepath}."/t/data/genotype_data/Intertek_SNP_info.csv";

#test upload with file where sample names are not in the database
my $ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/genotype/upload',
        Content_Type => 'form-data',
        Content => [
            upload_genotype_intertek_file_input => [ $file, 'genotype_intertek_grid_data_upload' ],
            upload_genotype_intertek_snp_file_input => [ $snp_info_file, 'genotype_intertek_snp_info_data_upload' ],
            "sgn_session_id"=>$sgn_session_id,
            "upload_genotypes_species_name_input"=>"Manihot esculenta",
            "upload_genotype_vcf_project_name"=>"Intertek SNP project 1",
            "upload_genotype_location_select"=>$location_id,
            "upload_genotype_year_select"=>"2018",
            "upload_genotype_breeding_program_select"=>$breeding_program_id,
            "upload_genotype_vcf_observation_type"=>"accession", #IDEALLY THIS IS "tissue_sample"
            "upload_genotype_vcf_facility_select"=>"IGD",
            "upload_genotype_vcf_project_description"=>"Intertek SNP project 1",
            "upload_genotype_vcf_protocol_name"=>"Intertek SNP protocol 1",
            "upload_genotype_vcf_reference_genome_name"=>"Mesculenta_511_v7",
            "upload_genotype_add_new_accessions"=>1, #IDEALLY THIS is set to 0
        ]
    );

$message = $response->decoded_content;
$message_hash = decode_json $message;
print STDERR Dumper $message_hash;
is($message_hash->{success}, 1);
ok($message_hash->{project_id});
ok($message_hash->{nd_protocol_id});

my $file = $f->config->{basepath}."/t/data/genotype_data/testset_GT-AD-DP-GQ-DS-PL.h5";


SKIP: {

    my $skip_hdf5_tests = ! (has_java() && (free_memory() > 12));

    print STDERR "SKIP HDF5 TESTS: $skip_hdf5_tests\n";
    
    skip "No java installed or not enough memory", 7 if $skip_hdf5_tests;
    
#test upload with file where sample names are not in the database
my $ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/genotype/upload',
        Content_Type => 'form-data',
        Content => [
            upload_genotype_tassel_hdf5_file_input => [ $file, 'upload_genotype_tassel_hdf5_file_input.h5' ],
            "sgn_session_id"=>$sgn_session_id,
            "upload_genotypes_species_name_input"=>"Manihot esculenta",
            "upload_genotype_vcf_project_name"=>"Tassel HDF5 project 1",
            "upload_genotype_location_select"=>$location_id,
            "upload_genotype_year_select"=>"2018",
            "upload_genotype_breeding_program_select"=>$breeding_program_id,
            "upload_genotype_vcf_observation_type"=>"accession", #IDEALLY THIS IS "tissue_sample"
            "upload_genotype_vcf_facility_select"=>"IGD",
            "upload_genotype_vcf_project_description"=>"Tassel HDF5 project 1",
            "upload_genotype_vcf_protocol_name"=>"Tassel HDF5 protocol 1",
            "upload_genotype_vcf_include_igd_numbers"=>1,
            "upload_genotype_vcf_reference_genome_name"=>"Mesculenta_511_v7",
            "upload_genotype_accept_warnings"=>1
        ]
    );

$message = $response->decoded_content;

print STDERR "ANOTHER MESSAGE: ".Dumper($message);

my $message_hash_tassel = decode_json $message;
print STDERR Dumper $message_hash_tassel;
is($message_hash_tassel->{success}, 1);
ok($message_hash_tassel->{project_id});
ok($message_hash_tassel->{nd_protocol_id});

my $genotypes_search = CXGN::Genotype::Search->new({
    bcs_schema=>$schema,
    people_schema=>$people_schema,
    protocol_id_list=>[$message_hash_tassel->{nd_protocol_id}],
});
my ($total_count, $data) = $genotypes_search->get_genotype_info();
is($total_count, 21);
print STDERR Dumper $data->[0];
print STDERR Dumper $data->[0]->{germplasmName};
is_deeply($data->[0]->{selected_genotype_hash}, {'S1_27874' => {'GQ' => undef,'DS' => 'NA','PL' => undef,'NT' => '','GT' => './.','AD' => '0','DP' => '0'},'S1_84628' => {'DS' => 'NA','PL' => undef,'NT' => '','GQ' => undef,'AD' => '0','DP' => '0','GT' => './.'},'S1_27720' => {'GT' => '0/0','AD' => '1','DP' => '1','GQ' => '66','DS' => '2','NT' => 'C,C','PL' => '0'},'S1_26646' => {'AD' => '4,0','DP' => '4','GT' => '0/0','DS' => '2','NT' => 'A,A','PL' => '0,12,144','GQ' => '94'},'S1_27746' => {'GT' => '0/0','DP' => '8','AD' => '8','GQ' => '99','NT' => 'A,A','PL' => '0','DS' => '2'},'S1_75644' => {'GQ' => undef,'DS' => 'NA','NT' => '','PL' => undef,'GT' => './.','AD' => '0','DP' => '0'},'S1_75629' => {'PL' => undef,'NT' => '','DS' => 'NA','GQ' => undef,'DP' => '0','AD' => '0','GT' => './.'},'S1_27724' => {'GQ' => '88','DS' => '2','PL' => '0','NT' => 'T,T','GT' => '0/0','AD' => '3','DP' => '3'},'S1_26576' => {'DP' => '4','AD' => '4,0','GT' => '0/0','NT' => 'A,A','PL' => '0,12,144','DS' => '2','GQ' => '94'},'S1_27739' => {'AD' => '3','DP' => '3','GT' => '0/0','DS' => '2','PL' => '0','NT' => 'A,A','GQ' => '88'},'S1_26674' => {'AD' => '1','DP' => '1','GT' => '0/0','DS' => '2','NT' => 'A,A','PL' => '0','GQ' => '66'},'S1_26659' => {'AD' => '4,0','DP' => '4','GT' => '0/0','DS' => '2','PL' => '0,12,144','NT' => 'C,C','GQ' => '94'},'S1_21597' => {'GQ' => '98','NT' => 'G,G','PL' => '0','DS' => '2','GT' => '0/0','DP' => '6','AD' => '6'},'S1_27861' => {'GT' => '0/0','AD' => '8','DP' => '8','GQ' => '99','DS' => '2','PL' => '0','NT' => 'C,C'},'S1_75465' => {'PL' => undef,'NT' => '','DS' => 'NA','GQ' => undef,'DP' => '0','AD' => '0','GT' => './.'},'S1_26662' => {'PL' => '0','NT' => 'C,C','DS' => '2','GQ' => '94','DP' => '4','AD' => '4','GT' => '0/0'},'S1_21594' => {'DP' => '0','AD' => '0','GT' => './.','PL' => undef,'NT' => '','DS' => 'NA','GQ' => undef},'S1_26624' => {'DS' => '2','PL' => '0','NT' => 'T,T','GQ' => '94','AD' => '4','DP' => '4','GT' => '0/0'}});


my $genotypes_search = CXGN::Genotype::Search->new({
    bcs_schema=>$schema,
    people_schema=>$people_schema,
    protocol_id_list=>[$message_hash->{nd_protocol_id}],
});
my ($total_count, $data) = $genotypes_search->get_genotype_info();
is($total_count, 17);
print STDERR Dumper $data->[0];
print STDERR Dumper $data->[0]->{germplasmName};
is_deeply($data->[0]->{selected_genotype_hash}, {'S1_2142358' => {'DP' => undef,'DS' => '2','GQ' => undef,'PL' => undef,'AD' => undef,'GT' => '0/0','NT' => 'C,C'},'S12_7926132' => {'PL' => undef,'GQ' => undef,'DS' => '1','DP' => undef,'AD' => undef,'NT' => 'T,G','GT' => '0/1'},'S14_4626854' => {'PL' => undef,'DP' => undef,'DS' => '0','GQ' => undef,'AD' => undef,'NT' => 'G,G','GT' => '1/1'},'S1_24197219' => {'DS' => '0','DP' => undef,'GQ' => undef,'PL' => undef,'AD' => undef,'GT' => '1/1','NT' => 'C,C'},'S1_24155522' => {'PL' => undef,'DS' => '0','GQ' => undef,'DP' => undef,'AD' => undef,'NT' => 'C,C','GT' => '1/1'}});

my $vcf_response_string_expected = '##INFO=<ID=VCFDownload, Description=\'VCFv4.2 FILE GENERATED BY BREEDBASE AT 2020-02-28_19:35:42\'>
##fileformat=VCFv4.0
##Tassel=<ID=GenotypeTable,Version=5,Description="Reference allele is not known. The major allele was used as reference allele">
##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">
##FORMAT=<ID=AD,Number=.,Type=Integer,Description="Allelic depths for the reference and alternate alleles in the order listed">
##FORMAT=<ID=DP,Number=1,Type=Integer,Description="Read Depth (only filtered reads used for calling)">
##FORMAT=<ID=GQ,Number=1,Type=Float,Description="Genotype Quality">
##FORMAT=<ID=PL,Number=3,Type=Float,Description="Normalized, Phred-scaled likelihoods for AA,AB,BB genotypes where A=ref and B=alt; not applicable if site is not biallelic">
##INFO=<ID=NS,Number=1,Type=Integer,Description="Number of Samples With Data">
##INFO=<ID=DP,Number=1,Type=Integer,Description="Total Depth">
##INFO=<ID=AF,Number=.,Type=Float,Description="Allele Frequency">
##FORMAT=<ID=DS,Number=1,Type=Float,Description="estimated ALT dose [P(RA) + P(AA)]">
## Synonyms of accessions:
#CHROM	POS	ID	REF	ALT	QUAL	FILTER	INFO	FORMAT	KBH2014_076	KBH2014_1155
1 	21594 	S1_21594	G	A	.	PASS	AR2=0.29;DR2=0.342;AF=0.375	GT:AD:DP:GQ:DS:PL:NT	./.:0,0:0:.:1:.:	0/0:1,0:1:66:0:0,3,36:G,G
1 	21597 	S1_21597	G	A	.	PASS	AR2=0;DR2=0.065;AF=0.001	GT:AD:DP:GQ:DS:PL:NT	0/0:6,0:6:98:0:0,18,216:G,G	0/0:5,0:5:96:0:0,15,180:G,G
1 	26576 	S1_26576	A	C	.	PASS	AR2=0.833;DR2=0.852;AF=0.009	GT:AD:DP:GQ:DS:PL:NT	0/0:4,0:4:94:0:0,12,144:A,A	0/0:7,0:7:99:0:0,21,252:A,A
1 	26624 	S1_26624	T	C	.	PASS	AR2=0.93;DR2=0.948;AF=0.022	GT:AD:DP:GQ:DS:PL:NT	0/0:4,0:4:94:0:0,12,144:T,T	0/0:7,0:7:99:0:0,21,252:T,T
1 	26646 	S1_26646	A	G	.	PASS	AR2=0;DR2=0;AF=0	GT:AD:DP:GQ:DS:PL:NT	0/0:4,0:4:94:0:0,12,144:A,A	0/0:7,0:7:99:0:0,21,252:A,A
1 	26659 	S1_26659	C	G	.	PASS	AR2=0.93;DR2=0.948;AF=0.022	GT:AD:DP:GQ:DS:PL:NT	0/0:4,0:4:94:0:0,12,144:C,C	0/0:7,0:7:99:0:0,21,252:C,C
1 	26662 	S1_26662	C	T	.	PASS	AR2=0.94;DR2=0.953;AF=0.023	GT:AD:DP:GQ:DS:PL:NT	0/0:4,0:4:94:0:0,12,144:C,C	0/0:7,0:7:99:0:0,21,252:C,C
1 	26674 	S1_26674	A	G	.	PASS	AR2=0;DR2=0;AF=0	GT:AD:DP:GQ:DS:PL:NT	0/0:1,0:1:66:0:0,3,36:A,A	0/0:3,0:3:88:0:0,9,108:A,A
1 	27720 	S1_27720	C	A	.	PASS	AR2=0.753;DR2=0.807;AF=0.019	GT:AD:DP:GQ:DS:PL:NT	0/0:1,0:1:66:0:0,3,36:C,C	0/0:2,0:2:79:0:0,6,72:C,C
1 	27724 	S1_27724	T	A	.	PASS	AR2=0.251;DR2=0.367;AF=0.002	GT:AD:DP:GQ:DS:PL:NT	0/0:3,0:3:88:0:0,9,108:T,T	0/0:4,0:4:94:0:0,12,144:T,T
1 	27739 	S1_27739	A	G	.	PASS	AR2=0.205;DR2=0.229;AF=0	GT:AD:DP:GQ:DS:PL:NT	0/0:3,0:3:88:0:0,9,108:A,A	0/0:4,0:4:94:0:0,12,144:A,A
1 	27746 	S1_27746	A	G	.	PASS	AR2=0.976;DR2=0.98;AF=0.026	GT:AD:DP:GQ:DS:PL:NT	0/0:8,0:8:99:0:0,24,255:A,A	0/0:3,0:3:88:0:0,9,108:A,A
1 	27861 	S1_27861	C	T	.	PASS	AR2=0.876;DR2=0.897;AF=0.003	GT:AD:DP:GQ:DS:PL:NT	0/0:8,0:8:99:0:0,24,255:C,C	0/0:3,0:3:88:0:0,9,108:C,C
1 	27874 	S1_27874	G	A	.	PASS	AR2=0.965;DR2=0.971;AF=0.029	GT:AD:DP:GQ:DS:PL:NT	./.:0,0:0:.:0:.:	./.:0,0:0:.:0:.:
1 	75465 	S1_75465	C	T	.	PASS	AR2=0.752;DR2=0.778;AF=0.361	GT:AD:DP:GQ:DS:PL:NT	./.:0,0:0:.:0:.:	./.:0,0:0:.:2:.:
1 	75629 	S1_75629	T	A	.	PASS	AR2=0.799;DR2=0.817;AF=0.377	GT:AD:DP:GQ:DS:PL:NT	./.:0,0:0:.:0:.:	./.:0,0:0:.:2:.:
1 	75644 	S1_75644	C	T	.	PASS	AR2=0.816;DR2=0.834;AF=0.023	GT:AD:DP:GQ:DS:PL:NT	./.:0,0:0:.:0:.:	./.:0,0:0:.:0:.:
1 	84628 	S1_84628	C	A	.	PASS	AR2=0;DR2=0;AF=0	GT:AD:DP:GQ:DS:PL:NT	./.:0,0:0:.:0:.:	./.:0,0:0:.:0:.:
';

my $accession_id1 = $schema->resultset("Stock::Stock")->find({uniquename=>$accession_name_1})->stock_id();
my $accession_id2 = $schema->resultset("Stock::Stock")->find({uniquename=>$accession_name_2})->stock_id();

my $ua = LWP::UserAgent->new;
$response = $ua->get("http://localhost:3010/breeders/download_gbs_action/?ids=$accession_id1,$accession_id2&forbid_cache=1&protocol_id=$protocol_id&format=accession_ids&download_format=VCF&compute_from_parents=0");
$message = $response->decoded_content;
print STDERR Dumper $message;
my @vcf_response_expected = split "\n", $vcf_response_string_expected;
my @vcf_response = split "\n", $message;
my $header_ts = shift @vcf_response_expected;
my $header_ts = shift @vcf_response;
print STDERR Dumper \@vcf_response;
is_deeply(\@vcf_response, \@vcf_response_expected);

my $dosage_matrix_string = 'Marker	KBH2014_076	KBH2014_1155
S1_21594	1	0
S1_21597	0	0
S1_26576	0	0
S1_26624	0	0
S1_26646	0	0
S1_26659	0	0
S1_26662	0	0
S1_26674	0	0
S1_27720	0	0
S1_27724	0	0
S1_27739	0	0
S1_27746	0	0
S1_27861	0	0
S1_27874	0	0
S1_75465	0	2
S1_75629	0	2
S1_75644	0	0
S1_84628	0	0
';

$ua = LWP::UserAgent->new;
$response = $ua->get("http://localhost:3010/breeders/download_gbs_action/?ids=$accession_id1,$accession_id2&forbid_cache=1&protocol_id=$protocol_id&format=accession_ids&download_format=DosageMatrix&compute_from_parents=0");
$message = $response->decoded_content;
print STDERR Dumper $message;
is($message, $dosage_matrix_string);


#Testing genotype search with marker names filter from marker set list object
my $marker_names_filtered = ["S1_21594", "S1_21597", "S1_75465"];

my $new_marker_set_list_id = CXGN::List::create_list($dbh, "Marker Set List 1", "Test marker set list 1", 41);
my $marker_set_list = CXGN::List->new( { dbh => $dbh, list_id => $new_marker_set_list_id } );
my @marker_names_set;
foreach (@$marker_names_filtered) {
    push @marker_names_set, encode_json {marker_name => $_};
}
$marker_set_list->add_bulk(\@marker_names_set);

my $dosage_matrix_string_filtered = 'Marker	KBH2014_076	KBH2014_1155
S1_21594	1	0
S1_21597	0	0
S1_75465	0	2
';

my $vcf_response_string_expected = '##INFO=<ID=VCFDownload, Description=\'VCFv4.2 FILE GENERATED BY BREEDBASE AT 2020-02-28_19:35:42\'>
##fileformat=VCFv4.0
##Tassel=<ID=GenotypeTable,Version=5,Description="Reference allele is not known. The major allele was used as reference allele">
##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">
##FORMAT=<ID=AD,Number=.,Type=Integer,Description="Allelic depths for the reference and alternate alleles in the order listed">
##FORMAT=<ID=DP,Number=1,Type=Integer,Description="Read Depth (only filtered reads used for calling)">
##FORMAT=<ID=GQ,Number=1,Type=Float,Description="Genotype Quality">
##FORMAT=<ID=PL,Number=3,Type=Float,Description="Normalized, Phred-scaled likelihoods for AA,AB,BB genotypes where A=ref and B=alt; not applicable if site is not biallelic">
##INFO=<ID=NS,Number=1,Type=Integer,Description="Number of Samples With Data">
##INFO=<ID=DP,Number=1,Type=Integer,Description="Total Depth">
##INFO=<ID=AF,Number=.,Type=Float,Description="Allele Frequency">
##FORMAT=<ID=DS,Number=1,Type=Float,Description="estimated ALT dose [P(RA) + P(AA)]">
## Synonyms of accessions:
#CHROM	POS	ID	REF	ALT	QUAL	FILTER	INFO	FORMAT	KBH2014_076	KBH2014_1155
1 	21594 	S1_21594	G	A	.	PASS	AR2=0.29;DR2=0.342;AF=0.375	GT:AD:DP:GQ:DS:PL:NT	./.:0,0:0:.:1:.:	0/0:1,0:1:66:0:0,3,36:G,G
1 	21597 	S1_21597	G	A	.	PASS	AR2=0;DR2=0.065;AF=0.001	GT:AD:DP:GQ:DS:PL:NT	0/0:6,0:6:98:0:0,18,216:G,G	0/0:5,0:5:96:0:0,15,180:G,G
1 	75465 	S1_75465	C	T	.	PASS	AR2=0.752;DR2=0.778;AF=0.361	GT:AD:DP:GQ:DS:PL:NT	./.:0,0:0:.:0:.:	./.:0,0:0:.:2:.:
';

my $ua = LWP::UserAgent->new;
$response = $ua->get("http://localhost:3010/breeders/download_gbs_action/?ids=$accession_id1,$accession_id2&forbid_cache=1&protocol_id=$protocol_id&format=accession_ids&download_format=VCF&compute_from_parents=0&marker_set_list_id=$new_marker_set_list_id");
$message = $response->decoded_content;
print STDERR Dumper $message;
my @vcf_response_expected = split "\n", $vcf_response_string_expected;
my @vcf_response = split "\n", $message;
my $header_ts = shift @vcf_response_expected;
my $header_ts = shift @vcf_response;
print STDERR Dumper \@vcf_response;
is_deeply(\@vcf_response, \@vcf_response_expected);

$ua = LWP::UserAgent->new;
$response = $ua->get("http://localhost:3010/breeders/download_gbs_action/?ids=$accession_id1,$accession_id2&forbid_cache=1&protocol_id=$protocol_id&format=accession_ids&download_format=DosageMatrix&compute_from_parents=0&marker_set_list_id=$new_marker_set_list_id");
$message = $response->decoded_content;
print STDERR Dumper $message;
is($message, $dosage_matrix_string_filtered);


#Testing computing genotypes from parents
my $test_accession_name_1 = 'test_accession1';
my $test_accession_name_2 = 'test_accession2';
my $test_accession1_id = $schema->resultset("Stock::Stock")->find({uniquename=>$test_accession_name_1})->stock_id();
my $test_accession2_id = $schema->resultset("Stock::Stock")->find({uniquename=>$test_accession_name_2})->stock_id();
my $p = Bio::GeneticRelationships::Pedigree->new({
    name => $test_accession_name_1,
    cross_type => 'biparental',
    female_parent => Bio::GeneticRelationships::Individual->new({ name => $accession_name_1 }),
    male_parent => Bio::GeneticRelationships::Individual->new({ name => $accession_name_2 }),
});
my $add = CXGN::Pedigree::AddPedigrees->new({ schema=>$schema, pedigrees=>[$p] });
my $overwrite_pedigree = 'true';
my $return = $add->add_pedigrees($overwrite_pedigree);

my $p = Bio::GeneticRelationships::Pedigree->new({
    name => $accession_name_1,
    cross_type => 'biparental',
    female_parent => Bio::GeneticRelationships::Individual->new({ name => $test_accession_name_1 }),
    male_parent => Bio::GeneticRelationships::Individual->new({ name => $accession_name_2 }),
});
my $add = CXGN::Pedigree::AddPedigrees->new({ schema=>$schema, pedigrees=>[$p] });
my $overwrite_pedigree = 'true';
my $return = $add->add_pedigrees($overwrite_pedigree);

my $computed_from_parents_vcf_string_expected = '##INFO=<ID=VCFDownload, Description=\'VCFv4.2 FILE GENERATED BY BREEDBASE AT 2020-03-02_19:59:02\'>
##fileformat=VCFv4.0
##Tassel=<ID=GenotypeTable,Version=5,Description="Reference allele is not known. The major allele was used as reference allele">
##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">
##FORMAT=<ID=AD,Number=.,Type=Integer,Description="Allelic depths for the reference and alternate alleles in the order listed">
##FORMAT=<ID=DP,Number=1,Type=Integer,Description="Read Depth (only filtered reads used for calling)">
##FORMAT=<ID=GQ,Number=1,Type=Float,Description="Genotype Quality">
##FORMAT=<ID=PL,Number=3,Type=Float,Description="Normalized, Phred-scaled likelihoods for AA,AB,BB genotypes where A=ref and B=alt; not applicable if site is not biallelic">
##INFO=<ID=NS,Number=1,Type=Integer,Description="Number of Samples With Data">
##INFO=<ID=DP,Number=1,Type=Integer,Description="Total Depth">
##INFO=<ID=AF,Number=.,Type=Float,Description="Allele Frequency">
##FORMAT=<ID=DS,Number=1,Type=Float,Description="estimated ALT dose [P(RA) + P(AA)]">
## Synonyms of accessions:  test_accession1=(test_accession1_synonym1)
#CHROM	POS	ID	REF	ALT	QUAL	FILTER	INFO	FORMAT	KBH2014_076
1 	21594 	S1_21594	G	A				DS	0.5
1 	21597 	S1_21597	G	A				DS	0
1 	26576 	S1_26576	A	C				DS	0
1 	26624 	S1_26624	T	C				DS	0
1 	26646 	S1_26646	A	G				DS	0
1 	26659 	S1_26659	C	G				DS	0
1 	26662 	S1_26662	C	T				DS	0
1 	26674 	S1_26674	A	G				DS	0
1 	27720 	S1_27720	C	A				DS	0
1 	27724 	S1_27724	T	A				DS	0
1 	27739 	S1_27739	A	G				DS	0
1 	27746 	S1_27746	A	G				DS	0
1 	27861 	S1_27861	C	T				DS	0
1 	27874 	S1_27874	G	A				DS	0
1 	75465 	S1_75465	C	T				DS	1
1 	75629 	S1_75629	T	A				DS	1
1 	75644 	S1_75644	C	T				DS	0
1 	84628 	S1_84628	C	A				DS	0
';

my $computed_from_parents_vcf_string_marker_set_expected = '##INFO=<ID=VCFDownload, Description=\'VCFv4.2 FILE GENERATED BY BREEDBASE AT 2020-03-02_19:59:02\'>
##fileformat=VCFv4.0
##Tassel=<ID=GenotypeTable,Version=5,Description="Reference allele is not known. The major allele was used as reference allele">
##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">
##FORMAT=<ID=AD,Number=.,Type=Integer,Description="Allelic depths for the reference and alternate alleles in the order listed">
##FORMAT=<ID=DP,Number=1,Type=Integer,Description="Read Depth (only filtered reads used for calling)">
##FORMAT=<ID=GQ,Number=1,Type=Float,Description="Genotype Quality">
##FORMAT=<ID=PL,Number=3,Type=Float,Description="Normalized, Phred-scaled likelihoods for AA,AB,BB genotypes where A=ref and B=alt; not applicable if site is not biallelic">
##INFO=<ID=NS,Number=1,Type=Integer,Description="Number of Samples With Data">
##INFO=<ID=DP,Number=1,Type=Integer,Description="Total Depth">
##INFO=<ID=AF,Number=.,Type=Float,Description="Allele Frequency">
##FORMAT=<ID=DS,Number=1,Type=Float,Description="estimated ALT dose [P(RA) + P(AA)]">
## Synonyms of accessions:  test_accession1=(test_accession1_synonym1)
#CHROM	POS	ID	REF	ALT	QUAL	FILTER	INFO	FORMAT	KBH2014_076
1 	21594 	S1_21594	G	A				DS	0.5
1 	21597 	S1_21597	G	A				DS	0
1 	75465 	S1_75465	C	T				DS	1
';

$ua = LWP::UserAgent->new;
$response = $ua->get("http://localhost:3010/breeders/download_gbs_action/?ids=$test_accession1_id&forbid_cache=1&protocol_id=$protocol_id&format=accession_ids&download_format=VCF&compute_from_parents=true");
$message = $response->decoded_content;
print STDERR Dumper $message;
my @vcf_response_expected = split "\n", $computed_from_parents_vcf_string_expected;
my @vcf_response = split "\n", $message;
my $header_ts = shift @vcf_response_expected;
my $header_ts = shift @vcf_response;
is_deeply(\@vcf_response, \@vcf_response_expected);

$ua = LWP::UserAgent->new;
$response = $ua->get("http://localhost:3010/breeders/download_gbs_action/?ids=$test_accession1_id&forbid_cache=1&protocol_id=$protocol_id&format=accession_ids&download_format=VCF&compute_from_parents=true&marker_set_list_id=$new_marker_set_list_id");
$message = $response->decoded_content;
print STDERR Dumper $message;
my @vcf_response_expected = split "\n", $computed_from_parents_vcf_string_marker_set_expected;
my @vcf_response = split "\n", $message;
my $header_ts = shift @vcf_response_expected;
my $header_ts = shift @vcf_response;
is_deeply(\@vcf_response, \@vcf_response_expected);

my $computed_from_parents_dosage_matrix_string = 'Marker	38840
S1_21594	0.5
S1_21597	0
S1_26576	0
S1_26624	0
S1_26646	0
S1_26659	0
S1_26662	0
S1_26674	0
S1_27720	0
S1_27724	0
S1_27739	0
S1_27746	0
S1_27861	0
S1_27874	0
S1_75465	1
S1_75629	1
S1_75644	0
S1_84628	0
';

my $computed_from_parents_dosage_matrix_marker_set_string = 'Marker	38840
S1_21594	0.5
S1_21597	0
S1_75465	1
';

$ua = LWP::UserAgent->new;
$response = $ua->get("http://localhost:3010/breeders/download_gbs_action/?ids=$test_accession1_id&forbid_cache=1&protocol_id=$protocol_id&format=accession_ids&download_format=DosageMatrix&compute_from_parents=true");
$message = $response->decoded_content;
print STDERR Dumper $message;
is($message, $computed_from_parents_dosage_matrix_string);

$ua = LWP::UserAgent->new;
$response = $ua->get("http://localhost:3010/breeders/download_gbs_action/?ids=$test_accession1_id&forbid_cache=1&protocol_id=$protocol_id&format=accession_ids&download_format=DosageMatrix&compute_from_parents=true&marker_set_list_id=$new_marker_set_list_id");
$message = $response->decoded_content;
print STDERR Dumper $message;
is($message, $computed_from_parents_dosage_matrix_marker_set_string);

## CHECK WIZARD SEARCH GRM

$ua = LWP::UserAgent->new;
$response = $ua->get("http://localhost:3010/breeders/download_grm_action/?ids=$accession_id1,$accession_id2&protocol_id=$protocol_id&format=accession_ids&compute_from_parents=false&download_format=matrix&minor_allele_frequency=0.01&marker_filter=1&individuals_filter=1");
$message = $response->decoded_content;
print STDERR Dumper $message;
my @grm1_split = split "\n", $message;
my @grm1_vals;
my $header1 = shift @grm1_split;
foreach (@grm1_split) {
    my @row = split "\t", $_;
    push @grm1_vals, ($row[1], $row[2]);
}
is_deeply(\@grm1_vals, [1.63636363636364,-1.63636363636364,-1.63636363636364,1.63636363636364]);

$ua = LWP::UserAgent->new;
$response = $ua->get("http://localhost:3010/breeders/download_grm_action/?ids=$accession_id1,$accession_id2&protocol_id=$protocol_id&format=accession_ids&compute_from_parents=false&download_format=three_column&minor_allele_frequency=0.01&marker_filter=1&individuals_filter=1");
$message = $response->decoded_content;
print STDERR Dumper $message;
my @grm2_split = split "\n", $message;
my @grm2_vals;
foreach (@grm2_split) {
    my @row = split "\t", $_;
    push @grm2_vals, $row[2];
}
is_deeply(\@grm2_vals, [1.63636363636364,-1.63636363636364,1.63636363636364]);

$ua = LWP::UserAgent->new;
$response = $ua->get("http://localhost:3010/breeders/download_grm_action/?ids=$test_accession1_id,$accession_id1&protocol_id=$protocol_id&format=accession_ids&compute_from_parents=true&download_format=three_column&minor_allele_frequency=0.001&marker_filter=1&individuals_filter=1");
$message = $response->decoded_content;
print STDERR Dumper $message;
my @grm3_split = split "\n", $message;
my @grm3_vals;
foreach (@grm3_split) {
    my @row = split "\t", $_;
    push @grm3_vals, $row[2];
}
is_deeply(\@grm3_vals, [0.0512820512820513,-0.0512820512820513,0.0512820512820513]);

$ua = LWP::UserAgent->new;
$response = $ua->get("http://localhost:3010/breeders/download_grm_action/?ids=$test_accession1_id,$accession_id1&protocol_id=$protocol_id&format=accession_ids&compute_from_parents=true&download_format=heatmap&minor_allele_frequency=0.01&marker_filter=1&individuals_filter=1");
$message = $response->decoded_content;
#print STDERR Dumper $message;
ok($message);

## CHECK WIZARD SEARCH GWAS

$ua = LWP::UserAgent->new;
$response = $ua->get("http://localhost:3010/breeders/download_gwas_action/?ids=38937,39033&trait_ids=70666,70668&protocol_id=1&format=accession_ids&compute_from_parents=false&download_format=manhattan_qq_plots&minor_allele_frequency=0.01&marker_filter=1&individuals_filter=1");
$message = $response->decoded_content;
#print STDERR Dumper $message;
ok($message);

$ua = LWP::UserAgent->new;
$response = $ua->get("http://localhost:3010/breeders/download_gwas_action/?ids=38937,39033&trait_ids=70666&trait_ids=70666,70668&protocol_id=1&format=accession_ids&compute_from_parents=false&download_format=results_tsv&minor_allele_frequency=0.01&marker_filter=1&individuals_filter=1");
$message = $response->decoded_content;
#print STDERR Dumper $message;
ok($message);

## DELETE genotyping protocol and data

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $access_token = $response->{access_token};

$ua = LWP::UserAgent->new;
$mech->get_ok("http://localhost:3010/ajax/genotyping_protocol/delete/$protocol_id?sgn_session_id=$access_token");
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {success=>1});

}


done_testing();

sub free_memory {
    my @lines = `free -h`;
    my ($label, $total, $used, $free) = split /\s+/, $lines[1];
    $free =~ m/\D+(\d+).*/;
    $free = $1;
    print STDERR "FREE MEMORY DETECTED: $free\n";
    return $free;
}

sub has_java {
    my @lines = `java -version`;
    if ($lines[0]=~/java version/) {
       return 1;
    }
    else {
    	return 0;
    }
}
       
    
