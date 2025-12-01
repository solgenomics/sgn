
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use LWP::UserAgent;

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
print STDERR Dumper $response;
#1
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
#2
is($response->{'userDisplayName'}, 'Jane Doe');
#3
is($response->{'expires_in'}, '7200');

$mech->delete_ok('http://localhost:3010/brapi/v2/token');
$response = decode_json $mech->content;
print STDERR Dumper $response;
#4
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'User Logged Out');

$mech->post_ok('http://localhost:3010/brapi/v2/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
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



$mech->get_ok('http://localhost:3010/brapi/v2/calls', "get calls");
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'message' => 'Loading CXGN::BrAPI::v2::Calls','messageType' => 'INFO'},{'messageType' => 'INFO','message' => 'Calls result constructed'}],'datafiles' => [],'pagination' => {'totalPages' => 26750,'totalCount' => 267500,'currentPage' => 0,'pageSize' => 10}},'result' => {'sepUnphased' => undef,'data' => [{'callSetDbId' => '38878','variantDbId' => 'S10114_185859','genotype' => {'values' => '0'},'additionalInfo' => undef,'variantName' => 'S10114_185859','callSetName' => 'UG120001','phaseSet' => undef,'genotype_likelihood' => undef},{'callSetName' => 'UG120001','variantDbId' => 'S10173_777651','genotype' => {'values' => '0'},'variantName' => 'S10173_777651','callSetDbId' => '38878','additionalInfo' => undef,'phaseSet' => undef,'genotype_likelihood' => undef},{'genotype' => {'values' => '2'},'variantDbId' => 'S10173_899514','callSetName' => 'UG120001','callSetDbId' => '38878','variantName' => 'S10173_899514','additionalInfo' => undef,'genotype_likelihood' => undef,'phaseSet' => undef},{'phaseSet' => undef,'genotype_likelihood' => undef,'additionalInfo' => undef,'variantName' => 'S10241_146006','callSetDbId' => '38878','callSetName' => 'UG120001','variantDbId' => 'S10241_146006','genotype' => {'values' => '0'}},{'variantName' => 'S1027_465354','callSetName' => 'UG120001','phaseSet' => undef,'genotype_likelihood' => undef,'callSetDbId' => '38878','genotype' => {'values' => '2'},'variantDbId' => 'S1027_465354','additionalInfo' => undef},{'additionalInfo' => undef,'phaseSet' => undef,'genotype_likelihood' => undef,'callSetName' => 'UG120001','genotype' => {'values' => '0'},'variantDbId' => 'S10367_21679','variantName' => 'S10367_21679','callSetDbId' => '38878'},{'additionalInfo' => undef,'variantDbId' => 'S1046_216535','genotype' => {'values' => '0'},'callSetDbId' => '38878','genotype_likelihood' => undef,'phaseSet' => undef,'callSetName' => 'UG120001','variantName' => 'S1046_216535'},{'variantName' => 'S10493_191533','callSetDbId' => '38878','callSetName' => 'UG120001','variantDbId' => 'S10493_191533','genotype' => {'values' => '1'},'phaseSet' => undef,'genotype_likelihood' => undef,'additionalInfo' => undef},{'additionalInfo' => undef,'genotype' => {'values' => '2'},'variantDbId' => 'S10493_282956','callSetDbId' => '38878','genotype_likelihood' => undef,'phaseSet' => undef,'callSetName' => 'UG120001','variantName' => 'S10493_282956'},{'genotype' => {'values' => '0'},'variantDbId' => 'S10493_529025','callSetDbId' => '38878','additionalInfo' => undef,'callSetName' => 'UG120001','variantName' => 'S10493_529025','phaseSet' => undef,'genotype_likelihood' => undef}],'sepPhased' => undef,'expandHomozygotes' => undef,'unknownString' => undef}}, "calls return data test");

