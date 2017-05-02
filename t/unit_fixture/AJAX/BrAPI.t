
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

$mech->get_ok('http://localhost:3010/brapi/v1/calls?pageSize=5&page=3');
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'result' => {'data' => [{'call' => 'crops','datatypes' => ['json'],'methods' => ['GET']},{'call' => 'seasons','datatypes' => ['json'],'methods' => ['GET','POST']},{'call' => 'studyTypes','datatypes' => ['json'],'methods' => ['GET','POST']},{'methods' => ['GET','POST'],'datatypes' => ['json'],'call' => 'trials'},{'call' => 'trials/id','datatypes' => ['json'],'methods' => ['GET']}]},'metadata' => {'pagination' => {'totalPages' => 9,'pageSize' => 5,'totalCount' => 41,'currentPage' => 3},'status' => [{'info' => 'BrAPI base call found with page=3, pageSize=5'},{'info' => 'Loading CXGN::BrAPI::v1::Calls'},{'success' => 'Calls result constructed'}],'datafiles' => []}}, 'check calls response content');

$mech->get_ok('http://localhost:3010/brapi/v1/calls?pageSize=50&datatype=tsv');
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'result' => {'data' => [{'methods' => ['GET','POST'],'call' => 'allelematrix-search','datatypes' => ['json','tsv','csv','xls']},{'methods' => ['GET'],'datatypes' => ['json','csv','xls','tsv'],'call' => 'studies/id/table'}]},'metadata' => {'datafiles' => [],'status' => [{'info' => 'BrAPI base call found with page=0, pageSize=50'},{'info' => 'Loading CXGN::BrAPI::v1::Calls'},{'success' => 'Calls result constructed'}],'pagination' => {'totalPages' => 1,'pageSize' => 50,'totalCount' => 2,'currentPage' => 0}}}, 'check calls response content');

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->[2]->{'success'}, 'Login Successfull');
is($response->{'userDisplayName'}, 'Jane Doe');
is($response->{'expires_in'}, '7200');

$mech->delete_ok('http://localhost:3010/brapi/v1/token');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->[2]->{'success'}, 'User Logged Out');

$mech->get_ok('http://localhost:3010/brapi/v1/germplasm-search?pageSize=2&page=3');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'datafiles' => [],'pagination' => {'currentPage' => 3,'pageSize' => 2,'totalPages' => 240,'totalCount' => 479},'status' => [{'info' => 'BrAPI base call found with page=3, pageSize=2'},{'info' => 'Loading CXGN::BrAPI::v1::Germplasm'},{'success' => 'Germplasm-search result constructed'}]},'result' => {'data' => [{'subtaxa' => undef,'speciesAuthority' => undef,'countryOfOriginCode' => undef,'pedigree' => 'test_accession4/test_accession5','acquisitionDate' => undef,'subtaxaAuthority' => undef,'species' => 'Solanum lycopersicum','germplasmName' => 'new_test_crossP002','genus' => 'Lycopersicon','commonCropName' => 'tomato','accessionNumber' => undef,'defaultDisplayName' => 'new_test_crossP002','germplasmPUI' => undef,'typeOfGermplasmStorageCode' => undef,'germplasmDbId' => 38847,'germplasmSeedSource' => undef,'instituteCode' => undef,'instituteName' => undef,'donors' => [{'germplasmPUI' => undef,'donorGermplasmName' => undef,'donorAccessionNumber' => undef,'donorInstituteCode' => undef}],'synonyms' => undef,'biologicalStatusOfAccessionCode' => undef},{'germplasmPUI' => undef,'germplasmDbId' => 38848,'typeOfGermplasmStorageCode' => undef,'instituteName' => undef,'germplasmSeedSource' => undef,'instituteCode' => undef,'biologicalStatusOfAccessionCode' => undef,'donors' => [{'germplasmPUI' => undef,'donorGermplasmName' => undef,'donorAccessionNumber' => undef,'donorInstituteCode' => undef}],'synonyms' => undef,'species' => 'Solanum lycopersicum','germplasmName' => 'new_test_crossP003','subtaxaAuthority' => undef,'genus' => 'Lycopersicon','defaultDisplayName' => 'new_test_crossP003','commonCropName' => 'tomato','accessionNumber' => undef,'acquisitionDate' => undef,'speciesAuthority' => undef,'subtaxa' => undef,'countryOfOriginCode' => undef,'pedigree' => 'test_accession4/test_accession5'}]}}, 'germplasm-search');

