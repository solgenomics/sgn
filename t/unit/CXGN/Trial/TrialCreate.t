
use strict;

use Test::More qw | no_plan |;

use lib 't/lib';

use SGN::Test::Fixture;

my $fix = SGN::Test::Fixture->new();

is(ref($fix->config()), "HASH", 'hashref check');

#my $q = "SELECT count(*) FROM stock";
#my $h = $fix->dbh()->prepare($q);
#$h->execute();
#my $stock_count = $h->fetchrow_array();
#ok($stock_count, "dbh test");

#my $rs = $fix->bcs_schema->resultset("Stock::Stock")->search( {} );
#ok($rs->count(), "bcs schema test");

BEGIN {use_ok('CXGN::Trial::TrialCreate');}
BEGIN {use_ok('CXGN::Trial::TrialLayout');}
BEGIN {use_ok('CXGN::Trial::TrialDesign');}
ok(my $chado_schema = $fix->bcs_schema);
ok(my $phenome_schema = $fix->phenome_schema);
ok(my $dbh = $fix->dbh);

# create a location for the trial
ok(my $trial_location = "test_location_for_trial");
ok(my $new_row = $chado_schema->resultset('NaturalDiversity::NdGeolocation')
   ->new({
    description => $trial_location,
	 }));
ok($new_row->insert());

# create stocks for the trial
ok(my $accession_cvterm = $chado_schema->resultset("Cv::Cvterm")
   ->create_with({
       name   => 'accession',
       cv     => 'stock type',
       db     => 'null',
       dbxref => 'accession',
		 }));
my @stock_names;
for (my $i = 1; $i <= 10; $i++) {
    push(@stock_names, "test_stock_for_trial".$i);
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

ok(my $trial_design = CXGN::Trial::TrialDesign->new());
ok($trial_design->set_trial_name("test_trial"));
ok($trial_design->set_stock_list(\@stock_names));
ok($trial_design->set_plot_start_number(1));
ok($trial_design->set_plot_number_increment(1));
ok($trial_design->set_number_of_blocks(2));
ok($trial_design->set_design_type("RCBD"));
ok($trial_design->calculate_design());
ok(my $design = $trial_design->get_design());

ok(my $trial_create = CXGN::Trial::TrialCreate->new({
    chado_schema => $chado_schema,
    phenome_schema => $phenome_schema,
    dbh => $dbh,
    user_name => "test_user",
    design => $design,	
    program => "test_program",
    trial_year => "2015",
    trial_description => "test description",
    trial_location => "test_location",
    trial_name => "test_trial_name",
    design_type => "test_design_type",
						    }));

