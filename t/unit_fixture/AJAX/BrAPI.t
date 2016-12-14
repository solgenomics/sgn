
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

$mech->get_ok('http://localhost:3010/brapi/v1/markerprofiles?pageSize=2&currentPage=3');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'datafiles' => [],'status' => {'message' => ''},'pagination' => {'totalCount' => 535,'pageSize' => 2,'totalPages' => 268,'currentPage' => 3}},'result' => {'data' => [{'resultCount' => 500,'uniqueDisplayName' => 'UG120004','markerProfileDbId' => 1626,'analysisMethod' => 'GBS ApeKI genotyping v4','sampleDbId' => '','extractDbId' => '','germplasmDbId' => 38881},{'markerProfileDbId' => 1627,'analysisMethod' => 'GBS ApeKI genotyping v4','sampleDbId' => '','extractDbId' => '','germplasmDbId' => 39007,'uniqueDisplayName' => 'UG120156','resultCount' => 500}]}}, 'markerprofile');

$mech->get_ok('http://localhost:3010/brapi/v1/markerprofiles?pageSize=1&currentPage=1&germplasmDbId=38937');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'markerProfileDbId' => 1622,'resultCount' => 500,'analysisMethod' => 'GBS ApeKI genotyping v4','uniqueDisplayName' => 'UG120066','sampleDbId' => '','germplasmDbId' => 38937,'extractDbId' => ''}]},'metadata' => {'datafiles' => [],'status' => {'message' => ''},'pagination' => {'currentPage' => 1,'totalCount' => 2,'totalPages' => 2,'pageSize' => 1}}}, 'markerprofile');

$mech->get_ok('http://localhost:3010/brapi/v1/markerprofiles?pageSize=2&currentPage=3&methodDbId=1');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'resultCount' => 500,'uniqueDisplayName' => 'UG120004','germplasmDbId' => 38881,'extractDbId' => '','analysisMethod' => 'GBS ApeKI genotyping v4','sampleDbId' => '','markerProfileDbId' => 1626},{'markerProfileDbId' => 1627,'analysisMethod' => 'GBS ApeKI genotyping v4','sampleDbId' => '','extractDbId' => '','germplasmDbId' => 39007,'resultCount' => 500,'uniqueDisplayName' => 'UG120156'}]},'metadata' => {'datafiles' => [],'status' => {'message' => ''},'pagination' => {'totalPages' => 268,'currentPage' => 3,'totalCount' => 535,'pageSize' => 2}}}, 'markerprofile');

$mech->get_ok('http://localhost:3010/brapi/v1/markerprofiles/1627');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'uniqueDisplayName' => 'UG120156','data' => [{'S5_36739' => 'BB'},{'S13_92567' => 'BB'},{'S69_57277' => 'BB'},{'S80_224901' => 'AA'},{'S80_232173' => 'BB'},{'S80_265728' => 'AA'},{'S97_219243' => 'AB'},{'S224_309814' => 'BB'},{'S248_174244' => 'BB'},{'S318_245078' => 'AA'},{'S325_476494' => 'AA'},{'S341_311907' => 'BB'},{'S341_745165' => 'BB'},{'S341_927602' => 'BB'},{'S435_153155' => 'AA'},{'S620_130205' => 'BB'},{'S784_76866' => 'BB'},{'S821_289681' => 'AB'},{'S823_109683' => 'AA'},{'S823_119622' => 'BB'}],'analysisMethod' => 'GBS ApeKI genotyping v4','markerprofileDbId' => '1627','extractDbId' => '','germplasmDbId' => 39007},'metadata' => {'datafiles' => [],'status' => {},'pagination' => {'totalCount' => 500,'currentPage' => 1,'pageSize' => 20,'totalPages' => 25}}}, 'markerprofile');

