
#Tests SGN::Controller::AJAX::Search::Stock

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use SGN::Model::Cvterm;
use JSON;
use Data::Dumper;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $mech = Test::WWW::Mechanize->new(timeout=>30000);
my $response;

$mech->post_ok('http://localhost:3010/ajax/search/stocks', ['length'=>10, 'start'=>0, "extra_stockprop_columns_view" => encode_json({"organization"=>1}), "stockprop_extra_columns_view_array"=> encode_json(["organization"]) ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'recordsTotal' => 2940,'data' => [['<a href="/stock/40326/view">BLANK</a>','accession',undef,'',''],['<a href="/stock/41284/view">CASS_6Genotypes_103</a>','plot','Manihot esculenta','',''],['<a href="/stock/41295/view">CASS_6Genotypes_104</a>','plot','Manihot esculenta','',''],['<a href="/stock/41296/view">CASS_6Genotypes_105</a>','plot','Manihot esculenta','',''],['<a href="/stock/41297/view">CASS_6Genotypes_106</a>','plot','Manihot esculenta','',''],['<a href="/stock/41298/view">CASS_6Genotypes_107</a>','plot','Manihot esculenta','',''],['<a href="/stock/41299/view">CASS_6Genotypes_201</a>','plot',undef,'',''],['<a href="/stock/41300/view">CASS_6Genotypes_202</a>','plot','Manihot esculenta','',''],['<a href="/stock/41301/view">CASS_6Genotypes_203</a>','plot','Manihot esculenta','',''],['<a href="/breeders/seedlot/41770">BLANK_001</a>','seedlot',undef,'','']],'draw' => undef,'recordsFiltered' => 2940}, 'test stock search 1');

my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
my $plot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();
my $population_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'population', 'stock_type')->cvterm_id();

$mech->post_ok('http://localhost:3010/ajax/search/stocks',['length'=>10, 'start'=>0, "any_name_matchtype" => "contains","any_name" => "test", "stock_type"=>'accession', "extra_stockprop_columns_view" => encode_json({"organization"=>1}), "stockprop_extra_columns_view_array"=> encode_json(["organization"]) ] );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'recordsTotal' => 25,'draw' => undef,'data' => [['<a href="/stock/38846/view">new_test_crossP001</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38847/view">new_test_crossP002</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38848/view">new_test_crossP003</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38849/view">new_test_crossP004</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38850/view">new_test_crossP005</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38851/view">new_test_crossP006</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38852/view">new_test_crossP007</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38853/view">new_test_crossP008</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38854/view">new_test_crossP009</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38855/view">new_test_crossP010</a>','accession','Solanum lycopersicum','','']],'recordsFiltered' => 25}, 'test stock search 2');
$mech->post_ok('http://localhost:3010/ajax/search/stocks',['length'=>10, 'start'=>0, "any_name_matchtype" => "contains","any_name" => "test", "stock_type"=>"plot", "extra_stockprop_columns_view" => encode_json({"organization"=>1}), "stockprop_extra_columns_view_array"=> encode_json(["organization"]) ] );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'data' => [['<a href="/stock/40327/view">test_t1</a>','plot','Solanum lycopersicum','',''],['<a href="/stock/40328/view">test_t10</a>','plot','Manihot esculenta','',''],['<a href="/stock/40329/view">test_t100</a>','plot','Solanum lycopersicum','',''],['<a href="/stock/40330/view">test_t101</a>','plot','Solanum lycopersicum','',''],['<a href="/stock/40331/view">test_t102</a>','plot','Solanum lycopersicum','',''],['<a href="/stock/40332/view">test_t103</a>','plot','Solanum lycopersicum','',''],['<a href="/stock/40333/view">test_t104</a>','plot','Solanum lycopersicum','',''],['<a href="/stock/40334/view">test_t105</a>','plot','Manihot esculenta','',''],['<a href="/stock/40335/view">test_t106</a>','plot','Solanum lycopersicum','',''],['<a href="/stock/40336/view">test_t107</a>','plot','Solanum lycopersicum','','']],'draw' => undef,'recordsFiltered' => 937,'recordsTotal' => 937}, 'test stock search 3');