$mech->post_ok('http://localhost:3010/brapi/v2/search/calls', ['callSetDbIds' => ['38878']], "post to calls test");
$response = decode_json $mech->content;
$searchId = $response->{result} ->{searchResultsDbId};
print STDERR Dumper $response;
$mech->get_ok('http://localhost:3010/brapi/v2/search/calls/'. $searchId, "get calls test");
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'genotype_likelihood' => undef,'variantDbId' => 'S10114_185859','additionalInfo' => undef,'callSetDbId' => '38878','phaseSet' => undef,'genotype' => {'values' => '0'},'callSetName' => 'UG120001','variantName' => 'S10114_185859'},{'variantDbId' => 'S10173_777651','genotype_likelihood' => undef,'variantName' => 'S10173_777651','callSetDbId' => '38878','phaseSet' => undef,'additionalInfo' => undef,'callSetName' => 'UG120001','genotype' => {'values' => '0'}},{'variantName' => 'S10173_899514','variantDbId' => 'S10173_899514','genotype_likelihood' => undef,'callSetName' => 'UG120001','genotype' => {'values' => '2'},'callSetDbId' => '38878','phaseSet' => undef,'additionalInfo' => undef},{'variantName' => 'S10241_146006','genotype_likelihood' => undef,'variantDbId' => 'S10241_146006','genotype' => {'values' => '0'},'callSetName' => 'UG120001','additionalInfo' => undef,'phaseSet' => undef,'callSetDbId' => '38878'},{'variantDbId' => 'S1027_465354','genotype_likelihood' => undef,'phaseSet' => undef,'callSetDbId' => '38878','additionalInfo' => undef,'callSetName' => 'UG120001','genotype' => {'values' => '2'},'variantName' => 'S1027_465354'},{'callSetDbId' => '38878','phaseSet' => undef,'additionalInfo' => undef,'callSetName' => 'UG120001','genotype' => {'values' => '0'},'variantDbId' => 'S10367_21679','genotype_likelihood' => undef,'variantName' => 'S10367_21679'},{'genotype' => {'values' => '0'},'callSetName' => 'UG120001','additionalInfo' => undef,'callSetDbId' => '38878','phaseSet' => undef,'variantName' => 'S1046_216535','genotype_likelihood' => undef,'variantDbId' => 'S1046_216535'},{'genotype' => {'values' => '1'},'callSetName' => 'UG120001','additionalInfo' => undef,'phaseSet' => undef,'callSetDbId' => '38878','variantName' => 'S10493_191533','genotype_likelihood' => undef,'variantDbId' => 'S10493_191533'},{'genotype_likelihood' => undef,'variantDbId' => 'S10493_282956','variantName' => 'S10493_282956','additionalInfo' => undef,'callSetDbId' => '38878','phaseSet' => undef,'genotype' => {'values' => '2'},'callSetName' => 'UG120001'},{'variantName' => 'S10493_529025','variantDbId' => 'S10493_529025','genotype_likelihood' => undef,'callSetName' => 'UG120001','genotype' => {'values' => '0'},'callSetDbId' => '38878','phaseSet' => undef,'additionalInfo' => undef}]},'metadata' => {'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'message' => 'Loading CXGN::BrAPI::v2::Results','messageType' => 'INFO'},{'message' => 'search result constructed','messageType' => 'INFO'}],'pagination' => {'currentPage' => 0,'totalPages' => 100,'pageSize' => 10,'totalCount' => 1000},'datafiles' => []}}, "get calls call");

$mech->get_ok('http://localhost:3010/brapi/v2/callsets/?callSetDbId=38879', 'get specific callset');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'studyDbId' => ['140','142'],'variantSetDbIds' => ['140p1','142p1'],'sampleDbId' => '38879','additionalInfo' => {'germplasmDbId' => '38879'},'created' => undef,'updated' => undef,'callSetName' => 'UG120002','callSetDbId' => '38879'}]},'metadata' => {'pagination' => {'totalPages' => 1,'pageSize' => 10,'totalCount' => 1,'currentPage' => 0},'datafiles' => [],'status' => [{'message' => 'BrAPI base call found with page=0, pageSize=10','messageType' => 'INFO'},{'message' => 'Loading CXGN::BrAPI::v2::CallSets','messageType' => 'INFO'},{'messageType' => 'INFO','message' => 'CallSets result constructed'}]}}, "callset call test");

