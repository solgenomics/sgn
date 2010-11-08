
use strict;
use warnings;

use lib 't/lib';
use JSON::Any;
use Test::More tests=>2;
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