$mech->post_ok('http://localhost:3010/ajax/search/stocks',['length'=>10, 'start'=>0, "any_name_matchtype" => "contains","any_name" => "test", "stock_type"=>"cross", "extra_stockprop_columns_view" => encode_json({"organization"=>1}), "stockprop_extra_columns_view_array"=> encode_json(["organization"]) ] );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'draw' => undef,'recordsFiltered' => 21,'data' => [['<a href="/cross/38845">new_test_cross</a>','cross','Solanum lycopersicum','',''],['<a href="/cross/41248">cross_test1</a>','cross','Solanum lycopersicum','',''],['<a href="/cross/41249">cross_test4</a>','cross','Solanum lycopersicum','',''],['<a href="/cross/41250">cross_test5</a>','cross','Solanum lycopersicum','',''],['<a href="/cross/41251">cross_test6</a>','cross','Solanum lycopersicum','',''],['<a href="/cross/41252">cross_test2</a>','cross','Solanum lycopersicum','',''],['<a href="/cross/41253">cross_test3</a>','cross','Solanum lycopersicum','',''],['<a href="/cross/41264">TestCross1</a>','cross','Manihot esculenta','',''],['<a href="/cross/41273">TestCross10</a>','cross','Manihot esculenta','',''],['<a href="/cross/41274">TestCross11</a>','cross','Manihot esculenta','','']],'recordsTotal' => 21}, 'test stock search 4');

$mech->post_ok('http://localhost:3010/ajax/search/stocks',['length'=>10, 'start'=>0, "any_name_matchtype" => "contains","any_name" => "test", "stock_type"=>"population", "extra_stockprop_columns_view" => encode_json({"organization"=>1}), "stockprop_extra_columns_view_array"=> encode_json(["organization"]) ] );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'recordsFiltered' => 5,'recordsTotal' => 5,'data' => [['<a href="/stock/41259/view">TestPopulation1</a>','population','Manihot esculenta','',''],['<a href="/stock/41260/view">TestPopulation2</a>','population','Manihot esculenta','',''],['<a href="/stock/41261/view">TestPopulation3</a>','population','Manihot esculenta','',''],['<a href="/stock/41262/view">TestPopulation4</a>','population','Manihot esculenta','',''],['<a href="/stock/41263/view">TestPopulation5</a>','population','Manihot esculenta','','']],'draw' => undef}, 'test stock search 5');

$mech->post_ok('http://localhost:3010/ajax/search/stocks',['length'=>10, 'start'=>0, "any_name_matchtype" => "starts_with","any_name" => "test5", "stock_type"=>"accession", "extra_stockprop_columns_view" => encode_json({"organization"=>1}), "stockprop_extra_columns_view_array"=> encode_json(["organization"]) ] );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'recordsTotal' => 5,'draw' => undef,'data' => [['<a href="/stock/38873/view">test5P001</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38874/view">test5P002</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38875/view">test5P003</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38876/view">test5P004</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38877/view">test5P005</a>','accession','Solanum lycopersicum','','']],'recordsFiltered' => 5}, 'test stock search 6');

$mech->post_ok('http://localhost:3010/ajax/search/stocks',['length'=>10, 'start'=>0, "any_name_matchtype" => "ends_with","any_name" => "001", "stock_type"=>"accession", "trait"=>"fresh root weight", "extra_stockprop_columns_view" => encode_json({"organization"=>1}), "stockprop_extra_columns_view_array"=> encode_json(["organization"]) ] );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'data' => [['<a href="/stock/38878/view">UG120001</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/39132/view">UG130001</a>','accession','Solanum lycopersicum','','']],'draw' => undef,'recordsFiltered' => 2,'recordsTotal' => 2}, "test stock search 7");

my $test_bp_id = $schema->resultset("Project::Project")->find({name=>'test'})->project_id;

