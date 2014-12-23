
use strict;
use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;

use Data::Dumper;

use CXGN::Trial;
use CXGN::Trial::TrialDesign;
use CXGN::Trial::TrialCreate;

my $f = SGN::Test::Fixture->new();

my $stock_count_rs = $f->bcs_schema()->resultset("Stock::Stock")->search( { } );
my $initial_stock_count = $stock_count_rs->count();

my $number_of_reps = 3;
my $stock_list = [ 'test_accession1', 'test_accession2', 'test_accession3' ];

my $td = CXGN::Trial::TrialDesign->new(
    { 
	schema => $f->bcs_schema(),
	trial_name => "another test trial",
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
	trial_name => "another test trial",
	design => $trial_design,
    });


my $message = $new_trial->save_trial();
print STDERR "Error saving trial: $message->{error}\n" if (exists($message->{error}));

my $after_design_creation_count = $stock_count_rs->count();

is($number_of_plots + $initial_stock_count, $after_design_creation_count, "check stock table count after trial creation.");

my $trial_rs = $f->bcs_schema->resultset("Project::Project")->search( { name => 'another test trial' });

my $trial_id = 0;

if ($trial_rs->count() > 0) { 
    $trial_id = $trial_rs->first()->project_id(); 
} 

if (!$trial_id) { die "Test failed... could not retrieve trial\n"; }

my $trial = CXGN::Trial->new( { bcs_schema => $f->bcs_schema(),
				trial_id => $trial_id });

my $desc = $trial->get_description();

ok($desc == "test_trial", "another test trial...");

# check trial layout deletion
#
my $error = $trial->delete_field_layout();

my $after_design_deletion_count = $stock_count_rs->count();

is($initial_stock_count, $after_design_deletion_count, "check that stock counts before layout creation and after deletion match");

done_testing();



