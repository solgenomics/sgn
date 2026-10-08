
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::WWW::Mechanize;
use Test::More;
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
my $mech = Test::WWW::Mechanize->new;
my $ua = LWP::UserAgent->new;

my $trial_id = 137;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = decode_json $mech->content;
#print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};

my $trial = CXGN::Trial->new({ bcs_schema => $f->bcs_schema(), trial_id => $trial_id, phenome_schema => $f->phenome_schema, metadata_schema => $f->metadata_schema });
$trial->create_plant_entities('2');

$trial = CXGN::Trial->new({ bcs_schema => $f->bcs_schema(), trial_id => $trial_id, phenome_schema => $f->phenome_schema, metadata_schema => $f->metadata_schema });
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
is($trial->create_tissue_samples(['leaf', 'root' ], 1, 1, undef, undef, $phenotype_store_config), 1, 'test create tissue samples without tissue numbers');

# NIRS Endpoints
my $matrix_file = $f->config->{basename} . "t/data/trial/nirs_data_matrix.csv";

#verify test NIRS data
$response = $ua->post(
    'http://localhost:3010/ajax/highdimensionalphenotypes/nirs_upload_verify',
    Content_Type => 'form-data',
    Content => [
        "upload_nirs_spreadsheet_protocol_name"         => "Test Protocol",
        "sgn_session_id"=>$sgn_session_id,
        upload_nirs_spreadsheet_protocol_desc         => "Test Desc",
        upload_nirs_spreadsheet_protocol_device_type => "SCIO",
        upload_nirs_spreadsheet_data_level => "tissue_samples",
        upload_nirs_spreadsheet_file_input => [$matrix_file, "nirs_data_matrix"],
    ]
);

my $verify_message = $response->decoded_content;
my $verify_message_hash = decode_json $verify_message;

is($verify_message_hash->{success}->[0], 'File nirs_data_matrix saved in archive.');
is($verify_message_hash->{success}->[1], 'File valid: nirs_data_matrix.');
is($verify_message_hash->{success}->[2], 'File data successfully parsed.');
is($verify_message_hash->{success}->[3], 'Aggregated file data successfully parsed.');
is($verify_message_hash->{success}->[4], 'Aggregated file data verified. Plot names and trait names are valid.');

#Store test NIRS data
$response = $ua->post(
    'http://localhost:3010/ajax/highdimensionalphenotypes/nirs_upload_store',
    Content_Type => 'form-data',
    Content => [
        "upload_nirs_spreadsheet_protocol_name"         => "Test Protocol",
        "sgn_session_id"=>$sgn_session_id,
        upload_nirs_spreadsheet_protocol_desc         => "Test Desc",
        upload_nirs_spreadsheet_protocol_device_type => "SCIO",
        upload_nirs_spreadsheet_file_input => [$matrix_file, "nirs_data_matrix"],
    ]
);
#print STDERR "test response2" . Dumper $response;
my $store_message = $response->decoded_content;
my $store_message_hash = decode_json $store_message;

is($store_message_hash->{success}->[0], 'File nirs_data_matrix saved in archive.');
is($store_message_hash->{success}->[1], 'File valid: nirs_data_matrix.');
is($store_message_hash->{success}->[2], 'File data successfully parsed.');
is($store_message_hash->{success}->[4], 'Aggregated file data successfully parsed.');
is($store_message_hash->{success}->[5], 'Aggregated file data verified. Plot names and trait names are valid.');

$mech->get_ok('http://localhost:3010/brapi/v2/nirs/protocols');
$response = decode_json $mech->content;
my $protocol_id = $response->{result}{data}[1]{protocolDbId};
is_deeply($response, { metadata => { pagination => { currentPage => 0, pageSize => 10, totalPages => 1, totalCount => 1 }, status => [ { messageType => 'INFO', message => 'BrAPI base call found with page=0, pageSize=10' }, { messageType => 'INFO', message => 'Loading CXGN::BrAPI::v2::Nirs' }, { message => 'Nirs protocol result constructed', messageType => 'INFO' } ], datafiles => [] }, result => { data => [ { protocolTitle => 'NIRS Protocol', protocolDbId => 2, additionalInfo => undef, documentationURL => undef, deviceFrequencyNumber => undef, protocolDescription => 'Default NIRS protocol', deviceType => 'SCIO', externalReferences => undef }, { protocolTitle => 'Test Protocol', protocolDbId => $protocol_id, deviceFrequencyNumber => undef, documentationURL => undef, additionalInfo => undef, protocolDescription => 'Test Desc', deviceType => 'SCIO', externalReferences => undef } ] } });

my $rs = $f->bcs_schema()->resultset('Stock::Stock')->search( undef, { columns => [ { stock_id => { max => "stock_id" }} ]} );
my $row = $rs->next();
my $stock_id = $row->stock_id();

my $stock = $schema->resultset('Stock::Stock')->find({
    uniquename => 'test_trial25_plant_1_leaf1',
});

