
use strict;
use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;

my $d = SGN::Test::WWW::WebDriver->new();

$d->while_logged_in_as("submitter", sub { 

    #Authentication

    $d->get_ok('/brapi/v1/token?grant_type=password&username=johndoe&password=secretpw');
    ok($d->driver->get_page_source()=~/Login Successfull/, "authentication call success");

    $d->get_ok('/brapi/v1/token?grant_type=wrongtype&username=johndoe&password=secretpw');
    ok($d->driver->get_page_source()=~/Grant Type Not Supported/, "authentication call bad grant type");

    $d->get_ok('/brapi/v1/token?grant_type=password&username=johndoe&password=wrong');
    ok($d->driver->get_page_source()=~/Incorrect Password/, "authentication call bad password");


    #Germplasm

    #Germplasm Search by Name

    $d->get_ok('/brapi/v1/germplasm?name=test*&matchMethod=wildcard');
    ok($d->driver->get_page_source()=~/test_accession3/, "germplasm search call");

    #Germplasm Details by germplasmId

    $d->get_ok('/brapi/v1/germplasm/38843');
    ok($d->driver->get_page_source()=~/test_accession4/, "germplasm detail call");

    #Germplasm MCPD

    #$d->get_ok('/brapi/v1/germplasm/38843/MCPD');
    #ok($d->driver->get_page_source()=~/test_accession4/, "germplasm MCPD detail call");

    #Germplasm Details List by StudyId

    $d->get_ok('/brapi/v1/studies/139/germplasm');
    ok($d->driver->get_page_source()=~/KASESE_TP2013_1016/, "study germplasm detail list call");

    #Germplasm Pedigree

    $d->get_ok('/brapi/v1/germplasm/38846/pedigree');
    ok($d->driver->get_page_source()=~/test_accession4\/test_accession5/, "germplasm pedigree call");

    #Germplasm Markerprofiles

    $d->get_ok('/brapi/v1/germplasm/38843/markerprofiles');
    ok($d->driver->get_page_source()=~/test_accession4/, "germplasm markerprofiles call");

    
    #Germplasm Attributes

    #



    #MarkerProfiles

    #Markerprofile search

    $d->get_ok('/brapi/v1/markerprofiles');
    ok($d->driver->get_page_source()=~/1622/, "markerprofile summary call");

    #Markerprofile data

    $d->get_ok('/brapi/v1/markerprofiles/1622');
    ok($d->driver->get_page_source()=~/AA/, "markerprofile detail call");





    $d->get_ok('/brapi/v1/maps');
    ok($d->driver->get_page_source()=~/linkageGroupCount/, "check map detail");
    ok($d->driver->get_page_source()=~/GBS ApeKI genotyping v4/, "check map name");

    $d->get_ok('/brapi/v1/maps/1');
    ok($d->driver->get_page_source()=~/"linkageGroupCount":268/, "check map data");

    $d->get_ok('/brapi/v1/maps/1/positions');
    ok($d->driver->get_page_source()=~/S224_309814/, "check marker in map");

});

done_testing();

