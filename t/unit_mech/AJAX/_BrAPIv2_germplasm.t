
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use LWP::UserAgent;
use CXGN::BreederSearch;

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
print STDERR "\n\n" . Dumper $response;
#1
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
#2
is($response->{'userDisplayName'}, 'Jane Doe');
#3
is($response->{'expires_in'}, '7200');

$mech->delete_ok('http://localhost:3010/brapi/v2/token');
$response = decode_json $mech->content;
print STDERR "\n\n" . Dumper $response;
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
is($response->{'expires_in'}, '7200');
my $access_token = $response->{access_token};

$ua->default_header("Content-Type" => "application/json");
$ua->default_header('Authorization'=> 'Bearer ' . $access_token);
$mech->default_header("Content-Type" => "application/json");
$mech->default_header('Authorization'=> 'Bearer ' . $access_token);


$mech->get_ok('http://localhost:3010/brapi/v2/germplasm?pageSize=3');
$response = decode_json $mech->content;
print STDERR "\n\n" . Dumper $response;
is_deeply($response, {'result' => {'data' => [{'subtaxa' => undef,'germplasmPUI' => 'http://localhost:3010/stock/40326/view','species' => undef,'subtaxaAuthority' => undef,'biologicalStatusOfAccessionCode' => 0,'donors' => [{'donorAccessionNumber' => undef,'donorInstituteCode' => undef}],'commonCropName' => undef,'speciesAuthority' => undef,'additionalInfo' => undef,'germplasmName' => 'BLANK','externalReferences' => [],'instituteCode' => '','taxonIds' => [],'storageTypes' => [],'defaultDisplayName' => 'BLANK','acquisitionDate' => undef,'biologicalStatusOfAccessionDescription' => undef,'documentationURL' => 'http://localhost:3010/stock/40326/view','countryOfOriginCode' => '','seedSourceDescription' => '','pedigree' => 'NA/NA','synonyms' => [],'germplasmOrigin' => [],'collection' => undef,'instituteName' => '','accessionNumber' => '','germplasmPreprocessing' => undef,'seedSource' => '','genus' => undef,'germplasmDbId' => '40326','breedingMethodDbId' => 'unknown'},{'germplasmPUI' => 'http://localhost:3010/stock/41279/view','subtaxa' => undef,'species' => 'Manihot esculenta','germplasmName' => 'IITA-TMS-IBA30572','additionalInfo' => undef,'externalReferences' => [],'biologicalStatusOfAccessionCode' => 0,'donors' => [{'donorInstituteCode' => undef,'donorAccessionNumber' => undef}],'subtaxaAuthority' => undef,'speciesAuthority' => undef,'commonCropName' => undef,'countryOfOriginCode' => '','storageTypes' => [],'defaultDisplayName' => 'IITA-TMS-IBA30572','instituteCode' => '','taxonIds' => [],'documentationURL' => 'http://localhost:3010/stock/41279/view','acquisitionDate' => undef,'biologicalStatusOfAccessionDescription' => undef,'seedSource' => '','genus' => 'Manihot','accessionNumber' => '','germplasmPreprocessing' => undef,'breedingMethodDbId' => 'unknown','germplasmDbId' => '41279','seedSourceDescription' => '','pedigree' => 'NA/NA','germplasmOrigin' => [],'synonyms' => [],'collection' => undef,'instituteName' => ''},{'species' => 'Manihot esculenta','germplasmPUI' => 'http://localhost:3010/stock/41281/view','subtaxa' => undef,'externalReferences' => [],'germplasmName' => 'IITA-TMS-IBA011412','additionalInfo' => undef,'speciesAuthority' => undef,'commonCropName' => undef,'biologicalStatusOfAccessionCode' => 0,'donors' => [{'donorAccessionNumber' => undef,'donorInstituteCode' => undef}],'subtaxaAuthority' => undef,'countryOfOriginCode' => '','documentationURL' => 'http://localhost:3010/stock/41281/view','acquisitionDate' => undef,'biologicalStatusOfAccessionDescription' => undef,'defaultDisplayName' => 'IITA-TMS-IBA011412','storageTypes' => [],'instituteCode' => '','taxonIds' => [],'breedingMethodDbId' => 'unknown','germplasmDbId' => '41281','seedSource' => '','genus' => 'Manihot','accessionNumber' => '','germplasmPreprocessing' => undef,'synonyms' => [],'germplasmOrigin' => [],'collection' => undef,'instituteName' => '','seedSourceDescription' => '','pedigree' => 'NA/NA'}]},'metadata' => {'pagination' => {'totalPages' => 160,'totalCount' => 479,'pageSize' => 3,'currentPage' => 0},'status' => [{'message' => 'BrAPI base call found with page=0, pageSize=3','messageType' => 'INFO'},{'message' => 'Loading CXGN::BrAPI::v2::Germplasm','messageType' => 'INFO'},{'message' => 'Germplasm result constructed','messageType' => 'INFO'}],'datafiles' => []}});


$mech->get_ok('http://localhost:3010/brapi/v2/germplasm/41281');
$response = decode_json $mech->content;
print STDERR "\n\n" . Dumper $response;
is_deeply($response, {'result' => {'biologicalStatusOfAccessionDescription' => undef,'acquisitionDate' => undef,'documentationURL' => 'http://localhost:3010/stock/41281/view','instituteCode' => '','taxonIds' => [],'storageTypes' => [],'defaultDisplayName' => 'IITA-TMS-IBA011412','countryOfOriginCode' => '','instituteName' => '','collection' => undef,'germplasmOrigin' => [],'synonyms' => [],'pedigree' => 'NA/NA','seedSourceDescription' => '','germplasmDbId' => '41281','breedingMethodDbId' => 'unknown','germplasmPreprocessing' => undef,'accessionNumber' => '','genus' => 'Manihot','seedSource' => '','species' => 'Manihot esculenta','subtaxa' => undef,'germplasmPUI' => 'http://localhost:3010/stock/41281/view','commonCropName' => undef,'speciesAuthority' => undef,'subtaxaAuthority' => undef,'donors' => [{'donorInstituteCode' => undef,'donorAccessionNumber' => undef}],'biologicalStatusOfAccessionCode' => 0,'externalReferences' => [],'additionalInfo' => undef,'germplasmName' => 'IITA-TMS-IBA011412'},'metadata' => {'datafiles' => [],'status' => [{'message' => 'BrAPI base call found with page=0, pageSize=10','messageType' => 'INFO'},{'message' => 'Loading CXGN::BrAPI::v2::Germplasm','messageType' => 'INFO'},{'messageType' => 'INFO','message' => 'Germplasm detail result constructed'}],'pagination' => {'totalCount' => 1,'pageSize' => 10,'currentPage' => 0,'totalPages' => 1}}});


