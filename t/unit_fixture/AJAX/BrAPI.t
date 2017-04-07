
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
is_deeply($response, {'result' => {'data' => [{'accessionNumber' => undef,'germplasmPUI' => undef,'germplasmDbId' => 38851,'instituteCode' => undef,'acquisitionDate' => undef,'subtaxa' => undef,'germplasmName' => 'new_test_crossP006','commonCropName' => 'tomato','speciesAuthority' => undef,'countryOfOriginCode' => undef,'subtaxaAuthority' => undef,'germplasmSeedSource' => undef,'defaultDisplayName' => 'new_test_crossP006','typeOfGermplasmStorageCode' => undef,'species' => 'Solanum lycopersicum','donors' => [{'germplasmPUI' => undef,'donorGermplasmName' => undef,'donorInstituteCode' => undef,'donorAccessionNumber' => undef}],'biologicalStatusOfAccessionCode' => undef,'genus' => 'Lycopersicon','instituteName' => undef,'synonyms' => undef,'pedigree' => 'test_accession4/test_accession5'},{'instituteCode' => undef,'acquisitionDate' => undef,'subtaxa' => undef,'germplasmName' => 'new_test_crossP007','commonCropName' => 'tomato','speciesAuthority' => undef,'countryOfOriginCode' => undef,'subtaxaAuthority' => undef,'accessionNumber' => undef,'germplasmPUI' => undef,'germplasmDbId' => 38852,'synonyms' => undef,'pedigree' => 'test_accession4/test_accession5','germplasmSeedSource' => undef,'species' => 'Solanum lycopersicum','defaultDisplayName' => 'new_test_crossP007','typeOfGermplasmStorageCode' => undef,'donors' => [{'donorGermplasmName' => undef,'germplasmPUI' => undef,'donorInstituteCode' => undef,'donorAccessionNumber' => undef}],'biologicalStatusOfAccessionCode' => undef,'genus' => 'Lycopersicon','instituteName' => undef}]},'metadata' => {'pagination' => {'totalCount' => 473,'pageSize' => 2,'totalPages' => 237,'currentPage' => 3},'datafiles' => [],'status' => [{'info' => 'BrAPI base call found with page=3, pageSize=2'},{'info' => 'Loading CXGN::BrAPI::v1::Germplasm'},{'success' => 'Germplasm-search result constructed'}]}}, 'germplasm-search');

