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

$mech->post_ok('http://localhost:3010/ajax/search/loci' );
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'data' => [['Cassava','<a href="/locus/2/view">test</a>','T1',''],['Cassava','<a href="/locus/3/view">test2</a>','test2','TEST2']],'recordsFiltered' => 2,'draw' => undef,'recordsTotal' => 2});


done_testing();
