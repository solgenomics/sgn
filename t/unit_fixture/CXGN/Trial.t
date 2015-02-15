
use strict;
use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use SimulateC;

use Data::Dumper;

use CXGN::Trial;
use CXGN::Trial::TrialDesign;
use CXGN::Trial::TrialCreate;
use CXGN::Phenotypes::StorePhenotypes;

my $f = SGN::Test::Fixture->new();

my $stock_count_rs = $f->bcs_schema()->resultset("Stock::Stock")->search( { } );
my $initial_stock_count = $stock_count_rs->count();

my $number_of_reps = 3;
my $stock_list = [ 'test_accession1', 'test_accession2', 'test_accession3' ];

my $td = CXGN::Trial::TrialDesign->new(
    { 
	schema => $f->bcs_schema(),
	trial_name => "anothertrial",
	stock_list => $stock_list,
	number_of_reps => $number_of_reps,
	block_size => 2,
	design_type => 'RCBD',
	number_of_blocks => 3,	
    });

my $number_of_plots = $number_of_reps * scalar(@$stock_list);

$td->calculate_design();

my $trial_design = $td->get_design();

my $breeding_program_row = $f->bcs_schema->resultset("Project::Project")->find( { name => 'test' });

my $new_trial = CXGN::Trial::TrialCreate->new(
    { 
	dbh => $f->dbh(),
	chado_schema => $f->bcs_schema(),
	metadata_schema => $f->metadata_schema(),
	phenome_schema => $f->phenome_schema(),
	user_name => 'janedoe',
	program => 'test',
	trial_year => 2014,
	trial_description => 'another test trial...',
	design_type => 'RCBD',
	trial_location => 'test_location',
	trial_name => "anothertrial",
	design => $trial_design,
    });

my $message = $new_trial->save_trial();

my $after_design_creation_count = $stock_count_rs->count();

is($number_of_plots + $initial_stock_count, $after_design_creation_count, "check stock table count after trial creation.");

my $trial_rs = $f->bcs_schema->resultset("Project::Project")->search( { name => 'anothertrial' });

my $trial_id = 0;

if ($trial_rs->count() > 0) { 
    $trial_id = $trial_rs->first()->project_id(); 
} 

if (!$trial_id) { die "Test failed... could not retrieve trial\n"; }

my $trial = CXGN::Trial->new( { bcs_schema => $f->bcs_schema(),
				trial_id => $trial_id });


my $rs = $f->bcs_schema()->resultset("Stock::Stock")->search( { name => 'anothertrial1' });

if ($rs->count() > 0) { 
    print STDERR "antohertrial1 has id ".$rs->first()->stock_id()."\n";
}
else { 
    print STDERR "anothertrial1 does not exist!\n";
}

# Test addition and deletion of phenotypic data
#
my $phenotype_count_before_store = $trial->phenotype_count();

ok($trial->phenotype_count() == 0, "trial has no phenotype data");

my $c = SimulateC->new( { dbh => $f->dbh(), 
			  bcs_schema => $f->bcs_schema(), 
			  metadata_schema => $f->metadata_schema(),
			  sp_person_id => 41 });

my $lp = CXGN::Phenotypes::StorePhenotypes->new();

my $plotlist_ref = [ 'anothertrial1', 'anothertrial2', 'anothertrial3', 'anothertrial4', 'anothertrial5' ];

my $traitlist_ref = [ 'CO:root number', 'CO:dry yield' ];

my %plot_trait_value = ( 'anothertrial1' => { 'CO:root number'  => 12, 'CO:dry yield' => 30 },
			   'anothertrial2' => { 'CO:root number'  => 10, 'CO:dry yield' => 40 },
			   'anothertrial3' => { 'CO:root number'  => 20, 'CO:dry_yield' => 50 },
    );


my %metadata = ( operator => 'johndoe', date => '20141223' );

$lp->store($c, $plotlist_ref, $traitlist_ref, \%plot_trait_value, \%metadata);

my $total_phenotypes = $trial->total_phenotypes();

my $trial_phenotype_count = $trial->phenotype_count();

is($trial_phenotype_count, 10, "trial has phenotype data");

# check trial deletion - first, delete associated phenotypes
#
$trial->delete_phenotype_data();

ok($trial->phenotype_count() ==0, "phenotype data deleted");

is($trial->total_phenotypes(), $total_phenotypes - $trial_phenotype_count, "check total phenotypes");

# check trial layout deletion
#
my $error = $trial->delete_field_layout();

ok(! $error, "no error upon layout deletion");

my $after_design_deletion_count = $stock_count_rs->count();

is( $after_design_deletion_count, $initial_stock_count, "check that stock counts before layout creation and after deletion match");

# test name accessors
#
is($trial->get_name(), "anothertrial");
$trial->set_name("anothertrial modified");
is($trial->get_name(), "anothertrial modified");

# test description accessors
#
my $desc = $trial->get_description();

ok($desc == "test_trial", "another test trial...");

$trial->set_description("blablabla");

is($trial->get_description(), "blablabla", "description setter test");

# test year accessors
#
is($trial->get_year(), 2014, "get year test");

$trial->set_year(2013);
is($trial->get_year(), 2013, "set year test");

# test location accessors
#
is_deeply($trial->get_location(), [ 23, 'test_location' ], "get location");
$trial->remove_location(23);
is_deeply($trial->get_location(), [], "remove location");

$trial->add_location(23);
is_deeply($trial->get_location(), [ 23, 'test_location' ], "set location");

# test project type accessors
#
is($trial->get_project_type(), undef, "get project type");

my $error = $trial->associate_project_type("clonal");

is($trial->get_project_type()->[1], "clonal", "associate project type");

my $error = $trial->dissociate_project_type();
is($trial->get_project_type(), undef, "dissociate project type");

$trial->delete_project_entry();

my $deleted_trial;
eval { 
     $deleted_trial = CXGN::Trial->new( { bcs_schema => $f->bcs_schema, trial_id=>$trial_id });
};

ok($@, "deleted trial id");


done_testing();


