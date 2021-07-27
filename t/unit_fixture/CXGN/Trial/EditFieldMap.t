use strict;

use Test::More;
use lib 't/lib';
use SGN::Test::Fixture;
use Data::Dumper;

my $fix = SGN::Test::Fixture->new();

is(ref($fix->config()), "HASH", 'hashref check');

BEGIN {use_ok('CXGN::Trial::TrialCreate');}
BEGIN {use_ok('CXGN::Trial::TrialLayout');}
BEGIN {use_ok('CXGN::Trial::TrialDesign');}
BEGIN {use_ok('CXGN::Trial::TrialLookup');}
BEGIN {use_ok('CXGN::Trial::FieldMap');}
BEGIN {use_ok('CXGN::Trial');}
ok(my $chado_schema = $fix->bcs_schema);
ok(my $phenome_schema = $fix->phenome_schema);
ok(my $dbh = $fix->dbh);

# create a location for the trial
ok(my $trial_location = "test_location_for_trial");
ok(my $location = $chado_schema->resultset('NaturalDiversity::NdGeolocation')
   ->new({
    description => $trial_location,
	 }));
ok($location->insert());

# create stocks for the trial
ok(my $accession_cvterm = $chado_schema->resultset("Cv::Cvterm")
   ->create_with({
       name   => 'accession',
       cv     => 'stock_type',

		 }));
my @stock_names;
for (my $i = 1; $i <= 10; $i++) {
    push(@stock_names, "test_stock_for_trial".$i);
}

# create a location for the trial
ok(my $trial_location = "test_location_for_trial");
ok(my $location = $chado_schema->resultset('NaturalDiversity::NdGeolocation')
   ->new({
    description => $trial_location,
	 }));
ok($location->insert());

# create stocks for the trial
ok(my $accession_cvterm = $chado_schema->resultset("Cv::Cvterm")
   ->create_with({
       name   => 'accession',
       cv     => 'stock_type',

		 }));
my @stock_names;
for (my $i = 1; $i <= 10; $i++) {
    push(@stock_names, "test_stock_for_fieldmap_trial".$i);
}

ok(my $organism = $chado_schema->resultset("Organism::Organism")
   ->find_or_create( {
       genus => 'Test_genus',
       species => 'Test_genus test_species',
		     }, ));

# create some test stocks
foreach my $stock_name (@stock_names) {
    my $accession_stock = $chado_schema->resultset('Stock::Stock')
	->create({
	    organism_id => $organism->organism_id,
	    name       => $stock_name,
	    uniquename => $stock_name,
	    type_id     => $accession_cvterm->cvterm_id,
		 });
};

ok(my $trial_design = CXGN::Trial::TrialDesign->new(), "create trial design object");
ok($trial_design->set_trial_name("new_test_trial_fieldmap_name"), "set trial name");
ok($trial_design->set_stock_list(\@stock_names), "set stock list");
ok($trial_design->set_plot_start_number(1), "set plot start number");
ok($trial_design->set_plot_number_increment(1), "set plot increment");
ok($trial_design->set_number_of_blocks(2), "set block number");
ok($trial_design->set_design_type("RCBD"), "set design type");
ok($trial_design->set_plot_layout_format("serpentine"), "set plot layout format");
ok($trial_design->calculate_design(), "calculate design");
ok(my $design = $trial_design->get_design(), "retrieve design");

ok(my $trial_create = CXGN::Trial::TrialCreate->new({
    chado_schema => $chado_schema,
    dbh => $dbh,
    owner_id => 41,
    design => $design,
    program => "test",
    trial_year => "2015",
    trial_description => "test description",
    trial_location => "test_location_for_trial",
    trial_name => "new_test_trial_fieldmap_name",
    design_type => "RCBD",
    operator => "janedoe"
						    }), "create trial object");

my $save = $trial_create->save_trial();
ok($save->{'trial_id'}, "save trial");

ok(my $trial_lookup = CXGN::Trial::TrialLookup->new({
    schema => $chado_schema,
    trial_name => "new_test_trial_fieldmap_name",
						    }), "create trial lookup object");
ok(my $trial = $trial_lookup->get_trial());
ok(my $trial_id = $trial->project_id());
ok(my $trial_layout = CXGN::Trial::TrialLayout->new({
    schema => $chado_schema,
    trial_id => $trial_id,
    experiment_type => 'field_layout'
						    }), "create trial layout object");

#replace trial accession
ok(my $old_accession = "test_stock_for_fieldmap_trial1");
ok(my $new_accession = "test_stock_for_fieldmap_trial2");
ok(my $stock_id = $chado_schema->resultset('Stock::Stock')->find({'uniquename' => $old_accession})->stock_id(), "get stock id");

my $replace_accession_fieldmap = CXGN::Trial::FieldMap->new({
  bcs_schema => $chado_schema,
  trial_id => $trial_id,
  old_accession_id => $stock_id,
  new_accession => $new_accession,
});
ok(!$replace_accession_fieldmap->replace_trial_stock_fieldMap(), "replace trial accession");


my $trial = CXGN::Trial->new( {
  bcs_schema => $chado_schema,
  trial_id => $trial_id
 });

#replace plot accession
ok(my @data = $trial->get_plots(), "get plots");
ok(my $old_plot_id = $data[0]->[0][0]);
print STDERR Dumper($old_plot_id);

my $replace_plot_accession_fieldmap = CXGN::Trial::FieldMap->new({
  bcs_schema => $chado_schema,
  trial_id => $trial_id,
  new_accession => $new_accession,
  old_accession => $old_accession,
  old_plot_id => $old_plot_id,

});
ok(!$replace_plot_accession_fieldmap->replace_plot_accession_fieldMap(), "replace plot accession");

# accessions substitution
ok(my $plot_1_id = $data[0]->[0][0]);
ok(my $plot_2_id = $data[0]->[1][0]);
ok(my $accession_1 = "test_stock_for_fieldmap_trial1");
ok(my $accession_2 = "test_stock_for_fieldmap_trial2");

my $fieldmap = CXGN::Trial::FieldMap->new({
  bcs_schema => $chado_schema,
  trial_id => $trial_id,
  first_plot_selected => $plot_1_id,
  second_plot_selected => $plot_2_id,
  first_accession_selected => $accession_1,
  second_accession_selected => $accession_2,
});

ok(!$fieldmap->substitute_accession_fieldmap(), "substituting plots accessions");

done_testing();
