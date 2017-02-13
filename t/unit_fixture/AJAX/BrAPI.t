
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

is_deeply($response, {'metadata' => {'datafiles' => [],'status' => [{}],'pagination' => {'totalCount' => 32,'currentPage' => 3,'pageSize' => 5,'totalPages' => 7}},'result' => {'data' => [{'datatypes' => ['json'],'call' => 'seasons','methods' => ['GET','POST']},{'datatypes' => ['json'],'methods' => ['GET','POST'],'call' => 'studyTypes'},{'methods' => ['GET','POST'],'call' => 'trials','datatypes' => ['json']},{'datatypes' => ['json'],'methods' => ['GET'],'call' => 'trials/id'},{'datatypes' => ['json'],'call' => 'studies-search','methods' => ['GET','POST']}]}}, 'check calls response content');

$mech->get_ok('http://localhost:3010/brapi/v1/calls?pageSize=50&datatype=tsv');
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'metadata' => {'status' => [{}],'pagination' => {'totalPages' => 1,'currentPage' => 0,'totalCount' => 32,'pageSize' => 50},'datafiles' => []},'result' => {'data' => [{'datatypes' => ['json','tsv','csv'],'methods' => ['GET','POST'],'call' => 'allelematrix-search'}]}}, 'check calls response content');

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->[0]->{'message'}, 'Login Successfull');
is($response->{'userDisplayName'}, 'Jane Doe');
is($response->{'expires_in'}, '7200');

$mech->delete_ok('http://localhost:3010/brapi/v1/token');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->[0]->{'message'}, 'Successfully logged out.');

$mech->get_ok('http://localhost:3010/brapi/v1/germplasm-search?pageSize=2&page=3');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'pagination' => {'totalPages' => 237,'pageSize' => 2,'currentPage' => 3,'totalCount' => 473},'datafiles' => [],'status' => [{'message' => ''}]},'result' => {'data' => [{'defaultDisplayName' => 'new_test_crossP002','typeOfGermplasmStorageCode' => 'Not Stored','pedigree' => 'test_accession4/test_accession5','instituteCode' => '','acquisitionDate' => '','germplasmDbId' => 38847,'species' => 'Solanum lycopersicum','commonCropName' => 'tomato','accessionNumber' => 'new_test_crossP002','instituteName' => '','germplasmSeedSource' => '','germplasmPUI' => 'http://localhost/stock/38847/view','subtaxaAuthority' => '','germplasmName' => 'new_test_crossP002','synonyms' => [],'speciesAuthority' => '','countryOfOriginCode' => '','donors' => [],'biologicalStatusOfAccessionCode' => '','subtaxa' => '','genus' => 'Lycopersicon'},{'acquisitionDate' => '','instituteCode' => '','pedigree' => 'test_accession4/test_accession5','defaultDisplayName' => 'new_test_crossP003','typeOfGermplasmStorageCode' => 'Not Stored','instituteName' => '','germplasmSeedSource' => '','accessionNumber' => 'new_test_crossP003','species' => 'Solanum lycopersicum','commonCropName' => 'tomato','germplasmDbId' => 38848,'synonyms' => [],'germplasmName' => 'new_test_crossP003','subtaxaAuthority' => '','germplasmPUI' => 'http://localhost/stock/38848/view','genus' => 'Lycopersicon','subtaxa' => '','biologicalStatusOfAccessionCode' => '','donors' => [],'countryOfOriginCode' => '','speciesAuthority' => ''}]}}, 'germplasm-search');

