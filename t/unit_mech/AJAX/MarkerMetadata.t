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

#adding genotyping data for testing marker metadata
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
            "upload_genotype_year_select"=>"2015",
            "upload_genotype_breeding_program_select"=>$breeding_program_id,
            "upload_genotype_vcf_observation_type"=>"accession",
            "upload_genotype_vcf_facility_select"=>"IGD",
            "upload_genotype_vcf_project_description"=>"Test uploading",
            "upload_genotype_vcf_protocol_name"=>"2015_genotype_protocol",
            "upload_genotype_vcf_include_igd_numbers"=>0,
            "upload_genotype_vcf_reference_genome_name"=>"Mesculenta_511_v7",
            "upload_genotype_add_new_accessions"=>0,
            "upload_genotype_accept_warnings"=>1,
        ]
    );

ok($response->is_success, 'Upload genotype VCF');
my $message = $response->decoded_content;
my $message_hash = decode_json $message;
is($message_hash->{success}, 1, 'Upload genotype VCF success');
ok($message_hash->{project_id}, 'Upload genotype project id');
ok($message_hash->{nd_protocol_id}, 'Upload genotype protocol id');

my $protocol_id = $message_hash->{nd_protocol_id};
my $project_id = $message_hash->{project_id};


# Upload Marker Metadata
my $metadata_file = $f->config->{basepath} . "/t/data/genotype_data/marker_metadata.csv";
$response = $ua->post(
    "http://localhost:3010/ajax/genotyping_protocol/add_marker_metadata/$protocol_id",
    Cookie => 'sgn_session_id=' . $sgn_session_id,
    Content_Type => 'form-data',
    Content => [
        upload_mla_file => [ $metadata_file, 'marker_metadata_upload.csv' ],
    ]
);
ok($response->is_success, 'Upload marker metadata');
my $upload_resp = decode_json $response->decoded_content;
is($upload_resp->{error_string}, undef, 'Upload marker metadata - no errors');
is($upload_resp->{success}, 1, 'Upload marker metadata - success');


# Get Marker Metadata (all)
$mech->get_ok("http://localhost:3010/ajax/genotyping_protocol/get_marker_metadata/$protocol_id", 'Get marker metadata - all');
$response = decode_json $mech->content;;
my $expected = {'ML_2' => {'locus_id' => 4,'alleles' => [{'allele_name' => '2_P','allele_id' => 2},{'allele_name' => '2_A','allele_id' => 3}],'references' => [{'url' => '/cvterm/70691/view','db_name' => 'CO_334','cvterm_id' => 70691,'cvterm_name' => 'fresh root yield','dbxref_accession' => '0000013'}],'marker_name' => 'S1_26576','nd_protocol_id' => 3,'locus_name' => 'ML_2','locus_description' => 'Description of Marker 2'},'S1_21597' => {'locus_name' => 'S1_21597','locus_description' => 'Description of Marker 1','nd_protocol_id' => 3,'marker_name' => 'S1_21597','locus_id' => 6,'alleles' => [{'allele_name' => '1_P','allele_id' => 7},{'allele_id' => 8,'allele_name' => '1_A'},{'allele_id' => 9,'allele_name' => '1_H'}],'references' => [{'dbxref_accession' => '0000478','url' => '/cvterm/76801/view','db_name' => 'CO_334','cvterm_id' => 76801,'cvterm_name' => 'Stem height'}]},'S2_26659' => {'locus_description' => 'Description of Marker 3','locus_name' => 'S2_26659','nd_protocol_id' => 3,'marker_name' => 'S2_26659','references' => [],'alleles' => [{'allele_name' => '3_P','allele_id' => 4},{'allele_name' => '3_A','allele_id' => 5},{'allele_name' => '3_H','allele_id' => 6}],'locus_id' => 5}};
check_metadata_response($expected, $response, "all");


