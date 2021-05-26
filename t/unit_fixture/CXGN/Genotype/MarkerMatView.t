use strict;

use lib 't/lib';

use Test::More tests => 14;

use Data::Dumper;
use JSON;

use SGN::Test::Fixture;
use SGN::Test::Data qw/create_test/;
use SGN::Test::WWW::Mechanize;
use LWP::UserAgent;

my $t = SGN::Test::Fixture->new();
my $mech = SGN::Test::WWW::Mechanize->new;
my $ua = LWP::UserAgent->new;
my $schema = $t->bcs_schema;


my $vcf_file = $t->config->{basepath} . "/t/data/genotype_data/test_markers.vcf";
my $vcf_file_marker_count = 10;
my $vcf_file_chrom = "1";
my $vcf_file_pos = 158861;

# Add Test Organism
my $reference_genome = "TestRefMap";
my $genus_name = "Test";
my $species_name = "test";
my $species = $genus_name . ' ' . $species_name;
my ($organism_rs) = $schema->resultset("Organism::Organism")->find_or_create({genus => $genus_name, species => $species});

# Get Location
my $location_rs = $schema->resultset('NaturalDiversity::NdGeolocation')->search({description => 'Cornell Biotech'});
my $location_id = $location_rs->first->nd_geolocation_id;

# Get Breeding Program
my $bp_rs = $schema->resultset('Project::Project')->search({name => 'test'});
my $breeding_program_id = $bp_rs->first->project_id;


##
## TEST: LOGIN
## tests = 3
##
$mech->post_ok('/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ], "BrAPI Login");
my $response = decode_json $mech->content;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull', "Login Succssful");
my $sgn_session_id = $response->{access_token};
isnt($sgn_session_id, '', "SGN Session Token");


##
## TEST: GENOTYPE UPLOAD
## tests = 2
##
$response = $ua->post(
    'http://localhost:3010/ajax/genotype/upload',
    Content_Type => 'form-data',
    Content => [
        upload_genotype_vcf_file_input => [ $vcf_file, 'genotype_vcf_data_upload' ],
        "sgn_session_id" => $sgn_session_id,
        "upload_genotypes_species_name_input" => $species,
        "upload_genotype_vcf_project_name" => "MatView Test Genotype Project",
        "upload_genotype_vcf_project_description" => "A test genotype project for the materialized_markervew matview",
        "upload_genotype_location_select" => $location_id,
        "upload_genotype_year_select" => "2020",
        "upload_genotype_breeding_program_select" => $breeding_program_id,
        "upload_genotype_vcf_observation_type" => "accession",
        "upload_genotype_vcf_facility_select" => "IGD",
        "upload_genotype_vcf_protocol_name" => "MatView Test Genotype Protocol",
        "upload_genotype_vcf_reference_genome_name" => $reference_genome,
        "upload_genotype_add_new_accessions" => 0
    ]
);
ok($response->is_success);
my $message = decode_json($response->decoded_content);
is($message->{success}, 1);


# PAUSE: wait for materialized_markerview table to be refreshed
sleep 10;


##
## TEST: GET REFERENCE GENOMES
## tests = 1
##
$mech->get('/ajax/markers/genotyped/reference_genomes');
my $reference_genomes_response = decode_json($mech->content)->{'reference_genomes'};
cmp_ok(scalar @$reference_genomes_response, 'gt', 0, "Retrieved Reference Genomes");


##
## TEST: GET CHROMOSOMES
## tests = 1
##
$mech->get('/ajax/markers/genotyped/chromosomes');
my $chromosomes_response = decode_json($mech->content)->{'chromosomes'};
my $test_chromosomes = $chromosomes_response->{$species}->{$reference_genome};
cmp_ok(scalar @$test_chromosomes, 'gt', 0, "Retrieved Chromosomes");


##
## TEST: GET PROTOCOLS
## tests = 1
##
$mech->get('/ajax/markers/genotyped/protocols');
my $protocols_response = decode_json($mech->content)->{'protocols'};
cmp_ok(scalar @$protocols_response, 'gt', 0, "Retrieved Protocols");


##
## TEST: QUERY BY NAME (SUBSTRING)
## tests = 2
##
$mech->get('/ajax/markers/genotyped/query?name=test&name_match=starts_with');
my $name_query_substring_results = decode_json($mech->content)->{'results'};
is($name_query_substring_results->{'counts'}->{'markers'}, $vcf_file_marker_count, "Query name substring count");
is(scalar keys %{$name_query_substring_results->{'variants'}}, $vcf_file_marker_count, "Query name substring variants");


##
## TEST: QUERY BY NAME (EXACT)
## tests = 2
##
$mech->get('/ajax/markers/genotyped/query?name=test_marker_7&name_match=exact');
my $name_query_exact_results = decode_json($mech->content)->{'results'};
is($name_query_exact_results->{'counts'}->{'markers'}, 1, "Query name exact count");
is(scalar keys %{$name_query_exact_results->{'variants'}}, 1, "Query name exact variants");


##
## TEST: QUERY BY POSITION
## tests = 2
##
$mech->get("/ajax/markers/genotyped/query?species=$species&reference_genome=$reference_genome&chrom=$vcf_file_chrom&start=$vcf_file_pos&end=$vcf_file_pos");
my $position_query_results = decode_json($mech->content)->{'results'};
is($position_query_results->{'counts'}->{'markers'}, 1, "Query position count");
is(scalar keys %{$position_query_results->{'variants'}}, 1, "Query position variants");


done_testing();