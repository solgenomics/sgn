
use strict;
use warnings;


use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use LWP::UserAgent;
use DateTime;
use Spreadsheet::WriteExcel;
use Spreadsheet::Read;
use CXGN::Dataset;
use CXGN::Phenotypes::ParseUpload;
use CXGN::Phenotypes::StorePhenotypes;

#Needed to update IO::Socket::SSL
use Data::Dumper;
use JSON;
local $Data::Dumper::Indent = 1;

my $f = SGN::Test::Fixture->new(); # calculate db stats

my $mech = Test::WWW::Mechanize->new;
my $ua   = LWP::UserAgent->new;
my $response; my $searchId; my $resp; my $data;

$mech->post_ok('http://localhost:3010/brapi/v2/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
$response = decode_json $mech->content;
#print STDERR "\n\n" . Dumper$response;
#1
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
#2
is($response->{'userDisplayName'}, 'Jane Doe');
#3
is($response->{'expires_in'}, '7200');

$mech->delete_ok('http://localhost:3010/brapi/v2/token');
$response = decode_json $mech->content;
#print STDERR "\n\n" . Dumper$response;
#4
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'User Logged Out');

$mech->post_ok('http://localhost:3010/brapi/v2/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
$response = decode_json $mech->content;
#print STDERR "\n\n" . Dumper$response;
#5
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
#6
is($response->{'userDisplayName'}, 'Jane Doe');
#7
is($response->{'expires_in'}, '7200');
my $access_token = $response->{access_token};

$ua->default_header("Content-Type" => "application/json");
$ua->default_header('Authorization'=> 'Bearer ' . $access_token);
$mech->default_header("Content-Type" => "application/json");
$mech->default_header('Authorization'=> 'Bearer ' . $access_token);


# Phenotyping

$mech->get_ok('http://localhost:3010/brapi/v2/observationlevels');
$response = decode_json $mech->content;
#print STDERR "\n\n" . Dumper$response;
#9
is_deeply($response, {'result' => {'data' => [{'levelName' => 'rep','levelOrder' => 0},{'levelName' => 'block','levelOrder' => 1},{'levelName' => 'plot','levelOrder' => 2},{'levelName' => 'subplot','levelOrder' => 3},{'levelName' => 'plant','levelOrder' => 4},{'levelName' => 'tissue_sample','levelOrder' => 5}]},'metadata' => {'pagination' => {'totalPages' => 1,'pageSize' => 6,'totalCount' => 6,'currentPage' => 0},'datafiles' => [],'status' => [{'message' => 'BrAPI base call found with page=0, pageSize=10','messageType' => 'INFO'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::ObservationVariables'},{'messageType' => 'INFO','message' => 'Observation Levels result constructed'}]}}, "observation levels test");

####### ObservationUnits
$mech->get_ok('http://localhost:3010/brapi/v2/observationunits');
$response = decode_json $mech->content;
#print STDERR "\n\n" . Dumper$response;
#10
is_deeply($response,{'metadata'=>{'pagination'=>{'pageSize'=>10,'totalCount'=>1954,'totalPages'=>196,'currentPage'=>0},'status'=>[{'messageType'=>'INFO','message'=>'BrAPI base call found with page=0, pageSize=10'},{'message'=>'Loading CXGN::BrAPI::v2::ObservationUnits','messageType'=>'INFO'},{'message'=>'Observation Units search result constructed','messageType'=>'INFO'}],'datafiles'=>[]},'result'=>{'data'=>[{'studyName'=>'CASS_6Genotypes_Sampling_2015','studyDbId'=>'165','programName'=>'test','locationDbId'=>'23','treatments'=>[{'factor'=>'No ManagementFactor','modality'=>undef}],'germplasmName'=>'IITA-TMS-IBA980581','plotImageDbIds'=>[],'seedLotName'=>undef,'germplasmDbId'=>'41283','crossDbId'=>undef,'crossName'=>undef,'observationUnitPosition'=>{'entryType'=>'test','positionCoordinateYType'=>'GRID_ROW','positionCoordinateY'=>undef,'observationLevelRelationships'=>[{'levelCode'=>'1','levelName'=>'rep','levelOrder'=>0},{'levelOrder'=>1,'levelCode'=>'1','levelName'=>'block'},{'levelName'=>'plot','levelCode'=>'103','levelOrder'=>2}],'positionCoordinateX'=>undef,'observationLevel'=>{'levelOrder'=>2,'levelCode'=>'103','levelName'=>'plot'},'geoCoordinates'=>undef,'positionCoordinateXType'=>'GRID_COL'},'locationName'=>'test_location','observations'=>[],'programDbId'=>'134','observationUnitDbId'=>'41284','observationUnitPUI'=>'http://localhost:3010/stock/41284/view','additionalInfo'=>undef,'seedLotDbId'=>undef,'externalReferences'=>[],'observationUnitName'=>'CASS_6Genotypes_103','trialName'=>'CASS_6Genotypes_Sampling_2015','trialDbId'=>'165'},{'locationDbId'=>'23','treatments'=>[{'factor'=>'No ManagementFactor','modality'=>undef}],'programName'=>'test','studyDbId'=>'165','studyName'=>'CASS_6Genotypes_Sampling_2015','plotImageDbIds'=>[],'seedLotName'=>undef,'germplasmName'=>'IITA-TMS-IBA980002','observations'=>[],'programDbId'=>'134','locationName'=>'test_location','observationUnitPosition'=>{'positionCoordinateX'=>undef,'observationLevelRelationships'=>[{'levelOrder'=>0,'levelName'=>'rep','levelCode'=>'1'},{'levelCode'=>'1','levelName'=>'block','levelOrder'=>1},{'levelOrder'=>2,'levelName'=>'plot','levelCode'=>'104'}],'positionCoordinateXType'=>'GRID_COL','geoCoordinates'=>undef,'observationLevel'=>{'levelCode'=>'104','levelName'=>'plot','levelOrder'=>2},'positionCoordinateYType'=>'GRID_ROW','entryType'=>'test','positionCoordinateY'=>undef},'germplasmDbId'=>'41282','crossDbId'=>undef,'crossName'=>undef,'trialDbId'=>'165','trialName'=>'CASS_6Genotypes_Sampling_2015','seedLotDbId'=>undef,'externalReferences'=>[],'observationUnitName'=>'CASS_6Genotypes_104','additionalInfo'=>undef,'observationUnitPUI'=>'http://localhost:3010/stock/41295/view','observationUnitDbId'=>'41295'},{'seedLotName'=>undef,'plotImageDbIds'=>[],'germplasmName'=>'IITA-TMS-IBA30572','treatments'=>[{'factor'=>'No ManagementFactor','modality'=>undef}],'locationDbId'=>'23','programName'=>'test','studyDbId'=>'165','studyName'=>'CASS_6Genotypes_Sampling_2015','trialDbId'=>'165','trialName'=>'CASS_6Genotypes_Sampling_2015','observationUnitName'=>'CASS_6Genotypes_105','externalReferences'=>[],'seedLotDbId'=>undef,'additionalInfo'=>undef,'observationUnitPUI'=>'http://localhost:3010/stock/41296/view','observationUnitDbId'=>'41296','programDbId'=>'134','observations'=>[],'locationName'=>'test_location','observationUnitPosition'=>{'geoCoordinates'=>undef,'positionCoordinateXType'=>'GRID_COL','observationLevel'=>{'levelCode'=>'105','levelName'=>'plot','levelOrder'=>2},'positionCoordinateX'=>undef,'observationLevelRelationships'=>[{'levelName'=>'rep','levelCode'=>'1','levelOrder'=>0},{'levelOrder'=>1,'levelName'=>'block','levelCode'=>'1'},{'levelCode'=>'105','levelName'=>'plot','levelOrder'=>2}],'positionCoordinateY'=>undef,'positionCoordinateYType'=>'GRID_ROW','entryType'=>'test'},'germplasmDbId'=>'41279','crossDbId'=>undef,'crossName'=>undef},{'seedLotName'=>undef,'plotImageDbIds'=>[],'germplasmName'=>'IITA-TMS-IBA011412','studyDbId'=>'165','studyName'=>'CASS_6Genotypes_Sampling_2015','treatments'=>[{'modality'=>undef,'factor'=>'No ManagementFactor'}],'locationDbId'=>'23','programName'=>'test','additionalInfo'=>undef,'observationUnitPUI'=>'http://localhost:3010/stock/41297/view','observationUnitDbId'=>'41297','trialDbId'=>'165','trialName'=>'CASS_6Genotypes_Sampling_2015','observationUnitName'=>'CASS_6Genotypes_106','externalReferences'=>[],'seedLotDbId'=>undef,'observationUnitPosition'=>{'positionCoordinateY'=>undef,'entryType'=>'test','positionCoordinateYType'=>'GRID_ROW','observationLevel'=>{'levelOrder'=>2,'levelName'=>'plot','levelCode'=>'106'},'geoCoordinates'=>undef,'positionCoordinateXType'=>'GRID_COL','positionCoordinateX'=>undef,'observationLevelRelationships'=>[{'levelOrder'=>0,'levelName'=>'rep','levelCode'=>'1'},{'levelOrder'=>1,'levelName'=>'block','levelCode'=>'1'},{'levelName'=>'plot','levelCode'=>'106','levelOrder'=>2}]},'germplasmDbId'=>'41281','crossDbId'=>undef,'crossName'=>undef,'programDbId'=>'134','observations'=>[],'locationName'=>'test_location'},{'plotImageDbIds'=>[],'seedLotName'=>undef,'germplasmName'=>'TMEB693','studyName'=>'CASS_6Genotypes_Sampling_2015','studyDbId'=>'165','locationDbId'=>'23','treatments'=>[{'factor'=>'No ManagementFactor','modality'=>undef}],'programName'=>'test','additionalInfo'=>undef,'observationUnitDbId'=>'41298','observationUnitPUI'=>'http://localhost:3010/stock/41298/view','trialName'=>'CASS_6Genotypes_Sampling_2015','trialDbId'=>'165','seedLotDbId'=>undef,'observationUnitName'=>'CASS_6Genotypes_107','externalReferences'=>[],'observationUnitPosition'=>{'positionCoordinateXType'=>'GRID_COL','geoCoordinates'=>undef,'observationLevel'=>{'levelCode'=>'107','levelName'=>'plot','levelOrder'=>2},'positionCoordinateX'=>undef,'observationLevelRelationships'=>[{'levelName'=>'rep','levelCode'=>'1','levelOrder'=>0},{'levelOrder'=>1,'levelCode'=>'1','levelName'=>'block'},{'levelCode'=>'107','levelName'=>'plot','levelOrder'=>2}],'positionCoordinateY'=>undef,'positionCoordinateYType'=>'GRID_ROW','entryType'=>'test'},'germplasmDbId'=>'41280','crossDbId'=>undef,'crossName'=>undef,'observations'=>[],'programDbId'=>'134','locationName'=>'test_location'},{'observationUnitPosition'=>{'positionCoordinateX'=>undef,'observationLevelRelationships'=>[{'levelOrder'=>0,'levelCode'=>'1','levelName'=>'rep'},{'levelCode'=>'2','levelName'=>'block','levelOrder'=>1},{'levelName'=>'plot','levelCode'=>'201','levelOrder'=>2}],'observationLevel'=>{'levelOrder'=>2,'levelName'=>'plot','levelCode'=>'201'},'geoCoordinates'=>undef,'positionCoordinateXType'=>'GRID_COL','entryType'=>'test','positionCoordinateYType'=>'GRID_ROW','positionCoordinateY'=>undef},'germplasmDbId'=>'40326','crossDbId'=>undef,'crossName'=>undef,'observations'=>[],'programDbId'=>'134','locationName'=>'test_location','additionalInfo'=>undef,'observationUnitDbId'=>'41299','observationUnitPUI'=>'http://localhost:3010/stock/41299/view','trialDbId'=>'165','trialName'=>'CASS_6Genotypes_Sampling_2015','externalReferences'=>[],'observationUnitName'=>'CASS_6Genotypes_201','seedLotDbId'=>undef,'studyDbId'=>'165','studyName'=>'CASS_6Genotypes_Sampling_2015','treatments'=>[{'factor'=>'No ManagementFactor','modality'=>undef}],'locationDbId'=>'23','programName'=>'test','seedLotName'=>undef,'plotImageDbIds'=>[],'germplasmName'=>'BLANK'},{'programName'=>'test','treatments'=>[{'modality'=>undef,'factor'=>'No ManagementFactor'}],'locationDbId'=>'23','studyDbId'=>'165','studyName'=>'CASS_6Genotypes_Sampling_2015','germplasmName'=>'TMEB693','seedLotName'=>undef,'plotImageDbIds'=>[],'locationName'=>'test_location','observations'=>[],'programDbId'=>'134','germplasmDbId'=>'41280','crossDbId'=>undef,'crossName'=>undef,'observationUnitPosition'=>{'positionCoordinateY'=>undef,'entryType'=>'test','positionCoordinateYType'=>'GRID_ROW','observationLevel'=>{'levelOrder'=>2,'levelName'=>'plot','levelCode'=>'202'},'geoCoordinates'=>undef,'positionCoordinateXType'=>'GRID_COL','positionCoordinateX'=>undef,'observationLevelRelationships'=>[{'levelOrder'=>0,'levelCode'=>'1','levelName'=>'rep'},{'levelOrder'=>1,'levelCode'=>'2','levelName'=>'block'},{'levelOrder'=>2,'levelCode'=>'202','levelName'=>'plot'}]},'externalReferences'=>[],'observationUnitName'=>'CASS_6Genotypes_202','seedLotDbId'=>undef,'trialName'=>'CASS_6Genotypes_Sampling_2015','trialDbId'=>'165','observationUnitPUI'=>'http://localhost:3010/stock/41300/view','observationUnitDbId'=>'41300','additionalInfo'=>undef},{'germplasmName'=>'IITA-TMS-IBA980002','seedLotName'=>undef,'plotImageDbIds'=>[],'studyDbId'=>'165','studyName'=>'CASS_6Genotypes_Sampling_2015','programName'=>'test','treatments'=>[{'modality'=>undef,'factor'=>'No ManagementFactor'}],'locationDbId'=>'23','observationUnitDbId'=>'41301','observationUnitPUI'=>'http://localhost:3010/stock/41301/view','additionalInfo'=>undef,'externalReferences'=>[],'observationUnitName'=>'CASS_6Genotypes_203','seedLotDbId'=>undef,'trialName'=>'CASS_6Genotypes_Sampling_2015','trialDbId'=>'165','germplasmDbId'=>'41282','crossDbId'=>undef,'crossName'=>undef,'observationUnitPosition'=>{'positionCoordinateY'=>undef,'positionCoordinateYType'=>'GRID_ROW','entryType'=>'test','positionCoordinateXType'=>'GRID_COL','geoCoordinates'=>undef,'observationLevel'=>{'levelCode'=>'203','levelName'=>'plot','levelOrder'=>2},'positionCoordinateX'=>undef,'observationLevelRelationships'=>[{'levelOrder'=>0,'levelCode'=>'1','levelName'=>'rep'},{'levelCode'=>'2','levelName'=>'block','levelOrder'=>1},{'levelName'=>'plot','levelCode'=>'203','levelOrder'=>2}]},'locationName'=>'test_location','observations'=>[],'programDbId'=>'134'},{'observationUnitPUI'=>'http://localhost:3010/stock/41302/view','observationUnitDbId'=>'41302','additionalInfo'=>undef,'seedLotDbId'=>undef,'observationUnitName'=>'CASS_6Genotypes_204','externalReferences'=>[],'trialName'=>'CASS_6Genotypes_Sampling_2015','trialDbId'=>'165','germplasmDbId'=>'41283','crossDbId'=>undef,'crossName'=>undef,'observationUnitPosition'=>{'positionCoordinateXType'=>'GRID_COL','geoCoordinates'=>undef,'observationLevel'=>{'levelName'=>'plot','levelCode'=>'204','levelOrder'=>2},'positionCoordinateX'=>undef,'observationLevelRelationships'=>[{'levelOrder'=>0,'levelName'=>'rep','levelCode'=>'1'},{'levelOrder'=>1,'levelName'=>'block','levelCode'=>'2'},{'levelCode'=>'204','levelName'=>'plot','levelOrder'=>2}],'positionCoordinateY'=>undef,'positionCoordinateYType'=>'GRID_ROW','entryType'=>'test'},'locationName'=>'test_location','observations'=>[],'programDbId'=>'134','germplasmName'=>'IITA-TMS-IBA980581','plotImageDbIds'=>[],'seedLotName'=>undef,'studyName'=>'CASS_6Genotypes_Sampling_2015','studyDbId'=>'165','programName'=>'test','locationDbId'=>'23','treatments'=>[{'factor'=>'No ManagementFactor','modality'=>undef}]},{'seedLotName'=>undef,'plotImageDbIds'=>[],'germplasmName'=>'IITA-TMS-IBA011412','treatments'=>[{'factor'=>'No ManagementFactor','modality'=>undef}],'locationDbId'=>'23','programName'=>'test','studyDbId'=>'165','studyName'=>'CASS_6Genotypes_Sampling_2015','trialName'=>'CASS_6Genotypes_Sampling_2015','trialDbId'=>'165','externalReferences'=>[],'observationUnitName'=>'CASS_6Genotypes_205','seedLotDbId'=>undef,'additionalInfo'=>undef,'observationUnitPUI'=>'http://localhost:3010/stock/41285/view','observationUnitDbId'=>'41285','observations'=>[],'programDbId'=>'134','locationName'=>'test_location','observationUnitPosition'=>{'positionCoordinateY'=>undef,'entryType'=>'test','positionCoordinateYType'=>'GRID_ROW','observationLevel'=>{'levelOrder'=>2,'levelName'=>'plot','levelCode'=>'205'},'geoCoordinates'=>undef,'positionCoordinateXType'=>'GRID_COL','positionCoordinateX'=>undef,'observationLevelRelationships'=>[{'levelCode'=>'1','levelName'=>'rep','levelOrder'=>0},{'levelOrder'=>1,'levelCode'=>'2','levelName'=>'block'},{'levelOrder'=>2,'levelCode'=>'205','levelName'=>'plot'}]},'germplasmDbId'=>'41281','crossDbId'=>undef,'crossName'=>undef}]}}, "GET observationunits test");


#it doesn't test geoCoordinates
$data = '[{ "additionalInfo": {"control": 1,"field" : "Field2" },"germplasmDbId": "41281","germplasmName": "IITA-TMS-IBA011412","locationDbId": "23","locationName": "test_location","observationUnitName": "Testing Plot","observationUnitPUI": "10","programDbId": "134","programName": "test","seedLotDbId": "","studyDbId": "165","studyName": "CASS_6Genotypes_Sampling_2015","treatments": [],"trialDbId": "165","trialName": "","observationUnitPosition": {"entryType": "TEST","geoCoordinates": {},"observationLevel": {"levelName": "plot","levelOrder": 2,"levelCode": "10"},"observationLevelRelationships": [{  "levelCode": "Field_1",  "levelName": "field",  "levelOrder": 0},{  "levelCode": "Block_12",  "levelName": "block",  "levelOrder": 1},{  "levelCode": "Plot_123",  "levelName": "plot",  "levelOrder": 2}],"positionCoordinateX": "74","positionCoordinateXType": "GRID_COL","positionCoordinateY": "03","positionCoordinateYType": "GRID_ROW"} }]';
$mech->post('http://localhost:3010/brapi/v2/observationunits/', Content => $data);
$response = decode_json $mech->content;
#print STDERR "\n\n" . Dumper$response;

my $rs = $f->bcs_schema()->resultset('Stock::Stock')->search( undef, { columns => [ { stock_id => { max => "stock_id" }} ]} );
my $row = $rs->next();
my $stock_id = $row->stock_id();

#11
is_deeply($response, {'result' => {'data' => [{'observationUnitDbId' => $stock_id,'observationUnitPUI' => 'http://localhost:3010/stock/'.$stock_id.'/view','externalReferences' => [],'additionalInfo' => {'field' => 'Field2'},'observationUnitPosition' => {'geoCoordinates' => undef,'observationLevel' => {'levelCode' => '10','levelOrder' => 2,'levelName' => 'plot'},'positionCoordinateY' => 3,'entryType' => 'test','positionCoordinateXType' => 'GRID_COL','positionCoordinateYType' => 'GRID_ROW','observationLevelRelationships' => [{'levelName' => 'rep','levelOrder' => 0,'levelCode' => '1'}, {'levelCode' => 'Block_12','levelName' => 'block','levelOrder' => 1},{'levelCode' => '10','levelOrder' => 2,'levelName' => 'plot'}],'positionCoordinateX' => 74},'studyName' => 'CASS_6Genotypes_Sampling_2015','trialDbId' => '165','programDbId' => '134','plotImageDbIds' => [],'locationName' => 'test_location','studyDbId' => '165','locationDbId' => '23','observationUnitName' => 'Testing Plot','germplasmName' => 'IITA-TMS-IBA011412','seedLotDbId' => undef,'seedLotName' => undef,'programName' => 'test','treatments' => [{'factor' => 'No ManagementFactor','modality' => undef}],'trialName' => 'CASS_6Genotypes_Sampling_2015','germplasmDbId' => '41281','crossDbId'=>undef,'crossName'=>undef,'observations' => [] }]},'metadata' => {'pagination' => {'totalCount' => 1,'totalPages' => 1,'pageSize' => 1,'currentPage' => 0},'datafiles' => [],'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'message' => 'Loading CXGN::BrAPI::v2::ObservationUnits','messageType' => 'INFO'},{'message' => 'Observation Units search result constructed','messageType' => 'INFO'}]}} ,"POST observationunits test");


$mech->get_ok('http://localhost:3010/brapi/v2/observationunits/41284');
$response = decode_json $mech->content;
#print STDERR "\n\n" . Dumper$response;
#12
is_deeply($response, {'metadata' => {'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::ObservationUnits'},{'messageType' => 'INFO','message' => 'Observation Units search result constructed'}],'pagination' => {'pageSize' => 10,'currentPage' => 0,'totalPages' => 1,'totalCount' => 1},'datafiles' => []},'result' => {'observationUnitDbId' => '41284','observationUnitPUI' => 'http://localhost:3010/stock/41284/view', 'additionalInfo' => undef,'externalReferences' => [],'studyName' => 'CASS_6Genotypes_Sampling_2015','observationUnitPosition' => {'observationLevelRelationships' => [{'levelCode' => '1','levelName' => 'rep','levelOrder' => 0}, {'levelCode' => '1','levelName' => 'block','levelOrder' => 1},{'levelCode' => '103','levelName' => 'plot','levelOrder' => 2}],'positionCoordinateX' => undef,'positionCoordinateYType' => 'GRID_ROW','positionCoordinateXType' => 'GRID_COL','entryType' => 'test','observationLevel' => {'levelName' => 'plot','levelOrder' => 2,'levelCode' => '103'},'positionCoordinateY' => undef,'geoCoordinates' => undef},'trialDbId' => '165','programDbId' => '134','plotImageDbIds' => [],'studyDbId' => '165','locationName' => 'test_location','observationUnitName' => 'CASS_6Genotypes_103','seedLotDbId' => undef,'seedLotName' => undef,'germplasmName' => 'IITA-TMS-IBA980581','locationDbId' => '23','programName' => 'test','treatments' => [{'modality' => undef,'factor' => 'No ManagementFactor'}],'trialName' => 'CASS_6Genotypes_Sampling_2015','observations' => [{'studyDbId' => '165','observationTimeStamp' => undef,'observationUnitDbId' => '41284','collector' => undef,'observationVariableDbId' => '77559','observationDbId' => '740336','externalReferences' => undef,'additionalInfo' =>undef,'observationUnitName' => 'CASS_6Genotypes_103','germplasmName' => 'IITA-TMS-IBA980581','uploadedBy' => undef,'value' => '601.518','season' => {'seasonDbId' => undef,'season' => undef,'year' => '2017'},'germplasmDbId' => '41283','observationVariableName' => 'cass sink leaf|3-phosphoglyceric acid|ug/g|week 16|COMP:0000013'},{'germplasmName' => 'IITA-TMS-IBA980581','observationUnitName' => 'CASS_6Genotypes_103','uploadedBy' => undef,'observationVariableDbId' => '77557','externalReferences' => undef,'observationDbId' => '740337','additionalInfo' =>undef,'collector' => undef,'observationTimeStamp' => undef,'observationUnitDbId' => '41284','studyDbId' => '165','observationVariableName' => 'cass sink leaf|ADP alpha-D-glucoside|ug/g|week 16|COMP:0000011','germplasmDbId' => '41283','season' => {'year' => '2017','seasonDbId' => undef,'season' => undef},'value' => '39.84365'},{'observationVariableName' => 'cass sink leaf|ADP|ug/g|week 16|COMP:0000010','germplasmDbId' => '41283','season' => {'year' => '2017','season' => undef,'seasonDbId' => undef},'value' => '655.92','uploadedBy' => undef,'germplasmName' => 'IITA-TMS-IBA980581','observationUnitName' => 'CASS_6Genotypes_103','externalReferences' => undef,'additionalInfo' => undef,'observationDbId' => '740338','observationVariableDbId' => '77556','collector' => undef,'studyDbId' => '165','observationTimeStamp' => undef,'observationUnitDbId' => '41284'},{'value' => '1259.08','season' => {'season' => undef,'seasonDbId' => undef,'year' => '2017'},'germplasmDbId' => '41283','observationVariableName' => 'cass source leaf|3-phosphoglyceric acid|ug/g|week 16|COMP:0000002','observationUnitDbId' => '41284','studyDbId' => '165','observationTimeStamp' => undef,'collector' => undef,'externalReferences' => undef,'observationDbId' => '740339','additionalInfo' => undef,'observationVariableDbId' => '77548','uploadedBy' => undef,'germplasmName' => 'IITA-TMS-IBA980581','observationUnitName' => 'CASS_6Genotypes_103'},{'value' => '17.38275','season' => {'year' => '2017','seasonDbId' => undef,'season' => undef},'germplasmDbId' => '41283','observationVariableName' => 'cass source leaf|ADP alpha-D-glucoside|ug/g|week 16|COMP:0000007','studyDbId' => '165','observationTimeStamp' => undef,'observationUnitDbId' => '41284','collector' => undef,'observationDbId' => '740340','additionalInfo' => undef,'externalReferences' => undef,'observationVariableDbId' => '77553','uploadedBy' => undef,'germplasmName' => 'IITA-TMS-IBA980581','observationUnitName' => 'CASS_6Genotypes_103'},{'collector' => undef,'observationUnitDbId' => '41284','studyDbId' => '165','observationTimeStamp' => undef,'observationUnitName' => 'CASS_6Genotypes_103','germplasmName' => 'IITA-TMS-IBA980581','uploadedBy' => undef,'observationVariableDbId' => '77549','externalReferences' => undef,'additionalInfo' => undef,'observationDbId' => '740341','season' => {'seasonDbId' => undef,'season' => undef,'year' => '2017'},'value' => '192.1495','observationVariableName' => 'cass source leaf|ADP|ug/g|week 16|COMP:0000003','germplasmDbId' => '41283'},{'germplasmDbId' => '41283','observationVariableName' => 'cass storage root|3-phosphoglyceric acid|ug/g|week 16|COMP:0000006','value' => '67.9959','season' => {'year' => '2017','season' => undef,'seasonDbId' => undef},'observationVariableDbId' => '77552','observationDbId' => '740342','externalReferences' => undef,'additionalInfo' => undef,'germplasmName' => 'IITA-TMS-IBA980581','observationUnitName' => 'CASS_6Genotypes_103','uploadedBy' => undef,'observationTimeStamp' => undef,'observationUnitDbId' => '41284','studyDbId' => '165','collector' => undef},{'observationVariableName' => 'cass storage root|ADP alpha-D-glucoside|ug/g|week 16|COMP:0000004','germplasmDbId' => '41283','season' => {'season' => undef,'seasonDbId' => undef,'year' => '2017'},'value' => '20.3038','uploadedBy' => undef,'germplasmName' => 'IITA-TMS-IBA980581','observationUnitName' => 'CASS_6Genotypes_103','additionalInfo' => undef,'observationDbId' => '740343','externalReferences' => undef,'observationVariableDbId' => '77550','collector' => undef,'observationTimeStamp' => undef,'observationUnitDbId' => '41284','studyDbId' => '165'},{'observationTimeStamp' => undef,'studyDbId' => '165','observationUnitDbId' => '41284','collector' => undef,'additionalInfo' => undef,'externalReferences' => undef,'observationDbId' => '740344','observationVariableDbId' => '77551','uploadedBy' => undef,'observationUnitName' => 'CASS_6Genotypes_103','germplasmName' => 'IITA-TMS-IBA980581','value' => '102.0875','season' => {'season' => undef,'seasonDbId' => undef,'year' => '2017'},'germplasmDbId' => '41283','observationVariableName' => 'cass storage root|ADP|ug/g|week 16|COMP:0000005'},{'germplasmName' => 'IITA-TMS-IBA980581','observationUnitName' => 'CASS_6Genotypes_103','uploadedBy' => undef,'observationVariableDbId' => '77558','additionalInfo' => undef,'externalReferences' => undef,'observationDbId' => '740345','collector' => undef,'observationUnitDbId' => '41284','observationTimeStamp' => undef,'studyDbId' => '165','observationVariableName' => 'cass upper stem|3-phosphoglyceric acid|ug/g|week 16|COMP:0000012','germplasmDbId' => '41283','season' => {'seasonDbId' => undef,'season' => undef,'year' => '2017'},'value' => '108.56995'},{'studyDbId' => '165','observationTimeStamp' => undef,'observationUnitDbId' => '41284','collector' => undef,'observationDbId' => '740346','externalReferences' => undef,'additionalInfo' => undef,'observationVariableDbId' => '77554','uploadedBy' => undef,'germplasmName' => 'IITA-TMS-IBA980581','observationUnitName' => 'CASS_6Genotypes_103','value' => '28.83915','season' => {'season' => undef,'seasonDbId' => undef,'year' => '2017'},'germplasmDbId' => '41283','observationVariableName' => 'cass upper stem|ADP alpha-D-glucoside|ug/g|week 16|COMP:0000008'},{'germplasmDbId' => '41283','observationVariableName' => 'cass upper stem|ADP|ug/g|week 16|COMP:0000009','value' => '379.16','season' => {'year' => '2017','season' => undef,'seasonDbId' => undef},'observationVariableDbId' => '77555','externalReferences' => undef,'additionalInfo' => undef,'observationDbId' => '740347','germplasmName' => 'IITA-TMS-IBA980581','observationUnitName' => 'CASS_6Genotypes_103','uploadedBy' => undef,'observationTimeStamp' => undef,'studyDbId' => '165','observationUnitDbId' => '41284','collector' => undef}],'germplasmDbId' => '41283','crossDbId'=>undef,'crossName'=>undef}} ,"GET observationunits/41284 test");

$mech->get_ok('http://localhost:3010/brapi/v2/observationunits/41299?pageSize=1&page=0');
$response = decode_json $mech->content;
#print STDERR "\n\n" . Dumper$response;
#13
is_deeply($response, {'result' => {'trialName' => 'CASS_6Genotypes_Sampling_2015','germplasmDbId' => '40326','crossDbId'=>undef,'crossName'=>undef,'observations' => [],'treatments' => [{'factor' => 'No ManagementFactor','modality' => undef}],'locationDbId' => '23','seedLotDbId' => undef,'seedLotName' => undef,'observationUnitName' => 'CASS_6Genotypes_201','germplasmName' => 'BLANK','programName' => 'test','locationName' => 'test_location','studyDbId' => '165','trialDbId' => '165','programDbId' => '134','plotImageDbIds' => [],'observationUnitPosition' => {'geoCoordinates' => undef,'positionCoordinateY' => undef,'observationLevel' => {'levelCode' => '201','levelOrder' => 2,'levelName' => 'plot'},'entryType' => 'test','positionCoordinateXType' => 'GRID_COL','positionCoordinateYType' => 'GRID_ROW','positionCoordinateX' => undef,'observationLevelRelationships' => [{'levelCode' => '1','levelOrder' => 0,'levelName' => 'rep'},{'levelOrder' => 1,'levelName' => 'block','levelCode' => '2'},{'levelCode' => '201','levelOrder' => 2,'levelName' => 'plot'}]},'studyName' => 'CASS_6Genotypes_Sampling_2015','externalReferences' => [],'additionalInfo' => undef,'observationUnitDbId' => '41299','observationUnitPUI' => 'http://localhost:3010/stock/41299/view'},'metadata' => {'pagination' => {'totalPages' => 1,'totalCount' => 1,'pageSize' => 1,'currentPage' => 0},'datafiles' => [],'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=1'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::ObservationUnits'},{'message' => 'Observation Units search result constructed','messageType' => 'INFO'}]}}, "GET observationunits/41299 page 0 test");

$mech->get_ok('http://localhost:3010/brapi/v2/observationunits/table');
$response = decode_json $mech->content;
#print STDERR "\n\n observationunits/table response:" . Dumper $response;
#14

my $expected = {'metadata'=>{'datafiles'=>[],'pagination'=>{'totalPages'=>102,'totalCount'=>1016,'pageSize'=>10,'currentPage'=>0},'status'=>[{'messageType'=>'INFO','message'=>'BrAPI base call found with page=0, pageSize=10'},{'message'=>'Loading CXGN::BrAPI::v2::ObservationTables','messageType'=>'INFO'},{'messageType'=>'INFO','message'=>'Observation Units table result constructed'}]},'result'=>{'headerRow'=>['studyYear','programDbId','programName','programDescription','studyDbId','studyName','studyDescription','studyDesign','plotWidth','plotLength','fieldSize','fieldTrialIsPlannedToBeGenotyped','fieldTrialIsPlannedToCross','plantingDate','harvestDate','locationDbId','locationName','germplasmDbId','germplasmName','germplasmSynonyms','observationLevel','observationUnitDbId','observationUnitName','replicate','blockNumber','plotNumber','rowNumber','colNumber','entryType','plantNumber'],'observationVariables'=>[{'observationVariableDbId'=>'77559','observationVariableName'=>'cass sink leaf|3-phosphoglyceric acid|ug/g|week 16|COMP:0000013'},{'observationVariableName'=>'cass sink leaf|ADP alpha-D-glucoside|ug/g|week 16|COMP:0000011','observationVariableDbId'=>'77557'},{'observationVariableName'=>'cass sink leaf|ADP|ug/g|week 16|COMP:0000010','observationVariableDbId'=>'77556'},{'observationVariableName'=>'cass source leaf|3-phosphoglyceric acid|ug/g|week 16|COMP:0000002','observationVariableDbId'=>'77548'},{'observationVariableName'=>'cass source leaf|ADP alpha-D-glucoside|ug/g|week 16|COMP:0000007','observationVariableDbId'=>'77553'},{'observationVariableDbId'=>'77549','observationVariableName'=>'cass source leaf|ADP|ug/g|week 16|COMP:0000003'},{'observationVariableName'=>'cass storage root|3-phosphoglyceric acid|ug/g|week 16|COMP:0000006','observationVariableDbId'=>'77552'},{'observationVariableDbId'=>'77550','observationVariableName'=>'cass storage root|ADP alpha-D-glucoside|ug/g|week 16|COMP:0000004'},{'observationVariableName'=>'cass storage root|ADP|ug/g|week 16|COMP:0000005','observationVariableDbId'=>'77551'},{'observationVariableName'=>'cass upper stem|3-phosphoglyceric acid|ug/g|week 16|COMP:0000012','observationVariableDbId'=>'77558'},{'observationVariableName'=>'cass upper stem|ADP alpha-D-glucoside|ug/g|week 16|COMP:0000008','observationVariableDbId'=>'77554'},{'observationVariableName'=>'cass upper stem|ADP|ug/g|week 16|COMP:0000009','observationVariableDbId'=>'77555'},{'observationVariableDbId'=>'70741','observationVariableName'=>'dry matter content percentage|CO_334:0000092'},{'observationVariableDbId'=>'70666','observationVariableName'=>'fresh root weight|CO_334:0000012'},{'observationVariableName'=>'fresh shoot weight measurement in kg|CO_334:0000016','observationVariableDbId'=>'70773'},{'observationVariableName'=>'harvest index variable|CO_334:0000015','observationVariableDbId'=>'70668'}],'data'=>[['2014',134,'test','test',139,'Kasese solgs trial','This trial was loaded into the fixture to test solgs.','Alpha',undef,undef,undef,undef,undef,undef,undef,'23','test_location',39086,'UG120250','','plot',39691,'KASESE_TP2013_1000','1','53','36014',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef],['2014',134,'test','test',139,'Kasese solgs trial','This trial was loaded into the fixture to test solgs.','Alpha',undef,undef,undef,undef,undef,undef,undef,'23','test_location',38960,'UG120092','','plot',39493,'KASESE_TP2013_1001','1','53','36015',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef],['2014',134,'test','test',139,'Kasese solgs trial','This trial was loaded into the fixture to test solgs.','Alpha',undef,undef,undef,undef,undef,undef,undef,'23','test_location',38981,'UG120120','','plot',39819,'KASESE_TP2013_1002','1','53','36016',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,'30.1','3.93','3',undef,undef],['2014',134,'test','test',139,'Kasese solgs trial','This trial was loaded into the fixture to test solgs.','Alpha',undef,undef,undef,undef,undef,undef,undef,'23','test_location',39194,'UG130076','','plot',39311,'KASESE_TP2013_1003','1','53','36017',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef],['2014',134,'test','test',139,'Kasese solgs trial','This trial was loaded into the fixture to test solgs.','Alpha',undef,undef,undef,undef,undef,undef,undef,'23','test_location',39174,'UG130050','','plot',39632,'KASESE_TP2013_1004','1','54','36018',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,'24.2','7.26','12.5',undef,undef],['2014',134,'test','test',139,'Kasese solgs trial','This trial was loaded into the fixture to test solgs.','Alpha',undef,undef,undef,undef,undef,undef,undef,'23','test_location',38919,'UG120043','','plot',39846,'KASESE_TP2013_1005','1','54','36019',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef],['2014',134,'test','test',139,'Kasese solgs trial','This trial was loaded into the fixture to test solgs.','Alpha',undef,undef,undef,undef,undef,undef,undef,'23','test_location',38952,'UG120084','','plot',39919,'KASESE_TP2013_1006','1','54','36020',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,'27.4','5.4','4.5',undef,undef],['2014',134,'test','test',139,'Kasese solgs trial','This trial was loaded into the fixture to test solgs.','Alpha',undef,undef,undef,undef,undef,undef,undef,'23','test_location',39049,'UG120202','','plot',39836,'KASESE_TP2013_1007','1','54','36021',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,'16.3','0.47','6.5',undef,undef],['2014',134,'test','test',139,'Kasese solgs trial','This trial was loaded into the fixture to test solgs.','Alpha',undef,undef,undef,undef,undef,undef,undef,'23','test_location',39105,'UG120273','','plot',39350,'KASESE_TP2013_1008','1','54','36022',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef],['2014',134,'test','test',139,'Kasese solgs trial','This trial was loaded into the fixture to test solgs.','Alpha',undef,undef,undef,undef,undef,undef,undef,'23','test_location',38966,'UG120099','','plot',39322,'KASESE_TP2013_1009','1','54','36023',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef,undef]]}};

#print STDERR "\n\nobservation_unit/table expected: ".Dumper($expected);

is_deeply($response, $expected , "GET observationunits table test");

####### Observations

$mech->get_ok('http://localhost:3010/brapi/v2/observations?pageSize=2');
$response = decode_json $mech->content;

#print STDERR "\n\nOBSERVATIONS RESPONSE: " . Dumper $response;

#15

my $expected = { 'metadata' => { 'status' => [ { 'message' => 'BrAPI base call found with page=0, pageSize=2', 'messageType' => 'INFO' }, { 'message' => 'Loading CXGN::BrAPI::v2::Observations', 'messageType' => 'INFO' }, { 'message' => 'Observations result constructed', 'messageType' => 'INFO' } ], 'pagination' => { 'totalCount' => 2781, 'pageSize' => 2, 'totalPages' => 1391, 'currentPage' => 0 }, 'datafiles' => [] }, 'result' => { 'data' => [ { 'observationVariableDbId' => '70773', 'collector' => undef, 'studyDbId' => '139', 'germplasmDbId' => '38981', 'observationUnitDbId' => '39819', 'observationVariableName' => 'fresh shoot weight measurement in kg|CO_334:0000016', 'value' => '3', 'observationTimeStamp' => undef, 'additionalInfo' => undef, 'season' => { 'seasonDbId' => '2014', 'season' => '2014', 'year' => '2014' }, 'uploadedBy' => undef, 'externalReferences' => undef, 'germplasmName' => 'UG120120', 'observationUnitName' => 'KASESE_TP2013_1002', 'observationDbId' => '737974' }, { 'season' => { 'seasonDbId' => '2014', 'season' => '2014', 'year' => '2014' }, 'additionalInfo' => undef, 'observationTimeStamp' => undef, 'value' => '30.1', 'observationVariableName' => 'dry matter content percentage|CO_334:0000092', 'observationUnitDbId' => '39819', 'germplasmDbId' => '38981', 'studyDbId' => '139', 'collector' => undef, 'observationVariableDbId' => '70741', 'observationDbId' => '737975', 'observationUnitName' => 'KASESE_TP2013_1002', 'germplasmName' => 'UG120120', 'uploadedBy' => undef, 'externalReferences' => undef } ] }};

#print STDERR "\n\nOBSERVATIONS EXPECTED: " . Dumper $expected;

is_deeply($response, $expected, "GET observations pageSize 2 test");

$mech->get_ok('http://localhost:3010/brapi/v2/observations/740338');
$response = decode_json $mech->content;
print STDERR "\n\n" . Dumper$response;
#16
is_deeply($response,  {'metadata' => {'datafiles' => [],'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::Observations'},{'messageType' => 'INFO','message' => 'Observations result constructed'}],'pagination' => {'totalCount' => 1,'totalPages' => 1,'currentPage' => 0,'pageSize' => 10}},'result' => {'externalReferences' => undef,'value' => '655.92','germplasmDbId' => '41283','season' => {'seasonDbId' => '2017','season' => '2017','year' => '2017'},'studyDbId' => '165','observationVariableName' => 'cass sink leaf|ADP|ug/g|week 16|COMP:0000010','observationVariableDbId' => '77556','observationUnitDbId' => '41284','germplasmName' => 'IITA-TMS-IBA980581','observationTimeStamp' => undef,'uploadedBy' => undef,'collector' => undef,'observationUnitName' => 'CASS_6Genotypes_103','observationDbId' => '740338','additionalInfo' => undef}}, "GET observations test");

$mech->get_ok('http://localhost:3010/brapi/v2/observations/table?pageSize=2');
$response = decode_json $mech->content;
 print STDERR "\n reponse is here:" . Dumper $response;
#17

is_deeply($response,
	  {
  'result' => {
    'data' => [
      [
        '2014',
        134,
        'test',
        'test',
        139,
        'Kasese solgs trial',
        'This trial was loaded into the fixture to test solgs.',
        'Alpha',
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        '23',
        'test_location',
        39086,
        'UG120250',
        '',
        'plot',
        39691,
        'KASESE_TP2013_1000',
        '1',
        '53',
        '36014',
        undef,
        undef,
        'test',
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef
      ],
      [
        '2014',
        134,
        'test',
        'test',
        139,
        'Kasese solgs trial',
        'This trial was loaded into the fixture to test solgs.',
        'Alpha',
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        '23',
        'test_location',
        38960,
        'UG120092',
        '',
        'plot',
        39493,
        'KASESE_TP2013_1001',
        '1',
        '53',
        '36015',
        undef,
        undef,
        'test',
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef
      ]
    ],
    'observationVariables' => [
      {
        'observationVariableName' => 'cass sink leaf|3-phosphoglyceric acid|ug/g|week 16|COMP:0000013',
        'observationVariableDbId' => '77559'
      },
      {
        'observationVariableDbId' => '77557',
        'observationVariableName' => 'cass sink leaf|ADP alpha-D-glucoside|ug/g|week 16|COMP:0000011'
      },
      {
        'observationVariableDbId' => '77556',
        'observationVariableName' => 'cass sink leaf|ADP|ug/g|week 16|COMP:0000010'
      },
      {
        'observationVariableDbId' => '77548',
        'observationVariableName' => 'cass source leaf|3-phosphoglyceric acid|ug/g|week 16|COMP:0000002'
      },
      {
        'observationVariableDbId' => '77553',
        'observationVariableName' => 'cass source leaf|ADP alpha-D-glucoside|ug/g|week 16|COMP:0000007'
      },
      {
        'observationVariableDbId' => '77549',
        'observationVariableName' => 'cass source leaf|ADP|ug/g|week 16|COMP:0000003'
      },
      {
        'observationVariableDbId' => '77552',
        'observationVariableName' => 'cass storage root|3-phosphoglyceric acid|ug/g|week 16|COMP:0000006'
      },
      {
        'observationVariableDbId' => '77550',
        'observationVariableName' => 'cass storage root|ADP alpha-D-glucoside|ug/g|week 16|COMP:0000004'
      },
      {
        'observationVariableName' => 'cass storage root|ADP|ug/g|week 16|COMP:0000005',
        'observationVariableDbId' => '77551'
      },
      {
        'observationVariableDbId' => '77558',
        'observationVariableName' => 'cass upper stem|3-phosphoglyceric acid|ug/g|week 16|COMP:0000012'
      },
      {
        'observationVariableDbId' => '77554',
        'observationVariableName' => 'cass upper stem|ADP alpha-D-glucoside|ug/g|week 16|COMP:0000008'
      },
      {
        'observationVariableName' => 'cass upper stem|ADP|ug/g|week 16|COMP:0000009',
        'observationVariableDbId' => '77555'
      },
      {
        'observationVariableName' => 'dry matter content percentage|CO_334:0000092',
        'observationVariableDbId' => '70741'
      },
      {
        'observationVariableDbId' => '70666',
        'observationVariableName' => 'fresh root weight|CO_334:0000012'
      },
      {
        'observationVariableName' => 'fresh shoot weight measurement in kg|CO_334:0000016',
        'observationVariableDbId' => '70773'
      },
      {
        'observationVariableDbId' => '70668',
        'observationVariableName' => 'harvest index variable|CO_334:0000015'
      }
    ],
    'headerRow' => [
      'studyYear',
      'programDbId',
      'programName',
      'programDescription',
      'studyDbId',
      'studyName',
      'studyDescription',
      'studyDesign',
      'plotWidth',
      'plotLength',
      'fieldSize',
      'fieldTrialIsPlannedToBeGenotyped',
      'fieldTrialIsPlannedToCross',
      'plantingDate',
      'harvestDate',
      'locationDbId',
      'locationName',
      'germplasmDbId',
      'germplasmName',
      'germplasmSynonyms',
      'observationLevel',
      'observationUnitDbId',
      'observationUnitName',
      'replicate',
      'blockNumber',
      'plotNumber',
      'rowNumber',
      'colNumber',
      'entryType',
      'plantNumber'
    ]
  },
  'metadata' => {
    'datafiles' => [],
    'status' => [
      {
        'messageType' => 'INFO',
        'message' => 'BrAPI base call found with page=0, pageSize=2'
      },
      {
        'message' => 'Loading CXGN::BrAPI::v2::ObservationTables',
        'messageType' => 'INFO'
      },
      {
        'message' => 'Observations table result constructed',
        'messageType' => 'INFO'
      }
    ],
    'pagination' => {
      'totalPages' => 508,
      'currentPage' => 0,
      'pageSize' => 2,
      'totalCount' => 1016
    }
  }
	  }, "table test");


# is_deeply($response, {'result' => {'observationVariables' => [{'observationVariableDbId' => '77559','observationVariableName' => 'cass sink leaf|3-phosphoglyceric acid|ug/g|week 16|COMP:0000013'},{'observationVariableName' => 'cass sink leaf|ADP alpha-D-glucoside|ug/g|week 16|COMP:0000011','observationVariableDbId' => '77557'},{'observationVariableDbId' => '77556','observationVariableName' => 'cass sink leaf|ADP|ug/g|week 16|COMP:0000010'},{'observationVariableName' => 'cass source leaf|3-phosphoglyceric acid|ug/g|week 16|COMP:0000002','observationVariableDbId' => '77548'},{'observationVariableName' => 'cass source leaf|ADP alpha-D-glucoside|ug/g|week 16|COMP:0000007','observationVariableDbId' => '77553'},{'observationVariableDbId' => '77549','observationVariableName' => 'cass source leaf|ADP|ug/g|week 16|COMP:0000003'},{'observationVariableName' => 'cass storage root|3-phosphoglyceric acid|ug/g|week 16|COMP:0000006','observationVariableDbId' => '77552'},{'observationVariableDbId' => '77550','observationVariableName' => 'cass storage root|ADP alpha-D-glucoside|ug/g|week 16|COMP:0000004'},{'observationVariableDbId' => '77551','observationVariableName' => 'cass storage root|ADP|ug/g|week 16|COMP:0000005'},{'observationVariableDbId' => '77558','observationVariableName' => 'cass upper stem|3-phosphoglyceric acid|ug/g|week 16|COMP:0000012'},{'observationVariableDbId' => '77554','observationVariableName' => 'cass upper stem|ADP alpha-D-glucoside|ug/g|week 16|COMP:0000008'},{'observationVariableName' => 'cass upper stem|ADP|ug/g|week 16|COMP:0000009','observationVariableDbId' => '77555'},{'observationVariableName' => 'dry matter content percentage|CO_334:0000092','observationVariableDbId' => '70741'},{'observationVariableName' => 'fresh root weight|CO_334:0000012','observationVariableDbId' => '70666'},{'observationVariableDbId' => '70773','observationVariableName' => 'fresh shoot weight measurement in kg|CO_334:0000016'},{'observationVariableDbId' => '70668','observationVariableName' => 'harvest index variable|CO_334:0000015'}],'data' => [[ '2014', 134, 'test', 'test', 139, 'Kasese solgs trial', 'This trial was loaded into the fixture to test solgs.', 'Alpha', undef, undef, undef, undef, undef, undef, undef, '23', 'test_location', 39086, 'UG120250', '', 'plot', 39691, 'KASESE_TP2013_1000', '1', '53', '36014', undef, undef, 'test', undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef ], [ '2014', 134, 'test', 'test', 139, 'Kasese solgs trial', 'This trial was loaded into the fixture to test solgs.', 'Alpha', undef, undef, undef, undef, undef, undef, undef, '23', 'test_location', 38960, 'UG120092', '', 'plot', 39493, 'KASESE_TP2013_1001', '1', '53', '36015', undef, undef, 'test', undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef ]],'headerRow' => ['studyYear','programDbId','programName','programDescription','studyDbId','studyName','studyDescription','studyDesign','plotWidth','plotLength','fieldSize','fieldTrialIsPlannedToBeGenotyped','fieldTrialIsPlannedToCross','plantingDate','harvestDate','locationDbId','locationName','germplasmDbId','germplasmName','germplasmSynonyms','observationLevel','observationUnitDbId','observationUnitName','replicate','blockNumber','plotNumber','rowNumber','colNumber','entryType','plantNumber']},'metadata' => {'pagination' => {'currentPage' => 0,'totalPages' => 508,'totalCount' => 1016,'pageSize' => 2},'status' => [{'message' => 'BrAPI base call found with page=0, pageSize=2','messageType' => 'INFO'},{'message' => 'Loading CXGN::BrAPI::v2::ObservationTables','messageType' => 'INFO'},{'message' => 'Observations table result constructed','messageType' => 'INFO'}],'datafiles' => []}}, "GET observations table test");
#is_deeply ($response, {'result' => {  'headerRow' => ['studyYear','programDbId','programName','programDescription','studyDbId','studyName','studyDescription','studyDesign','plotWidth','plotLength','fieldSize','fieldTrialIsPlannedToBeGenotyped','fieldTrialIsPlannedToCross','plantingDate','harvestDate','locationDbId','locationName','germplasmDbId','germplasmName','germplasmSynonyms','observationLevel','observationUnitDbId','observationUnitName','replicate','blockNumber','plotNumber','rowNumber','colNumber','entryType','plantNumber'],  'data' => [['2014',134,'test','test',139,'Kasese solgs trial','This trial was loaded into the fixture to test solgs.', 'Alpha', undef, undef, undef, undef, undef, undef, undef, '23', 'test_location', 39086, 'UG120250', '','plot', 39691, 'KASESE_TP2013_1000', '1', '53', '36014', undef, undef, 'test', undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef,'0', '0', '0', undef, undef  ],  ['2014', 134, 'test', 'test', 139, 'Kasese solgs trial', 'This trial was loaded into the fixture to test solgs.', 'Alpha', undef, undef, undef, undef, undef, undef, undef, '23', 'test_location', 38960, 'UG120092', '', 'plot', 39493, 'KASESE_TP2013_1001', '1', '53', '36015', undef, undef, 'test', undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, undef, '0', '0', '0', undef, undef]],  'observationVariables' => [{'observationVariableDbId' => '77559', 'observationVariableName' => 'cass sink leaf|3-phosphoglyceric acid|ug/g|week 16|COMP:0000013'},{'observationVariableDbId' => '77557','observationVariableName' => 'cass sink leaf|ADP alpha-D-glucoside|ug/g|week 16|COMP:0000011'},{'observationVariableName' => 'cass sink leaf|ADP|ug/g|week 16|COMP:0000010','observationVariableDbId' => '77556'},{  'observationVariableName' => 'cass source leaf|3-phosphoglyceric acid|ug/g|week 16|COMP:0000002',  'observationVariableDbId' => '77548'},{  'observationVariableName' => 'cass source leaf|ADP alpha-D-glucoside|ug/g|week 16|COMP:0000007',  'observationVariableDbId' => '77553'},{  'observationVariableDbId' => '77549',  'observationVariableName' => 'cass source leaf|ADP|ug/g|week 16|COMP:0000003'},{  'observationVariableDbId' => '77552',  'observationVariableName' => 'cass storage root|3-phosphoglyceric acid|ug/g|week 16|COMP:0000006'},{  'observationVariableName' => 'cass storage root|ADP alpha-D-glucoside|ug/g|week 16|COMP:0000004',  'observationVariableDbId' => '77550'},{  'observationVariableDbId' => '77551',  'observationVariableName' => 'cass storage root|ADP|ug/g|week 16|COMP:0000005'},{  'observationVariableName' => 'cass upper stem|3-phosphoglyceric acid|ug/g|week 16|COMP:0000012',  'observationVariableDbId' => '77558'},{  'observationVariableDbId' => '77554',  'observationVariableName' => 'cass upper stem|ADP alpha-D-glucoside|ug/g|week 16|COMP:0000008'},{  'observationVariableName' => 'cass upper stem|ADP|ug/g|week 16|COMP:0000009',  'observationVariableDbId' => '77555'},{  'observationVariableDbId' => '70741',  'observationVariableName' => 'dry matter content percentage|CO_334:0000092'},{  'observationVariableDbId' => '70666',  'observationVariableName' => 'fresh root weight|CO_334:0000012'},{  'observationVariableName' => 'fresh shoot weight measurement in kg|CO_334:0000016',  'observationVariableDbId' => '70773'},{  'observationVariableName' => 'harvest index variable|CO_334:0000015',  'observationVariableDbId' => '70668'}]},  'metadata' => {'status' => [  {'message' => 'BrAPI base call found with page=0, pageSize=2',    'messageType' => 'INFO'  },  {'message' => 'Loading CXGN::BrAPI::v2::ObservationTables', 'messageType' => 'INFO'  },  {'message' => 'Observations table result constructed', 'messageType' => 'INFO'}],  'pagination' => {  'totalCount' => 1016,  'currentPage' => 0,  'pageSize' => 2,  'totalPages' => 508},  'datafiles' => []}}, "GET OBSERVATION  TABLE TEST");

$mech->post_ok('http://localhost:3010/brapi/v2/search/observations', ['pageSize'=>'2', 'observationDbIds' => ['740337']]);
$response = decode_json $mech->content;
$searchId = $response->{result} ->{searchResultsDbId};
#print STDERR "\n\n" . Dumper$response;
$mech->get_ok('http://localhost:3010/brapi/v2/search/observations/'. $searchId);
$response = decode_json $mech->content;
#print STDERR "\n\n" . Dumper$response;
#18
is_deeply($response, {'metadata' => {'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::Results'},{'message' => 'search result constructed','messageType' => 'INFO'}],'pagination' => {'totalCount' => 1,'currentPage' => 0,'pageSize' => 10,'totalPages' => 1},'datafiles' => []},'result' => {'data' => [{'observationVariableName' => 'cass sink leaf|ADP alpha-D-glucoside|ug/g|week 16|COMP:0000011','germplasmDbId' => '41283','studyDbId' => '165','observationTimeStamp' => undef,'collector' => undef,'value' => '39.84365','observationVariableDbId' => '77557','observationDbId' => '740337','observationUnitName' => 'CASS_6Genotypes_103','externalReferences' => undef,'observationUnitDbId' => '41284','season' => {'seasonDbId' => '2017','season' => '2017','year' => '2017'},'uploadedBy' => undef,'germplasmName' => 'IITA-TMS-IBA980581','additionalInfo' => undef}]}}, "Search observations test");


# POST /observations
$data = '[ {"observationUnitDbId": 41294,  "uploadedBy": "Jane Doe", "observationTimeStamp": "2019-01-05T14:47:23Z", "observationVariableDbId":"70741", "season": "2011",   "value": "15", "externalReferences" : [{ "referenceId": "doi:10.155454/12341234", "referenceSource" : "DOI" } ], "additionalInfo" : { "year" : "2011" } } ]';
$mech->post('http://localhost:3010/brapi/v2/observations/', Content => $data);
$response = decode_json $mech->content;

my $column = $f->bcs_schema()->resultset('Phenotype::Phenotype')->get_column('phenotype_id');
my $phenotype_id = $column->max();

#21
is_deeply($response,{"result"=>{"data"=>[{"value"=>"15","observationUnitName"=>"CASS_6Genotypes_307","observationVariableName"=>"dry matter content percentage","observationTimeStamp"=>"2019-01-05T14:47:23Z","collector"=>"janedoe","studyDbId"=>165,"uploadedBy"=>"janedoe","observationVariableDbId"=>"70741","observationDbId"=>$phenotype_id,"observationLevel"=>"plot","observationUnitDbId"=>41294,"germplasmName"=>"IITA-TMS-IBA980581","germplasmDbId"=>41283, "externalReferences" => [{ "referenceId"=> "doi:10.155454/12341234", "referenceSource" => "DOI" }], "additionalInfo" => { "year" => "2011" } } ]},"metadata"=>{"pagination"=>{"currentPage"=>0,"totalCount"=>1,"totalPages"=>1,"pageSize"=>10},"datafiles"=>[],"status"=>[{"message"=>"BrAPI base call found with page=0, pageSize=10","messageType"=>"INFO"},{"message"=>"Loading CXGN::BrAPI::v2::Observations","messageType"=>"INFO"},{"messageType"=>"info","message"=>"Request structure is valid"},{"message"=>"Request data is valid","messageType"=>"info"},{"messageType"=>"info","message"=>"File for incoming brapi obserations saved in archive."},{"messageType"=>"INFO","message"=>"All values in your file have been successfully processed!<br><br>1 new values stored<br>0 previously stored values skipped<br>0 previously stored values overwritten<br>0 previously stored values removed<br><br>"}]} } , "check observation storage");


# GET /observations/{observationDbId}
#21 verify
$mech->get_ok('http://localhost:3010/brapi/v2/observations/' . $phenotype_id);
$response = decode_json $mech->content;

is_deeply($response,{'metadata' => { 'datafiles' => [], 'status' => [ {   'message' => 'BrAPI base call found with page=0, pageSize=10',   'messageType' => 'INFO' }, {   'message' => 'Loading CXGN::BrAPI::v2::Observations',   'messageType' => 'INFO' }, {   'messageType' => 'INFO',   'message' => 'Observations result constructed' } ], 'pagination' => { 'currentPage' => 0, 'pageSize' => 10, 'totalPages' => 1, 'totalCount' => 1 } },'result' => { 'uploadedBy' => 'janedoe', 'value' => '15', 'studyDbId' => '165', 'observationUnitName' => 'CASS_6Genotypes_307', 'season' => {   'seasonDbId' => '2017',   'season' => '2017',   'year' => '2017' } , 'observationDbId' => $phenotype_id, 'observationTimeStamp' => '2019-01-05T14:47:23Z', 'germplasmDbId' => '41283', 'observationVariableDbId' => '70741', 'observationVariableName' => 'dry matter content percentage|CO_334:0000092', 'collector' => 'janedoe', 'observationUnitDbId' => '41294', 'externalReferences' => [ {   'referenceId' => 'doi:10.155454/12341234',   'referenceSource' => 'DOI' } ], 'germplasmName' => 'IITA-TMS-IBA980581', 'additionalInfo' => { 'year' => '2011' } }} ,"check stored observation");

# PUT /observations
$data = '{ "740336":  { "observationUnitDbId": "41284",  "collector": "Jane Doe", "observationTimeStamp": "2020-01-01T14:47:23-07:00", "observationVariableDbId":"77559", "season": "2011",  "value": "value 5", "observationUnitName" : "CASS_6Genotypes_103", "externalReferences" : [{ "referenceId": "doi:10.155454/5555", "referenceSource" : "DOI" } ], "additionalInfo" : { "year" : "2011" } }}';
#it need same variable and unit, only updates values or collector
$resp = $ua->put("http://localhost:3010/brapi/v2/observations/", Content => $data);
$response = decode_json $resp->{_content};

# 19 Test will be fixed when repeted and modified obsverations are allowed
is_deeply($response, {'metadata' => {'pagination' => {'currentPage' => 0,'totalCount' => 1,'pageSize' => 10,'totalPages' => 1},'datafiles' => [],'status' => [{'message' => 'BrAPI base call found with page=0, pageSize=10','messageType' => 'INFO'},{'message' => 'Loading CXGN::BrAPI::v2::Observations','messageType' => 'INFO'},{'messageType' => 'info','message' => 'Request structure is valid'},{'messageType' => 'info','message' => 'Request data is valid'},{'messageType' => 'info','message' => 'File for incoming brapi obserations saved in archive.'},{'messageType' => 'INFO','message' => 'All values in your file have been successfully processed!<br><br>0 new values stored<br>0 previously stored values skipped<br>1 previously stored values overwritten<br>0 previously stored values removed<br><br>'}]},'result' => {'data' => [{'germplasmName' => 'IITA-TMS-IBA980581','observationVariableName' => 'cass sink leaf|3-phosphoglyceric acid|ug/g|week 16','observationUnitName' => 'CASS_6Genotypes_103','observationTimeStamp' => '2020-01-01T14:47:23-07:00','germplasmDbId' => 41283,'collector' => 'Jane Doe','observationDbId' => 740336,'studyDbId' => 165,'observationLevel' => 'plot','observationUnitDbId' => 41284,'observationVariableDbId' => '77559','value' => 'value 5','uploadedBy' => 'Jane Doe', 'externalReferences' => [{ "referenceId" => "doi:10.155454/5555", "referenceSource" => "DOI" } ], "additionalInfo" => { "year" => "2011" }  }]}}, "PUT observations test");

$data = '{ "observationUnitDbId": 39548,  "collector": "John Doe", "observationTimeStamp": "2023-01-01T14:47:23-06:10", "observationVariableDbId":"70741", "season": "2011",  "value": "500", "externalReferences" : [{ "referenceId": "doi:10.155454/200" , "referenceSource" : "DOI" } ] }';
$resp = $ua->put("http://localhost:3010/brapi/v2/observations/737987", Content => $data);
$response = decode_json $resp->{_content};
#print STDERR "\n\n--update" . Dumper$response;

is_deeply($response, { 'result' => {'data' => [ { 'collector' => 'John Doe', 'observationVariableDbId' => '70741', 'germplasmName' => 'UG130133', 'additionalInfo' => undef, 'germplasmDbId' => '39243', 'observationDbId' => '737987', 'observationUnitDbId' => '39548', 'observationUnitName' => 'KASESE_TP2013_1012', 'observationVariableName' => 'dry matter content percentage', 'observationTimeStamp' => '2023-01-01T14:47:23-06:10', 'observationLevel' => 'plot', 'value' => '500', 'uploadedBy' => 'John Doe', 'externalReferences' => [ 	{ 	  'referenceId' => 'doi:10.155454/200', 	  'referenceSource' => 'DOI' 	} ], 'studyDbId' => '139' } ]},	'metadata' => { 'status' => [ { 'messageType' => 'INFO', 'message' => 'BrAPI base call found with page=0, pageSize=10' }, { 'messageType' => 'INFO', 'message' => 'Loading CXGN::BrAPI::v2::Observations' }, { 'message' => 'Request structure is valid', 'messageType' => 'info' }, { 'messageType' => 'info', 'message' => 'Request data is valid' }, { 'messageType' => 'info', 'message' => 'File for incoming brapi obserations saved in archive.' }, { 'message' => 'All values in your file have been successfully processed!<br><br>0 new values stored<br>0 previously stored values skipped<br>1 previously stored values overwritten<br>0 previously stored values removed<br><br>', 'messageType' => 'INFO' } ], 'pagination' => { 'totalPages' => 1, 'pageSize' => 10, 'totalCount' => 1, 'currentPage' => 0 }, 'datafiles' => [] } } , "PUT observations detail test");

####### Variables
$mech->get_ok('http://localhost:3010/brapi/v2/variables?pageSize=2');
$response = decode_json $mech->content;
#print STDERR "\n\n" . Dumper$response;
is_deeply($response,  {'metadata' => {'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=2'},{'message' => 'Loading CXGN::BrAPI::v2::ObservationVariables','messageType' => 'INFO'},{'message' => 'Observationvariable search result constructed','messageType' => 'INFO'}],'pagination' => {'totalCount' => 267,'pageSize' => 2,'totalPages' => 134,'currentPage' => 0},'datafiles' => []},'result' => {'data' => [ { 'documentationURL' => '', 'growthStage' => undef, 'institution' => undef, 'observationVariableDbId' => '70692', 'additionalInfo' => {}, 'observationVariableName' => 'abscisic acid content of leaf ug/g|CO_334:0000047', 'synonyms' => [ 'abscon', 'AbsCt_Meas_ugg' ], 'language' => 'eng', 'ontologyReference' => { 'ontologyName' => 'CO_334', 'documentationLinks' => undef, 'ontologyDbId' => '186', 'version' => undef }, 'commonCropName' => 'Cassava', 'contextOfUse' => undef, 'observationVariablePUI' => 'CO_334:0000047', 'method' => {}, 'scientist' => undef, 'trait' => { 'attribute' => undef, 'synonyms' => [ 'abscon', 'AbsCt_Meas_ugg' ], 'additionalInfo' => {}, 'alternativeAbbreviations' => undef, 'entity' => undef, 'traitDescription' => 'Abscisic acid content of leaf sample.', 'attributePUI' => undef, 'externalReferences' => [ { 'referenceId' => 'CO_334:0000047', 'referenceSource' => 'Crop Ontology' } ], 'entityPUI' => undef, 'status' => 'active', 'mainAbbreviation' => undef, 'traitPUI' => undef, 'traitClass' => undef, 'traitDbId' => '70692', 'traitName' => 'abscisic acid content of leaf ug/g', 'ontologyReference' => { 'documentationLinks' => undef, 'ontologyName' => 'CO_334', 'version' => undef, 'ontologyDbId' => '186' } }, 'defaultValue' => '', 'status' => 'active', 'externalReferences' => [ { 'referenceId' => 'CO_334:0000047', 'referenceSource' => 'Crop Ontology' } ], 'scale' => { 'dataType' => 'Text', 'decimalPlaces' => undef, 'scalePUI' => undef, 'ontologyReference' => undef, 'scaleDbId' => undef, 'scaleName' => undef, 'externalReferences' => undef, 'validValues' => { 'categories' => undef, 'maximumValue' => undef, 'minimumValue' => undef }, 'units' => undef, 'additionalInfo' => undef }, 'submissionTimestamp' => undef }, { 'defaultValue' => '', 'status' => 'active', 'scale' => { 'externalReferences' => undef, 'scaleDbId' => undef, 'scaleName' => undef, 'additionalInfo' => undef, 'units' => undef, 'validValues' => { 'categories' => undef, 'maximumValue' => undef, 'minimumValue' => undef }, 'dataType' => 'Text', 'ontologyReference' => undef, 'decimalPlaces' => undef, 'scalePUI' => undef }, 'externalReferences' => [ { 'referenceId' => 'CO_334:0000121', 'referenceSource' => 'Crop Ontology' } ], 'submissionTimestamp' => undef, 'ontologyReference' => { 'documentationLinks' => undef, 'ontologyName' => 'CO_334', 'version' => undef, 'ontologyDbId' => '186' }, 'commonCropName' => 'Cassava', 'observationVariablePUI' => 'CO_334:0000121', 'contextOfUse' => undef, 'method' => {}, 'scientist' => undef, 'trait' => { 'ontologyReference' => { 'documentationLinks' => undef, 'ontologyName' => 'CO_334', 'version' => undef, 'ontologyDbId' => '186' }, 'traitName' => 'amylopectin content ug/g in percentage', 'traitDbId' => '70761', 'traitClass' => undef, 'status' => 'active', 'traitPUI' => undef, 'mainAbbreviation' => undef, 'entityPUI' => undef, 'externalReferences' => [ { 'referenceSource' => 'Crop Ontology', 'referenceId' => 'CO_334:0000121' } ], 'entity' => undef, 'traitDescription' => 'Estimation of amylopectin content of cassava roots in percentage(%).', 'attributePUI' => undef, 'alternativeAbbreviations' => undef, 'additionalInfo' => {}, 'attribute' => undef, 'synonyms' => [ 'amylp', 'AmylPCt_Meas_pct' ] }, 'additionalInfo' => {}, 'observationVariableName' => 'amylopectin content ug/g in percentage|CO_334:0000121', 'synonyms' => [ 'amylp', 'AmylPCt_Meas_pct' ], 'language' => 'eng', 'documentationURL' => '', 'growthStage' => undef, 'institution' => undef, 'observationVariableDbId' => '70761'} ] }});

$mech->get_ok('http://localhost:3010/brapi/v2/variables/70752');
$response = decode_json $mech->content;
#print STDERR "\n\n" . Dumper$response;
is_deeply($response, {'metadata' => {'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'message' => 'Loading CXGN::BrAPI::v2::ObservationVariables','messageType' => 'INFO'},{'message' => 'Observationvariable search result constructed','messageType' => 'INFO'}],'pagination' => {'totalPages' => 1,'pageSize' => 10,'currentPage' => 0,'totalCount' => 1},'datafiles' => []},'result' => { 'documentationURL' => '', 'growthStage' => undef, 'observationVariableDbId' => '70752', 'institution' => undef, 'observationVariableName' => 'amylose amylopectin root content ratio|CO_334:0000124', 'additionalInfo' => {}, 'language' => 'eng', 'synonyms' => [ 'amylrt', 'AmylR_Comp_r' ], 'commonCropName' => 'Cassava', 'observationVariablePUI' => 'CO_334:0000124', 'contextOfUse' => undef, 'ontologyReference' => { 'ontologyDbId' => '186', 'version' => undef, 'documentationLinks' => undef, 'ontologyName' => 'CO_334' }, 'trait' => { 'additionalInfo' => {}, 'synonyms' => [ 'amylrt', 'AmylR_Comp_r' ], 'attribute' => undef, 'attributePUI' => undef, 'entity' => undef, 'traitDescription' => 'The amylose content of a cassava root sample divided by the amylopectin content of the same sample.', 'alternativeAbbreviations' => undef, 'traitPUI' => undef, 'mainAbbreviation' => undef, 'status' => 'active', 'entityPUI' => undef, 'externalReferences' => [ { 'referenceSource' => 'Crop Ontology', 'referenceId' => 'CO_334:0000124' } ], 'ontologyReference' => { 'version' => undef, 'ontologyDbId' => '186', 'documentationLinks' => undef, 'ontologyName' => 'CO_334' }, 'traitName' => 'amylose amylopectin root content ratio', 'traitDbId' => '70752', 'traitClass' => undef }, 'method' => {}, 'scientist' => undef, 'status' => 'active', 'defaultValue' => '', 'submissionTimestamp' => undef, 'scale' => { 'ontologyReference' => undef, 'scalePUI' => undef, 'decimalPlaces' => undef, 'dataType' => 'Text', 'additionalInfo' => undef, 'validValues' => { 'maximumValue' => undef, 'minimumValue' => undef, 'categories' => undef }, 'units' => undef, 'externalReferences' => undef, 'scaleName' => undef, 'scaleDbId' => undef }, 'externalReferences' => [ { 'referenceSource' => 'Crop Ontology', 'referenceId' => 'CO_334:0000124' } ] }});

$mech->post_ok('http://localhost:3010/brapi/v2/search/variables', ['pageSize'=>'1', 'observationVariableDbIds' => ['70761']]);
$response = decode_json $mech->content;
$searchId = $response->{result} ->{searchResultsDbId};
#print STDERR "\n\n" . Dumper$response;
$mech->get_ok('http://localhost:3010/brapi/v2/search/variables/'. $searchId);
$response = decode_json $mech->content;
#print STDERR "\n\n" . Dumper$response;
is_deeply($response, {'result' => {'data' => [ { 'commonCropName' => 'Cassava', 'contextOfUse' => undef, 'trait' => { 'externalReferences' => [ { 'referenceId' => 'CO_334:0000121', 'referenceSource' => 'Crop Ontology' } ], 'traitClass' => undef, 'traitName' => 'amylopectin content ug/g in percentage', 'synonyms' => [ 'amylp', 'AmylPCt_Meas_pct' ], 'status' => 'active', 'additionalInfo' => {}, 'ontologyReference' => { 'documentationLinks' => undef, 'ontologyDbId' => '186', 'ontologyName' => 'CO_334', 'version' => undef }, 'traitPUI' => undef, 'traitDescription' => 'Estimation of amylopectin content of cassava roots in percentage(%).', 'entityPUI' => undef, 'attributePUI' => undef, 'attribute' => undef, 'alternativeAbbreviations' => undef, 'entity' => undef, 'mainAbbreviation' => undef, 'traitDbId' => '70761' }, 'institution' => undef, 'submissionTimestamp' => undef, 'language' => 'eng', 'scientist' => undef, 'observationVariableDbId' => '70761', 'observationVariableName' => 'amylopectin content ug/g in percentage|CO_334:0000121', 'defaultValue' => '', 'ontologyReference' => { 'ontologyDbId' => '186', 'ontologyName' => 'CO_334', 'documentationLinks' => undef, 'version' => undef }, 'documentationURL' => '', 'synonyms' => [ 'amylp', 'AmylPCt_Meas_pct' ], 'additionalInfo' => {}, 'growthStage' => undef, 'status' => 'active', 'scale' => { 'units' => undef, 'validValues' => { 'minimumValue' => undef, 'maximumValue' => undef, 'categories' => undef }, 'scalePUI' => undef, 'externalReferences' => undef, 'scaleDbId' => undef, 'additionalInfo' => undef, 'scaleName' => undef, 'dataType' => 'Text', 'ontologyReference' => undef, 'decimalPlaces' => undef }, 'observationVariablePUI' => 'CO_334:0000121', 'externalReferences' => [ { 'referenceId' => 'CO_334:0000121', 'referenceSource' => 'Crop Ontology' } ], 'method' => {}
 }]},'metadata' => {'datafiles' => [],'pagination' => {'totalCount' => 1,'pageSize' => 10,'currentPage' => 0,'totalPages' => 1},'status' => [{'message' => 'BrAPI base call found with page=0, pageSize=10','messageType' => 'INFO'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::Results'},{'message' => 'search result constructed','messageType' => 'INFO'}]}});


####### Traits
$mech->get_ok('http://localhost:3010/brapi/v2/traits?pageSize=1&page=1');
$response = decode_json $mech->content;
#print STDERR "\n\n" . Dumper$response;
is_deeply($response,  {
  'metadata' => {
    'datafiles' => [],
    'status' => [
      {
        'messageType' => 'INFO',
        'message' => 'BrAPI base call found with page=1, pageSize=1'
      },
      {
        'messageType' => 'INFO',
        'message' => 'Loading CXGN::BrAPI::v2::Traits'
      },
      {
        'message' => 'Traits list result constructed',
        'messageType' => 'INFO'
      }
    ],
    'pagination' => {
      'pageSize' => 1,
      'currentPage' => 1,
      'totalPages' => 7035,
      'totalCount' => 7035
    }
  },
  'result' => {
    'data' => [
      {
        'status' => 'active',
        'attribute' => undef,
        'traitClass' => undef,
        'traitDbId' => '68621',
        'traitPUI' => undef,
        'attributePUI' => undef,
        'entityPUI' => undef,
        'entity' => undef,
        'traitName' => '1,3-beta-D-glucan synthase complex',
        'ontologyReference' => {
          'version' => undef,
          'documentationLinks' => undef,
          'ontologyName' => 'GO',
          'ontologyDbId' => 5
        },
        'alternativeAbbreviations' => undef,
        'synonyms' => [],
        'mainAbbreviation' => undef,
        'externalReferences' => [
          {
            'referenceSource' => 'EC',
            'referenceId' => '2.4.1.34'
          },
          {
            'referenceId' => 'http://www.cropontology.org/terms/GO:0000148/',
            'referenceSource' => 'Crop Ontology'
          }
        ],
        'additionalInfo' => {},
        'traitDescription' => 'A protein complex that catalyzes the transfer of a glucose group from UDP-glucose to a 1,3-beta-D-glucan chain.'
      }
    ]
  }
});

$mech->get_ok('http://localhost:3010/brapi/v2/traits/77216');
$response = decode_json $mech->content;
#print STDERR "\n\n" . Dumper$response;
is_deeply($response, {'metadata' => {'pagination' => {'totalPages' => 1,'pageSize' => 10,'totalCount' => 1,'currentPage' => 0},'datafiles' => [],'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::Traits'},{'message' => 'Trait detail result constructed','messageType' => 'INFO'}]},'result' => {'additionalInfo' => {},'traitName' => '3-phosphoglyceric acid','traitPUI' => undef,'entity' => undef,'attributePUI' => undef, 'entityPUI' => undef,'externalReferences' => [{'referenceId' => '40016','referenceSource' => 'CHEBI'},{'referenceSource' => 'CHEBI','referenceId' => '11882'},{'referenceId' => '1659','referenceSource' => 'CHEBI'},{'referenceId' => '24345','referenceSource' => 'CHEBI'},{'referenceId' => '22735334 "PubMed citation"','referenceSource' => 'CiteXplore'},{'referenceSource' => 'CiteXplore','referenceId' => '17439666 "PubMed citation"'},{'referenceSource' => 'CiteXplore','referenceId' => '19212411 "PubMed citation"'},{'referenceSource' => 'CiteXplore','referenceId' => '2490073 "PubMed citation"'},{'referenceId' => 'HMDB00807 "HMDB"','referenceSource' => 'HMDB'},{'referenceSource' => 'CiteXplore','referenceId' => '7602787 "PubMed citation"'},{'referenceId' => '3-Phosphoglycerate "Wikipedia"','referenceSource' => 'Wikipedia'},{'referenceId' => 'C00007286 "KNApSAcK"','referenceSource' => 'KNApSAcK'},{'referenceId' => '1726829 "Reaxys Registry Number"','referenceSource' => 'Reaxys'},{'referenceSource' => 'CiteXplore','referenceId' => '10937433 "PubMed citation"'},{'referenceId' => '2153800 "PubMed citation"','referenceSource' => 'CiteXplore'},{'referenceSource' => 'CiteXplore','referenceId' => '183226 "PubMed citation"'},{'referenceId' => '7664478 "PubMed citation"','referenceSource' => 'CiteXplore'},{'referenceSource' => 'DrugBank','referenceId' => 'DB04510 "DrugBank"'},{'referenceId' => '23857558 "PubMed citation"','referenceSource' => 'CiteXplore'},{'referenceSource' => 'CiteXplore','referenceId' => '15882454 "PubMed citation"'},{'referenceId' => '36399 "PubMed citation"','referenceSource' => 'CiteXplore'},{'referenceSource' => 'ChemIDplus','referenceId' => '820-11-1 "CAS Registry Number"'},{'referenceSource' => 'CiteXplore','referenceId' => '9055056 "PubMed citation"'},{'referenceSource' => 'Wikipedia','referenceId' => '3-Phosphoglyceric_acid "Wikipedia"'},{'referenceSource' => 'CiteXplore','referenceId' => '8412001 "PubMed citation"'},{'referenceId' => 'C00597 "KEGG COMPOUND"','referenceSource' => 'KEGG COMPOUND'},{'referenceSource' => 'Crop Ontology','referenceId' => 'http://www.cropontology.org/terms/CHEBI:17050/'}],'mainAbbreviation' => undef,'traitDbId' => '77216','ontologyReference' => {'ontologyName' => 'CHEBI','documentationLinks' => undef,'ontologyDbId' => 88,'version' => undef},'status' => 'active','attribute' => undef,'synonyms' => ['G3P','3-Pg','3-PGA','C3H7O7P','Glycerate-3-P','3-P-Glycerate','3-P-D-Glycerate','Phosphoglycerate','3-Phosphoglycerate','3-Phospho-glycerate','3-Glycerophosphorate','3-Phospho-D-glycerate','Glycerate 3-phosphate','OC(COP(O)(O)=O)C(O)=O','3-phosphoglyceric acid','glycerate 3-phosphates','3-Phospho-(R)-glycerate','3-Phospho-glyceric acid','D-Glycerate 3-phosphate','DL-Glycerate 3-phosphate','3-Glycerophosphoric acid','Glyceric acid 3-phosphate','OSJPPGNTCRNQQC-UHFFFAOYSA-N','D-(-)-3-Phosphoglyceric acid','3-(dihydrogen phosphate)Glycerate','3-(dihydrogen phosphate)Glyceric acid','2-hydroxy-3-(phosphonooxy)propanoic acid','InChI=1S/C3H7O7P/c4-2(3(5)6)1-10-11(7,8)9/h2,4H,1H2,(H,5,6)(H2,7,8,9)'],'traitDescription' => 'A monophosphoglyceric acid having the phospho group at the 3-position. It is an intermediate in metabolic pathways like glycolysis and calvin cycle.','traitClass' => undef,'alternativeAbbreviations' => undef}});


####### Images
$data = '[  {"additionalInfo": {},"copyright": "Copyright 2018 Bob","description": "Tomatoes","descriptiveOntologyTerms": [],"externalReferences": [],"imageFileName": "image_00G00231a.jpg","imageFileSize": 50000,"imageHeight": 550,"imageLocation": {  "geometry": {"coordinates": [  -76.506042,  42.417373,  9],"type": "Point"  },  "type": "Feature"},"imageName": "Tomato Imag-10","imageTimeStamp": "2020-06-17T16:20:00.217Z","imageURL": "https://breedbase.org/images/tomato","imageWidth": 700,"mimeType": "image/jpeg","observationDbIds": [],"observationUnitDbId": "38842"  }]';

$mech->post('http://localhost:3010/brapi/v2/images', Content => $data);

$response = decode_json $mech->content;
#print STDERR "\n\n" . Dumper $response;
is_deeply($response->{metadata}, {'status' => [{'message' => 'BrAPI base call found with page=0, pageSize=10','messageType' => 'INFO'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::Images'},{'message' => 'Image metadata stored','messageType' => 'INFO'}],'datafiles' => undef,'pagination' => {'pageSize' => 10,'totalPages' => 1,'currentPage' => 0,'totalCount' => 1}});

$data = '{  "additionalInfo": {},  "copyright": "Copyright 2019 Bob",  "description": "picture of a tomato",  "descriptiveOntologyTerms": [],  "externalReferences": [],  "imageFileName": "image_0AA0231.jpg",  "imageFileSize": 50000,  "imageHeight": 550,  "imageLocation": {"geometry": {  "coordinates": [-76.506042,42.417373,123  ],  "type": "Point"},"type": "Feature"  },  "imageName": "Tomato Image-x1",  "imageTimeStamp": "2020-06-17T16:08:42.015Z",  "imageURL": "https://breedbase.org/images/tomato",  "imageWidth": 700,  "mimeType": "image/jpeg",  "observationDbIds": [],  "observationUnitDbId": "38843"}';

my $dbh = SGN::Test::Fixture->new()->dbh();

my $sth = $dbh->prepare('SELECT image_id FROM metadata.md_image WHERE name = ?');
$sth->execute('Tomato Imag-10');
my ($image_id) = $sth->fetchrow_array();

$sth->finish;
$dbh->disconnect;

if (defined $image_id) {
    print "Image ID: $image_id\n";
} else {
    die "Image ID not found for image name 'image_0AA0231.jpg'.\n";
}

$resp = $ua->put("http://localhost:3010/brapi/v2/images/$image_id", Content => $data);
$response = decode_json $resp->{_content};
#print STDERR "\n\n" . Dumper$response;
is_deeply($response->{result}->{observationUnitDbId} , '38843');
my $image_timestamp = $response->{result}->{imageTimeStamp} ;

$mech->get_ok('http://localhost:3010/brapi/v2/images');
$response = decode_json $mech->content;
#print STDERR "\n\n" . Dumper$response;
is_deeply($response, {'result' => {'data' => [{'descriptiveOntologyTerms' => [],'imageWidth' => undef,'imageLocation' => undef,'imageFileName' => 'image_0AA0231.jpg','imageFileSize' => undef,'imageURL' => 'http://localhost:3010/data/images/image_files/XX/XX/XX/XX/XXXXXXXXXXXXXXXXXXXXXXXX/medium.jpg','description' => 'picture of a tomato','copyright' => 'janedoe '.DateTime->now->year,'imageDbId' => "$image_id",'imageTimeStamp' => $image_timestamp,'mimeType' => 'image/jpeg','additionalInfo' => {'observationLevel' => 'accession','tags' => [],'observationUnitName' => 'test_accession4'},'imageHeight' => undef,'observationUnitDbId' => '38843','observationDbIds' => [],'imageName' => 'Tomato Image-x1','externalReferences' => []}]},'metadata' => {'datafiles' => [],'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'message' => 'Loading CXGN::BrAPI::v2::Images','messageType' => 'INFO'},{'messageType' => 'INFO','message' => 'Image search result constructed'}],'pagination' => {'currentPage' => 0,'totalCount' => 1,'totalPages' => 1,'pageSize' => 10}}} );

####### ObsverationUnits
# Test OU plant creation
$data = '[{"germplasmDbId":"41281","locationDbId":"23","observationUnitName":"Testing Plant","programDbId":"134","studyDbId":"165","trialDbId":"165","observationUnitPosition":{"observationLevel":{"levelName":"plant","levelCode":"plant_1"},"observationLevelRelationships":[{"levelCode":"' . $stock_id. '","levelName":"plot"}],"positionCoordinateX":"74","positionCoordinateXType":"GRID_COL","positionCoordinateY":"03","positionCoordinateYType":"GRID_ROW"}, "additionalInfo" : {"observationUnitParent":"' . $stock_id. '"} }]';
$mech->post('http://localhost:3010/brapi/v2/observationunits/', Content => $data);
$response = decode_json $mech->content;
#print STDERR "\n\n Observation Unit Response is : " . $stock_id . Dumper($response);

my $rs = $f->bcs_schema()->resultset('Stock::Stock')->search( undef, { columns => [ { stock_id => { max => "stock_id" }} ]} );
my $row = $rs->next();

my $plant_id = $row->stock_id();
my $expected = {'metadata' => {'pagination' => {'currentPage' => 0,'totalPages' => 1,'pageSize' => 1,'totalCount' => 1},'status' => [{'message' => 'BrAPI base call found with page=0, pageSize=10','messageType' => 'INFO'},{'message' => 'Loading CXGN::BrAPI::v2::ObservationUnits','messageType' => 'INFO'},{'messageType' => 'INFO','message' => 'Observation Units search result constructed'}],'datafiles' => []},'result' => {'data' => [ { 'observationUnitDbId' => $plant_id, 'germplasmDbId' => '41281','crossDbId'=>undef,'crossName'=>undef,'germplasmName' => 'IITA-TMS-IBA011412', 'observationUnitPUI' => 'http://localhost:3010/stock/'. $plant_id .'/view', 'externalReferences' => [], 'trialDbId' => '165', 'studyName' => 'CASS_6Genotypes_Sampling_2015', 'observations' => [], 'seedLotName' => undef, 'observationUnitPosition' => { 'positionCoordinateYType' => 'GRID_ROW', 'positionCoordinateX' => 74, 'geoCoordinates' => undef, 'observationLevel' => { 'levelName' => 'plant', 'levelOrder' => 4, 'levelCode' => '1' }, 'entryType' => 'test', 'positionCoordinateXType' => 'GRID_COL', 'observationLevelRelationships' => [ { 'levelCode' => '1', 'levelName' => 'rep', 'levelOrder' => 0 }, { 'levelName' => 'block', 'levelOrder' => 1, 'levelCode' => '1' }, { 'levelCode' => '10', 'levelName' => 'plot', 'levelOrder' => 2 }, { 'levelName' => 'plant', 'levelOrder' => 4, 'levelCode' => '1' } ], 'positionCoordinateY' => 3 }, 'programName' => 'test', 'trialName' => 'CASS_6Genotypes_Sampling_2015', 'seedLotDbId' => undef, 'programDbId' => '134', 'studyDbId' => '165', 'locationName' => 'test_location', 'treatments' => [ { 'factor' => 'No ManagementFactor', 'modality' => undef } ], 'plotImageDbIds' => [], 'observationUnitName' => 'Testing Plant', 'locationDbId' => '23', 'additionalInfo' => { 'observationUnitParent' => $stock_id } } ]}};

#print STDERR "\n\n Observation Unit Expected is :  " . Dumper($expected);
is_deeply($response, $expected, "POST observationunits test" );


#Test observationunits put
$data = '{ "'.$stock_id.'":  { "observationUnitName":"Testing Plot", "studyDbId": "165","studyName": "CASS_6Genotypes_Sampling_2015", "germplasmDbId": "41281", "germplasmName": "IITA-TMS-IBA011412", "externalReferences" :[], "observationUnitPosition": {"entryType": "TEST", "geoCoordinates": { "geometry": { "coordinates": [ -76.506042, 42.417373, 10 ], "type": "Point" }, "type": "Feature" }, "observationLevel": { "levelName": "plot", "levelOrder": 2, "levelCode": "Plot_123" }, "observationLevelRelationships": [ { "levelCode": "Rep_1", "levelName": "rep", "levelOrder": 0 }, { "levelCode": "Block_12", "levelName": "block", "levelOrder": 1 }, { "levelCode": "Plot_123", "levelName": "plot", "levelOrder": 2 } ], "positionCoordinateX": "74", "positionCoordinateXType": "GRID_COL", "positionCoordinateY": "03", "positionCoordinateYType": "GRID_ROW" }} }';

$resp = $ua->put("http://localhost:3010/brapi/v2/observationunits/", Content => $data);
$response = decode_json $resp->{_content};
is_deeply($response, {'metadata' => {'pagination' => {'totalCount' => 1,'currentPage' => 0,'pageSize' => 10,'totalPages' => 1},'datafiles' => [],'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'message' => 'Loading CXGN::BrAPI::v2::ObservationUnits','messageType' => 'INFO'},{'message' => 'Observation Units search result constructed','messageType' => 'INFO'}]},'result' => {'data' => [{'observationUnitDbId' => $stock_id, 'observationUnitPUI' => 'http://localhost:3010/stock/'. $stock_id .'/view', 'locationDbId' => '23','programDbId' => '134','observationUnitName' => 'Testing Plot','locationName' => 'test_location','trialDbId' => '165','studyDbId' => '165','germplasmDbId' => '41281','crossDbId'=>undef,'crossName'=>undef,'observationUnitPosition' => {'positionCoordinateYType' => 'GRID_ROW','observationLevel' => {'levelOrder' => 2,'levelCode' => 'Plot_123','levelName' => 'plot'},'positionCoordinateY' => 3,'observationLevelRelationships' => [{'levelName' => 'rep','levelCode' => 'Rep_1','levelOrder' => 0}, {'levelCode' => 'Block_12','levelOrder' => 1,'levelName' =>'block'},{'levelCode' => 'Plot_123','levelOrder' => 2,'levelName' => 'plot'}],'positionCoordinateX' => 74,'entryType' => 'test','positionCoordinateXType' => 'GRID_COL','geoCoordinates' => {'type' => 'Feature','geometry' => {'coordinates' => ['-76.506042','42.417373',10],'type' => 'Point'}}},'trialName' => 'CASS_6Genotypes_Sampling_2015','studyName' => 'CASS_6Genotypes_Sampling_2015','germplasmName' => 'IITA-TMS-IBA011412','programName' => 'test','treatments' => [{'factor' => 'No ManagementFactor','modality' => undef}],'externalReferences' => [],'observations' => [],'additionalInfo' =>  {'field' => 'Field2'},'seedLotDbId' => undef, 'seedLotName' => undef,'plotImageDbIds' => []}]}}, "observationunits put test");

#
$mech->post_ok('http://localhost:3010/brapi/v2/search/observationunits', ['observationUnitDbIds'=>['41300','41301']]);
$response = decode_json $mech->content;
$searchId = $response->{result} ->{searchResultsDbId};
$mech->get_ok('http://localhost:3010/brapi/v2/search/observationunits/'. $searchId);
$response = decode_json $mech->content;
#print STDERR "\n\n" . Dumper $response;
is_deeply($response,  {'metadata' => {'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'message' => 'Loading CXGN::BrAPI::v2::Results','messageType' => 'INFO'},{'message' => 'search result constructed','messageType' => 'INFO'}],'pagination' => {'totalPages' => 1,'totalCount' => 2,'currentPage' => 0,'pageSize' => 10},'datafiles' => []},'result' => {'data' => [{'additionalInfo' => undef,'observationUnitName' => 'CASS_6Genotypes_202', 'seedLotDbId' => undef, 'seedLotName' => undef , 'locationDbId' => '23','trialDbId' => '165','germplasmName' => 'TMEB693','observationUnitDbId' => '41300','observationUnitPUI' => 'http://localhost:3010/stock/41300/view', 'studyDbId' => '165','externalReferences' => [],'programDbId' => '134','observations' => [],'plotImageDbIds' => [], 'germplasmDbId' => '41280','crossDbId'=>undef,'crossName'=>undef,'programName' => 'test','observationUnitPosition' => {'positionCoordinateY' => undef,'positionCoordinateXType' => 'GRID_COL','positionCoordinateYType' => 'GRID_ROW','positionCoordinateX' => undef,'geoCoordinates' => undef,'entryType' => 'test','observationLevelRelationships' => [{'levelCode' => '1','levelOrder' => 0,'levelName' => 'rep'},{'levelCode' => '2','levelName' => 'block','levelOrder' => 1},{'levelCode' => '202','levelOrder' => 2,'levelName' => 'plot'}],'observationLevel' => {'levelName' => 'plot','levelOrder' => 2,'levelCode' => '202'}},'treatments' => [{'factor' => 'No ManagementFactor','modality' => undef}],'locationName' => 'test_location','trialName' => 'CASS_6Genotypes_Sampling_2015','studyName' => 'CASS_6Genotypes_Sampling_2015'},{'studyName' => 'CASS_6Genotypes_Sampling_2015','treatments' => [{'factor' => 'No ManagementFactor','modality' => undef}],'locationName' => 'test_location','trialName' => 'CASS_6Genotypes_Sampling_2015','observations' => [],'seedLotDbId' => undef, 'seedLotName' => undef , 'germplasmDbId' => '41282','crossDbId'=>undef,'crossName'=>undef,'programName' => 'test','observationUnitPosition' => {'observationLevel' => {'levelCode' => '203','levelName' => 'plot','levelOrder' => 2},'observationLevelRelationships' => [{'levelCode' => '1','levelOrder' => 0,'levelName' => 'rep'},{'levelOrder' => 1,'levelName' => 'block','levelCode' => '2'},{'levelCode' => '203','levelOrder' => 2,'levelName' => 'plot'}],'positionCoordinateXType' => 'GRID_COL','positionCoordinateY' => undef,'entryType' => 'test','geoCoordinates' => undef,'positionCoordinateYType' => 'GRID_ROW','positionCoordinateX' => undef},'programDbId' => '134','observationUnitDbId' => '41301','observationUnitPUI' => 'http://localhost:3010/stock/41301/view','studyDbId' => '165','externalReferences' => [],'locationDbId' => '23','trialDbId' => '165','germplasmName' => 'IITA-TMS-IBA980002','plotImageDbIds' => [], 'additionalInfo' => undef,'observationUnitName' => 'CASS_6Genotypes_203'}]}});



$data = '{ "additionalInfo": { "control": 1 }, "germplasmDbId": "41280", "germplasmName": "TMEB693", "locationDbId": "23", "locationName": "test_location", "observationUnitName": "CASS_6Genotypes_202", "observationUnitPUI": "10", "programDbId": "134", "programName": "test", "seedLotDbId": "", "studyDbId": "165", "studyName": "CASS_6Genotypes_Sampling_2015", "treatments": [], "trialDbId": "165", "trialName": "", "observationUnitPosition": {"entryType": "test", "geoCoordinates": { "geometry": { "coordinates": [   -76.506042,   42.417373,   157 ], "type": "Point" }, "type": "Feature" }, "observationLevel": { "levelName": "plot", "levelOrder": 2, "levelCode": "10" }, "observationLevelRelationships": [ { "levelCode": "Rep_2", "levelName": "rep", "levelOrder": 0 }, { "levelCode": "Block_12", "levelName": "block", "levelOrder": 1 }, { "levelCode": "10", "levelName": "plot", "levelOrder": 2 } ], "positionCoordinateX": "75", "positionCoordinateXType": "GRID_COL", "positionCoordinateY": "30", "positionCoordinateYType": "GRID_ROW" }, "externalReferences": [{ "referenceID": "doi:10.155454/12341234", "referenceSource": "DOI" }] }';
$resp = $ua->put("http://localhost:3010/brapi/v2/observationunits/41300", Content => $data);
$response = decode_json $resp->{_content};
#print STDERR "\n\n Observation Unit Response is : " . Dumper $response;
my $expected = {'metadata' => {'pagination' => {'totalCount' => 1,'pageSize' => 10,'currentPage' => 0,'totalPages' => 1},'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'message' => 'Loading CXGN::BrAPI::v2::ObservationUnits','messageType' => 'INFO'},{'messageType' => 'INFO','message' => 'Observation Units search result constructed'}],'datafiles' => []},'result' => {'data' => [{'treatments' => [{'factor' => 'No ManagementFactor','modality' => undef}],'studyName' => 'CASS_6Genotypes_Sampling_2015','trialName' => 'CASS_6Genotypes_Sampling_2015','plotImageDbIds' => [],'observationUnitPosition' => {'observationLevel' => {'levelCode' => '10','levelName' => 'plot','levelOrder' => 2},'positionCoordinateX' => 75,'entryType' => 'test','positionCoordinateY' => 30,'geoCoordinates' => {'geometry' => {'coordinates' => ['-76.506042','42.417373',157],'type' => 'Point'},'type' => 'Feature'},'positionCoordinateXType' => 'GRID_COL','observationLevelRelationships' => [{'levelName' => 'rep','levelCode' => 'Rep_2','levelOrder' => 0}, {'levelOrder' => 1,'levelCode' => 'Block_12','levelName' => 'block'},{'levelCode' => '10','levelName' => 'plot','levelOrder' => 2}],'positionCoordinateYType' => 'GRID_ROW'},'locationDbId' => '23','seedLotDbId' => undef,'studyDbId' => '165','observationUnitPUI' => 'http://localhost:3010/stock/41300/view','additionalInfo' => undef,'externalReferences' => [{ 'referenceId'=> 'doi:10.155454/12341234', 'referenceSource'=> 'DOI' }],'observations' => [],'programName' => 'test','trialDbId' => '165','germplasmName' => 'TMEB693','germplasmDbId' => '41280','crossDbId'=>undef,'crossName'=>undef,'programDbId' => '134','locationName' => 'test_location','seedLotName' => undef,'observationUnitName' => 'CASS_6Genotypes_202','observationUnitDbId' => '41300'}]}};

#print STDERR "\n\n Observation Unit Expected is :  " . Dumper($expected);
is_deeply($response,  $expected, "PUT OU 41300 test" );
print STDERR "\n\n   DONE with phenotyping tests.\n\n";


####### NIRS Tests

# NIRS upload validation
for my $extension ("xls", "xlsx") {

    my $schema = $f->bcs_schema;
    my $dbh = $schema->storage->dbh;
    my $people_schema = $f->people_schema;

    my $mech = Test::WWW::Mechanize->new;

    $mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username" => "janedoe", "password" => "secretpw", "grant_type" => "password" ]);
    my $response = decode_json $mech->content;
    print STDERR Dumper $response;
    is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
    my $sgn_session_id = $response->{access_token};
    print STDERR $sgn_session_id . "\n";

    my $location_rs = $schema->resultset('NaturalDiversity::NdGeolocation')->search({ description => 'Cornell Biotech' });
    my $location_id = $location_rs->first->nd_geolocation_id;

    my $bp_rs = $schema->resultset('Project::Project')->search({ name => 'test' });
    my $breeding_program_id = $bp_rs->first->project_id;

    my $tn = CXGN::Trial->new({ bcs_schema => $f->bcs_schema(), trial_id => 137 });
    $tn->create_plant_entities(2);

    my $parser = CXGN::Phenotypes::ParseUpload->new();
    my $filename = "t/data/trial/upload_phenotypin_spreadsheet_large.$extension";
    my $parsed_file = $parser->parse('phenotype spreadsheet', $filename, 0, 'plots', $f->bcs_schema);
    ok($parsed_file, "Check if parse parse phenotype spreadsheet works");

    my %phenotype_metadata;
    $phenotype_metadata{'archived_file'} = $filename;
    $phenotype_metadata{'archived_file_type'} = "spreadsheet phenotype file";
    $phenotype_metadata{'operator'} = "janedoe";
    $phenotype_metadata{'date'} = "2016-02-17_05:15:21";
    my %parsed_data = %{$parsed_file->{'data'}};
    my @plots = @{$parsed_file->{'units'}};
    my @traits = @{$parsed_file->{'variables'}};

    my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
        basepath                   => $f->config->{basepath},
        dbhost                     => $f->config->{dbhost},
        dbname                     => $f->config->{dbname},
        dbuser                     => $f->config->{dbuser},
        dbpass                     => $f->config->{dbpass},
        temp_file_nd_experiment_id => $f->config->{cluster_shared_tempdir} . "/test_temp_nd_experiment_id_delete",
        bcs_schema                 => $f->bcs_schema,
        metadata_schema            => $f->metadata_schema,
        phenome_schema             => $f->phenome_schema,
        user_id                    => 41,
        stock_list                 => \@plots,
        trait_list                 => \@traits,
        values_hash                => \%parsed_data,
        has_timestamps             => 0,
        overwrite_values           => 0,
        metadata_hash              => \%phenotype_metadata,
        composable_validation_check_name => $f->config->{composable_validation_check_name}
    );
    my ($verified_warning, $verified_error) = $store_phenotypes->verify();
    ok(!$verified_error);
    my ($stored_phenotype_error_msg, $store_success) = $store_phenotypes->store();
    ok(!$stored_phenotype_error_msg, "check that store large pheno spreadsheet works");

    print STDERR "Uploading NIRS\n";

    my $file = $f->config->{basepath} . "/t/data/NIRS/C16Mval_spectra.csv";

    my $ua = LWP::UserAgent->new;
    $response = $ua->post(
        'http://localhost:3010/ajax/highdimensionalphenotypes/nirs_upload_verify',
        Content_Type => 'form-data',
        Content      => [
            upload_nirs_spreadsheet_file_input             => [ $file, 'nirs_data_upload' ],
            "sgn_session_id"                               => $sgn_session_id,
            "upload_nirs_spreadsheet_data_level"           => "plants",
            "upload_nirs_spreadsheet_protocol_name"        => "NIRS SCIO Protocol 2",
            "upload_nirs_spreadsheet_protocol_desc"        => "description",
            "upload_nirs_spreadsheet_protocol_device_type" => "SCIO"
        ]
    );

    #print STDERR Dumper $response;
    ok($response->is_success);
    my $message = $response->decoded_content;
    print STDERR Dumper $message;
    my $message_hash = decode_json $message;
    print STDERR Dumper $message_hash;
    ok($message_hash->{figure});
    is_deeply($message_hash->{success}, [ 'File nirs_data_upload saved in archive.', 'File valid: nirs_data_upload.', 'File data successfully parsed.', 'Aggregated file data successfully parsed.', 'Aggregated file data verified. Plot names and trait names are valid.' ]);

    my $ua = LWP::UserAgent->new;
    $response = $ua->post(
        'http://localhost:3010/ajax/highdimensionalphenotypes/nirs_upload_store',
        Content_Type => 'form-data',
        Content      => [
            upload_nirs_spreadsheet_file_input             => [ $file, 'nirs_data_upload' ],
            "sgn_session_id"                               => $sgn_session_id,
            "upload_nirs_spreadsheet_data_level"           => "plants",
            "upload_nirs_spreadsheet_protocol_name"        => "NIRS SCIO Protocol",
            "upload_nirs_spreadsheet_protocol_desc"        => "description",
            "upload_nirs_spreadsheet_protocol_device_type" => "SCIO"
        ]
    );

    my $message = $response->decoded_content;
    my $message_hash = decode_json $message;
    print STDERR Dumper $message_hash;
    ok($message_hash->{figure});
    is(scalar(@{$message_hash->{success}}), 8);
    is($message_hash->{success}->[6], 'All values in your file have been successfully processed!<br><br>30 new values stored<br>0 previously stored values skipped<br>0 previously stored values overwritten<br>0 previously stored values removed<br><br>');
    my $nirs_protocol_id = $message_hash->{nd_protocol_id};

    my $dry_matter_trait_id = $f->bcs_schema()->resultset("Cv::Cvterm")->find({ name => 'dry matter content percentage' })->cvterm_id();

    my $ds = CXGN::Dataset->new(people_schema => $f->people_schema(), schema => $f->bcs_schema());
    $ds->plots([
        $f->bcs_schema()->resultset("Stock::Stock")->find({ uniquename => 'test_trial21' })->stock_id(),
        $f->bcs_schema()->resultset("Stock::Stock")->find({ uniquename => 'test_trial22' })->stock_id(),
        $f->bcs_schema()->resultset("Stock::Stock")->find({ uniquename => 'test_trial23' })->stock_id(),
        $f->bcs_schema()->resultset("Stock::Stock")->find({ uniquename => 'test_trial24' })->stock_id(),
        $f->bcs_schema()->resultset("Stock::Stock")->find({ uniquename => 'test_trial25' })->stock_id(),
        $f->bcs_schema()->resultset("Stock::Stock")->find({ uniquename => 'test_trial26' })->stock_id(),
        $f->bcs_schema()->resultset("Stock::Stock")->find({ uniquename => 'test_trial27' })->stock_id(),
        $f->bcs_schema()->resultset("Stock::Stock")->find({ uniquename => 'test_trial28' })->stock_id(),
        $f->bcs_schema()->resultset("Stock::Stock")->find({ uniquename => 'test_trial29' })->stock_id(),
        $f->bcs_schema()->resultset("Stock::Stock")->find({ uniquename => 'test_trial210' })->stock_id(),
        $f->bcs_schema()->resultset("Stock::Stock")->find({ uniquename => 'test_trial211' })->stock_id()
    ]);
    $ds->traits([
        $dry_matter_trait_id
    ]);
    $ds->name("nirs_dataset_test");
    $ds->description("test nirs description");
    $ds->sp_person_id(41);
    my $sp_dataset_id = $ds->store();

    # GET /brapi/v2/nirs/{protocolId}
    $mech->get_ok("http://localhost:3010/brapi/v2/nirs/$nirs_protocol_id");
    $response = decode_json $mech->content;
    #print STDERR Dumper($response);

    my $expected = {
      'result' => {
        'data' => [
          {
            'header_column_names' => ['1000','1001','1002','1003','1004','1005','1006','1007','1008','1009','1010','1011','1012','1013','1014','1015','1016','1017','1018','1019','1020','1021','1022','1023','1024','1025','1026','1027','1028','1029','1030','1031','1032','1033','1034','1035','1036','1037','1038','1039','1040','1041','1042','1043','1044','1045','1046','1047','1048','1049','1050','1051','1052','1053','1054','1055','1056','1057','1058','1059','1060','1061','1062','1063','1064','1065','1066','1067','1068','1069','1070','1071','1072','1073','1074','1075','1076','1077','1078','1079','1080','1081','1082','1083','1084','1085','1086','1087','1088','1089','1090','1091','1092','1093','1094','1095','1096','1097','1098','1099','1100','1101','1102','1103','1104','1105','1106','1107','1108','1109','1110','1111','1112','1113','1114','1115','1116','1117','1118','1119','1120','1121','1122','1123','1124','1125','1126','1127','1128','1129','1130','1131','1132','1133','1134','1135','1136','1137','1138','1139','1140','1141','1142','1143','1144','1145','1146','1147','1148','1149','1150','1151','1152','1153','1154','1155','1156','1157','1158','1159','1160','1161','1162','1163','1164','1165','1166','1167','1168','1169','1170','1171','1172','1173','1174','1175','1176','1177','1178','1179','1180','1181','1182','1183','1184','1185','1186','1187','1188','1189','1190','1191','1192','1193','1194','1195','1196','1197','1198','1199','1200','1201','1202','1203','1204','1205','1206','1207','1208','1209','1210','1211','1212','1213','1214','1215','1216','1217','1218','1219','1220','1221','1222','1223','1224','1225','1226','1227','1228','1229','1230','1231','1232','1233','1234','1235','1236','1237','1238','1239','1240','1241','1242','1243','1244','1245','1246','1247','1248','1249','1250','1251','1252','1253','1254','1255','1256','1257','1258','1259','1260','1261','1262','1263','1264','1265','1266','1267','1268','1269','1270','1271','1272','1273','1274','1275','1276','1277','1278','1279','1280','1281','1282','1283','1284','1285','1286','1287','1288','1289','1290','1291','1292','1293','1294','1295','1296','1297','1298','1299','1300','1301','1302','1303','1304','1305','1306','1307','1308','1309','1310','1311','1312','1313','1314','1315','1316','1317','1318','1319','1320','1321','1322','1323','1324','1325','1326','1327','1328','1329','1330','1331','1332','1333','1334','1335','1336','1337','1338','1339','1340','1341','1342','1343','1344','1345','1346','1347','1348','1349','1350','1351','1352','1353','1354','1355','1356','1357','1358','1359','1360','1361','1362','1363','1364','1365','1366','1367','1368','1369','350','351','352','353','354','355','356','357','358','359','360','361','362','363','364','365','366','367','368','369','370','371','372','373','374','375','376','377','378','379','380','381','382','383','384','385','386','387','388','389','390','391','392','393','394','395','396','397','398','399','400','401','402','403','404','405','406','407','408','409','410','411','412','413','414','415','416','417','418','419','420','421','422','423','424','425','426','427','428','429','430','431','432','433','434','435','436','437','438','439','440','441','442','443','444','445','446','447','448','449','450','451','452','453','454','455','456','457','458','459','460','461','462','463','464','465','466','467','468','469','470','471','472','473','474','475','476','477','478','479','480','481','482','483','484','485','486','487','488','489','490','491','492','493','494','495','496','497','498','499','500','501','502','503','504','505','506','507','508','509','510','511','512','513','514','515','516','517','518','519','520','521','522','523','524','525','526','527','528','529','530','531','532','533','534','535','536','537','538','539','540','541','542','543','544','545','546','547','548','549','550','551','552','553','554','555','556','557','558','559','560','561','562','563','564','565','566','567','568','569','570','571','572','573','574','575','576','577','578','579','580','581','582','583','584','585','586','587','588','589','590','591','592','593','594','595','596','597','598','599','600','601','602','603','604','605','606','607','608','609','610','611','612','613','614','615','616','617','618','619','620','621','622','623','624','625','626','627','628','629','630','631','632','633','634','635','636','637','638','639','640','641','642','643','644','645','646','647','648','649','650','651','652','653','654','655','656','657','658','659','660','661','662','663','664','665','666','667','668','669','670','671','672','673','674','675','676','677','678','679','680','681','682','683','684','685','686','687','688','689','690','691','692','693','694','695','696','697','698','699','700','701','702','703','704','705','706','707','708','709','710','711','712','713','714','715','716','717','718','719','720','721','722','723','724','725','726','727','728','729','730','731','732','733','734','735','736','737','738','739','740','741','742','743','744','745','746','747','748','749','750','751','752','753','754','755','756','757','758','759','760','761','762','763','764','765','766','767','768','769','770','771','772','773','774','775','776','777','778','779','780','781','782','783','784','785','786','787','788','789','790','791','792','793','794','795','796','797','798','799','800','801','802','803','804','805','806','807','808','809','810','811','812','813','814','815','816','817','818','819','820','821','822','823','824','825','826','827','828','829','830','831','832','833','834','835','836','837','838','839','840','841','842','843','844','845','846','847','848','849','850','851','852','853','854','855','856','857','858','859','860','861','862','863','864','865','866','867','868','869','870','871','872','873','874','875','876','877','878','879','880','881','882','883','884','885','886','887','888','889','890','891','892','893','894','895','896','897','898','899','900','901','902','903','904','905','906','907','908','909','910','911','912','913','914','915','916','917','918','919','920','921','922','923','924','925','926','927','928','929','930','931','932','933','934','935','936','937','938','939','940','941','942','943','944','945','946','947','948','949','950','951','952','953','954','955','956','957','958','959','960','961','962','963','964','965','966','967','968','969','970','971','972','973','974','975','976','977','978','979','980','981', '982', '983', '984', '985', '986', '987', '988', '989', '990', '991', '992', '993', '994', '995', '996', '997', '998', '999'],
            'device_type' => 'SCIO'
          }
        ]
      },
      'metadata' => {
        'pagination' => {
          'totalCount' => 1,
          'pageSize' => 10,
          'totalPages' => 1,
          'currentPage' => 0
        },
        'datafiles' => [],
        'status' => [
          {
            'messageType' => 'INFO',
            'message' => 'BrAPI base call found with page=0, pageSize=10'
          },
          {
            'messageType' => 'INFO',
            'message' => 'Loading CXGN::BrAPI::v2::Nirs'
          },
          {
            'messageType' => 'INFO',
            'message' => 'Nirs detail result constructed'
          }
        ]
      }
    };

    is_deeply($response, $expected, "GET NIRS protocol test");

    $f->clean_up_db();
}

$f->clean_up_db();

done_testing();