$mech->get_ok('http://localhost:3010/brapi/v1/germplasm-search?pageSize=2&page=5');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'pagination' => {'totalPages' => 237,'currentPage' => 5,'totalCount' => 473,'pageSize' => 2},'datafiles' => [],'status' => [{'message' => ''}]},'result' => {'data' => [{'genus' => 'Lycopersicon','biologicalStatusOfAccessionCode' => '','subtaxa' => '','countryOfOriginCode' => '','donors' => [],'speciesAuthority' => '','germplasmName' => 'new_test_crossP006','synonyms' => [],'germplasmPUI' => 'http://localhost/stock/38851/view','subtaxaAuthority' => '','instituteName' => '','germplasmSeedSource' => '','accessionNumber' => 'new_test_crossP006','commonCropName' => 'tomato','species' => 'Solanum lycopersicum','germplasmDbId' => 38851,'acquisitionDate' => '','defaultDisplayName' => 'new_test_crossP006','typeOfGermplasmStorageCode' => 'Not Stored','instituteCode' => '','pedigree' => 'test_accession4/test_accession5'},{'acquisitionDate' => '','typeOfGermplasmStorageCode' => 'Not Stored','defaultDisplayName' => 'new_test_crossP007','instituteCode' => '','pedigree' => 'test_accession4/test_accession5','instituteName' => '','germplasmSeedSource' => '','accessionNumber' => 'new_test_crossP007','commonCropName' => 'tomato','species' => 'Solanum lycopersicum','germplasmDbId' => 38852,'germplasmName' => 'new_test_crossP007','synonyms' => [],'germplasmPUI' => 'http://localhost/stock/38852/view','subtaxaAuthority' => '','genus' => 'Lycopersicon','biologicalStatusOfAccessionCode' => '','subtaxa' => '','donors' => [],'speciesAuthority' => '','countryOfOriginCode' => ''}]}}, 'germplasm-search');

$mech->get_ok('http://localhost:3010/brapi/v1/germplasm-search?pageSize=2&page=0&germplasmDbId=38849');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'status' => [{'message' => ''}],'pagination' => {'totalCount' => 1,'pageSize' => 2,'currentPage' => 0,'totalPages' => 1},'datafiles' => []},'result' => {'data' => [{'speciesAuthority' => '','genus' => 'Lycopersicon','instituteName' => '','typeOfGermplasmStorageCode' => 'Not Stored','species' => 'Solanum lycopersicum','germplasmPUI' => 'http://localhost/stock/38849/view','pedigree' => 'test_accession4/test_accession5','accessionNumber' => 'new_test_crossP004','defaultDisplayName' => 'new_test_crossP004','commonCropName' => 'tomato','subtaxa' => '','germplasmDbId' => 38849,'synonyms' => [],'germplasmName' => 'new_test_crossP004','countryOfOriginCode' => '','biologicalStatusOfAccessionCode' => '','instituteCode' => '','germplasmSeedSource' => '','donors' => [],'subtaxaAuthority' => '','acquisitionDate' => ''}]}}, 'germplasm-search');

$mech->get_ok('http://localhost:3010/brapi/v1/germplasm-search?pageSize=2&page=4&germplasmName=te%&matchMethod=wildcard');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'donors' => [],'commonCropName' => 'tomato','germplasmSeedSource' => '','countryOfOriginCode' => '','instituteCode' => '','accessionNumber' => 'test5P004','germplasmDbId' => 38876,'subtaxaAuthority' => '','instituteName' => '','germplasmName' => 'test5P004','biologicalStatusOfAccessionCode' => '','pedigree' => 'test_accession4/test_accession5','typeOfGermplasmStorageCode' => 'Not Stored','genus' => 'Lycopersicon','speciesAuthority' => '','defaultDisplayName' => 'test5P004','synonyms' => [],'species' => 'Solanum lycopersicum','acquisitionDate' => '','subtaxa' => '','germplasmPUI' => 'http://localhost/stock/38876/view'},{'biologicalStatusOfAccessionCode' => '','pedigree' => 'test_accession4/test_accession5','subtaxaAuthority' => '','instituteName' => '','germplasmName' => 'test5P005','countryOfOriginCode' => '','instituteCode' => '','accessionNumber' => 'test5P005','germplasmDbId' => 38877,'donors' => [],'commonCropName' => 'tomato','germplasmSeedSource' => '','germplasmPUI' => 'http://localhost/stock/38877/view','defaultDisplayName' => 'test5P005','species' => 'Solanum lycopersicum','synonyms' => [],'acquisitionDate' => '','subtaxa' => '','genus' => 'Lycopersicon','speciesAuthority' => '','typeOfGermplasmStorageCode' => 'Not Stored'}]},'metadata' => {'pagination' => {'totalCount' => 15,'totalPages' => 8,'pageSize' => 2,'currentPage' => 4},'status' => [{'message' => ''}],'datafiles' => []}}, 'germplasm-search');

