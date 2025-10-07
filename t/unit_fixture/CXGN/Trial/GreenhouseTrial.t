
use strict;

use Test::More;
use lib 't/lib';
use SGN::Test::Fixture;
use JSON::Any;
use Data::Dumper;
use Test::WWW::Mechanize;
use JSON;
use LWP::UserAgent;

my $fix = SGN::Test::Fixture->new();

is(ref($fix->config()), "HASH", 'hashref check');

BEGIN {use_ok('CXGN::Trial::TrialCreate');}
BEGIN {use_ok('CXGN::Trial::TrialLayout');}
BEGIN {use_ok('CXGN::Trial::TrialDesign');}
BEGIN {use_ok('CXGN::Trial::TrialLookup');}
BEGIN {use_ok('CXGN::Trial::Download');}
BEGIN {use_ok('CXGN::Fieldbook::DownloadTrial');}
BEGIN {use_ok('CXGN::Trial::TrialLayoutDownload');}
BEGIN {use_ok('CXGN::Trial');}

ok(my $schema = $fix->bcs_schema);
ok(my $phenome_schema = $fix->phenome_schema);
ok(my $metadata_schema = $fix->metadata_schema);
ok(my $dbh = $fix->dbh);

my $json = JSON->new->allow_nonref;

# create accession names for greenhouse trial
my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();

my @greenhouse_accessions;
for (my $i = 1; $i <= 8; $i++) {
    push(@greenhouse_accessions, "accession_for_greenhouse" . $i);
}

ok(my $organism = $schema->resultset("Organism::Organism")
    ->find_or_create({
    genus   => 'Test_genus',
    species => 'Test_genus test_species',
},));

foreach my $accession_name (@greenhouse_accessions) {
    my $accessions = $schema->resultset('Stock::Stock')->create({
        organism_id => $organism->organism_id,
        name        => $accession_name,
        uniquename  => $accession_name,
        type_id     => $accession_type_id,
    });
};

my @greenhouse_accessions_1 = ('accession_for_greenhouse1','accession_for_greenhouse2','accession_for_greenhouse3','accession_for_greenhouse4','accession_for_greenhouse5','accession_for_greenhouse6');
my @greenhouse_accessions_2 = ('accession_for_greenhouse7','accession_for_greenhouse8');

my @greenhouse_num_plants_1 = ('1','1','1','1','1','1');
my @greenhouse_num_plants_2 = ('1','1');

ok(my $greenhouse_trial = CXGN::Trial::TrialDesign->new(), "create trial design object");
ok($greenhouse_trial->set_trial_name("greenhouse_1"), "set trial name");
ok($greenhouse_trial->set_stock_list(\@greenhouse_accessions_1), "set stock list");
ok($greenhouse_trial->set_plot_start_number(1), "set plot start number");
ok($greenhouse_trial->set_plot_number_increment(1), "set plot increment");
ok($greenhouse_trial->set_number_of_blocks(1), "set block number");
ok($greenhouse_trial->set_design_type("greenhouse"), "set design type");
ok($greenhouse_trial->set_greenhouse_num_plants(\@greenhouse_num_plants_1), "set number of plants");

ok($greenhouse_trial->calculate_design(), "calculate design");
ok(my $greenhouse_design = $greenhouse_trial->get_design(), "retrieve design");

ok(my $greenhouse_trial_create = CXGN::Trial::TrialCreate->new({
    chado_schema      => $schema,
    dbh               => $dbh,
    owner_id          => 41,
    design            => $greenhouse_design,
    program           => "test",
    trial_year        => "2025",
    trial_description => "test description",
    trial_location    => "test_location",
    trial_name        => "greenhouse_1",
    trial_type        => '',
    design_type       => "greenhouse",
    operator          => "janedoe",
    trial_stock_type  => "accession"
}), "create trial object");

my $greenhouse_trial_save = $greenhouse_trial_create->save_trial();
ok($greenhouse_trial_save->{'trial_id'}, "save trial");


ok(my $greenhouse_trial_lookup = CXGN::Trial::TrialLookup->new({
    schema     => $schema,
    trial_name => "greenhouse_1",
}), "create trial lookup object");
ok(my $greenhouse_trial = $greenhouse_trial_lookup->get_trial());
ok(my $greenhouse_trial_id = $greenhouse_trial->project_id());

my $greenhouse_trial_layout;
ok($greenhouse_trial_layout = CXGN::Trial::TrialLayout->new({
    schema          => $schema,
    trial_id        => $greenhouse_trial_id,
    experiment_type => 'field_layout'
}), "create trial layout object for greenhouse trial");

my $greenhouse_trial_design = $greenhouse_trial_layout->get_design();
my @plot_nums;
my @accessions;
my @block_nums;
my @plot_names;
my @plant_names;

foreach my $plot_num (keys %$greenhouse_trial_design) {
    push @plot_nums, $plot_num;
    push @accessions, $greenhouse_trial_design->{$plot_num}->{'accession_name'};
    push @block_nums, $greenhouse_trial_design->{$plot_num}->{'block_number'};
    push @plot_names, $greenhouse_trial_design->{$plot_num}->{'plot_name'};
    my $plant_name = $greenhouse_trial_design->{$plot_num}->{'plant_names'};
    push @plant_names, @$plant_name;
}