$mech->post_ok('http://localhost:3010/ajax/search/stocks',['length'=>10, 'start'=>0, "any_name_matchtype" => "contains","any_name" => "g", "stock_type"=>"accession", "breeding_program" => $test_bp_id, "extra_stockprop_columns_view" => encode_json({"organization"=>1}), "stockprop_extra_columns_view_array"=> encode_json(["organization"]) ] );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'data' => [['<a href="/stock/38878/view">UG120001</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38879/view">UG120002</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38880/view">UG120003</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38881/view">UG120004</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38882/view">UG120005</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38883/view">UG120006</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38884/view">UG120007</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38885/view">UG120008</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38886/view">UG120009</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38887/view">UG120010</a>','accession','Solanum lycopersicum','','']],'draw' => undef,'recordsTotal' => 427,'recordsFiltered' => 427}, "test 8");

$mech->post_ok('http://localhost:3010/ajax/search/stocks',['length'=>10, 'start'=>0, "any_name_matchtype" => "contains","any_name" => "t", "stock_type"=>"accession", "project" => "test_trial", "extra_stockprop_columns_view" => encode_json({"organization"=>1}), "stockprop_extra_columns_view_array"=> encode_json(["organization"]) ] );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'draw' => undef,'data' => [['<a href="/stock/38840/view">test_accession1</a>','accession','Solanum lycopersicum','test_accession1_synonym1',''],['<a href="/stock/38841/view">test_accession2</a>','accession','Solanum lycopersicum','test_accession2_synonym1,test_accession2_synonym2',''],['<a href="/stock/38842/view">test_accession3</a>','accession','Solanum lycopersicum','test_accession3_synonym1',''],['<a href="/stock/38843/view">test_accession4</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38844/view">test_accession5</a>','accession','Solanum lycopersicum','','']],'recordsTotal' => 5,'recordsFiltered' => 5}, 'test stock search 9');

$mech->post_ok('http://localhost:3010/ajax/search/stocks',['length'=>10, 'start'=>0, "stock_type"=>"accession", "year" => "2014", "extra_stockprop_columns_view" => encode_json({"organization"=>1}), "stockprop_extra_columns_view_array"=> encode_json(["organization"]) ] );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'draw' => undef,'recordsFiltered' => 432,'data' => [['<a href="/stock/38840/view">test_accession1</a>','accession','Solanum lycopersicum','test_accession1_synonym1',''],['<a href="/stock/38841/view">test_accession2</a>','accession','Solanum lycopersicum','test_accession2_synonym1,test_accession2_synonym2',''],['<a href="/stock/38842/view">test_accession3</a>','accession','Solanum lycopersicum','test_accession3_synonym1',''],['<a href="/stock/38843/view">test_accession4</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38844/view">test_accession5</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38878/view">UG120001</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38879/view">UG120002</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38880/view">UG120003</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38881/view">UG120004</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38882/view">UG120005</a>','accession','Solanum lycopersicum','','']],'recordsTotal' => 432}, 'test stock search 10');

$mech->post_ok('http://localhost:3010/ajax/search/stocks',['length'=>10, 'start'=>0, "any_name_matchtype" => "contains","any_name" => "g", "stock_type"=>"accession", "breeding_program" => $test_bp_id, "location"=>"test_location", "extra_stockprop_columns_view" => encode_json({"organization"=>1}), "stockprop_extra_columns_view_array"=> encode_json(["organization"]) ] );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'recordsFiltered' => 427,'recordsTotal' => 427,'data' => [['<a href="/stock/38878/view">UG120001</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38879/view">UG120002</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38880/view">UG120003</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38881/view">UG120004</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38882/view">UG120005</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38883/view">UG120006</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38884/view">UG120007</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38885/view">UG120008</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38886/view">UG120009</a>','accession','Solanum lycopersicum','',''],['<a href="/stock/38887/view">UG120010</a>','accession','Solanum lycopersicum','','']],'draw' => undef}, 'test stock search 11');

