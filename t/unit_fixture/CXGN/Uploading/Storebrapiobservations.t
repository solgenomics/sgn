use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use SGN::Model::Cvterm;
use Data::Dumper;
use JSON;
use HTTP::Request;
use LWP::UserAgent;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $mech = Test::WWW::Mechanize->new(timeout=>30000);
my $response;

my $plot_id1 = $schema->resultset('Stock::Stock')->find({uniquename=>'test_trial210'})->stock_id;
my $plot_id2 = $schema->resultset('Stock::Stock')->find({uniquename=>'test_trial214'})->stock_id;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
$response = decode_json $mech->content;
# print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};


my $data = {
    observations => [
        {
            observationDbId => '',
            observationUnitDbId => $plot_id1,
            observationVariableDbId => '70741',
            collector => 'collector1',
            observationTimeStamp => '2015-06-16T00:53:26Z',
            value => '11'
        },
        {
            observationDbId => '',
            observationUnitDbId => $plot_id2,
            observationVariableDbId => '70773',
            collector => 'collector1',
            observationTimeStamp => '2015-06-16T00:53:26Z',
            value => '110'
        },
    ]
};
my $j = encode_json $data;

my $req = HTTP::Request->new( "PUT" => "http://localhost:3010/brapi/v1/observations" );
$req->content_type( 'application/json' );
$req->content_length(
    do { use bytes; length( $j ) }
);
$req->content( $j );

my $ua = LWP::UserAgent->new();
my $res = $ua->request($req);
$response = decode_json $res->content;
# print STDERR Dumper $response;
is_deeply($response, {
          'result' => undef,
          'metadata' => {
                          'status' => [
                                        {
                                          'messageType' => 'ERROR',
                                          'message' => 'You must login and have permission to access this BrAPI call.'
                                        }
                                      ],
                          'datafiles' => [],
                          'pagination' => {
                                            'pageSize' => 1,
                                            'totalCount' => 0,
                                            'totalPages' => 0,
                                            'currentPage' => 0
                                          }
                        }
        });

my $trait_id1 = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'CO_334:0000092')->cvterm_id();
my $trait_id2 = SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema, 'CO_334:0000016')->cvterm_id();

my $data = {
    access_token => $sgn_session_id,
    observations => [
        {
            observationDbId => '',
            observationUnitDbId => $plot_id1,
            observationVariableDbId => $trait_id1,
            collector => 'collector1',
            observationTimeStamp => '2015-06-16T00:53:26Z',
            value => '11'
        },
        {
            observationDbId => '',
            observationUnitDbId => $plot_id2,
            observationVariableDbId => $trait_id2,
            collector => 'collector1',
            observationTimeStamp => '2015-06-16T00:53:26Z',
            value => '110'
        },
    ]
};
$j = encode_json $data;
$req = HTTP::Request->new( "PUT" => "http://localhost:3010/brapi/v1/observations" );
$req->content_type( 'application/json' );
$req->content_length(
    do { use bytes; length( $j ) }
);
$req->content( $j );

$ua = LWP::UserAgent->new();
$res = $ua->request($req);
$response = decode_json $res->content;
# print STDERR Dumper $	response;

#Remove observationdbid from result because it is variable
foreach (@{$response->{result}->{observations}}){
    delete $_->{observationDbId};
}

# is_deeply($response, {'result' => {'observations' => [{'observationLevel' => 'plot', 'observationTimeStamp' => '2015-06-16T00:53:26Z', 'germplasmName' => 'test_accession3', 'observationUnitName' => 'test_trial210', 'uploadedBy' => 'collector1', 'collector' => 'collector1', 'germplasmDbId' => 38842, 'observationUnitDbId' => 38866, 'value' => '11', 'observationVariableName' => 'dry matter content percentage', 'observationVariableDbId' => '70741', 'studyDbId' => 137, 'externalReferences' => undef, 'additionalInfo' => undef}, {'observationLevel' => 'plot', 'observationTimeStamp' => '2015-06-16T00:53:26Z', 'germplasmName' => 'test_accession4', 'observationUnitName' => 'test_trial214', 'uploadedBy' => 'collector1', 'collector' => 'collector1', 'germplasmDbId' => 38843, 'observationUnitDbId' => 38870, 'value' => '110', 'observationVariableDbId' => '70773', 'observationVariableName' => 'fresh shoot weight measurement in kg', 'studyDbId' => 137, 'externalReferences' => undef, 'additionalInfo' => undef}]}, 'metadata' => {'datafiles' => [], 'status' => [{'message' => 'BrAPI base call found with page=0, pageSize=10', 'messageType' => 'INFO'}, {'messageType' => 'INFO', 'message' => 'Loading CXGN::BrAPI::v1::Observations'}, {'message' => 'Request structure is valid', 'messageType' => 'info'}, {'messageType' => 'info', 'message' => 'Request data is valid'}, {'message' => 'File for incoming brapi obserations saved in archive.', 'messageType' => 'info'}, {'messageType' => 'INFO', 'message' => 'All values in your file have been successfully processed!<br><br>2 new values stored<br>0 previously stored values skipped<br>0 previously stored values overwritten<br>0 previously stored values removed<br><br>'}], 'pagination' => {'totalPages' => 1, 'totalCount' => 2, 'pageSize' => 10, 'currentPage' => 0}}});


