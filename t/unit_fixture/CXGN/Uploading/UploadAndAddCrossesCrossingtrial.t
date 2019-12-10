
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use LWP::UserAgent;
use CXGN::Trial;
use CXGN::Pedigree::AddCrossingtrial;
use CXGN::Pedigree::AddCrosses;
use CXGN::Pedigree::AddCrossInfo;
use CXGN::Cross;
use LWP::UserAgent;

#Needed to update IO::Socket::SSL
use Data::Dumper;
use JSON;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $mech = Test::WWW::Mechanize->new;


# test adding crossing trial
$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = decode_json $mech->content;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};
print STDERR $sgn_session_id."\n";

$mech->post_ok('http://localhost:3010/ajax/cross/add_crossingtrial', [ 'crossingtrial_name' => 'test_crossingtrial', 'crossingtrial_program_id' => 134 ,
    'crossingtrial_location' => 'test_location', 'year' => '2017', 'project_description' => 'test description' ]);

$response = decode_json $mech->content;
is($response->{'success'}, '1');

$mech->post_ok('http://localhost:3010/ajax/cross/add_crossingtrial', [ 'crossingtrial_name' => 'test_crossingtrial2', 'crossingtrial_program_id' => 134 ,
    'crossingtrial_location' => 'test_location', 'year' => '2018', 'project_description' => 'test description2' ]);

$response = decode_json $mech->content;
is($response->{'success'}, '1');

$mech->post_ok('http://localhost:3010/ajax/cross/add_crossingtrial', [ 'crossingtrial_name' => 'test_crossingtrial_deletion', 'crossingtrial_program_id' => 134 ,
    'crossingtrial_location' => 'test_location', 'year' => '2019', 'project_description' => 'test deletion' ]);

$response = decode_json $mech->content;
is($response->{'success'}, '1');

# test adding cross and info
my $crossing_trial_rs = $schema->resultset('Project::Project')->find({name =>'test_crossingtrial'});
my $crossing_trial_id = $crossing_trial_rs->project_id();
my $female_plot_id = $schema->resultset('Stock::Stock')->find({name =>'KASESE_TP2013_842'})->stock_id();
my $male_plot_id = $schema->resultset('Stock::Stock')->find({name =>'KASESE_TP2013_1591'})->stock_id();
my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "cross", "stock_type")->cvterm_id();
my $cross_combination_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "cross_combination", "stock_property")->cvterm_id();

my $before_adding_cross = $schema->resultset("Stock::Stock")->search({ type_id => $cross_type_id})->count();
my $before_adding_stocks = $schema->resultset("Stock::Stock")->search({})->count();
my $before_adding_stockprop = $schema->resultset("Stock::Stockprop")->search({ type_id => $cross_combination_type_id})->count();
my $before_adding_stockprop_all = $schema->resultset("Stock::Stockprop")->search({})->count();
my $before_adding_relationship = $schema->resultset("Stock::StockRelationship")->search({})->count();
my $before_adding_cross_in_experiment = $schema->resultset("NaturalDiversity::NdExperiment")->search({})->count();
my $before_adding_cross_in_experiment_stock = $schema->resultset("NaturalDiversity::NdExperimentStock")->search({})->count();


$mech->post_ok('http://localhost:3010/ajax/cross/add_cross', [ 'crossing_trial_id' => $crossing_trial_id, 'cross_name' => 'test_add_cross', 'cross_combination' => 'UG120001xUG120002', 'cross_type' => 'biparental', 'maternal' => 'UG120001', 'paternal' => 'UG120002', 'female_plot' => $female_plot_id,'male_plot' => $male_plot_id]);

$response = decode_json $mech->content;
is($response->{'success'}, '1');

my $after_adding_cross = $schema->resultset("Stock::Stock")->search({ type_id => $cross_type_id})->count();
my $after_adding_stocks = $schema->resultset("Stock::Stock")->search({})->count();
my $after_adding_stockprop = $schema->resultset("Stock::Stockprop")->search({ type_id => $cross_combination_type_id})->count();
my $after_adding_stockprop_all = $schema->resultset("Stock::Stockprop")->search({})->count();
my $after_adding_relationship = $schema->resultset("Stock::StockRelationship")->search({})->count();
my $after_adding_cross_in_experiment = $schema->resultset("NaturalDiversity::NdExperiment")->search({})->count();
my $after_adding_cross_in_experiment_stock = $schema->resultset("NaturalDiversity::NdExperimentStock")->search({})->count();