$mech->get_ok('http://localhost:3010/brapi/v1/germplasm-search?pageSize=2&page=5');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'status' => [{'info' => 'BrAPI base call found with page=5, pageSize=2'},{'info' => 'Loading CXGN::BrAPI::v1::Germplasm'},{'success' => 'Germplasm-search result constructed'}],'pagination' => {'totalPages' => 237,'currentPage' => 5,'totalCount' => 473,'pageSize' => 2},'datafiles' => []},'result' => {'data' => [{'donors' => [{'donorAccessionNumber' => undef,'donorInstituteCode' => undef,'donorGermplasmName' => undef,'germplasmPUI' => undef}],'genus' => 'Lycopersicon','biologicalStatusOfAccessionCode' => undef,'instituteName' => undef,'germplasmSeedSource' => undef,'species' => 'Solanum lycopersicum','typeOfGermplasmStorageCode' => undef,'defaultDisplayName' => 'new_test_crossP010','pedigree' => 'test_accession4/test_accession5','synonyms' => undef,'germplasmDbId' => 38855,'accessionNumber' => undef,'germplasmPUI' => undef,'speciesAuthority' => undef,'countryOfOriginCode' => undef,'subtaxaAuthority' => undef,'instituteCode' => undef,'acquisitionDate' => undef,'germplasmName' => 'new_test_crossP010','commonCropName' => 'tomato','subtaxa' => undef},{'germplasmPUI' => undef,'accessionNumber' => undef,'germplasmDbId' => 38873,'commonCropName' => 'tomato','subtaxa' => undef,'germplasmName' => 'test5P001','acquisitionDate' => undef,'instituteCode' => undef,'subtaxaAuthority' => undef,'speciesAuthority' => undef,'countryOfOriginCode' => undef,'defaultDisplayName' => 'test5P001','species' => 'Solanum lycopersicum','typeOfGermplasmStorageCode' => undef,'germplasmSeedSource' => undef,'instituteName' => undef,'genus' => 'Lycopersicon','biologicalStatusOfAccessionCode' => undef,'donors' => [{'donorInstituteCode' => undef,'donorAccessionNumber' => undef,'donorGermplasmName' => undef,'germplasmPUI' => undef}],'synonyms' => undef,'pedigree' => 'test_accession4/test_accession5'}]}}, 'germplasm-search');

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
is_deeply($response, {'result' => {'data' => [{'speciesAuthority' => undef,'countryOfOriginCode' => undef,'subtaxaAuthority' => undef,'instituteCode' => undef,'commonCropName' => 'tomato','germplasmName' => 'new_test_crossP006','subtaxa' => undef,'acquisitionDate' => undef,'germplasmDbId' => 38851,'germplasmPUI' => undef,'accessionNumber' => undef,'synonyms' => undef,'pedigree' => 'test_accession4/test_accession5','biologicalStatusOfAccessionCode' => undef,'genus' => 'Lycopersicon','donors' => [{'germplasmPUI' => undef,'donorGermplasmName' => undef,'donorInstituteCode' => undef,'donorAccessionNumber' => undef}],'instituteName' => undef,'species' => 'Solanum lycopersicum','defaultDisplayName' => 'new_test_crossP006','typeOfGermplasmStorageCode' => undef,'germplasmSeedSource' => undef}]},'metadata' => {'status' => [{'info' => 'BrAPI base call found with page=5, pageSize=1'},{'info' => 'Loading CXGN::BrAPI::v1::Germplasm'},{'success' => 'Germplasm-search result constructed'}],'datafiles' => [],'pagination' => {'totalCount' => 25,'pageSize' => 1,'totalPages' => 25,'currentPage' => 5}}}, 'germplasm-search post');

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
is_deeply($response, {'metadata' => {'datafiles' => [],'status' => [{'info' => 'BrAPI base call found with page=2, pageSize=2'},{'info' => 'Loading CXGN::BrAPI::v1::Studies'},{'success' => 'Studies-search result constructed'}],'pagination' => {'pageSize' => 2,'currentPage' => 2,'totalCount' => 8,'totalPages' => 4}},'result' => {'data' => [{'programDbId' => undef,'startDate' => undef,'seasons' => ['2015'],'additionalInfo' => {'description' => 'test_population2','design' => undef},'locationName' => undef,'trialName' => undef,'endDate' => undef,'studyName' => 'test_population2','active' => '','trialDbId' => undef,'studyDbId' => 142,'studyType' => undef,'programName' => undef,'locationDbId' => undef},{'seasons' => ['2016'],'additionalInfo' => {'description' => 'test tets','design' => 'CRD'},'locationName' => 'test_location','trialName' => undef,'endDate' => undef,'programDbId' => 134,'startDate' => undef,'studyDbId' => 144,'studyType' => undef,'programName' => 'test','locationDbId' => '23','studyName' => 'test_t','active' => '','trialDbId' => undef}]}}, 'studies-search');

$mech->post_ok('http://localhost:3010/brapi/v1/studies-search?pageSize=2&page=0&studyLocations=test_location' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'programDbId' => 134,'startDate' => undef,'endDate' => undef,'trialName' => undef,'locationName' => 'test_location','additionalInfo' => {'design' => 'Alpha','description' => 'This trial was loaded into the fixture to test solgs.'},'seasons' => ['2014'],'trialDbId' => undef,'active' => '','studyName' => 'Kasese solgs trial','programName' => 'test','locationDbId' => '23','studyType' => 'Clonal Evaluation','studyDbId' => 139},{'studyName' => 'new_test_cross','active' => '','trialDbId' => undef,'studyDbId' => 135,'studyType' => undef,'locationDbId' => undef,'programName' => 'test','startDate' => undef,'programDbId' => 134,'seasons' => [undef],'additionalInfo' => {'description' => 'new_test_cross','design' => undef},'locationName' => undef,'trialName' => undef,'endDate' => undef}]},'metadata' => {'status' => [{'info' => 'BrAPI base call found with page=0, pageSize=2'},{'info' => 'Loading CXGN::BrAPI::v1::Studies'},{'success' => 'Studies-search result constructed'}],'pagination' => {'totalCount' => 8,'totalPages' => 4,'currentPage' => 0,'pageSize' => 2},'datafiles' => []}}, 'studies-search');