my $expected = {
    'result' => {
		'observations' => [
            {
              	'externalReferences' => undef,
              	'value' => '11',
              	'germplasmDbId' => '38842',
              	'observationVariableDbId' => '70741',
              	'germplasmName' => 'test_accession3',
              	'additionalInfo' => undef,
              	'observationLevel' => 'plot',
              	'collector' => 'collector1',
              	'observationUnitDbId' => '38866',
              	'uploadedBy' => 'collector1',
              	'studyDbId' => '137',
              	'observationTimeStamp' => '2015-06-16T00:53:26Z',
              	'observationUnitName' => 'test_trial210',
              	'observationVariableName' => 'dry matter content percentage'
            },
            {
              	'externalReferences' => undef,
              	'observationVariableDbId' => '70773',
              	'germplasmDbId' => '38842',
              	'value' => undef,
              	'collector' => 'collector1',
              	'observationLevel' => 'plot',
              	'additionalInfo' => undef,
              	'germplasmName' => 'test_accession3',
              	'uploadedBy' => 'collector1',
              	'observationUnitDbId' => '38866',
              	'observationUnitName' => 'test_trial210',
              	'studyDbId' => '137',
              	'observationVariableName' => 'fresh shoot weight measurement in kg'
            },
            {
              	'observationUnitName' => 'test_trial214',
              	'studyDbId' => '137',
              	'observationVariableName' => 'dry matter content percentage',
              	'collector' => 'collector1',
              	'observationLevel' => 'plot',
              	'germplasmName' => 'test_accession4',
              	'additionalInfo' => undef,
              	'observationUnitDbId' => '38870',
              	'uploadedBy' => 'collector1',
              	'observationVariableDbId' => '70741',
              	'value' => undef,
              	'germplasmDbId' => '38843',
              	'externalReferences' => undef
            },
            {
              	'externalReferences' => undef,
              	'observationVariableDbId' => '70773',
              	'value' => '110',
              	'germplasmDbId' => '38843',
              	'observationLevel' => 'plot',
              	'collector' => 'collector1',
              	'additionalInfo' => undef,
              	'germplasmName' => 'test_accession4',
              	'uploadedBy' => 'collector1',
              	'observationUnitDbId' => '38870',
              	'observationUnitName' => 'test_trial214',
              	'observationTimeStamp' => '2015-06-16T00:53:26Z',
              	'studyDbId' => '137',
              	'observationVariableName' => 'fresh shoot weight measurement in kg'
            }
		]
	},'metadata' => {
    	'datafiles' => [],
    	'status' => [
    	    {
    	      	'messageType' => 'INFO',
    	      	'message' => 'BrAPI base call found with page=0, pageSize=10'
    	    },
    	    {
    	      	'messageType' => 'INFO',
    	      	'message' => 'Loading CXGN::BrAPI::v1::Observations'
    	    },
    	    {
    	      	'message' => 'Request structure is valid',
    	      	'messageType' => 'info'
    	    },
    	    {
    	      	'messageType' => 'info',
    	      	'message' => 'Request data is valid'
    	    },
    	    {
    	      	'message' => 'File for incoming brapi obserations saved in archive.',
    	      	'messageType' => 'info'
    	    },
    	    {
    	      	'message' => 'All values in your file have been successfully processed!<br><br>4 new values stored<br>0 previously stored values skipped<br>0 previously stored values overwritten<br>0 previously stored values removed<br><br>',
    	      	'messageType' => 'INFO'
    	    }
    	],'pagination' => {
    	    'totalCount' => 2,
    	    'currentPage' => 0,
    	    'totalPages' => 1,
    	    'pageSize' => 10
    	}
    }
};

is_deeply($response, $expected, 'GET Observations stored correctly');

$f->dbh()->rollback();
$f->clean_up_db();

done_testing();