is($after_adding_cross, $before_adding_cross + 1);
is($after_adding_stocks, $before_adding_stocks + 1);
is($after_adding_stockprop, $before_adding_stockprop + 1);
is($after_adding_stockprop_all, $before_adding_stockprop_all + 1);
is($after_adding_relationship, $before_adding_relationship + 4);
is($after_adding_cross_in_experiment, $before_adding_cross_in_experiment + 1);
is($after_adding_cross_in_experiment_stock, $before_adding_cross_in_experiment_stock + 1);

# test uploading crosses with only accession info
my $before_uploading_cross_a = $schema->resultset("Stock::Stock")->search({ type_id => $cross_type_id})->count();
my $before_uploading_stocks_a = $schema->resultset("Stock::Stock")->search({})->count();
my $before_uploading_relationship_a = $schema->resultset("Stock::StockRelationship")->search({})->count();

my $crossing_trial2_rs = $schema->resultset('Project::Project')->find({name =>'test_crossingtrial2'});
my $crossing_trial2_id = $crossing_trial2_rs->project_id();
my $file = $f->config->{basepath}."/t/data/cross/crosses_simple_upload.xls";
my $ua = LWP::UserAgent->new;
$response = $ua->post(
    'http://localhost:3010/ajax/cross/upload_crosses_file',
    Content_Type => 'form-data',
    Content => [
        "xls_crosses_simple_file" => [ $file, 'crosses_simple_upload.xls', Content_Type => 'application/vnd.ms-excel', ],
        "cross_upload_crossing_trial" => $crossing_trial2_id,
        "sgn_session_id" => $sgn_session_id
    ]
);
ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = decode_json $message;
is_deeply($message_hash, {'success' => 1});

my $after_uploading_cross_a = $schema->resultset("Stock::Stock")->search({ type_id => $cross_type_id})->count();
my $after_uploading_stocks_a = $schema->resultset("Stock::Stock")->search({})->count();
my $after_uploading_relationship_a = $schema->resultset("Stock::StockRelationship")->search({})->count();

is($after_uploading_cross_a, $before_uploading_cross_a + 2);
is($after_uploading_stocks_a, $before_uploading_stocks_a + 2);
is($after_uploading_relationship_a, $before_uploading_relationship_a + 4);

# test uploading crosses with plots
my $female_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "female_parent", "stock_relationship")->cvterm_id();
my $male_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "male_parent", "stock_relationship")->cvterm_id();
my $female_plot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "female_plot_of", "stock_relationship")->cvterm_id();
my $male_plot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "male_plot_of", "stock_relationship")->cvterm_id();

my $before_uploading_relationship_all = $schema->resultset("Stock::StockRelationship")->search({})->count();
my $before_uploading_relationship_female = $schema->resultset("Stock::StockRelationship")->search({type_id => $female_type_id})->count();
my $before_uploading_relationship_male = $schema->resultset("Stock::StockRelationship")->search({type_id => $male_type_id})->count();
my $before_uploading_relationship_femaleplot = $schema->resultset("Stock::StockRelationship")->search({type_id => $female_plot_type_id})->count();
my $before_uploading_relationship_maleplot = $schema->resultset("Stock::StockRelationship")->search({type_id => $male_plot_type_id})->count();

$crossing_trial2_rs = $schema->resultset('Project::Project')->find({name =>'test_crossingtrial2'});
$crossing_trial2_id = $crossing_trial2_rs->project_id();
$file = $f->config->{basepath}."/t/data/cross/crosses_plots_upload.xls";
$ua = LWP::UserAgent->new;
$response = $ua->post(
    'http://localhost:3010/ajax/cross/upload_crosses_file',
    Content_Type => 'form-data',
    Content => [
        "xls_crosses_plots_file" => [ $file, 'crosses_plots_upload.xls', Content_Type => 'application/vnd.ms-excel', ],
        "cross_upload_crossing_trial" => $crossing_trial2_id,
        "sgn_session_id" => $sgn_session_id
    ]
);
ok($response->is_success);
$message = $response->decoded_content;
$message_hash = decode_json $message;
is_deeply($message_hash, {'success' => 1});

my $after_uploading_relationship_all = $schema->resultset("Stock::StockRelationship")->search({})->count();
my $after_uploading_relationship_female = $schema->resultset("Stock::StockRelationship")->search({type_id => $female_type_id})->count();
my $after_uploading_relationship_male = $schema->resultset("Stock::StockRelationship")->search({type_id => $male_type_id})->count();
my $after_uploading_relationship_femaleplot = $schema->resultset("Stock::StockRelationship")->search({type_id => $female_plot_type_id})->count();
my $after_uploading_relationship_maleplot = $schema->resultset("Stock::StockRelationship")->search({type_id => $male_plot_type_id})->count();