$mech->get_ok('http://localhost:3010/brapi/v1/germplasm-search?pageSize=2&page=5');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'pedigree' => 'test_accession4/test_accession5','countryOfOriginCode' => undef,'speciesAuthority' => undef,'subtaxa' => undef,'acquisitionDate' => undef,'defaultDisplayName' => 'new_test_crossP006','accessionNumber' => undef,'commonCropName' => 'tomato','genus' => 'Lycopersicon','subtaxaAuthority' => undef,'germplasmName' => 'new_test_crossP006','species' => 'Solanum lycopersicum','synonyms' => undef,'donors' => [{'donorGermplasmName' => undef,'germplasmPUI' => undef,'donorInstituteCode' => undef,'donorAccessionNumber' => undef}],'biologicalStatusOfAccessionCode' => undef,'instituteName' => undef,'instituteCode' => undef,'germplasmSeedSource' => undef,'typeOfGermplasmStorageCode' => undef,'germplasmDbId' => 38851,'germplasmPUI' => undef},{'acquisitionDate' => undef,'countryOfOriginCode' => undef,'speciesAuthority' => undef,'subtaxa' => undef,'pedigree' => 'test_accession4/test_accession5','typeOfGermplasmStorageCode' => undef,'germplasmDbId' => 38852,'germplasmPUI' => undef,'donors' => [{'donorInstituteCode' => undef,'donorAccessionNumber' => undef,'donorGermplasmName' => undef,'germplasmPUI' => undef}],'synonyms' => undef,'biologicalStatusOfAccessionCode' => undef,'germplasmSeedSource' => undef,'instituteName' => undef,'instituteCode' => undef,'subtaxaAuthority' => undef,'germplasmName' => 'new_test_crossP007','species' => 'Solanum lycopersicum','accessionNumber' => undef,'defaultDisplayName' => 'new_test_crossP007','commonCropName' => 'tomato','genus' => 'Lycopersicon'}]},'metadata' => {'status' => [{'info' => 'BrAPI base call found with page=5, pageSize=2'},{'info' => 'Loading CXGN::BrAPI::v1::Germplasm'},{'success' => 'Germplasm-search result constructed'}],'datafiles' => [],'pagination' => {'totalCount' => 479,'totalPages' => 240,'pageSize' => 2,'currentPage' => 5}}}, 'germplasm-search');

$mech->get_ok('http://localhost:3010/brapi/v1/germplasm-search?pageSize=2&page=0&germplasmDbId=38849');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'germplasmDbId' => 38849,'germplasmPUI' => undef,'accessionNumber' => undef,'subtaxaAuthority' => undef,'speciesAuthority' => undef,'countryOfOriginCode' => undef,'commonCropName' => 'tomato','subtaxa' => undef,'germplasmName' => 'new_test_crossP004','acquisitionDate' => undef,'instituteCode' => undef,'instituteName' => undef,'genus' => 'Lycopersicon','biologicalStatusOfAccessionCode' => undef,'donors' => [{'germplasmPUI' => undef,'donorGermplasmName' => undef,'donorInstituteCode' => undef,'donorAccessionNumber' => undef}],'defaultDisplayName' => 'new_test_crossP004','typeOfGermplasmStorageCode' => undef,'species' => 'Solanum lycopersicum','germplasmSeedSource' => undef,'synonyms' => undef,'pedigree' => 'test_accession4/test_accession5'}]},'metadata' => {'status' => [{'info' => 'BrAPI base call found with page=0, pageSize=2'},{'info' => 'Loading CXGN::BrAPI::v1::Germplasm'},{'success' => 'Germplasm-search result constructed'}],'datafiles' => [],'pagination' => {'pageSize' => 2,'totalCount' => 1,'totalPages' => 1,'currentPage' => 0}}}, 'germplasm-search');

