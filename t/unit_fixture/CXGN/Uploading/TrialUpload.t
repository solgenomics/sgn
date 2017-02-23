use strict;
use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use SimulateC;
use CXGN::UploadFile;
use CXGN::Trial;
use CXGN::Trial::TrialCreate;
use CXGN::Trial::ParseUpload;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::Location::LocationLookup;
use CXGN::Stock::StockLookup;
use CXGN::List;
use CXGN::Trial::TrialDesign;
use DateTime;

my $f = SGN::Test::Fixture->new();

my $c = SimulateC->new( { dbh => $f->dbh(),
			  bcs_schema => $f->bcs_schema(),
			  metadata_schema => $f->metadata_schema(),
			  phenome_schema => $f->phenome_schema(),
			  sp_person_id => 41 });

#######################################
#Find out table counts before adding anything, so that changes can be compared

my $pre_project_count = $c->bcs_schema->resultset('Project::Project')->search({})->count();
my $pre_nd_experiment_count = $c->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search({})->count();
my $pre_nd_experimentprop_count = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentprop')->search({})->count();
my $pre_nd_experiment_proj_count = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentProject')->search({})->count();
my $pre_project_prop_count = $c->bcs_schema->resultset('Project::Projectprop')->search({})->count();
my $pre_stock_count = $c->bcs_schema->resultset('Stock::Stock')->search({})->count();
my $pre_stock_prop_count = $c->bcs_schema->resultset('Stock::Stockprop')->search({})->count();
my $pre_stock_relationship_count = $c->bcs_schema->resultset('Stock::StockRelationship')->search({})->count();
my $pre_nd_experiment_stock_count = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentStock')->search({})->count();
my $pre_project_relationship_count = $c->bcs_schema->resultset('Project::ProjectRelationship')->search({})->count();



#First Upload Excel Trial File


my %upload_metadata;
my $file_name = 't/data/trial/trial_layout_example.xls';
my $time = DateTime->now();
my $timestamp = $time->ymd()."_".$time->hms();

#Test archive upload file
my $uploader = CXGN::UploadFile->new({
  tempfile => $file_name,
  subdirectory => 'temp_trial_upload',
  archive_path => '/tmp',
  archive_filename => 'trial_layout_example.xls',
  timestamp => $timestamp,
  user_id => 41, #janedoe in fixture
  user_role => 'curator'
});

## Store uploaded temporary file in archive
my $archived_filename_with_path = $uploader->archive();
my $md5 = $uploader->get_md5($archived_filename_with_path);
ok($archived_filename_with_path);
ok($md5);

$upload_metadata{'archived_file'} = $archived_filename_with_path;
$upload_metadata{'archived_file_type'}="trial upload file";
$upload_metadata{'user_id'}=$c->sp_person_id;
$upload_metadata{'date'}="2014-02-14_09:10:11";


#parse uploaded file with wrong plugin
my $parser = CXGN::Trial::ParseUpload->new(chado_schema => $f->bcs_schema(), filename => $archived_filename_with_path);
$parser->load_plugin('ParseIGDFile');
my $parsed_data = $parser->parse();
ok(!$parsed_data, "Check if parse validate igd file fails for excel");
ok($parser->has_parse_errors(), "Check that parser errors occur");

#parse uploaded file with appropriate plugin
$parser = CXGN::Trial::ParseUpload->new(chado_schema => $f->bcs_schema(), filename => $archived_filename_with_path);
$parser->load_plugin('TrialExcelFormat');
$parsed_data = $parser->parse();
ok($parsed_data, "Check if parse validate excel file works");
ok(!$parser->has_parse_errors(), "Check that parse returns no errors");

#print STDERR Dumper $parsed_data;

