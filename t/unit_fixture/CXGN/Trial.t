
use strict;
use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use SimulateC;

use Data::Dumper;

use CXGN::Trial;
use CXGN::Trial::TrialLayout;
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

my $traitlist_ref = [ 'root number|CO:0000011', 'dry yield|CO:0000014' ];

my %plot_trait_value = ( 'anothertrial1' => { 'root number|CO:0000011'  => [12,''], 'dry yield|CO:0000014' => [30,''] },
			   'anothertrial2' => { 'root number|CO:0000011'  => [10,''], 'dry yield|CO:0000014' => [40,''] },
			   'anothertrial3' => { 'root number|CO:0000011'  => [20,''], 'dry yield|CO:0000014' => [50,''] },
    );


my %metadata = ( operator => 'johndoe', date => '20141223' );

my $size = scalar(@$plotlist_ref) * scalar(@$traitlist_ref);

$lp->store($c, $size, $plotlist_ref, $traitlist_ref, \%plot_trait_value, \%metadata);

my $total_phenotypes = $trial->total_phenotypes();

my $trial_phenotype_count = $trial->phenotype_count();

print STDERR "Total phentoypes: $total_phenotypes\n";
is($trial_phenotype_count, 6, "trial has phenotype data");

my $tn = CXGN::Trial->new( { bcs_schema => $f->bcs_schema(),
				trial_id => 141 });

my $traits_assayed  = $tn->get_traits_assayed();
my @traits_assayed_sorted = sort {$a->[0] cmp $b->[0]} @$traits_assayed;
#print STDERR Dumper @traits_assayed_sorted;

my @traits_assayed_check = (['70666','Fresh root weight'],['70668','Harvest index variable'],['70741','Dry matter content percentage'],['70773','Fresh shoot weight measurement in kg']);

is_deeply(\@traits_assayed_sorted, \@traits_assayed_check, 'check traits assayed' );

my @pheno_for_trait = $tn->get_phenotypes_for_trait(70741);
my @pheno_for_trait_sorted = sort {$a <=> $b} @pheno_for_trait;

my @pheno_for_trait_check = ('14.6', '18.3', '18.4', '19.4', '19.7', '19.7', '20.5', '20.7', '20.8', '22.2', '23.4', '23.6', '23.6', '23.8', '24.2', '24.4', '24.4', '24.5', '24.5', '24.6', '24.8', '24.9', '25.1', '25.1', '25.4', '25.8', '26.1', '26.2', '26.3', '26.4', '26.6', '26.6', '26.7', '26.8', '27', '27.3', '27.6', '28', '28.2', '28.2', '28.2', '28.3', '28.4', '28.4', '28.5', '28.5', '29', '29', '29', '29.1', '29.2', '29.6', '29.8', '29.8', '29.8', '29.9', '30.1', '30.2', '30.2', '30.6', '30.9', '30.9', '30.9', '30.9', '31', '31.1', '31.2', '31.2', '31.2', '31.2', '31.3', '31.4', '31.5', '31.5', '31.6', '31.6', '31.9', '31.9', '32', '32.2', '32.2', '32.3', '32.3', '32.5', '32.7', '32.7', '32.8', '32.9', '32.9', '32.9', '32.9', '33', '33', '33', '33', '33', '33.1', '33.1', '33.1', '33.2', '33.2', '33.3', '33.4', '33.5', '33.6', '33.7', '33.7', '33.9', '34', '34', '34.2', '34.2', '34.3', '34.4', '34.5', '34.6', '34.6', '34.6', '34.7', '34.7', '34.8', '34.9', '35', '35', '35.1', '35.2', '35.3', '35.3', '35.4', '35.6', '35.6', '35.7', '35.9', '36.1', '36.2', '36.2', '36.2', '36.2', '36.2', '36.3', '36.3', '36.4', '36.4', '36.4', '36.5', '36.6', '36.7', '36.8', '36.8', '36.9', '36.9', '36.9', '37', '37', '37', '37', '37.1', '37.1', '37.1', '37.2', '37.3', '37.4', '37.5', '37.5', '37.5', '37.5', '37.7', '37.7', '37.7', '37.8', '37.9', '37.9', '38', '38', '38.1', '38.1', '38.1', '38.2', '38.3', '38.3', '38.3', '38.4', '38.4', '38.4', '38.5', '38.5', '38.5', '38.6', '38.6', '38.7', '38.7', '38.8', '38.8', '38.9', '38.9', '38.9', '39.1', '39.1', '39.2', '39.3', '39.3', '39.4', '39.9', '40', '40', '40.1', '40.1', '40.2', '40.2', '40.3', '40.3', '40.3', '40.4', '40.4', '40.5', '40.5', '40.6', '40.7', '40.8', '40.8', '40.8', '40.9', '41', '41.2', '41.2', '41.2', '41.4', '41.4', '41.5', '41.6', '41.6', '41.6', '41.8', '41.8', '41.9', '41.9', '42.1', '42.1', '42.1', '42.1', '42.2', '42.3', '42.6', '42.8', '42.9', '42.9', '43', '43', '43', '43', '43.1', '43.3', '43.4', '43.5', '43.6', '43.7', '44.3', '44.4', '44.5', '44.6', '44.7', '44.7', '44.8', '44.8', '44.8', '45.1', '45.5', '45.8', '45.9', '46.3', '46.8', '47.2');

is_deeply(\@pheno_for_trait_sorted, \@pheno_for_trait_check, 'check traits assayed' );

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


