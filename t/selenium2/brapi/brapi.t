
use strict;
use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;
use JSON::Any;
use Data::Dumper;

my $d = SGN::Test::WWW::WebDriver->new();
my $j = JSON::Any->new();

    #Authentication

    $d->get_ok('/brapi/v1/token?grant_type=wrongtype&username=johndoe&password=secretpw');
    ok($d->driver->get_page_source()=~/Grant Type Not Supported/, "authentication call bad grant type");

    $d->get_ok('/brapi/v1/token?grant_type=password&username=johndoe&password=wrong');
    ok($d->driver->get_page_source()=~/Incorrect Password/, "authentication call bad password");

    $d->get_ok('/brapi/v1/token?grant_type=password&username=janedoe&password=secretpw');
    my $json_response = $d->find_element_ok('body', 'tag_name', "find body")->get_text();
    my $auth = $j->jsonToObj($json_response);
    my $session_token = $auth->{session_token};


    #Germplasm

    #Germplasm Search by Name

    $d->get_ok('/brapi/v1/germplasm?name=test*&matchMethod=wildcard&session_token='.$session_token);
    $json_response = $d->find_element_ok('body', 'tag_name', "find body")->get_text();
    my $germplasm = $j->jsonToObj($json_response);
    #print STDERR Dumper $germplasm;
    is_deeply($germplasm, {
          'metadata' => {
                          'status' => [],
                          'pagination' => {
                                            'totalCount' => '10',
                                            'currentPage' => 1,
                                            'totalPages' => 1,
                                            'pageSize' => 20
                                          }
                        },
          'result' => {
                        'data' => [
                                    {
                                      'pedigree' => undef,
                                      'germplasmName' => 'test_accession1',
                                      'defaultDisplayName' => 'test_accession1',
                                      'synonyms' => [],
                                      'seedSource' => '',
                                      'germplasmDbId' => 38840,
                                      'accessionNumber' => '',
                                      'germplasmPUI' => 'test_accession1'
                                    },
                                    {
                                      'pedigree' => undef,
                                      'germplasmName' => 'test_accession2',
                                      'defaultDisplayName' => 'test_accession2',
                                      'synonyms' => [],
                                      'seedSource' => '',
                                      'germplasmDbId' => 38841,
                                      'accessionNumber' => '',
                                      'germplasmPUI' => 'test_accession2'
                                    },
                                    {
                                      'pedigree' => undef,
                                      'germplasmName' => 'test_accession3',
                                      'defaultDisplayName' => 'test_accession3',
                                      'synonyms' => [],
                                      'seedSource' => '',
                                      'germplasmDbId' => 38842,
                                      'accessionNumber' => '',
                                      'germplasmPUI' => 'test_accession3'
                                    },
                                    {
                                      'pedigree' => undef,
                                      'germplasmName' => 'test_accession4',
                                      'defaultDisplayName' => 'test_accession4',
                                      'synonyms' => [],
                                      'seedSource' => '',
                                      'germplasmDbId' => 38843,
                                      'accessionNumber' => '',
                                      'germplasmPUI' => 'test_accession4'
                                    },
                                    {
                                      'pedigree' => undef,
                                      'germplasmName' => 'test_accession5',
                                      'defaultDisplayName' => 'test_accession5',
                                      'synonyms' => [],
                                      'seedSource' => '',
                                      'germplasmDbId' => 38844,
                                      'accessionNumber' => '',
                                      'germplasmPUI' => 'test_accession5'
                                    },
                                    {
                                      'pedigree' => 'test_accession4/test_accession5',
                                      'germplasmName' => 'test5P001',
                                      'defaultDisplayName' => 'test5P001',
                                      'synonyms' => [],
                                      'seedSource' => '',
                                      'germplasmDbId' => 38873,
                                      'accessionNumber' => '',
                                      'germplasmPUI' => 'test5P001'
                                    },
                                    {
                                      'pedigree' => 'test_accession4/test_accession5',
                                      'germplasmName' => 'test5P002',
                                      'defaultDisplayName' => 'test5P002',
                                      'synonyms' => [],
                                      'seedSource' => '',
                                      'germplasmDbId' => 38874,
                                      'accessionNumber' => '',
                                      'germplasmPUI' => 'test5P002'
                                    },
                                    {
                                      'pedigree' => 'test_accession4/test_accession5',
                                      'germplasmName' => 'test5P003',
                                      'defaultDisplayName' => 'test5P003',
                                      'synonyms' => [],
                                      'seedSource' => '',
                                      'germplasmDbId' => 38875,
                                      'accessionNumber' => '',
                                      'germplasmPUI' => 'test5P003'
                                    },
                                    {
                                      'pedigree' => 'test_accession4/test_accession5',
                                      'germplasmName' => 'test5P004',
                                      'defaultDisplayName' => 'test5P004',
                                      'synonyms' => [],
                                      'seedSource' => '',
                                      'germplasmDbId' => 38876,
                                      'accessionNumber' => '',
                                      'germplasmPUI' => 'test5P004'
                                    },
                                    {
                                      'pedigree' => 'test_accession4/test_accession5',
                                      'germplasmName' => 'test5P005',
                                      'defaultDisplayName' => 'test5P005',
                                      'synonyms' => [],
                                      'seedSource' => '',
                                      'germplasmDbId' => 38877,
                                      'accessionNumber' => '',
                                      'germplasmPUI' => 'test5P005'
                                    }
                                  ]
                      }
        }, 'germplasm test');

    #Germplasm Details by germplasmId

    $d->get_ok('/brapi/v1/germplasm/38843?session_token='.$session_token);
    $json_response = $d->find_element_ok('body', 'tag_name', "find body")->get_text();
    my $germplasm_detail = $j->jsonToObj($json_response);
    #print STDERR Dumper $germplasm_detail;

    is_deeply($germplasm_detail, {
          'metadata' => {
                          'status' => [],
                          'pagination' => {
                                            'totalCount' => 1,
                                            'currentPage' => 1,
                                            'totalPages' => 1,
                                            'pageSize' => 20
                                          }
                        },
          'result' => {
                        'pedigree' => undef,
                        'germplasmName' => 'test_accession4',
                        'defaultDisplayName' => 'test_accession4',
                        'synonyms' => [],
                        'seedSource' => '',
                        'germplasmDbId' => '38843',
                        'accessionNumber' => 'test_accession4',
                        'germplasmPUI' => 'test_accession4'
                      }
        }, 'germplasm detail test'); 


    

    #Germplasm MCPD

    #$d->get_ok('/brapi/v1/germplasm/38843/MCPD');
    #ok($d->driver->get_page_source()=~/test_accession4/, "germplasm MCPD detail call");

    #Germplasm Details List by StudyId

    $d->get_ok('/brapi/v1/studies/139/germplasm?session_token='.$session_token);
    $json_response = $d->find_element_ok('body', 'tag_name', "find body")->get_text();
    my $studies_germplasm = $j->jsonToObj($json_response);
    #print STDERR Dumper $studies_germplasm;

    is_deeply($studies_germplasm, {
          'metadata' => {
                          'status' => [],
                          'pagination' => {
                                            'totalCount' => 374,
                                            'currentPage' => 1,
                                            'totalPages' => 19,
                                            'pageSize' => 20
                                          }
                        },
          'result' => {
                        'studyName' => 'Kasese solgs trial',
                        'data' => [
                                    {
                                      'pedigree' => undef,
                                      'studyEntryNumberId' => '',
                                      'germplasmName' => 'UG120001',
                                      'synonyms' => [],
                                      'defaultDisplayName' => 'UG120001',
                                      'seedSource' => '',
                                      'germplasmDbId' => 38878,
                                      'accessionNumber' => 'UG120001',
                                      'germplasmPUI' => 'UG120001'
                                    },
                                    {
                                      'pedigree' => undef,
                                      'studyEntryNumberId' => '',
                                      'germplasmName' => 'UG120002',
                                      'synonyms' => [],
                                      'defaultDisplayName' => 'UG120002',
                                      'seedSource' => '',
                                      'germplasmDbId' => 38879,
                                      'accessionNumber' => 'UG120002',
                                      'germplasmPUI' => 'UG120002'
                                    },
                                    {
                                      'pedigree' => undef,
                                      'studyEntryNumberId' => '',
                                      'germplasmName' => 'UG120003',
                                      'synonyms' => [],
                                      'defaultDisplayName' => 'UG120003',
                                      'seedSource' => '',
                                      'germplasmDbId' => 38880,
                                      'accessionNumber' => 'UG120003',
                                      'germplasmPUI' => 'UG120003'
                                    },
                                    {
                                      'pedigree' => undef,
                                      'studyEntryNumberId' => '',
                                      'germplasmName' => 'UG120004',
                                      'synonyms' => [],
                                      'defaultDisplayName' => 'UG120004',
                                      'seedSource' => '',
                                      'germplasmDbId' => 38881,
                                      'accessionNumber' => 'UG120004',
                                      'germplasmPUI' => 'UG120004'
                                    },
                                    {
                                      'pedigree' => undef,
                                      'studyEntryNumberId' => '',
                                      'germplasmName' => 'UG120005',
                                      'synonyms' => [],
                                      'defaultDisplayName' => 'UG120005',
                                      'seedSource' => '',
                                      'germplasmDbId' => 38882,
                                      'accessionNumber' => 'UG120005',
                                      'germplasmPUI' => 'UG120005'
                                    },
                                    {
                                      'pedigree' => undef,
                                      'studyEntryNumberId' => '',
                                      'germplasmName' => 'UG120006',
                                      'synonyms' => [],
                                      'defaultDisplayName' => 'UG120006',
                                      'seedSource' => '',
                                      'germplasmDbId' => 38883,
                                      'accessionNumber' => 'UG120006',
                                      'germplasmPUI' => 'UG120006'
                                    },
                                    {
                                      'pedigree' => undef,
                                      'studyEntryNumberId' => '',
                                      'germplasmName' => 'UG120007',
                                      'synonyms' => [],
                                      'defaultDisplayName' => 'UG120007',
                                      'seedSource' => '',
                                      'germplasmDbId' => 38884,
                                      'accessionNumber' => 'UG120007',
                                      'germplasmPUI' => 'UG120007'
                                    },
                                    {
                                      'pedigree' => undef,
                                      'studyEntryNumberId' => '',
                                      'germplasmName' => 'UG120008',
                                      'synonyms' => [],
                                      'defaultDisplayName' => 'UG120008',
                                      'seedSource' => '',
                                      'germplasmDbId' => 38885,
                                      'accessionNumber' => 'UG120008',
                                      'germplasmPUI' => 'UG120008'
                                    },
                                    {
                                      'pedigree' => undef,
                                      'studyEntryNumberId' => '',
                                      'germplasmName' => 'UG120009',
                                      'synonyms' => [],
                                      'defaultDisplayName' => 'UG120009',
                                      'seedSource' => '',
                                      'germplasmDbId' => 38886,
                                      'accessionNumber' => 'UG120009',
                                      'germplasmPUI' => 'UG120009'
                                    },
                                    {
                                      'pedigree' => undef,
                                      'studyEntryNumberId' => '',
                                      'germplasmName' => 'UG120010',
                                      'synonyms' => [],
                                      'defaultDisplayName' => 'UG120010',
                                      'seedSource' => '',
                                      'germplasmDbId' => 38887,
                                      'accessionNumber' => 'UG120010',
                                      'germplasmPUI' => 'UG120010'
                                    },
                                    {
                                      'pedigree' => undef,
                                      'studyEntryNumberId' => '',
                                      'germplasmName' => 'UG120011',
                                      'synonyms' => [],
                                      'defaultDisplayName' => 'UG120011',
                                      'seedSource' => '',
                                      'germplasmDbId' => 38888,
                                      'accessionNumber' => 'UG120011',
                                      'germplasmPUI' => 'UG120011'
                                    },
                                    {
                                      'pedigree' => undef,
                                      'studyEntryNumberId' => '',
                                      'germplasmName' => 'UG120012',
                                      'synonyms' => [],
                                      'defaultDisplayName' => 'UG120012',
                                      'seedSource' => '',
                                      'germplasmDbId' => 38889,
                                      'accessionNumber' => 'UG120012',
                                      'germplasmPUI' => 'UG120012'
                                    },
                                    {
                                      'pedigree' => undef,
                                      'studyEntryNumberId' => '',
                                      'germplasmName' => 'UG120013',
                                      'synonyms' => [],
                                      'defaultDisplayName' => 'UG120013',
                                      'seedSource' => '',
                                      'germplasmDbId' => 38890,
                                      'accessionNumber' => 'UG120013',
                                      'germplasmPUI' => 'UG120013'
                                    },
                                    {
                                      'pedigree' => undef,
                                      'studyEntryNumberId' => '',
                                      'germplasmName' => 'UG120014',
                                      'synonyms' => [],
                                      'defaultDisplayName' => 'UG120014',
                                      'seedSource' => '',
                                      'germplasmDbId' => 38891,
                                      'accessionNumber' => 'UG120014',
                                      'germplasmPUI' => 'UG120014'
                                    },
                                    {
                                      'pedigree' => undef,
                                      'studyEntryNumberId' => '',
                                      'germplasmName' => 'UG120015',
                                      'synonyms' => [],
                                      'defaultDisplayName' => 'UG120015',
                                      'seedSource' => '',
                                      'germplasmDbId' => 38892,
                                      'accessionNumber' => 'UG120015',
                                      'germplasmPUI' => 'UG120015'
                                    },
                                    {
                                      'pedigree' => undef,
                                      'studyEntryNumberId' => '',
                                      'germplasmName' => 'UG120016',
                                      'synonyms' => [],
                                      'defaultDisplayName' => 'UG120016',
                                      'seedSource' => '',
                                      'germplasmDbId' => 38893,
                                      'accessionNumber' => 'UG120016',
                                      'germplasmPUI' => 'UG120016'
                                    },
                                    {
                                      'pedigree' => undef,
                                      'studyEntryNumberId' => '',
                                      'germplasmName' => 'UG120017',
                                      'synonyms' => [],
                                      'defaultDisplayName' => 'UG120017',
                                      'seedSource' => '',
                                      'germplasmDbId' => 38894,
                                      'accessionNumber' => 'UG120017',
                                      'germplasmPUI' => 'UG120017'
                                    },
                                    {
                                      'pedigree' => undef,
                                      'studyEntryNumberId' => '',
                                      'germplasmName' => 'UG120018',
                                      'synonyms' => [],
                                      'defaultDisplayName' => 'UG120018',
                                      'seedSource' => '',
                                      'germplasmDbId' => 38895,
                                      'accessionNumber' => 'UG120018',
                                      'germplasmPUI' => 'UG120018'
                                    },
                                    {
                                      'pedigree' => undef,
                                      'studyEntryNumberId' => '',
                                      'germplasmName' => 'UG120019',
                                      'synonyms' => [],
                                      'defaultDisplayName' => 'UG120019',
                                      'seedSource' => '',
                                      'germplasmDbId' => 38896,
                                      'accessionNumber' => 'UG120019',
                                      'germplasmPUI' => 'UG120019'
                                    },
                                    {
                                      'pedigree' => undef,
                                      'studyEntryNumberId' => '',
                                      'germplasmName' => 'UG120020',
                                      'synonyms' => [],
                                      'defaultDisplayName' => 'UG120020',
                                      'seedSource' => '',
                                      'germplasmDbId' => 38897,
                                      'accessionNumber' => 'UG120020',
                                      'germplasmPUI' => 'UG120020'
                                    }
                                  ],
                        'studyDbId' => '139'
                      }
        }, 'study germplasm test');

    #Germplasm Pedigree

    $d->get_ok('/brapi/v1/germplasm/38846/pedigree?session_token='.$session_token);
    $json_response = $d->find_element_ok('body', 'tag_name', "find body")->get_text();
    my $germplasm_pedigree = $j->jsonToObj($json_response);
    #print STDERR Dumper $germplasm_pedigree;

    is_deeply($germplasm_pedigree, {
          'metadata' => {
                          'status' => [],
                          'pagination' => {
                                            'totalCount' => 1,
                                            'currentPage' => 1,
                                            'totalPages' => 1,
                                            'pageSize' => 20
                                          }
                        },
          'result' => {
                        'pedigree' => 'test_accession4/test_accession5',
                        'parent2Id' => 38844,
                        'germplasmDbId' => '38846',
                        'parent1Id' => 38843
                      }
        }, 'germplasm pedigree test');

    #Germplasm Markerprofiles

    #$d->get_ok('/brapi/v1/germplasm/39024/markerprofiles?session_token='.$session_token);
    #my $json_response = $d->find_element_ok('body', 'tag_name', "find body")->get_text();
    #my $germplasm_markerprofiles = $j->jsonToObj($json_response);
    #print STDERR Dumper $germplasm_markerprofiles;

    
    #Germplasm Attributes

    #



    #MarkerProfiles

    #Markerprofile search

    $d->get_ok('/brapi/v1/markerprofiles?session_token='.$session_token);
    $json_response = $d->find_element_ok('body', 'tag_name', "find body")->get_text();
    my $markerprofiles = $j->jsonToObj($json_response);
    #print STDERR Dumper $markerprofiles;

    is_deeply($markerprofiles, {
          'metadata' => {
                          'status' => [],
                          'pagination' => {
                                            'totalCount' => 535,
                                            'currentPage' => 1,
                                            'totalPages' => 27,
                                            'pageSize' => 20
                                          }
                        },
          'result' => {
                        'data' => [
                                    {
                                      'resultCount' => 500,
                                      'markerProfileDbId' => 1622,
                                      'germplasmDbId' => 38937,
                                      'extractDbId' => '',
                                      'analysisMethod' => 'GBS ApeKI genotyping v4'
                                    },
                                    {
                                      'resultCount' => 500,
                                      'markerProfileDbId' => 1623,
                                      'germplasmDbId' => 38994,
                                      'extractDbId' => '',
                                      'analysisMethod' => 'GBS ApeKI genotyping v4'
                                    },
                                    {
                                      'resultCount' => 500,
                                      'markerProfileDbId' => 1624,
                                      'germplasmDbId' => 39006,
                                      'extractDbId' => '',
                                      'analysisMethod' => 'GBS ApeKI genotyping v4'
                                    },
                                    {
                                      'resultCount' => 500,
                                      'markerProfileDbId' => 1625,
                                      'germplasmDbId' => 39045,
                                      'extractDbId' => '',
                                      'analysisMethod' => 'GBS ApeKI genotyping v4'
                                    },
                                    {
                                      'resultCount' => 500,
                                      'markerProfileDbId' => 1626,
                                      'germplasmDbId' => 38881,
                                      'extractDbId' => '',
                                      'analysisMethod' => 'GBS ApeKI genotyping v4'
                                    },
                                    {
                                      'resultCount' => 500,
                                      'markerProfileDbId' => 1627,
                                      'germplasmDbId' => 39007,
                                      'extractDbId' => '',
                                      'analysisMethod' => 'GBS ApeKI genotyping v4'
                                    },
                                    {
                                      'resultCount' => 500,
                                      'markerProfileDbId' => 1628,
                                      'germplasmDbId' => 39027,
                                      'extractDbId' => '',
                                      'analysisMethod' => 'GBS ApeKI genotyping v4'
                                    },
                                    {
                                      'resultCount' => 500,
                                      'markerProfileDbId' => 1629,
                                      'germplasmDbId' => 39028,
                                      'extractDbId' => '',
                                      'analysisMethod' => 'GBS ApeKI genotyping v4'
                                    },
                                    {
                                      'resultCount' => 500,
                                      'markerProfileDbId' => 1630,
                                      'germplasmDbId' => 39033,
                                      'extractDbId' => '',
                                      'analysisMethod' => 'GBS ApeKI genotyping v4'
                                    },
                                    {
                                      'resultCount' => 500,
                                      'markerProfileDbId' => 1631,
                                      'germplasmDbId' => 38917,
                                      'extractDbId' => '',
                                      'analysisMethod' => 'GBS ApeKI genotyping v4'
                                    },
                                    {
                                      'resultCount' => 500,
                                      'markerProfileDbId' => 1632,
                                      'germplasmDbId' => 39044,
                                      'extractDbId' => '',
                                      'analysisMethod' => 'GBS ApeKI genotyping v4'
                                    },
                                    {
                                      'resultCount' => 500,
                                      'markerProfileDbId' => 1633,
                                      'germplasmDbId' => 39050,
                                      'extractDbId' => '',
                                      'analysisMethod' => 'GBS ApeKI genotyping v4'
                                    },
                                    {
                                      'resultCount' => 500,
                                      'markerProfileDbId' => 1634,
                                      'germplasmDbId' => 39070,
                                      'extractDbId' => '',
                                      'analysisMethod' => 'GBS ApeKI genotyping v4'
                                    },
                                    {
                                      'resultCount' => 500,
                                      'markerProfileDbId' => 1635,
                                      'germplasmDbId' => 38884,
                                      'extractDbId' => '',
                                      'analysisMethod' => 'GBS ApeKI genotyping v4'
                                    },
                                    {
                                      'resultCount' => 500,
                                      'markerProfileDbId' => 1636,
                                      'germplasmDbId' => 38981,
                                      'extractDbId' => '',
                                      'analysisMethod' => 'GBS ApeKI genotyping v4'
                                    },
                                    {
                                      'resultCount' => 500,
                                      'markerProfileDbId' => 1637,
                                      'germplasmDbId' => 38998,
                                      'extractDbId' => '',
                                      'analysisMethod' => 'GBS ApeKI genotyping v4'
                                    },
                                    {
                                      'resultCount' => 500,
                                      'markerProfileDbId' => 1638,
                                      'germplasmDbId' => 39078,
                                      'extractDbId' => '',
                                      'analysisMethod' => 'GBS ApeKI genotyping v4'
                                    },
                                    {
                                      'resultCount' => 500,
                                      'markerProfileDbId' => 1639,
                                      'germplasmDbId' => 39052,
                                      'extractDbId' => '',
                                      'analysisMethod' => 'GBS ApeKI genotyping v4'
                                    },
                                    {
                                      'resultCount' => 500,
                                      'markerProfileDbId' => 1640,
                                      'germplasmDbId' => 38946,
                                      'extractDbId' => '',
                                      'analysisMethod' => 'GBS ApeKI genotyping v4'
                                    },
                                    {
                                      'resultCount' => 500,
                                      'markerProfileDbId' => 1641,
                                      'germplasmDbId' => 39024,
                                      'extractDbId' => '',
                                      'analysisMethod' => 'GBS ApeKI genotyping v4'
                                    }
                                  ]
                      }
        }, 'markerprofiles test');

    #Markerprofile data

    $d->get_ok('/brapi/v1/markerprofiles/1622?session_token='.$session_token);
    $json_response = $d->find_element_ok('body', 'tag_name', "find body")->get_text();
    my $markerprofiles_detail = $j->jsonToObj($json_response);
    #print STDERR Dumper $markerprofiles_detail;

    is_deeply($markerprofiles_detail, {
          'metadata' => {
                          'status' => [],
                          'pagination' => {
                                            'totalCount' => 500,
                                            'currentPage' => 1,
                                            'totalPages' => 25,
                                            'pageSize' => 20
                                          }
                        },
          'result' => {
                        'markerprofileDbId' => '1622',
                        'data' => [
                                    {
                                      'S5_36739' => 'AA'
                                    },
                                    {
                                      'S13_92567' => 'BB'
                                    },
                                    {
                                      'S69_57277' => 'AB'
                                    },
                                    {
                                      'S80_224901' => 'AA'
                                    },
                                    {
                                      'S80_232173' => 'BB'
                                    },
                                    {
                                      'S80_265728' => 'AA'
                                    },
                                    {
                                      'S97_219243' => 'AB'
                                    },
                                    {
                                      'S224_309814' => 'BB'
                                    },
                                    {
                                      'S248_174244' => 'BB'
                                    },
                                    {
                                      'S318_245078' => 'AA'
                                    },
                                    {
                                      'S325_476494' => 'AB'
                                    },
                                    {
                                      'S341_311907' => 'BB'
                                    },
                                    {
                                      'S341_745165' => 'BB'
                                    },
                                    {
                                      'S341_927602' => 'BB'
                                    },
                                    {
                                      'S435_153155' => 'BB'
                                    },
                                    {
                                      'S620_130205' => 'BB'
                                    },
                                    {
                                      'S784_76866' => 'BB'
                                    },
                                    {
                                      'S821_289681' => 'AA'
                                    },
                                    {
                                      'S823_109683' => 'AA'
                                    },
                                    {
                                      'S823_119622' => 'BB'
                                    }
                                  ],
                        'germplasmDbId' => 38937,
                        'extractDbId' => '',
                        'analysisMethod' => 'GBS ApeKI genotyping v4',
                        'encoding' => 'AA,BB,AB'
                      }
        }, 'markerprofiles detail test');



    $d->get_ok('/brapi/v1/maps?session_token='.$session_token);
    $json_response = $d->find_element_ok('body', 'tag_name', "find body")->get_text();
    my $maps = $j->jsonToObj($json_response);
    #print STDERR Dumper $maps;

    is_deeply($maps, {
          'metadata' => {
                          'status' => [],
                          'pagination' => {
                                            'totalCount' => 1,
                                            'currentPage' => 1,
                                            'totalPages' => 1,
                                            'pageSize' => 20
                                          }
                        },
          'result' => {
                        'data' => [
                                    {
                                      'name' => 'GBS ApeKI genotyping v4',
                                      'publishedDate' => undef,
                                      'species' => 'Cassava SNP genotypes for stock 520 20 24 25 29 30 44 46 108 109 112 114 520name = UG120066, id = 38937)',
                                      'mapId' => 1,
                                      'comments' => '',
                                      'markerCount' => 500,
                                      'unit' => 'bp',
                                      'linkageGroupCount' => 268,
                                      'type' => 'physical'
                                    }
                                  ]
                      }
        }, 'maps data test');

    $d->get_ok('/brapi/v1/maps/1?session_token='.$session_token);
    $json_response = $d->find_element_ok('body', 'tag_name', "find body")->get_text();
    my $maps_detail = $j->jsonToObj($json_response);
    #print STDERR Dumper $maps_detail;

    is_deeply($maps_detail, {
          'metadata' => {
                          'status' => [],
                          'pagination' => {
                                            'totalCount' => 268,
                                            'currentPage' => 1,
                                            'totalPages' => 14,
                                            'pageSize' => 20
                                          }
                        },
          'result' => {
                        'unit' => 'bp',
                        'name' => 'GBS ApeKI genotyping v4',
                        'linkageGroups' => [
                                             {
                                               'numberMarkers' => 1,
                                               'maxPosition' => '185859',
                                               'linkageGroupId' => 'S10114'
                                             },
                                             {
                                               'numberMarkers' => 2,
                                               'maxPosition' => '899514',
                                               'linkageGroupId' => 'S10173'
                                             },
                                             {
                                               'numberMarkers' => 1,
                                               'maxPosition' => '146006',
                                               'linkageGroupId' => 'S10241'
                                             },
                                             {
                                               'numberMarkers' => 1,
                                               'maxPosition' => '465354',
                                               'linkageGroupId' => 'S1027'
                                             },
                                             {
                                               'numberMarkers' => 1,
                                               'maxPosition' => '21679',
                                               'linkageGroupId' => 'S10367'
                                             },
                                             {
                                               'numberMarkers' => 1,
                                               'maxPosition' => '216535',
                                               'linkageGroupId' => 'S1046'
                                             },
                                             {
                                               'numberMarkers' => 3,
                                               'maxPosition' => '529025',
                                               'linkageGroupId' => 'S10493'
                                             },
                                             {
                                               'numberMarkers' => 3,
                                               'maxPosition' => '96591',
                                               'linkageGroupId' => 'S10551'
                                             },
                                             {
                                               'numberMarkers' => 5,
                                               'maxPosition' => '996687',
                                               'linkageGroupId' => 'S10563'
                                             },
                                             {
                                               'numberMarkers' => 2,
                                               'maxPosition' => '585587',
                                               'linkageGroupId' => 'S10689'
                                             },
                                             {
                                               'numberMarkers' => 1,
                                               'maxPosition' => '25444',
                                               'linkageGroupId' => 'S10780'
                                             },
                                             {
                                               'numberMarkers' => 2,
                                               'maxPosition' => '244349',
                                               'linkageGroupId' => 'S10797'
                                             },
                                             {
                                               'numberMarkers' => 1,
                                               'maxPosition' => '781226',
                                               'linkageGroupId' => 'S10963'
                                             },
                                             {
                                               'numberMarkers' => 1,
                                               'maxPosition' => '78443',
                                               'linkageGroupId' => 'S11106'
                                             },
                                             {
                                               'numberMarkers' => 2,
                                               'maxPosition' => '231468',
                                               'linkageGroupId' => 'S11179'
                                             },
                                             {
                                               'numberMarkers' => 1,
                                               'maxPosition' => '108022',
                                               'linkageGroupId' => 'S11267'
                                             },
                                             {
                                               'numberMarkers' => 1,
                                               'maxPosition' => '16826',
                                               'linkageGroupId' => 'S1127'
                                             },
                                             {
                                               'numberMarkers' => 1,
                                               'maxPosition' => '135336',
                                               'linkageGroupId' => 'S11279'
                                             },
                                             {
                                               'numberMarkers' => 4,
                                               'maxPosition' => '591849',
                                               'linkageGroupId' => 'S11297'
                                             },
                                             {
                                               'numberMarkers' => 2,
                                               'maxPosition' => '582872',
                                               'linkageGroupId' => 'S11341'
                                             }
                                           ],
                        'type' => 'physical',
                        'mapId' => 1
                      }
        }, 'map details test');

    $d->get_ok('/brapi/v1/maps/1/positions?session_token='.$session_token);
    $json_response = $d->find_element_ok('body', 'tag_name', "find body")->get_text();
    my $maps_position = $j->jsonToObj($json_response);
    #print STDERR Dumper $maps_position;

    is_deeply($maps_position, {
          'metadata' => {
                          'status' => [],
                          'pagination' => {
                                            'totalCount' => 500,
                                            'currentPage' => 1,
                                            'totalPages' => 25,
                                            'pageSize' => 20
                                          }
                        },
          'result' => {
                        'data' => [
                                    {
                                      'markerName' => 'S5_36739',
                                      'linkageGroup' => 'S5',
                                      'markerId' => 'S5_36739',
                                      'location' => '36739'
                                    },
                                    {
                                      'markerName' => 'S13_92567',
                                      'linkageGroup' => 'S13',
                                      'markerId' => 'S13_92567',
                                      'location' => '92567'
                                    },
                                    {
                                      'markerName' => 'S69_57277',
                                      'linkageGroup' => 'S69',
                                      'markerId' => 'S69_57277',
                                      'location' => '57277'
                                    },
                                    {
                                      'markerName' => 'S80_224901',
                                      'linkageGroup' => 'S80',
                                      'markerId' => 'S80_224901',
                                      'location' => '224901'
                                    },
                                    {
                                      'markerName' => 'S80_232173',
                                      'linkageGroup' => 'S80',
                                      'markerId' => 'S80_232173',
                                      'location' => '232173'
                                    },
                                    {
                                      'markerName' => 'S80_265728',
                                      'linkageGroup' => 'S80',
                                      'markerId' => 'S80_265728',
                                      'location' => '265728'
                                    },
                                    {
                                      'markerName' => 'S97_219243',
                                      'linkageGroup' => 'S97',
                                      'markerId' => 'S97_219243',
                                      'location' => '219243'
                                    },
                                    {
                                      'markerName' => 'S224_309814',
                                      'linkageGroup' => 'S224',
                                      'markerId' => 'S224_309814',
                                      'location' => '309814'
                                    },
                                    {
                                      'markerName' => 'S248_174244',
                                      'linkageGroup' => 'S248',
                                      'markerId' => 'S248_174244',
                                      'location' => '174244'
                                    },
                                    {
                                      'markerName' => 'S318_245078',
                                      'linkageGroup' => 'S318',
                                      'markerId' => 'S318_245078',
                                      'location' => '245078'
                                    },
                                    {
                                      'markerName' => 'S325_476494',
                                      'linkageGroup' => 'S325',
                                      'markerId' => 'S325_476494',
                                      'location' => '476494'
                                    },
                                    {
                                      'markerName' => 'S341_311907',
                                      'linkageGroup' => 'S341',
                                      'markerId' => 'S341_311907',
                                      'location' => '311907'
                                    },
                                    {
                                      'markerName' => 'S341_745165',
                                      'linkageGroup' => 'S341',
                                      'markerId' => 'S341_745165',
                                      'location' => '745165'
                                    },
                                    {
                                      'markerName' => 'S341_927602',
                                      'linkageGroup' => 'S341',
                                      'markerId' => 'S341_927602',
                                      'location' => '927602'
                                    },
                                    {
                                      'markerName' => 'S435_153155',
                                      'linkageGroup' => 'S435',
                                      'markerId' => 'S435_153155',
                                      'location' => '153155'
                                    },
                                    {
                                      'markerName' => 'S620_130205',
                                      'linkageGroup' => 'S620',
                                      'markerId' => 'S620_130205',
                                      'location' => '130205'
                                    },
                                    {
                                      'markerName' => 'S784_76866',
                                      'linkageGroup' => 'S784',
                                      'markerId' => 'S784_76866',
                                      'location' => '76866'
                                    },
                                    {
                                      'markerName' => 'S821_289681',
                                      'linkageGroup' => 'S821',
                                      'markerId' => 'S821_289681',
                                      'location' => '289681'
                                    },
                                    {
                                      'markerName' => 'S823_109683',
                                      'linkageGroup' => 'S823',
                                      'markerId' => 'S823_109683',
                                      'location' => '109683'
                                    },
                                    {
                                      'markerName' => 'S823_119622',
                                      'linkageGroup' => 'S823',
                                      'markerId' => 'S823_119622',
                                      'location' => '119622'
                                    }
                                  ]
                      }
        }, 'maps positions test');


done_testing();

