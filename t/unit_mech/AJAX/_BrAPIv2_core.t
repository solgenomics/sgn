
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use LWP::UserAgent;
use Math::Round qw | round |;

#Needed to update IO::Socket::SSL
use Data::Dumper;
use JSON;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new(); # calculate db stats

my $mech = Test::WWW::Mechanize->new;
my $ua   = LWP::UserAgent->new;
my $response; my $searchId; my $resp; my $data;

$mech->post_ok('http://localhost:3010/brapi/v2/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
$response = decode_json $mech->content;
print STDERR "\n\n" . Dumper $response;
#1
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
#2
is($response->{'userDisplayName'}, 'Jane Doe');
#3
is($response->{'expires_in'}, '7200');

$mech->delete_ok('http://localhost:3010/brapi/v2/token');
$response = decode_json $mech->content;
print STDERR "\n\nLogin response " . Dumper $response;
#4
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'User Logged Out');

$mech->post_ok('http://localhost:3010/brapi/v2/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
$response = decode_json $mech->content;
print STDERR "\n\n" . Dumper $response;
#5
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
#6
is($response->{'userDisplayName'}, 'Jane Doe');
#7
is($response->{'expires_in'}, '7200', 'check expiry time in seconds');
my $access_token = $response->{access_token};

$ua->default_header("Content-Type" => "application/json");
$ua->default_header('Authorization'=> 'Bearer ' . $access_token);
$mech->default_header("Content-Type" => "application/json");
$mech->default_header('Authorization'=> 'Bearer ' . $access_token);


$mech->get_ok('http://localhost:3010/brapi/v2/serverinfo');
$response = decode_json $mech->content;
print STDERR "\n\nserverinfo response" . Dumper $response;
#8
is_deeply($response, {'result' => {'serverName' => 'breeDBase','documentationURL' => 'https://solgenomics.github.io/sgn/','serverDescription' => 'BrAPI v2.0 compliant server','location' => 'USA','contactEmail' => 'lam87@cornell.edu','calls' => [{'dataTypes' => ['application/json'],'service' => 'serverinfo','methods' => ['GET'],'versions' => ['2.0'],'contentTypes' => ['application/json']},{'versions' => ['2.0'],'contentTypes' => ['application/json'],'methods' => ['GET'],'dataTypes' => ['application/json'],'service' => 'commoncropnames'},{'contentTypes' => ['application/json'],'versions' => ['2.0'],'methods' => ['GET','POST'],'dataTypes' => ['application/json'],'service' => 'lists'},{'methods' => ['GET','PUT'],'versions' => ['2.0'],'contentTypes' => ['application/json'],'dataTypes' => ['application/json'],'service' => 'lists/{listDbId}'},{'dataTypes' => ['application/json'],'service' => 'lists/{listDbId}/items','contentTypes' => ['application/json'],'methods' => ['POST'],'versions' => ['2.0']},{'dataTypes' => ['application/json'],'service' => 'search/lists','versions' => ['2.0'],'contentTypes' => ['application/json'],'methods' => ['POST']},{'service' => 'search/lists/{searchResultsDbId}','dataTypes' => ['application/json'],'versions' => ['2.0'],'methods' => ['GET'],'contentTypes' => ['application/json']},{'service' => 'locations','dataTypes' => ['application/json'],'contentTypes' => ['application/json'],'methods' => ['GET','POST'],'versions' => ['2.0']},{'methods' => ['GET','PUT'],'contentTypes' => ['application/json'],'versions' => ['2.0'],'dataTypes' => ['application/json'],'service' => 'locations/{locationDbId}'},{'service' => 'search/locations','dataTypes' => ['application/json'],'methods' => ['POST'],'contentTypes' => ['application/json'],'versions' => ['2.0']},{'service' => 'search/locations/{searchResultsDbId}','dataTypes' => ['application/json'],'methods' => ['GET'],'contentTypes' => ['application/json'],'versions' => ['2.0']},{'contentTypes' => ['application/json'],'versions' => ['2.0'],'methods' => ['GET'],'dataTypes' => ['application/json'],'service' => 'people'},{'versions' => ['2.0'],'methods' => ['GET'],'contentTypes' => ['application/json'],'service' => 'people/{peopleDbId}','dataTypes' => ['application/json']},{'versions' => ['2.0'],'methods' => ['POST'],'contentTypes' => ['application/json'],'service' => 'search/people','dataTypes' => ['application/json']},{'service' => 'search/people/{searchResultsDbId}','dataTypes' => ['application/json'],'contentTypes' => ['application/json'],'versions' => ['2.0'],'methods' => ['GET']},{'service' => 'programs','dataTypes' => ['application/json'],'methods' => ['GET','POST'],'versions' => ['2.0'],'contentTypes' => ['application/json']},{'dataTypes' => ['application/json'],'service' => 'programs/{programDbId}','contentTypes' => ['application/json'],'methods' => ['GET','PUT'],'versions' => ['2.0']},{'dataTypes' => ['application/json'],'service' => 'search/programs','methods' => ['POST'],'versions' => ['2.0'],'contentTypes' => ['application/json']},{'service' => 'search/programs/{searchResultsDbId}','dataTypes' => ['application/json'],'versions' => ['2.0'],'contentTypes' => ['application/json'],'methods' => ['GET']},{'dataTypes' => ['application/json'],'service' => 'seasons','contentTypes' => ['application/json'],'methods' => ['GET'],'versions' => ['2.0']},{'versions' => ['2.0'],'methods' => ['GET'],'contentTypes' => ['application/json'],'dataTypes' => ['application/json'],'service' => 'seasons/{seasonDbId}'},{'versions' => ['2.0'],'methods' => ['POST'],'contentTypes' => ['application/json'],'dataTypes' => ['application/json'],'service' => 'search/seasons'},{'versions' => ['2.0'],'methods' => ['GET'],'contentTypes' => ['application/json'],'dataTypes' => ['application/json'],'service' => 'search/seasons/{searchResultsDbId}'},{'contentTypes' => ['application/json'],'methods' => ['GET','POST'],'versions' => ['2.0'],'service' => 'studies','dataTypes' => ['application/json']},{'methods' => ['GET','PUT'],'contentTypes' => ['application/json'],'versions' => ['2.0'],'dataTypes' => ['application/json'],'service' => 'studies/{studyDbId}'},{'dataTypes' => ['application/json'],'service' => 'search/studies','versions' => ['2.0'],'methods' => ['POST'],'contentTypes' => ['application/json']},{'service' => 'search/studies/{searchResultsDbId}','dataTypes' => ['application/json'],'versions' => ['2.0'],'contentTypes' => ['application/json'],'methods' => ['GET']},{'methods' => ['GET'],'contentTypes' => ['application/json'],'versions' => ['2.0'],'service' => 'studytypes','dataTypes' => ['application/json']},{'contentTypes' => ['application/json'],'methods' => ['GET','POST'],'versions' => ['2.0'],'dataTypes' => ['application/json'],'service' => 'trials'},{'dataTypes' => ['application/json'],'service' => 'trials/{trialDbId}','methods' => ['GET','PUT'],'versions' => ['2.0'],'contentTypes' => ['application/json']},{'methods' => ['POST'],'versions' => ['2.0'],'contentTypes' => ['application/json'],'service' => 'search/trials','dataTypes' => ['application/json']},{'contentTypes' => ['application/json'],'versions' => ['2.0'],'methods' => ['GET'],'dataTypes' => ['application/json'],'service' => 'search/trials/{searchResultsDbId}'},{'contentTypes' => ['application/json'],'methods' => ['GET','POST'],'versions' => ['2.0','2.1'],'dataTypes' => ['application/json'],'service' => 'images'},{'service' => 'images/{imageDbId}','dataTypes' => ['application/json'],'versions' => ['2.0','2.1'],'contentTypes' => ['application/json'],'methods' => ['GET','PUT']},{'methods' => ['PUT'],'contentTypes' => ['application/json'],'versions' => ['2.0','2.1'],'service' => 'images/{imageDbId}/imagecontent','dataTypes' => ['application/json']},{'service' => 'search/images','dataTypes' => ['application/json'],'contentTypes' => ['application/json'],'methods' => ['POST'],'versions' => ['2.0','2.1']},{'dataTypes' => ['application/json'],'service' => 'search/images/{searchResultsDbId}','versions' => ['2.0','2.1'],'methods' => ['GET'],'contentTypes' => ['application/json']},{'contentTypes' => ['application/json'],'versions' => ['2.0'],'methods' => ['GET','POST','PUT'],'service' => 'observations','dataTypes' => ['application/json']},{'versions' => ['2.0'],'methods' => ['GET','PUT'],'contentTypes' => ['application/json'],'dataTypes' => ['application/json'],'service' => 'observations/{observationDbId}'},{'versions' => ['2.0'],'methods' => ['GET'],'contentTypes' => ['application/json'],'dataTypes' => ['application/json'],'service' => 'observations/table'},{'methods' => ['POST'],'contentTypes' => ['application/json'],'versions' => ['2.0'],'dataTypes' => ['application/json'],'service' => 'search/observations'},{'methods' => ['GET'],'contentTypes' => ['application/json'],'versions' => ['2.0'],'service' => 'search/observations/{searchResultsDbId}','dataTypes' => ['application/json']},{'contentTypes' => ['application/json'],'versions' => ['2.0'],'methods' => ['GET'],'service' => 'observationlevels','dataTypes' => ['application/json']},{'versions' => ['2.0'],'contentTypes' => ['application/json'],'methods' => ['GET','POST','PUT'],'dataTypes' => ['application/json'],'service' => 'observationunits'},{'methods' => ['GET','PUT'],'contentTypes' => ['application/json'],'versions' => ['2.0'],'dataTypes' => ['application/json'],'service' => 'observationunits/{observationUnitDbId}'},{'service' => 'search/observationunits','dataTypes' => ['application/json'],'versions' => ['2.0'],'methods' => ['POST'],'contentTypes' => ['application/json']},{'versions' => ['2.0'],'contentTypes' => ['application/json'],'methods' => ['GET'],'service' => 'search/observationunits/{searchResultsDbId}','dataTypes' => ['application/json']},{'contentTypes' => ['application/json'],'versions' => ['2.0'],'methods' => ['GET'],'dataTypes' => ['application/json'],'service' => 'ontologies'},{'versions' => ['2.0','2.1'],'methods' => ['GET'],'contentTypes' => ['application/json'],'service' => 'traits','dataTypes' => ['application/json']},{'methods' => ['GET'],'contentTypes' => ['application/json'],'versions' => ['2.0','2.1'],'service' => 'traits/{traitDbId}','dataTypes' => ['application/json']},{'service' => 'variables','dataTypes' => ['application/json'],'contentTypes' => ['application/json'],'versions' => ['2.0','2.1'],'methods' => ['GET']},{'dataTypes' => ['application/json'],'service' => 'variables/{observationVariableDbId}','methods' => ['GET'],'contentTypes' => ['application/json'],'versions' => ['2.0']},{'service' => 'search/variables','dataTypes' => ['application/json'],'versions' => ['2.0'],'methods' => ['POST'],'contentTypes' => ['application/json']},{'methods' => ['GET'],'contentTypes' => ['application/json'],'versions' => ['2.0'],'dataTypes' => ['application/json'],'service' => 'search/variables/{searchResultsDbId}'},{'methods' => ['GET'],'contentTypes' => ['application/json'],'versions' => ['2.0'],'dataTypes' => ['application/json'],'service' => 'events'},{'contentTypes' => ['application/json'],'methods' => ['GET'],'versions' => ['2.0'],'dataTypes' => ['application/json'],'service' => 'calls'},{'methods' => ['POST'],'contentTypes' => ['application/json'],'versions' => ['2.0'],'dataTypes' => ['application/json'],'service' => 'search/calls'},{'contentTypes' => ['application/json'],'methods' => ['GET'],'versions' => ['2.0'],'dataTypes' => ['application/json'],'service' => 'search/calls/{searchResultsDbId}'},{'contentTypes' => ['application/json'],'versions' => ['2.0'],'methods' => ['GET'],'dataTypes' => ['application/json'],'service' => 'callsets'},{'dataTypes' => ['application/json'],'service' => 'callsets/{callSetDbId}','methods' => ['GET'],'contentTypes' => ['application/json'],'versions' => ['2.0']},{'service' => 'callsets/{callSetDbId}/calls','dataTypes' => ['application/json'],'methods' => ['GET'],'versions' => ['2.0'],'contentTypes' => ['application/json']},{'dataTypes' => ['application/json'],'service' => 'search/callsets','versions' => ['2.0'],'methods' => ['POST'],'contentTypes' => ['application/json']},{'methods' => ['GET'],'versions' => ['2.0'],'contentTypes' => ['application/json'],'dataTypes' => ['application/json'],'service' => 'search/callsets/{searchResultsDbId}'},{'dataTypes' => ['application/json'],'service' => 'maps','contentTypes' => ['application/json'],'versions' => ['2.0'],'methods' => ['GET']},{'versions' => ['2.0'],'methods' => ['GET'],'contentTypes' => ['application/json'],'service' => 'maps/{mapDbId}','dataTypes' => ['application/json']},{'dataTypes' => ['application/json'],'service' => 'maps/{mapDbId}/linkagegroups','methods' => ['GET'],'contentTypes' => ['application/json'],'versions' => ['2.0']},{'dataTypes' => ['application/json'],'service' => 'markerpositions','methods' => ['GET'],'contentTypes' => ['application/json'],'versions' => ['2.0']},{'contentTypes' => ['application/json'],'methods' => ['POST'],'versions' => ['2.0'],'dataTypes' => ['application/json'],'service' => 'search/markerpositions'},{'contentTypes' => ['application/json'],'methods' => ['GET'],'versions' => ['2.0'],'service' => 'search/markerpositions/{searchResultsDbId}','dataTypes' => ['application/json']},{'service' => 'references','dataTypes' => ['application/json'],'contentTypes' => ['application/json'],'methods' => ['GET'],'versions' => ['2.0']},{'dataTypes' => ['application/json'],'service' => 'references/{referenceDbId}','methods' => ['GET'],'contentTypes' => ['application/json'],'versions' => ['2.0']},{'contentTypes' => ['application/json'],'methods' => ['POST'],'versions' => ['2.0'],'service' => 'search/references','dataTypes' => ['application/json']},{'versions' => ['2.0'],'methods' => ['GET'],'contentTypes' => ['application/json'],'dataTypes' => ['application/json'],'service' => 'search/references/{searchResultsDbId}'},{'dataTypes' => ['application/json'],'service' => 'referencesets','contentTypes' => ['application/json'],'methods' => ['GET'],'versions' => ['2.0']},{'dataTypes' => ['application/json'],'service' => 'referencesets/{referenceSetDbId}','versions' => ['2.0'],'contentTypes' => ['application/json'],'methods' => ['GET']},{'service' => 'search/referencesets','dataTypes' => ['application/json'],'versions' => ['2.0'],'methods' => ['POST'],'contentTypes' => ['application/json']},{'service' => 'search/referencesets/{searchResultsDbId}','dataTypes' => ['application/json'],'methods' => ['GET'],'contentTypes' => ['application/json'],'versions' => ['2.0']},{'contentTypes' => ['application/json'],'methods' => ['GET'],'versions' => ['2.0'],'service' => 'samples','dataTypes' => ['application/json']},{'versions' => ['2.0'],'contentTypes' => ['application/json'],'methods' => ['GET'],'dataTypes' => ['application/json'],'service' => 'samples/{sampleDbId}'},{'service' => 'search/samples','dataTypes' => ['application/json'],'methods' => ['POST'],'contentTypes' => ['application/json'],'versions' => ['2.0']},{'dataTypes' => ['application/json'],'service' => 'search/samples/{searchResultsDbId}','contentTypes' => ['application/json'],'methods' => ['GET'],'versions' => ['2.0']},{'dataTypes' => ['application/json'],'service' => 'variants','contentTypes' => ['application/json'],'methods' => ['GET'],'versions' => ['2.0']},{'service' => 'variants/{variantDbId}','dataTypes' => ['application/json'],'versions' => ['2.0'],'contentTypes' => ['application/json'],'methods' => ['GET']},{'methods' => ['GET'],'versions' => ['2.0'],'contentTypes' => ['application/json'],'service' => 'variants/{variantDbId}/calls','dataTypes' => ['application/json']},{'dataTypes' => ['application/json'],'service' => 'search/variants','versions' => ['2.0'],'methods' => ['POST'],'contentTypes' => ['application/json']},{'dataTypes' => ['application/json'],'service' => 'search/variants/{searchResultsDbId}','methods' => ['GET'],'versions' => ['2.0'],'contentTypes' => ['application/json']},{'dataTypes' => ['application/json'],'service' => 'variantsets','versions' => ['2.0'],'methods' => ['GET'],'contentTypes' => ['application/json']},{'methods' => ['GET'],'versions' => ['2.0'],'contentTypes' => ['application/json'],'service' => 'variantsets/extract','dataTypes' => ['application/json']},{'dataTypes' => ['application/json'],'service' => 'variantsets/{variantSetDbId}','methods' => ['GET'],'versions' => ['2.0'],'contentTypes' => ['application/json']},{'versions' => ['2.0'],'methods' => ['GET'],'contentTypes' => ['application/json'],'dataTypes' => ['application/json'],'service' => 'variantsets/{variantSetDbId}/calls'},{'service' => 'variantsets/{variantSetDbId}/callsets','dataTypes' => ['application/json'],'contentTypes' => ['application/json'],'versions' => ['2.0'],'methods' => ['GET']},{'versions' => ['2.0'],'methods' => ['GET'],'contentTypes' => ['application/json'],'dataTypes' => ['application/json'],'service' => 'variantsets/{variantSetDbId}/variants'},{'versions' => ['2.0'],'methods' => ['POST'],'contentTypes' => ['application/json'],'dataTypes' => ['application/json'],'service' => 'search/variantsets'},{'methods' => ['GET'],'versions' => ['2.0'],'contentTypes' => ['application/json'],'service' => 'search/variantsets/{searchResultsDbId}','dataTypes' => ['application/json']},{'service' => 'germplasm','dataTypes' => ['application/json'],'methods' => ['GET','POST'],'versions' => ['2.0'],'contentTypes' => ['application/json']},{'contentTypes' => ['application/json'],'versions' => ['2.0'],'methods' => ['GET','PUT'],'service' => 'germplasm/{germplasmDbId}','dataTypes' => ['application/json']},{'methods' => ['GET'],'versions' => ['2.0'],'contentTypes' => ['application/json'],'dataTypes' => ['application/json'],'service' => 'germplasm/{germplasmDbId}/pedigree'},{'methods' => ['GET'],'versions' => ['2.0'],'contentTypes' => ['application/json'],'service' => 'germplasm/{germplasmDbId}/progeny','dataTypes' => ['application/json']},{'service' => 'germplasm/{germplasmDbId}/mcpd','dataTypes' => ['application/json'],'methods' => ['GET'],'versions' => ['2.0'],'contentTypes' => ['application/json']},{'dataTypes' => ['application/json'],'service' => 'search/germplasm','contentTypes' => ['application/json'],'methods' => ['POST'],'versions' => ['2.0']},{'dataTypes' => ['application/json'],'service' => 'search/germplasm/{searchResultsDbId}','methods' => ['GET'],'contentTypes' => ['application/json'],'versions' => ['2.0']},{'contentTypes' => ['application/json'],'methods' => ['GET'],'versions' => ['2.0'],'service' => 'attributes','dataTypes' => ['application/json']},{'service' => 'attributes/categories','dataTypes' => ['application/json'],'versions' => ['2.0'],'methods' => ['GET'],'contentTypes' => ['application/json']},{'methods' => ['GET'],'contentTypes' => ['application/json'],'versions' => ['2.0'],'service' => 'attributes/{attributeDbId}','dataTypes' => ['application/json']},{'contentTypes' => ['application/json'],'methods' => ['POST'],'versions' => ['2.0'],'service' => 'search/attributes','dataTypes' => ['application/json']},{'versions' => ['2.0'],'methods' => ['GET'],'contentTypes' => ['application/json'],'dataTypes' => ['application/json'],'service' => 'search/attributes/{searchResultsDbId}'},{'dataTypes' => ['application/json'],'service' => 'attributevalues','contentTypes' => ['application/json'],'versions' => ['2.0'],'methods' => ['GET']},{'service' => 'attributevalues/{attributeValueDbId}','dataTypes' => ['application/json'],'contentTypes' => ['application/json'],'methods' => ['GET'],'versions' => ['2.0']},{'dataTypes' => ['application/json'],'service' => 'search/attributevalues','methods' => ['POST'],'contentTypes' => ['application/json'],'versions' => ['2.0']},{'service' => 'search/attributevalues/{searchResultsDbId}','dataTypes' => ['application/json'],'contentTypes' => ['application/json'],'versions' => ['2.0'],'methods' => ['GET']},{'contentTypes' => ['application/json'],'versions' => ['2.0'],'methods' => ['GET','POST'],'service' => 'crossingprojects','dataTypes' => ['application/json']},{'methods' => ['GET','PUT'],'versions' => ['2.0'],'contentTypes' => ['application/json'],'dataTypes' => ['application/json'],'service' => 'crossingprojects/{crossingProjectDbId}'},{'contentTypes' => ['application/json'],'methods' => ['GET','POST'],'versions' => ['2.0'],'service' => 'crosses','dataTypes' => ['application/json']},{'dataTypes' => ['application/json'],'service' => 'seedlots','contentTypes' => ['application/json'],'methods' => ['GET','POST'],'versions' => ['2.0','2.1']},{'dataTypes' => ['application/json'],'service' => 'seedlots/transactions','versions' => ['2.0'],'contentTypes' => ['application/json'],'methods' => ['GET','POST']},{'contentTypes' => ['application/json'],'methods' => ['GET','PUT'],'versions' => ['2.0'],'dataTypes' => ['application/json'],'service' => 'seedlots/{seedLotDbId}'},{'methods' => ['GET'],'versions' => ['2.0'],'contentTypes' => ['application/json'],'service' => 'seedlots/{seedLotDbId}/transactions','dataTypes' => ['application/json']},{'dataTypes' => ['application/json'],'service' => 'pedigree','contentTypes' => ['application/json'],'methods' => ['GET'],'versions' => ['2.1']}],'organizationName' => 'Boyce Thompson Institute','organizationURL' => 'http://localhost:3010/'},'metadata' => {'pagination' => {'totalPages' => 1,'pageSize' => 1000,'totalCount' => 118,'currentPage' => 0},'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::ServerInfo'},{'messageType' => 'INFO','message' => 'Calls result constructed'}],'datafiles' => []}});



