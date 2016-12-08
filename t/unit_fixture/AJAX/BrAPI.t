
use strict;
use warnings;

#use lib 't/lib';
#use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;

#Needed to update IO::Socket::SSL
use Data::Dumper;
use JSON;
local $Data::Dumper::Indent = 0;

my $mech = Test::WWW::Mechanize->new;
my $response;

$mech->get_ok('http://localhost:3010/brapi/v1/calls?pageSize=5&currentPage=3');
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'result' => {'data' => [{'methods' => ['GET'],'datatypes' => ['json'],'call' => 'markerprofiles'},{'call' => 'markerprofiles/id','methods' => ['GET'],'datatypes' => ['json']},{'call' => 'allelematrix-search','methods' => ['GET','POST'],'datatypes' => ['json','tsv','csv']},{'datatypes' => ['json'],'methods' => ['GET'],'call' => 'programs'},{'datatypes' => ['json'],'methods' => ['GET'],'call' => 'crops'}]},'metadata' => {'datafiles' => [],'pagination' => {'totalCount' => 32,'totalPages' => 7,'pageSize' => 5,'currentPage' => 3},'status' => {}}}, 'check calls response content');

$mech->get_ok('http://localhost:3010/brapi/v1/calls?pageSize=50&datatype=tsv');
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'result' => {'data' => [{'call' => 'allelematrix-search','methods' => ['GET','POST'],'datatypes' => ['json','tsv','csv']}]},'metadata' => {'datafiles' => [],'pagination' => {'pageSize' => 50,'totalPages' => 1,'currentPage' => 1,'totalCount' => 32},'status' => {}}}, 'check calls response content');

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw"=> "grant_type"=> "password" ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->{'message'}, 'Login Successfull');
is($response->{'userDisplayName'}, 'Jane Doe');
is($response->{'expires_in'}, '7200');

$mech->delete_ok('http://localhost:3010/brapi/v1/token');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->{'message'}, 'Successfully logged out.');

$mech->get_ok('http://localhost:3010/brapi/v1/germplasm-search?pageSize=2&currentPage=3');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'datafiles' => [],'pagination' => {'pageSize' => 2,'totalPages' => 234,'currentPage' => 3,'totalCount' => 468},'status' => {'message' => ''}},'result' => {'data' => [{'germplasmSeedSource' => '','speciesAuthority' => '','defaultDisplayName' => 'test_accession5','instituteName' => '','biologicalStatusOfAccessionCode' => '','accessionNumber' => undef,'pedigree' => undef,'instituteCode' => '','commonCropName' => 'tomato','species' => 'Solanum lycopersicum','germplasmPUI' => 'test_accession5','countryOfOriginCode' => '','germplasmName' => 'test_accession5','subtaxa' => '','germplasmDbId' => 38844,'synonyms' => [],'typeOfGermplasmStorageCode' => 'Not Stored','genus' => 'Lycopersicon','acquisitionDate' => '','subtaxaAuthority' => '','donors' => []},{'germplasmName' => 'new_test_crossP001','subtaxa' => '','synonyms' => [],'germplasmDbId' => 38846,'typeOfGermplasmStorageCode' => 'Not Stored','genus' => 'Lycopersicon','acquisitionDate' => '','donors' => [],'subtaxaAuthority' => '','defaultDisplayName' => 'new_test_crossP001','germplasmSeedSource' => '','speciesAuthority' => '','instituteName' => '','biologicalStatusOfAccessionCode' => '','pedigree' => 'test_accession4/test_accession5','accessionNumber' => undef,'instituteCode' => '','species' => 'Solanum lycopersicum','commonCropName' => 'tomato','germplasmPUI' => 'new_test_crossP001','countryOfOriginCode' => ''}]}}, 'germplasm-search');

$mech->get_ok('http://localhost:3010/brapi/v1/germplasm-search?pageSize=2&currentPage=5');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'donors' => [],'subtaxaAuthority' => '','acquisitionDate' => '','genus' => 'Lycopersicon','typeOfGermplasmStorageCode' => 'Not Stored','synonyms' => [],'germplasmDbId' => 38849,'subtaxa' => '','germplasmName' => 'new_test_crossP004','countryOfOriginCode' => '','germplasmPUI' => 'new_test_crossP004','species' => 'Solanum lycopersicum','commonCropName' => 'tomato','instituteCode' => '','accessionNumber' => undef,'pedigree' => 'test_accession4/test_accession5','instituteName' => '','biologicalStatusOfAccessionCode' => '','defaultDisplayName' => 'new_test_crossP004','speciesAuthority' => '','germplasmSeedSource' => ''},{'countryOfOriginCode' => '','commonCropName' => 'tomato','species' => 'Solanum lycopersicum','germplasmPUI' => 'new_test_crossP005','pedigree' => 'test_accession4/test_accession5','accessionNumber' => undef,'instituteCode' => '','speciesAuthority' => '','germplasmSeedSource' => '','defaultDisplayName' => 'new_test_crossP005','instituteName' => '','biologicalStatusOfAccessionCode' => '','acquisitionDate' => '','subtaxaAuthority' => '','donors' => [],'typeOfGermplasmStorageCode' => 'Not Stored','genus' => 'Lycopersicon','subtaxa' => '','germplasmDbId' => 38850,'synonyms' => [],'germplasmName' => 'new_test_crossP005'}]},'metadata' => {'pagination' => {'pageSize' => 2,'totalPages' => 234,'currentPage' => 5,'totalCount' => 468},'status' => {'message' => ''},'datafiles' => []}}, 'germplasm-search');