my $parsed_data_check = {
          '6' => {
                   'block_number' => '2',
                   'is_a_control' => 0,
                   'stock_name' => 'test_accession3',
                   'plot_number' => '6',
                   'rep_number' => '2',
                   'range_number' => '2',
                   'row_number' => '2',
                   'plot_name' => 'plot_name6'
                 },
          '3' => {
                   'block_number' => '1',
                   'is_a_control' => 0,
                   'stock_name' => 'test_accession2',
                   'plot_number' => '3',
                   'rep_number' => '1',
                   'range_number' => '1',
                   'row_number' => '3',
                   'plot_name' => 'plot_name3'
                 },
          '7' => {
                   'block_number' => '2',
                   'is_a_control' => 0,
                   'stock_name' => 'test_accession4',
                   'plot_number' => '7',
                   'rep_number' => '1',
                   'range_number' => '2',
                   'row_number' => '3',
                   'plot_name' => 'plot_name7'
                 },
          '2' => {
                   'block_number' => '1',
                   'is_a_control' => 0,
                   'stock_name' => 'test_accession1',
                   'plot_number' => '2',
                   'rep_number' => '2',
                   'range_number' => '1',
                   'row_number' => '2',
                   'plot_name' => 'plot_name2'
                 },
          '8' => {
                   'block_number' => '2',
                   'is_a_control' => 0,
                   'stock_name' => 'test_accession4',
                   'plot_number' => '8',
                   'rep_number' => '2',
                   'range_number' => '2',
                   'row_number' => '4',
                   'plot_name' => 'plot_name8'
                 },
          '1' => {
                   'block_number' => '1',
                   'is_a_control' => 0,
                   'stock_name' => 'test_accession1',
                   'plot_number' => '1',
                   'rep_number' => '1',
                   'range_number' => '1',
                   'row_number' => '1',
                   'plot_name' => 'plot_name1'
                 },
          '4' => {
                   'block_number' => '1',
                   'is_a_control' => 0,
                   'stock_name' => 'test_accession2',
                   'plot_number' => '4',
                   'rep_number' => '2',
                   'range_number' => '1',
                   'row_number' => '4',
                   'plot_name' => 'plot_name4'
                 },
          '5' => {
                   'block_number' => '2',
                   'is_a_control' => 0,
                   'stock_name' => 'test_accession3',
                   'plot_number' => '5',
                   'rep_number' => '1',
                   'range_number' => '2',
                   'row_number' => '1',
                   'plot_name' => 'plot_name5'
                 }
        };

is_deeply($parsed_data, $parsed_data_check, 'check trial excel parse data' );

my $trial_create = CXGN::Trial::TrialCreate
    ->new({
	   chado_schema => $c->bcs_schema(),
	   dbh => $c->dbh(),
	   trial_year => "2016",
	   trial_description => "Trial Upload Test",
	   trial_location => "test_location",
	   trial_name => "Trial_upload_test",
	   user_name => "janedoe", #not implemented
	   design_type => "RCBD",
	   design => $parsed_data,
	   program => "test",
	   upload_trial_file => $archived_filename_with_path,
	  });

$trial_create->save_trial();

ok($trial_create, "check that trial_create worked");
my $project_name = $c->bcs_schema()->resultset('Project::Project')->search({}, {order_by => { -desc => 'project_id' }})->first()->name();
ok($project_name == "Trial_upload_test", "check that trial_create really worked");

my $project_desc = $c->bcs_schema()->resultset('Project::Project')->search({}, {order_by => { -desc => 'project_id' }})->first()->description();
ok($project_desc == "Trial Upload Test", "check that trial_create really worked");


my $post_project_count = $c->bcs_schema->resultset('Project::Project')->search({})->count();
my $post1_project_diff = $post_project_count - $pre_project_count;
print STDERR "Project: ".$post1_project_diff."\n";
ok($post1_project_diff == 1, "check project table after upload excel trial");

my $post_nd_experiment_count = $c->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search({})->count();
my $post1_nd_experiment_diff = $post_nd_experiment_count - $pre_nd_experiment_count;
print STDERR "NdExperiment: ".$post1_nd_experiment_diff."\n";
ok($post1_nd_experiment_diff == 1, "check ndexperiment table after upload excel trial");

my $post_nd_experiment_proj_count = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentProject')->search({})->count();
my $post1_nd_experiment_proj_diff = $post_nd_experiment_proj_count - $pre_nd_experiment_proj_count;
print STDERR "NdExperimentProject: ".$post1_nd_experiment_proj_diff."\n";
ok($post1_nd_experiment_proj_diff == 1, "check ndexperimentproject table after upload excel trial");

my $post_nd_experimentprop_count = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentprop')->search({})->count();
my $post1_nd_experimentprop_diff = $post_nd_experimentprop_count - $pre_nd_experimentprop_count;
print STDERR "NdExperimentprop: ".$post1_nd_experimentprop_diff."\n";
ok($post1_nd_experimentprop_diff == 0, "check ndexperimentprop table after upload excel trial");

my $post_project_prop_count = $c->bcs_schema->resultset('Project::Projectprop')->search({})->count();
my $post1_project_prop_diff = $post_project_prop_count - $pre_project_prop_count;
print STDERR "Projectprop: ".$post1_project_prop_diff."\n";
ok($post1_project_prop_diff == 3, "check projectprop table after upload excel trial");

my $post_stock_count = $c->bcs_schema->resultset('Stock::Stock')->search({})->count();
my $post1_stock_diff = $post_stock_count - $pre_stock_count;
print STDERR "Stock: ".$post1_stock_diff."\n";
ok($post1_stock_diff == 8, "check stock table after upload excel trial");

my $post_stock_prop_count = $c->bcs_schema->resultset('Stock::Stockprop')->search({})->count();
my $post1_stock_prop_diff = $post_stock_prop_count - $pre_stock_prop_count;
print STDERR "Stockprop: ".$post1_stock_prop_diff."\n";
ok($post1_stock_prop_diff == 40, "check stockprop table after upload excel trial");