$mech->post_ok('http://localhost:3010/ajax/search/stocks',['length'=>10, 'start'=>0, "any_name_matchtype" => "contains","any_name" => "t", "stock_type"=>"plot", "project" => "test_trial", "extra_stockprop_columns_view" => encode_json({"organization"=>1}), "stockprop_extra_columns_view_array"=> encode_json(["organization"]) ] );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'recordsTotal' => 15,'data' => [['<a href="/stock/38857/view">test_trial21</a>','plot','Solanum lycopersicum','',''],['<a href="/stock/38858/view">test_trial22</a>','plot','Solanum lycopersicum','',''],['<a href="/stock/38859/view">test_trial23</a>','plot','Solanum lycopersicum','',''],['<a href="/stock/38860/view">test_trial24</a>','plot','Solanum lycopersicum','',''],['<a href="/stock/38866/view">test_trial210</a>','plot','Solanum lycopersicum','',''],['<a href="/stock/38867/view">test_trial211</a>','plot','Solanum lycopersicum','',''],['<a href="/stock/38868/view">test_trial212</a>','plot','Solanum lycopersicum','',''],['<a href="/stock/38869/view">test_trial213</a>','plot','Solanum lycopersicum','',''],['<a href="/stock/38870/view">test_trial214</a>','plot','Solanum lycopersicum','',''],['<a href="/stock/38871/view">test_trial215</a>','plot','Solanum lycopersicum','','']],'recordsFiltered' => 15,'draw' => undef}, 'test stock search 12');

$mech->post_ok('http://localhost:3010/ajax/search/stocks',['length'=>10, 'start'=>0, "stock_type"=>"plot", "year" => "2014", "extra_stockprop_columns_view" => encode_json({"organization"=>1}), "stockprop_extra_columns_view_array"=> encode_json(["organization"]) ] );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'recordsTotal' => 1014,'data' => [['<a href="/stock/39311/view">KASESE_TP2013_1003</a>','plot','Solanum lycopersicum','',''],['<a href="/stock/39322/view">KASESE_TP2013_1009</a>','plot','Solanum lycopersicum','',''],['<a href="/stock/39350/view">KASESE_TP2013_1008</a>','plot','Solanum lycopersicum','',''],['<a href="/stock/39493/view">KASESE_TP2013_1001</a>','plot','Solanum lycopersicum','',''],['<a href="/stock/39632/view">KASESE_TP2013_1004</a>','plot','Solanum lycopersicum','',''],['<a href="/stock/39691/view">KASESE_TP2013_1000</a>','plot','Solanum lycopersicum','',''],['<a href="/stock/39819/view">KASESE_TP2013_1002</a>','plot','Solanum lycopersicum','',''],['<a href="/stock/39836/view">KASESE_TP2013_1007</a>','plot','Solanum lycopersicum','',''],['<a href="/stock/39846/view">KASESE_TP2013_1005</a>','plot','Solanum lycopersicum','',''],['<a href="/stock/39919/view">KASESE_TP2013_1006</a>','plot','Solanum lycopersicum','','']],'recordsFiltered' => 1014,'draw' => undef}, 'test stock search 13');

$mech->post_ok('http://localhost:3010/ajax/search/stocks',['length'=>10, 'start'=>0, "any_name_matchtype" => "contains","any_name" => "g", "stock_type"=>"plot", "breeding_program" => $test_bp_id, "extra_stockprop_columns_view" => encode_json({"organization"=>1}), "stockprop_extra_columns_view_array"=> encode_json(["organization"]) ] );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'draw' => undef,'data' => [['<a href="/stock/41284/view">CASS_6Genotypes_103</a>','plot','Manihot esculenta','',''],['<a href="/stock/41285/view">CASS_6Genotypes_205</a>','plot','Manihot esculenta','',''],['<a href="/stock/41295/view">CASS_6Genotypes_104</a>','plot','Manihot esculenta','',''],['<a href="/stock/41296/view">CASS_6Genotypes_105</a>','plot','Manihot esculenta','',''],['<a href="/stock/41297/view">CASS_6Genotypes_106</a>','plot','Manihot esculenta','',''],['<a href="/stock/41298/view">CASS_6Genotypes_107</a>','plot','Manihot esculenta','',''],['<a href="/stock/41299/view">CASS_6Genotypes_201</a>','plot',undef,'',''],['<a href="/stock/41300/view">CASS_6Genotypes_202</a>','plot','Manihot esculenta','',''],['<a href="/stock/41301/view">CASS_6Genotypes_203</a>','plot','Manihot esculenta','',''],['<a href="/stock/41302/view">CASS_6Genotypes_204</a>','plot','Manihot esculenta','','']],'recordsFiltered' => 326,'recordsTotal' => 326}, 'test stock search 14');