$mech->post_ok('http://localhost:3010/brapi/v1/studies-search?pageSize=2&page=0&studyLocations=test_location&studyType=Clonal%20Evaluation' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'datafiles' => [],'status' => [{'info' => 'BrAPI base call found with page=0, pageSize=2'},{'info' => 'Loading CXGN::BrAPI::v1::Studies'},{'success' => 'Studies-search result constructed'}],'pagination' => {'pageSize' => 2,'totalCount' => 8,'totalPages' => 4,'currentPage' => 0}},'result' => {'data' => [{'active' => '','studyName' => 'Kasese solgs trial','trialDbId' => undef,'studyDbId' => 139,'locationDbId' => '23','programName' => 'test','studyType' => 'Clonal Evaluation','programDbId' => 134,'startDate' => undef,'locationName' => 'test_location','additionalInfo' => {'description' => 'This trial was loaded into the fixture to test solgs.','design' => 'Alpha'},'seasons' => ['2014'],'endDate' => undef,'trialName' => undef},{'studyName' => 'new_test_cross','active' => '','trialDbId' => undef,'studyDbId' => 135,'studyType' => undef,'programName' => 'test','locationDbId' => undef,'programDbId' => 134,'startDate' => undef,'seasons' => [undef],'additionalInfo' => {'design' => undef,'description' => 'new_test_cross'},'locationName' => undef,'trialName' => undef,'endDate' => undef}]}}, 'studies-search');

$mech->post_ok('http://localhost:3010/brapi/v1/studies-search?pageSize=2&page=0&programNames=test' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'endDate' => undef,'trialName' => undef,'locationName' => 'test_location','seasons' => ['2014'],'additionalInfo' => {'design' => 'Alpha','description' => 'This trial was loaded into the fixture to test solgs.'},'startDate' => undef,'programDbId' => 134,'locationDbId' => '23','programName' => 'test','studyType' => 'Clonal Evaluation','studyDbId' => 139,'trialDbId' => undef,'active' => '','studyName' => 'Kasese solgs trial'},{'trialName' => undef,'endDate' => undef,'additionalInfo' => {'design' => undef,'description' => 'new_test_cross'},'seasons' => [undef],'locationName' => undef,'startDate' => undef,'programDbId' => 134,'studyType' => undef,'locationDbId' => undef,'programName' => 'test','studyDbId' => 135,'trialDbId' => undef,'studyName' => 'new_test_cross','active' => ''}]},'metadata' => {'datafiles' => [],'status' => [{'info' => 'BrAPI base call found with page=0, pageSize=2'},{'info' => 'Loading CXGN::BrAPI::v1::Studies'},{'success' => 'Studies-search result constructed'}],'pagination' => {'pageSize' => 2,'totalCount' => 5,'totalPages' => 3,'currentPage' => 0}}}, 'studies-search');

$mech->get_ok('http://localhost:3010/brapi/v1/locations?pageSize=1&page=1' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'datafiles' => [],'pagination' => {'totalPages' => 2,'totalCount' => 2,'currentPage' => 1,'pageSize' => 1},'status' => [{'info' => 'BrAPI base call found with page=1, pageSize=1'},{'info' => 'Loading CXGN::BrAPI::v1::Locations'},{'success' => 'Locations list result constructed'}]},'result' => {'data' => [{'countryName' => '','locationType' => '','additionalInfo' => {'geodetic datum' => undef},'altitude' => undef,'latitude' => undef,'countryCode' => '','longitude' => undef,'name' => 'Cornell Biotech','locationDbId' => 24,'abbreviation' => ''}]}}, 'location');


done_testing();
