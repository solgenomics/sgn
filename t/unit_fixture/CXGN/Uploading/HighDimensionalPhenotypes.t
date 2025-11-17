use strict;
use warnings;

use lib 't/lib';
use Test::More tests => 7;
use SGN::Test::Fixture;
use SGN::Test::WWW::Mechanize;
use CXGN::Phenotypes::ParseUpload;
use CXGN::UploadFile;
use CXGN::Phenotypes::StorePhenotypes;
use DateTime;
use File::Temp qw(tempfile);
use JSON;
use Data::Dumper;
use CXGN::Trial;
use SimulateC;


local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();
my $metadata_schema = $f->metadata_schema();
my $phenome_schema = $f->phenome_schema();

my $mech = SGN::Test::WWW::Mechanize->new();
my $data;
my $submit_result;

my $c = SimulateC->new({ dbh => $f->dbh(),
		bcs_schema               => $f->bcs_schema(),
		metadata_schema          => $f->metadata_schema(),
		phenome_schema           => $f->phenome_schema(),
		sp_person_id             => 41 });

my $trial_id = 137;


$mech->post_ok('http://localhost:3010/brapi/v2/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = decode_json $mech->content;
my $sgn_session_id = $response->{access_token};

my $trial = CXGN::Trial->new({ bcs_schema => $f->bcs_schema(), trial_id => $trial_id });
$trial->create_plant_entities('2');

$trial = CXGN::Trial->new({ bcs_schema => $f->bcs_schema(), trial_id => $trial_id });
is($trial->create_tissue_samples(['leaf', ], 1, 0), 1, 'test create tissue samples without tissue numbers');

# Create fake transcriptomics CSV
my ($fh_data, $file_data) = tempfile(SUFFIX => '.csv');
print $fh_data join("\n",
    "sample_name,device_id,comments,Manes.01G000100,Manes.01G000200",
    "sampleA,dev1,ok,5.1,8.2",
    "sampleB,dev1,ok,9.4,1.2"
);
close $fh_data;

# Create fake metadata transcript CSV
my ($fh_meta, $file_meta) = tempfile(SUFFIX => '.csv');
print $fh_meta join("\n",
    "transcript_name,description",
    "Manes.01G000100,gene A",
    "Manes.01G000200,gene B"
);
close $fh_meta;

# POST to VERIFY endpoint

$mech->post_ok(
    '/ajax/highdimensionalphenotypes/transcriptomics_upload_verify',
    Content_Type => 'form-data',
    Content => [
        upload_transcriptomics_spreadsheet_protocol_name         => "Test Protocol",
        upload_transcriptomics_spreadsheet_protocol_desc         => "Test Desc",
        upload_transcriptomics_spreadsheet_protocol_unit         => "TPM",
        upload_transcriptomics_spreadsheet_protocol_genome       => "v1",
        upload_transcriptomics_spreadsheet_protocol_annotation   => "v1",
        upload_transcriptomics_spreadsheet_protocol_instrument_model   => "Illumina",
        upload_transcriptomics_spreadsheet_protocol_layout             => "Paired-end",
        upload_transcriptomics_spreadsheet_protocol_library_method     => "RNA-seq",
        upload_transcriptomics_spreadsheet_protocol_library_comments   => "None",
        upload_transcriptomics_spreadsheet_protocol_mapping_software   => "STAR",
        upload_transcriptomics_spreadsheet_protocol_sequencing_center  => "Cornell",
        upload_transcriptomics_spreadsheet_protocol_sequencing_platform=> "NovaSeq",
        upload_transcriptomics_spreadsheet_protocol_read_length        => "150",
        upload_transcriptomics_spreadsheet_protocol_nucleic_acid_extraction_method => "TRIzol",
        upload_transcriptomics_spreadsheet_data_level => 'tissue_samples',
        upload_transcriptomics_spreadsheet_file_input => [$file_data, 'test_data.csv', Content_Type => 'text/csv'],
        upload_transcriptomics_transcript_metadata_spreadsheet_file_input => [$file_meta, 'test_meta.csv', Content_Type => 'text/csv'],
    ]
);

my $verify_response = decode_json( $mech->content );
diag explain $verify_response;

ok(!$verify_response->{error}, "No errors in verify");
ok(grep(/File data verified/, @{$verify_response->{success}}), "Verify succeeded");

# POST to STORE endpoint
$mech->post_ok(
    '/ajax/highdimensionalphenotypes/transcriptomics_upload_store',
    Content_Type => 'form-data',
    Content => [
        upload_transcriptomics_spreadsheet_protocol_name => 'ProtocolX',
        upload_transcriptomics_spreadsheet_protocol_desc => 'desc',
        upload_transcriptomics_spreadsheet_protocol_unit => 'TPM',
        upload_transcriptomics_spreadsheet_protocol_genome => 'v1',
        upload_transcriptomics_spreadsheet_protocol_annotation => 'anno1',

        upload_transcriptomics_spreadsheet_data_level => 'tissue_samples',

        upload_transcriptomics_spreadsheet_file_input => [$file_data],
        upload_transcriptomics_transcript_metadata_spreadsheet_file_input => [$file_meta],
    ]
);

my $store_response = decode_json( $mech->content );
diag explain $store_response;

ok(!$store_response->{error}, "No errors in store");
ok($store_response->{nd_protocol_id}, "Protocol ID returned");

done_testing;