$mech->post_ok('http://localhost:3010/brapi/v1/germplasm-search', ['pageSize'=>'1', 'page'=>'5', 'germplasmName'=>'t%', 'matchMethod'=>'wildcard'] );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'donors' => [],'germplasmSeedSource' => '','acquisitionDate' => '','subtaxaAuthority' => '','instituteCode' => '','biologicalStatusOfAccessionCode' => '','germplasmDbId' => 38873,'countryOfOriginCode' => '','synonyms' => [],'germplasmName' => 'test5P001','commonCropName' => 'tomato','defaultDisplayName' => 'test5P001','subtaxa' => '','accessionNumber' => 'test5P001','typeOfGermplasmStorageCode' => 'Not Stored','instituteName' => '','pedigree' => 'test_accession4/test_accession5','species' => 'Solanum lycopersicum','germplasmPUI' => 'http://localhost/stock/38873/view','genus' => 'Lycopersicon','speciesAuthority' => ''}]},'metadata' => {'pagination' => {'totalPages' => 15,'pageSize' => 1,'totalCount' => 15,'currentPage' => 5},'datafiles' => [],'status' => [{'message' => ''}]}}, 'germplasm-search post');

$mech->get_ok('http://localhost:3010/brapi/v1/germplasm/38876');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'pedigree' => 'test_accession4/test_accession5','species' => 'Solanum lycopersicum','germplasmPUI' => 'test5P004','typeOfGermplasmStorageCode' => 'Not Stored','instituteName' => '','accessionNumber' => 'test5P004','speciesAuthority' => '','genus' => 'Lycopersicon','instituteCode' => '','biologicalStatusOfAccessionCode' => '','acquisitionDate' => '','subtaxaAuthority' => '','donors' => [],'germplasmSeedSource' => '','subtaxa' => '','defaultDisplayName' => 'test5P004','commonCropName' => 'tomato','countryOfOriginCode' => '','synonyms' => [],'germplasmName' => 'test5P004','germplasmDbId' => '38876'},'metadata' => {'datafiles' => [],'pagination' => {'currentPage' => 0,'pageSize' => 20,'totalCount' => 1,'totalPages' => 1},'status' => [{}]}}, 'germplasm detail');

$mech->get_ok('http://localhost:3010/brapi/v1/germplasm/38876/pedigree');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'datafiles' => [],'pagination' => {'totalPages' => 1,'totalCount' => 1,'pageSize' => 20,'currentPage' => 0},'status' => [{'message' => ''}]},'result' => {'parent2Id' => 38844,'pedigree' => 'test_accession4/test_accession5','germplasmDbId' => '38876','parent1Id' => 38843}}, 'germplasm pedigree');

$mech->get_ok('http://localhost:3010/brapi/v1/germplasm/38937/markerprofiles');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'status' => [{}],'datafiles' => [],'pagination' => {'totalPages' => 1,'totalCount' => 2,'pageSize' => 20,'currentPage' => 0}},'result' => {'germplasmDbId' => '38937','markerProfiles' => [1622,1934]}}, 'germplasm markerprofile');