$mech->post_ok('http://localhost:3010/ajax/search/stocks',['length'=>10, 'start'=>0, "stock_type"=>"plot", "location"=>"test_location", "extra_stockprop_columns_view" => encode_json({"organization"=>1}), "stockprop_extra_columns_view_array"=> encode_json(["organization"]) ] );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'recordsTotal' => 1954,'recordsFiltered' => 1954,'data' => [['<a href="/stock/41284/view">CASS_6Genotypes_103</a>','plot','Manihot esculenta','',''],['<a href="/stock/41285/view">CASS_6Genotypes_205</a>','plot','Manihot esculenta','',''],['<a href="/stock/41295/view">CASS_6Genotypes_104</a>','plot','Manihot esculenta','',''],['<a href="/stock/41296/view">CASS_6Genotypes_105</a>','plot','Manihot esculenta','',''],['<a href="/stock/41297/view">CASS_6Genotypes_106</a>','plot','Manihot esculenta','',''],['<a href="/stock/41298/view">CASS_6Genotypes_107</a>','plot','Manihot esculenta','',''],['<a href="/stock/41299/view">CASS_6Genotypes_201</a>','plot',undef,'',''],['<a href="/stock/41300/view">CASS_6Genotypes_202</a>','plot','Manihot esculenta','',''],['<a href="/stock/41301/view">CASS_6Genotypes_203</a>','plot','Manihot esculenta','',''],['<a href="/stock/41302/view">CASS_6Genotypes_204</a>','plot','Manihot esculenta','','']],'draw' => undef}, 'test stock search 15');

#add an organization stockprop to an existing stockprop, then search for stocks with that stockprop. login required to add stockprops
$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
$response = decode_json $mech->content;
#print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
$mech->post_ok('http://localhost:3010/stock/prop/add',["stock_id"=>"38842", "prop"=>"organization_name_1", "prop_type"=>"organization"] );
$response = decode_json $mech->content;
print STDERR Dumper $response;
$mech->post_ok('http://localhost:3010/ajax/search/stocks',["editable_stockprop_values" => encode_json({"organization"=>{"matchtype"=>"contains", "value"=>"organization_name_1"}})] );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'data' => [['<a href="/stock/38842/view">test_accession3</a>','accession','Solanum lycopersicum','test_accession3_synonym1']],'recordsFiltered' => 1,'draw' => undef,'recordsTotal' => 1}, 'test stock search 16');

$mech->post_ok('http://localhost:3010/ajax/search/stocks',["editable_stockprop_values" => encode_json({"organization"=>{"matchtype"=>"contains", "value"=>"organization_name_1"}}), "extra_stockprop_columns_view" => encode_json({"organization"=>1}), "stockprop_extra_columns_view_array"=> encode_json(["organization"]) ] );
$response = decode_json $mech->content;
#print STDERR Dumper $response;

is_deeply($response, {'recordsFiltered' => 1,'recordsTotal' => 1,'draw' => undef,'data' => [['<a href="/stock/38842/view">test_accession3</a>','accession','Solanum lycopersicum','test_accession3_synonym1','organization_name_1']]}, 'test stock search 16');

$f->clean_up_db();
done_testing();