$mech->get_ok('http://localhost:3010/brapi/v2/callsets/38880', "get callset");
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'pagination' => {'currentPage' => 0,'totalCount' => 1,'totalPages' => 1,'pageSize' => 10},'datafiles' => [],'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'message' => 'Loading CXGN::BrAPI::v2::CallSets','messageType' => 'INFO'},{'message' => 'CallSets detail result constructed','messageType' => 'INFO'}]},'result' => {'additionalInfo' => {'germplasmDbId' => '38880'},'variantSetDbIds' => ['140p1','142p1'],'updated' => undef,'created' => undef,'callSetDbId' => '38880','callSetName' => 'UG120003','studyDbId' => ['140','142'],'sampleDbId' => '38880'}}, "callsets detail test");

$mech->get_ok('http://localhost:3010/brapi/v2/callsets/38882/calls', "get calls for callset");
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'sepUnphased' => undef,'data' => [{'additionalInfo' => undef,'callSetDbId' => '38882','phaseSet' => undef,'genotype' => {'values' => '1'},'variantDbId' => 'S10114_185859','callSetName' => 'UG120005','genotype_likelihood' => undef,'variantName' => 'S10114_185859'},{'callSetDbId' => '38882','additionalInfo' => undef,'callSetName' => 'UG120005','variantDbId' => 'S10173_777651','genotype_likelihood' => undef,'variantName' => 'S10173_777651','phaseSet' => undef,'genotype' => {'values' => '0'}},{'genotype_likelihood' => undef,'variantName' => 'S10173_899514','callSetName' => 'UG120005','variantDbId' => 'S10173_899514','genotype' => {'values' => '0'},'phaseSet' => undef,'callSetDbId' => '38882','additionalInfo' => undef},{'callSetDbId' => '38882','additionalInfo' => undef,'genotype_likelihood' => undef,'variantName' => 'S10241_146006','callSetName' => 'UG120005','variantDbId' => 'S10241_146006','genotype' => {'values' => '0'},'phaseSet' => undef},{'callSetDbId' => '38882','additionalInfo' => undef,'variantDbId' => 'S1027_465354','callSetName' => 'UG120005','variantName' => 'S1027_465354','genotype_likelihood' => undef,'phaseSet' => undef,'genotype' => {'values' => '2'}},{'callSetDbId' => '38882','additionalInfo' => undef,'variantName' => 'S10367_21679','genotype_likelihood' => undef,'callSetName' => 'UG120005','variantDbId' => 'S10367_21679','genotype' => {'values' => '0'},'phaseSet' => undef},{'callSetDbId' => '38882','additionalInfo' => undef,'variantName' => 'S1046_216535','genotype_likelihood' => undef,'callSetName' => 'UG120005','variantDbId' => 'S1046_216535','genotype' => {'values' => '0'},'phaseSet' => undef},{'genotype_likelihood' => undef,'variantName' => 'S10493_191533','callSetName' => 'UG120005','variantDbId' => 'S10493_191533','genotype' => {'values' => '2'},'phaseSet' => undef,'callSetDbId' => '38882','additionalInfo' => undef},{'genotype_likelihood' => undef,'variantName' => 'S10493_282956','callSetName' => 'UG120005','variantDbId' => 'S10493_282956','genotype' => {'values' => '2'},'phaseSet' => undef,'callSetDbId' => '38882','additionalInfo' => undef},{'callSetDbId' => '38882','additionalInfo' => undef,'variantDbId' => 'S10493_529025','callSetName' => 'UG120005','genotype_likelihood' => undef,'variantName' => 'S10493_529025','phaseSet' => undef,'genotype' => {'values' => '1'}}],'expandHomozygotes' => undef,'sepPhased' => undef,'unknownString' => undef},'metadata' => {'pagination' => {'totalCount' => 1000,'currentPage' => 0,'totalPages' => 100,'pageSize' => 10},'status' => [{'message' => 'BrAPI base call found with page=0, pageSize=10','messageType' => 'INFO'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::CallSets'},{'messageType' => 'INFO','message' => 'Markerprofiles allelematrix result constructed'}],'datafiles' => []}}, "callsets/<id>/calls test" );

$mech->post_ok('http://localhost:3010/brapi/v2/search/callsets', ['callSetDbIds' => ['38881']], "post to callset search");
$response = decode_json $mech->content;
$searchId = $response->{result} ->{searchResultsDbId};
print STDERR Dumper $response;
$mech->get_ok('http://localhost:3010/brapi/v2/search/callsets/'. $searchId, "get callset search results");
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'additionalInfo' => {'germplasmDbId' => '38881'},'variantSetDbIds' => ['140p1','142p1'],'sampleDbId' => '38881','studyDbId' => ['140','142'],'callSetDbId' => '38881','updated' => undef,'callSetName' => 'UG120004','created' => undef}]},'metadata' => {'pagination' => {'totalPages' => 1,'pageSize' => 10,'currentPage' => 0,'totalCount' => 1},'datafiles' => [],'status' => [{'message' => 'BrAPI base call found with page=0, pageSize=10','messageType' => 'INFO'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::Results'},{'messageType' => 'INFO','message' => 'search result constructed'}]}});

$mech->get_ok('http://localhost:3010/brapi/v2/variantsets/?studyDbId=140', "variantsets call");
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response,  {'result' => {'data' => [{'variantSetName' => 'test_genotyping_project - GBS ApeKI genotyping v4','callSetCount' => 235,'additionalInfo' => {},'variantCount' => 500,'referenceSetDbId' => '1','variantSetDbId' => '140p1','availableFormats' => [{'fileFormat' => 'json','dataFormat' => 'json','fileURL' => undef}],'studyDbId' => '140','analysis' => [{'type' => undef,'updated' => undef,'description' => undef,'analysisDbId' => '1','created' => undef,'software' => undef,'analysisName' => 'GBS ApeKI genotyping v4'}]}]},'metadata' => {'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'message' => 'Loading CXGN::BrAPI::v2::VariantSets','messageType' => 'INFO'},{'message' => 'VariantSets result constructed','messageType' => 'INFO'}],'pagination' => {'totalCount' => 1,'totalPages' => 1,'currentPage' => 0,'pageSize' => 10},'datafiles' => []}}, "variantsets call return data check");

$mech->get_ok('http://localhost:3010/brapi/v2/variantsets/142p1', "get specific variantset");
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'message' => 'Loading CXGN::BrAPI::v2::VariantSets','messageType' => 'INFO'},{'messageType' => 'INFO','message' => 'VariantSets result constructed'}],'pagination' => {'totalCount' => 1,'totalPages' => 1,'currentPage' => 0,'pageSize' => 10},'datafiles' => []},'result' => {'studyDbId' => '142','variantCount' => 500,'referenceSetDbId' => '1','variantSetDbId' => '142p1','variantSetName' => 'test_population2 - GBS ApeKI genotyping v4','availableFormats' => [{'dataFormat' => 'json','fileFormat' => 'json','fileURL' => undef}],'analysis' => [{'description' => undef,'type' => undef,'analysisDbId' => '1','analysisName' => 'GBS ApeKI genotyping v4','created' => undef,'updated' => undef,'software' => undef}],'callSetCount' => 280,'additionalInfo' => {}}}, "check specific variant set return data");

