
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use LWP::UserAgent;

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
is($response->{'metadata'}->{'status'}->[2]->{'success'}, 'Login Successfull');
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
        ]
    );

$message = $response->decoded_content;
$message_hash = decode_json $message;
print STDERR Dumper $message_hash;
is($message_hash->{success}, 1);
is($project_id, $message_hash->{project_id});
is($protocol_id, $message_hash->{nd_protocol_id});

done_testing();