$mech->get_ok('http://localhost:3010/brapi/v1/germplasm-search?pageSize=2&currentPage=1&germplasmDbId=38849');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'germplasmPUI' => 'new_test_crossP004','acquisitionDate' => '','typeOfGermplasmStorageCode' => 'Not Stored','commonCropName' => 'tomato','species' => 'Solanum lycopersicum','instituteCode' => '','instituteName' => '','countryOfOriginCode' => '','germplasmSeedSource' => '','subtaxa' => '','donors' => [],'biologicalStatusOfAccessionCode' => '','pedigree' => 'test_accession4/test_accession5','germplasmDbId' => 38849,'subtaxaAuthority' => '','synonyms' => [],'speciesAuthority' => '','germplasmName' => 'new_test_crossP004','defaultDisplayName' => 'new_test_crossP004','genus' => 'Lycopersicon','accessionNumber' => undef}]},'metadata' => {'status' => {'message' => ''},'pagination' => {'totalCount' => 1,'totalPages' => 1,'currentPage' => 1,'pageSize' => 2},'datafiles' => []}}, 'germplasm-search');

$mech->get_ok('http://localhost:3010/brapi/v1/germplasm-search?pageSize=2&currentPage=5&germplasmName=te%&matchMethod=wildcard');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'genus' => 'Lycopersicon','germplasmSeedSource' => '','instituteName' => '','commonCropName' => 'tomato','instituteCode' => '','subtaxaAuthority' => '','germplasmName' => 'test5P004','acquisitionDate' => '','donors' => [],'speciesAuthority' => '','pedigree' => 'test_accession4/test_accession5','biologicalStatusOfAccessionCode' => '','germplasmDbId' => 38876,'accessionNumber' => undef,'species' => 'Solanum lycopersicum','typeOfGermplasmStorageCode' => 'Not Stored','synonyms' => [],'countryOfOriginCode' => '','defaultDisplayName' => 'test5P004','germplasmPUI' => 'test5P004','subtaxa' => ''},{'germplasmName' => 'test5P005','acquisitionDate' => '','donors' => [],'speciesAuthority' => '','genus' => 'Lycopersicon','germplasmSeedSource' => '','commonCropName' => 'tomato','instituteName' => '','instituteCode' => '','subtaxaAuthority' => '','countryOfOriginCode' => '','defaultDisplayName' => 'test5P005','germplasmPUI' => 'test5P005','subtaxa' => '','pedigree' => 'test_accession4/test_accession5','biologicalStatusOfAccessionCode' => '','germplasmDbId' => 38877,'species' => 'Solanum lycopersicum','accessionNumber' => undef,'typeOfGermplasmStorageCode' => 'Not Stored','synonyms' => []}]},'metadata' => {'status' => {'message' => ''},'datafiles' => [],'pagination' => {'totalCount' => 10,'pageSize' => 2,'currentPage' => 5,'totalPages' => 5}}}, 'germplasm-search');

$mech->post_ok('http://localhost:3010/brapi/v1/germplasm-search', ['pageSize'=>'1', 'currentPage'=>'5', 'germplasmName'=>'t%', 'matchMethod'=>'wildcard'] );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'germplasmDbId' => 38844,'commonCropName' => 'tomato','speciesAuthority' => '','genus' => 'Lycopersicon','germplasmSeedSource' => '','germplasmName' => 'test_accession5','instituteName' => '','accessionNumber' => undef,'subtaxa' => '','synonyms' => [],'acquisitionDate' => '','donors' => [],'species' => 'Solanum lycopersicum','pedigree' => undef,'biologicalStatusOfAccessionCode' => '','instituteCode' => '','subtaxaAuthority' => '','typeOfGermplasmStorageCode' => 'Not Stored','germplasmPUI' => 'test_accession5','defaultDisplayName' => 'test_accession5','countryOfOriginCode' => ''}]},'metadata' => {'pagination' => {'pageSize' => 1,'totalPages' => 10,'totalCount' => 10,'currentPage' => 5},'status' => {'message' => ''},'datafiles' => []}}, 'germplasm-search post');

$mech->get_ok('http://localhost:3010/brapi/v1/germplasm/38876');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'datafiles' => [],'status' => {},'pagination' => {'pageSize' => 20,'totalCount' => 1,'currentPage' => 1,'totalPages' => 1}},'result' => {'donors' => [],'germplasmPUI' => 'test5P004','defaultDisplayName' => 'test5P004','germplasmSeedSource' => '','species' => 'Solanum lycopersicum','instituteCode' => '','typeOfGermplasmStorageCode' => 'Not Stored','pedigree' => 'test_accession4/test_accession5','germplasmName' => 'test5P004','instituteName' => '','subtaxaAuthority' => '','biologicalStatusOfAccessionCode' => '','germplasmDbId' => '38876','accessionNumber' => 'test5P004','countryOfOriginCode' => '','genus' => 'Lycopersicon','subtaxa' => '','commonCropName' => 'tomato','acquisitionDate' => '','synonyms' => [],'speciesAuthority' => ''}}, 'germplasm detail');

$mech->get_ok('http://localhost:3010/brapi/v1/germplasm/38876/pedigree');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'parent1Id' => 38843,'pedigree' => 'test_accession4/test_accession5','parent2Id' => 38844,'germplasmDbId' => '38876'},'metadata' => {'pagination' => {'totalCount' => 1,'totalPages' => 1,'currentPage' => 1,'pageSize' => 20},'datafiles' => [],'status' => {'message' => ''}}}, 'germplasm pedigree');

$mech->get_ok('http://localhost:3010/brapi/v1/germplasm/38937/markerprofiles');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'status' => {},'pagination' => {'pageSize' => 20,'totalPages' => 1,'totalCount' => 2,'currentPage' => 1},'datafiles' => []},'result' => {'markerProfiles' => [1622,1934],'germplasmDbId' => '38937'}}, 'germplasm markerprofile');

done_testing();
