
use strict;

use Test::More;
use lib 't/lib';
use SGN::Test::Fixture;
use JSON::Any;
use Data::Dumper;

my $fix = SGN::Test::Fixture->new();

is(ref($fix->config()), "HASH", 'hashref check');

BEGIN {use_ok('CXGN::Trial::TrialCreate');}
BEGIN {use_ok('CXGN::Trial::TrialLayout');}
BEGIN {use_ok('CXGN::Trial::TrialDesign');}
BEGIN {use_ok('CXGN::Trial::TrialLayoutDownload');}
BEGIN {use_ok('CXGN::Trial::TrialLookup');}
ok(my $schema = $fix->bcs_schema);
ok(my $phenome_schema = $fix->phenome_schema);
ok(my $dbh = $fix->dbh);

# create crosses and family_names for the trial
my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "cross", "stock_type")->cvterm_id();
my $family_name_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "family_name", "stock_type")->cvterm_id();

my @cross_ids;
for (my $i = 1; $i <= 5; $i++) {
    push(@cross_ids, "cross_for_trial".$i);
}

my @family_names;
for (my $i = 1; $i <= 5; $i++) {
    push(@family_names, "family_name_for_trial".$i);
}

ok(my $organism = $schema->resultset("Organism::Organism")
    ->find_or_create( {
       genus => 'Test_genus',
       species => 'Test_genus test_species',
	}, ));

foreach my $cross_id (@cross_ids) {
    my $cross_for_trial = $schema->resultset('Stock::Stock')
	->create({
	    organism_id => $organism->organism_id,
	    name       => $cross_id,
	    uniquename => $cross_id,
	    type_id     => $cross_type_id,
    });
};

foreach my $family_name (@family_names) {
    my $family_name_for_trial = $schema->resultset('Stock::Stock')
	->create({
	    organism_id => $organism->organism_id,
	    name       => $family_name,
	    uniquename => $family_name,
	    type_id     => $family_name_type_id,
	});
};

# create trial with cross stock type
ok(my $trial_design = CXGN::Trial::TrialDesign->new(), "create trial design object");
ok($trial_design->set_trial_name("cross_to_trial1"), "set trial name");
ok($trial_design->set_stock_list(\@cross_ids), "set stock list");
ok($trial_design->set_plot_start_number(1), "set plot start number");
ok($trial_design->set_plot_number_increment(1), "set plot increment");
ok($trial_design->set_number_of_blocks(2), "set block number");
ok($trial_design->set_design_type("RCBD"), "set design type");
ok($trial_design->calculate_design(), "calculate design");
ok(my $design = $trial_design->get_design(), "retrieve design");

my $preliminary_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'Preliminary Yield Trial', 'project_type')->cvterm_id();

ok(my $trial_create = CXGN::Trial::TrialCreate->new({
    chado_schema => $schema,
    dbh => $dbh,
    user_name => "janedoe", #not implemented
    design => $design,
    program => "test",
    trial_year => "2020",
    trial_description => "test description",
    trial_location => "test_location",
    trial_name => "cross_to_trial1",
    trial_type=>$preliminary_trial_cvterm_id,
    design_type => "RCBD",
    operator => "janedoe",
    trial_stock_type => "cross"
						    }), "create trial object");

my $save = $trial_create->save_trial();
ok($save->{'trial_id'}, "save trial");

ok(my $trial_lookup = CXGN::Trial::TrialLookup->new({
    schema => $schema,
    trial_name => "cross_to_trial1",
						    }), "create trial lookup object");
ok(my $trial = $trial_lookup->get_trial());
ok(my $trial_id = $trial->project_id());
ok(my $trial_layout = CXGN::Trial::TrialLayout->new({
    schema => $schema,
    trial_id => $trial_id,
    experiment_type => 'field_layout'
						    }), "create trial layout object");

ok(my $crosses = $trial_layout->get_accession_names(), "retrieve cross unique ids");
my $trial_type = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $trial_id });
my $trial_stock_type = $trial_type->get_trial_stock_type();
is_deeply($trial_stock_type, 'cross');
print STDERR "CROSS STOCK TYPE =".Dumper($trial_stock_type)."\n";

# create trial with family_name stock type
ok(my $trial_design = CXGN::Trial::TrialDesign->new(), "create trial design object");
ok($trial_design->set_trial_name("family_name_to_trial1"), "set trial name");
ok($trial_design->set_stock_list(\@family_names), "set stock list");
ok($trial_design->set_plot_start_number(1), "set plot start number");
ok($trial_design->set_plot_number_increment(1), "set plot increment");
ok($trial_design->set_number_of_reps(2), "set rep number");
ok($trial_design->set_design_type("CRD"), "set design type");
ok($trial_design->calculate_design(), "calculate design");
ok(my $design = $trial_design->get_design(), "retrieve design");

ok(my $trial_create = CXGN::Trial::TrialCreate->new({
    chado_schema => $schema,
    dbh => $dbh,
    user_name => "janedoe", #not implemented
    design => $design,
    program => "test",
    trial_year => "2020",
    trial_description => "test description",
    trial_location => "test_location",
    trial_name => "family_name_to_trial1",
    trial_type=>$preliminary_trial_cvterm_id,
    design_type => "CRD",
    operator => "janedoe",
    trial_stock_type => "family_name"
						    }), "create trial object");

my $save = $trial_create->save_trial();
ok($save->{'trial_id'}, "save trial");
ok(my $trial_lookup = CXGN::Trial::TrialLookup->new({
    schema => $schema,
    trial_name => "family_name_to_trial1",
						    }), "create trial lookup object");
ok(my $trial = $trial_lookup->get_trial());
ok(my $trial_id = $trial->project_id());
ok(my $trial_layout = CXGN::Trial::TrialLayout->new({
    schema => $schema,
    trial_id => $trial_id,
    experiment_type => 'field_layout'
						    }), "create trial layout object");

ok(my $family_names = $trial_layout->get_accession_names(), "retrieve family names");
my $trial_type = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $trial_id });
my $trial_stock_type = $trial_type->get_trial_stock_type();
is_deeply($trial_stock_type, 'family_name');
print STDERR "FAMILY STOCK TYPE =".Dumper($trial_stock_type)."\n";
done_testing();
