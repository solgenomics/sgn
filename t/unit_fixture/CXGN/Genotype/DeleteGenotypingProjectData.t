# upload 2 genotype projects, delete 1, check that 1 remains and 1 is deleted

use strict;
use warnings;
use lib 't/lib';

use Test::More;
use Test::WWW::Mechanize;
use SGN::Test::Fixture;

use Data::Dumper;
use JSON;

use Catalyst::Test 'SGN';
use HTTP::Request::Common;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $dbh = $schema->storage->dbh;
my $people_schema = $f->people_schema;

my $mech = Test::WWW::Mechanize->new;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = decode_json $mech->content;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};

my $location_rs = $schema->resultset('NaturalDiversity::NdGeolocation')->search({description => 'Cornell Biotech'});
my $location_id = $location_rs->first->nd_geolocation_id;

my $bp_rs = $schema->resultset('Project::Project')->search({name => 'test'});
my $breeding_program_id = $bp_rs->first->project_id;
my $project_id = $bp_rs->first->project_id;

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
is($message_hash->{success}, undef);

print STDERR Dumper $message_hash;

#test upload with file where sample names are added as accessions automatically
$ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/genotype/upload',
        Content_Type => 'form-data',
        Content => [
            upload_genotype_vcf_file_input => [ $file, 'genotype_vcf_data_upload' ],
            "sgn_session_id"=>$sgn_session_id,
            "upload_genotypes_species_name_input"=>"Manihot esculenta",
            "upload_genotype_vcf_project_name"=>"Test genotype project 1",
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

ok($response->is_success);
$message = $response->decoded_content;
$message_hash = decode_json $message;
is($message_hash->{success}, 1);
ok($message_hash->{project_id});
ok($message_hash->{nd_protocol_id});
print STDERR Dumper $message_hash;

my $protocol_id1 = $message_hash->{nd_protocol_id};
my $project_id1 = $message_hash->{project_id};

$ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/genotype/upload',
        Content_Type => 'form-data',
        Content => [
            upload_genotype_vcf_file_input => [ $file, 'genotype_vcf_data_upload' ],
            "sgn_session_id"=>$sgn_session_id,
            "upload_genotypes_species_name_input"=>"Manihot esculenta",
            "upload_genotype_vcf_project_name"=>"Test genotype project 2",
            "upload_genotype_location_select"=>$location_id,
            "upload_genotype_year_select"=>"2018",
            "upload_genotype_breeding_program_select"=>$breeding_program_id,
            "upload_genotype_vcf_observation_type"=>"accession", #IDEALLY THIS IS "tissue_sample"
            "upload_genotype_vcf_facility_select"=>"IGD",
            "upload_genotype_vcf_project_description"=>"Diversity panel genotype study",
            "upload_genotype_vcf_protocol_name"=>"Cassava GBS v7 2019",
            "upload_genotype_vcf_include_igd_numbers"=>1,
            "upload_genotype_vcf_reference_genome_name"=>"Mesculenta_511_v7",
            "upload_genotype_add_new_accessions"=>1, #IDEALLY THIS is set to 0
	    "upload_genotype_accept_warnings"=>1
        ]
    );

ok($response->is_success);
$message = $response->decoded_content;
$message_hash = decode_json $message;
is($message_hash->{success}, 1);
ok($message_hash->{project_id});
ok($message_hash->{nd_protocol_id});
print STDERR Dumper $message_hash;

my $protocol_id2 = $message_hash->{nd_protocol_id};
my $project_id2 = $message_hash->{project_id};

#test deleting genotyping project data
my $genotypes_search = CXGN::Genotype::Search->new({
    bcs_schema=>$schema,
    people_schema=>$people_schema,
    protocol_id_list=>[$protocol_id1],

});
my ($before_deleting_genotyping_project, $data) = $genotypes_search->get_genotype_info();
is($before_deleting_genotyping_project, 21);

$genotypes_search = CXGN::Genotype::Search->new({
    bcs_schema=>$schema,
    people_schema=>$people_schema,
    protocol_id_list=>[$protocol_id2],

});
($before_deleting_genotyping_project, $data) = $genotypes_search->get_genotype_info();
is($before_deleting_genotyping_project, 21);

print STDERR Dumper "VCF GENOTYPE SEARCH";
print STDERR Dumper $data->[0];
print STDERR Dumper $data->[0]->{germplasmName};

$response = $ua->post(
	"http://localhost:3010/ajax/genotyping_project/delete/$project_id2",
	Content_Type => 'form-data',
	Content => [
            "sgn_session_id" =>$sgn_session_id	
	]
    );
ok($response->is_success);
$message = $response->decoded_content;
$message_hash = decode_json $message;
print STDERR Dumper $message_hash;

my ($after_deleting_genotyping_project, $data2) = $genotypes_search->get_genotype_info();
is($after_deleting_genotyping_project, 0);
print STDERR Dumper "VCF GENOTYPE SEARCH";
print STDERR Dumper $data2->[0];
print STDERR Dumper $data2->[0]->{germplasmName};

$genotypes_search = CXGN::Genotype::Search->new({
    bcs_schema=>$schema,
    people_schema=>$people_schema,
    protocol_id_list=>[$protocol_id1],

});
($after_deleting_genotyping_project, $data) = $genotypes_search->get_genotype_info();
is($after_deleting_genotyping_project, 21);

$f->clean_up_db();

done_testing();
