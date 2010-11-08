
use strict;
use warnings;

use lib 't/lib';
use JSON::Any;
use Test::More tests=>10;
use SGN::Test::WWW::Mechanize;

my $m = SGN::Test::WWW::Mechanize->new();
my $j = JSON::Any->new();

my $term = "SP:0000181";
$m->get_ok("/ajax/onto/parents/?node=$term");
my $contents = $m->content();

my $parsed_content = $j->jsonToObj($contents);

my $expected_json = '[{"has_children":1,"cvterm_name":"fruit color","relationship":"","cvterm_id":"22996","accession":"SP:0000012"},{"has_children":1,"cvterm_name":"fruit","relationship":"","cvterm_id":"39958","accession":"SP:0000037"},{"has_children":1,"cvterm_name":"Solanaceae phenotype ontology","relationship":"","cvterm_id":"23057","accession":"SP:0001000"},{"has_children":1,"cvterm_name":"distal fruit end","relationship":"","cvterm_id":"50180","accession":"SP:0000179"},{"has_children":1,"cvterm_name":"fruit end","relationship":"","cvterm_id":"39959","accession":"SP:0000069"},{"has_children":1,"cvterm_name":"fruit","relationship":"","cvterm_id":"39958","accession":"SP:0000037"},{"has_children":1,"cvterm_name":"Solanaceae phenotype ontology","relationship":"","cvterm_id":"23057","accession":"SP:0001000"}]';


my $expected = $j->jsonToObj($expected_json);

is_deeply($parsed_content, $expected);

##
$term = 'SP:0000069';
$m->get_ok("/ajax/onto/children/?node=$term");
$contents = $m->content();

$parsed_content = $j->jsonToObj($contents);

$expected_json = '[{"has_children":1,"cvterm_name":"distal fruit end","relationship":"is_a","cvterm_id":"50147","accession":"SP:0000179"},{"has_children":1,"cvterm_name":"proximal fruit end","relationship":"is_a","cvterm_id":"50164","accession":"SP:0000180"}]';


$expected = $j->jsonToObj($expected_json);

is_deeply($parsed_content, $expected);

##
$m->get_ok("/ajax/onto/roots");
$contents = $m->content();

$parsed_content = $j->jsonToObj($contents);

$expected_json = '[{"has_children":1,"cvterm_name":"biological_process","relationship":"","cvterm_id":"4884","accession":"GO:0008150"},{"has_children":1,"cvterm_name":"cellular_component","relationship":"","cvterm_id":"2789","accession":"GO:0005575"},{"has_children":1,"cvterm_name":"molecular_function","relationship":"","cvterm_id":"1149","accession":"GO:0003674"},{"has_children":1,"cvterm_name":"plant growth and development stages","relationship":"","cvterm_id":"21904","accession":"PO:0009012"},{"has_children":1,"cvterm_name":"plant structure","relationship":"","cvterm_id":"21444","accession":"PO:0009011"},{"has_children":1,"cvterm_name":"Solanaceae phenotype ontology","relationship":"","cvterm_id":"23057","accession":"SP:0001000"},{"has_children":1,"cvterm_name":"Sequence_Ontology","relationship":"","cvterm_id":"21922","accession":"SO:0000000"},{"has_children":1,"cvterm_name":"quality","relationship":"","cvterm_id":"49742","accession":"PATO:0000001"}]';


$expected = $j->jsonToObj($expected_json);

is_deeply($parsed_content, $expected);

##
$m->get_ok("/ajax/onto/cache/?node=$term");
$contents = $m->content();

$parsed_content = $j->jsonToObj($contents);

