use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use Data::Dumper;
use DateTime;
use JSON;
use SGN::Model::Cvterm;
use CXGN::Transformation::Transformation;
use Sort::Key::Natural qw(natkeysort);

local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $dbh = $schema->storage->dbh;
my $people_schema = $f->people_schema;
my $phenome_schema = $f->phenome_schema;

my $mech = Test::WWW::Mechanize->new;
my $json = JSON->new->allow_nonref;
my @all_new_stocks;
my $time = DateTime->now();
my $upload_date = $time->ymd();

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = decode_json $mech->content;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};

my $location_rs = $schema->resultset('NaturalDiversity::NdGeolocation')->search({description => 'Cornell Biotech'});
my $location_id = $location_rs->first->nd_geolocation_id;

my $bp_rs = $schema->resultset('Project::Project')->search({name => 'test'});
my $breeding_program_id = $bp_rs->first->project_id;

#adding project for uploading data
$mech->post_ok('http://localhost:3010/ajax/transformation/add_transformation_project', [ 'project_name' => 'bti_transformation_1', 'project_program_id' => $breeding_program_id,
    'project_location' => 'test_location', 'year' => '2025', 'project_description' => 'test transgenic historical upload' ]);

$response = decode_json $mech->content;
is($response->{'success'}, '1');

my $project_rs = $schema->resultset('Project::Project')->find({ name => 'bti_transformation_1' });
my $project_id = $project_rs->project_id();

$mech->post_ok('http://localhost:3010/ajax/transformation/set_default_plant_material', [ 'transformation_project_id' => $project_id, 'default_plant_material' => 'UG120001', 'program_name' => 'test']);
$response = decode_json $mech->content;
is($response->{'success'}, '1');


#adding vector construct for testing
my $vector_construct_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "vector_construct", "stock_type")->cvterm_id();
ok(my $organism = $schema->resultset("Organism::Organism")->find_or_create({
    genus   => 'Test_genus',
    species => 'Test_genus test_species',
},));

my @new_vector_constructs = ('BTI_1', 'BTI_2', 'BTI_C');
foreach my $construct_name (@new_vector_constructs) {
    my $new_stock = $schema->resultset('Stock::Stock')->create({
        organism_id => $organism->organism_id,
        name => $construct_name,
        uniquename => $construct_name,
        type_id     => $vector_construct_type_id,
    });

    my $vector_construct_rs = $schema->resultset('Stock::Stock')->find({ uniquename => $construct_name });
    my $vector_stock_id = $vector_construct_rs->stock_id();
    push @all_new_stocks, $vector_stock_id;
}


#test transgenic data upload
my $file = $f->config->{basepath} . "/t/data/stock/transgenic_data_upload.xlsx";
my $ua = LWP::UserAgent->new;
$response = $ua->post(
    'http://localhost:3010/ajax/transformation/upload_transgenic_historical_data',
    Content_Type => 'form-data',
    Content      => [
        "transgenic_historical_data_file" => [
            $file,
            "transgenic_data_upload.xlsx",
            Content_Type => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',

        ],
        "transgenic_data_project_id" => $project_id,
        "transgenic_data_project_name" => 'bti_transformation_1',
        "default_plant_material_name" => 'UG120001',
        "project_breeding_program_name" => 'test',
        "sgn_session_id" => $sgn_session_id,
    ]
);
ok($response->is_success);
my $message = $response->decoded_content;

my $message_hash = decode_json $message;
is_deeply($message_hash, { 'success' => 1 });

#checking generated transformation IDs and controls
my $transformation_obj = CXGN::Transformation::Transformation->new({schema=>$schema, dbh=>$dbh, project_id=>$project_id});
my $transformations = $transformation_obj->get_active_transformations_in_project();
is(scalar(@$transformations), '4');

my $transformation1_stock_id = $transformations->[0]->[0];
push @all_new_stocks, $transformation1_stock_id;
my $transformation1_name = $transformations->[0]->[1];
my $transformation1_is_a_control = $transformations->[0]->[7];
my $transformation1_control_name = $transformations->[0]->[9];

my $transformation2_stock_id = $transformations->[1]->[0];
push @all_new_stocks, $transformation2_stock_id;
my $transformation2_name = $transformations->[1]->[1];
my $transformation2_is_a_control = $transformations->[1]->[7];
my $transformation2_control_name = $transformations->[1]->[9];

