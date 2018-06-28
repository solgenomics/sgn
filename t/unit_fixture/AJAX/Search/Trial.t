use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;

use Data::Dumper;
use JSON;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $mech = Test::WWW::Mechanize->new;
my $response;

$mech->post_ok('http://localhost:3010/ajax/search/trials?nd_geolocation=not_provided' );
$response = decode_json $mech->content;
print STDERR Dumper $response;

my $data = $response->{data};
my @removed_last_val;
foreach (@$data){
    pop @$_;
    push @removed_last_val, $_;
}

is_deeply(\@removed_last_val, [['<a href="/breeders_toolbox/trial/165">CASS_6Genotypes_Sampling_2015</a>','Copy of trial with postcomposed phenotypes from cassbase.','<a href="/breeders/program/134">test</a>','','2017','test_location','Preliminary Yield Trial','RCBD',undef,undef],['<a href="/breeders_toolbox/trial/139">Kasese solgs trial</a>','This trial was loaded into the fixture to test solgs.','<a href="/breeders/program/134">test</a>','','2014','test_location','Clonal Evaluation','Alpha',undef,undef],['<a href="/breeders_toolbox/trial/135">new_test_cross</a>','new_test_cross','<a href="/breeders/program/134">test</a>','',undef,undef,undef,undef,undef,undef],['<a href="/breeders_toolbox/trial/143">selection_population</a>','selection_population','<a href="/breeders/program/"></a>','','2015',undef,undef,undef,undef,undef],['<a href="/breeders_toolbox/trial/140">test_genotyping_project</a>','test_genotyping_project','<a href="/breeders/program/"></a>','','2015',undef,undef,undef,undef,undef],['<a href="/breeders_toolbox/trial/142">test_population2</a>','test_population2','<a href="/breeders/program/"></a>','','2015',undef,undef,undef,undef,undef],['<a href="/breeders_toolbox/trial/144">test_t</a>','test tets','<a href="/breeders/program/134">test</a>','','2016','test_location',undef,'CRD',undef,undef],['<a href="/breeders_toolbox/trial/137">test_trial</a>','test trial','<a href="/breeders/program/134">test</a>','','2014','test_location',undef,'CRD','2017-July-04','2017-July-21'],['<a href="/breeders_toolbox/trial/141">trial2 NaCRRI</a>','another trial for solGS','<a href="/breeders/program/134">test</a>','','2014','test_location',undef,'CRD',undef,undef]], 'trial ajax search');


done_testing();
