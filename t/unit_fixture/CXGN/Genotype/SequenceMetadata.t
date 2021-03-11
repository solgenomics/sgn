use strict;

use lib 't/lib';

use Test::More tests => 16;

use Data::Dumper;
use JSON;
use File::Copy;

use SGN::Test::Fixture;
use SGN::Test::Data qw/create_test/;
use SGN::Test::WWW::Mechanize;
use LWP::UserAgent;

use SGN::Model::Cvterm;
use CXGN::Genotype::SequenceMetadata;


my $t = SGN::Test::Fixture->new();
my $mech = SGN::Test::WWW::Mechanize->new;
my $ua = LWP::UserAgent->new;
my $schema = $t->bcs_schema;

my $smd = CXGN::Genotype::SequenceMetadata->new(bcs_schema => $schema);
my $smd_script_dir = $t->config->{basepath} . $smd->shell_script_dir;
my $test_file = $t->config->{basepath} . "/t/data/sequence_metadata/gwas_sgn.gff3";

my ($organism_rs) = $schema->resultset("Organism::Organism")->find_or_create({genus => 'Test', species => 'test'});
my $feature_organism_id = $organism_rs->organism_id;
my $feature_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'chromosome', 'sequence')->cvterm_id();
my $type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'GWAS Results', 'sequence_metadata_types')->cvterm_id();

my $query_feature_name = "chr1A";
my $query_feature_id;
my $query_type_name = "GWAS Results";
my $query_type_id;
my $query_protocol_name = "Test Protocol";
my $query_protocol_id;


# Get features from test file
my $script = $smd_script_dir . "/get_unique_features.sh";
my $cmd = "bash " . $script . " \"" . $test_file . "\"";
my @features = `$cmd`;
chomp(@features);

# Add features to database
foreach my $feature (@features) {
    if ( $feature !~ /^#/ ) {
        my ($feature_rs) = $schema->resultset("Sequence::Feature")->find_or_create({
            organism_id => $feature_organism_id,
            name => $feature,
            uniquename => $feature,
            type_id => $feature_type_id,
            is_obsolete => 'f'
        });
    }
}

# Get attributes from test file
my $attributes_script = $smd_script_dir . "/get_unique_attributes.sh";
my $attributes_cmd = "bash " . $attributes_script . " \"" . $test_file . "\"";
my @attributes = `$attributes_cmd`;
chomp(@attributes);




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
## TEST: VERIFY GFF FILE
## tests = 2
##
my %verification_body = (
    file => [ $test_file, 'sequence_metadata_upload' ],
    "use_existing_protocol" => "false",
    "new_protocol_attribute_count" => scalar @attributes
);
my $verification_attribute_count = 1;
foreach my $a (@attributes) {
    $verification_body{'new_protocol_attribute_key_' . $verification_attribute_count} = $a;
    $verification_attribute_count++;
}

my $verification_response = $ua->post(
    'http://localhost:3010/ajax/sequence_metadata/file_upload_verify',
    Cookie => 'sgn_session_id=' . $sgn_session_id,
    Content_Type => 'form-data',
    Content => \%verification_body
);
my $verification_message = decode_json $verification_response->decoded_content;
my $processed_file = $verification_message->{'results'}->{'processed_filepath'};
is($verification_message->{'results'}->{'processed'}, 1, "Process GFF File");
is($verification_message->{'results'}->{'verified'}, 1, "Verify GFF File");



##
## TEST 3: STORE GFF FILE
## tests = 2
##
my %store_body = (
    "processed_filepath" => $processed_file,
    "use_existing_protocol" => "false",
    "new_protocol_name" => $query_protocol_name,
    "new_protocol_description" => "Protocol used for testing the sequence metadata storage",
    "new_protocol_sequence_metadata_type" => $type_id,
    "new_protocol_reference_genome" => "Test Reference Genome",
    "new_protocol_score_description" => "score description",
    "new_protocol_attribute_count" => scalar @attributes
);
my $store_attribute_count = 1;
foreach my $a (@attributes) {
    $store_body{'new_protocol_attribute_key_' . $store_attribute_count} = $a;
    $store_attribute_count++;
}

my $store_response = $ua->post(
    'http://localhost:3010/ajax/sequence_metadata/store',
    Cookie => 'sgn_session_id=' . $sgn_session_id,
    Content_Type => 'form-data',
    Content => \%store_body
);
my $store_message = decode_json $store_response->decoded_content;
is($store_message->{'results'}->{'stored'}, 1, "Store GFF File");
cmp_ok($store_message->{'results'}->{'chunks'}, 'gt', 0, "Stored Chunks");