my $transformation3_stock_id = $transformations->[2]->[0];
push @all_new_stocks, $transformation3_stock_id;
my $transformation3_name = $transformations->[2]->[1];
my $transformation3_is_a_control = $transformations->[2]->[7];
my $transformation3_control_name = $transformations->[2]->[9];

my $transformation4_stock_id = $transformations->[3]->[0];
push @all_new_stocks, $transformation4_stock_id;
my $transformation4_name = $transformations->[3]->[1];
my $transformation4_is_a_control = $transformations->[3]->[7];
my $transformation4_control_name = $transformations->[3]->[9];

is($transformation1_name, "bti_transformation_1_".$upload_date."_BTI_1_batch_1");
is($transformation2_name, "bti_transformation_1_".$upload_date."_BTI_C_batch_1");
is($transformation3_name, "bti_transformation_1_".$upload_date."_BTI_2_batch_2");
is($transformation4_name, "bti_transformation_1_".$upload_date."_BTI_C_batch_2");

is($transformation2_is_a_control, '1');
is($transformation4_is_a_control, '1');

is($transformation1_control_name, "bti_transformation_1_".$upload_date."_BTI_C_batch_1");
is($transformation3_control_name, "bti_transformation_1_".$upload_date."_BTI_C_batch_2");

#checking transformants in each transformation id
my $transformants_1 = CXGN::Transformation::Transformation->new({schema=>$schema, dbh=>$dbh, transformation_stock_id=>$transformation1_stock_id});
my $result1 = $transformants_1->get_transformant_details();
is (scalar(@$result1), '4');

my @sorted_names_1 = natkeysort {($_->[1])} @$result1;
is($sorted_names_1[0][1], 'new_accession_1');
is($sorted_names_1[0][2], '1');
is($sorted_names_1[2][1], 'new_accession_3');
is($sorted_names_1[2][2], '2');

foreach my $r (@$result1){
    my ($stock_id, $stock_name) =@$r;
    push @all_new_stocks, $stock_id;
}

my $transformants_2 = CXGN::Transformation::Transformation->new({schema=>$schema, dbh=>$dbh, transformation_stock_id=>$transformation2_stock_id});
my $result2 = $transformants_2->get_transformant_details();
is (scalar(@$result2), '4');

my @sorted_names_2 = natkeysort {($_->[1])} @$result2;
is($sorted_names_2[0][1], 'new_accession_10');
is($sorted_names_2[0][2], '3');
is($sorted_names_2[2][1], 'new_accession_12');
is($sorted_names_2[2][2], '1');

foreach my $r (@$result2){
    my ($stock_id, $stock_name) =@$r;
    push @all_new_stocks, $stock_id;
}

my $transformants_3 = CXGN::Transformation::Transformation->new({schema=>$schema, dbh=>$dbh, transformation_stock_id=>$transformation3_stock_id});
my $result3 = $transformants_3->get_transformant_details();
is (scalar(@$result3), '5');

my @sorted_names_3 = natkeysort {($_->[1])} @$result3;
is($sorted_names_3[0][1], 'new_accession_5');
is($sorted_names_3[0][2], '1');
is($sorted_names_3[2][1], 'new_accession_7');
is($sorted_names_3[2][2], '1');

foreach my $r (@$result3){
    my ($stock_id, $stock_name) =@$r;
    push @all_new_stocks, $stock_id;
}

my $transformants_4 = CXGN::Transformation::Transformation->new({schema=>$schema, dbh=>$dbh, transformation_stock_id=>$transformation4_stock_id});
my $result4 = $transformants_4->get_transformant_details();
is (scalar(@$result4), '2');

my @sorted_names_4 = natkeysort {($_->[1])} @$result4;
is($sorted_names_4[0][1], 'new_accession_14');
is($sorted_names_4[0][2], '1');
is($sorted_names_4[1][1], 'new_accession_15');
is($sorted_names_4[1][2], '1');

foreach my $r (@$result4){
    my ($stock_id, $stock_name) =@$r;
    push @all_new_stocks, $stock_id;
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

my $project_owner = $phenome_schema->resultset('ProjectOwner')->find({ project_id => $project_id });
$project_owner->delete();
$project_rs->delete();

$f->clean_up_db();


done_testing();