@plot_nums = sort @plot_nums;
@accessions = sort @accessions;
@plot_names = sort @plot_names;
@plant_names = sort @plant_names;

is_deeply(\@plot_nums, [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
], "check plot numbers");

is_deeply(\@accessions, [
    'accession_for_greenhouse1',
    'accession_for_greenhouse2',
    'accession_for_greenhouse3',
    'accession_for_greenhouse4',
    'accession_for_greenhouse5',
    'accession_for_greenhouse6',
], "check accessions");

is_deeply(\@plot_names, [
    'greenhouse_1_accession_for_greenhouse1_1',
    'greenhouse_1_accession_for_greenhouse2_2',
    'greenhouse_1_accession_for_greenhouse3_3',
    'greenhouse_1_accession_for_greenhouse4_4',
    'greenhouse_1_accession_for_greenhouse5_5',
    'greenhouse_1_accession_for_greenhouse6_6'
], "check plot names");

is_deeply(\@plant_names, [
    'greenhouse_1_accession_for_greenhouse1_1_plant_1',
    'greenhouse_1_accession_for_greenhouse2_2_plant_1',
    'greenhouse_1_accession_for_greenhouse3_3_plant_1',
    'greenhouse_1_accession_for_greenhouse4_4_plant_1',
    'greenhouse_1_accession_for_greenhouse5_5_plant_1',
    'greenhouse_1_accession_for_greenhouse6_6_plant_1'
], "check plant names");

is_deeply(\@block_nums, [
    '1',
    '1',
    '1',
    '1',
    '1',
    '1',
], "check greenhouse block numbers");

#add additional accessions
my $mech = Test::WWW::Mechanize->new;
$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username" => "janedoe", "password" => "secretpw", "grant_type" => "password" ]);
my $response = decode_json $mech->content;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};
print STDERR $sgn_session_id . "\n";

$mech->post_ok('http://localhost:3010/ajax/breeders/trial/'.$greenhouse_trial_id.'/add_additional_stocks_for_greenhouse', [ 'new_stocks'=>$json->encode(\@greenhouse_accessions_2), 'number_of_plants'=>$json->encode(\@greenhouse_num_plants_2) ]);
my $response = decode_json $mech->content;

is($response->{'success'}, '1');

#checking greenhouse design after adding additional accessions
my $greenhouse_trial_layout_2;
ok($greenhouse_trial_layout_2 = CXGN::Trial::TrialLayout->new({
    schema          => $schema,
    trial_id        => $greenhouse_trial_id,
    experiment_type => 'field_layout'
}));

my $greenhouse_trial_design_2 = $greenhouse_trial_layout_2->get_design();
my @plot_nums_2;
my @accessions_2;
my @plot_names_2;
my @plant_names_2;

foreach my $plot_num_2 (keys %$greenhouse_trial_design_2) {
    push @plot_nums_2, $plot_num_2;
    push @accessions_2, $greenhouse_trial_design_2->{$plot_num_2}->{'accession_name'};
    push @plot_names_2, $greenhouse_trial_design_2->{$plot_num_2}->{'plot_name'};
    my $plant_name_2 = $greenhouse_trial_design_2->{$plot_num_2}->{'plant_names'};
    push @plant_names_2, @$plant_name_2;
}

@plot_nums_2 = sort @plot_nums_2;
@accessions_2 = sort @accessions_2;
@plot_names_2 = sort @plot_names_2;
@plant_names_2 = sort @plant_names_2;

is_deeply(\@plot_nums_2, [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8'
], "check plot numbers");

is_deeply(\@accessions_2, [
    'accession_for_greenhouse1',
    'accession_for_greenhouse2',
    'accession_for_greenhouse3',
    'accession_for_greenhouse4',
    'accession_for_greenhouse5',
    'accession_for_greenhouse6',
    'accession_for_greenhouse7',
    'accession_for_greenhouse8',
], "check accessions");

is_deeply(\@plot_names_2, [
    'greenhouse_1_accession_for_greenhouse1_1',
    'greenhouse_1_accession_for_greenhouse2_2',
    'greenhouse_1_accession_for_greenhouse3_3',
    'greenhouse_1_accession_for_greenhouse4_4',
    'greenhouse_1_accession_for_greenhouse5_5',
    'greenhouse_1_accession_for_greenhouse6_6',
    'greenhouse_1_accession_for_greenhouse7_7',
    'greenhouse_1_accession_for_greenhouse8_8'
], "check plot names");

is_deeply(\@plant_names_2, [
    'greenhouse_1_accession_for_greenhouse1_1_plant_1',
    'greenhouse_1_accession_for_greenhouse2_2_plant_1',
    'greenhouse_1_accession_for_greenhouse3_3_plant_1',
    'greenhouse_1_accession_for_greenhouse4_4_plant_1',
    'greenhouse_1_accession_for_greenhouse5_5_plant_1',
    'greenhouse_1_accession_for_greenhouse6_6_plant_1',
    'greenhouse_1_accession_for_greenhouse7_7_plant_1',
    'greenhouse_1_accession_for_greenhouse8_8_plant_1'
], "check plant names");


$fix->clean_up_db();

done_testing();