$mech->get_ok('http://localhost:3010/brapi/v2/variantsets/142p1/calls', "get variantset calls");
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'status' => [{'message' => 'BrAPI base call found with page=0, pageSize=10','messageType' => 'INFO'},{'message' => 'Loading CXGN::BrAPI::v2::VariantSets','messageType' => 'INFO'},{'message' => 'VariantSets result constructed','messageType' => 'INFO'}],'pagination' => {'totalPages' => 14000,'totalCount' => 140000,'pageSize' => 10,'currentPage' => 0},'datafiles' => []},'result' => {'unknownString' => undef,'expandHomozygotes' => undef,'sepUnphased' => undef,'data' => [{'phaseSet' => undef,'variantName' => 'S10114_185859','additionalInfo' => {},'callSetDbId' => '38878','variantDbId' => 'S10114_185859','genotype' => {'values' => '0'},'callSetName' => 'UG120001','genotype_likelihood' => undef},{'genotype_likelihood' => undef,'callSetDbId' => '38878','additionalInfo' => {},'variantName' => 'S10173_777651','genotype' => {'values' => '0'},'callSetName' => 'UG120001','variantDbId' => 'S10173_777651','phaseSet' => undef},{'phaseSet' => undef,'callSetName' => 'UG120001','genotype' => {'values' => '2'},'variantDbId' => 'S10173_899514','callSetDbId' => '38878','additionalInfo' => {},'variantName' => 'S10173_899514','genotype_likelihood' => undef},{'genotype' => {'values' => '0'},'callSetName' => 'UG120001','variantDbId' => 'S10241_146006','additionalInfo' => {},'callSetDbId' => '38878','variantName' => 'S10241_146006','phaseSet' => undef,'genotype_likelihood' => undef},{'phaseSet' => undef,'genotype_likelihood' => undef,'callSetName' => 'UG120001','genotype' => {'values' => '2'},'variantDbId' => 'S1027_465354','callSetDbId' => '38878','additionalInfo' => {},'variantName' => 'S1027_465354'},{'genotype_likelihood' => undef,'variantName' => 'S10367_21679','additionalInfo' => {},'callSetDbId' => '38878','variantDbId' => 'S10367_21679','callSetName' => 'UG120001','genotype' => {'values' => '0'},'phaseSet' => undef},{'phaseSet' => undef,'callSetName' => 'UG120001','genotype' => {'values' => '0'},'variantDbId' => 'S1046_216535','additionalInfo' => {},'callSetDbId' => '38878','variantName' => 'S1046_216535','genotype_likelihood' => undef},{'genotype' => {'values' => '1'},'callSetName' => 'UG120001','variantDbId' => 'S10493_191533','additionalInfo' => {},'callSetDbId' => '38878','variantName' => 'S10493_191533','phaseSet' => undef,'genotype_likelihood' => undef},{'phaseSet' => undef,'genotype_likelihood' => undef,'variantName' => 'S10493_282956','additionalInfo' => {},'callSetDbId' => '38878','variantDbId' => 'S10493_282956','callSetName' => 'UG120001','genotype' => {'values' => '2'}},{'phaseSet' => undef,'variantDbId' => 'S10493_529025','callSetName' => 'UG120001','genotype' => {'values' => '0'},'variantName' => 'S10493_529025','callSetDbId' => '38878','additionalInfo' => {},'genotype_likelihood' => undef}],'sepPhased' => undef}}, "check vriantset calls return data");

