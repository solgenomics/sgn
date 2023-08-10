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
#print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};
#print STDERR $sgn_session_id."\n";

my $location_rs = $schema->resultset('NaturalDiversity::NdGeolocation')->search({description => 'Cornell Biotech'});
my $location_id = $location_rs->first->nd_geolocation_id;

my $bp_rs = $schema->resultset('Project::Project')->search({name => 'test'});
my $breeding_program_id = $bp_rs->first->project_id;

my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();
my @new_accessions;
for (my $i = 1; $i <= 10; $i++) {
    push(@new_accessions, "new_accession_" . $i);
}

my $organism = $schema->resultset("Organism::Organism")->find_or_create({
    genus   => 'Test_genus',
    species => 'Test_genus test_species',
});

foreach my $new_accession (@new_accessions) {
    my $add_new_accession = $schema->resultset('Stock::Stock')
        ->create({
        organism_id => $organism->organism_id,
        name        => $new_accession,
        uniquename  => $new_accession,
        type_id     => $accession_type_id,
    });
};

my $file = $f->config->{basepath}."/t/data/genotype_data/kasp_results.csv";
my $marker_info_file = $f->config->{basepath}."/t/data/genotype_data/kasp_marker_info.csv";

#test upload kasp data using customer marker names and sample names in the database.
my $ua = LWP::UserAgent->new;
$response = $ua->post(
    'http://localhost:3010/ajax/genotype/upload',
    Content_Type => 'form-data',
    Content => [
        upload_genotype_data_kasp_file_input => [ $file, 'kasp_data_upload' ],
        upload_genotype_kasp_marker_info_file_input => [ $marker_info_file, 'kasp_marker_info_upload' ],
        "sgn_session_id"=>$sgn_session_id,
        "upload_genotypes_species_name_input"=>"Manihot esculenta",
        "upload_genotype_vcf_project_name"=>"kasp_project_1",
        "upload_genotype_location_select"=>$location_id,
        "upload_genotype_year_select"=>"2023",
        "upload_genotype_breeding_program_select"=>$breeding_program_id,
        "upload_genotype_vcf_observation_type"=>"accession",
        "upload_genotype_vcf_facility_select"=>"Intertek",
        "upload_genotype_vcf_project_description"=>"test",
        "upload_genotype_vcf_protocol_name"=>"kasp_protocol_1",
        "upload_genotype_vcf_reference_genome_name"=>"Mesculenta_511_v7",
        "upload_genotype_add_new_accessions"=>0,
        "assay_type"=>"KASP",
    ]
);

my $message = $response->decoded_content;
my $message_hash = decode_json $message;
ok($message_hash->{nd_protocol_id});

my $kasp_project_id = $message_hash->{project_id};
my $kasp_protocol_id = $message_hash->{nd_protocol_id};

$mech->get_ok('http://localhost:3010/ajax/genotyping_protocol/markers_search?protocol_id='.$kasp_protocol_id.'&marker_names=S01_0001');
$response = decode_json $mech->content;
is_deeply($response->{'data'}, [['S01_0001','S01','7926132','T','G','AAAAACATTAAAATT[T/G]TAGGCCGGAGCAAG']]);






done_testing();
