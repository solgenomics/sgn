use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use LWP::UserAgent;
use CXGN::Genotype::Search;
use Data::Dumper;
use JSON;
use CXGN::Genotype::StoreGenotypingProject;
use CXGN::Genotype::Protocol;
use CXGN::Genotype::ProtocolProp;
use SGN::Model::Cvterm;

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
    my $add_new_accession = $schema->resultset('Stock::Stock')->create({
        organism_id => $organism->organism_id,
        name        => $new_accession,
        uniquename  => $new_accession,
        type_id     => $accession_type_id,
    });
};

#add projects
my $add_genotyping_project_1 = CXGN::Genotype::StoreGenotypingProject->new({
    chado_schema        => $schema,
    dbh                 => $f->dbh(),
    project_name        => 'kasp_project_1',
    breeding_program_id => $breeding_program_id,
    project_facility    => 'intertek',
    data_type           => 'snp',
    year                => '2023',
    project_description => 'genotyping project for test',
    nd_geolocation_id   => $location_id,
    owner_id            => 41
});
ok(my $store_return_1 = $add_genotyping_project_1->store_genotyping_project(), "store genotyping project");

my $gp_rs_1 = $schema->resultset('Project::Project')->find({ name => 'kasp_project_1' });
my $genotyping_project_id_1 = $gp_rs_1->project_id();

my $add_genotyping_project_2 = CXGN::Genotype::StoreGenotypingProject->new({
    chado_schema        => $schema,
    dbh                 => $dbh,
    project_name        => 'kasp_project_2',
    breeding_program_id => $breeding_program_id,
    project_facility    => 'intertek',
    data_type           => 'snp',
    year                => '2023',
    project_description => 'genotyping project for test',
    nd_geolocation_id   => $location_id,
    owner_id            => 41
});
ok(my $store_return_2 = $add_genotyping_project_2->store_genotyping_project(), "store genotyping project");

my $gp_rs_2 = $schema->resultset('Project::Project')->find({ name => 'kasp_project_2' });
my $genotyping_project_id_2 = $gp_rs_2->project_id();

#test upload kasp data using customer marker names and sample names in the database.
my $file = $f->config->{basepath}."/t/data/genotype_data/kasp_results.csv";
my $marker_info_file = $f->config->{basepath}."/t/data/genotype_data/kasp_marker_info.csv";

