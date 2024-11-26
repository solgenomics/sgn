
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
use CXGN::Pedigree::AddProgeniesExistingAccessions;
use CXGN::Pedigree::AddPedigrees;
use Bio::GeneticRelationships::Individual;
use Bio::GeneticRelationships::Pedigree;
use CXGN::Cross;
use CXGN::Pedigree::AddCrossTissueSamples;
use LWP::UserAgent;
use CXGN::Trial::Download;
use Spreadsheet::WriteExcel;
use Spreadsheet::Read;

#Needed to update IO::Socket::SSL
use Data::Dumper;
use JSON;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $phenome_schema = $f->phenome_schema;

my $mech = Test::WWW::Mechanize->new;

for my $extension ("xls", "xlsx") {

    # test adding crossing trial
    $mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username" => "janedoe", "password" => "secretpw", "grant_type" => "password" ]);
    my $response = decode_json $mech->content;
    is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
    my $sgn_session_id = $response->{access_token};
    print STDERR $sgn_session_id . "\n";

    $mech->post_ok('http://localhost:3010/ajax/cross/add_crossingtrial', [ 'crossingtrial_name' => 'test_crossingtrial', 'crossingtrial_program_id' => 134,
        'crossingtrial_location'                                                                => 'test_location', 'year' => '2017', 'project_description' => 'test description' ]);

    $response = decode_json $mech->content;
    is($response->{'success'}, '1');

    $mech->post_ok('http://localhost:3010/ajax/cross/add_crossingtrial', [ 'crossingtrial_name' => 'test_crossingtrial2', 'crossingtrial_program_id' => 134,
        'crossingtrial_location'                                                                => 'test_location', 'year' => '2018', 'project_description' => 'test description2' ]);

    $response = decode_json $mech->content;
    is($response->{'success'}, '1');

    $mech->post_ok('http://localhost:3010/ajax/cross/add_crossingtrial', [ 'crossingtrial_name' => 'test_crossingtrial_deletion', 'crossingtrial_program_id' => 134,
        'crossingtrial_location'                                                                => 'test_location', 'year' => '2019', 'project_description' => 'test deletion' ]);

    $response = decode_json $mech->content;
    is($response->{'success'}, '1');

    #create populations for testing bulk and bulk_open cross types
    $mech->post_ok('http://localhost:3010/ajax/population/new', [ "population_name"=> 'test_population_A', "member_type"=>'accessions', "accessions[]"=> ['UG120001', 'UG120002'] ]);
    $response = decode_json $mech->content;
    is($response->{'success'}, "Success! Population test_population_A created");
    my $population_A_id = $response->{'population_id'};

    $mech->post_ok('http://localhost:3010/ajax/population/new', [ "population_name"=> 'test_population_B', "member_type"=>'accessions', "accessions[]"=> ['UG120003', 'UG120004'] ]);
    $response = decode_json $mech->content;
    is($response->{'success'}, "Success! Population test_population_B created");
    my $population_B_id = $response->{'population_id'};

    # test adding cross and info
    my $crossing_trial_rs = $schema->resultset('Project::Project')->find({ name => 'test_crossingtrial' });
    my $crossing_trial_id = $crossing_trial_rs->project_id();
    my $female_plot_id = $schema->resultset('Stock::Stock')->find({ name => 'KASESE_TP2013_842' })->stock_id();
    my $male_plot_id = $schema->resultset('Stock::Stock')->find({ name => 'KASESE_TP2013_1591' })->stock_id();
    my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "cross", "stock_type")->cvterm_id();
    my $cross_combination_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "cross_combination", "stock_property")->cvterm_id();

    my $before_adding_cross = $schema->resultset("Stock::Stock")->search({ type_id => $cross_type_id })->count();
    my $before_adding_stocks = $schema->resultset("Stock::Stock")->search({})->count();
    my $before_adding_stockprop = $schema->resultset("Stock::Stockprop")->search({ type_id => $cross_combination_type_id })->count();
    my $before_adding_stockprop_all = $schema->resultset("Stock::Stockprop")->search({})->count();
    my $before_adding_relationship = $schema->resultset("Stock::StockRelationship")->search({})->count();
    my $before_adding_cross_in_experiment = $schema->resultset("NaturalDiversity::NdExperiment")->search({})->count();
    my $before_adding_cross_in_experiment_stock = $schema->resultset("NaturalDiversity::NdExperimentStock")->search({})->count();

    $mech->post_ok('http://localhost:3010/ajax/cross/add_cross', [ 'crossing_trial_id' => $crossing_trial_id, 'cross_name' => 'test_add_cross', 'cross_combination' => 'UG120001xUG120002', 'cross_type' => 'biparental', 'maternal' => 'UG120001', 'paternal' => 'UG120002', 'female_plot_plant' => $female_plot_id, 'male_plot_plant' => $male_plot_id ]);

    $response = decode_json $mech->content;
    is($response->{'success'}, '1');

    my $after_adding_cross = $schema->resultset("Stock::Stock")->search({ type_id => $cross_type_id })->count();
    my $after_adding_stocks = $schema->resultset("Stock::Stock")->search({})->count();
    my $after_adding_stockprop = $schema->resultset("Stock::Stockprop")->search({ type_id => $cross_combination_type_id })->count();
    my $after_adding_stockprop_all = $schema->resultset("Stock::Stockprop")->search({})->count();
    my $after_adding_relationship = $schema->resultset("Stock::StockRelationship")->search({})->count();
    my $after_adding_cross_in_experiment = $schema->resultset("NaturalDiversity::NdExperiment")->search({})->count();
    my $after_adding_cross_in_experiment_stock = $schema->resultset("NaturalDiversity::NdExperimentStock")->search({})->count();

    is($after_adding_cross, $before_adding_cross + 1);
    is($after_adding_stocks, $before_adding_stocks + 1);
    is($after_adding_stockprop, $before_adding_stockprop + 1);
    is($after_adding_stockprop_all, $before_adding_stockprop_all + 2);
    is($after_adding_relationship, $before_adding_relationship + 4);
    is($after_adding_cross_in_experiment, $before_adding_cross_in_experiment + 1);
    is($after_adding_cross_in_experiment_stock, $before_adding_cross_in_experiment_stock + 1);

    #test adding a cross with backcross cross type
    my $crossing_trial2_rs = $schema->resultset('Project::Project')->find({ name => 'test_crossingtrial2' });
    my $crossing_trial2_id = $crossing_trial2_rs->project_id();

    $mech->post_ok('http://localhost:3010/ajax/cross/add_cross', [ 'crossing_trial_id' => $crossing_trial2_id, 'cross_name' => 'test_backcross1', 'cross_combination' => 'test_add_crossxUG120001', 'cross_type' => 'backcross', 'maternal' => 'test_add_cross', 'paternal' => 'UG120001' ]);

    $response = decode_json $mech->content;
    is($response->{'success'}, '1');

    #test uploading crosses with backcross cross type
    my $file = $f->config->{basepath} . "/t/data/cross/backcross_upload.$extension";
    my $ua = LWP::UserAgent->new;
    $response = $ua->post(
        'http://localhost:3010/ajax/cross/upload_crosses_file',
        Content_Type => 'form-data',
        Content      => [
            "upload_crosses_file" => [
                $file,
                "backcross_upload.$extension",
                Content_Type => ($extension eq "xls") ? 'application/vnd.ms-excel' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ],
            "upload_crosses_crossing_experiment_id" => $crossing_trial2_id,
            "sgn_session_id"                        => $sgn_session_id
        ]
    );
    ok($response->is_success);
    my $message = $response->decoded_content;
    my $message_hash = decode_json $message;
    is_deeply($message_hash, { 'success' => 1 });

    # test uploading crosses with only accession info

    my $before_uploading_cross_a = $schema->resultset("Stock::Stock")->search({ type_id => $cross_type_id })->count();
    my $before_uploading_stocks_a = $schema->resultset("Stock::Stock")->search({})->count();
    my $before_uploading_relationship_a = $schema->resultset("Stock::StockRelationship")->search({})->count();

    my $file = $f->config->{basepath} . "/t/data/cross/crosses_simple_upload.$extension";
    my $ua = LWP::UserAgent->new;
    $response = $ua->post(
        'http://localhost:3010/ajax/cross/upload_crosses_file',
        Content_Type => 'form-data',
        Content      => [
            "upload_crosses_file" => [
                $file,
                "crosses_simple_upload.$extension",
                Content_Type => ($extension eq "xls") ? 'application/vnd.ms-excel' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ],
            "upload_crosses_crossing_experiment_id" => $crossing_trial2_id,
            "sgn_session_id"                        => $sgn_session_id
        ]
    );
    ok($response->is_success);
    my $message = $response->decoded_content;
    my $message_hash = decode_json $message;
    is_deeply($message_hash, { 'success' => 1 });

    my $after_uploading_cross_a = $schema->resultset("Stock::Stock")->search({ type_id => $cross_type_id })->count();
    my $after_uploading_stocks_a = $schema->resultset("Stock::Stock")->search({})->count();
    my $after_uploading_relationship_a = $schema->resultset("Stock::StockRelationship")->search({})->count();

    is($after_uploading_cross_a, $before_uploading_cross_a + 4);
    is($after_uploading_stocks_a, $before_uploading_stocks_a + 4);
    is($after_uploading_relationship_a, $before_uploading_relationship_a + 8);

    # test uploading crosses with plots
    my $female_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "female_parent", "stock_relationship")->cvterm_id();
    my $male_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "male_parent", "stock_relationship")->cvterm_id();
    my $female_plot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "female_plot_of", "stock_relationship")->cvterm_id();
    my $male_plot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "male_plot_of", "stock_relationship")->cvterm_id();

    my $before_uploading_relationship_all = $schema->resultset("Stock::StockRelationship")->search({})->count();
    my $before_uploading_relationship_female = $schema->resultset("Stock::StockRelationship")->search({ type_id => $female_type_id })->count();
    my $before_uploading_relationship_male = $schema->resultset("Stock::StockRelationship")->search({ type_id => $male_type_id })->count();
    my $before_uploading_relationship_femaleplot = $schema->resultset("Stock::StockRelationship")->search({ type_id => $female_plot_type_id })->count();
    my $before_uploading_relationship_maleplot = $schema->resultset("Stock::StockRelationship")->search({ type_id => $male_plot_type_id })->count();

    $file = $f->config->{basepath} . "/t/data/cross/crosses_plots_upload.$extension";
    $ua = LWP::UserAgent->new;
    $response = $ua->post(
        'http://localhost:3010/ajax/cross/upload_crosses_file',
        Content_Type => 'form-data',
        Content      => [
            "upload_crosses_file" => [
                $file,
                "crosses_plots_upload.$extension",
                Content_Type => ($extension eq "xls") ? 'application/vnd.ms-excel' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ],
            "upload_crosses_crossing_experiment_id" => $crossing_trial2_id,
            "sgn_session_id"                        => $sgn_session_id
        ]
    );
    ok($response->is_success);
    $message = $response->decoded_content;
    $message_hash = decode_json $message;
    is_deeply($message_hash, { 'success' => 1 });

    my $after_uploading_relationship_all = $schema->resultset("Stock::StockRelationship")->search({})->count();
    my $after_uploading_relationship_female = $schema->resultset("Stock::StockRelationship")->search({ type_id => $female_type_id })->count();
    my $after_uploading_relationship_male = $schema->resultset("Stock::StockRelationship")->search({ type_id => $male_type_id })->count();
    my $after_uploading_relationship_femaleplot = $schema->resultset("Stock::StockRelationship")->search({ type_id => $female_plot_type_id })->count();
    my $after_uploading_relationship_maleplot = $schema->resultset("Stock::StockRelationship")->search({ type_id => $male_plot_type_id })->count();

    is($after_uploading_relationship_all, $before_uploading_relationship_all + 10);
    is($after_uploading_relationship_female, $before_uploading_relationship_female + 3);
    is($after_uploading_relationship_male, $before_uploading_relationship_male + 2);
    is($after_uploading_relationship_femaleplot, $before_uploading_relationship_femaleplot + 3);
    is($after_uploading_relationship_maleplot, $before_uploading_relationship_maleplot + 2);

    #add plants for testing (a total of 38 entries)
    my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => 165 });
    $trial->create_plant_entities(2);

    # test uploading crosses with plants
    my $female_plant_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "female_parent", "stock_relationship")->cvterm_id();
    my $male_plant_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "male_parent", "stock_relationship")->cvterm_id();

    my $before_uploading_relationship_femaleplant = $schema->resultset("Stock::StockRelationship")->search({ type_id => $female_plant_type_id })->count();
    my $before_uploading_relationship_maleplant = $schema->resultset("Stock::StockRelationship")->search({ type_id => $male_plant_type_id })->count();

    $file = $f->config->{basepath} . "/t/data/cross/crosses_plants_upload.$extension";
    $ua = LWP::UserAgent->new;
    $response = $ua->post(
        'http://localhost:3010/ajax/cross/upload_crosses_file',
        Content_Type => 'form-data',
        Content      => [
            "upload_crosses_file" => [
                $file,
                "crosses_plants_upload.$extension",
                Content_Type => ($extension eq "xls") ? 'application/vnd.ms-excel' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ],
            "upload_crosses_crossing_experiment_id" => $crossing_trial2_id,
            "sgn_session_id"                        => $sgn_session_id
        ]
    );
    ok($response->is_success);
    $message = $response->decoded_content;
    $message_hash = decode_json $message;
    is_deeply($message_hash, { 'success' => 1 });

    my $after_uploading_relationship_femaleplant = $schema->resultset("Stock::StockRelationship")->search({ type_id => $female_plant_type_id })->count();
    my $after_uploading_relationship_maleplant = $schema->resultset("Stock::StockRelationship")->search({ type_id => $male_plant_type_id })->count();

    is($after_uploading_relationship_femaleplant, $before_uploading_relationship_femaleplant + 3);
    is($after_uploading_relationship_maleplant, $before_uploading_relationship_maleplant + 2);

    # test uploading crosses with simplified parent info format
    my $before_uploading_cross_simplified_info = $schema->resultset("Stock::Stock")->search({ type_id => $cross_type_id })->count();
    my $before_uploading_stocks_simplified_info = $schema->resultset("Stock::Stock")->search({})->count();
    my $before_uploading_relationship_simplified_info = $schema->resultset("Stock::StockRelationship")->search({})->count();

    my $file = $f->config->{basepath} . "/t/data/cross/crosses_simplified_parents_upload.$extension";
    my $ua = LWP::UserAgent->new;
    $response = $ua->post(
        'http://localhost:3010/ajax/cross/upload_crosses_file',
        Content_Type => 'form-data',
        Content      => [
            "upload_crosses_file" => [
                $file,
                "crosses_simplified_parents_upload.$extension",
                Content_Type => ($extension eq "xls") ? 'application/vnd.ms-excel' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ],
            "upload_crosses_crossing_experiment_id" => $crossing_trial2_id,
            "sgn_session_id"                        => $sgn_session_id
        ]
    );
    ok($response->is_success);
    my $message = $response->decoded_content;
    my $message_hash = decode_json $message;
    is_deeply($message_hash, { 'success' => 1 });

    my $after_uploading_cross_simplified_info = $schema->resultset("Stock::Stock")->search({ type_id => $cross_type_id })->count();
    my $after_uploading_stocks_simplified_info = $schema->resultset("Stock::Stock")->search({})->count();
    my $after_uploading_relationship_simplified_info = $schema->resultset("Stock::StockRelationship")->search({})->count();

    is($after_uploading_cross_simplified_info, $before_uploading_cross_simplified_info + 4);
    is($after_uploading_stocks_simplified_info, $before_uploading_stocks_simplified_info + 4);
    is($after_uploading_relationship_simplified_info, $before_uploading_relationship_simplified_info + 13);

    # test retrieving crosses in a trial
    my $test_add_cross_rs = $schema->resultset('Stock::Stock')->find({ name => 'test_add_cross' });
    my $test_add_cross_id = $test_add_cross_rs->stock_id();
    my $UG120001_id = $schema->resultset('Stock::Stock')->find({ name => 'UG120001' })->stock_id();
    my $UG120002_id = $schema->resultset('Stock::Stock')->find({ name => 'UG120002' })->stock_id();

    $mech->post_ok("http://localhost:3010/ajax/breeders/trial/$crossing_trial_id/crosses_and_details_in_trial");
    $response = decode_json $mech->content;

    is_deeply($response, { 'data' => [ {
        cross_id            => $test_add_cross_id,
        cross_name          => 'test_add_cross',
        cross_combination   => 'UG120001xUG120002',
        cross_type          => 'biparental',
        female_parent_id    => $UG120001_id,
        female_parent_name  => 'UG120001',
        female_ploidy_level => undef,
        male_parent_id      => $UG120002_id,
        male_parent_name    => 'UG120002',
        male_ploidy_level   => undef,
        female_plot_id      => $female_plot_id,
        female_plot_name    => 'KASESE_TP2013_842',
        male_plot_id        => $male_plot_id,
        male_plot_name      => 'KASESE_TP2013_1591',
        female_plant_id     => undef,
        female_plant_name   => undef,
        male_plant_id       => undef,
        male_plant_name     => undef
    } ] }, 'crosses in a trial');

    # test uploading 6 progenies with new accessions
    my $offspring_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "offspring_of", "stock_relationship")->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();

    my $before_add_progenies_stock = $schema->resultset("Stock::Stock")->search({})->count();
    my $before_add_progenies_accession = $schema->resultset("Stock::Stock")->search({ type_id => $accession_type_id })->count();
    my $before_add_progenies_relationship_all = $schema->resultset("Stock::StockRelationship")->search({})->count();
    my $before_add_progenies_offspring = $schema->resultset("Stock::StockRelationship")->search({ type_id => $offspring_type_id })->count();

    $file = $f->config->{basepath} . "/t/data/cross/update_progenies.$extension";
    $ua = LWP::UserAgent->new;
    $response = $ua->post(
        'http://localhost:3010/ajax/cross/upload_progenies',
        Content_Type => 'form-data',
        Content      => [
            progenies_new_upload_file => [
                $file,
                "update_progenies.$extension",
                Content_Type => ($extension eq "xls") ? 'application/vnd.ms-excel' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ],
            "sgn_session_id"          => $sgn_session_id
        ]
    );
    ok($response->is_success);
    $message = $response->decoded_content;
    $message_hash = decode_json $message;
    is_deeply($message_hash, { 'success' => 1 });

    my $after_add_progenies_stock = $schema->resultset("Stock::Stock")->search({})->count();
    my $after_add_progenies_accession = $schema->resultset("Stock::Stock")->search({ type_id => $accession_type_id })->count();
    my $after_add_progenies_relationship_all = $schema->resultset("Stock::StockRelationship")->search({})->count();
    my $after_add_progenies_offspring = $schema->resultset("Stock::StockRelationship")->search({ type_id => $offspring_type_id })->count();

    is($after_add_progenies_stock, $before_add_progenies_stock + 6);
    is($after_add_progenies_accession, $before_add_progenies_accession + 6);
    is($after_add_progenies_relationship_all, $before_add_progenies_relationship_all + 18);
    is($after_add_progenies_offspring, $before_add_progenies_offspring + 6);


    #validate uploading 4 progenies using existing accessions (without previously stored pedigrees)
    $file = $f->config->{basepath} . "/t/data/cross/update_progenies_existing_accessions.$extension";
    $ua = LWP::UserAgent->new;
    $response = $ua->post(
        'http://localhost:3010/ajax/cross/validate_upload_existing_progenies',
        Content_Type => 'form-data',
        Content      => [
            progenies_exist_upload_file => [
                $file,
                "update_progenies_existing_accessions.$extension",
                Content_Type => ($extension eq "xls") ? 'application/vnd.ms-excel' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ],
            "sgn_session_id"            => $sgn_session_id
        ]
    );

    ok($response->is_success);
    $message = $response->decoded_content;
    $message_hash = decode_json $message;
    my %response_hash = %$message_hash;
    my $message1 = $response_hash{'error_string'};
    my $message2 = $response_hash{'existing_pedigrees'};
    ok($message1 eq '');
    ok($message2 eq '');


    #test storing 4 progenies using existing accessions (without previously stored pedigrees)
    my $cross_name = 'test_add_cross';
    my @existing_accessions = qw(XG120015 XG120021 XG120068 XG120073);
    my $overwrite_pedigrees = 'true';
    my $adding_progenies = CXGN::Pedigree::AddProgeniesExistingAccessions->new({
        chado_schema  => $schema,
        cross_name    => $cross_name,
        progeny_names => \@existing_accessions,
    });

    ok(my $return = $adding_progenies->add_progenies_existing_accessions($overwrite_pedigrees));
    ok(!exists($return->{error}));

    my $after_add_progenies_exist_stock = $schema->resultset("Stock::Stock")->search({})->count();
    my $after_add_progenies_exist_accession = $schema->resultset("Stock::Stock")->search({ type_id => $accession_type_id })->count();
    my $after_add_progenies_exist_relationship_all = $schema->resultset("Stock::StockRelationship")->search({})->count();
    my $after_add_progenies_exist_offspring = $schema->resultset("Stock::StockRelationship")->search({ type_id => $offspring_type_id })->count();

    is($after_add_progenies_exist_stock, $after_add_progenies_stock);
    is($after_add_progenies_exist_accession, $after_add_progenies_accession);
    is($after_add_progenies_exist_relationship_all, $after_add_progenies_relationship_all + 12);
    is($after_add_progenies_exist_offspring, $after_add_progenies_offspring + 4);


    #validate uploading 2 progenies using existing accessions (accessions have previously stored pedigrees)
    #adding pedigrees for testing
    my $female_parent = Bio::GeneticRelationships::Individual->new(name => 'TestAccession1');
    my $male_parent = Bio::GeneticRelationships::Individual->new(name => 'TestAccession2');
    my $pedigree1 = Bio::GeneticRelationships::Pedigree->new(name => 'TestAccession3', cross_type => 'biparental');
    $pedigree1->set_female_parent($female_parent);
    $pedigree1->set_male_parent($male_parent);

    my $pedigree2 = Bio::GeneticRelationships::Pedigree->new(name => 'TestAccession4', cross_type => 'biparental');
    $pedigree2->set_female_parent($female_parent);
    $pedigree2->set_male_parent($male_parent);

    my @pedigrees = ($pedigree1, $pedigree2);
    my $add_pedigrees = CXGN::Pedigree::AddPedigrees->new(schema => $schema, pedigrees => \@pedigrees);
    my $pedigree_return = $add_pedigrees->add_pedigrees();

    my $after_add_pedigrees_relationship_all = $schema->resultset("Stock::StockRelationship")->search({})->count();

    $file = $f->config->{basepath} . "/t/data/cross/update_progenies_overwrite_pedigrees.$extension";
    $ua = LWP::UserAgent->new;
    $response = $ua->post(
        'http://localhost:3010/ajax/cross/validate_upload_existing_progenies',
        Content_Type => 'form-data',
        Content      => [
            progenies_exist_upload_file => [
                $file,
                "update_progenies_overwrite_pedigrees.$extension",
                Content_Type => ($extension eq "xls") ? 'application/vnd.ms-excel' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ],
            "sgn_session_id"            => $sgn_session_id
        ]
    );

    ok($response->is_success);
    $message = $response->decoded_content;
    $message_hash = decode_json $message;
    %response_hash = %$message_hash;
    my $message3 = $response_hash{'error_string'};
    my $message4 = $response_hash{'existing_pedigrees'};
    ok($message3 eq '');
    ok($message4 ne '');


    #test storing 2 progenies using existing accessions (accessions have previously stored pedigrees)
    $cross_name = 'test_add_cross';
    @existing_accessions = qw(TestAccession3 TestAccession4);
    $overwrite_pedigrees = 'true';
    $adding_progenies = CXGN::Pedigree::AddProgeniesExistingAccessions->new({
        chado_schema  => $schema,
        cross_name    => $cross_name,
        progeny_names => \@existing_accessions,
    });

    ok($return = $adding_progenies->add_progenies_existing_accessions($overwrite_pedigrees));
    ok(!exists($return->{error}));

    my $after_add_progenies_overwrite_stock = $schema->resultset("Stock::Stock")->search({})->count();
    my $after_add_progenies_overwrite_accession = $schema->resultset("Stock::Stock")->search({ type_id => $accession_type_id })->count();
    my $after_add_progenies_overwrite_relationship_all = $schema->resultset("Stock::StockRelationship")->search({})->count();
    my $after_add_progenies_overwrite_offspring = $schema->resultset("Stock::StockRelationship")->search({ type_id => $offspring_type_id })->count();

    is($after_add_progenies_overwrite_stock, $after_add_progenies_exist_stock);
    is($after_add_progenies_overwrite_accession, $after_add_progenies_exist_accession);
    is($after_add_progenies_overwrite_relationship_all, $after_add_pedigrees_relationship_all + 2);
    is($after_add_progenies_overwrite_offspring, $after_add_progenies_exist_offspring + 2);


    # test updating cross info by uploading
    my $before_updating_info_stocks = $schema->resultset("Stock::Stock")->search({})->count();
    my $before_updating_info_stockprop = $schema->resultset("Stock::Stockprop")->search({})->count();
    my $before_updating_info_relationship = $schema->resultset("Stock::StockRelationship")->search({})->count();

    $file = $f->config->{basepath} . "/t/data/cross/update_crossinfo.$extension";
    $ua = LWP::UserAgent->new;
    $response = $ua->post(
        'http://localhost:3010/ajax/cross/upload_info',
        Content_Type => 'form-data',
        Content      => [
            crossinfo_upload_file => [
                $file,
                "update_crossinfo.$extension",
                Content_Type => ($extension eq "xls") ? 'application/vnd.ms-excel' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ],
            "sgn_session_id"      => $sgn_session_id
        ]
    );
    ok($response->is_success);
    $message = $response->decoded_content;
    $message_hash = decode_json $message;
    is_deeply($message_hash, { 'success' => 1 });

    my $after_updating_info_stocks = $schema->resultset("Stock::Stock")->search({})->count();
    my $after_updating_info_stockprop = $schema->resultset("Stock::Stockprop")->search({})->count();
    my $after_updating_info_relationship = $schema->resultset("Stock::StockRelationship")->search({})->count();

    is($after_updating_info_stocks, $before_updating_info_stocks);
    is($after_updating_info_stockprop, $before_updating_info_stockprop + 3);
    is($after_updating_info_relationship, $before_updating_info_relationship);

    # test uploading additional parent info
    $file = $f->config->{basepath} . "/t/data/cross/upload_additional_info.$extension";
    $ua = LWP::UserAgent->new;
    $response = $ua->post(
        'http://localhost:3010/ajax/cross/upload_info',
        Content_Type => 'form-data',
        Content      => [
            additional_info_upload_file => [
                $file,
                "upload_additional_info.$extension",
                Content_Type => ($extension eq "xls") ? 'application/vnd.ms-excel' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ],
            "sgn_session_id"            => $sgn_session_id
        ]
    );
    ok($response->is_success);
    $message = $response->decoded_content;
    $message_hash = decode_json $message;
    is_deeply($message_hash, { 'success' => 1 });

    my $after_upload_additional_info_stocks = $schema->resultset("Stock::Stock")->search({})->count();
    my $after_upload_additional_info_stockprop = $schema->resultset("Stock::Stockprop")->search({})->count();
    my $after_upload_additional_info_relationship = $schema->resultset("Stock::StockRelationship")->search({})->count();

    # note:added 3 more rows in stockprop table after uploading field crossing activities, then 3 more rows in stockprop table after uploading parent additional info
    is($after_upload_additional_info_stocks, $before_updating_info_stocks);
    is($after_upload_additional_info_stockprop, $before_updating_info_stockprop + 6);
    is($after_upload_additional_info_relationship, $before_updating_info_relationship);

    # test retrieving crossing experimental info after updating
    $mech->post_ok("http://localhost:3010/ajax/breeders/trial/$crossing_trial_id/cross_properties_trial");
    $response = decode_json $mech->content;

    is_deeply($response, { 'data' => [
        [ qq{<a href = "/cross/$test_add_cross_id">test_add_cross</a>}, 'UG120001xUG120002', "10", "2017/02/02", "10", "50", undef, undef ]
    ] }, 'crossing experiment info');


    # test uploading family names
    my $family_name_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "family_name", "stock_type")->cvterm_id();
    my $cross_member_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross_member_of', 'stock_relationship')->cvterm_id();
    my $family_female_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'family_female_parent_of', 'stock_relationship')->cvterm_id();
    my $family_male_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'family_male_parent_of', 'stock_relationship')->cvterm_id();
    my $family_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, "family_type", "stock_property")->cvterm_id();

    my $before_family_name_stocks = $schema->resultset("Stock::Stock")->search({})->count();
    my $before_add_family_name = $schema->resultset("Stock::Stock")->search({ type_id => $family_name_type_id })->count();
    my $before_upload_family_relationship = $schema->resultset("Stock::StockRelationship")->search({})->count();
    my $before_upload_family_member = $schema->resultset("Stock::StockRelationship")->search({ type_id => $cross_member_of_cvterm_id })->count();
    my $before_upload_family_female = $schema->resultset("Stock::StockRelationship")->search({ type_id => $family_female_parent_cvterm_id })->count();
    my $before_upload_family_male = $schema->resultset("Stock::StockRelationship")->search({ type_id => $family_male_parent_cvterm_id })->count();
    my $before_upload_family_stockprop = $schema->resultset("Stock::Stockprop")->search({ type_id => $family_type_cvterm_id })->count();

    $file = $f->config->{basepath} . "/t/data/cross/family_name_upload.$extension";
    $ua = LWP::UserAgent->new;
    $response = $ua->post(
        'http://localhost:3010/ajax/cross/upload_family_names',
        Content_Type => 'form-data',
        Content      => [
            same_parents_file => [
                $file,
                "family_name_upload.$extension",
                Content_Type => ($extension eq "xls") ? 'application/vnd.ms-excel' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ],
            "sgn_session_id"  => $sgn_session_id
        ]
    );
    ok($response->is_success);
    $message = $response->decoded_content;
    $message_hash = decode_json $message;
    is_deeply($message_hash, { 'success' => 1 });

    my $after_family_name_stocks = $schema->resultset("Stock::Stock")->search({})->count();
    my $after_add_family_name = $schema->resultset("Stock::Stock")->search({ type_id => $family_name_type_id })->count();
    my $after_upload_family_relationship = $schema->resultset("Stock::StockRelationship")->search({})->count();
    my $after_upload_family_member = $schema->resultset("Stock::StockRelationship")->search({ type_id => $cross_member_of_cvterm_id })->count();
    my $after_upload_family_female = $schema->resultset("Stock::StockRelationship")->search({ type_id => $family_female_parent_cvterm_id })->count();
    my $after_upload_family_male = $schema->resultset("Stock::StockRelationship")->search({ type_id => $family_male_parent_cvterm_id })->count();
    my $after_upload_family_stockprop = $schema->resultset("Stock::Stockprop")->search({ type_id => $family_type_cvterm_id })->count();

    is($after_family_name_stocks, $before_family_name_stocks + 2);
    is($after_add_family_name, $before_add_family_name + 2);
    is($after_upload_family_relationship, $before_upload_family_relationship + 8);
    is($after_upload_family_member, $before_upload_family_member + 4);
    is($after_upload_family_female, $before_upload_family_female + 2);
    is($after_upload_family_male, $before_upload_family_male + 2);
    is($after_upload_family_stockprop, $before_upload_family_stockprop + 2);

    #test retrieving family name info
    my $family_stock_rs = $schema->resultset("Stock::Stock")->find({ name => 'family1x2', type_id => $family_name_type_id });
    my $family_stock_id = $family_stock_rs->stock_id();
    my $family_type = $schema->resultset("Stock::Stockprop")->find({ stock_id => $family_stock_id, type_id => $family_type_cvterm_id })->value();
    is($family_type, 'same_parents');
    #print STDERR "FAMILY ID =".Dumper($family_stock_id)."\n";
    $mech->post_ok('http://localhost:3010/ajax/family/members/' . $family_stock_id);
    $response = decode_json $mech->content;
    my %data = %$response;
    my $members = $data{data};
    my $number_of_members = @$members;
    is($number_of_members, 2);

    $mech->post_ok('http://localhost:3010/ajax/family/all_progenies/' . $family_stock_id);
    $response = decode_json $mech->content;
    my %data = %$response;
    my $progenies = $data{data};
    my $number_of_progenies = @$progenies;
    is($number_of_progenies, 2);

    #test adding tissue culture samples
    my $before_adding_samples_stockprop = $schema->resultset("Stock::Stockprop")->search({})->count();

    my $cross_unique_id = 'test_add_cross';
    my $sample_type = 'Embryo IDs';
    my @ids = qw(test_embryo_1 test_embryo_2 test_embryo_3 test_embryo_4);
    my $cross_add_samples = CXGN::Pedigree::AddCrossTissueSamples->new({
        chado_schema => $schema,
        cross_name   => $cross_unique_id,
        key          => $sample_type,
        value        => \@ids,
    });

    ok(my $return = $cross_add_samples->add_samples());

    my $after_adding_samples_stockprop = $schema->resultset("Stock::Stockprop")->search({})->count();
    is($after_adding_samples_stockprop, $before_adding_samples_stockprop + 1);

    #test retrieving tissue culture samples
    my $cross_id = $schema->resultset('Stock::Stock')->find({ name => 'test_add_cross' })->stock_id();
    my $cross_samples_obj = CXGN::Cross->new({ schema => $schema, cross_stock_id => $cross_id });
    my $cross_sample_data = $cross_samples_obj->get_cross_tissue_culture_samples();
    my $embryo_ids_ref = $cross_sample_data->{'Embryo IDs'};
    my $number_of_embryo_samples = @$embryo_ids_ref;
    is($number_of_embryo_samples, 4);


    #test search crosses using female parent
    $mech->post_ok('http://localhost:3010/ajax/search/crosses', [ 'female_parent' => 'TMEB419' ]);
    $response = decode_json $mech->content;
    my %data1 = %$response;
    my $result1 = $data1{data};
    my $number_of_result1 = @$result1;
    is($number_of_result1, 4);

    #test search crosses using both female and male parents
    $mech->post_ok('http://localhost:3010/ajax/search/crosses', [ 'female_parent' => 'TMEB419', 'male_parent' => 'TMEB693' ]);
    $response = decode_json $mech->content;
    my %data2 = %$response;
    my $result2 = $data2{data};
    my $number_of_result2 = @$result2;
    is($number_of_result2, 2);

    #test search crosses using male parent
    $mech->post_ok('http://localhost:3010/ajax/search/crosses', [ 'male_parent' => 'TMEB693' ]);
    $response = decode_json $mech->content;
    my %data3 = %$response;
    my $result3 = $data3{data};
    my $number_of_result3 = @$result3;
    is($number_of_result3, 2);

    #test crossing experiment download
    my @cross_properties = ("Tag Number", "Pollination Date", "Number of Bags", "Number of Flowers", "Number of Fruits", "Number of Seeds");
    my $tempfile = "/tmp/test_download_crossing_experiment.$extension";
    my $format = 'CrossingExperimentXLS';
    my $create_spreadsheet = CXGN::Trial::Download->new({
        bcs_schema                => $f->bcs_schema,
        trial_list                => [ $crossing_trial2_id ],
        filename                  => $tempfile,
        format                    => $format,
        field_crossing_data_order => \@cross_properties
    });

    $create_spreadsheet->download();
    my $contents = ReadData $tempfile;

    my $columns = $contents->[1]->{'cell'};
    my @column_array = @$columns;
    my $number_of_columns = scalar @column_array;
    print STDERR "COLUMNS =".Dumper ($columns)."\n";

    ok(scalar($number_of_columns) == 22, "check number of columns.");
    is_deeply($contents->[1]->{'cell'}->[1], [
        undef,
        'Cross Unique ID',
        'test_backcross1',
        'test_backcross2',
        'test_backcross3',
        'test_cross_upload1',
        'test_cross_upload2',
        'test_bulk_cross',
        'test_bulk_open_cross',
        'test_cross_upload3',
        'test_cross_upload4',
        'test_open_upload',
        'test_cross_upload5',
        'test_cross_upload6',
        'test_open_plant_upload',
        'test_cross_simplified_parents_1',
        'test_cross_simplified_parents_2',
        'test_cross_simplified_parents_3',
        'test_cross_simplified_parents_4'
    ], "check column 1");

    is_deeply($contents->[1]->{'cell'}->[3], [
        undef,
        'Cross Type',
        'backcross',
        'backcross',
        'backcross',
        'biparental',
        'self',
        'bulk',
        'bulk_open',
        'biparental',
        'self',
        'open',
        'biparental',
        'self',
        'open',
        'biparental',
        'biparental',
        'biparental',
        'biparental'
    ], "check column 3");

    is_deeply($contents->[1]->{'cell'}->[4], [
        undef,
        'Female Parent',
        'test_add_cross',
        'test_add_cross',
        'test_add_cross',
        'UG120001',
        'UG120001',
        'test_population_A',
        'test_population_A',
        'UG120001',
        'UG120001',
        'UG120001',
        'TMEB419',
        'TMEB419',
        'TMEB419',
        'UG120001',
        'UG120001',
        'UG120001',
        'TMEB419'
    ], "check column 4");


    # test retrieving all cross entries
    my $crosses = CXGN::Cross->new({ schema => $schema });
    my $result = $crosses->get_all_cross_entries();
    my @all_cross_entries = @$result;
    my $first_cross = $all_cross_entries[0];
    is(scalar @all_cross_entries, 18);
    is($first_cross->[1], 'test_add_cross');
    is($first_cross->[2], 'biparental');
    is($first_cross->[4], 'UG120001');
    is($first_cross->[8], 'UG120002');
    is($first_cross->[11], '2017/02/02');
    is($first_cross->[13], 8);
    is($first_cross->[15], 'test_crossingtrial');

    #test deleting cross
    my $before_deleting_crosses = $schema->resultset("Stock::Stock")->search({ type_id => $cross_type_id })->count();
    my $before_deleting_accessions = $schema->resultset("Stock::Stock")->search({ type_id => $accession_type_id })->count();
    my $before_deleting_stocks = $schema->resultset("Stock::Stock")->search({})->count();
    my $before_deleting_relationship = $schema->resultset("Stock::StockRelationship")->search({})->count();
    my $experiment_before_deleting_cross = $schema->resultset("NaturalDiversity::NdExperiment")->search({})->count();
    my $experiment_stock_before_deleting_cross = $schema->resultset("NaturalDiversity::NdExperimentStock")->search({})->count();

    # test_cross_upload1 has 2 progenies and has family name
    my $deleting_cross_id = $schema->resultset("Stock::Stock")->find({ name => 'test_cross_upload1' })->stock_id;
    $mech->post_ok('http://localhost:3010/ajax/cross/delete', [ 'cross_id' => $deleting_cross_id ]);
    $response = decode_json $mech->content;
    is($response->{'success'}, '1');

    my $after_deleting_crosses = $schema->resultset("Stock::Stock")->search({ type_id => $cross_type_id })->count();
    my $after_deleting_accessions = $schema->resultset("Stock::Stock")->search({ type_id => $accession_type_id })->count();
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

    my $crossing_experiment_id = $schema->resultset("Project::Project")->find({ name => 'test_crossingtrial_deletion' })->project_id;
    $mech->get_ok('http://localhost:3010/ajax/breeders/trial/' . $crossing_experiment_id . '/delete/crossing_experiment');
    $response = decode_json $mech->content;
    is($response->{'success'}, '1');

    my $after_deleting_empty_experiment = $schema->resultset("Project::Project")->search({})->count();

    is($after_deleting_empty_experiment, $before_deleting_empty_experiment - 1);

    # test deleting crossing experiment with crosses
    my $before_deleting_experiment = $schema->resultset("Project::Project")->search({})->count();

    my $crossing_experiment_id_2 = $schema->resultset("Project::Project")->find({ name => 'test_crossingtrial' })->project_id;
    $mech->get_ok('http://localhost:3010/ajax/breeders/trial/' . $crossing_experiment_id_2 . '/delete/crossing_experiment');
    $response = decode_json $mech->content;
    ok($response->{'error'});

    my $after_deleting_experiment = $schema->resultset("Project::Project")->search({})->count();

    is($after_deleting_experiment, $before_deleting_experiment);

    #test deleting all crosses in test_crossingtrial and test_crossingtrial2
    $mech->get_ok('http://localhost:3010/ajax/breeders/trial/' . $crossing_trial2_id . '/delete_all_crosses_in_crossingtrial');
    $mech->get_ok('http://localhost:3010/ajax/breeders/trial/' . $crossing_trial_id . '/delete_all_crosses_in_crossingtrial');

    my $after_delete_all_crosses = $schema->resultset("Stock::Stock")->search({ type_id => $cross_type_id })->count();
    my $after_delete_all_crosses_in_experiment = $schema->resultset("NaturalDiversity::NdExperiment")->search({})->count();
    my $after_delete_all_crosses_in_experiment_stock = $schema->resultset("NaturalDiversity::NdExperimentStock")->search({})->count();
    my $stocks_after_delete_all_crosses = $schema->resultset("Stock::Stock")->search({})->count();

    is($after_delete_all_crosses, $before_adding_cross + 1);                             #one cross cannot be deleted because progenies have associated data
    is($after_delete_all_crosses_in_experiment, $before_adding_cross_in_experiment + 1); #one cross cannot be deleted because progenies have associated data

    # nd_experiment_stock has 38 more rows after adding plants for testing uploading crosses with plant info
    is($after_delete_all_crosses_in_experiment_stock, $before_adding_cross_in_experiment_stock + 39);

    # stock table has 43 more rows after adding family names and plants, one cross with two new accessions cannot be deleted
    is($stocks_after_delete_all_crosses, $before_adding_stocks + 43);

    # remove added crossing trials after test so that they don't affect downstream tests
    my $project_owner_row_1 = $phenome_schema->resultset('ProjectOwner')->find({ project_id => $crossing_trial_rs->project_id() });
    $project_owner_row_1->delete();
    $crossing_trial_rs->delete();

    my $project_owner_row_2 = $phenome_schema->resultset('ProjectOwner')->find({ project_id => $crossing_trial2_rs->project_id() });
    $project_owner_row_2->delete();
    $crossing_trial2_rs->delete();

    $f->clean_up_db();
}

done_testing();