$mech->get_ok('http://localhost:3010/brapi/v2/germplasm/38843/progeny');
$response = decode_json $mech->content;
print STDERR "\n\n" . Dumper $response;
is_deeply($response, {'metadata' => {'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::Germplasm'},{'message' => 'Germplasm progeny result constructed','messageType' => 'INFO'}],'pagination' => {'totalCount' => 15,'totalPages' => 1,'pageSize' => 15,'currentPage' => 0},'datafiles' => []},'result' => {'germplasmName' => 'test_accession4','progeny' => [{'parentType' => 'FEMALE','germplasmDbId' => '38846','germplasmName' => 'new_test_crossP001'},{'germplasmName' => 'new_test_crossP002','germplasmDbId' => '38847','parentType' => 'FEMALE'},{'parentType' => 'FEMALE','germplasmName' => 'new_test_crossP003','germplasmDbId' => '38848'},{'parentType' => 'FEMALE','germplasmName' => 'new_test_crossP004','germplasmDbId' => '38849'},{'parentType' => 'FEMALE','germplasmName' => 'new_test_crossP005','germplasmDbId' => '38850'},{'germplasmDbId' => '38851','germplasmName' => 'new_test_crossP006','parentType' => 'FEMALE'},{'germplasmName' => 'new_test_crossP007','germplasmDbId' => '38852','parentType' => 'FEMALE'},{'parentType' => 'FEMALE','germplasmName' => 'new_test_crossP008','germplasmDbId' => '38853'},{'parentType' => 'FEMALE','germplasmName' => 'new_test_crossP009','germplasmDbId' => '38854'},{'parentType' => 'FEMALE','germplasmName' => 'new_test_crossP010','germplasmDbId' => '38855'},{ 'germplasmName' => 'test5P001', 'parentType' => 'FEMALE', 'germplasmDbId' => '38873' },{ 'parentType' => 'FEMALE', 'germplasmDbId' => '38874', 'germplasmName' => 'test5P002' },{ 'germplasmName' => 'test5P003', 'parentType' => 'FEMALE', 'germplasmDbId' => '38875' },{ 'parentType' => 'FEMALE', 'germplasmDbId' => '38876', 'germplasmName' => 'test5P004' },{ 'germplasmName' => 'test5P005', 'parentType' => 'FEMALE', 'germplasmDbId' => '38877' } ],'germplasmDbId' => '38843'}});