$expected_json = '[{"has_children":1,"parent":"SP:0000037","cvterm_name":"fruit number","relationship":"is_a","cvterm_id":"47489","accession":"SP:0000106"},{"has_children":1,"parent":"SP:0000037","cvterm_name":"fruit metabolites","relationship":"is_a","cvterm_id":"47848","accession":"SP:0000167"},{"has_children":1,"parent":"SP:0000037","cvterm_name":"fruit ripening","relationship":"is_a","cvterm_id":"22997","accession":"SP:0000013"},{"has_children":1,"parent":"SP:0000037","cvterm_name":"fruit color","relationship":"is_a","cvterm_id":"22996","accession":"SP:0000012"},{"has_children":1,"parent":"SP:0000037","cvterm_name":"fruit morphology","relationship":"is_a","cvterm_id":"22995","accession":"SP:0000011"},{"has_children":1,"parent":"SP:0000037","cvterm_name":"fruit end","relationship":"part_of","cvterm_id":"39959","accession":"SP:0000069"},{"has_children":1,"parent":"SP:0000037","cvterm_name":"fruit mass","relationship":"is_a","cvterm_id":"39966","accession":"SP:0000080"},{"has_children":1,"parent":"SP:0000037","cvterm_name":"pericarp","relationship":"part_of","cvterm_id":"58476","accession":"SP:0000371"},{"has_children":1,"parent":"SP:0001000","cvterm_name":"seed","relationship":"is_a","cvterm_id":"47485","accession":"SP:0000100"},{"has_children":1,"parent":"SP:0001000","cvterm_name":"leaf","relationship":"is_a","cvterm_id":"47507","accession":"SP:0000108"},{"has_children":1,"parent":"SP:0001000","cvterm_name":"flower","relationship":"is_a","cvterm_id":"47498","accession":"SP:0000115"},{"has_children":1,"parent":"SP:0001000","cvterm_name":"flowering","relationship":"is_a","cvterm_id":"22990","accession":"SP:0000006"},{"has_children":1,"parent":"SP:0001000","cvterm_name":"sterility","relationship":"is_a","cvterm_id":"22998","accession":"SP:0000014"},{"has_children":0,"parent":"SP:0001000","cvterm_name":"hair modifications","relationship":"is_a","cvterm_id":"23002","accession":"SP:0000018"},{"has_children":1,"parent":"SP:0001000","cvterm_name":"biochemical metabolites","relationship":"is_a","cvterm_id":"23003","accession":"SP:0000019"},{"has_children":0,"parent":"SP:0001000","cvterm_name":"root modifications","relationship":"is_a","cvterm_id":"23004","accession":"SP:0000020"},{"has_children":0,"parent":"SP:0001000","cvterm_name":"nutritional or hormonal disorder","relationship":"is_a","cvterm_id":"23009","accession":"SP:0000025"},{"has_children":0,"parent":"SP:0001000","cvterm_name":"allozyme variant","relationship":"is_a","cvterm_id":"23065","accession":"SP:0000029"},{"has_children":0,"parent":"SP:0001000","cvterm_name":"vascular tissue","relationship":"is_a","cvterm_id":"23066","accession":"SP:0000030"},{"has_children":1,"parent":"SP:0001000","cvterm_name":"fruit","relationship":"is_a","cvterm_id":"39958","accession":"SP:0000037"},{"has_children":1,"parent":"SP:0001000","cvterm_name":"post harvest quality","relationship":"is_a","cvterm_id":"50157","accession":"SP:0000197"},{"has_children":1,"parent":"SP:0001000","cvterm_name":"whole plant phenotype","relationship":"is_a","cvterm_id":"50158","accession":"SP:0000205"},{"has_children":1,"parent":"SP:0001000","cvterm_name":"shoot phenotype","relationship":"is_a","cvterm_id":"50156","accession":"SP:0000192"},{"has_children":1,"parent":"SP:0001000","cvterm_name":"processing quality","relationship":"is_a","cvterm_id":"56634","accession":"SP:0000221"}]';


$expected = $j->jsonToObj($expected_json);

is_deeply($parsed_content, $expected);


##

my $match_string = 'fruit end color';
$m->get_ok("/ajax/onto/match/?db_name=SP&term_name=$match_string");
$contents = $m->content();

$parsed_content = $j->jsonToObj($contents);

$expected_json = '[{"cv_name":"solanaceae_phenotype","cvterm_name":"proximal fruit end color","cvterm_id":"50132","accession":"SP:0000182"},{"cv_name":"solanaceae_phenotype","cvterm_name":"distal fruit end color","cvterm_id":"50137","accession":"SP:0000181"}]';


$expected = $j->jsonToObj($expected_json);

is_deeply($parsed_content, $expected);
