
use strict;
use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;

my $d = SGN::Test::WWW::WebDriver->new();

$d->get_ok('/brapi/v1/germplasm/38843');
ok($d->driver->get_page_source()=~/test_accession4/, "germplasm detail call");

$d->get_ok('/brapi/v1/germplasm');
ok($d->driver->get_page_source()=~/test_accession3/, "germplasm summary call");

$d->get_ok('/brapi/v1/markerprofiles');
ok($d->driver->get_page_source()=~/1622/, "markerprofile summary call");

$d->get_ok('/brapi/v1/markerprofiles/1622');
ok($d->driver->get_page_source()=~/AA/, "markerprofile detail call");

$d->get_ok('/brapi/v1/maps');
ok($d->driver->get_page_source()=~/linkageGroupCount/, "check map detail");
ok($d->driver->get_page_source()=~/GBS ApeKI genotyping v4/, "check map name");

$d->get_ok('/brapi/v1/maps/1');
ok($d->driver->get_page_source()=~/"linkageGroupCount":268/, "check map data");

$d->get_ok('/brapi/v1/maps/1/positions');
ok($d->driver->get_page_source()=~/S224_309814/, "check marker in map");

done_testing();