$mech->get_ok('http://localhost:3010/brapi/v2/germplasm/41279/mcpd');
$response = decode_json $mech->content;
print STDERR "\n\n" . Dumper $response;
is_deeply($response, {'metadata' => {'pagination' => {'totalCount' => 1,'totalPages' => 1,'currentPage' => 0,'pageSize' => 10},'datafiles' => [],'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'message' => 'Loading CXGN::BrAPI::v2::Germplasm','messageType' => 'INFO'},{'messageType' => 'INFO','message' => 'Germplasm detail result constructed'}]},'result' => {'storageTypeCodes' => [],'germplasmPUI' => '','collectingInfo' => {},'breedingInstitutes' => {'instituteCode' => '','instituteName' => ''},'safetyDuplicateInstitutes' => undef,'genus' => 'Manihot','species' => 'Manihot esculenta','subtaxonAuthority' => undef,'commonCropName' => undef,'remarks' => undef,'alternateIDs' => [41279],'donorInfo' => [],'speciesAuthority' => undef,'biologicalStatusOfAccessionCode' => 0,'instituteCode' => '','accessionNames' => ['IITA-TMS-IBA30572','IITA-TMS-IBA30572'],'mlsStatus' => undef,'accessionNumber' => '','acquisitionDate' => undef,'germplasmDbId' => '41279','subtaxon' => undef,'ancestralData' => 'NA/NA','countryOfOrigin' => ''}});

$mech->get_ok('http://localhost:3010/brapi/v2/germplasm/38876/pedigree');
$response = decode_json $mech->content;
print STDERR "\n\n" . Dumper $response;
is_deeply($response, {'metadata' => {'pagination' => {'currentPage' => 0,'pageSize' => 1,'totalPages' => 1,'totalCount' => 1},'datafiles' => [],'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::Germplasm'},{'messageType' => 'INFO','message' => 'Germplasm pedigree result constructed'}]},'result' => {'germplasmName' => 'test5P004','germplasmDbId' => '38876','crossingProjectDbId' => undef,'familyCode' => undef,'pedigree' => 'test_accession4/test_accession5','parents' => [{'parentType' => 'FEMALE','germplasmName' => 'test_accession4','germplasmDbId' => '38843'},{'germplasmDbId' => '38844','germplasmName' => 'test_accession5','parentType' => 'MALE'}],'crossingYear' => undef,'siblings' => [{'germplasmName' => 'new_test_crossP001','germplasmDbId' => '38846'},{'germplasmDbId' => '38847','germplasmName' => 'new_test_crossP002'},{'germplasmDbId' => '38848','germplasmName' => 'new_test_crossP003'},{'germplasmName' => 'new_test_crossP004','germplasmDbId' => '38849'},{'germplasmDbId' => '38850','germplasmName' => 'new_test_crossP005'},{'germplasmName' => 'new_test_crossP006','germplasmDbId' => '38851'},{'germplasmDbId' => '38852','germplasmName' => 'new_test_crossP007'},{'germplasmName' => 'new_test_crossP008','germplasmDbId' => '38853'},{'germplasmDbId' => '38854','germplasmName' => 'new_test_crossP009'},{'germplasmName' => 'new_test_crossP010','germplasmDbId' => '38855'},{'germplasmDbId' => '38873','germplasmName' => 'test5P001'},{'germplasmDbId' => '38874','germplasmName' => 'test5P002'},{'germplasmDbId' => '38875','germplasmName' => 'test5P003'},{'germplasmName' => 'test5P005','germplasmDbId' => '38877'}]}});

$mech->post_ok('http://localhost:3010/brapi/v2/search/germplasm', ['germplasmDbIds' => ['40326']]);
$response = decode_json $mech->content;
$searchId = $response->{result} ->{searchResultsDbId};
print STDERR "\n\n" . Dumper $response;
$mech->get_ok('http://localhost:3010/brapi/v2/search/germplasm/'. $searchId);
$response = decode_json $mech->content;
print STDERR "\n\n" . Dumper $response;
is_deeply($response, {'metadata' => {'pagination' => {'totalPages' => 1,'currentPage' => 0,'totalCount' => 1,'pageSize' => 10},'status' => [{'message' => 'BrAPI base call found with page=0, pageSize=10','messageType' => 'INFO'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::Results'},{'messageType' => 'INFO','message' => 'search result constructed'}],'datafiles' => []},'result' => {'data' => [{'germplasmName' => 'BLANK','externalReferences' => [],'storageTypes' => [],'genus' => undef,'acquisitionDate' => undef,'subtaxa' => undef,'subtaxaAuthority' => undef,'accessionNumber' => '','donors' => [{'donorAccessionNumber' => undef,'donorInstituteCode' => undef}],'biologicalStatusOfAccessionDescription' => undef,'seedSource' => '','pedigree' => 'NA/NA','germplasmOrigin' => [],'countryOfOriginCode' => '','collection' => undef,'documentationURL' => 'http://localhost:3010/stock/40326/view','breedingMethodDbId' => 'unknown','seedSourceDescription' => '','biologicalStatusOfAccessionCode' => 0,'instituteName' => '','germplasmPUI' => 'http://localhost:3010/stock/40326/view','commonCropName' => undef,'germplasmDbId' => '40326','taxonIds' => [],'instituteCode' => '','additionalInfo' => undef,'speciesAuthority' => undef,'species' => undef,'germplasmPreprocessing' => undef,'defaultDisplayName' => 'BLANK','synonyms' => []}]}});



$mech->get_ok('http://localhost:3010/brapi/v2/crossingprojects/?pageSize=6');
$response = decode_json $mech->content;
print STDERR "\n\nCROSSING PROJECTS RESPONSE: " . Dumper $response;
#$response->{metadata}->{pagination}= {};

my $expected_results = {'data' => [{'commonCropName' => undef,'externalReferences' => [],'additionalInfo' => {},'crossingProjectDescription' => 'CASS_6Genotypes_Sampling_2015','programDbId' => '134','programName' => 'test','crossingProjectDbId' => '165','crossingProjectName' => 'CASS_6Genotypes_Sampling_2015'},{'commonCropName' => undef,'externalReferences' => [],'crossingProjectDescription' => 'Kasese solgs trial','additionalInfo' => {},'programName' => 'test','programDbId' => '134','crossingProjectDbId' => '139','crossingProjectName' => 'Kasese solgs trial'},{'crossingProjectDbId' => '135','crossingProjectName' => 'new_test_cross','additionalInfo' => {},'crossingProjectDescription' => 'new_test_cross','externalReferences' => [],'programName' => 'test','programDbId' => '134','commonCropName' => undef},{'programName' => 'test','programDbId' => '134','externalReferences' => [],'additionalInfo' => {},'crossingProjectDescription' => 'test_t','commonCropName' => undef,'crossingProjectName' => 'test_t','crossingProjectDbId' => '144'},{'crossingProjectName' => 'test_trial','crossingProjectDbId' => '137','commonCropName' => undef,'programDbId' => '134','programName' => 'test','additionalInfo' => {},'crossingProjectDescription' => 'test_trial','externalReferences' => []},{'crossingProjectName' => 'trial2 NaCRRI','crossingProjectDbId' => '141','programDbId' => '134','programName' => 'test','externalReferences' => [],'additionalInfo' => {},'crossingProjectDescription' => 'trial2 NaCRRI','commonCropName' => undef}]};

print STDERR "\n\nCROSSING PROJECTS EXPECTED: ".Dumper($expected_results);

is_deeply($response->{result}, $expected_results, "testing crossing projects");

$mech->get_ok('http://localhost:3010/brapi/v2/crossingprojects/139');
$response = decode_json $mech->content;
print STDERR "\n\n" . Dumper $response;
is_deeply($response, {'metadata' => {'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::Crossing'},{'message' => 'Crossing projects result constructed','messageType' => 'INFO'}],'pagination' => {'currentPage' => 0,'totalCount' => 1,'pageSize' => 10,'totalPages' => 1},'datafiles' => []},'result' => {'programName' => 'test','commonCropName' => undef,'crossingProjectName' => 'Kasese solgs trial','crossingProjectDescription' => 'Kasese solgs trial','programDbId' => '134','crossingProjectDbId' => '139','additionalInfo' => {},'externalReferences' => []}});

$mech->get_ok('http://localhost:3010/brapi/v2/breedingmethods');
$response = decode_json $mech->content;
print STDERR "\n\nBREEDING METHODS RESPONSE:" . Dumper $response;

my $expected_response = {'metadata' => {'pagination' => {'totalPages' => 1,'currentPage' => 0,'pageSize' => 10,'totalCount' => 1},'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::BreedingMethods'},{'message' => 'Breeding methods result constructed','messageType' => 'INFO'}],'datafiles' => []},'result' => {'data' => [{'breedingMethodName' => 'doubled_haploid','description' => 'doubled_haploid','breedingMethodDbId' => 'doubled_haploid','abbreviation' => 'doubled_haploid'},{'description' => 'self','breedingMethodDbId' => 'self','breedingMethodName' => 'self','abbreviation' => 'self'},{'description' => 'open','breedingMethodDbId' => 'open','breedingMethodName' => 'open','abbreviation' => 'open'},{'breedingMethodDbId' => 'bulk','description' => 'bulk','breedingMethodName' => 'bulk','abbreviation' => 'bulk'},{'abbreviation' => 'bulk_self','breedingMethodName' => 'bulk_self','description' => 'bulk_self','breedingMethodDbId' => 'bulk_self'},{'abbreviation' => 'biparental','description' => 'biparental','breedingMethodDbId' => 'biparental','breedingMethodName' => 'biparental'},{'abbreviation' => 'bulk_open','breedingMethodDbId' => 'bulk_open','description' => 'bulk_open','breedingMethodName' => 'bulk_open'}]}};

print STDERR "BREEDING METHODS EXPECTED: ".Dumper($expected_response);

# response has different order if run individually or together with other tests; sort to prevent test failure
#
my $expected_response_sorted = sort { $a->{breedingMethodName} cmp $b->{breedingMethodName} } @{$expected_response->{result}->{data}};

my $response_sorted = sort { $a->{breedingMethodName} cmp $b->{breedingMethodName} } @{$response->{result}->{data}};

is_deeply($response_sorted, $expected_response_sorted, "breeding methods test");

$mech->get_ok('http://localhost:3010/brapi/v2/seedlots');
$response = decode_json $mech->content;
print STDERR "\n\nSEEDSLOTS RESPONSE: " . Dumper $response;
foreach my $t (@{$response->{result}->{data}}) {
    $t->{storageLocation} = "NA";
}

is_deeply($response, {'result' => {'data' => [{'additionalInfo' => {},'lastUpdated' => undef,'programDbId' => '134','programName' => 'test','amount' => '1','externalReferences' => [],'seedLotName' => 'new_test_crossP001_001','seedLotDbId' => '41305','sourceCollection' => undef,'createdDate' => undef,'storageLocation' => 'NA','units' => 'seeds','seedLotDescription' => '','contentMixture' => [{ 'crossName' => undef, 'crossDbId' => undef, 'mixturePercentage' => 100,'germplasmName' => 'new_test_crossP001','germplasmDbId' => '38846' } ],'locationDbId' => '25','locationName' => 'Location 2'},{'seedLotDescription' => '','contentMixture' => [{ 'crossName' => undef, 'crossDbId' => undef, 'mixturePercentage' => 100,'germplasmName' => 'new_test_crossP002','germplasmDbId' => '38847' } ],'locationDbId' => '25','locationName' => 'Location 2','externalReferences' => [],'sourceCollection' => undef,'seedLotDbId' => '41306','seedLotName' => 'new_test_crossP002_001','storageLocation' => 'NA','createdDate' => undef,'units' => 'seeds','programDbId' => '134','programName' => 'test','lastUpdated' => undef,'amount' => '1','additionalInfo' => {}},{'programDbId' => '134','programName' => 'test','lastUpdated' => undef,'contentMixture' => [{ 'crossName' => undef, 'crossDbId' => undef, 'mixturePercentage' => 100,'germplasmName' => 'new_test_crossP003','germplasmDbId' => '38848' } ],'amount' => '1','additionalInfo' => {},'seedLotDescription' => '','locationDbId' => '25','locationName' => 'Location 2','seedLotDbId' => '41307','seedLotName' => 'new_test_crossP003_001','sourceCollection' => undef,'externalReferences' => [],'units' => 'seeds','storageLocation' => 'NA','createdDate' => undef},{'units' => 'seeds','createdDate' => undef,'storageLocation' => 'NA','sourceCollection' => undef,'seedLotDbId' => '41308','seedLotName' => 'new_test_crossP004_001','externalReferences' => [],'locationDbId' => '25','locationName' => 'Location 2','seedLotDescription' => '','additionalInfo' => {},'contentMixture' => [{ 'crossName' => undef, 'crossDbId' => undef, 'mixturePercentage' => 100,'germplasmName' => 'new_test_crossP004','germplasmDbId' => '38849' } ],'amount' => '1','lastUpdated' => undef,'programDbId' => '134', 'programName' => 'test'},{'sourceCollection' => undef,'seedLotName' => 'new_test_crossP005_001','seedLotDbId' => '41309','externalReferences' => [],'units' => 'seeds','storageLocation' => 'NA','createdDate' => undef,'seedLotDescription' => '','locationDbId' => '25','locationName' => 'Location 2','additionalInfo' => {},'programDbId' => '134','programName' => 'test','lastUpdated' => undef,'contentMixture' => [{ 'crossName' => undef, 'crossDbId' => undef, 'mixturePercentage' => 100,'germplasmName' => 'new_test_crossP005','germplasmDbId' => '38850' } ],'amount' => '1'},{'seedLotDescription' => '','locationDbId' => '25','locationName' => 'Location 2','externalReferences' => [],'seedLotName' => 'new_test_crossP006_001','sourceCollection' => undef,'seedLotDbId' => '41310','storageLocation' => 'NA','createdDate' => undef,'units' => 'seeds','programDbId' => '134','programName' => 'test','lastUpdated' => undef,'amount' => '1', 'contentMixture' => [{ 'crossName' => undef, 'crossDbId' => undef, 'mixturePercentage' => 100,'germplasmName' => 'new_test_crossP006','germplasmDbId' => '38851' } ], 'additionalInfo' => {}},{'locationDbId' => '25','locationName' => 'Location 2','seedLotDescription' => '','units' => 'seeds','createdDate' => undef,'storageLocation' => 'NA','seedLotName' => 'new_test_crossP007_001','seedLotDbId' => '41311','sourceCollection' => undef,'externalReferences' => [],'contentMixture' => [{ 'crossName' => undef, 'crossDbId' => undef, 'mixturePercentage' => 100,'germplasmName' => 'new_test_crossP007','germplasmDbId' => '38852' } ],'amount' => '1','lastUpdated' => undef,'programDbId' => '134','programName' => 'test','additionalInfo' => {}},{'createdDate' => undef,'storageLocation' => 'NA','units' => 'seeds','externalReferences' => [],'sourceCollection' => undef,'seedLotName' => 'new_test_crossP008_001','seedLotDbId' => '41312','locationDbId' => '25','locationName' => 'Location 2','seedLotDescription' => '','additionalInfo' => {},'amount' => '1','lastUpdated' => undef,'programDbId' => '134','programName' => 'test','contentMixture' => [{ 'crossName' => undef, 'crossDbId' => undef, 'mixturePercentage' => 100,'germplasmName' => 'new_test_crossP008','germplasmDbId' => '38853' } ]},{'additionalInfo' => {},'amount' => '1','contentMixture' => [{ 'crossName' => undef, 'crossDbId' => undef, 'mixturePercentage' => 100,'germplasmName' => 'test_accession4','germplasmDbId' => '38843' } ],'lastUpdated' => undef,'programDbId' => '134','programName' => 'test', 'createdDate' => undef,'storageLocation' => 'NA','units' => 'seeds','externalReferences' => [],'seedLotName' => 'test_accession4_001','sourceCollection' => undef,'seedLotDbId' => '41303','locationDbId' => '25','locationName' => 'Location 2','seedLotDescription' => ''},{'seedLotDescription' => '','locationDbId' => '25','locationName' => 'Location 2','seedLotName' => 'test_accession5_001','seedLotDbId' => '41304','sourceCollection' => undef,'externalReferences' => [],'units' => 'seeds','storageLocation' => 'NA','createdDate' => undef,'programDbId' => '134','programName' => 'test','lastUpdated' => undef,'contentMixture' => [{ 'crossName' => undef, 'crossDbId' => undef, 'mixturePercentage' => 100,'germplasmName' => 'test_accession5','germplasmDbId' => '38844' } ],'amount' => '1','additionalInfo' => {}}]},'metadata' => {'status' => [{'message' => 'BrAPI base call found with page=0, pageSize=10','messageType' => 'INFO'},{'message' => 'Loading CXGN::BrAPI::v2::SeedLots','messageType' => 'INFO'},{'message' => 'Seed lots result constructed','messageType' => 'INFO'}],'pagination' => {'totalCount' => 479,'pageSize' => 10,'currentPage' => 0,'totalPages' => 48},'datafiles' => []}});

$mech->get_ok('http://localhost:3010/brapi/v2/seedlots/transactions');
$response = decode_json $mech->content;

foreach my $t (@{$response->{result}->{data}}) {
    $t->{transactionDbId} = "NA";
    $t->{toSeedLotDbId} = "NA";
    $t->{fromSeedLotDbId} = "NA";
    $t->{transactionTimestamp} = "NA";
    $t->{amount} = "NA";
}

print STDERR "CLEANED RESPONSE: ". Dumper $response;

my $data_expected = { 'metadata' => {'pagination' => {'pageSize' => 10,'totalCount' => 479,'currentPage' => 0,'totalPages' => 48},'status' => [{'message' => 'BrAPI base call found with page=0, pageSize=10','messageType' => 'INFO'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::SeedLots'},{'messageType' => 'INFO','message' => 'Transactions result constructed'}],'datafiles' => []},'result' => {'data' => [{'additionalInfo' => {},'transactionDbId' => 'NA','toSeedLotDbId' => 'NA','externalReferences' => [],'fromSeedLotDbId' => 'NA','units' => 'seeds','transactionDescription' => 'Auto generated seedlot from accession. DbPatch 00085','transactionTimestamp' => 'NA','amount' => 'NA'},{'transactionTimestamp' => 'NA','amount' => 'NA','transactionDescription' => 'Auto generated seedlot from accession. DbPatch 00085','toSeedLotDbId' => 'NA','fromSeedLotDbId' => 'NA','units' => 'seeds','externalReferences' => [],'transactionDbId' => 'NA','additionalInfo' => {}},{'units' => 'seeds','fromSeedLotDbId' => 'NA','externalReferences' => [],'toSeedLotDbId' => 'NA','transactionDbId' => 'NA','additionalInfo' => {},'amount' => 'NA','transactionTimestamp' => 'NA','transactionDescription' => 'Auto generated seedlot from accession. DbPatch 00085'},{'transactionTimestamp' => 'NA','amount' => 'NA','transactionDescription' => 'Auto generated seedlot from accession. DbPatch 00085','externalReferences' => [],'units' => 'seeds','fromSeedLotDbId' => 'NA','toSeedLotDbId' => 'NA','additionalInfo' => {},'transactionDbId' => 'NA'},{'amount' => 'NA','transactionTimestamp' => 'NA','transactionDescription' => 'Auto generated seedlot from accession. DbPatch 00085','toSeedLotDbId' => 'NA','externalReferences' => [],'fromSeedLotDbId' => 'NA','units' => 'seeds','additionalInfo' => {},'transactionDbId' => 'NA'},{'externalReferences' => [],'units' => 'seeds','fromSeedLotDbId' => 'NA','toSeedLotDbId' => 'NA','additionalInfo' => {},'transactionDbId' => 'NA','amount' => 'NA','transactionTimestamp' => 'NA','transactionDescription' => 'Auto generated seedlot from accession. DbPatch 00085'},{'transactionDbId' => 'NA','additionalInfo' => {},'units' => 'seeds','fromSeedLotDbId' => 'NA','externalReferences' => [],'toSeedLotDbId' => 'NA','transactionDescription' => 'Auto generated seedlot from accession. DbPatch 00085','transactionTimestamp' => 'NA','amount' => 'NA'},{'toSeedLotDbId' => 'NA','fromSeedLotDbId' => 'NA','units' => 'seeds','externalReferences' => [],'transactionDbId' => 'NA','additionalInfo' => {},'amount' => 'NA','transactionTimestamp' => 'NA','transactionDescription' => 'Auto generated seedlot from accession. DbPatch 00085'},{'transactionDescription' => 'Auto generated seedlot from accession. DbPatch 00085','amount' => 'NA','transactionTimestamp' => 'NA','additionalInfo' => {},'transactionDbId' => 'NA','externalReferences' => [],'units' => 'seeds','fromSeedLotDbId' => 'NA','toSeedLotDbId' => 'NA'},{'transactionDescription' => 'Auto generated seedlot from accession. DbPatch 00085','amount' => 'NA','transactionTimestamp' => 'NA','additionalInfo' => {},'transactionDbId' => 'NA','toSeedLotDbId' => 'NA','externalReferences' => [],'fromSeedLotDbId' => 'NA','units' => 'seeds'}]}};

print STDERR "EXPECTED RESPONSE FOR SESEDLOT TRANSACTIONS: ".Dumper($data_expected);

is_deeply($response, $data_expected, "compare clean response with clean data");



$mech->get_ok('http://localhost:3010/brapi/v2/seedlots/41310');
$response = decode_json $mech->content;
print STDERR "\n\n" . Dumper $response;
$response->{result}->{storageLocation} = "NA";

is_deeply($response, {'metadata' => {'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::SeedLots'},{'message' => 'Seed lots result constructed','messageType' => 'INFO'}],'pagination' => {'pageSize' => 10,'totalCount' => 1,'currentPage' => 0,'totalPages' => 1},'datafiles' => []},'result' => {'sourceCollection' => undef,'externalReferences' => [],'additionalInfo' => {},'amount' => 1,'createdDate' => undef,'storageLocation' => 'NA','units' => 'seeds','locationDbId' => '25','locationName' => 'Location 2','lastUpdated' => undef,'seedLotDbId' => '41310','seedLotDescription' => '','contentMixture' => [{ 'crossName' => undef, 'crossDbId' => undef, 'mixturePercentage' => 100,'germplasmName' => 'new_test_crossP006','germplasmDbId' => '38851' } ],'programDbId' => '134','programName' => 'test','seedLotName' => 'new_test_crossP006_001'}});

$mech->get_ok('http://localhost:3010/brapi/v2/seedlots/41305/transactions');
$response = decode_json $mech->content;
print STDERR "\n\n" . Dumper $response;
is_deeply($response, {'metadata' => {'datafiles' => [],'status' => [{'message' => 'BrAPI base call found with page=0, pageSize=10','messageType' => 'INFO'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::SeedLots'},{'messageType' => 'INFO','message' => 'Transactions result constructed'}],'pagination' => {'currentPage' => 0,'totalPages' => 1,'totalCount' => 1,'pageSize' => 10}},'result' => {'data' => [{'externalReferences' => [],'additionalInfo' => {},'toSeedLotDbId' => '41305','fromSeedLotDbId' => '38846','units' => 'seeds','transactionDbId' => '40056','transactionDescription' => 'Auto generated seedlot from accession. DbPatch 00085','transactionTimestamp' => '2017-09-18T11:43:59+0000','amount' => '1'}]}});

$data = '[{ "amount":30, "weight":3000, "germplasmDbId":38848, "locationDbId":23, "programDbId":134, "seedLotDescription":"brap test", "seedLotName":"SeedLots test2", "sourceCollection":"box", "lastUpdated": "2020-06-01T14:47:23-0600" }]';
$mech->post('http://localhost:3010/brapi/v2/seedlots/', Content => $data);
$response = decode_json $mech->content;
print STDERR "\n\n" . Dumper $response;

my $rs = $f->bcs_schema()->resultset('Stock::Stock')->search( undef, { columns => [ { stock_id => { max => "stock_id" }} ]} );
my $row = $rs->next();
my $seedlot_id = $row->stock_id();

is_deeply($response,  {'metadata' => {'datafiles' => [],'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'message' => 'Loading CXGN::BrAPI::v2::SeedLots','messageType' => 'INFO'},{'messageType' => 'INFO','message' => 'Seed lots stored'}],'pagination' => {'currentPage' => 0,'pageSize' => 10,'totalPages' => 1,'totalCount' => 1}},'result' => {'data' => [{'storageLocation' => 'test_location','seedLotDbId' => $seedlot_id,'sourceCollection' => undef,'createdDate' => undef,'seedLotName' => 'SeedLots test2','units' => 'seeds','externalReferences' => [],'amount' => '30','seedLotDescription' => 'brap test','germplasmDbId' => '38848','locationDbId' => '23','programDbId' => '134','lastUpdated' => undef,'additionalInfo' => {}}]}});


$data = '[{ "amount":300, "toSeedLotDbId":41307, "fromSeedLotDbId":41305, "transactionDescription":"BrAPI transactions test2", "transactionTimestamp": "2020-06-01T14:47:23-0600" }]';
$mech->post('http://localhost:3010/brapi/v2/seedlots/transactions/', Content => $data);
$response = decode_json $mech->content;
print STDERR "\n\n" . Dumper $response;

foreach my $t (@{$response->{result}->{data}}) {
    $t->{transactionDbId} = "NA";
}

is_deeply($response, {'result' => {'data' => [{'units' => 'seeds','additionalInfo' => {},'transactionTimestamp' => '2020-06-01T14:47:23-0600','transactionDescription' => 'BrAPI transactions test2','fromSeedLotDbId' => '41305','amount' => 300,'transactionDbId' => 'NA','toSeedLotDbId' => '41307','externalReferences' => []}]},'metadata' => {'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::SeedLots'},{'messageType' => 'INFO','message' => 'Transactions stored'}],'datafiles' => [],'pagination' => {'currentPage' => 0,'totalPages' => 1,'pageSize' => 10,'totalCount' => 1}}}, "POST seedlot transactions test");

$data = '{ "additionalInfo": {}, "amount": 561, "createdDate": "2020-08-05T20:11:51.636Z", "externalReferences": [], "germplasmDbId": "38848", "lastUpdated": "2020-08-05T20:11:51.636Z", "locationDbId": "23", "programDbId": "134", "seedLotDescription": "This is a description of a seed lot", "seedLotName": "Seed Lot Alpha", "sourceCollection": "nursery", "storageLocation": "The storage location", "units": "seeds" }';
$resp = $ua->put("http://localhost:3010/brapi/v2/seedlots/41310", Content => $data);
$response = decode_json $resp->{_content};
print STDERR "\n\n" . Dumper $response;
is_deeply($response, {'result' => {'crossDbId' => '','createdDate' => undef,'lastUpdated' => undef,'amount' => 1,'units' => 'seeds','externalReferences' => [],'seedLotDbId' => '41310','germplasmDbId' => '38848','programDbId' => '134','additionalInfo' => {},'storageLocation' => 'test_location','seedLotName' => 'Seed Lot Alpha','sourceCollection' => undef,'seedLotDescription' => 'This is a description of a seed lot','locationDbId' => '23'},'metadata' => {'pagination' => {'totalPages' => 1,'currentPage' => 0,'pageSize' => 10,'totalCount' => 1},'status' => [{'message' => 'BrAPI base call found with page=0, pageSize=10','messageType' => 'INFO'},{'message' => 'Loading CXGN::BrAPI::v2::SeedLots','messageType' => 'INFO'},{'message' => 'Seed lots updated','messageType' => 'INFO'}],'datafiles' => []}} );



$data = '[ { "accessionNumber": "fem_maleProgeny_002new", "acquisitionDate": "2018-01-01", "additionalInfo": {}, "biologicalStatusOfAccessionCode": "420", "biologicalStatusOfAccessionDescription": "Genetic stock", "breedingMethodDbId": "ffcce7ef",  "collection": "Rice Diversity Panel 1 (RDP1)",  "commonCropName": "Maize",  "countryOfOriginCode": "BES", "defaultDisplayName": "fem_maleProgeny_002", "documentationURL": "https://breedbase.org/", "donors": [ { "donorAccessionNumber": "A0000123", "donorInstituteCode": "PER001" } ], "externalReferences": [], "genus": "Aspergillus", "germplasmName": "test_Germplasm9", "germplasmOrigin": [ { "coordinateUncertainty": "20", "coordinates": { "geometry": { "coordinates": [  -76.506042,  42.417373,  123 ], "type": "Point" }, "type": "Feature" } } ], "germplasmPUI": "http://pui.per/accession/fem_maleProgeny_002", "germplasmPreprocessing": "EO:0007210; transplanted from study 2351 observation unit ID: pot:894", "instituteCode": "PER001", "instituteName": "BTI", "pedigree": "UG120001/UG120002", "seedSource": "A0000001/A0000002", "seedSourceDescription": "Branches were collected from a 10-year-old", "species": "Solanum lycopersicum", "speciesAuthority": "Smith, 1822", "storageTypes": [ { "code": "20", "description": "Field collection" }, { "code": "10", "description": "Field collection" } ], "subtaxa": "Aspergillus fructus A", "subtaxaAuthority": "Smith, 1822", "synonyms": [ { "synonym": "variety_1", "type": "Pre-Code" } ], "taxonIds": [ { "sourceName": "NCBI", "taxonId": "2026747" } ]  } ]';

$mech->post('http://localhost:3010/brapi/v2/germplasm/', Content => $data);
$response = decode_json $mech->content;
print STDERR "\n\n" . Dumper $response;

my $rs = $f->bcs_schema()->resultset('Stock::Stock')->search( { uniquename=>"test_Germplasm9" } );
my $row = $rs->next();
my $germplasm_id = $row->stock_id();

is_deeply($response, {'metadata' => {'pagination' => {'totalPages' => 1,'currentPage' => 0,'totalCount' => 1,'pageSize' => 10},'datafiles' => [],'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::Germplasm'},{'message' => 'Germplasm saved','messageType' => 'INFO'}]},'result' => {'data' => [{'germplasmDbId' => $germplasm_id,'instituteName' => 'BTI','biologicalStatusOfAccessionCode' => '420','germplasmPUI' => 'http://localhost:3010/stock/'. $germplasm_id . '/view,http://pui.per/accession/fem_maleProgeny_002','taxonIds' => [],'additionalInfo' => {},'subtaxa' => undef,'speciesAuthority' => undef,'germplasmOrigin' => [],'acquisitionDate' => '2018-01-01','synonyms' => [{'synonym' => 'variety_1','type' => undef}],'externalReferences' => [],'germplasmName' => 'test_Germplasm9','pedigree' => 'UG120001/UG120002','collection' => 'Rice Diversity Panel 1 (RDP1)','countryOfOriginCode' => 'BES','instituteCode' => 'PER001','genus' => 'Lycopersicon','germplasmPreprocessing' => undef,'donors' => [{'donorInstituteCode' => 'PER001','donorAccessionNumber' => 'A0000123'}],'breedingMethodDbId' => 'biparental','seedSource' => 'A0000001/A0000002','commonCropName' => 'tomato','storageTypes' => [{'description' => undef,'code' => '20'}],'seedSourceDescription' => 'A0000001/A0000002','biologicalStatusOfAccessionDescription' => undef,'subtaxaAuthority' => undef,'species' => 'Solanum lycopersicum','defaultDisplayName' => 'fem_maleProgeny_002','documentationURL' => 'http://localhost:3010/stock/' . $germplasm_id . '/view,http://pui.per/accession/fem_maleProgeny_002','accessionNumber' => 'fem_maleProgeny_002new'}]}}, "POST germplasm test");

$data = '{"accessionNumber": "fem_maleProgeny_002", "acquisitionDate": "2018-01-07", "additionalInfo": {}, "biologicalStatusOfAccessionCode": "4207", "biologicalStatusOfAccessionDescription": "Genetic stock", "breedingMethodDbId": "ffcce7ef",  "collection": "Rice Diversity Panel 1 (RDP1)",  "commonCropName": "Maize", "countryOfOriginCode": "BES7", "defaultDisplayName": "fem_maleProgeny_0027", "documentationURL": "https://breedbase.org", "donors": [ { "donorAccessionNumber": "A0000123", "donorInstituteCode": "PER0017" } ], "externalReferences": [], "genus": "Aspergillus7",  "germplasmName": "test_Germplasm", "germplasmOrigin": [ { "coordinateUncertainty": "20", "coordinates": { "geometry": { "coordinates": [  -76.506042,  42.417373,  123 ], "type": "Point" }, "type": "Feature" } } ], "germplasmPUI": "http://accession/fem_maleProgeny_0027", "germplasmPreprocessing": "EO:0007210; transplanted from study 2351 observation unit ID: pot:894", "instituteCode": "PER0017", "instituteName": "BTI Ithaca", "pedigree": "UG120001/UG120027",  "seedSource": "A0000001/A00000027",  "seedSourceDescription": "Branches were collected from a 10-year-old tree growing in a progeny trial established in a loamy brown earth soil7.", "species": "Solanum lycopersicum", "speciesAuthority": "Smith, 1822", "storageTypes": [ { "code": "207", "description": "Field collection" }, { "code": "10", "description": "Field collection" } ], "subtaxa": "Aspergillus fructus A", "subtaxaAuthority": "Smith, 1822", "synonyms": [ { "synonym": "variety_17", "type": "Pre-Code" } ], "taxonIds": [ { "sourceName": "NCBI", "taxonId": "2026747" } ] }';

$resp = $ua->put("http://localhost:3010/brapi/v2/germplasm/41279", Content => $data);
$response = decode_json $resp->{_content};
print STDERR "\n\n" . Dumper $response;
is_deeply($response, {'metadata' => {'pagination' => {'totalCount' => 1,'currentPage' => 0,'pageSize' => 10,'totalPages' => 1},'datafiles' => [],'status' => [{'messageType' => 'INFO','message' => 'BrAPI base call found with page=0, pageSize=10'},{'messageType' => 'INFO','message' => 'Loading CXGN::BrAPI::v2::Germplasm'},{'message' => 'Germplasm updated','messageType' => 'INFO'}]},'result' => {'pedigree' => 'UG120001/UG120027','instituteCode' => 'PER0017','species' => 'Manihot esculenta','externalReferences' => [],'collection' => 'Rice Diversity Panel 1 (RDP1)','commonCropName' => undef,'breedingMethodDbId' => 'biparental','speciesAuthority' => undef,'donors' => [{'donorAccessionNumber' => 'A0000123', 'donorInstituteCode' => 'PER0017'}],'seedSource' => 'A0000001/A00000027','seedSourceDescription' => 'A0000001/A00000027','acquisitionDate' => '2018-01-07','genus' => 'Manihot','germplasmPreprocessing' => undef,'accessionNumber' => 'fem_maleProgeny_002','germplasmPUI' => 'http://localhost:3010/stock/41279/view,http://accession/fem_maleProgeny_0027','documentationURL' => 'http://localhost:3010/stock/41279/view,http://accession/fem_maleProgeny_0027','synonyms' => [{'type' => undef,'synonym' => 'variety_17'}],'biologicalStatusOfAccessionCode' => '4207','instituteName' => 'BTI Ithaca','additionalInfo' => {},'germplasmName' => 'test_Germplasm','subtaxa' => undef,'biologicalStatusOfAccessionDescription' => undef,'germplasmOrigin' => [],'taxonIds' => [],'germplasmDbId' => '41279','storageTypes' => [{'code' => '207','description' => undef}],'defaultDisplayName' => 'IITA-TMS-IBA30572','countryOfOriginCode' => 'BES7','subtaxaAuthority' => undef}});


#Crossing

#location and year is Needed
$data = '[ { "additionalInfo": { "locationName" : "test_location", "year" : "2019" }, "commonCropName": "Cassava", "crossingProjectDescription": "Crosses between germplasm X and germplasm Y", "crossingProjectName": "Ibadan_Crosses_2018", "externalReferences": [], "programDbId": "134", "programName": "test" },{ "additionalInfo": { "locationName" : "test_location", "year" : "2019" }, "commonCropName": "Cassava", "crossingProjectDescription": "Crosses between germplasm X and germplasm Y", "crossingProjectName": "Ibadan_Crosses_2018-2", "externalReferences": [], "programDbId": "134", "programName": "test" } ]';
$mech->post('http://localhost:3010/brapi/v2/crossingprojects/', Content => $data);
$response = decode_json $mech->content;
print STDERR "\n\n" . Dumper $response;
is_deeply($response, {'metadata' => {'status' => [{'message' => 'BrAPI base call found with page=0, pageSize=10','messageType' => 'INFO'},{'message' => 'Loading CXGN::BrAPI::v2::Crossing','messageType' => 'INFO'},{'messageType' => 'INFO','message' => '2 Crossing projects stored'}],'pagination' => {'totalPages' => 1,'totalCount' => 2,'currentPage' => 0,'pageSize' => 10},'datafiles' => []},'result' => {}});

$data = '{ "additionalInfo": {"locationName" : "test_location" }, "commonCropName": "Cassava", "crossingProjectDescription": "Crosses germplasm X and Y", "crossingProjectName": "Ibadan_Crosses_2018 - 2", "externalReferences": [], "programDbId": "134", "programName": "test"}';
$resp = $ua->put("http://localhost:3010/brapi/v2/crossingprojects/140", Content => $data);
$response = decode_json $resp->{_content};
print STDERR "\n\n" . Dumper $response;
is_deeply($response, {'metadata' => {'status' => [{'message' => 'BrAPI base call found with page=0, pageSize=10','messageType' => 'INFO'},{'message' => 'Loading CXGN::BrAPI::v2::Crossing','messageType' => 'INFO'},{'messageType' => 'INFO','message' => 'Crossing project updated'}],'pagination' => {'currentPage' => 0,'totalPages' => 1,'pageSize' => 10,'totalCount' => 1},'datafiles' => []},'result' => {'commonCropName' => undef,'crossingProjectDescription' => 'Ibadan_Crosses_2018 - 2','crossingProjectName' => 'Ibadan_Crosses_2018 - 2','additionalInfo' => {},'programName' => 'test','programDbId' => '134','externalReferences' => [],'crossingProjectDbId' => '140'}});

#deleting crossing experiments
my $project_id_1 = $f->bcs_schema()->resultset("Project::Project")->find({name=>'Ibadan_Crosses_2018'})->project_id;
$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$project_id_1.'/delete/crossing_experiment');
$response = decode_json $mech->content;
is($response->{'success'}, '1');

my $project_id_2 = $f->bcs_schema()->resultset("Project::Project")->find({name=>'Ibadan_Crosses_2018-2'})->project_id;
$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$project_id_2.'/delete/crossing_experiment');
$response = decode_json $mech->content;
is($response->{'success'}, '1');

my $project_id_3 = $f->bcs_schema()->resultset("Project::Project")->find({name=>'Ibadan_Crosses_2018 - 2'})->project_id;
$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$project_id_3.'/delete/crossing_experiment');
$response = decode_json $mech->content;
is($response->{'success'}, '1');

$f->clean_up_db();

# rename back changed stock names and synonyms
#
my $row = $f->bcs_schema()->resultset('Stock::Stock')->find( { uniquename => 'test_Germplasm' });

$row->uniquename('IITA-TMS-IBA30572');
$row->update();

$row = $f->bcs_schema()->resultset('Stock::Stockprop')->find( { value => 'variety_17' });
if ($row) { $row->delete(); }

 my $bs = CXGN::BreederSearch->new( { dbh=>$f->dbh, dbname=>$f->config->{dbname} } );
 $bs->refresh_matviews($f->config->{dbhost}, $f->config->{dbname}, $f->config->{dbuser}, $f->config->{dbpass}, 'fullview', 'basic', $f->config->{basepath});
$bs->refresh_matviews($f->config->{dbhost}, $f->config->{dbname}, $f->config->{dbuser}, $f->config->{dbpass}, 'stockprop', 'basic', $f->config->{basepath});
 $bs->refresh_matviews($f->config->{dbhost}, $f->config->{dbname}, $f->config->{dbuser}, $f->config->{dbpass}, 'phenotype', 'basic', $f->config->{basepath});

 while (exists($bs->matviews_status()->{refreshing})) {
     print STDERR "Matview refreshing... Waiting.\n";
     sleep(1);
 }

$f->clean_up_db();

done_testing();