$mech->get_ok('http://localhost:3010/brapi/v1/germplasm-search?pageSize=2&page=4&germplasmName=te%&matchMethod=wildcard');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'synonyms' => undef,'pedigree' => 'test_accession4/test_accession5','typeOfGermplasmStorageCode' => undef,'species' => 'Solanum lycopersicum','defaultDisplayName' => 'new_test_crossP009','germplasmSeedSource' => undef,'instituteName' => undef,'genus' => 'Lycopersicon','biologicalStatusOfAccessionCode' => undef,'donors' => [{'donorGermplasmName' => undef,'germplasmPUI' => undef,'donorAccessionNumber' => undef,'donorInstituteCode' => undef}],'germplasmName' => 'new_test_crossP009','commonCropName' => 'tomato','subtaxa' => undef,'acquisitionDate' => undef,'instituteCode' => undef,'subtaxaAuthority' => undef,'countryOfOriginCode' => undef,'speciesAuthority' => undef,'germplasmPUI' => undef,'accessionNumber' => undef,'germplasmDbId' => 38854},{'acquisitionDate' => undef,'commonCropName' => 'tomato','subtaxa' => undef,'germplasmName' => 'new_test_crossP010','instituteCode' => undef,'subtaxaAuthority' => undef,'speciesAuthority' => undef,'countryOfOriginCode' => undef,'accessionNumber' => undef,'germplasmPUI' => undef,'germplasmDbId' => 38855,'synonyms' => undef,'pedigree' => 'test_accession4/test_accession5','germplasmSeedSource' => undef,'defaultDisplayName' => 'new_test_crossP010','typeOfGermplasmStorageCode' => undef,'species' => 'Solanum lycopersicum','instituteName' => undef,'donors' => [{'donorInstituteCode' => undef,'donorAccessionNumber' => undef,'germplasmPUI' => undef,'donorGermplasmName' => undef}],'genus' => 'Lycopersicon','biologicalStatusOfAccessionCode' => undef}]},'metadata' => {'datafiles' => [],'pagination' => {'totalCount' => 25,'pageSize' => 2,'totalPages' => 13,'currentPage' => 4},'status' => [{'info' => 'BrAPI base call found with page=4, pageSize=2'},{'info' => 'Loading CXGN::BrAPI::v1::Germplasm'},{'success' => 'Germplasm-search result constructed'}]}}, 'germplasm-search');

$mech->post_ok('http://localhost:3010/brapi/v1/germplasm-search', ['pageSize'=>'1', 'page'=>'5', 'germplasmName'=>'t%', 'matchMethod'=>'wildcard'] );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'genus' => 'Lycopersicon','accessionNumber' => undef,'defaultDisplayName' => 'new_test_crossP002','commonCropName' => 'tomato','species' => 'Solanum lycopersicum','germplasmName' => 'new_test_crossP002','subtaxaAuthority' => undef,'germplasmSeedSource' => undef,'instituteName' => undef,'instituteCode' => undef,'biologicalStatusOfAccessionCode' => undef,'synonyms' => undef,'donors' => [{'donorInstituteCode' => undef,'donorAccessionNumber' => undef,'donorGermplasmName' => undef,'germplasmPUI' => undef}],'germplasmPUI' => undef,'germplasmDbId' => 38847,'typeOfGermplasmStorageCode' => undef,'pedigree' => 'test_accession4/test_accession5','subtaxa' => undef,'speciesAuthority' => undef,'countryOfOriginCode' => undef,'acquisitionDate' => undef}]},'metadata' => {'status' => [{'info' => 'BrAPI base call found with page=5, pageSize=1'},{'info' => 'Loading CXGN::BrAPI::v1::Germplasm'},{'success' => 'Germplasm-search result constructed'}],'pagination' => {'totalCount' => 31,'pageSize' => 1,'totalPages' => 31,'currentPage' => 5},'datafiles' => []}}, 'germplasm-search post');

$mech->get_ok('http://localhost:3010/brapi/v1/germplasm/38876');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'defaultDisplayName' => 'test5P004','pedigree' => 'test_accession4/test_accession5','genus' => 'Lycopersicon','germplasmName' => 'test5P004','countryOfOriginCode' => undef,'subtaxaAuthority' => undef,'instituteCode' => undef,'germplasmDbId' => 38876,'typeOfGermplasmStorageCode' => undef,'subtaxa' => undef,'instituteName' => undef,'acquisitionDate' => undef,'germplasmSeedSource' => undef,'speciesAuthority' => undef,'accessionNumber' => undef,'species' => 'Solanum lycopersicum','synonyms' => undef,'germplasmPUI' => undef,'commonCropName' => 'tomato','donors' => [{'donorAccessionNumber' => undef,'donorInstituteCode' => undef,'donorGermplasmName' => undef,'germplasmPUI' => undef}],'biologicalStatusOfAccessionCode' => undef},'metadata' => {'datafiles' => [],'status' => [{'info' => 'BrAPI base call found with page=0, pageSize=20'},{'info' => 'Loading CXGN::BrAPI::v1::Germplasm'},{'success' => 'Germplasm detail result constructed'}],'pagination' => {'pageSize' => 1,'totalPages' => 1,'currentPage' => 0,'totalCount' => 1}}}, 'germplasm detail');

