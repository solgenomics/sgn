use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use JSON;
use SGN::Model::Cvterm;

# /ajax/stock/add_stock_parent is called from mason/pedigree/stock_pedigree.mas,
# whose success handler reads response.error. Every answer, including a
# successful one, must therefore be a JSON object.

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $mech = Test::WWW::Mechanize->new;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = decode_json $mech->content;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');

my $female_parent = $schema->resultset('Stock::Stock')->find({ uniquename => 'test_accession1' });
my $male_parent = $schema->resultset('Stock::Stock')->find({ uniquename => 'test_accession2' });

# a new accession without parents, so the test does not depend on fixture pedigrees
my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
my $child = $schema->resultset('Stock::Stock')->create({
    organism_id => $female_parent->organism_id(),
    name => 'add_stock_parent_test_child',
    uniquename => 'add_stock_parent_test_child',
    type_id => $accession_type_id,
});
my $child_id = $child->stock_id();

my $add_parent = sub {
    my $parent_name = shift;
    my $parent_type = shift;
    $mech->get_ok("http://localhost:3010/ajax/stock/add_stock_parent?stock_id=$child_id&parent_name=$parent_name&parent_type=$parent_type&cross_type=biparental", "add $parent_type parent $parent_name");
    my $decoded = eval { decode_json $mech->content };
    # show the raw body in the test output when it is not a JSON object (for example null)
    return ref($decoded) eq 'HASH' ? $decoded : { body => $mech->content };
};

$response = $add_parent->('add_stock_parent_test_missing', 'female');
like($response->{'error'}, qr/was not found/, 'an unknown parent returns a JSON error');

$response = $add_parent->('test_accession1', 'female');
is_deeply($response, { success => 1 }, 'adding a female parent returns a JSON success object');

$response = $add_parent->('test_accession2', 'male');
is_deeply($response, { success => 1 }, 'adding a male parent returns a JSON success object');

$response = $add_parent->('test_accession2', 'female');
like($response->{'error'}, qr/already associated/, 'a second female parent returns a JSON error');

my $female_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
my $male_parent_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();
my $relationships = $schema->resultset('Stock::StockRelationship')->search({ object_id => $child_id });
is($relationships->search({ subject_id => $female_parent->stock_id(), type_id => $female_parent_type_id })->count(), 1, 'female parent is stored');
is($relationships->search({ subject_id => $male_parent->stock_id(), type_id => $male_parent_type_id })->count(), 1, 'male parent is stored');
is($relationships->count(), 2, 'failed requests store no relationship');

# remove the relationships and the accession created by this test
$relationships->delete();
$child->delete();
$f->clean_up_db();

done_testing();
