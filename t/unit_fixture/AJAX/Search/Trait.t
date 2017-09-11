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

$mech->post_ok('http://localhost:3010/ajax/search/traits?limit=5&offset=1' );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'data' => [['<a href="/cvterm/70761/view">CO_334:0000121</a>','<a href="/cvterm/70761/view">amylopectin content ug/g in percentage</a>','Estimation of amylopectin content of cassava roots in percentage(%).'],['<a href="/cvterm/70752/view">CO_334:0000124</a>','<a href="/cvterm/70752/view">amylose amylopectin root content ratio</a>','The amylose content of a cassava root sample divided by the amylopectin content of the same sample.'],['<a href="/cvterm/70676/view">CO_334:0000075</a>','<a href="/cvterm/70676/view">amylose content in ug/g percentage</a>','Estimation of amylose content of cassava roots in percentage (%).'],['<a href="/cvterm/70717/view">CO_334:0000061</a>','<a href="/cvterm/70717/view">anther color</a>','Visual scoring of anther color with 1 = cream, 2 = yellow, and 3 = other.'],['<a href="/cvterm/70775/view">CO_334:0000103</a>','<a href="/cvterm/70775/view">anthocyanin pigmentation visual rating 0-3</a>','Visual rating of distribution of anthocyanin pigmentation with 0 = absent, 1 = top part, 2 = central part, 3 = totally pigmented.']]}, 'trait ajax search');


done_testing();
