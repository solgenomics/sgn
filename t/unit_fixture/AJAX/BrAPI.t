
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
is_deeply($response, {'metadata' => {'status' => [{'info' => 'BrAPI base call found with page=3, pageSize=2'},{'info' => 'Loading CXGN::BrAPI::v1::Germplasm'},{'success' => 'Germplasm-search result constructed'}],'datafiles' => [],'pagination' => {'pageSize' => 2,'totalPages' => 240,'totalCount' => 479,'currentPage' => 3}},'result' => {'data' => [{'defaultDisplayName' => 'new_test_crossP002','species' => 'Solanum lycopersicum','speciesAuthority' => undef,'instituteName' => undef,'subtaxaAuthority' => undef,'typeOfGermplasmStorageCode' => undef,'biologicalStatusOfAccessionCode' => undef,'germplasmDbId' => 38847,'genus' => 'Lycopersicon','acquisitionDate' => undef,'germplasmPUI' => undef,'synonyms' => [],'instituteCode' => undef,'subtaxa' => undef,'donors' => [],'accessionNumber' => undef,'commonCropName' => 'tomato','pedigree' => 'test_accession4/test_accession5','germplasmName' => 'new_test_crossP002','countryOfOriginCode' => undef,'germplasmSeedSource' => undef},{'pedigree' => 'test_accession4/test_accession5','commonCropName' => 'tomato','accessionNumber' => undef,'instituteCode' => undef,'donors' => [],'subtaxa' => undef,'germplasmSeedSource' => undef,'germplasmName' => 'new_test_crossP003','countryOfOriginCode' => undef,'acquisitionDate' => undef,'genus' => 'Lycopersicon','germplasmPUI' => undef,'synonyms' => [],'biologicalStatusOfAccessionCode' => undef,'typeOfGermplasmStorageCode' => undef,'subtaxaAuthority' => undef,'germplasmDbId' => 38848,'defaultDisplayName' => 'new_test_crossP003','instituteName' => undef,'speciesAuthority' => undef,'species' => 'Solanum lycopersicum'}]}}, 'germplasm-search');

$mech->get_ok('http://localhost:3010/brapi/v1/germplasm-search?pageSize=2&page=5');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'status' => [{'info' => 'BrAPI base call found with page=5, pageSize=2'},{'info' => 'Loading CXGN::BrAPI::v1::Germplasm'},{'success' => 'Germplasm-search result constructed'}],'datafiles' => [],'pagination' => {'pageSize' => 2,'currentPage' => 5,'totalPages' => 240,'totalCount' => 479}},'result' => {'data' => [{'synonyms' => [],'germplasmPUI' => undef,'genus' => 'Lycopersicon','acquisitionDate' => undef,'germplasmName' => 'new_test_crossP006','countryOfOriginCode' => undef,'germplasmSeedSource' => undef,'subtaxa' => undef,'accessionNumber' => undef,'donors' => [],'instituteCode' => undef,'commonCropName' => 'tomato','pedigree' => 'test_accession4/test_accession5','species' => 'Solanum lycopersicum','speciesAuthority' => undef,'instituteName' => undef,'defaultDisplayName' => 'new_test_crossP006','germplasmDbId' => 38851,'subtaxaAuthority' => undef,'typeOfGermplasmStorageCode' => undef,'biologicalStatusOfAccessionCode' => undef},{'germplasmDbId' => 38852,'subtaxaAuthority' => undef,'biologicalStatusOfAccessionCode' => undef,'typeOfGermplasmStorageCode' => undef,'speciesAuthority' => undef,'species' => 'Solanum lycopersicum','instituteName' => undef,'defaultDisplayName' => 'new_test_crossP007','germplasmName' => 'new_test_crossP007','countryOfOriginCode' => undef,'germplasmSeedSource' => undef,'accessionNumber' => undef,'donors' => [],'instituteCode' => undef,'subtaxa' => undef,'pedigree' => 'test_accession4/test_accession5','commonCropName' => 'tomato','germplasmPUI' => undef,'synonyms' => [],'genus' => 'Lycopersicon','acquisitionDate' => undef}]}}, 'germplasm-search');