$mech->get_ok('http://localhost:3010/brapi/v1/germplasm/38876/pedigree');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'germplasmDbId' => '38876','parent2Id' => 38844,'parent1Id' => 38843,'pedigree' => 'test_accession4/test_accession5'},'metadata' => {'status' => [{'info' => 'BrAPI base call found with page=0, pageSize=20'},{'info' => 'Loading CXGN::BrAPI::v1::Germplasm'},{'success' => 'Germplasm pedigree result constructed'}],'pagination' => {'currentPage' => 0,'totalPages' => 1,'pageSize' => 1,'totalCount' => 1},'datafiles' => []}}, 'germplasm pedigree');

$mech->get_ok('http://localhost:3010/brapi/v1/germplasm/38937/markerprofiles');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'germplasmDbId' => '38937','markerProfiles' => [1622,1934]},'metadata' => {'datafiles' => [],'pagination' => {'totalPages' => 1,'pageSize' => 20,'currentPage' => 0,'totalCount' => 2},'status' => [{'info' => 'BrAPI base call found with page=0, pageSize=20'},{'info' => 'Loading CXGN::BrAPI::v1::Germplasm'},{'success' => 'Germplasm markerprofiles result constructed'}]}}, 'germplasm markerprofile');

$mech->get_ok('http://localhost:3010/brapi/v1/markerprofiles?pageSize=2&page=3');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'status' => [{'info' => 'BrAPI base call found with page=3, pageSize=2'},{'info' => 'Loading CXGN::BrAPI::v1::Markerprofiles'},{'success' => 'Markerprofiles-search result constructed'}],'pagination' => {'currentPage' => 3,'totalPages' => 1,'totalCount' => 2,'pageSize' => 2},'datafiles' => []},'result' => {'data' => [{'extractDbId' => 'UG120178|78266','uniqueDisplayName' => 'UG120178|78266','germplasmDbId' => 39027,'resultCount' => 500,'sampleDbId' => 'UG120178|78266','markerProfileDbId' => 1628,'analysisMethod' => 'GBS ApeKI genotyping v4'},{'analysisMethod' => 'GBS ApeKI genotyping v4','sampleDbId' => 'UG120179|78267','markerProfileDbId' => 1629,'germplasmDbId' => 39028,'resultCount' => 500,'extractDbId' => 'UG120179|78267','uniqueDisplayName' => 'UG120179|78267'}]}}, 'markerprofile');

$mech->get_ok('http://localhost:3010/brapi/v1/markerprofiles?pageSize=1&page=1&germplasmDbId=38937');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'sampleDbId' => 'UG120066|79802','markerProfileDbId' => 1934,'analysisMethod' => 'GBS ApeKI genotyping v4','resultCount' => 500,'germplasmDbId' => 38937,'uniqueDisplayName' => 'UG120066|79802','extractDbId' => 'UG120066|79802'}]},'metadata' => {'pagination' => {'pageSize' => 1,'totalPages' => 1,'totalCount' => 1,'currentPage' => 1},'status' => [{'info' => 'BrAPI base call found with page=1, pageSize=1'},{'info' => 'Loading CXGN::BrAPI::v1::Markerprofiles'},{'success' => 'Markerprofiles-search result constructed'}],'datafiles' => []}}, 'markerprofile');

