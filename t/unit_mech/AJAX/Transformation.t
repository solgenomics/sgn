use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use Data::Dumper;
use JSON;
use SGN::Model::Cvterm;
use CXGN::Transformation::Transformation;

local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $dbh = $schema->storage->dbh;
my $people_schema = $f->people_schema;
my $phenome_schema = $f->phenome_schema;

my $mech = Test::WWW::Mechanize->new;
my $json = JSON->new->allow_nonref;
my @all_new_stocks;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = decode_json $mech->content;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};

my $location_rs = $schema->resultset('NaturalDiversity::NdGeolocation')->search({description => 'Cornell Biotech'});
my $location_id = $location_rs->first->nd_geolocation_id;

my $bp_rs = $schema->resultset('Project::Project')->search({name => 'test'});
my $breeding_program_id = $bp_rs->first->project_id;

#test adding project
$mech->post_ok('http://localhost:3010/ajax/transformation/add_transformation_project', [ 'project_name' => 'transformation_project_1', 'project_program_id' => 134,
    'project_location' => 'test_location', 'year' => '2024', 'project_description' => 'test transformation' ]);

$response = decode_json $mech->content;
is($response->{'success'}, '1');

my $project_rs = $schema->resultset('Project::Project')->find({ name => 'transformation_project_1' });
my $project_id = $project_rs->project_id();

#test adding transformation id

#adding vector construct for testing
my $vector_construct_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "vector_construct", "stock_type")->cvterm_id();
ok(my $organism = $schema->resultset("Organism::Organism")->find_or_create({
    genus   => 'Test_genus',
    species => 'Test_genus test_species',
},));

my $new_vector_construct = $schema->resultset('Stock::Stock')->create({
    organism_id => $organism->organism_id,
    name => 'TT1',
    uniquename => 'TT1',
    type_id     => $vector_construct_type_id,
});

my $vector_construct_rs = $schema->resultset('Stock::Stock')->find({ name => 'TT1' });
my $vector_stock_id = $vector_construct_rs->stock_id();
push @all_new_stocks, $vector_stock_id;

my $transformation_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "transformation", "stock_type")->cvterm_id();
my $before_adding_transformation_id = $schema->resultset("Stock::Stock")->search({ type_id => $transformation_type_id })->count();
my $before_adding_transformation_id_relationship = $schema->resultset("Stock::StockRelationship")->search({})->count();

$mech->post_ok('http://localhost:3010/ajax/transformation/add_transformation_identifier', [ 'transformation_identifier' => 'UG1TT1', 'plant_material' => 'UG120001', 'vector_construct' => 'TT1', 'notes' => 'test', 'transformation_project_id' => $project_id]);

$response = decode_json $mech->content;
is($response->{'success'}, '1');

my $transformation_rs = $schema->resultset('Stock::Stock')->find({name => 'UG1TT1'});
my $transformation_stock_id = $transformation_rs->stock_id();
push @all_new_stocks, $transformation_stock_id;

my $after_adding_transformation_id = $schema->resultset("Stock::Stock")->search({ type_id => $transformation_type_id })->count();
is($after_adding_transformation_id, $before_adding_transformation_id + 1);
my $after_adding_transformation_id_relationship = $schema->resultset("Stock::StockRelationship")->search({})->count();
is($after_adding_transformation_id_relationship, $before_adding_transformation_id_relationship + 2);

#test adding transformants (accessions)
$mech->post_ok('http://localhost:3010/ajax/transformation/add_transformants', [ 'transformation_name' => 'UG1TT1', 'transformation_stock_id' => $transformation_stock_id, 'new_name_count' => 2, 'last_number' => 0 ]);

$response = decode_json $mech->content;
is($response->{'success'}, '1');

#retrieving transformation info
$mech->post_ok("http://localhost:3010/ajax/transformation/transformations_in_project/$project_id");

$response = decode_json $mech->content;
my $transformation = $response->{'data'};
my $transformation_id_count = scalar(@$transformation);
is($transformation_id_count, '1');

$mech->post_ok("http://localhost:3010/ajax/transformation/transformants/$transformation_stock_id");

$response = decode_json $mech->content;
my $transformants = $response->{'data'};
my $transformant_count = scalar(@$transformants);
is($transformant_count, '2');

#retrieving related stocks for vector page
$mech->get_ok("http://localhost:3010/stock/$vector_stock_id/datatables/vector_related_stocks");
$response = decode_json $mech->content;
my $related_stocks = $response->{'data'};
my $related_stock_count = scalar(@$related_stocks);
is($related_stock_count, '2');

#deleting project, transformation_id, vector_construct, transformants
my $project_owner = $phenome_schema->resultset('ProjectOwner')->find({ project_id => $project_id });
$project_owner->delete();
$project_rs->delete();

my $transformation_obj = CXGN::Transformation::Transformation->new({schema=>$schema, dbh=>$dbh, transformation_stock_id=>$transformation_stock_id});
my $result = $transformation_obj->get_transformants();
foreach my $transformant (@$result) {
    push @all_new_stocks, $transformant->[0];
}
#print STDERR "ALL NEW STOCKS =".Dumper(\@all_new_stocks)."\n";
my $dbh = $schema->storage->dbh;
my $q = "delete from phenome.stock_owner where stock_id=?";
my $h = $dbh->prepare($q);

foreach (@all_new_stocks){
    my $row  = $schema->resultset('Stock::Stock')->find({stock_id=>$_});
    $h->execute($_);
    $row->delete();
}


$f->clean_up_db();


done_testing();