is($after_uploading_relationship_all, $before_uploading_relationship_all + 8);
is($after_uploading_relationship_female, $before_uploading_relationship_female + 2);
is($after_uploading_relationship_male, $before_uploading_relationship_male +2);
is($after_uploading_relationship_femaleplot, $before_uploading_relationship_femaleplot + 2);
is($after_uploading_relationship_maleplot, $before_uploading_relationship_maleplot + 2);

#add plants for testing (a total of 38 entries)
my $trial = CXGN::Trial->new({bcs_schema => $schema, trial_id => 165});
$trial->create_plant_entities(2);

# test uploading crosses with plants
my $female_plant_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "female_parent", "stock_relationship")->cvterm_id();
my $male_plant_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "male_parent", "stock_relationship")->cvterm_id();

my $before_uploading_relationship_femaleplant = $schema->resultset("Stock::StockRelationship")->search({type_id => $female_plant_type_id})->count();
my $before_uploading_relationship_maleplant = $schema->resultset("Stock::StockRelationship")->search({type_id => $male_plant_type_id})->count();

$crossing_trial2_rs = $schema->resultset('Project::Project')->find({name =>'test_crossingtrial2'});
$crossing_trial2_id = $crossing_trial2_rs->project_id();
$file = $f->config->{basepath}."/t/data/cross/crosses_plants_upload.xls";
$ua = LWP::UserAgent->new;
$response = $ua->post(
    'http://localhost:3010/ajax/cross/upload_crosses_file',
    Content_Type => 'form-data',
    Content => [
        "xls_crosses_plants_file" => [ $file, 'crosses_plants_upload.xls', Content_Type => 'application/vnd.ms-excel', ],
        "cross_upload_crossing_trial" => $crossing_trial2_id,
        "sgn_session_id" => $sgn_session_id
    ]
);
ok($response->is_success);
$message = $response->decoded_content;
$message_hash = decode_json $message;
is_deeply($message_hash, {'success' => 1});

my $after_uploading_relationship_femaleplant = $schema->resultset("Stock::StockRelationship")->search({type_id => $female_plant_type_id})->count();
my $after_uploading_relationship_maleplant = $schema->resultset("Stock::StockRelationship")->search({type_id => $male_plant_type_id})->count();

is($after_uploading_relationship_femaleplant, $before_uploading_relationship_femaleplant + 2);
is($after_uploading_relationship_maleplant, $before_uploading_relationship_maleplant + 2);

# test retrieving crosses in a trial
my $test_add_cross_rs = $schema->resultset('Stock::Stock')->find({name =>'test_add_cross'});
my $test_add_cross_id = $test_add_cross_rs->stock_id();
my $UG120001_id = $schema->resultset('Stock::Stock')->find({name =>'UG120001'})->stock_id();
my $UG120002_id = $schema->resultset('Stock::Stock')->find({name =>'UG120002'})->stock_id();

$mech->post_ok("http://localhost:3010/ajax/breeders/trial/$crossing_trial_id/crosses_and_details_in_trial");
$response = decode_json $mech->content;

is_deeply($response, {'data'=> [
    [qq{<a href = "/cross/$test_add_cross_id">test_add_cross</a>}, 'UG120001xUG120002', 'biparental', qq{<a href = "/stock/$UG120001_id/view">UG120001</a>}, qq{<a href = "/stock/$UG120002_id/view">UG120002</a>}, qq{<a href = "/stock/$female_plot_id/view">KASESE_TP2013_842</a>}, qq{<a href = "/stock/$male_plot_id/view">KASESE_TP2013_1591</a>}, qq{<a href = "/stock//view"></a>}, qq{<a href = "/stock//view"></a>}]
]}, 'crosses in a trial');

# test uploading progenies
my $offspring_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "offspring_of", "stock_relationship")->cvterm_id();
my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();

my $before_add_progenies_stock = $schema->resultset("Stock::Stock")->search({})->count();
my $before_add_progenies_accession = $schema->resultset("Stock::Stock")->search({type_id => $accession_type_id})->count();
my $before_add_progenies_relationship_all = $schema->resultset("Stock::StockRelationship")->search({})->count();
my $before_add_progenies_offspring = $schema->resultset("Stock::StockRelationship")->search({type_id => $offspring_type_id})->count();

