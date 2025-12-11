use strict;

use Test::More;
use lib 't/lib';
use SGN::Test::Fixture;
use JSON::Any;
use Data::Dumper;
use Test::WWW::Mechanize;
use CXGN::Cross;
use JSON;
use LWP::UserAgent;
use CXGN::Stock::AddDerivedAccession;

my $f = SGN::Test::Fixture->new();
my $mech = Test::WWW::Mechanize->new;

is(ref($f->config()), "HASH", 'hashref check');

BEGIN {use_ok('CXGN::Trial::TrialCreate');}
BEGIN {use_ok('CXGN::Trial::TrialLayout');}
BEGIN {use_ok('CXGN::Trial::TrialDesign');}
BEGIN {use_ok('CXGN::Trial::TrialLookup');}
BEGIN {use_ok('CXGN::Trial::Download');}
BEGIN {use_ok('CXGN::Fieldbook::DownloadTrial');}
BEGIN {use_ok('CXGN::Trial::TrialLayoutDownload');}
BEGIN {use_ok('CXGN::Trial');}

ok(my $schema = $f->bcs_schema);
ok(my $phenome_schema = $f->phenome_schema);
ok(my $metadata_schema = $f->metadata_schema);
ok(my $dbh = $f->dbh);

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username" => "janedoe", "password" => "secretpw", "grant_type" => "password" ]);
my $response = decode_json $mech->content;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};
print STDERR $sgn_session_id . "\n";

# create crosses for using in trial
$mech->post_ok('http://localhost:3010/ajax/cross/add_crossingtrial', [ 'crossingtrial_name' => 'crossing_experiment_1', 'crossingtrial_program_id' => 134, 'crossingtrial_location' => 'test_location', 'year' => '2025', 'project_description' => 'test description' ]);
$response = decode_json $mech->content;
is($response->{'success'}, '1');

my $crossing_experiment_rs = $schema->resultset('Project::Project')->find({ name => 'crossing_experiment_1' });
my $crossing_experiment_id = $crossing_experiment_rs->project_id();

$mech->post_ok('http://localhost:3010/ajax/cross/add_cross', [ 'crossing_trial_id' => $crossing_experiment_id, 'cross_name' => 'cross1', 'cross_combination' => 'UG120001xUG120002', 'cross_type' => 'biparental', 'maternal' => 'UG120001', 'paternal' => 'UG120002' ]);
$response = decode_json $mech->content;
is($response->{'success'}, '1');

$mech->post_ok('http://localhost:3010/ajax/cross/add_cross', [ 'crossing_trial_id' => $crossing_experiment_id, 'cross_name' => 'cross2', 'cross_combination' => 'UG120003xUG120004', 'cross_type' => 'biparental', 'maternal' => 'UG120003', 'paternal' => 'UG120004' ]);
$response = decode_json $mech->content;
is($response->{'success'}, '1');

$mech->post_ok('http://localhost:3010/ajax/cross/add_cross', [ 'crossing_trial_id' => $crossing_experiment_id, 'cross_name' => 'cross3', 'cross_combination' => 'UG120005xUG120006', 'cross_type' => 'biparental', 'maternal' => 'UG120005', 'paternal' => 'UG120006' ]);
$response = decode_json $mech->content;
is($response->{'success'}, '1');

#creat a trial
my @greenhouse_stocks = ('cross1','cross2','cross3','UG120007');
my @greenhouse_num_plants = ('1','1','1','1');