$mech->get_ok('http://localhost:3010/brapi/v1/markerprofiles?pageSize=2&page=3&methodDbId=1');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'markerProfileDbId' => 1628,'sampleDbId' => 'UG120178|78266','analysisMethod' => 'GBS ApeKI genotyping v4','uniqueDisplayName' => 'UG120178|78266','extractDbId' => 'UG120178|78266','resultCount' => 500,'germplasmDbId' => 39027},{'markerProfileDbId' => 1629,'analysisMethod' => 'GBS ApeKI genotyping v4','sampleDbId' => 'UG120179|78267','uniqueDisplayName' => 'UG120179|78267','extractDbId' => 'UG120179|78267','germplasmDbId' => 39028,'resultCount' => 500}]},'metadata' => {'pagination' => {'totalCount' => 2,'totalPages' => 1,'currentPage' => 3,'pageSize' => 2},'status' => [{'info' => 'BrAPI base call found with page=3, pageSize=2'},{'info' => 'Loading CXGN::BrAPI::v1::Markerprofiles'},{'success' => 'Markerprofiles-search result constructed'}],'datafiles' => []}}, 'markerprofile');

$mech->get_ok('http://localhost:3010/brapi/v1/markerprofiles/1627');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'germplasmDbId' => 39007,'uniqueDisplayName' => 'UG120156','data' => [{'S5_36739' => 'BB'},{'S13_92567' => 'BB'},{'S69_57277' => 'BB'},{'S80_224901' => 'AA'},{'S80_232173' => 'BB'},{'S80_265728' => 'AA'},{'S97_219243' => 'AB'},{'S224_309814' => 'BB'},{'S248_174244' => 'BB'},{'S318_245078' => 'AA'},{'S325_476494' => 'AA'},{'S341_311907' => 'BB'},{'S341_745165' => 'BB'},{'S341_927602' => 'BB'},{'S435_153155' => 'AA'},{'S620_130205' => 'BB'},{'S784_76866' => 'BB'},{'S821_289681' => 'AB'},{'S823_109683' => 'AA'},{'S823_119622' => 'BB'}],'markerprofileDbId' => '1627','extractDbId' => 'UG120156|78265','analysisMethod' => 'GBS ApeKI genotyping v4'},'metadata' => {'datafiles' => [],'pagination' => undef,'status' => [{'info' => 'BrAPI base call found with page=0, pageSize=20'},{'info' => 'Loading CXGN::BrAPI::v1::Markerprofiles'},{'success' => 'Markerprofiles detail result constructed'}]}}, 'markerprofile');

$mech->post_ok('http://localhost:3010/brapi/v1/allelematrix-search', ['markerprofileDbId'=>[1626,1627], 'format'=>'json'] );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [['S10114_185859',1626,'BB'],['S10173_777651',1626,'BB'],['S10173_899514',1626,'BB'],['S10241_146006',1626,'AA'],['S1027_465354',1626,'AA'],['S10367_21679',1626,'AA'],['S1046_216535',1626,'AB'],['S10493_191533',1626,'BB'],['S10493_282956',1626,'AB'],['S10493_529025',1626,'BB'],['S10551_41284',1626,'BB'],['S10551_44996',1626,'AA'],['S10551_96591',1626,'BB'],['S10563_110710',1626,'AA'],['S10563_458792',1626,'BB'],['S10563_535346',1626,'AA'],['S10563_6640',1626,'BB'],['S10563_996687',1626,'AA'],['S10689_537521',1626,'BB']]},'metadata' => {'datafiles' => [],'status' => [{'info' => 'BrAPI base call found with page=0, pageSize=20'},{'info' => 'Loading CXGN::BrAPI::v1::Markerprofiles'},{'success' => 'Markerprofiles allelematrix result constructed'}],'pagination' => {'totalCount' => 1000,'totalPages' => 50,'currentPage' => 0,'pageSize' => 20}}}, 'allelematrix-search');

$mech->get_ok('http://localhost:3010/brapi/v1/programs' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'leadPerson' => '','name' => 'test','objective' => 'test','abbreviation' => '','programDbId' => 134}]},'metadata' => {'status' => [{'info' => 'BrAPI base call found with page=0, pageSize=20'},{'info' => 'Loading CXGN::BrAPI::v1::Programs'},{'success' => 'Program list result constructed'}],'datafiles' => [],'pagination' => {'totalCount' => 1,'totalPages' => 1,'pageSize' => 20,'currentPage' => 0}}}, 'programs');