$mech->get_ok('http://localhost:3010/brapi/v1/markerprofiles?pageSize=2&page=3');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'pagination' => {'totalPages' => 1,'pageSize' => 2,'totalCount' => 2,'currentPage' => 3},'datafiles' => [],'status' => [{'message' => '','code' => 'message'}]},'result' => {'data' => [{'uniqueDisplayName' => 'UG120178|78266','germplasmDbId' => 39027,'resultCount' => 500,'markerProfileDbId' => 1628,'extractDbId' => '','sampleDbId' => '','analysisMethod' => 'GBS ApeKI genotyping v4'},{'extractDbId' => '','analysisMethod' => 'GBS ApeKI genotyping v4','sampleDbId' => '','markerProfileDbId' => 1629,'uniqueDisplayName' => 'UG120179|78267','germplasmDbId' => 39028,'resultCount' => 500}]}}, 'markerprofile');

$mech->get_ok('http://localhost:3010/brapi/v1/markerprofiles?pageSize=1&page=1&germplasmDbId=38937');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'analysisMethod' => 'GBS ApeKI genotyping v4','sampleDbId' => '','extractDbId' => '','markerProfileDbId' => 1934,'resultCount' => 500,'germplasmDbId' => 38937,'uniqueDisplayName' => 'UG120066|79802'}]},'metadata' => {'datafiles' => [],'pagination' => {'currentPage' => 1,'totalCount' => 1,'totalPages' => 1,'pageSize' => 1},'status' => [{'message' => '','code' => 'message'}]}}, 'markerprofile');

$mech->get_ok('http://localhost:3010/brapi/v1/markerprofiles?pageSize=2&page=3&methodDbId=1');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'datafiles' => [],'pagination' => {'totalPages' => 1,'pageSize' => 2,'currentPage' => 3,'totalCount' => 2},'status' => [{'message' => '','code' => 'message'}]},'result' => {'data' => [{'analysisMethod' => 'GBS ApeKI genotyping v4','sampleDbId' => '','extractDbId' => '','uniqueDisplayName' => 'UG120178|78266','germplasmDbId' => 39027,'resultCount' => 500,'markerProfileDbId' => 1628},{'markerProfileDbId' => 1629,'uniqueDisplayName' => 'UG120179|78267','germplasmDbId' => 39028,'resultCount' => 500,'analysisMethod' => 'GBS ApeKI genotyping v4','extractDbId' => '','sampleDbId' => ''}]}}, 'markerprofile');

$mech->get_ok('http://localhost:3010/brapi/v1/markerprofiles/1627');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'pagination' => {'totalPages' => 25,'pageSize' => 20,'totalCount' => 500,'currentPage' => 0},'datafiles' => [],'status' => [{}]},'result' => {'extractDbId' => '','data' => [{'S5_36739' => 'BB'},{'S13_92567' => 'BB'},{'S69_57277' => 'BB'},{'S80_224901' => 'AA'},{'S80_232173' => 'BB'},{'S80_265728' => 'AA'},{'S97_219243' => 'AB'},{'S224_309814' => 'BB'},{'S248_174244' => 'BB'},{'S318_245078' => 'AA'},{'S325_476494' => 'AA'},{'S341_311907' => 'BB'},{'S341_745165' => 'BB'},{'S341_927602' => 'BB'},{'S435_153155' => 'AA'},{'S620_130205' => 'BB'},{'S784_76866' => 'BB'},{'S821_289681' => 'AB'},{'S823_109683' => 'AA'}],'markerprofileDbId' => '1627','uniqueDisplayName' => 'UG120156','analysisMethod' => 'GBS ApeKI genotyping v4','germplasmDbId' => 39007}}, 'markerprofile');

