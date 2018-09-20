
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use LWP::UserAgent;
use CXGN::Genotype::Protocol;
use CXGN::Genotype::Search;

#Needed to update IO::Socket::SSL
use Data::Dumper;
use JSON;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

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

#print STDERR Dumper $response;
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
    protocol_id_list=>[$protocol_id],
    
});
my ($total_count, $data) = $genotypes_search->get_genotype_info();
is($total_count, 63);
print STDERR Dumper $data->[0];
is_deeply($data->[0]->{selected_genotype_hash}, {'S1_27874' => {'DP' => '0','GQ' => '.','GT' => './.','AD' => '0,0','PL' => '.','DS' => '0'},'S1_21594' => {'GT' => './.','GQ' => '.','AD' => '0,0','PL' => '.','DS' => '0.897','DP' => '0'},'S1_27724' => {'DS' => '0','PL' => '.','AD' => '0,0','GQ' => '.','GT' => './.','DP' => '0'},'S1_26646' => {'DP' => '5','AD' => '5,0','PL' => '0,15,180','DS' => '0','GT' => '0/0','GQ' => '96'},'S1_75465' => {'GT' => './.','GQ' => '.','AD' => '0,0','PL' => '.','DS' => '0.032','DP' => '0'},'S1_26659' => {'GT' => '0/0','GQ' => '96','PL' => '0,15,180','AD' => '5,0','DS' => '0','DP' => '5'},'S1_26674' => {'DP' => '17','DS' => '0','PL' => '0,51,255','AD' => '17,0','GQ' => '99','GT' => '0/0'},'S1_26624' => {'DP' => '5','GQ' => '96','GT' => '0/0','PL' => '0,15,180','DS' => '0','AD' => '5,0'},'S1_26576' => {'PL' => '0,15,180','DS' => '0','AD' => '5,0','GQ' => '96','GT' => '0/0','DP' => '5'},'S1_84628' => {'GT' => './.','GQ' => '.','DS' => '0','PL' => '.','AD' => '0,0','DP' => '0'},'S1_27746' => {'DP' => '5','PL' => '0,15,180','DS' => '0','AD' => '5,0','GQ' => '96','GT' => '0/0'},'S1_27739' => {'DP' => '0','GQ' => '.','GT' => './.','AD' => '0,0','PL' => '.','DS' => '0.001'},'S1_27861' => {'DP' => '5','AD' => '5,0','PL' => '0,15,180','DS' => '0','GQ' => '96','GT' => '0/0'},'S1_26662' => {'DP' => '5','PL' => '0,15,180','AD' => '5,0','DS' => '0','GQ' => '96','GT' => '0/0'},'S1_75644' => {'GT' => './.','GQ' => '.','PL' => '.','AD' => '0,0','DS' => '0','DP' => '0'},'S1_27720' => {'DP' => '10','GQ' => '99','GT' => '0/0','PL' => '0,30,255','AD' => '10,0','DS' => '0'},'S1_21597' => {'GQ' => '99','GT' => '0/0','PL' => '0,27,255','DS' => '0','AD' => '9,0','DP' => '9'},'S1_75629' => {'DP' => '0','GT' => './.','GQ' => '.','PL' => '.','DS' => '0.027','AD' => '0,0'}}, 'test genotype search');
is_deeply($data->[0]->{selected_protocol_hash}->{markers_array}, [{'format' => 'GT:AD:DP:GQ:DS:PL','pos' => '21594','filter' => 'PASS','alt' => 'A','ref' => 'G','qual' => '.','name' => 'S1_21594','info' => 'AR2=0.29;DR2=0.342;AF=0.375','chrom' => '1'},{'qual' => '.','ref' => 'G','filter' => 'PASS','alt' => 'A','chrom' => '1','info' => 'AR2=0;DR2=0.065;AF=0.001','name' => 'S1_21597','format' => 'GT:AD:DP:GQ:DS:PL','pos' => '21597'},{'format' => 'GT:AD:DP:GQ:DS:PL','pos' => '26576','name' => 'S1_26576','chrom' => '1','info' => 'AR2=0.833;DR2=0.852;AF=0.009','filter' => 'PASS','alt' => 'C','ref' => 'A','qual' => '.'},{'pos' => '26624','format' => 'GT:AD:DP:GQ:DS:PL','chrom' => '1','info' => 'AR2=0.93;DR2=0.948;AF=0.022','name' => 'S1_26624','ref' => 'T','qual' => '.','filter' => 'PASS','alt' => 'C'},{'qual' => '.','ref' => 'A','filter' => 'PASS','alt' => 'G','info' => 'AR2=0;DR2=0;AF=0','chrom' => '1','name' => 'S1_26646','format' => 'GT:AD:DP:GQ:DS:PL','pos' => '26646'},{'pos' => '26659','format' => 'GT:AD:DP:GQ:DS:PL','name' => 'S1_26659','info' => 'AR2=0.93;DR2=0.948;AF=0.022','chrom' => '1','filter' => 'PASS','alt' => 'G','qual' => '.','ref' => 'C'},{'pos' => '26662','format' => 'GT:AD:DP:GQ:DS:PL','name' => 'S1_26662','chrom' => '1','info' => 'AR2=0.94;DR2=0.953;AF=0.023','filter' => 'PASS','alt' => 'T','ref' => 'C','qual' => '.'},{'format' => 'GT:AD:DP:GQ:DS:PL','pos' => '26674','qual' => '.','ref' => 'A','filter' => 'PASS','alt' => 'G','info' => 'AR2=0;DR2=0;AF=0','chrom' => '1','name' => 'S1_26674'},{'name' => 'S1_27720','chrom' => '1','info' => 'AR2=0.753;DR2=0.807;AF=0.019','filter' => 'PASS','alt' => 'A','ref' => 'C','qual' => '.','format' => 'GT:AD:DP:GQ:DS:PL','pos' => '27720'},{'pos' => '27724','format' => 'GT:AD:DP:GQ:DS:PL','name' => 'S1_27724','chrom' => '1','info' => 'AR2=0.251;DR2=0.367;AF=0.002','filter' => 'PASS','alt' => 'A','ref' => 'T','qual' => '.'},{'ref' => 'A','qual' => '.','filter' => 'PASS','alt' => 'G','info' => 'AR2=0.205;DR2=0.229;AF=0','chrom' => '1','name' => 'S1_27739','pos' => '27739','format' => 'GT:AD:DP:GQ:DS:PL'},{'pos' => '27746','format' => 'GT:AD:DP:GQ:DS:PL','chrom' => '1','info' => 'AR2=0.976;DR2=0.98;AF=0.026','name' => 'S1_27746','qual' => '.','ref' => 'A','filter' => 'PASS','alt' => 'G'},{'info' => 'AR2=0.876;DR2=0.897;AF=0.003','chrom' => '1','name' => 'S1_27861','ref' => 'C','qual' => '.','filter' => 'PASS','alt' => 'T','format' => 'GT:AD:DP:GQ:DS:PL','pos' => '27861'},{'name' => 'S1_27874','chrom' => '1','info' => 'AR2=0.965;DR2=0.971;AF=0.029','alt' => 'A','filter' => 'PASS','ref' => 'G','qual' => '.','format' => 'GT:AD:DP:GQ:DS:PL','pos' => '27874'},{'filter' => 'PASS','alt' => 'T','qual' => '.','ref' => 'C','name' => 'S1_75465','info' => 'AR2=0.752;DR2=0.778;AF=0.361','chrom' => '1','pos' => '75465','format' => 'GT:AD:DP:GQ:DS:PL'},{'name' => 'S1_75629','info' => 'AR2=0.799;DR2=0.817;AF=0.377','chrom' => '1','alt' => 'A','filter' => 'PASS','ref' => 'T','qual' => '.','pos' => '75629','format' => 'GT:AD:DP:GQ:DS:PL'},{'format' => 'GT:AD:DP:GQ:DS:PL','pos' => '75644','qual' => '.','ref' => 'C','alt' => 'T','filter' => 'PASS','chrom' => '1','info' => 'AR2=0.816;DR2=0.834;AF=0.023','name' => 'S1_75644'},{'qual' => '.','ref' => 'C','filter' => 'PASS','alt' => 'A','chrom' => '1','info' => 'AR2=0;DR2=0;AF=0','name' => 'S1_84628','pos' => '84628','format' => 'GT:AD:DP:GQ:DS:PL'}], 'test genotype search');

done_testing();
