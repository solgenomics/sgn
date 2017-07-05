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

$mech->post_ok('http://localhost:3010/ajax/search/traits' );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'data' => [['<a href="/cvterm/70700/view">CO:0000008</a>','sprouting proportion','Proportion of stakes germinated scored one month after planting.'],['<a href="/cvterm/70765/view">CO:0000009</a>','initial vigor assessment 1-7','Visual assessment of plant vigor during establishment scored one month after planting.'],['<a href="/cvterm/70765/view">CO:0000010</a>','plant stands harvested counting','A count of the number of plant stands at harvest.'] ]}, 'trait ajax search');


done_testing();
