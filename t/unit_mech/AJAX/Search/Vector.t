#Tests SGN::Controller::AJAX::Search::Stock

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use SGN::Model::Cvterm;
use Data::Dumper;
use JSON;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $mech = Test::WWW::Mechanize->new(timeout=>30000);
my $response;

$mech->post_ok('http://localhost:3010/ajax/search/vectors', ['length'=>10, 'start'=>0, "extra_stockprop_columns_view" => encode_json({"organization"=>1}), "stockprop_extra_columns_view_array"=> encode_json(["organization"]) ]);
$response = decode_json $mech->content;
print STDERR "\n\n". Dumper $response;

$mech->post_ok('http://localhost:3010/ajax/search/stocks',["editable_stockprop_values" => encode_json({"SelectionMarker"=>{"matchtype"=>"contains", "value"=>"marker1"}}), "extra_stockprop_columns_view" => encode_json({"organization"=>1}), "stockprop_extra_columns_view_array"=> encode_json(["organization"]) ] );
$response = decode_json $mech->content;
print STDERR "\n\n". Dumper $response;

#Vector tests will be created here ...

$f->clean_up_db();
done_testing();