$mech->get_ok('http://localhost:3010/brapi/v1/germplasm-search?pageSize=2&page=0&germplasmDbId=38849');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'datafiles' => [],'pagination' => {'pageSize' => 2,'currentPage' => 0,'totalCount' => 1,'totalPages' => 1},'status' => [{'info' => 'BrAPI base call found with page=0, pageSize=2'},{'info' => 'Loading CXGN::BrAPI::v1::Germplasm'},{'success' => 'Germplasm-search result constructed'}]},'result' => {'data' => [{'germplasmPUI' => undef,'commonCropName' => 'tomato','speciesAuthority' => undef,'subtaxa' => undef,'typeOfGermplasmStorageCode' => undef,'instituteName' => undef,'pedigree' => 'test_accession4/test_accession5','germplasmDbId' => 38849,'accessionNumber' => undef,'acquisitionDate' => undef,'genus' => 'Lycopersicon','species' => 'Solanum lycopersicum','subtaxaAuthority' => undef,'defaultDisplayName' => 'new_test_crossP004','donors' => [],'germplasmSeedSource' => undef,'countryOfOriginCode' => undef,'biologicalStatusOfAccessionCode' => undef,'synonyms' => [],'instituteCode' => undef,'germplasmName' => 'new_test_crossP004'}]}}, 'germplasm-search');

$mech->get_ok('http://localhost:3010/brapi/v1/germplasm-search?pageSize=2&page=4&germplasmName=te%&matchMethod=wildcard');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'synonyms' => [],'biologicalStatusOfAccessionCode' => undef,'instituteCode' => undef,'germplasmName' => 'new_test_crossP009','countryOfOriginCode' => undef,'donors' => [],'defaultDisplayName' => 'new_test_crossP009','germplasmSeedSource' => undef,'species' => 'Solanum lycopersicum','genus' => 'Lycopersicon','acquisitionDate' => undef,'germplasmDbId' => 38854,'accessionNumber' => undef,'subtaxaAuthority' => undef,'commonCropName' => 'tomato','germplasmPUI' => undef,'typeOfGermplasmStorageCode' => undef,'instituteName' => undef,'pedigree' => 'test_accession4/test_accession5','speciesAuthority' => undef,'subtaxa' => undef},{'typeOfGermplasmStorageCode' => undef,'instituteName' => undef,'pedigree' => 'test_accession4/test_accession5','speciesAuthority' => undef,'subtaxa' => undef,'commonCropName' => 'tomato','germplasmPUI' => undef,'subtaxaAuthority' => undef,'species' => 'Solanum lycopersicum','genus' => 'Lycopersicon','accessionNumber' => undef,'germplasmDbId' => 38855,'acquisitionDate' => undef,'countryOfOriginCode' => undef,'donors' => [],'defaultDisplayName' => 'new_test_crossP010','germplasmSeedSource' => undef,'germplasmName' => 'new_test_crossP010','biologicalStatusOfAccessionCode' => undef,'synonyms' => [],'instituteCode' => undef}]},'metadata' => {'status' => [{'info' => 'BrAPI base call found with page=4, pageSize=2'},{'info' => 'Loading CXGN::BrAPI::v1::Germplasm'},{'success' => 'Germplasm-search result constructed'}],'pagination' => {'totalPages' => 13,'totalCount' => 25,'currentPage' => 4,'pageSize' => 2},'datafiles' => []}}, 'germplasm-search');

$mech->post_ok('http://localhost:3010/brapi/v1/germplasm-search', ['pageSize'=>'1', 'page'=>'5', 'germplasmName'=>'t%', 'matchMethod'=>'wildcard'] );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'status' => [{'info' => 'BrAPI base call found with page=5, pageSize=1'},{'info' => 'Loading CXGN::BrAPI::v1::Germplasm'},{'success' => 'Germplasm-search result constructed'}],'pagination' => {'totalPages' => 31,'pageSize' => 1,'currentPage' => 5,'totalCount' => 31},'datafiles' => []},'result' => {'data' => [{'defaultDisplayName' => 'new_test_crossP002','instituteName' => undef,'germplasmName' => 'new_test_crossP002','genus' => 'Lycopersicon','accessionNumber' => undef,'instituteCode' => undef,'commonCropName' => 'tomato','biologicalStatusOfAccessionCode' => undef,'typeOfGermplasmStorageCode' => undef,'subtaxaAuthority' => undef,'subtaxa' => undef,'synonyms' => [],'germplasmPUI' => undef,'donors' => [],'acquisitionDate' => undef,'countryOfOriginCode' => undef,'speciesAuthority' => undef,'germplasmSeedSource' => undef,'pedigree' => 'test_accession4/test_accession5','species' => 'Solanum lycopersicum','germplasmDbId' => 38847}]}}, 'germplasm-search post');