ok(my $greenhouse_trial = CXGN::Trial::TrialDesign->new(), "create trial design object");
ok($greenhouse_trial->set_trial_name("cross_greenhouse"), "set trial name");
ok($greenhouse_trial->set_stock_list(\@greenhouse_stocks), "set stock list");
ok($greenhouse_trial->set_plot_start_number(1), "set plot start number");
ok($greenhouse_trial->set_plot_number_increment(1), "set plot increment");
ok($greenhouse_trial->set_number_of_blocks(1), "set block number");
ok($greenhouse_trial->set_design_type("greenhouse"), "set design type");
ok($greenhouse_trial->set_greenhouse_num_plants(\@greenhouse_num_plants), "set number of plants");

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
    trial_name        => "cross_greenhouse",
    trial_type        => '',
    design_type       => "greenhouse",
    operator          => "janedoe",
    trial_stock_type  => "cross"
}), "create trial object");

my $greenhouse_trial_save = $greenhouse_trial_create->save_trial();
ok($greenhouse_trial_save->{'trial_id'}, "save trial");


ok(my $greenhouse_trial_lookup = CXGN::Trial::TrialLookup->new({
    schema     => $schema,
    trial_name => "cross_greenhouse",
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
my @stocks;
my @all_plant_names;

foreach my $plot_num (keys %$greenhouse_trial_design) {
    push @stocks, $greenhouse_trial_design->{$plot_num}->{'accession_name'};
    my $plant_names = $greenhouse_trial_design->{$plot_num}->{'plant_names'};
    push @all_plant_names, @$plant_names;
}

@stocks = sort @stocks;
@all_plant_names = sort @all_plant_names;

print STDERR "STOCKS =".Dumper(\@stocks)."\n";
print STDERR "PLANT NAMES =".Dumper(\@all_plant_names)."\n";

is_deeply(\@stocks, [
    'UG120007',
    'cross1',
    'cross2',
    'cross3',
], "check stocks");

is_deeply(\@all_plant_names, [
    'cross_greenhouse_UG120007_4_plant_1',
    'cross_greenhouse_cross1_1_plant_1',
    'cross_greenhouse_cross2_2_plant_1',
    'cross_greenhouse_cross3_3_plant_1'
], "check plant names");

my $cross1_id = $schema->resultset("Stock::Stock")->find({'uniquename' => 'cross1' })->stock_id;
my $UG120007_id = $schema->resultset("Stock::Stock")->find({'uniquename' => 'UG120007' })->stock_id;
my $plant_from_cross1_id = $schema->resultset("Stock::Stock")->find({'uniquename' => 'cross_greenhouse_cross1_1_plant_1' })->stock_id;
my $plant_from_UG120007_id = $schema->resultset("Stock::Stock")->find({'uniquename' => 'cross_greenhouse_UG120007_4_plant_1' })->stock_id;

#test adding derived accession from a plant with cross origin
my $add_derived_accession_1 = CXGN::Stock::AddDerivedAccession->new({
    chado_schema => $schema,
    phenome_schema => $phenome_schema,
    dbh => $dbh,
    derived_from_stock_id => $plant_from_cross1_id,
    derived_accession_name => 'derived_accession_1',
    description => 'from plant with cross origin',
    owner_id => 41,
});

ok($add_derived_accession_1->add_derived_accession());

my $derived_accession_1_id = $schema->resultset("Stock::Stock")->find({'uniquename' => 'derived_accession_1' })->stock_id;
print STDERR "DERIVED ACCESSION 1 ID =".Dumper($derived_accession_1_id)."\n";

#test adding derived accession from a plant with accession origin
my $add_derived_accession_2 = CXGN::Stock::AddDerivedAccession->new({
    chado_schema => $schema,
    phenome_schema => $phenome_schema,
    dbh => $dbh,
    derived_from_stock_id => $plant_from_UG120007_id,
    derived_accession_name => 'derived_accession_2',
    description => 'from plant with accession origin',
    owner_id => 41,
});

ok($add_derived_accession_2->add_derived_accession());

my $derived_accession_2_id = $schema->resultset("Stock::Stock")->find({'uniquename' => 'derived_accession_2' })->stock_id;
print STDERR "DERIVED ACCESSION 2 ID =".Dumper($derived_accession_2_id)."\n";


$f->clean_up_db();
done_testing();