# Get Marker Metadata (S1_21597)
$mech->get_ok("http://localhost:3010/ajax/genotyping_protocol/get_marker_metadata/$protocol_id?marker_name=S1_21597", 'Get marker metadata - S1_21597');
$response = decode_json $mech->content;
$expected = {'S1_21597' => {'nd_protocol_id' => 3,'marker_name' => 'S1_21597','locus_name' => 'S1_21597','locus_description'
 => 'Description of Marker 1','alleles' => [{'allele_name' => '1_P','allele_id' => 7},{'allele_id' => 8,'allele_name' => '1_A'},{'allele_id' => 9,'allele_name' => '1_H'}],'references' => [{'db_name' => 'CO_334','url' => '/cvterm/76801/view','cvterm_name' => 'Stem height','cvterm_id' => 76801,'dbxref_accession' => '0000478'}],'locus_id' => 6}};
check_metadata_response($expected, $response, "S1_21597");


# Update Marker Metadata (S1_21597)
$mech->post(
    "http://localhost:3010/ajax/genotyping_protocol/update_marker_metadata/$protocol_id",
    {
        locus_id => $response->{S1_21597}->{locus_id},
        marker => 'S1_21597',
        description => 'Updated description of Marker 1',
        'alleles[]' => [ '1_P', '1_A', '1_UNK' ],
        'references[]' => [ 'CO_334:0000478' ]
    }
);
$response = decode_json $mech->content;
$expected = {'S1_21597' => {'alleles' => [{'allele_id' => 10,'allele_name' => '1_P'},{'allele_id' => 11,'allele_name' => '1_A'},{'allele_id' => 12,'allele_name' => '1_UNK'}],'locus_name' => 'S1_21597','nd_protocol_id' => 3,'locus_description' => 'Updated description of Marker 1','references' => [{'cvterm_id' => 76801,'db_name' => 'CO_334','cvterm_name' => 'Stem height','url' => '/cvterm/76801/view','dbxref_accession' => '0000478'}],'locus_id' => 7,'marker_name' => 'S1_21597'}};
check_metadata_response($expected, $response, "S1_21597 - updated");


# Delete marker metadata
$response = $ua->delete("http://localhost:3010/ajax/genotyping_protocol/delete_marker_metadata/$protocol_id", Cookie => "sgn_session_id=$sgn_session_id");
ok($response->is_success, 'Delete marker metadata');

# Delete genotype protocol after testing
$mech->get("/ajax/genotyping_protocol/delete/$protocol_id");
$response = decode_json $mech->content;
is($response->{'success'}, 1, 'Delete genotype protocol');

#Delete genotype project
$schema->resultset("Project::Project")->find({project_id=>$project_id})->delete();

$f->clean_up_db();

done_testing();


sub check_metadata_response {
    my $expected = shift;
    my $response = shift;
    my $label = shift;

    # Check marker names
    my $expected_loci = keys %$expected;
    my $response_loci = keys %$response;
    is_deeply($response_loci, $expected_loci, "Get marker metadata - $label - marker names");

    # Check marker descriptions
    my %expected_descriptions;
    my %response_descriptions;
     foreach my $m (keys %$expected) {
        $expected_descriptions{$m} = $expected->{$m}->{locus_description};
    }
    foreach my $m (keys %$response) {
        $response_descriptions{$m} = $response->{$m}->{locus_description};
    }
    is_deeply(\%response_descriptions, \%expected_descriptions, "Get marker metadata - $label - marker descriptions");

    # Check allele names
    my %expected_alleles;
    my %response_alleles;
    foreach my $m (keys %$expected) {
        my @an = map { $_->{allele_name} } @{$expected->{$m}->{alleles}};
        $expected_alleles{$m} = \@an;
    }
    foreach my $m (keys %$response) {
        my @an = map { $_->{allele_name} } @{$response->{$m}->{alleles}};
        $response_alleles{$m} = \@an;
    }
    is_deeply(\%response_alleles, \%expected_alleles, "Get marker metadata - $label - allele names");

    # Check references
    my %expected_references;
    my %response_references;
    foreach my $m (keys %$expected) {
        my @ref = map { $_->{db_name} . ":" . $_->{dbxref_accession} } @{$expected->{$m}->{references}};
        $expected_references{$m} = \@ref;
    }
    foreach my $m (keys %$response) {
        my @ref = map { $_->{db_name} . ":" . $_->{dbxref_accession} } @{$response->{$m}->{references}};
        $response_references{$m} = \@ref;
    }
    is_deeply(\%response_references, \%expected_references, "Get marker metadata - $label - references");
}