$mech->get_ok('http://localhost:3010/brapi/v2/programs', "get all brapi v2 programs call test");
$response = decode_json $mech->content;
print STDERR "\n\n" . Dumper $response;
is_deeply($response, {'metadata' => {'datafiles' => [],'pagination' => {'totalCount' => 1,'totalPages' => 1,'pageSize' => 10,'currentPage' => 0},'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::Programs'},{'message' => 'Program list result constructed','messageType' => 'INFO'}]},'result' => {'data' => [{'abbreviation' => '','externalReferences' => [],'objective' => 'test','leadPersonDbId' => '','leadPersonName' => '','programDbId' => '134','additionalInfo' => {},'programName' => 'test','documentationURL' => undef,'commonCropName' => 'Cassava'}]}}, "get all programs data test");


$data = '[ {"abbreviation" : "P1","additionalInfo" : {},"commonCropName" : "Tomatillo","documentationURL" : "","externalReferences" : [],"leadPersonDbId" : "50","leadPersonName" : "Bob","objective" : "Make a better tomatillo","programName" : "program3" } ]';
$mech->post('http://localhost:3010/brapi/v2/programs/', Content => $data);
$response = decode_json $mech->content;
print STDERR "\n\n" . Dumper $response;

my $column = $f->bcs_schema()->resultset('Project::Project')->get_column('project_id');
my $project_id = $column->max();
print STDERR "SELECTED PROJECT ID: $project_id\n";
is_deeply($response, {'metadata' => {'status' => [{'message' => 'BrAPI base call found with page=0, pageSize=10','messageType' => 'INFO'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::Programs'},{'message' => '1 Programs were stored.','messageType' => 'INFO'}],'datafiles' => undef,'pagination' => {'totalCount' => 1,'totalPages' => 1,'currentPage' => 0,'pageSize' => 10}},'result' => {}}, "get specific program with project id test" );

$mech->get_ok('http://localhost:3010/brapi/v2/programs/134', 'check v2 get program 134');
$response = decode_json $mech->content;
print STDERR "\n\n" . Dumper $response;
is_deeply($response, {'metadata' => {'pagination' => {'pageSize' => 10,'currentPage' => 0,'totalCount' => 1,'totalPages' => 1},'datafiles' => [],'status' => [{'message' => 'BrAPI base call found with page=0, pageSize=10','messageType' => 'INFO'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::Programs'},{'message' => 'Program list result constructed','messageType' => 'INFO'}]},'result' => {'leadPersonName' => undef,'programDbId' => '134','externalReferences' => [],'abbreviation' => undef,'leadPersonDbId' => undef,'objective' => 'test','commonCropName' => 'Cassava','documentationURL' => undef,'additionalInfo' => {},'programName' => 'test'}}, "get brapi breeding program" );

$data = ' { "abbreviation" : "P1","additionalInfo" : {},"commonCropName" : "Tomatillo","documentationURL" : "https://breedbase.org/","externalReferences" : [],"leadPersonDbId" : "fe6f5c50", "leadPersonName" : "Bob Robertson","objective" : "Make a better tomatillo","programName" : "Program5" }';

# note for the put method: A previous implementation used LWP::UserAgent for the put, but that didn't work for the logins.
# switching to WWW::Mechanize didn't work directly, only when content_type was added it worked. For some reason that's not
# necessary for the post method.
#
$resp = $mech->put("http://localhost:3010/brapi/v2/programs/". $project_id, content_type => 'application/json', content => $data);

print STDERR "RESPONSE: ".Dumper($resp);
$response = decode_json $resp->{_content};
print STDERR "\n\nRESPONSE FROM v2 programs: " . Dumper($response);
is_deeply($response, {'result' => {},'metadata' => {'datafiles' => undef,'pagination' => {'totalPages' => 1,'pageSize' => 10,'currentPage' => 0,'totalCount' => 1},'status' => [{'message' => 'BrAPI base call found with page=0, pageSize=10','messageType' => 'INFO'},{'message' => 'Loading CXGN::BrAPI::v2::Programs','messageType' => 'INFO'},{'messageType' => 'INFO','message' => '1 Program updated.'}]}}, "program put test return data" );

$mech->post_ok('http://localhost:3010/brapi/v2/search/programs', ['programDbIds'=>'134'], "post to program search for id 134");
$response = decode_json $mech->content;
print STDERR "\n\n/brapi/v2/search/programs output: " . Dumper $response;
$searchId = $response->{result} ->{searchResultsDbId};

print STDERR "GENERATED SEARCH ID = $searchId\n";

$mech->get_ok('http://localhost:3010/brapi/v2/search/programs/'. $searchId);

$response = decode_json $mech->content;

print STDERR "\n\n" . Dumper $response;

is_deeply($response, {'metadata' => {'pagination' => {'currentPage' => 0,'pageSize' => 10,'totalPages' => 1,'totalCount' => 1},'datafiles' => [],'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'message' => 'Loading CXGN::BrAPI::v2::Results','messageType' => 'INFO'},{'messageType' => 'INFO','message' => 'search result constructed'}]},'result' => {'data' => [{'programName' => 'test','documentationURL' => undef,'additionalInfo' => {},'commonCropName' => undef,'objective' => 'test','leadPersonDbId' => '','abbreviation' => '','externalReferences' => [],'programDbId' => '134','leadPersonName' => ''}]}}, "search programs test :-)" );

$mech->get_ok('http://localhost:3010/brapi/v2/commoncropnames');
$response = decode_json $mech->content;
print STDERR "\n\n" . Dumper $response;
is_deeply($response, {'result' => {'data' => ['Cassava']},'metadata' => {'datafiles' => [],'pagination' => {'totalPages' => 1,'currentPage' => 0,'pageSize' => 10,'totalCount' => 1},'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::CommonCropNames'},{'messageType' => 'INFO','message' => 'Crops result constructed'}]}}, "commoncropnames test");

$mech->get_ok('http://localhost:3010/brapi/v2/studies/?pageSize=3');
$response = decode_json $mech->content;
print STDERR "\n\nSTUDIES GET: " . Dumper $response;
is_deeply($response, {'result' => {'data' => [{'locationName' => 'test_location','environmentParameters' => undef,'culturalPractices' => undef,'endDate' => undef,'observationUnitsDescription' => undef,'dataLinks' => [],'studyDbId' => '165','observationLevels' => undef,'documentationURL' => '','growthFacility' => undef,'externalReferences' => [],'studyName' => 'CASS_6Genotypes_Sampling_2015','studyPUI' => undef,'studyType' => 'Preliminary Yield Trial','commonCropName' => 'Cassava','startDate' => undef,'experimentalDesign' => {'PUI' => 'RCBD','description' => 'RCBD'},'contacts' => undef,'trialDbId' => '134','seasons' => ['2017'],'license' => undef,'trialName' => 'test','locationDbId' => '23','studyCode' => undef,'studyDescription' => 'Copy of trial with postcomposed phenotypes from cassbase.','lastUpdate' => undef,'active' => JSON::true,'additionalInfo' => {'programName' => 'test','programDbId' => '134'}},{'license' => undef,'seasons' => ['2014'],'trialDbId' => '134','contacts' => undef,'additionalInfo' => {'programDbId' => '134','programName' => 'test'},'active' => JSON::true,'lastUpdate' => undef,'studyDescription' => 'This trial was loaded into the fixture to test solgs.','studyCode' => undef,'locationDbId' => '23','trialName' => 'test','observationLevels' => undef,'studyDbId' => '139','dataLinks' => [],'observationUnitsDescription' => undef,'culturalPractices' => undef,'endDate' => undef,'environmentParameters' => undef,'locationName' => 'test_location','experimentalDesign' => {'PUI' => 'Alpha','description' => 'Alpha'},'startDate' => undef,'commonCropName' => 'Cassava','studyType' => 'Clonal Evaluation','studyPUI' => undef,'studyName' => 'Kasese solgs trial','externalReferences' => [],'growthFacility' => undef,'documentationURL' => ''},{'experimentalDesign' => {},'startDate' => undef,'commonCropName' => 'Cassava','studyType' => undef,'studyPUI' => undef,'studyName' => 'new_test_cross','externalReferences' => [],'growthFacility' => undef,'documentationURL' => '','observationLevels' => undef,'dataLinks' => [],'studyDbId' => '135','observationUnitsDescription' => undef,'endDate' => undef,'culturalPractices' => undef,'environmentParameters' => undef,'locationName' => '','additionalInfo' => {'programDbId' => '134','programName' => 'test'},'active' => JSON::true,'lastUpdate' => undef,'studyDescription' => 'new_test_cross','studyCode' => undef,'locationDbId' => undef,'trialName' => 'test','license' => undef,'contacts' => undef,'seasons' => [undef],'trialDbId' => '134'}]},'metadata' => {'datafiles' => [],'pagination' => {'totalCount' => 6,'totalPages' => 2,'currentPage' => 0,'pageSize' => 3},'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=3'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::Studies'},{'messageType' => 'INFO','message' => 'Studies search result constructed'}]}}, "v2 studies test");

$mech->post_ok('http://localhost:3010/brapi/v2/search/studies', ['pageSize'=>'2', 'page'=>'2']);
$response = decode_json $mech->content;
$searchId = $response->{result} ->{searchResultsDbId};
$mech->get_ok('http://localhost:3010/brapi/v2/search/studies/'. $searchId);
$response = decode_json $mech->content;
print STDERR "\n\nSTUDIES POST 2: " . Dumper $response;
is_deeply($response, {'result' => {'data' => [{'studyDescription' => 'test trial','studyCode' => undef,'lastUpdate' => undef,'observationUnitsDescription' => undef,'experimentalDesign' => {'PUI' => 'CRD','description' => 'CRD'},'environmentParameters' => undef,'externalReferences' => [],'studyType' => undef,'locationName' => 'test_location','commonCropName' => 'Cassava','growthFacility' => undef,'startDate' => '2017-07-04T00:00:00Z','studyName' => 'test_trial','trialDbId' => '134','studyPUI' => undef,'license' => undef,'additionalInfo' => {'programName' => 'test','programDbId' => '134'},'locationDbId' => '23','observationLevels' => undef,'contacts' => undef,'seasons' => ['2014'],'endDate' => '2017-07-21T00:00:00Z','studyDbId' => '137','trialName' => 'test','dataLinks' => [],'active' => JSON::true,'culturalPractices' => undef,'documentationURL' => ''},{'trialName' => 'test','studyDbId' => '141','documentationURL' => '','culturalPractices' => undef,'dataLinks' => [],'active' => JSON::true,'contacts' => undef,'endDate' => undef,'seasons' => ['2014'],'observationLevels' => undef,'trialDbId' => '134','startDate' => undef,'studyName' => 'trial2 NaCRRI','locationDbId' => '23','additionalInfo' => {'programName' => 'test','programDbId' => '134'},'license' => undef,'studyPUI' => undef,'commonCropName' => 'Cassava','locationName' => 'test_location','growthFacility' => undef,'externalReferences' => [],'environmentParameters' => undef,'studyType' => undef,'observationUnitsDescription' => undef,'lastUpdate' => undef,'experimentalDesign' => {'PUI' => 'CRD','description' => 'CRD'},'studyDescription' => 'another trial for solGS','studyCode' => undef}]},'metadata' => {'pagination' => {'totalCount' => 2,'pageSize' => 10,'totalPages' => 1,'currentPage' => 0},'status' => [{'message' => 'BrAPI base call found with page=0, pageSize=10','messageType' => 'INFO'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::Results'},{'messageType' => 'INFO','message' => 'search result constructed'}],'datafiles' => []}}, "search studies test");
$mech->get_ok('http://localhost:3010/brapi/v2/studies/139');
$response = decode_json $mech->content;

#print STDERR "\n\nSTUDIES GET 2: " . Dumper $response;

is_deeply($response, {'metadata' => {'pagination' => {'totalCount' => 1,'totalPages' => 1,'currentPage' => 0,'pageSize' => 10},'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'message' => 'Loading CXGN::BrAPI::v2::Studies','messageType' => 'INFO'},{'messageType' => 'INFO','message' => 'Studies search result constructed'}],'datafiles' => []},'result' => {'studyCode' => undef,'trialDbId' => '134','environmentParameters' => undef,'externalReferences' => [],'dataLinks' => [],'commonCropName' => 'Cassava','studyType' => 'Clonal Evaluation','additionalInfo' => {'programDbId' => '134', 'programName' => 'test'},'documentationURL' => '','endDate' => undef,'studyDescription' => 'This trial was loaded into the fixture to test solgs.','studyName' => 'Kasese solgs trial','locationName' => 'test_location','studyPUI' => undef,'lastUpdate' => undef,'experimentalDesign' => {'PUI' => 'Alpha','description' => 'Alpha'},'observationUnitsDescription' => undef,'startDate' => undef,'studyDbId' => '139','observationLevels' => undef,'culturalPractices' => undef,'growthFacility' => undef,'locationDbId' => '23','seasons' => ['2014'],'contacts' => undef,'active' => JSON::true ,'trialName' => 'test','license' => undef}}, "check study after search" );
$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = 1;
$mech->get_ok('http://localhost:3010/brapi/v2/locations?pageSize=3');

$response = decode_json $mech->content();

foreach my $d (@{$response->{result}->{data}}) {
    foreach my $coord (@{$d->{coordinates}->{geometry}->{coordinates}}) {
	$coord = round($coord);
    }
}

print STDERR "\n\n Locations response after transformation (pagesize = 3): " . Dumper $response;

my $expected = {'result' => {'data' => [{'siteStatus' => undef,'environmentType' => undef,'coordinateUncertainty' => undef,'countryCode' => 'USA','instituteAddress' => '','topography' => undef,'coordinateDescription' => undef,'instituteName' => '','additionalInfo' => {'geodetic datum' => undef, breeding_program => 134 },'externalReferences' => [],'abbreviation' => '','exposure' => undef,'coordinates' => {'type' => 'Feature','geometry' => {'coordinates' => ['-116','33','109'],'type' => 'Point'}},'documentationURL' => undef,'locationType' => '','locationName' => 'test_location','countryName' => 'United States','slope' => undef,'locationDbId' => '23'},{'countryCode' => 'USA','instituteAddress' => '','topography' => undef,'siteStatus' => undef,'environmentType' => undef,'coordinateUncertainty' => undef,'externalReferences' => [],'additionalInfo' => {'geodetic datum' => undef, breeding_program => 134},'instituteName' => '','coordinateDescription' => undef,'countryName' => 'United States','locationName' => 'Cornell Biotech','abbreviation' => '','documentationURL' => undef,'exposure' => undef,'coordinates' => {'geometry' => {'type' => 'Point','coordinates' => ['-76','42','274']},'type' => 'Feature'},'locationType' => '','locationDbId' => '24','slope' => undef},{'environmentType' => undef,'coordinateUncertainty' => undef,'siteStatus' => undef,'instituteAddress' => '','topography' => undef,'countryCode' => '','instituteName' => '','coordinateDescription' => undef,'externalReferences' => [],'additionalInfo' => {'geodetic datum' => undef, },'locationType' => '','documentationURL' => undef,'exposure' => undef,'abbreviation' => '','coordinates' => { 'geometry' => { 'coordinates' => [] } },'countryName' => '','locationName' => 'NA','locationDbId' => '25','slope' => undef } ] },'metadata' => {'pagination' => {'totalCount' => 4,'totalPages' => 2,'currentPage' => 0,'pageSize' => 3},'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=3'},{'message' => 'Loading CXGN::BrAPI::v2::Locations','messageType' => 'INFO'},{'messageType' => 'INFO','message' => 'Locations list result constructed'}],'datafiles' => []}};

print STDERR "\n\n Locations that were expected: ".Dumper($expected);

is_deeply($response, $expected, "locations test");

$data = '[{ "abbreviation" : "L1", "additionalInfo" : {"noaaStationId" : "PALMIRA","programDbId" : "134"}, "coordinateDescription" : "North East corner of greenhouse", "coordinateUncertainty" : "20", "coordinates" : { "geometry" : { "coordinates" : [ -76.506042, 42.417373, 123 ], "type" : "Point" }, "type" : "Feature" }, "countryCode" : "PER", "countryName" : "Peru", "documentationURL" : "https://brapi.org",    "environmentType" : "Nursery", "exposure" : "Structure, no exposure",    "externalReferences" : [ { "referenceID" : "doi:10.155454/12341234", "referenceSource" : "DOI" }, { "referenceID" : "http://purl.obolibrary.org/obo/ro.owl", "referenceSource" : "OBO Library" }, { "referenceID" : "75a50e76", "referenceSource" : "Remote Data Collection Upload Tool" } ], "instituteAddress" : "71 Pilgrim Avenue Chevy Chase MD 20815", "instituteName" : "Plant Science Institute", "locationName" : "Location 1", "locationType" : "Field", "siteStatus" : "Private", "slope" : "0", "topography" : "Valley" }]';

print STDERR "DATA PARSED: ".Dumper(decode_json($data));

$mech->post('http://localhost:3010/brapi/v2/locations/', Content => $data);

$response = decode_json $mech->content;

#print STDERR "\n\n" . Dumper $response;

foreach my $d (@{$response->{result}->{data}}) {

    foreach my $coord (@{$d->{coordinates}->{geometry}->{coordinates}}) {
	$coord = round($coord);
    }
}
my $rs = $f->bcs_schema()->resultset('NaturalDiversity::NdGeolocation')->search( undef, { columns => [ { nd_geolocation_id => { max => "nd_geolocation_id" }} ]} );
my $row = $rs->next();

my $location_id = $row->nd_geolocation_id();

#print STDERR "\n\n" . Dumper $response;

$expected = { 'metadata'=> { 'datafiles'=> [], 'pagination'=> { 'currentPage'=> 0, 'totalPages'=> 1, 'totalCount'=> 1, 'pageSize'=> 10 }, 'status'=> [ { 'messageType'=> 'INFO', 'message'=> 'BrAPI base call found with page=0, pageSize=10' }, { 'messageType'=> 'INFO', 'message'=> 'Loading CXGN::BrAPI::v2::Locations' }, { 'messageType'=> 'INFO', 'message'=> 'Locations list result constructed' } ] }, 'result'=> { 'data'=> [ { 'topography'=> undef, 'additionalInfo'=> { 'geodetic datum'=> undef, 'noaa_station_id'=> 'PALMIRA' }, 'locationDbId'=> $location_id, 'coordinateDescription'=> undef, 'abbreviation'=> 'L1', 'instituteAddress'=> '', 'environmentType'=> undef, 'externalReferences'=> [{ 'referenceId' => 'doi:10.155454/12341234', 'referenceSource' => 'DOI' }, {'referenceId' => 'http://purl.obolibrary.org/obo/ro.owl', 'referenceSource' => 'OBO Library' }, { 'referenceId' => '75a50e76', 'referenceSource' => 'Remote Data Collection Upload Tool' } ], 'exposure'=> undef, 'coordinateUncertainty'=> undef, 'documentationURL'=> undef, 'slope'=> undef, 'locationType'=> 'Field', 'siteStatus'=> undef, 'locationName'=> 'Location 1', 'coordinates'=> { 'geometry'=> { 'type'=> 'Point', 'coordinates'=> [ '-77','42', '123' ] }, 'type'=> 'Feature' }, 'countryCode'=> 'PER', 'countryName'=> 'Peru', 'instituteName'=> '' } ]}};

is_deeply($response, $expected, "POST locations test"  );

$mech->get_ok('http://localhost:3010/brapi/v2/locations/23');
$response = decode_json $mech->content;
#print STDERR "\n\n" . Dumper $response;
foreach my $coord (@{$response->{result}->{coordinates}->{geometry}->{coordinates}}) {
	$coord = round($coord);
}

$expected = {'metadata' => {'pagination' => {'currentPage' => 0,'totalCount' => 1,'totalPages' => 1,'pageSize' => 10},'datafiles' => [],'status' => [{'message' => 'BrAPI base call found with page=0, pageSize=10','messageType' => 'INFO'},{'message' => 'Loading CXGN::BrAPI::v2::Locations','messageType' => 'INFO'},{'messageType' => 'INFO','message' => 'Locations object result constructed'}]},'result' => {'externalReferences' => [],'countryCode' => 'USA','instituteName' => '','locationType' => '','documentationURL' => undef,'instituteAddress' => '','exposure' => undef,'abbreviation' => '','coordinateUncertainty' => undef,'additionalInfo' => {'breeding_program' => '134','geodetic datum' => undef},'coordinates' => {'geometry' => {'coordinates' => ['-116','33','109'],'type' => 'Point'},'type' => 'Feature'},'locationName' => 'test_location','siteStatus' => undef,'slope' => undef,'coordinateDescription' => undef,'environmentType' => undef,'topography' => undef,'locationDbId' => '23','countryName' => 'United States'}};
is_deeply($response, $expected, "locations 23 test"  );


$data = '{ "abbreviation" : "L2", "additionalInfo" : { "noaaStationId" : "PALMIRA", "programDbId" : "134"}, "coordinateDescription" : "North East corner of greenhouse",  "coordinateUncertainty" : "20", "coordinates" : { "geometry" : { "coordinates" : [ -76.506042, 42.417373, 123 ], "type" : "Point" }, "type" : "Feature" }, "countryCode" : "PER", "countryName" : "Peru", "documentationURL" : "https://brapi.org",  "environmentType" : "Nursery", "exposure" : "Structure, no exposure",  "externalReferences" : [ { "referenceID" : "doi:10.155454/12341234", "referenceSource" : "DOI" }, { "referenceID" : "http://purl.obolibrary.org/obo/ro.owl", "referenceSource" : "OBO Library" }, { "referenceID" : "75a50e76", "referenceSource" : "Remote Data Collection Upload Tool" } ], "instituteAddress" : "71 Pilgrim Avenue Chevy Chase MD 20815", "instituteName" : "Plant Science Institute", "locationName" : "Location 2", "locationType" : "Field", "siteStatus" : "Private", "slope" : "0", "topography" : "Valley" }';

print STDERR "INPUT DATA = ".Dumper($data);

$resp = $mech->put("http://localhost:3010/brapi/v2/locations/25", content_type => 'application/json', content => $data);

print STDERR "RESPONSE: ".Dumper($resp);
$response = decode_json $resp->{_content};

print STDERR "\n\n locations details in the response: " . Dumper $response;
foreach my $coord (@{$response->{result}->{coordinates}->{geometry}->{coordinates}}) {
    $coord = round($coord);
}

$expected = { 'result'=> { 'environmentType'=> undef, 'externalReferences'=> [], 'instituteAddress'=> '', 'abbreviation'=> 'L2', 'coordinateDescription'=> undef, 'topography'=> undef, 'additionalInfo'=> { 'geodetic datum'=> undef, 'noaa_station_id'=> 'PALMIRA' }, 'locationDbId'=> '25', 'instituteName'=> '', 'countryCode'=> 'PER', 'countryName'=> 'Peru', 'siteStatus'=> undef, 'locationName'=> 'Location 2', 'coordinates'=> { 'type'=> 'Feature', 'geometry'=> { 'coordinates'=> [ '-77','42','123'], 'type'=> 'Point' } }, 'slope'=> undef, 'documentationURL'=> undef, 'locationType'=> 'Field', 'coordinateUncertainty'=> undef, 'exposure'=> undef }, 'metadata'=> { 'status'=> [ { 'messageType'=> 'INFO', 'message'=> 'BrAPI base call found with page=0, pageSize=10' }, { 'messageType'=> 'INFO', 'message'=> 'Loading CXGN::BrAPI::v2::Locations' }, { 'message'=> 'Locations list result constructed', 'messageType'=> 'INFO' } ], 'pagination'=> { 'totalPages'=> 1, 'pageSize'=> 10, 'totalCount'=> 1, 'currentPage'=> 0 }, 'datafiles'=> [] }};
is_deeply($response, $expected, "PUT locations 25 test"  );

$mech->post('http://localhost:3010/brapi/v2/search/locations', Content => ['locationDbIds'=>['25']]);
$response = decode_json $mech->content;
$searchId = $response->{result} ->{searchResultsDbId};

$mech->get_ok('http://localhost:3010/brapi/v2/search/locations/'. $searchId, "retrieve searched location data");
$response = decode_json $mech->content;

foreach my $d (@{$response->{result}->{data}}) {
    foreach my $coord (@{$d->{coordinates}->{geometry}->{coordinates}}) {
	$coord = round($coord);
    }
}
print STDERR "\n\nlocations call response : " . Dumper \$response;

$expected = {'result' => {'data' => [{'locationType' => 'Field','externalReferences' => [],'countryCode' => 'PER','instituteName' => '','documentationURL' => undef,'instituteAddress' => '','locationName' => 'Location 2','siteStatus' => undef,'slope' => undef,'exposure' => undef,'coordinateUncertainty' => undef,'abbreviation' => 'L2','additionalInfo' => {'noaa_station_id' => 'PALMIRA','geodetic datum' => undef},'coordinates' => {'type' => 'Feature','geometry' => {'coordinates' => ['-77','42',123],'type' => 'Point'}},'countryName' => 'Peru','environmentType' => undef,'coordinateDescription' => undef,'topography' => undef,'locationDbId' => '25'}]},'metadata' => {'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::Results'},{'message' => 'search result constructed','messageType' => 'INFO'}],'pagination' => {'totalCount' => 1,'totalPages' => 1,'pageSize' => 10,'currentPage' => 0},'datafiles' => []}} ;
is_deeply($response, $expected, "locations search post test"  );

# rename the location to what it was before so that other tests don't trip over it
#
my $row = $f->bcs_schema->resultset("NaturalDiversity::NdGeolocation")->find( { description => 'Location 2' });
$row->description('NA');
$row->update();

print STDERR "RENAMED LOCATION 2 BACK TO NA\n";

$mech->get_ok('http://localhost:3010/brapi/v2/people');
$response = decode_json $mech->content;
print STDERR "\n\n People in the brapi response: " . Dumper $response;
is_deeply($response, {'result' => {'data' => [{'personDbId' => '40','mailingAddress' => undef,'userID' => 'johndoe','firstName' => 'John','emailAddress' => undef,'description' => undef,'phoneNumber' => undef,'additionalInfo' => {'country' => undef},'lastName' => 'Doe','externalReferences' => {'referenceSource' => undef,'referenceID' => undef},'middleName' => undef},{'middleName' => undef,'externalReferences' => {'referenceID' => undef,'referenceSource' => undef},'lastName' => 'Doe','additionalInfo' => {'country' => undef},'phoneNumber' => undef,'description' => undef,'emailAddress' => undef,'userID' => 'janedoe','firstName' => 'Jane','mailingAddress' => undef,'personDbId' => '41'},{'lastName' => 'Sanger','middleName' => undef,'emailAddress' => undef,'description' => undef,'phoneNumber' => undef,'additionalInfo' => {'country' => undef},'externalReferences' => {'referenceID' => undef,'referenceSource' => undef},'personDbId' => '42','mailingAddress' => undef,'firstName' => 'Fred','userID' => 'freddy'}]},'metadata' => {'pagination' => {'pageSize' => 10,'totalCount' => 3,'totalPages' => 1,'currentPage' => 0},'datafiles' => [],'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::People'},{'message' => 'People result constructed','messageType' => 'INFO'}]}});

$mech->get_ok('http://localhost:3010/brapi/v2/people/41');
$response = decode_json $mech->content;
print STDERR "\n\n PEOPLE GET RESPONSE:" . Dumper $response;
is_deeply($response, {'result' => {'mailingAddress' => undef,'middleName' => undef,'personDbId' => '41','additionalInfo' => {'country' => undef},'externalReferences' => {'referenceID' => undef,'referenceSource' => undef},'description' => 'Organization: ','lastName' => 'Doe','firstName' => 'Jane','userID' => 'janedoe','phoneNumber' => undef,'emailAddress' => undef},'metadata' => {'datafiles' => [],'pagination' => {'pageSize' => 10,'currentPage' => 0,'totalCount' => 1,'totalPages' => 1},'status' => [{'message' => 'BrAPI base call found with page=0, pageSize=10','messageType' => 'INFO'},{'message' => 'Loading CXGN::BrAPI::v2::People','messageType' => 'INFO'},{'messageType' => 'INFO','message' => 'People result constructed'}]}} );

$mech->post_ok('http://localhost:3010/brapi/v2/search/people', ['personDbId'=>['40','41']]);
$response = decode_json $mech->content;
$searchId = $response->{result} ->{searchResultsDbId};
$mech->get_ok('http://localhost:3010/brapi/v2/search/people/'. $searchId);
$response = decode_json $mech->content;
print STDERR "\n\nPEOPLE POST REPONSE: " . Dumper $response;
is_deeply($response, {'result' => {'data' => [{'emailAddress' => undef,'personDbId' => '40','firstName' => 'John','mailingAddress' => undef,'additionalInfo' => {'country' => undef},'userID' => 'johndoe','lastName' => 'Doe','description' => undef,'phoneNumber' => undef,'externalReferences' => {'referenceID' => undef,'referenceSource' => undef},'middleName' => undef},{'description' => undef,'phoneNumber' => undef,'externalReferences' => {'referenceID' => undef,'referenceSource' => undef},'middleName' => undef,'emailAddress' => undef,'personDbId' => '41','firstName' => 'Jane','mailingAddress' => undef,'additionalInfo' => {'country' => undef},'userID' => 'janedoe','lastName' => 'Doe'}]},'metadata' => {'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::Results'},{'messageType' => 'INFO','message' => 'search result constructed'}],'datafiles' => [],'pagination' => {'totalPages' => 1,'pageSize' => 10,'currentPage' => 0,'totalCount' => 2}}});

## Trials

# #post
$data = '[ {"active": "true","additionalInfo": {},"commonCropName": "Cassava","contacts": [],"datasetAuthorships": [],"documentationURL": "https://breedbase.org/","endDate": "2020-06-24","externalReferences": [],"programDbId": "134","programName": "test","publications": [],"startDate": "2020-06-24","trialDescription": "General drought resistance trial initiated in Peru","trialName": "Peru Yield Trial 2010","trialPUI": "https://doi.org/101093190"  }]';
$mech->post('http://localhost:3010/brapi/v2/trials/', Content => $data);
$response = decode_json $mech->content;
print STDERR "\n\nTRIALS POST: " . Dumper $response;
$column = $f->bcs_schema()->resultset('Project::Project')->get_column('project_id');
my $trial_id = $column->max();

print STDERR "WORKING WITH TRIAL ID $trial_id\n";

is_deeply($response, {'metadata' => {'datafiles' => [],'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'message' => 'Loading CXGN::BrAPI::v2::Trials','messageType' => 'INFO'},{'message' => 'Trials result constructed','messageType' => 'INFO'}],'pagination' => {'totalCount' => 1,'totalPages' => 1,'currentPage' => 0,'pageSize' => 10}},'result' => {'data' => [{'documentationURL' => undef,'contacts' => undef,'trialName' => 'Peru Yield Trial 2010','trialPUI' => undef,'additionalInfo' => {},'endDate' => undef,'programName' => 'test','startDate' => undef,'externalReferences' => [],'active' => JSON::true,'publications' => undef,'datasetAuthorships' => undef,'programDbId' => '134','commonCropName' => undef,'trialDescription' => 'General drought resistance trial initiated in Peru', 'trialDbId' => $trial_id }]}}, "trial post test");


$mech->get_ok('http://localhost:3010/brapi/v2/trials/');
$response = decode_json $mech->content;
print STDERR "\n\nTRIALS GET" . Dumper $response;
is_deeply($response, { 'result'=> { 'data'=> [ { 'datasetAuthorships'=> undef, 'additionalInfo'=> {}, 'publications'=> undef, 'externalReferences'=> [], 'trialDescription'=> 'General drought resistance trial initiated in Peru', 'programDbId'=> '134', 'active'=> JSON::true, 'endDate'=> undef, 'programName'=> 'test', 'contacts'=> undef, 'documentationURL'=> undef, 'trialDbId'=> $trial_id, 'commonCropName'=> 'Cassava', 'startDate'=> undef, 'trialPUI'=> undef, 'trialName'=> 'Peru Yield Trial 2010' } ] }, 'metadata'=> { 'pagination'=> { 'pageSize'=> 10, 'totalPages'=> 1, 'totalCount'=> 1, 'currentPage'=> 0 }, 'datafiles'=> [], 'status'=> [ { 'messageType'=> 'INFO', 'message'=> 'BrAPI base call found with page=0, pageSize=10' }, { 'messageType'=> 'INFO', 'message'=> 'Loading CXGN::BrAPI::v2::Trials' }, { 'message'=> 'Trials result constructed', 'messageType'=> 'INFO' } ] } });

## Studies

$data = '[ { "active": "true", "additionalInfo": {}, "commonCropName": "Grape", "contacts": [], "culturalPractices": "Irrigation was applied according needs during summer to prevent water stress.", "dataLinks": [], "documentationURL": "https://breedbase.org/", "endDate": "2020-06-12T22:05:35.680Z", "environmentParameters": [], "experimentalDesign": {   "PUI": "RCBD",   "description": "Random" }, "externalReferences": [], "growthFacility": { }, "lastUpdate": {}, "license": "MIT License", "locationDbId": "23", "locationName": "test_location", "observationLevels": [], "observationUnitsDescription": "Observation units", "seasons": [   "2018" ], "startDate": "2020-06-12T22:05:35.680Z", "studyCode": "Grape_Yield_Spring_2018", "studyDescription": "This is a yield study for Spring 2018", "studyName": "Observation at Kenya 1", "studyPUI": "doi:10.155454/12349537312", "studyType": "nonexisting_type", "trialDbId": "'. $trial_id .'", "trialName": "Peru Yield Trial 2010"} ]';
$mech->post('http://localhost:3010/brapi/v2/studies', Content => $data);
$response = decode_json $mech->content;
print STDERR "\n\nSTUDIES POST: " . Dumper $response;
$column = $f->bcs_schema()->resultset('Project::Project')->get_column('project_id');
my $study_id = $column->max();

print STDERR "STUDY ID = $study_id\n";

is_deeply($response, {'result' => {'data' => [{'observationLevels' => undef,'dataLinks' => [],'experimentalDesign' => {'PUI' => 'RCBD','description' => 'RCBD'},'observationUnitsDescription' => undef,'studyName' => 'Observation at Kenya 1','startDate' => undef,'growthFacility' => undef,'active' => JSON::true,'lastUpdate' => undef,'contacts' => undef,'endDate' => undef,'studyDbId' => $study_id,'locationDbId' => '23','documentationURL' => '','additionalInfo' => {'programDbId' => '134','programName' => 'test'},'seasons' => ['2018'],'culturalPractices' => undef,'studyDescription' => 'This is a yield study for Spring 2018','externalReferences' => [],'studyPUI' => undef,'commonCropName' => 'Cassava','trialDbId' => $trial_id,'studyType' => 'nonexisting_type','trialName' => 'Peru Yield Trial 2010','locationName' => 'test_location','license' => undef,'studyCode' => undef,'environmentParameters' => undef}]},'metadata' => {'datafiles' => [],'pagination' => {'totalCount' => 1,'currentPage' => 0,'pageSize' => 1,'totalPages' => 1},'status' => [{'message' => 'BrAPI base call found with page=0, pageSize=10','messageType' => 'INFO'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::Studies'},{'message' => 'Studies stored successfully','messageType' => 'INFO'}]}}, "verify studies call data");

$data = '{ "active" : "true", "additionalInfo" : {}, "commonCropName" : "Grape", "contacts" : [], "culturalPractices" : "Irrigation was applied according needs during summer to prevent water stress.", "dataLinks" : [], "documentationURL" : "http://breedbase.org", "endDate" : "2018-01-01", "environmentParameters" : [   { "description" : "the soil type was clay", "parameterName" : "soil type", "parameterPUI" : "PECO:0007155", "unit" : "pH", "unitPUI" : "PECO:0007059", "value" : "clay soil", "valuePUI" : "ENVO:00002262"   } ], "experimentalDesign" : {   "PUI" : "CRD",   "description" : "Lines were repeated twice at each location using a complete block design. In order to limit competition effects, each block was organized into four sub-blocks corresponding to earliest groups based on a prior information." }, "externalReferences" : [], "growthFacility" : {   "PUI" : "CO_715:0000162",   "description" : "field environment condition, greenhouse" }, "lastUpdate" : {   "timestamp" : "2018-01-01T14:47:23-0600",   "version" : "1.2.3" }, "license" : "MIT License", "locationDbId" : "23", "locationName" : "test_location", "observationLevels" : [], "observationUnitsDescription" : "Observation units consisted in individual plots themselves consisting of a row of 15 plants at a density of approximately six plants per square meter.", "seasons" : [   "Spring_2018" ], "startDate" : "2018-01-01", "studyCode" : "Grape_Yield_Spring_2018", "studyDescription" : "This is a yield study for Spring 2018", "studyName" : "INRAs Walnut Genetic Resources Observation at Kenya modified", "studyPUI" : "doi:10.155454/12349537312", "studyType" : "phenotyping_trial", "trialDbId" : "'. $trial_id .'", "trialName" : "Peru Yield Trial 2010"} ';
$resp = $mech->put("http://localhost:3010/brapi/v2/studies/".$study_id, content_type => 'application/json', content => $data);
$response = decode_json $resp->{_content};
print STDERR "\n\nSTUDIES PUT" . Dumper $response;
is_deeply($response, {'result' => {'culturalPractices' => undef,'studyDescription' => 'This is a yield study for Spring 2018','externalReferences' => [],'studyPUI' => undef,'commonCropName' => 'Cassava','trialDbId' => $trial_id,'studyType' => 'phenotyping_trial','additionalInfo' => {'programName' => 'test','programDbId' => '134'},'seasons' => ['Spring_2018'],'environmentParameters' => undef,'trialName' => 'Peru Yield Trial 2010','locationName' => 'test_location','studyCode' => undef,'license' => undef,'observationUnitsDescription' => undef,'studyName' => 'INRAs Walnut Genetic Resources Observation at Kenya modified','startDate' => '2018-01-01T00:00:00Z','growthFacility' => undef,'active' => JSON::true,'lastUpdate' => undef,'observationLevels' => undef,'dataLinks' => [],'experimentalDesign' => {'PUI' => 'CRD','description' => 'CRD'},'locationDbId' => '23','documentationURL' => '','contacts' => undef,'endDate' => '2018-01-01T00:00:00Z','studyDbId' => $study_id},'metadata' => {'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'message' => 'Loading CXGN::BrAPI::v2::Studies','messageType' => 'INFO'},{'messageType' => 'INFO','message' => 'Studies result constructed'}],'datafiles' => [],'pagination' => {'totalCount' => 1,'totalPages' => 1,'pageSize' => 10,'currentPage' => 0}}}, "check update studies call return data" );

# print STDERR "Checking put with Kasese trial...\n";
# #
# $data = '{ "studyName": "Kasese solgs trial", "trialDbId": 134, "seasons": [   "2014" ], "locationDbId":"23", "studyType":"phenotyping_trial", "experimentalDesign": {"PUI": "CRD"}}';
# $resp = $ua->put("http://localhost:3010/brapi/v2/studies/139", Content => $data);
# $response = decode_json $resp->{_content};
# print STDERR "\n\n" . Dumper $response;
# is_deeply($response,  {'result' => {'lastUpdate' => undef,'startDate' => undef,'active' => JSON::true,'growthFacility' => undef,'observationUnitsDescription' => undef,'studyName' => 'Kasese solgs trial','dataLinks' => [],'experimentalDesign' => {'PUI' => 'CRD','description' => 'CRD'},'observationLevels' => undef,'documentationURL' => '','locationDbId' => '23','studyDbId' => 139,'endDate' => undef,'contacts' => undef,'commonCropName' => 'Cassava','trialDbId' => 134, 'studyType' => 'Clonal Evaluation', 'externalReferences' => [],'studyPUI' => undef,'studyDescription' => 'This trial was loaded into the fixture to test solgs.','culturalPractices' => undef,'seasons' => ['2014'],'additionalInfo' => {'programName' => 'test','programDbId' => '134'},'environmentParameters' => undef,'studyCode' => undef,'license' => '','trialName' => 'test','locationName' => 'test_location'},'metadata' => {'pagination' => {'pageSize' => 10,'currentPage' => 0,'totalPages' => 1,'totalCount' => 1},'datafiles' => [],'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::Studies'},{'messageType' => 'INFO','message' => 'Studies result constructed'}]}});

# ## change trial data back to what it was before!!!:
# $data = '{ "studyName": "Kasese solgs trial", "trialDbId": 139, "seasons": [   "2014" ], "locationDbId":"23", "studyType":"Clonal Evaluation", "experimentalDesign": {"PUI": "CRD"}}';
# $resp = $ua->put("http://localhost:3010/brapi/v2/studies/139", Content => $data);

##  Trials
#it doesn't update date or description
$data = ' { "active" : "true","additionalInfo" : {},"commonCropName" : "Cassava","contacts" : [],"datasetAuthorships" : [],"documentationURL" : "https://breedbase.org/","endDate" : "2020-06-24","externalReferences" : [],"programDbId" : "134","programName" : "test","publications" : [],"startDate" : "2020-06-24","trialDescription" : "Trial initiated in Peru","trialName" : "Peru Yield Trial 2020-1","trialPUI" : "https://doi.org/101093190" } ';
$resp = $mech->put("http://localhost:3010/brapi/v2/trials/". $trial_id, content_type => 'application/json', content => $data);
$response = decode_json $resp->{_content};
print STDERR "\n\n" . Dumper $response;
is_deeply($response, {'result' => {'additionalInfo' => {},'publications' => undef,'endDate' => undef,'documentationURL' => undef,'startDate' => undef,'commonCropName' => 'Cassava','trialPUI' => undef,'trialDescription' => 'Peru Yield Trial 2020-1','programName' => 'test','programDbId' => '134','trialDbId' => $trial_id, 'active' => JSON::true, 'datasetAuthorships' => undef,'contacts' => undef,'externalReferences' => [],'trialName' => 'Peru Yield Trial 2020-1'},'metadata' => {'datafiles' => [],'status' => [{'message' => 'BrAPI base call found with page=0, pageSize=10','messageType' => 'INFO'},{'message' => 'Loading CXGN::BrAPI::v2::Trials','messageType' => 'INFO'},{'message' => 'Trial detail result constructed','messageType' => 'INFO'}],'pagination' => {'totalCount' => 1,'totalPages' => 1,'currentPage' => 0,'pageSize' => 10}}}, "Update trial test");

$mech->get_ok('http://localhost:3010/brapi/v2/trials/' . $trial_id);
$response = decode_json $mech->content;
print STDERR "\n\n" . Dumper $response;
is_deeply($response,  {'result' => {'trialPUI' => undef,'externalReferences' => [],'documentationURL' => undef,'publications' => undef,'contacts' => undef,'programName' => 'test','commonCropName' => 'Cassava','datasetAuthorships' => undef,'endDate' => undef,'active' => JSON::true,'trialName' => 'Peru Yield Trial 2020-1','programDbId' => '134','startDate' => undef,'additionalInfo' => {},'trialDescription' => 'Trial initiated in Peru','trialDbId' => $trial_id },'metadata' => {'datafiles' => [],'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::Trials'},{'messageType' => 'INFO','message' => 'Trial detail result constructed'}],'pagination' => {'currentPage' => 0,'totalCount' => 1,'pageSize' => 10,'totalPages' => 1}}}, "");

$mech->get_ok('http://localhost:3010/brapi/v2/trials/?trialDbId=' . $trial_id);
$response = decode_json $mech->content;
print STDERR "\n\n" . Dumper $response;
is_deeply($response, {'metadata' => {'status' => [{'message' => 'BrAPI base call found with page=0, pageSize=10','messageType' => 'INFO'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::Trials'},{'message' => 'Trials result constructed','messageType' => 'INFO'}],'datafiles' => [],'pagination' => {'totalPages' => 1,'pageSize' => 10,'totalCount' => 1,'currentPage' => 0}},'result' => {'data' => [{'contacts' => undef,'trialDescription' => 'Trial initiated in Peru','active' => JSON::true,'programDbId' => '134','publications' => undef,'trialDbId' => $trial_id,'startDate' => undef,'additionalInfo' => {},'trialPUI' => undef,'endDate' => undef,'datasetAuthorships' => undef,'trialName' => 'Peru Yield Trial 2020-1','externalReferences' => [],'programName' => 'test','documentationURL' => undef,'commonCropName' => 'Cassava'}]}});

$mech->post_ok('http://localhost:3010/brapi/v2/search/trials', ['pageSize'=>'1', 'trialDbId' => [$trial_id]]);
$response = decode_json $mech->content;
$searchId = $response->{result} ->{searchResultsDbId};
print STDERR "\n\n" . Dumper $response;
$mech->get_ok('http://localhost:3010/brapi/v2/search/trials/'. $searchId);
$response = decode_json $mech->content;
print STDERR "\n\n" . Dumper $response;
is_deeply($response, {'result' => {'data' => [{'startDate' => undef,'programDbId' => '134','datasetAuthorships' => undef,'active' => JSON::true ,'publications' => undef,'trialName' => 'Peru Yield Trial 2020-1','trialPUI' => undef,'trialDbId' => $trial_id,'contacts' => undef,'additionalInfo' => {},'commonCropName' => undef,'documentationURL' => undef,'trialDescription' => 'Trial initiated in Peru','programName' => 'test','endDate' => undef,'externalReferences' => []}]},'metadata' => {'datafiles' => [],'status' => [{'message' => 'BrAPI base call found with page=0, pageSize=10','messageType' => 'INFO'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::Results'},{'message' => 'search result constructed','messageType' => 'INFO'}],'pagination' => {'totalPages' => 1,'pageSize' => 10,'currentPage' => 0,'totalCount' => 1}}} );

## REMOVE created objects...

$f->clean_up_db();

done_testing();
