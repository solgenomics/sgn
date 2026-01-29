use strict;
use warnings;

use lib 't/lib';
use Test::More;
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
use LWP::UserAgent;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();
my $metadata_schema = $f->metadata_schema();
my $phenome_schema = $f->phenome_schema();

my $mech = SGN::Test::WWW::Mechanize->new();
my $trial_id = 137;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = decode_json $mech->content;
#print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};

my $trial = CXGN::Trial->new({ bcs_schema => $f->bcs_schema(), metadata_schema => $f->metadata_schema(), phenome_schema => $f->phenome_schema(), trial_id => $trial_id });
$trial->create_plant_entities('2');

$trial = CXGN::Trial->new({ bcs_schema => $f->bcs_schema(), metadata_schema => $f->metadata_schema(), phenome_schema => $f->phenome_schema(), trial_id => $trial_id });
my $temp_basedir = $f->config->{tempfiles_subdir};
my $site_basedir = $f->config->{basepath};
if (! -d "$site_basedir/$temp_basedir/delete_nd_experiment_ids/"){
    mkdir("$site_basedir/$temp_basedir/delete_nd_experiment_ids/");
}
my (undef, $tempfile) = tempfile("$site_basedir/$temp_basedir/delete_nd_experiment_ids/fileXXXX");
my $time = DateTime->now();
my $timestamp = $time->ymd()."_".$time->hms();
my $phenotype_store_config = {
    basepath => "$site_basedir/$temp_basedir",
    dbhost => $f->config->{dbhost},
    dbuser => $f->config->{dbuser},
    dbname => $f->config->{dbname},
    dbpass => $f->config->{dbpass},
    temp_file_nd_experiment_id => $tempfile,
    user_id => '41',
    metadata_hash => {
        archived_file => 'none',
        archived_file_type => 'new stock treatment auto inheritance',
        operator => 'janedoe',
        date => $timestamp
    }
};
is($trial->create_tissue_samples(['leaf', ], 1, 0, undef, undef, $phenotype_store_config), 1, 'test create tissue samples without tissue numbers');

my $matrix_file = $f->config->{basename} . "t/data/trial/transcript_data_matrix.csv";
my $details_file = $f->config->{basename} . "t/data/trial/transcriptomics_test_datafile.csv";

# POST to VERIFY endpoint
my $ua = LWP::UserAgent->new;
$response = $ua->post(
    'http://localhost:3010/ajax/highdimensionalphenotypes/transcriptomics_upload_verify',
    Content_Type => 'form-data',
    Content => [
        "upload_transcriptomics_spreadsheet_protocol_name"         => "Test Protocol",
        "sgn_session_id"=>$sgn_session_id,
        upload_transcriptomics_spreadsheet_protocol_desc         => "Test Desc",
        upload_transcriptomics_spreadsheet_protocol_unit         => "TPM",
        upload_transcriptomics_spreadsheet_protocol_genome       => "v1",
        upload_transcriptomics_spreadsheet_protocol_annotation   => "v1",

        upload_transcriptomics_spreadsheet_data_level => 'tissue_samples',
        upload_transcriptomics_spreadsheet_file_input => [$matrix_file, "transcriptomics_data_matrix"],
        upload_transcriptomics_transcript_metadata_spreadsheet_file_input => [$details_file, "transcriptomics_details"],
    ]
);
my $verify_message = $response->decoded_content;
my $verify_message_hash = decode_json $verify_message;
#print STDERR "message hash test:" . Dumper $verify_message_hash;

is($verify_message_hash->{success}->[0], 'File transcriptomics_data_matrix saved in archive.');
is($verify_message_hash->{success}->[1], 'File transcriptomics_details saved in archive.');
is($verify_message_hash->{success}->[2], 'File valid: transcriptomics_data_matrix.');
is($verify_message_hash->{success}->[3], 'File data successfully parsed.');
is($verify_message_hash->{success}->[4], 'File data verified. Plot names and trait names are valid.');

# POST to STORE endpoint
my $ua = LWP::UserAgent->new;
$response = $ua->post(
    'http://localhost:3010/ajax/highdimensionalphenotypes/transcriptomics_upload_store',
    Content_Type => 'form-data',
    Content => [
        "upload_transcriptomics_spreadsheet_protocol_name"         => "Test Protocol",
        "sgn_session_id"=>$sgn_session_id,
        upload_transcriptomics_spreadsheet_protocol_desc         => "Test Desc",
        upload_transcriptomics_spreadsheet_protocol_unit         => "TPM",
        upload_transcriptomics_spreadsheet_protocol_genome       => "v1",
        upload_transcriptomics_spreadsheet_protocol_annotation   => "v1",

        upload_transcriptomics_spreadsheet_data_level => 'tissue_samples',

        upload_transcriptomics_spreadsheet_file_input => [$matrix_file, "transcriptomics_data_matrix"],
        upload_transcriptomics_transcript_metadata_spreadsheet_file_input => [$details_file, "transcriptomics_details"],
    ]
);
#print STDERR "test response2" . Dumper $response;
my $store_message = $response->decoded_content;
my $store_message_hash = decode_json $store_message;
#print STDERR "store hash test:" .  Dumper $store_message_hash;

is($store_message_hash->{success}->[0], 'File transcriptomics_data_matrix saved in archive.');
is($store_message_hash->{success}->[1], 'File transcriptomics_details saved in archive.');
is($store_message_hash->{success}->[2], 'File valid: transcriptomics_data_matrix.');
is($store_message_hash->{success}->[3], 'File data successfully parsed.');
is($store_message_hash->{success}->[4], 'File data verified. Plot names and trait names are valid.');
is($store_message_hash->{success}->[5], 'All values in your file have been successfully processed!<br><br>1 new values stored<br>0 previously stored values skipped<br>0 previously stored values overwritten<br>0 previously stored values removed<br><br>');
is($store_message_hash->{success}->[6], 'Metadata saved for archived file.');

ok($store_message_hash->{nd_protocol_id}, "Protocol ID returned");

$f->clean_up_db();

done_testing();