my $post_stock_relationship_count = $c->bcs_schema->resultset('Stock::StockRelationship')->search({})->count();
my $post1_stock_relationship_diff = $post_stock_relationship_count - $pre_stock_relationship_count;
print STDERR "StockRelationship: ".$post1_stock_relationship_diff."\n";
ok($post1_stock_relationship_diff == 8, "check stockrelationship table after upload excel trial");

my $post_nd_experiment_stock_count = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentStock')->search({})->count();
my $post1_nd_experiment_stock_diff = $post_nd_experiment_stock_count - $pre_nd_experiment_stock_count;
print STDERR "NdExperimentStock: ".$post1_nd_experiment_stock_diff."\n";
ok($post1_nd_experiment_stock_diff == 8, "check ndexperimentstock table after upload excel trial");

my $post_project_relationship_count = $c->bcs_schema->resultset('Project::ProjectRelationship')->search({})->count();
my $post1_project_relationship_diff = $post_project_relationship_count - $pre_project_relationship_count;
print STDERR "ProjectRelationship: ".$post1_project_relationship_diff."\n";
ok($post1_project_relationship_diff == 1, "check projectrelationship table after upload excel trial");



#Upload IGD Trial File

$file_name = 't/data/genotype_trial_upload/CASSAVA_GS_74Template';
#parse uploaded file with wrong plugin
$parser = CXGN::Trial::ParseUpload->new(chado_schema => $f->bcs_schema(), filename => $file_name);
$parser->load_plugin('TrialExcelFormat');
$parsed_data = $parser->parse();
ok(!$parsed_data, "Check if parse validate excel fails for igd parser");
ok($parser->has_parse_errors(), "Check that parser errors occur");

#parse uploaded file with appropriate plugin
$parser = CXGN::Trial::ParseUpload->new(chado_schema => $f->bcs_schema(), filename => $file_name);
$parser->load_plugin('ParseIGDFile');
my $meta = $parser->parse();
ok($meta, "Check if parse validate excel file works");

#print STDERR Dumper $meta;

my $parsed_data_check = {
          'blank_well' => 'F05',
          'trial_name' => 'CASSAVA_GS_74',
          'user_id' => 'I.Rabbi@cgiar.org',
          'project_name' => 'NEXTGENCASSAVA'
        };

is_deeply($meta, $parsed_data_check, 'check igd file parse data' );


my $list_id = 4;
my $list = CXGN::List->new( { dbh => $c->dbh(), list_id => $list_id });
my $elements = $list->elements();

my $slu = CXGN::Stock::StockLookup->new({ schema => $c->bcs_schema });

# remove non-word characters from names as required by
# IGD naming conventions. Store new names as synonyms.
#

foreach my $e (@$elements) {
	my $submission_name = $e;
	$submission_name =~ s/\W/\_/g;

	print STDERR "Replacing element $e with $submission_name\n";
	$slu->set_stock_name($e);
	my $s = $slu -> get_stock();
	$slu->set_stock_name($submission_name);

	print STDERR "Storing synonym $submission_name for $e\n";
	$slu->set_stock_name($e);
	eval {
	    #my $rs = $slu->_get_stock_resultset();
	    $s->create_stockprops(
		{ igd_synonym => $submission_name },
		{  autocreate => 1,
		   'cv.name' => 'local',
		});
	};
}


my $td = CXGN::Trial::TrialDesign->new( { schema => $c->bcs_schema });

$td->set_stock_list($elements);
$td->set_block_size(96);
$td->set_blank($meta->{blank_well});
$td->set_design_type("genotyping_plate");
$td->set_trial_name($meta->{trial_name});

my $design;
$td->calculate_design();
$design = $td->get_design();

#print STDERR Dumper $design;

my $igd_design_check = {
          'A01' => {
                     'stock_name' => 'test_accession1',
                     'plot_name' => 'CASSAVA_GS_74_A01'
                   },
          'A03' => {
                     'stock_name' => 'test_accession3',
                     'plot_name' => 'CASSAVA_GS_74_A03'
                   },
          'F05' => {
                     'stock_name' => 'BLANK',
                     'plot_name' => 'CASSAVA_GS_74_F05_BLANK'
                   },
          'A05' => {
                     'stock_name' => 'test_accession5',
                     'plot_name' => 'CASSAVA_GS_74_A05'
                   },
          'A02' => {
                     'stock_name' => 'test_accession2',
                     'plot_name' => 'CASSAVA_GS_74_A02'
                   },
          'A04' => {
                     'stock_name' => 'test_accession4',
                     'plot_name' => 'CASSAVA_GS_74_A04'
                   }
        };

is_deeply($design, $igd_design_check, "check igd design");