$mech->get_ok('http://localhost:3010/brapi/v2/variantsets/140p1/callsets', "get callsets in variantset");
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'datafiles' => [],'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::VariantSets'},{'message' => 'VariantSets result constructed','messageType' => 'INFO'}],'pagination' => {'currentPage' => 0,'pageSize' => 10,'totalPages' => 24,'totalCount' => 235}},'result' => {'data' => [{'additionalInfo' => {},'callSetDbId' => '38878','callSetName' => 'UG120001','created' => undef,'sampleDbId' => '38878','updated' => undef,'studyDbId' => '140','variantSetDbIds' => ['140p1']},{'callSetName' => 'UG120002','callSetDbId' => '38879','additionalInfo' => {},'sampleDbId' => '38879','created' => undef,'studyDbId' => '140','updated' => undef,'variantSetDbIds' => ['140p1']},{'updated' => undef,'studyDbId' => '140','variantSetDbIds' => ['140p1'],'callSetName' => 'UG120003','additionalInfo' => {},'callSetDbId' => '38880','sampleDbId' => '38880','created' => undef},{'updated' => undef,'studyDbId' => '140','variantSetDbIds' => ['140p1'],'callSetName' => 'UG120004','callSetDbId' => '38881','additionalInfo' => {},'sampleDbId' => '38881','created' => undef},{'studyDbId' => '140','updated' => undef,'variantSetDbIds' => ['140p1'],'additionalInfo' => {},'callSetDbId' => '38882','callSetName' => 'UG120005','created' => undef,'sampleDbId' => '38882'},{'studyDbId' => '140','updated' => undef,'variantSetDbIds' => ['140p1'],'additionalInfo' => {},'callSetDbId' => '38883','callSetName' => 'UG120006','sampleDbId' => '38883','created' => undef},{'callSetName' => 'UG120007','additionalInfo' => {},'callSetDbId' => '38884','created' => undef,'sampleDbId' => '38884','updated' => undef,'studyDbId' => '140','variantSetDbIds' => ['140p1']},{'created' => undef,'sampleDbId' => '38885','callSetDbId' => '38885','additionalInfo' => {},'callSetName' => 'UG120008','variantSetDbIds' => ['140p1'],'studyDbId' => '140','updated' => undef},{'studyDbId' => '140','updated' => undef,'variantSetDbIds' => ['140p1'],'callSetDbId' => '38886','additionalInfo' => {},'callSetName' => 'UG120009','sampleDbId' => '38886','created' => undef},{'variantSetDbIds' => ['140p1'],'updated' => undef,'studyDbId' => '140','sampleDbId' => '38887','created' => undef,'callSetDbId' => '38887','additionalInfo' => {},'callSetName' => 'UG120010'}]}}, "check return data for fallsets in variantset");