$mech->get_ok('http://localhost:3010/brapi/v1/crops' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'datafiles' => [],'status' => [{'info' => 'BrAPI base call found with page=0, pageSize=20'},{'info' => 'Loading CXGN::BrAPI::v1::Crops'},{'success' => 'Crops result constructed'}],'pagination' => {'totalPages' => 1,'totalCount' => 1,'currentPage' => 0,'pageSize' => 20}},'result' => {'data' => ['Cassava']}}, 'crops');

$mech->get_ok('http://localhost:3010/brapi/v1/studyTypes' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'description' => 'seedling','name' => 'Seedling Nursery','studyTypeDbId' => 76464},{'studyTypeDbId' => 76514,'description' => undef,'name' => 'Advanced Yield Trial'},{'name' => 'Preliminary Yield Trial','description' => undef,'studyTypeDbId' => 76515},{'studyTypeDbId' => 76516,'name' => 'Uniform Yield Trial','description' => undef},{'description' => undef,'name' => 'Variety Release Trial','studyTypeDbId' => 77105},{'description' => undef,'name' => 'Clonal Evaluation','studyTypeDbId' => 77106}]},'metadata' => {'datafiles' => [],'pagination' => {'totalCount' => 6,'pageSize' => 20,'totalPages' => 1,'currentPage' => 0},'status' => [{'info' => 'BrAPI base call found with page=0, pageSize=20'},{'info' => 'Loading CXGN::BrAPI::v1::Studies'},{'success' => 'StudyTypes list result constructed'}]}}, 'studyTypes');

$mech->get_ok('http://localhost:3010/brapi/v1/studyTypes?pageSize=2&page=2' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'status' => [{'info' => 'BrAPI base call found with page=2, pageSize=2'},{'info' => 'Loading CXGN::BrAPI::v1::Studies'},{'success' => 'StudyTypes list result constructed'}],'pagination' => {'totalCount' => 6,'totalPages' => 3,'pageSize' => 2,'currentPage' => 2},'datafiles' => []},'result' => {'data' => [{'studyTypeDbId' => 77105,'name' => 'Variety Release Trial','description' => undef},{'description' => undef,'name' => 'Clonal Evaluation','studyTypeDbId' => 77106}]}}, 'studyTypes');

$mech->post_ok('http://localhost:3010/brapi/v1/studies-search?pageSize=2&page=2' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'datafiles' => [],'pagination' => {'totalCount' => 9,'currentPage' => 2,'pageSize' => 2,'totalPages' => 5},'status' => [{'info' => 'BrAPI base call found with page=2, pageSize=2'},{'info' => 'Loading CXGN::BrAPI::v1::Studies'},{'success' => 'Studies-search result constructed'}]},'result' => {'data' => [{'trialDbId' => undef,'studyDbId' => 140,'programDbId' => undef,'startDate' => undef,'studyName' => 'test_genotyping_project','programName' => undef,'seasons' => ['2015'],'additionalInfo' => {'description' => 'test_genotyping_project','design' => undef},'trialName' => undef,'endDate' => undef,'studyType' => undef,'locationDbId' => undef,'locationName' => undef,'active' => ''},{'locationName' => undef,'active' => '','endDate' => undef,'studyType' => undef,'locationDbId' => undef,'programName' => undef,'studyName' => 'test_population2','seasons' => ['2015'],'trialName' => undef,'additionalInfo' => {'design' => undef,'description' => 'test_population2'},'trialDbId' => undef,'studyDbId' => 142,'programDbId' => undef,'startDate' => undef}]}}, 'studies-search');

$mech->post_ok('http://localhost:3010/brapi/v1/studies-search?pageSize=2&page=0&studyLocations=test_location' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'studyType' => undef,'locationDbId' => '23','endDate' => undef,'active' => '','locationName' => 'test_location','startDate' => undef,'programDbId' => 134,'studyDbId' => 165,'trialDbId' => undef,'trialName' => undef,'additionalInfo' => {'description' => 'Copy of trial with postcomposed phenotypes from cassbase.','design' => 'RCBD'},'seasons' => ['2017'],'programName' => 'test','studyName' => 'CASS_6Genotypes_Sampling_2015'},{'active' => '','locationName' => 'test_location','endDate' => undef,'studyType' => 'Clonal Evaluation','locationDbId' => '23','trialName' => undef,'additionalInfo' => {'description' => 'This trial was loaded into the fixture to test solgs.','design' => 'Alpha'},'studyName' => 'Kasese solgs trial','programName' => 'test','seasons' => ['2014'],'programDbId' => 134,'startDate' => undef,'trialDbId' => undef,'studyDbId' => 139}]},'metadata' => {'pagination' => {'pageSize' => 2,'totalPages' => 5,'currentPage' => 0,'totalCount' => 9},'datafiles' => [],'status' => [{'info' => 'BrAPI base call found with page=0, pageSize=2'},{'info' => 'Loading CXGN::BrAPI::v1::Studies'},{'success' => 'Studies-search result constructed'}]}}, 'studies-search');