$mech->post_ok('http://localhost:3010/brapi/v1/allelematrix-search', ['markerprofileDbId'=>[1626,1627], 'format'=>'json'] );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'status' => {},'datafiles' => [undef],'pagination' => {'pageSize' => 20,'totalCount' => 1000,'totalPages' => 50,'currentPage' => 1}},'result' => {'data' => [['S10114_185859',1626,'BB'],['S10173_777651',1626,'BB'],['S10173_899514',1626,'BB'],['S10241_146006',1626,'AA'],['S1027_465354',1626,'AA'],['S10367_21679',1626,'AA'],['S1046_216535',1626,'AB'],['S10493_191533',1626,'BB'],['S10493_282956',1626,'AB'],['S10493_529025',1626,'BB'],['S10551_41284',1626,'BB'],['S10551_44996',1626,'AA'],['S10551_96591',1626,'BB'],['S10563_110710',1626,'AA'],['S10563_458792',1626,'BB'],['S10563_535346',1626,'AA'],['S10563_6640',1626,'BB'],['S10563_996687',1626,'AA'],['S10689_537521',1626,'BB'],['S10689_585587',1626,'BB']]}}, 'allelematrix-search');

$mech->get_ok('http://localhost:3010/brapi/v1/programs' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'pagination' => {'totalCount' => 1,'pageSize' => 20,'currentPage' => 1,'totalPages' => 1},'datafiles' => [],'status' => {}},'result' => {'data' => [{'programDbId' => 134,'name' => 'test','abbreviation' => 'test','objective' => 'test','leadPerson' => ''}]}}, 'programs');

$mech->get_ok('http://localhost:3010/brapi/v1/crops' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'pagination' => {},'status' => {},'datafiles' => []},'result' => {'data' => ['Cassava']}}, 'crops');

$mech->get_ok('http://localhost:3010/brapi/v1/studyTypes' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'description' => 'seedling','studyTypeDbId' => 76464,'name' => 'Seedling Nursery'},{'description' => undef,'studyTypeDbId' => 76514,'name' => 'Advanced Yield Trial'},{'name' => 'Preliminary Yield Trial','description' => undef,'studyTypeDbId' => 76515},{'description' => undef,'studyTypeDbId' => 76516,'name' => 'Uniform Yield Trial'},{'name' => 'Variety Release Trial','description' => undef,'studyTypeDbId' => 77105},{'name' => 'Clonal Evaluation','studyTypeDbId' => 77106,'description' => undef}]},'metadata' => {'status' => {},'pagination' => {'totalPages' => 1,'totalCount' => 6,'pageSize' => 20,'currentPage' => 1},'datafiles' => []}}, 'studyTypes');

$mech->get_ok('http://localhost:3010/brapi/v1/studyTypes?pageSize=2&currentPage=2' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'pagination' => {'totalPages' => 3,'pageSize' => 2,'totalCount' => 6,'currentPage' => 2},'status' => {},'datafiles' => []},'result' => {'data' => [{'name' => 'Preliminary Yield Trial','description' => undef,'studyTypeDbId' => 76515},{'description' => undef,'studyTypeDbId' => 76516,'name' => 'Uniform Yield Trial'}]}}, 'studyTypes');

$mech->post_ok('http://localhost:3010/brapi/v1/studies-search?pageSize=2&currentPage=2' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'metadata' => {'status' => {},'datafiles' => [],'pagination' => {'totalCount' => 6,'totalPages' => 3,'pageSize' => 2,'currentPage' => 2}},'result' => {'data' => [{'startDate' => '','seasons' => ['2014'],'studyType' => 'Clonal Evaluation','locationDbId' => '23','programName' => 'test','locationName' => 'test_location','trialDbId' => 134,'programDbId' => 134,'endDate' => '','additionalInfo' => {'studyPUI' => ''},'trialName' => 'test','studyDbId' => 139,'name' => 'Kasese solgs trial'}]}}, 'studies-search');

$mech->get_ok('http://localhost:3010/brapi/v1/locations?pageSize=1&currentPage=1' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'result' => {'data' => [{'altitude' => undef,'countryCode' => '','abbreviation' => '','latitude' => undef,'locationType' => '','longitude' => undef,'locationDbId' => 23,'additionalInfo' => [{'geodetic datum' => undef}],'countryName' => '','name' => 'test_location'}]},'metadata' => {'status' => {},'datafiles' => [],'pagination' => {'pageSize' => 1,'totalPages' => 2,'currentPage' => 1,'totalCount' => 2}}}, 'location');


done_testing();