#no data for variants
# $mech->get_ok('http://localhost:3010/brapi/v2/variants');
# $response = decode_json $mech->content;
# print STDERR Dumper $response;
# $mech->get_ok('http://localhost:3010/brapi/v2/variantsets/140p1/variants');
# $response = decode_json $mech->content;
# print STDERR Dumper $response;


$mech->post_ok('http://localhost:3010/brapi/v2/search/variantsets', ['variantSetDbIds' => ['143p1']], "post to variantset search");
$response = decode_json $mech->content;
$searchId = $response->{result} ->{searchResultsDbId};
$mech->get_ok('http://localhost:3010/brapi/v2/search/variantsets/'. $searchId, "get search variantset results");
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'availableFormats' => [{'dataFormat' => 'json','fileFormat' => 'json','fileURL' => undef}],'variantSetName' => 'selection_population - GBS ApeKI genotyping v4','analysis' => [{'analysisDbId' => '1','updated' => undef,'description' => undef,'created' => undef,'software' => undef,'type' => undef,'analysisName' => 'GBS ApeKI genotyping v4'}],'additionalInfo' => {},'callSetCount' => 20,'studyDbId' => '143','referenceSetDbId' => '1','variantCount' => 500,'variantSetDbId' => '143p1'}]},'metadata' => {'status' => [{'message' => 'BrAPI base call found with page=0, pageSize=10','messageType' => 'INFO'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::Results'},{'messageType' => 'INFO','message' => 'search result constructed'}],'pagination' => {'totalPages' => 1,'totalCount' => 1,'pageSize' => 10,'currentPage' => 0},'datafiles' => []}}, "check return data from vriantset search");

$mech->post_ok('http://localhost:3010/brapi/v2/variantsets/extract', ['variantSetDbIds' => ['142p1']], "extract variantset");
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'callSetCount' => 280,'variantSetDbId' => '142p1','variantCount' => 500,'studyDbId' => '142','referenceSetDbId' => '1','variantSetName' => 'test_population2 - GBS ApeKI genotyping v4','availableFormats' => [{'fileURL' => undef,'fileFormat' => 'json','dataFormat' => 'json'}],'additionalInfo' => {},'analysis' => [{'software' => undef,'description' => undef,'created' => undef,'analysisName' => 'GBS ApeKI genotyping v4','type' => undef,'analysisDbId' => '1','updated' => undef}]}]},'metadata' => {'datafiles' => [],'pagination' => {'totalCount' => 1,'totalPages' => 1,'pageSize' => 10,'currentPage' => 0},'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::VariantSets'},{'messageType' => 'INFO','message' => 'VariantSets result constructed'}]}}, "extract variantset data");

$f->clean_up_db();

done_testing();