##
## TEST: GET FEATURES
## tests = 1
##
$mech->get('/ajax/sequence_metadata/features');
my $features_response = decode_json($mech->content)->{'features'};
my $missing_features = 0;
foreach my $ff (@features) {
    if ( $ff !~ /^#/ ) {
        my $found = 0;
        foreach my $rf (@$features_response) {
            if ( $rf->{'feature_name'} eq $ff ) {
                $found = 1;
                if ( $ff eq $query_feature_name ) {
                    $query_feature_id = $rf->{'feature_id'};
                }
            }
        }
        if ( !$found ) {
            $missing_features++;
        }
    }
}
is($missing_features, 0, "Stored and Retrieved Features");



##
## TEST: GET DATA TYPES
## tests = 1
##
$mech->get('/ajax/sequence_metadata/types');
my $types_response = decode_json($mech->content)->{'types'};
foreach my $type (@$types_response) {
    if ( $type->{'type_name'} eq $query_type_name ) {
        $query_type_id = $type->{'type_id'};
    }
}
cmp_ok(scalar @$types_response, 'gt', 0, "Retrieved Data Types");



##
## TEST: GET PROTOCOLS
## tests = 1
##
$mech->get('/ajax/sequence_metadata/protocols');
my $protocols_response = decode_json($mech->content)->{'protocols'};
my $found_protocol = 0;
foreach my $protocol (@$protocols_response) {
    if ( $protocol->{'nd_protocol_name'} eq $query_protocol_name ) {
        $found_protocol = 1;
        $query_protocol_id = $protocol->{'nd_protocol_id'};
    }
}
is($found_protocol, 1, "Stored and Retrieved Protocol");



##
## TEST: QUERY
## tests = 6
##
isnt($query_feature_id, undef, "Query Feature ID Defined");
isnt($query_type_id, undef, "Query Type ID Defined");
isnt($query_protocol_id, undef, "Query Protocol ID Defined");

my $params = "feature_id=$query_feature_id&type_id=$query_type_id&nd_protocol_id=$query_protocol_id&";
$params .= "start=20000000&end=22000000&";
$params .= "attribute=score|$query_protocol_id|gt|0.03,Locus|$query_protocol_id|eq|TraesCS1A02G038400";

# JSON Format
$mech->get("/ajax/sequence_metadata/query?$params&format=JSON");
my $json_response = decode_json($mech->content);
is_deeply($json_response, {
    'results' => [
        {
            'start' => 21040550,
            'featureprop_json_id' => 1,
            'type_id' => $query_type_id,
            'end' => 21040550,
            'type_name' => $query_type_name,
            'nd_protocol_id' => $query_protocol_id,
            'attributes' => {
                    'qvalue' => '0.0455793811186712',
                    'Variable' => 'CO_321:0001138',
                    'zvalue' => '3.3484904423247',
                    'ID' => 'Ex_c64327_523',
                    'Trait' => 'SDS sedimentation',
                    'Locus' => 'TraesCS1A02G038400',
                    'Population' => 'TCAP90K_SpringAM_panel x SW-AMPanel_2012_Saskatoon',
                    'pvalue' => '0.000812530833156448'
                },
            'feature_id' => $query_feature_id,
            'nd_protocol_name' => $query_protocol_name,
            'feature_name' => $query_feature_name,
            'score' => '0.0455793811186712'
        }
    ]
}, 'Query JSON Response');


# GA4GH Format
$mech->get("/ajax/sequence_metadata/query?$params&format=GA4GH");
my $ga4gh_response = decode_json($mech->content);
is_deeply($ga4gh_response, {
    'features' => [
        {
            'end' => 21040550,
            'feature_set_id' => $query_protocol_id,
            'reference_name' => $query_feature_name,
            'parent_id' => $query_feature_id,
            'start' => 21040550,
            'attributes' => {
                'Population' => [
                    'TCAP90K_SpringAM_panel x SW-AMPanel_2012_Saskatoon'
                ],
                'pvalue' => [
                    '0.000812530833156448'
                ],
                'zvalue' => [
                    '3.3484904423247'
                ],
                'Locus' => [
                    'TraesCS1A02G038400'
                ],
                'bb_metadata' => {
                    'type_name' => [
                        'GWAS Results'
                    ],
                    'type_id' => [
                        $query_type_id
                    ],
                    'nd_protocol_id' => [
                        $query_protocol_id
                    ],
                    'nd_protocol_name' => [
                        $query_protocol_name
                    ]
                },
                'ID' => [
                    'Ex_c64327_523'
                ],
                'Variable' => [
                    'CO_321:0001138'
                ],
                'Trait' => [
                    'SDS sedimentation'
                ],
                'score' => [
                    '0.0455793811186712'
                ],
                'qvalue' => [
                    '0.0455793811186712'
                ]
            },
            'id' => '1.0'
        }
    ]
}, "Query GA4GH Response");

# GFF Format
$mech->get("/ajax/sequence_metadata/query?$params&format=gff");
my $gff_response = $mech->content;
like(
    $gff_response,
    qr/$query_feature_name\t\.\t\.\t21040550\t21040550\t0\.0455793811186712\t\.\t\.\t.*/,
    "Query GFF Response"
);



done_testing();