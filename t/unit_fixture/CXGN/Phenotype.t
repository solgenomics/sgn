
use strict;

use Test::More;


use lib 't/lib';

use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Phenotype;

my $f = SGN::Test::Fixture->new();

my $p = CXGN::Phenotype->new( { schema => $f->bcs_schema() });


$p->cvterm_name('dry matter content percentage');
is($p->cvterm_name(), "dry matter content percentage", "cvterm_name check");

$p->value(40);
is($p->value(), 40, "value check");

$p->observationunit_id(39252); # KASESE_TP2013_1016
is($p->observationunit_id(), 39252, "observationunit_id test");

$p->nd_experiment_id(78151); # an nd_experiment_id associated with KASESE_TP2023_1016

$p->uniquename('test_uniquename');
is($p->uniquename(), "test_uniquename", "uniquename test");

$p->operator("Butz");
is($p->operator(), "Butz", "operator test");

$p->collect_date("2025-03-18 22:00");
is($p->collect_date(), "2025-03-18 22:00", "collect date test");

my $result = $p->store();

is($result->{success}, 1, "store result test");

print STDERR "phenotype_id = ".$result->{phenotype_id}."\n";

# insert some properties
#
my $trait_maximum_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($f->bcs_schema, "trait_maximum", "trait_property")->cvterm_id();
my $trait_minimum_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($f->bcs_schema, "trait_minimum", "trait_property")->cvterm_id();
my $trait_categories_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($f->bcs_schema, "trait_categories", "trait_property")->cvterm_id();
my $trait_format_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($f->bcs_schema, "trait_format", "trait_property")->cvterm_id();
my $trait_repeat_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($f->bcs_schema, "trait_repeat_type", "trait_property")->cvterm_id();
my $cvterm_id = SGN::Model::Cvterm->get_cvterm_row($f->bcs_schema, $p->cvterm_name(), "cassava_trait")->cvterm_id();

print STDERR "CVTERM ID $cvterm_id\n";

my @values = (20, 10, '1/2/3/4/5', 'numeric', 'single');

foreach my $trait_id ( $trait_maximum_cvterm_id , $trait_minimum_cvterm_id, $trait_categories_cvterm_id, $trait_format_cvterm_id,  $trait_repeat_type_cvterm_id ) {
    my $value = unshift(@values);
    my $row = {
	cvterm_id => $cvterm_id,
	type_id => $trait_id,
	value => $value,
    };

    $f->bcs_schema()->resultset("Cv::Cvtermprop")->find_or_create($row);
}

my $p2 = CXGN::Phenotype->new( { schema => $f->bcs_schema(), phenotype_id => $result->{phenotype_id} });

is($p2->cvterm_id(), $cvterm_id, "cvterm_id check");

is($p2->value(), 40, "value check");

is($p2->nd_experiment_id(), 78151, "nd_experiment_id check");

is($p2->uniquename(), "test_uniquename", "uniquename test");

is($p2->operator(), "Butz", "operator test");

is($p2->collect_date(), "2025-03-18 22:00:00", "collect date test");

$p2->get_trait_props();

ok($p2->check_trait_minimum(), "check trait minimum");

ok($p2->check_trait_maximum(), "check trait maximum");

$f->clean_up_db();

done_testing();




