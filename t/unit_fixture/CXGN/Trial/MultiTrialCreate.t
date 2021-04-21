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
ok(my $chado_schema = $fix->bcs_schema);
ok(my $phenome_schema = $fix->phenome_schema);
ok(my $dbh = $fix->dbh);

# create locations for the trial
my @multi_location;
for (my $i = 1; $i <= 2; $i++) {
  ok(my $trial_location = "test_location_for_multi_trial".$i);
  push @multi_location, $trial_location;
}

foreach my $multi_trial_loc (@multi_location) {
  ok(my $location = $chado_schema->resultset('NaturalDiversity::NdGeolocation')
     ->new({
      description => $multi_trial_loc,
  	 }));
  ok($location->insert());
};

# create stocks for the trial
ok(my $accession_cvterm = $chado_schema->resultset("Cv::Cvterm")
   ->create_with({
       name   => 'accession',
       cv     => 'stock_type',

		 }));

my @stock_names;
for (my $i = 1; $i <= 10; $i++) {
    push(@stock_names, "test_stock_for_multi_trial".$i);
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

#create multilocation trial
my @multi_design;
my $design_index = 0;
foreach my $trial_location (@multi_location) {
  ok(my $trial_design = CXGN::Trial::TrialDesign->new(), "create trial design object");
  ok($trial_design->set_trial_name("test_multi_trial_name".$trial_location), "set trial name");
  ok($trial_design->set_stock_list(\@stock_names), "set stock list");
  ok($trial_design->set_plot_start_number(1), "set plot start number");
  ok($trial_design->set_plot_number_increment(1), "set plot increment");
  ok($trial_design->set_number_of_blocks(2), "set block number");
  ok($trial_design->set_design_type("RCBD"), "set design type");
  ok($trial_design->calculate_design(), "calculate design");
  ok(my $design = $trial_design->get_design(), "retrieve design");
  push @multi_design, $design;

    ok(my $trial_create = CXGN::Trial::TrialCreate->new({
        chado_schema => $chado_schema,
        dbh => $dbh,
        owner_id => 41,
        design => $multi_design[$design_index],
        program => "test",
        trial_year => "2016",
        trial_description => "multilocation test description",
        #trial_location => "test_location_for_trial",
        trial_location => $trial_location,
        trial_name => "test_multi_trial_name".$trial_location,
        design_type => "RCBD",
        operator => "janedoe"
    						    }), "create trial object");

    my $save = $trial_create->save_trial();
    ok($save->{'trial_id'}, "save trial");

$design_index++;

ok(my $trial_lookup = CXGN::Trial::TrialLookup->new({
    schema => $chado_schema,
    trial_name => "test_multi_trial_name".$trial_location,
						    }), "create trial lookup object");
ok(my $trial = $trial_lookup->get_trial());
ok(my $trial_id = $trial->project_id());
ok(my $trial_layout = CXGN::Trial::TrialLayout->new({
    schema => $chado_schema,
    trial_id => $trial_id,
    experiment_type => 'field_layout'
						    }), "create trial layout object");
print STDERR Dumper($trial_layout->get_design());

ok(my $accession_names = $trial_layout->get_accession_names(), "retrieve accession names2");

my %stocks = map { $_ => 1 } @stock_names;

foreach my $acc (@$accession_names) {
    ok(exists($stocks{$acc->{accession_name}}), "check accession names $acc->{accession_name}");
}

}

done_testing();