my $trial_create = CXGN::Trial::TrialCreate
    ->new({
	chado_schema => $c->bcs_schema,
     	dbh => $c->dbh(),
     	user_name => 'janedoe', #not implemented
     	trial_year => '2016',
	trial_location => 'test_location',
	program => 'test',
	trial_description => "Test Genotyping Trial Upload",
	design_type => 'genotyping_plate',
	design => $design,
	trial_name => "test_genotyping_trial_upload",
	is_genotyping => 1,
	genotyping_user_id => $meta->{user_id} || "unknown",
	genotyping_project_name => $meta->{project_name} || "unknown",
	  });

$trial_create->save_trial();

ok($trial_create, "check that trial_create worked");
my $project_name = $c->bcs_schema()->resultset('Project::Project')->search({}, {order_by => { -desc => 'project_id' }})->first()->name();
ok($project_name == "test_genotyping_trial_upload", "check that trial_create really worked for igd trial");

my $project_desc = $c->bcs_schema()->resultset('Project::Project')->search({}, {order_by => { -desc => 'project_id' }})->first()->description();
ok($project_desc == "Test Genotyping Trial Upload", "check that trial_create really worked for igd trial");


$post_project_count = $c->bcs_schema->resultset('Project::Project')->search({})->count();
my $post2_project_diff = $post_project_count - $pre_project_count;
print STDERR "Project: ".$post2_project_diff."\n";
ok($post2_project_diff == 2, "check project table after upload igd trial");

$post_nd_experiment_count = $c->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search({})->count();
my $post2_nd_experiment_diff = $post_nd_experiment_count - $pre_nd_experiment_count;
print STDERR "NdExperiment: ".$post2_nd_experiment_diff."\n";
ok($post2_nd_experiment_diff == 2, "check ndexperiment table after upload igd trial");

$post_nd_experiment_proj_count = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentProject')->search({})->count();
my $post2_nd_experiment_proj_diff = $post_nd_experiment_proj_count - $pre_nd_experiment_proj_count;
print STDERR "NdExperimentProject: ".$post2_nd_experiment_proj_diff."\n";
ok($post2_nd_experiment_proj_diff == 2, "check ndexperimentproject table after upload igd trial");

$post_nd_experimentprop_count = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentprop')->search({})->count();
my $post2_nd_experimentprop_diff = $post_nd_experimentprop_count - $pre_nd_experimentprop_count;
print STDERR "NdExperimentprop: ".$post2_nd_experimentprop_diff."\n";
ok($post2_nd_experimentprop_diff == 2, "check ndexperimentprop table after upload igd trial");

$post_project_prop_count = $c->bcs_schema->resultset('Project::Projectprop')->search({})->count();
my $post2_project_prop_diff = $post_project_prop_count - $pre_project_prop_count;
print STDERR "Projectprop: ".$post2_project_prop_diff."\n";
ok($post2_project_prop_diff == 6, "check projectprop table after upload igd trial");

$post_stock_count = $c->bcs_schema->resultset('Stock::Stock')->search({})->count();
my $post2_stock_diff = $post_stock_count - $pre_stock_count;
print STDERR "Stock: ".$post2_stock_diff."\n";
ok($post2_stock_diff == 14, "check stock table after upload igd trial");

$post_stock_prop_count = $c->bcs_schema->resultset('Stock::Stockprop')->search({})->count();
my $post2_stock_prop_diff = $post_stock_prop_count - $pre_stock_prop_count;
print STDERR "Stockprop: ".$post2_stock_prop_diff."\n";
ok($post2_stock_prop_diff == 63, "check stockprop table after upload igd trial");

$post_stock_relationship_count = $c->bcs_schema->resultset('Stock::StockRelationship')->search({})->count();
my $post2_stock_relationship_diff = $post_stock_relationship_count - $pre_stock_relationship_count;
print STDERR "StockRelationship: ".$post2_stock_relationship_diff."\n";
ok($post2_stock_relationship_diff == 14, "check stockrelationship table after upload igd trial");

$post_nd_experiment_stock_count = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentStock')->search({})->count();
my $post2_nd_experiment_stock_diff = $post_nd_experiment_stock_count - $pre_nd_experiment_stock_count;
print STDERR "NdExperimentStock: ".$post2_nd_experiment_stock_diff."\n";
ok($post2_nd_experiment_stock_diff == 14, "check ndexperimentstock table after upload igd trial");

$post_project_relationship_count = $c->bcs_schema->resultset('Project::ProjectRelationship')->search({})->count();
my $post2_project_relationship_diff = $post_project_relationship_count - $pre_project_relationship_count;
print STDERR "ProjectRelationship: ".$post2_project_relationship_diff."\n";
ok($post2_project_relationship_diff == 2, "check projectrelationship table after upload igd trial");




done_testing();
