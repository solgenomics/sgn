use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use CXGN::List;
use CXGN::Genotype::Protocol;
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
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};

my $location_rs = $schema->resultset('NaturalDiversity::NdGeolocation')->search({description => 'Cornell Biotech'});
my $location_id = $location_rs->first->nd_geolocation_id;

my $bp_rs = $schema->resultset('Project::Project')->search({name => 'test'});
my $breeding_program_id = $bp_rs->first->project_id;

#adding genotyping data for testing markerset and accession search
my $file = $f->config->{basepath}."/t/data/genotype_data/test_genotype_upload.vcf";

my $ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/genotype/upload',
        Content_Type => 'form-data',
        Content => [
            upload_genotype_vcf_file_input => [ $file, 'genotype_vcf_data_upload' ],
            "sgn_session_id"=>$sgn_session_id,
            "upload_genotypes_species_name_input"=>"Manihot esculenta",
            "upload_genotype_vcf_project_name"=>"test_genotype_project",
            "upload_genotype_location_select"=>$location_id,
            "upload_genotype_year_select"=>"2021",
            "upload_genotype_breeding_program_select"=>$breeding_program_id,
            "upload_genotype_vcf_observation_type"=>"accession",
            "upload_genotype_vcf_facility_select"=>"IGD",
            "upload_genotype_vcf_project_description"=>"Test uploading",
            "upload_genotype_vcf_protocol_name"=>"2021_genotype_protocol",
            "upload_genotype_vcf_include_igd_numbers"=>0,
            "upload_genotype_vcf_reference_genome_name"=>"Mesculenta_511_v7",
            "upload_genotype_add_new_accessions"=>0,
            "upload_genotype_accept_warnings"=>1,
        ]
    );

#print STDERR Dumper $response;
ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = decode_json $message;
is($message_hash->{success}, 1);
ok($message_hash->{project_id});
ok($message_hash->{nd_protocol_id});

my $protocol_id = $message_hash->{nd_protocol_id};

#test adding markerset
$mech->get_ok('http://localhost:3010/list/new?name=test_markerset_1&desc=test');
$response = decode_json $mech->content;
my $markerset_list_id = $response->{list_id};
#print STDERR "MARKERSET LIST ID =".Dumper($markerset_list_id)."\n";
ok($markerset_list_id);

$mech->get_ok('http://localhost:3010/list/item/add?list_id='.$markerset_list_id.'&element={"genotyping_protocol_name":"2021_genotype_protocol", "genotyping_protocol_id":'.$protocol_id.', "genotyping_data_type":"Dosage"}');
$response = decode_json $mech->content;
is($response->[0],'SUCCESS');

$mech->get_ok('http://localhost:3010/list/item/add?list_id='.$markerset_list_id.'&element={"marker_name":"S1_21594", "allele_dosage":"0"}');
$response = decode_json $mech->content;
is($response->[0],'SUCCESS');

$mech->get_ok('http://localhost:3010/list/new?name=test_markerset_2&desc=test');
$response = decode_json $mech->content;
my $markerset2_list_id = $response->{list_id};
#print STDERR "MARKERSET LIST ID =".Dumper($markerset_list_id)."\n";
ok($markerset2_list_id);

$mech->get_ok('http://localhost:3010/list/item/add?list_id='.$markerset2_list_id.'&element={"genotyping_protocol_name":"2021_genotype_protocol", "genotyping_protocol_id":'.$protocol_id.', "genotyping_data_type":"SNP"}');
$response = decode_json $mech->content;
is($response->[0],'SUCCESS');

$mech->get_ok('http://localhost:3010/list/item/add?list_id='.$markerset2_list_id.'&element={"marker_name":"S1_21597","allele1":"G","allele2":"G"}');
$response = decode_json $mech->content;
is($response->[0],'SUCCESS');

#create a list of accessions
$mech->get_ok('http://localhost:3010/list/new?name=accession_list_1&desc=test');
$response = decode_json $mech->content;
my $accession_list_id = $response->{list_id};
#print STDERR "ACCESSION LIST ID =".Dumper($accession_list_id)."\n";
ok($accession_list_id);

my @accessions = qw(UG120001 UG120002 UG120003 UG120004 UG120005 UG120006 UG120007 UG120008 UG120009 UG120010 UG120011 UG120012 UG120013 UG120014 UG120015 UG120016 UG120017 UG120018 UG120019 UG120020 UG120021);

my $accession_list = CXGN::List->new( { dbh=>$dbh, list_id => $accession_list_id });
my $response = $accession_list->add_bulk(\@accessions);
is($response->{'count'},21);

#test searching accessions with dosage
$mech->get_ok('http://localhost:3010/ajax/search/search_stocks_using_markerset?stock_list_id='.$accession_list_id.'&markerset_id='.$markerset_list_id);
$response = decode_json $mech->content;
#print STDERR "RESPONSE 4=".Dumper($response)."\n";
my %result_hash1 = %{$response};
my $selected_accessions_dosage = $result_hash1{'data'};
my $number_of_accessions_dosage = scalar@$selected_accessions_dosage;
is($number_of_accessions_dosage,9);

#test searching accessions with snp
$mech->get_ok('http://localhost:3010/ajax/search/search_stocks_using_markerset?stock_list_id='.$accession_list_id.'&markerset_id='.$markerset2_list_id);
$response = decode_json $mech->content;
#print STDERR "RESPONSE 4=".Dumper($response)."\n";
my %result_hash2 = %{$response};
my $selected_accessions_snp = $result_hash2{'data'};
my $number_of_accessions_snp = scalar@$selected_accessions_snp;
is($number_of_accessions_snp,14);

# Delete genotype protocol after testing
$mech->get("/ajax/genotyping_protocol/delete/$protocol_id");
$response = decode_json $mech->content;
is($response->{'success'}, 1);

done_testing();