$mech->post_ok('http://localhost:3010/brapi/v1/allelematrix-search', ['markerprofileDbId'=>[1626,1627], 'format'=>'json'] );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [['S10114_185859',1626,'BB'],['S10173_777651',1626,'BB'],['S10173_899514',1626,'BB'],['S10241_146006',1626,'AA'],['S1027_465354',1626,'AA'],['S10367_21679',1626,'AA'],['S1046_216535',1626,'AB'],['S10493_191533',1626,'BB'],['S10493_282956',1626,'AB'],['S10493_529025',1626,'BB'],['S10551_41284',1626,'BB'],['S10551_44996',1626,'AA'],['S10551_96591',1626,'BB'],['S10563_110710',1626,'AA'],['S10563_458792',1626,'BB'],['S10563_535346',1626,'AA'],['S10563_6640',1626,'BB'],['S10563_996687',1626,'AA'],['S10689_537521',1626,'BB']]},'metadata' => {'pagination' => {'currentPage' => 0,'totalCount' => 1000,'pageSize' => 20,'totalPages' => 50},'datafiles' => [undef],'status' => [{}]}}, 'allelematrix-search');

$mech->get_ok('http://localhost:3010/brapi/v1/programs' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'leadPerson' => '','objective' => 'test','programDbId' => 134,'abbreviation' => 'test','name' => 'test'}]},'metadata' => {'status' => [{}],'pagination' => {'currentPage' => 0,'pageSize' => 20,'totalCount' => 1,'totalPages' => 1},'datafiles' => []}}, 'programs');

$mech->get_ok('http://localhost:3010/brapi/v1/crops' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'status' => [{}],'datafiles' => [],'pagination' => {}},'result' => {'data' => ['Cassava']}}, 'crops');

$mech->get_ok('http://localhost:3010/brapi/v1/studyTypes' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'datafiles' => [],'pagination' => {'totalPages' => 1,'totalCount' => 6,'pageSize' => 20,'currentPage' => 0},'status' => [{}]},'result' => {'data' => [{'description' => 'seedling','name' => 'Seedling Nursery','studyTypeDbId' => 76464},{'studyTypeDbId' => 76514,'description' => undef,'name' => 'Advanced Yield Trial'},{'studyTypeDbId' => 76515,'description' => undef,'name' => 'Preliminary Yield Trial'},{'studyTypeDbId' => 76516,'description' => undef,'name' => 'Uniform Yield Trial'},{'description' => undef,'name' => 'Variety Release Trial','studyTypeDbId' => 77105},{'name' => 'Clonal Evaluation','description' => undef,'studyTypeDbId' => 77106}]}}, 'studyTypes');

$mech->get_ok('http://localhost:3010/brapi/v1/studyTypes?pageSize=2&page=2' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'pagination' => {'currentPage' => 2,'pageSize' => 2,'totalCount' => 6,'totalPages' => 3},'datafiles' => [],'status' => [{}]},'result' => {'data' => [{'studyTypeDbId' => 77105,'description' => undef,'name' => 'Variety Release Trial'},{'description' => undef,'name' => 'Clonal Evaluation','studyTypeDbId' => 77106}]}}, 'studyTypes');

$mech->post_ok('http://localhost:3010/brapi/v1/studies-search?pageSize=2&page=2' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'active' => '','studyDbId' => 142,'seasons' => ['2015'],'trialName' => undef,'startDate' => undef,'additionalInfo' => {'design' => undef,'description' => 'test_population2'},'programDbId' => undef,'studyType' => undef,'endDate' => undef,'locationDbId' => undef,'studyName' => 'test_population2','trialDbId' => undef,'programName' => undef,'locationName' => undef},{'trialName' => undef,'studyDbId' => 144,'seasons' => ['2016'],'active' => '','locationDbId' => '23','endDate' => undef,'studyType' => undef,'programDbId' => 134,'startDate' => undef,'additionalInfo' => {'design' => 'CRD','description' => 'test tets'},'programName' => 'test','trialDbId' => undef,'studyName' => 'test_t','locationName' => 'test_location'}]},'metadata' => {'pagination' => {'currentPage' => 2,'totalCount' => 8,'pageSize' => 2,'totalPages' => 4},'datafiles' => [],'status' => [{}]}}, 'studies-search');