$file = $f->config->{basepath}."/t/data/cross/update_progenies.xls";
$ua = LWP::UserAgent->new;
$response = $ua->post(
    'http://localhost:3010/ajax/cross/upload_progenies',
    Content_Type => 'form-data',
    Content => [
        progenies_upload_file => [ $file, 'update_progenies.xls', Content_Type => 'application/vnd.ms-excel', ],
        "sgn_session_id" => $sgn_session_id
    ]
);
ok($response->is_success);
$message = $response->decoded_content;
$message_hash = decode_json $message;
is_deeply($message_hash, {'success' => 1});

my $after_add_progenies_stock = $schema->resultset("Stock::Stock")->search({})->count();
my $after_add_progenies_accession = $schema->resultset("Stock::Stock")->search({type_id => $accession_type_id})->count();
my $after_add_progenies_relationship_all = $schema->resultset("Stock::StockRelationship")->search({})->count();
my $after_add_progenies_offspring = $schema->resultset("Stock::StockRelationship")->search({type_id => $offspring_type_id})->count();

is($after_add_progenies_stock, $before_add_progenies_stock + 6);
is($after_add_progenies_accession, $before_add_progenies_accession + 6);
is($after_add_progenies_relationship_all, $before_add_progenies_relationship_all + 18);
is($after_add_progenies_offspring, $before_add_progenies_offspring + 6);

# test updating cross info by uploading
my $before_updating_info_stocks = $schema->resultset("Stock::Stock")->search({})->count();
my $before_updating_info_stockprop = $schema->resultset("Stock::Stockprop")->search({})->count();
my $before_updating_info_relationship = $schema->resultset("Stock::StockRelationship")->search({})->count();

$file = $f->config->{basepath}."/t/data/cross/update_crossinfo.xls";
$ua = LWP::UserAgent->new;
$response = $ua->post(
    'http://localhost:3010/ajax/cross/upload_info',
    Content_Type => 'form-data',
    Content => [
        crossinfo_upload_file => [ $file, 'update_crossinfo.xls', Content_Type => 'application/vnd.ms-excel', ],
        "sgn_session_id" => $sgn_session_id
    ]
);
ok($response->is_success);
$message = $response->decoded_content;
$message_hash = decode_json $message;
is_deeply($message_hash, {'success' => 1});

my $after_updating_info_stocks = $schema->resultset("Stock::Stock")->search({})->count();
my $after_updating_info_stockprop = $schema->resultset("Stock::Stockprop")->search({})->count();
my $after_updating_info_relationship = $schema->resultset("Stock::StockRelationship")->search({})->count();

is($after_updating_info_stocks, $before_updating_info_stocks);
is($after_updating_info_stockprop, $before_updating_info_stockprop+1);
is($after_updating_info_relationship, $before_updating_info_relationship);

# test retrieving crossing experimental info after updating
$mech->post_ok("http://localhost:3010/ajax/breeders/trial/$crossing_trial_id/cross_properties_trial");
$response = decode_json $mech->content;

is_deeply($response, {'data'=> [
    [qq{<a href = "/cross/$test_add_cross_id">test_add_cross</a>}, 'UG120001xUG120002', "10", "2017/02/02", "10", "50", undef, undef]
]}, 'crossing experiment info');


# test uploading family names
my $family_name_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "family_name", "stock_type")->cvterm_id();

my $before_family_name_stocks = $schema->resultset("Stock::Stock")->search({})->count();
my $before_add_family_name = $schema->resultset("Stock::Stock")->search({type_id => $family_name_type_id})->count();

$file = $f->config->{basepath}."/t/data/cross/family_name_upload.xls";
$ua = LWP::UserAgent->new;
$response = $ua->post(
    'http://localhost:3010/ajax/cross/upload_family_names',
    Content_Type => 'form-data',
    Content => [
        family_name_upload_file => [ $file, 'family_name_upload.xls', Content_Type => 'application/vnd.ms-excel', ],
        "sgn_session_id" => $sgn_session_id
    ]
);
ok($response->is_success);
$message = $response->decoded_content;
$message_hash = decode_json $message;
is_deeply($message_hash, {'success' => 1});

my $after_family_name_stocks = $schema->resultset("Stock::Stock")->search({})->count();
my $after_add_family_name = $schema->resultset("Stock::Stock")->search({type_id => $family_name_type_id})->count();

is($after_family_name_stocks, $before_family_name_stocks +4);
is($after_add_family_name, $before_add_family_name + 4);