my $tissue_id = $stock ? $stock->stock_id : undef;

$mech->get_ok('http://localhost:3010/brapi/v2/nirs/protocols?protocolDbId=2');
$response = decode_json $mech->content;

is_deeply($response, { metadata => { status => [ { message => 'BrAPI base call found with page=0, pageSize=10', messageType => 'INFO' }, { messageType => 'INFO', message => 'Loading CXGN::BrAPI::v2::Nirs' }, { messageType => 'INFO', message => 'Nirs protocol result constructed' } ], pagination => { pageSize => 10, totalCount => 1, totalPages => 1, currentPage => 0 }, datafiles => [] }, result => { data => [ { protocolTitle => 'NIRS Protocol', protocolDbId => '2', additionalInfo => undef, documentationURL => undef, protocolDescription => 'Default NIRS protocol', deviceType => 'SCIO', externalReferences => undef, deviceFrequencyNumber => undef } ] } });

$mech->get_ok('http://localhost:3010/brapi/v2/nirs/instances');
$response = decode_json $mech->content;
#print STDERR "instances response: " . Dumper $response;
my $timestamp = $response->{result}{data}[0]{uploadTimestamp};
my $col_headers = $response->{result}{data}[0]{columnHeaders};
$protocol_id = $response->{result}{data}[0]{protocolDbId};
my $instance_id = $response->{result}{data}[0]{instanceDbId};

is_deeply($response, { metadata => { datafiles => [], pagination => { currentPage => 0, pageSize => 10, totalCount => 1, totalPages => 1 }, status => [ { messageType => 'INFO', message => 'BrAPI base call found with page=0, pageSize=10' }, { message => 'Loading CXGN::BrAPI::v2::Nirs', messageType => 'INFO' }, { messageType => 'INFO', message => 'Nirs instance result constructed' } ] }, result => { data => [ { protocolDbId => $protocol_id, deviceSerialNumber => undef, columnHeaders => $col_headers, uploadTimestamp => $timestamp, instanceDbId => $instance_id } ] } });

$mech->get_ok('http://localhost:3010/brapi/v2/nirs/instances?protocolDbId=' . $protocol_id . '&instanceDbId=' . $instance_id);
$response = decode_json $mech->content;
$timestamp = $response->{result}{data}[0]{uploadTimestamp};
$col_headers = $response->{result}{data}[0]{columnHeaders};
$protocol_id = $response->{result}{data}[0]{protocolDbId};
$instance_id = $response->{result}{data}[0]{instanceDbId};

is_deeply($response, { metadata => { datafiles => [], pagination => { currentPage => 0, pageSize => 10, totalCount => 1, totalPages => 1 }, status => [ { messageType => 'INFO', message => 'BrAPI base call found with page=0, pageSize=10' }, { message => 'Loading CXGN::BrAPI::v2::Nirs', messageType => 'INFO' }, { messageType => 'INFO', message => 'Nirs instance result constructed' } ] }, result => { data => [ { protocolDbId => $protocol_id, deviceSerialNumber => undef, columnHeaders => $col_headers, uploadTimestamp => $timestamp, instanceDbId => $instance_id } ] } });

# Transcriptomics Endpoints
my $transcriptomics_matrix_file = $f->config->{basename} . "t/data/trial/transcriptomics_data_matrix.csv";
my $transcriptomics_metadata_file = $f->config->{basename} . "t/data/trial/transcriptomics_metadata.csv";

#verify test transcriptomics data
$response = $ua->post(
    'http://localhost:3010/ajax/highdimensionalphenotypes/transcriptomics_upload_verify',
    Content_Type => 'form-data',
    Content => [
        "upload_transcriptomics_spreadsheet_protocol_name" => "Test Protocol",
        "upload_transcriptomics_spreadsheet_protocol_desc" => "Test Desc",
        "upload_transcriptomics_spreadsheet_protocol_unit" => "RPKM",
        "upload_transcriptomics_spreadsheet_protocol_genome" => "v1.0",
        "upload_transcriptomics_spreadsheet_protocol_annotation" => "v1.0",
        "upload_transcriptomics_spreadsheet_data_level" => "tissue_samples",
        "sgn_session_id" => $sgn_session_id,
        "upload_transcriptomics_spreadsheet_file_input" =>
            [$transcriptomics_matrix_file, "transcriptomics_data_matrix"],
        "upload_transcriptomics_transcript_metadata_spreadsheet_file_input" =>
            [$transcriptomics_metadata_file, "transcript_metadata_file"],
    ]
);

my $verify_message = $response->decoded_content;
my $verify_message_hash = decode_json $verify_message;

is($verify_message_hash->{success}->[0], 'File transcriptomics_data_matrix saved in archive.');
is($verify_message_hash->{success}->[1], 'File transcript_metadata_file saved in archive.');
is($verify_message_hash->{success}->[2], 'File valid: transcriptomics_data_matrix.');
is($verify_message_hash->{success}->[3], 'File data successfully parsed.');
is($verify_message_hash->{success}->[4], 'File data verified. Plot names and trait names are valid.');