my $ua = LWP::UserAgent->new;
$response = $ua->post(
    'http://localhost:3010/ajax/genotype/upload',
    Content_Type => 'form-data',
    Content => [
        upload_genotype_data_kasp_file_input => [ $file, 'kasp_data_upload' ],
        upload_genotype_kasp_marker_info_file_input => [ $marker_info_file, 'kasp_marker_info_upload' ],
        "sgn_session_id"=>$sgn_session_id,
        "upload_genotypes_species_name_input"=>"Manihot esculenta",
        "upload_genotype_project_id"=>$genotyping_project_id_1,
        "upload_genotype_location_select"=>$location_id,
        "upload_genotype_year_select"=>"2023",
        "upload_genotype_breeding_program_select"=>$breeding_program_id,
        "upload_genotype_vcf_observation_type"=>"accession",
        "upload_genotype_vcf_facility_select"=>"intertek",
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

my $kasp_project_id_1 = $message_hash->{project_id};
my $kasp_protocol_id_1 = $message_hash->{nd_protocol_id};


$mech->get_ok('http://localhost:3010/ajax/genotyping_protocol/markers_search?protocol_id='.$kasp_protocol_id_1.'&marker_names=S01_0001');
$response = decode_json $mech->content;
is_deeply($response->{'data'}, [['S01_0001','S01','7926132','T','G','AAAAACATTAAAATT[T/G]TAGGCCGGAGCAAG']]);

my $genotypes_search_1 = CXGN::Genotype::Search->new({
    bcs_schema=>$schema,
    people_schema=>$people_schema,
    protocol_id_list=>[$kasp_protocol_id_1],
});
my ($total_count_1, $data_1) = $genotypes_search_1->get_genotype_info();
is($total_count_1, 5);

#test KASP data download from project page

my $kasp_project_response = $ua->get("http://localhost:3010/breeders/download_kasp_genotyping_data_csv/?genotyping_project_id=$genotyping_project_id_1");
my $kasp_project_message = $kasp_project_response->decoded_content;

my $kasp_data = '"MARKER NAME","SAMPLE NAME","SNP CALL (X,Y)","X VALUE","Y VALUE"
"S01_0001","new_accession_1","T,T","1.36",".58"
"S01_0001","new_accession_2","T,T","1.25",".49"
"S01_0001","new_accession_3","T,G","1.57","1.38"
"S01_0001","new_accession_4","T,G","1.24","1.56"
"S01_0001","new_accession_5","./.",".65",".58"
"S01_0002","new_accession_1","A,A","1.43",".59"
"S01_0002","new_accession_2","A,G","1.25","1.43"
"S01_0002","new_accession_3","A,G","1.22","1.41"
"S01_0002","new_accession_4","A,G","1.11","1.27"
"S01_0002","new_accession_5","A,A","1.65",".62"
"S02_0001","new_accession_1","T,T","1.75",".75"
"S02_0001","new_accession_2","T,T","1.21",".61"
"S02_0001","new_accession_3","T,T","1.17",".46"
"S02_0001","new_accession_4","T,C","1.59","1.46"
"S02_0001","new_accession_5","T,C","1.26","1.31"
"S02_0002","new_accession_1","A,A","1.75",".32"
"S02_0002","new_accession_2","A,A","1.38",".59"
"S02_0002","new_accession_3","A,C","1.36","1.47"
"S02_0002","new_accession_4","A,A","1.75",".74"
"S02_0002","new_accession_5","A,C","1.32","1.46"
"S03_0001","new_accession_1","C,C","1.76",".38"
"S03_0001","new_accession_2","C,C","1.47",".24"
"S03_0001","new_accession_3","C,T","1.86","1.48"
"S03_0001","new_accession_4","C,T","1.23","1.49"
"S03_0001","new_accession_5","C,T","1.11","1.23"
';

is($kasp_project_message, $kasp_data);

#test upload kasp data using facility names
#store facility sample Names
my $plate_file = $f->config->{basepath} . "/t/data/genotype_trial_upload/plate_with_identifier_upload.xls";
my $plate_ua = LWP::UserAgent->new;
$response = $plate_ua->post(
    'http://localhost:3010/ajax/breeders/parsegenotypetrial',
    Content_Type => 'form-data',
    Content      => [
        genotyping_trial_layout_upload => [
            $plate_file,
            "plate_with_identifier_upload.xls",
            Content_Type => 'application/vnd.ms-excel',
        ],
        "sgn_session_id" => $sgn_session_id,
        "genotyping_trial_name" => '2023_plate_1',
        "upload_include_facility_identifiers" => 1,
    ]
);

ok($response->is_success);
$message = $response->decoded_content;
$message_hash = decode_json $message;

my $plate_data = {
    design                     => $message_hash->{design},
    genotyping_facility_submit => 'no',
    name                       => '2023_plate_1',
    genotyping_project_id      => $genotyping_project_id_2,
    sample_type                => 'tissue_sample',
    plate_format               => '96'
};

$mech->post_ok('http://localhost:3010/ajax/breeders/storegenotypetrial', [ "sgn_session_id" => $sgn_session_id, plate_data => encode_json($plate_data) ]);
$response = decode_json $mech->content;
ok($response->{trial_id});
my $plate_id = $response->{trial_id};


my $facility_file = $f->config->{basepath}."/t/data/genotype_data/kasp_results_with_facility_names_1.csv";
my $facility_marker_info_file = $f->config->{basepath}."/t/data/genotype_data/kasp_marker_info_with_facility_names.csv";

my $ua2 = LWP::UserAgent->new;
$response = $ua2->post(
    'http://localhost:3010/ajax/genotype/upload',
    Content_Type => 'form-data',
    Content => [
        upload_genotype_data_kasp_file_input => [ $facility_file, 'kasp_data_upload_using_facility_names' ],
        upload_genotype_kasp_marker_info_file_input => [ $facility_marker_info_file, 'kasp_marker_info_upload_with_facility_names' ],
        "sgn_session_id"=>$sgn_session_id,
        "upload_genotypes_species_name_input"=>"Manihot esculenta",
        "upload_genotype_project_id"=>$genotyping_project_id_2,
        "upload_genotype_location_select"=>$location_id,
        "upload_genotype_year_select"=>"2023",
        "upload_genotype_breeding_program_select"=>$breeding_program_id,
        "upload_genotype_vcf_observation_type"=>"tissue_sample",
        "upload_genotype_vcf_facility_select"=>"intertek",
        "upload_genotype_vcf_project_description"=>"test",
        "upload_genotype_vcf_protocol_name"=>"kasp_protocol_2",
        "upload_genotype_vcf_reference_genome_name"=>"Mesculenta_511_v7",
        "upload_genotype_add_new_accessions"=>0,
        "assay_type"=>"KASP",
    ]
);

$message = $response->decoded_content;
$message_hash = decode_json $message;
ok($message_hash->{nd_protocol_id});

my $kasp_project_id_2 = $message_hash->{project_id};
my $kasp_protocol_id_2 = $message_hash->{nd_protocol_id};

$mech->get_ok('http://localhost:3010/ajax/genotyping_protocol/markers_search?protocol_id='.$kasp_protocol_id_2.'&marker_names=S01_0001');
$response = decode_json $mech->content;
is_deeply($response->{'data'}, [['S01_0001','S01','7926132','T','G','AAAAACATTAAAATT[T/G]TAGGCCGGAGCAAG','snpME0001']]);

my $genotypes_search_2 = CXGN::Genotype::Search->new({
    bcs_schema=>$schema,
    people_schema=>$people_schema,
    protocol_id_list=>[$kasp_protocol_id_2],
});
my ($total_count_2, $data_2) = $genotypes_search_2->get_genotype_info();
is($total_count_2, 4);

#upload with incorrect marker info
my $facility_file_3 = $f->config->{basepath}."/t/data/genotype_data/kasp_results_with_facility_names_2.csv";
my $facility_marker_info_file_3 = $f->config->{basepath}."/t/data/genotype_data/kasp_marker_info_with_facility_names_error.csv";

my $ua3 = LWP::UserAgent->new;
$response = $ua3->post(
    'http://localhost:3010/ajax/genotype/upload',
    Content_Type => 'form-data',
    Content => [
        upload_genotype_data_kasp_file_input => [ $facility_file_3, 'kasp_data_upload_using_facility_names' ],
        upload_genotype_kasp_marker_info_file_input => [ $facility_marker_info_file_3, 'kasp_marker_info_upload_with_facility_names' ],
        "sgn_session_id"=>$sgn_session_id,
        "upload_genotype_project_id"=>$genotyping_project_id_2,
        "upload_genotype_protocol_id"=>$kasp_protocol_id_2,
        "upload_genotypes_species_name_input"=>"Manihot esculenta",
        "upload_genotype_location_select"=>$location_id,
        "upload_genotype_vcf_observation_type"=>"tissue_sample",
        "upload_genotype_vcf_include_igd_numbers"=>0,
        "upload_genotype_add_new_accessions"=>0,
        "upload_genotype_accept_warnings"=>0
    ]
);

$message = $response->decoded_content;
$message_hash = decode_json $message;
ok($message_hash->{warning});

#checking protocol metadata
my $protocol = CXGN::Genotype::Protocol->new({
    bcs_schema => $schema,
    nd_protocol_id => $kasp_protocol_id_1
});

is($protocol->protocol_name, 'kasp_protocol_1');
is($protocol->assay_type, 'KASP');
is($protocol->reference_genome_name, 'Mesculenta_511_v7');
is($protocol->species_name, 'Manihot esculenta');

#editing protocol metadata
my $protocol_vcf_details_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_map_details', 'protocol_property')->cvterm_id();
my $protocolprop_rs = $schema->resultset('NaturalDiversity::NdProtocolprop')->find({'nd_protocol_id' => $kasp_protocol_id_1, 'type_id' => $protocol_vcf_details_cvterm_id});
my $protocolprop_id = $protocolprop_rs->nd_protocolprop_id();
my $protocolprop = CXGN::Genotype::ProtocolProp->new({
    bcs_schema => $schema,
    parent_id => $kasp_protocol_id_1,
    prop_id => $protocolprop_id
});

ok($protocol->set_name('kasp_protocol_1_edited'));
ok($protocol->set_description('test editing description'));

$protocolprop->reference_genome_name('Mesculenta_511_v8');
ok($protocolprop->store());

#after editing
my $protocol_edited = CXGN::Genotype::Protocol->new({
    bcs_schema => $schema,
    nd_protocol_id => $kasp_protocol_id_1
});

is($protocol_edited->protocol_name, 'kasp_protocol_1_edited');
is($protocol_edited->protocol_description, 'test editing description');
is($protocol_edited->reference_genome_name, 'Mesculenta_511_v8');

## DELETE genotyping protocols, data, plate and projects
$mech->get_ok("http://localhost:3010/ajax/genotyping_protocol/delete/$kasp_protocol_id_1?sgn_session_id=$sgn_session_id");
$response = decode_json $mech->content;
is_deeply($response, {success=>1});

$mech->get_ok("http://localhost:3010/ajax/genotyping_protocol/delete/$kasp_protocol_id_2?sgn_session_id=$sgn_session_id");
$response = decode_json $mech->content;
is_deeply($response, {success=>1});

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$plate_id.'/delete/layout');
$response = decode_json $mech->content;
is($response->{'success'}, '1');


$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$genotyping_project_id_1.'/delete/genotyping_project');
$response = decode_json $mech->content;
is($response->{'success'}, '1');

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$genotyping_project_id_2.'/delete/genotyping_project');
$response = decode_json $mech->content;
is($response->{'success'}, '1');


done_testing();