$mech->get_ok('http://localhost:3010/brapi/v1/germplasm/38876');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'donors' => [],'acquisitionDate' => undef,'germplasmSeedSource' => undef,'synonyms' => [],'subtaxa' => undef,'countryOfOriginCode' => undef,'instituteCode' => undef,'biologicalStatusOfAccessionCode' => undef,'pedigree' => 'test_accession4/test_accession5','germplasmDbId' => 38876,'germplasmPUI' => undef,'subtaxaAuthority' => undef,'accessionNumber' => undef,'germplasmName' => 'test5P004','typeOfGermplasmStorageCode' => undef,'commonCropName' => 'tomato','species' => 'Solanum lycopersicum','instituteName' => undef,'defaultDisplayName' => 'test5P004','speciesAuthority' => undef,'genus' => 'Lycopersicon'},'metadata' => {'pagination' => {'totalPages' => 1,'pageSize' => 1,'currentPage' => 0,'totalCount' => 1},'datafiles' => [],'status' => [{'info' => 'BrAPI base call found with page=0, pageSize=10'},{'info' => 'Loading CXGN::BrAPI::v1::Germplasm'},{'success' => 'Germplasm detail result constructed'}]}}, 'germplasm detail');

$mech->get_ok('http://localhost:3010/brapi/v1/germplasm/38876/pedigree');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'datafiles' => [],'status' => [{'info' => 'BrAPI base call found with page=0, pageSize=10'},{'info' => 'Loading CXGN::BrAPI::v1::Germplasm'},{'success' => 'Germplasm pedigree result constructed'}],'pagination' => {'currentPage' => 0,'pageSize' => 1,'totalCount' => 1,'totalPages' => 1}},'result' => {'parent2Id' => 38844,'germplasmDbId' => '38876','pedigree' => 'test_accession4/test_accession5','parent1Id' => 38843}}, 'germplasm pedigree');

$mech->get_ok('http://localhost:3010/brapi/v1/germplasm/38937/markerprofiles');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'germplasmDbId' => '38937','markerProfiles' => [1622,1934]},'metadata' => {'pagination' => {'totalCount' => 2,'pageSize' => 10,'currentPage' => 0,'totalPages' => 1},'datafiles' => [],'status' => [{'info' => 'BrAPI base call found with page=0, pageSize=10'},{'info' => 'Loading CXGN::BrAPI::v1::Germplasm'},{'success' => 'Germplasm markerprofiles result constructed'}]}}, 'germplasm markerprofile');

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
is_deeply($response, {'metadata' => {'pagination' => undef,'datafiles' => [],'status' => [{'info' => 'BrAPI base call found with page=0, pageSize=10'},{'info' => 'Loading CXGN::BrAPI::v1::Markerprofiles'},{'success' => 'Markerprofiles detail result constructed'}]},'result' => {'analysisMethod' => 'GBS ApeKI genotyping v4','uniqueDisplayName' => 'UG120156','germplasmDbId' => 39007,'data' => [{'S5_36739' => 'BB'},{'S13_92567' => 'BB'},{'S69_57277' => 'BB'},{'S80_224901' => 'AA'},{'S80_232173' => 'BB'},{'S80_265728' => 'AA'},{'S97_219243' => 'AB'},{'S224_309814' => 'BB'},{'S248_174244' => 'BB'},{'S318_245078' => 'AA'}],'extractDbId' => 'UG120156|78265','markerprofileDbId' => '1627'}}, 'markerprofile');

$mech->post_ok('http://localhost:3010/brapi/v1/allelematrix-search', ['markerprofileDbId'=>[1626,1627], 'format'=>'json'] );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'datafiles' => [],'status' => [{'info' => 'BrAPI base call found with page=0, pageSize=10'},{'info' => 'Loading CXGN::BrAPI::v1::Markerprofiles'},{'success' => 'Markerprofiles allelematrix result constructed'}],'pagination' => {'totalCount' => 1000,'currentPage' => 0,'pageSize' => 10,'totalPages' => 100}},'result' => {'data' => [['S10114_185859',1626,'BB'],['S10173_777651',1626,'BB'],['S10173_899514',1626,'BB'],['S10241_146006',1626,'AA'],['S1027_465354',1626,'AA'],['S10367_21679',1626,'AA'],['S1046_216535',1626,'AB'],['S10493_191533',1626,'BB'],['S10493_282956',1626,'AB']]}}, 'allelematrix-search');