$mech->post_ok('http://localhost:3010/brapi/v1/studies-search?pageSize=2&page=0&studyLocations=test_location&studyType=Clonal%20Evaluation' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'datafiles' => [],'pagination' => {'totalCount' => 9,'currentPage' => 0,'totalPages' => 5,'pageSize' => 2},'status' => [{'info' => 'BrAPI base call found with page=0, pageSize=2'},{'info' => 'Loading CXGN::BrAPI::v1::Studies'},{'success' => 'Studies-search result constructed'}]},'result' => {'data' => [{'endDate' => undef,'locationDbId' => '23','studyType' => undef,'locationName' => 'test_location','active' => '','trialDbId' => undef,'studyDbId' => 165,'programDbId' => 134,'startDate' => undef,'programName' => 'test','studyName' => 'CASS_6Genotypes_Sampling_2015','seasons' => ['2017'],'trialName' => undef,'additionalInfo' => {'description' => 'Copy of trial with postcomposed phenotypes from cassbase.','design' => 'RCBD'}},{'programName' => 'test','studyName' => 'Kasese solgs trial','seasons' => ['2014'],'additionalInfo' => {'design' => 'Alpha','description' => 'This trial was loaded into the fixture to test solgs.'},'trialName' => undef,'trialDbId' => undef,'studyDbId' => 139,'programDbId' => 134,'startDate' => undef,'locationName' => 'test_location','active' => '','endDate' => undef,'locationDbId' => '23','studyType' => 'Clonal Evaluation'}]}}, 'studies-search');

$mech->post_ok('http://localhost:3010/brapi/v1/studies-search?pageSize=2&page=0&programNames=test' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'status' => [{'info' => 'BrAPI base call found with page=0, pageSize=2'},{'info' => 'Loading CXGN::BrAPI::v1::Studies'},{'success' => 'Studies-search result constructed'}],'datafiles' => [],'pagination' => {'totalCount' => 6,'totalPages' => 3,'pageSize' => 2,'currentPage' => 0}},'result' => {'data' => [{'programDbId' => 134,'startDate' => undef,'trialDbId' => undef,'studyDbId' => 165,'trialName' => undef,'additionalInfo' => {'design' => 'RCBD','description' => 'Copy of trial with postcomposed phenotypes from cassbase.'},'studyName' => 'CASS_6Genotypes_Sampling_2015','programName' => 'test','seasons' => ['2017'],'endDate' => undef,'locationDbId' => '23','studyType' => undef,'active' => '','locationName' => 'test_location'},{'endDate' => undef,'studyType' => 'Clonal Evaluation','locationDbId' => '23','active' => '','locationName' => 'test_location','programDbId' => 134,'startDate' => undef,'trialDbId' => undef,'studyDbId' => 139,'trialName' => undef,'additionalInfo' => {'design' => 'Alpha','description' => 'This trial was loaded into the fixture to test solgs.'},'programName' => 'test','studyName' => 'Kasese solgs trial','seasons' => ['2014']}]}}, 'studies-search');

$mech->get_ok('http://localhost:3010/brapi/v1/locations?pageSize=1&page=1' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'datafiles' => [],'pagination' => {'totalPages' => 2,'totalCount' => 2,'currentPage' => 1,'pageSize' => 1},'status' => [{'info' => 'BrAPI base call found with page=1, pageSize=1'},{'info' => 'Loading CXGN::BrAPI::v1::Locations'},{'success' => 'Locations list result constructed'}]},'result' => {'data' => [{'countryName' => '','locationType' => '','additionalInfo' => {'geodetic datum' => undef},'altitude' => undef,'latitude' => undef,'countryCode' => '','longitude' => undef,'name' => 'Cornell Biotech','locationDbId' => 24,'abbreviation' => ''}]}}, 'location');


done_testing();