#test deleting crossing
my $before_deleting_crosses = $schema->resultset("Stock::Stock")->search({ type_id => $cross_type_id})->count();
my $before_deleting_accessions = $schema->resultset("Stock::Stock")->search({ type_id => $accession_type_id})->count();
my $before_deleting_stocks = $schema->resultset("Stock::Stock")->search({})->count();
my $before_deleting_relationship = $schema->resultset("Stock::StockRelationship")->search({})->count();
my $experiment_before_deleting_cross = $schema->resultset("NaturalDiversity::NdExperiment")->search({})->count();
my $experiment_stock_before_deleting_cross = $schema->resultset("NaturalDiversity::NdExperimentStock")->search({})->count();

# test_cross_upload1 has 2 progenies and has family name
my $deleting_cross_id = $schema->resultset("Stock::Stock")->find({name=>'test_cross_upload1'})->stock_id;
$mech->post_ok('http://localhost:3010/ajax/cross/delete', [ 'cross_id' => $deleting_cross_id]);
$response = decode_json $mech->content;
is_deeply($message_hash, {'success' => 1});

my $after_deleting_crosses = $schema->resultset("Stock::Stock")->search({ type_id => $cross_type_id})->count();
my $after_deleting_accessions = $schema->resultset("Stock::Stock")->search({ type_id => $accession_type_id})->count();
my $after_deleting_stocks = $schema->resultset("Stock::Stock")->search({})->count();
my $after_deleting_relationship = $schema->resultset("Stock::StockRelationship")->search({})->count();
my $experiment_after_deleting_cross = $schema->resultset("NaturalDiversity::NdExperiment")->search({})->count();
my $experiment_stock_after_deleting_cross = $schema->resultset("NaturalDiversity::NdExperimentStock")->search({})->count();

is($after_deleting_crosses, $before_deleting_crosses - 1);
is($after_deleting_accessions, $before_deleting_accessions - 2);
is($after_deleting_stocks, $before_deleting_stocks - 3);
is($after_deleting_relationship, $before_deleting_relationship - 9);
is($experiment_after_deleting_cross, $experiment_before_deleting_cross - 1);
is($experiment_stock_after_deleting_cross, $experiment_stock_before_deleting_cross - 1);

# test deleting empty crossing experiment
my $before_deleting_empty_experiment = $schema->resultset("Project::Project")->search({})->count();

my $crossing_experiment_id = $schema->resultset("Project::Project")->find({name=>'test_crossingtrial_deletion'})->project_id;
$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$crossing_experiment_id.'/delete/crossing_experiment');
$response = decode_json $mech->content;
is_deeply($message_hash, {'success' => 1});

my $after_deleting_empty_experiment = $schema->resultset("Project::Project")->search({})->count();

is($after_deleting_empty_experiment, $before_deleting_empty_experiment - 1);

# test deleting crossing experiment with crosses
my $before_deleting_experiment = $schema->resultset("Project::Project")->search({})->count();

my $crossing_experiment_id_2 = $schema->resultset("Project::Project")->find({name=>'test_crossingtrial'})->project_id;
$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$crossing_experiment_id_2.'/delete/crossing_experiment');
$response = decode_json $mech->content;
ok($response->{'error'});

my $after_deleting_experiment = $schema->resultset("Project::Project")->search({})->count();

is($after_deleting_experiment, $before_deleting_experiment);

#test deleting all crosses in test_crossingtrial and test_crossingtrial2
$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$crossing_trial2_id.'/delete_all_crosses_in_crossingtrial');
$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$crossing_trial_id.'/delete_all_crosses_in_crossingtrial');

my $after_delete_all_crosses_crosses = $schema->resultset("Stock::Stock")->search({ type_id => $cross_type_id})->count();
my $after_delete_all_crosses_in_experiment = $schema->resultset("NaturalDiversity::NdExperiment")->search({})->count();
my $after_delete_all_crosses_in_experiment_stock = $schema->resultset("NaturalDiversity::NdExperimentStock")->search({})->count();
my $stocks_after_delete_all_crosses = $schema->resultset("Stock::Stock")->search({})->count();

is($after_delete_all_crosses_crosses, $before_adding_cross);
is($after_delete_all_crosses_in_experiment, $before_adding_cross_in_experiment);

# nd_experiment_stock has 38 more rows after adding plants for testing uploading crosses with plant info
is($after_delete_all_crosses_in_experiment_stock, $before_adding_cross_in_experiment_stock + 38);

# stock table has 42 more rows after adding 4 family names and 38 plants
is($stocks_after_delete_all_crosses, $before_adding_stocks + 42);

# remove added crossing trials after test so that they don't affect downstream tests
$crossing_trial_rs->delete();
$crossing_trial2_rs->delete();



done_testing();