$mech->get_ok('http://localhost:3010/brapi/v1/programs' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'status' => [{'info' => 'BrAPI base call found with page=0, pageSize=10'},{'info' => 'Loading CXGN::BrAPI::v1::Programs'},{'success' => 'Program list result constructed'}],'datafiles' => [],'pagination' => {'pageSize' => 10,'currentPage' => 0,'totalCount' => 1,'totalPages' => 1}},'result' => {'data' => [{'abbreviation' => '','name' => 'test','programDbId' => 134,'leadPerson' => '','objective' => 'test'}]}}, 'programs');

$mech->get_ok('http://localhost:3010/brapi/v1/crops' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'status' => [{'info' => 'BrAPI base call found with page=0, pageSize=10'},{'info' => 'Loading CXGN::BrAPI::v1::Crops'},{'success' => 'Crops result constructed'}],'datafiles' => [],'pagination' => {'totalCount' => 1,'currentPage' => 0,'pageSize' => 10,'totalPages' => 1}},'result' => {'data' => ['Cassava']}}, 'crops');

$mech->get_ok('http://localhost:3010/brapi/v1/studyTypes' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'studyTypeDbId' => 76464,'name' => 'Seedling Nursery','description' => 'seedling'},{'studyTypeDbId' => 76514,'description' => undef,'name' => 'Advanced Yield Trial'},{'name' => 'Preliminary Yield Trial','description' => undef,'studyTypeDbId' => 76515},{'studyTypeDbId' => 76516,'name' => 'Uniform Yield Trial','description' => undef},{'name' => 'Variety Release Trial','description' => undef,'studyTypeDbId' => 77105},{'studyTypeDbId' => 77106,'name' => 'Clonal Evaluation','description' => undef}]},'metadata' => {'datafiles' => [],'status' => [{'info' => 'BrAPI base call found with page=0, pageSize=10'},{'info' => 'Loading CXGN::BrAPI::v1::Studies'},{'success' => 'StudyTypes list result constructed'}],'pagination' => {'pageSize' => 10,'currentPage' => 0,'totalCount' => 6,'totalPages' => 1}}}, 'studyTypes');

$mech->get_ok('http://localhost:3010/brapi/v1/studyTypes?pageSize=2&page=2' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'status' => [{'info' => 'BrAPI base call found with page=2, pageSize=2'},{'info' => 'Loading CXGN::BrAPI::v1::Studies'},{'success' => 'StudyTypes list result constructed'}],'pagination' => {'totalCount' => 6,'totalPages' => 3,'pageSize' => 2,'currentPage' => 2},'datafiles' => []},'result' => {'data' => [{'studyTypeDbId' => 77105,'name' => 'Variety Release Trial','description' => undef},{'description' => undef,'name' => 'Clonal Evaluation','studyTypeDbId' => 77106}]}}, 'studyTypes');

$mech->post_ok('http://localhost:3010/brapi/v1/studies-search?pageSize=2&page=3' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'trialName' => undef,'locationName' => 'test_location','studyType' => undef,'locationDbId' => '23','active' => '','startDate' => undef,'additionalInfo' => {'design' => 'CRD','description' => 'test tets'},'endDate' => undef,'programDbId' => 134,'studyDbId' => 144,'programName' => 'test','studyName' => 'test_t','trialDbId' => undef,'seasons' => ['2016']},{'programDbId' => 134,'endDate' => undef,'studyDbId' => 137,'locationName' => 'test_location','trialName' => undef,'additionalInfo' => {'design' => 'CRD','description' => 'test trial'},'startDate' => undef,'active' => '','locationDbId' => '23','studyType' => undef,'seasons' => ['2014'],'trialDbId' => undef,'studyName' => 'test_trial','programName' => 'test'}]},'metadata' => {'status' => [{'info' => 'BrAPI base call found with page=3, pageSize=2'},{'info' => 'Loading CXGN::BrAPI::v1::Studies'},{'success' => 'Studies-search result constructed'}],'pagination' => {'currentPage' => 3,'totalCount' => 9,'totalPages' => 5,'pageSize' => 2},'datafiles' => []}}, 'studies-search');

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