#Store test transcriptomics data
$response = $ua->post(
    'http://localhost:3010/ajax/highdimensionalphenotypes/transcriptomics_upload_store',
    Content_Type => 'form-data',
    Content => [
        "upload_transcriptomics_spreadsheet_protocol_name" => "Test Protocol1",
        "upload_transcriptomics_spreadsheet_protocol_desc" => "Test Desc",
        "upload_transcriptomics_spreadsheet_protocol_unit" => "RPKM",
        "upload_transcriptomics_spreadsheet_protocol_genome" => "v1.0",
        "upload_transcriptomics_spreadsheet_protocol_annotation" => "v1.0",
        "upload_transcriptomics_spreadsheet_data_level" => "tissue_samples",
        "sgn_session_id" => $sgn_session_id,
        "upload_transcriptomics_spreadsheet_file_input" =>
            [$transcriptomics_matrix_file, "transcriptomics_data_matrix"],
        "upload_transcriptomics_transcript_metadata_spreadsheet_file_input" =>
            [$transcriptomics_metadata_file, "transcript_metadata_file"],
    ]
);

my $store_message = $response->decoded_content;
my $store_message_hash = decode_json $store_message;
print STDERR "store message hash: " . Dumper($store_message_hash);

is($store_message_hash->{success}->[0], 'File transcriptomics_data_matrix saved in archive.');
is($store_message_hash->{success}->[1], 'File transcript_metadata_file saved in archive.');
is($store_message_hash->{success}->[2], 'File valid: transcriptomics_data_matrix.');
is($store_message_hash->{success}->[4], 'File data verified. Plot names and trait names are valid.');

$mech->get_ok('http://localhost:3010/brapi/v2/transcriptomics/protocols');
$response = decode_json $mech->content;

is($response->{metadata}->{status}->[2]->{message}, 'Transcriptomics protocol result constructed');
ok(scalar @{$response->{result}->{data}} >= 1, 'At least one transcriptomics protocol returned');

my $transcriptomics_protocol_id = int($response->{result}->{data}->[0]->{protocolDbId});

# Get transcriptomics instances
$mech->get_ok('http://localhost:3010/brapi/v2/transcriptomics/instances');
$response = decode_json $mech->content;

is($response->{metadata}->{status}->[2]->{message}, 'transcriptomics instance result constructed');
ok(scalar @{$response->{result}->{data}} >= 1, 'At least one transcriptomics instance returned');

my $transcriptomics_instance_id = $response->{result}->{data}->[0]->{instanceDbId};
my $col_headers = $response->{result}->{data}->[0]->{columnHeaders};

ok(defined $transcriptomics_instance_id, 'Transcriptomics instanceDbId defined');
ok(ref($col_headers) eq 'ARRAY', 'Column headers returned as array');

# Get specific instance by protocol + instance
$mech->get_ok( 'http://localhost:3010/brapi/v2/transcriptomics/instances?protocolDbId=' . $transcriptomics_protocol_id . '&instanceDbId=' . $transcriptomics_instance_id );

$response = decode_json $mech->content;

is($response->{result}->{data}->[0]->{protocolDbId}, $transcriptomics_protocol_id, 'Protocol matches');
is($response->{result}->{data}->[0]->{instanceDbId}, $transcriptomics_instance_id, 'Instance matches');

# Transcriptomics search endpoint
$mech->get_ok('http://localhost:3010/brapi/v2/transcriptomics');
$response = decode_json $mech->content;

is($response->{metadata}->{status}->[2]->{message}, 'Transcriptomics result constructed');
ok(ref($response->{result}->{data}) eq 'ARRAY', 'Transcriptomics search returns array');

# Transcriptomics matrix by instance
$mech->get_ok( 'http://localhost:3010/brapi/v2/transcriptomics/matrix?instanceDbId=' . $transcriptomics_instance_id );

$response = decode_json $mech->content;

is($response->{metadata}->{status}->[2]->{message}, 'Transcriptomics matrix result constructed');

ok(defined $response->{result}->{protocolDbId}, 'Matrix protocolDbId defined');
ok(defined $response->{result}->{instanceDbId}, 'Matrix instanceDbId defined');
ok(ref($response->{result}->{columnHeaders}) eq 'ARRAY', 'Matrix column headers returned');
ok(ref($response->{result}->{data}) eq 'ARRAY', 'Matrix data returned');

# Transcriptomics matrix by protocol
$mech->get_ok( 'http://localhost:3010/brapi/v2/transcriptomics/matrix?protocolDbId=' . $transcriptomics_protocol_id );

$response = decode_json $mech->content;

is($response->{metadata}->{status}->[2]->{message}, 'Transcriptomics matrix result constructed');
ok(ref($response->{result}->{data}) eq 'ARRAY', 'Matrix by protocol returns data');

$f->clean_up_db();

done_testing();