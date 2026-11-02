use strict;
use warnings;
use lib 't/lib';
use Test::More;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Transformation::AddTransformant;

my$f=SGN::Test::Fixture->new;
my$s=$f->bcs_schema;
my$seed=$s->resultset('Stock::Stock')->find({uniquename=>'test_accession1'});
my%type=map{$_=>SGN::Model::Cvterm->get_cvterm_row($s,$_,'stock_type')->cvterm_id}qw(transformation vector_construct);
my%rel=map{$_=>SGN::Model::Cvterm->get_cvterm_row($s,$_,'stock_relationship')->cvterm_id}qw(plant_material_of vector_construct_of female_parent male_parent);
my$vector=$s->resultset('Stock::Stock')->create({name=>'parentage_factory_vector',uniquename=>'parentage_factory_vector',
    organism_id=>$seed->organism_id,type_id=>$type{vector_construct}});
my$transformation=$s->resultset('Stock::Stock')->create({name=>'parentage_factory_transformation',uniquename=>'parentage_factory_transformation',
    organism_id=>$seed->organism_id,type_id=>$type{transformation}});
for my$pair([$seed,$rel{plant_material_of}],[$vector,$rel{vector_construct_of}]) {
    $s->resultset('Stock::StockRelationship')->create({object_id=>$transformation->stock_id,subject_id=>$pair->[0]->stock_id,type_id=>$pair->[1]});
}
my$name='parentage_factory_transformant';
my$r=CXGN::Transformation::AddTransformant->new(schema=>$s,phenome_schema=>$f->phenome_schema,dbh=>$f->dbh,
    transformation_stock_id=>$transformation->stock_id,transformant_names=>[$name],owner_id=>41,
    additional_transformant_info=>{$name=>{number_of_insertions=>1}})->add_transformant;
ok($r->{success},'standard transformation factory still creates its accession');
my$child=$s->resultset('Stock::Stock')->find({uniquename=>$name});
ok($child,'new transformant exists');
if($child) {
    my$rows=$s->resultset('Stock::StockRelationship')->search({object_id=>$child->stock_id});
    is($rows->find({type_id=>$rel{female_parent}})->subject_id,$seed->stock_id,'maternal source unchanged');
    is($rows->find({type_id=>$rel{male_parent}})->subject_id,$vector->stock_id,'vector parent unchanged');
    is($rows->find({type_id=>$rel{male_parent}})->value,undef,'male link does not carry a duplicate method');
    $f->phenome_schema->resultset('StockOwner')->search({stock_id=>$child->stock_id})->delete;
    $s->resultset('Stock::StockRelationship')->search({-or=>[object_id=>$child->stock_id,subject_id=>$child->stock_id]})->delete;
    $child->delete;
}
my@ids=($vector->stock_id,$transformation->stock_id);
$s->resultset('Stock::StockRelationship')->search({-or=>[object_id=>{-in=>\@ids},subject_id=>{-in=>\@ids}]})->delete;
$transformation->delete;$vector->delete;
$f->clean_up_db;
done_testing;