$mech->post_ok('http://localhost:3010/brapi/v1/studies-search?pageSize=2&page=0&studyLocations=test_location' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'programDbId' => 134,'studyDbId' => 139,'seasons' => ['2014'],'locationDbId' => '23','studyType' => 'Clonal Evaluation','startDate' => undef,'trialDbId' => undef,'studyName' => 'Kasese solgs trial','locationName' => 'test_location','programName' => 'test','endDate' => undef,'trialName' => undef,'additionalInfo' => {'design' => 'Alpha','description' => 'This trial was loaded into the fixture to test solgs.'},'active' => ''},{'trialDbId' => undef,'programName' => 'test','studyName' => 'test_t','locationName' => 'test_location','endDate' => undef,'active' => '','trialName' => undef,'additionalInfo' => {'description' => 'test tets','design' => 'CRD'},'studyDbId' => 144,'programDbId' => 134,'seasons' => ['2016'],'locationDbId' => '23','startDate' => undef,'studyType' => undef}]},'metadata' => {'datafiles' => [],'pagination' => {'totalCount' => 4,'currentPage' => 0,'pageSize' => 2,'totalPages' => 2},'status' => [{}]}}, 'studies-search');

$mech->post_ok('http://localhost:3010/brapi/v1/studies-search?pageSize=2&page=0&studyLocations=test_location&studyType=Clonal%20Evaluation' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'trialDbId' => undef,'studyName' => 'Kasese solgs trial','programName' => 'test','endDate' => undef,'locationName' => 'test_location','trialName' => undef,'additionalInfo' => {'design' => 'Alpha','description' => 'This trial was loaded into the fixture to test solgs.'},'active' => '','programDbId' => 134,'studyDbId' => 139,'seasons' => ['2014'],'locationDbId' => '23','studyType' => 'Clonal Evaluation','startDate' => undef}]},'metadata' => {'datafiles' => [],'pagination' => {'totalCount' => 1,'pageSize' => 2,'totalPages' => 1,'currentPage' => 0},'status' => [{}]}}, 'studies-search');

$mech->post_ok('http://localhost:3010/brapi/v1/studies-search?pageSize=2&page=0&programNames=test' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'datafiles' => [],'pagination' => {'totalCount' => 5,'pageSize' => 2,'totalPages' => 3,'currentPage' => 0},'status' => [{}]},'result' => {'data' => [{'studyType' => 'Clonal Evaluation','startDate' => undef,'locationDbId' => '23','seasons' => ['2014'],'programDbId' => 134,'studyDbId' => 139,'trialName' => undef,'additionalInfo' => {'design' => 'Alpha','description' => 'This trial was loaded into the fixture to test solgs.'},'active' => '','studyName' => 'Kasese solgs trial','locationName' => 'test_location','programName' => 'test','endDate' => undef,'trialDbId' => undef},{'active' => '','trialName' => undef,'additionalInfo' => {'design' => undef,'description' => 'new_test_cross'},'endDate' => undef,'programName' => 'test','studyName' => 'new_test_cross','locationName' => undef,'trialDbId' => undef,'startDate' => undef,'studyType' => undef,'locationDbId' => undef,'seasons' => [undef],'studyDbId' => 135,'programDbId' => 134}]}}, 'studies-search');

$mech->get_ok('http://localhost:3010/brapi/v1/locations?pageSize=1&page=1' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'countryCode' => '','longitude' => undef,'altitude' => undef,'locationDbId' => 24,'countryName' => '','additionalInfo' => [{'geodetic datum' => undef}],'abbreviation' => '','latitude' => undef,'name' => 'Cornell Biotech','locationType' => ''}]},'metadata' => {'pagination' => {'totalPages' => 2,'totalCount' => 2,'pageSize' => 1,'currentPage' => 1},'datafiles' => [],'status' => [{}]}}, 'location');


done_testing();
