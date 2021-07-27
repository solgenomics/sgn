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
use Test::WWW::Mechanize;
use LWP::UserAgent;
use JSON;
use Spreadsheet::Read;
use Text::CSV;

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

print STDERR Dumper $parsed_data;

my $parsed_data_check = {
	'1' => {
			  'plot_name' => 'plot_name1',
			  'stock_name' => 'test_accession1',
			  'col_number' => '1',
			  'is_a_control' => 0,
			  'rep_number' => '1',
			  'block_number' => '1',
			  'range_number' => '1',
			  'row_number' => '1',
			  'plot_number' => '1'
			},
	 '6' => {
			  'rep_number' => '2',
			  'is_a_control' => 0,
			  'block_number' => '2',
			  'plot_name' => 'plot_name6',
			  'stock_name' => 'test_accession3',
			  'col_number' => '2',
			  'range_number' => '2',
			  'row_number' => '2',
			  'plot_number' => '6'
			},
	 '7' => {
			  'range_number' => '2',
			  'row_number' => '3',
			  'plot_number' => '7',
			  'plot_name' => 'plot_name7',
			  'stock_name' => 'test_accession4',
			  'col_number' => '2',
			  'rep_number' => '1',
			  'is_a_control' => 0,
			  'block_number' => '2'
			},
	 '4' => {
			  'range_number' => '1',
			  'plot_number' => '4',
			  'row_number' => '4',
			  'is_a_control' => 0,
			  'rep_number' => '2',
			  'block_number' => '1',
			  'plot_name' => 'plot_name4',
			  'col_number' => '1',
			  'stock_name' => 'test_accession2'
			},
	 '8' => {
			  'range_number' => '2',
			  'row_number' => '4',
			  'plot_number' => '8',
			  'plot_name' => 'plot_name8',
			  'stock_name' => 'test_accession4',
			  'col_number' => '2',
			  'rep_number' => '2',
			  'is_a_control' => 0,
			  'block_number' => '2'
			},
	 '2' => {
			  'range_number' => '1',
			  'plot_number' => '2',
			  'row_number' => '2',
			  'plot_name' => 'plot_name2',
			  'col_number' => '1',
			  'stock_name' => 'test_accession1',
			  'is_a_control' => 0,
			  'rep_number' => '2',
			  'block_number' => '1'
			},
	 '5' => {
			  'range_number' => '2',
			  'row_number' => '1',
			  'plot_number' => '5',
			  'plot_name' => 'plot_name5',
			  'stock_name' => 'test_accession3',
			  'col_number' => '2',
			  'is_a_control' => 0,
			  'rep_number' => '1',
			  'block_number' => '2'
			},
	 '3' => {
			  'stock_name' => 'test_accession2',
			  'col_number' => '1',
			  'plot_name' => 'plot_name3',
			  'block_number' => '1',
			  'is_a_control' => 0,
			  'rep_number' => '1',
			  'row_number' => '3',
			  'plot_number' => '3',
			  'range_number' => '1'
			}
   };

is_deeply($parsed_data, $parsed_data_check, 'check trial excel parse data' );

my $trial_create = CXGN::Trial::TrialCreate
    ->new({
	   chado_schema => $c->bcs_schema(),
	   dbh => $c->dbh(),
	   owner_id => 41,
	   trial_year => "2016",
	   trial_description => "Trial Upload Test",
	   trial_location => "test_location",
	   trial_name => "Trial_upload_test",
	   design_type => "RCBD",
	   design => $parsed_data,
	   program => "test",
	   upload_trial_file => $archived_filename_with_path,
	   operator => "janedoe"
	  });

my $save = $trial_create->save_trial();

ok($save->{'trial_id'}, "check that trial_create worked");
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
ok($post1_project_prop_diff == 4, "check projectprop table after upload excel trial");

my $post_stock_count = $c->bcs_schema->resultset('Stock::Stock')->search({})->count();
my $post1_stock_diff = $post_stock_count - $pre_stock_count;
print STDERR "Stock: ".$post1_stock_diff."\n";
ok($post1_stock_diff == 8, "check stock table after upload excel trial");

my $post_stock_prop_count = $c->bcs_schema->resultset('Stock::Stockprop')->search({})->count();
my $post1_stock_prop_diff = $post_stock_prop_count - $pre_stock_prop_count;
print STDERR "Stockprop: ".$post1_stock_prop_diff."\n";
ok($post1_stock_prop_diff == 48, "check stockprop table after upload excel trial");

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

print STDERR Dumper $design;

my $igd_design_check = {
          'A05' => {
                     'stock_name' => 'test_accession5',
                     'col_number' => 5,
                     'is_blank' => 0,
                     'row_number' => 'A',
                     'plot_number' => 'A05',
                     'plot_name' => 'CASSAVA_GS_74_A05'
                   },
          'A04' => {
                     'plot_number' => 'A04',
                     'plot_name' => 'CASSAVA_GS_74_A04',
                     'col_number' => 4,
                     'stock_name' => 'test_accession4',
                     'is_blank' => 0,
                     'row_number' => 'A'
                   },
          'A02' => {
                     'is_blank' => 0,
                     'row_number' => 'A',
                     'col_number' => 2,
                     'stock_name' => 'test_accession2',
                     'plot_name' => 'CASSAVA_GS_74_A02',
                     'plot_number' => 'A02'
                   },
          'A01' => {
                     'stock_name' => 'test_accession1',
                     'col_number' => 1,
                     'row_number' => 'A',
                     'is_blank' => 0,
                     'plot_name' => 'CASSAVA_GS_74_A01',
                     'plot_number' => 'A01'
                   },
          'F05' => {
                     'plot_name' => 'CASSAVA_GS_74_F05_BLANK',
                     'plot_number' => 'F05',
                     'is_blank' => 1,
                     'row_number' => 'F',
                     'stock_name' => 'BLANK',
                     'col_number' => 5
                   },
          'A03' => {
                     'plot_name' => 'CASSAVA_GS_74_A03',
                     'plot_number' => 'A03',
                     'stock_name' => 'test_accession3',
                     'col_number' => 3,
                     'row_number' => 'A',
                     'is_blank' => 0
                   }
        };

is_deeply($design, $igd_design_check, "check igd design");


my $trial_create = CXGN::Trial::TrialCreate
    ->new({
	chado_schema => $c->bcs_schema,
 	dbh => $c->dbh(),
	owner_id => 41,
 	trial_year => '2016',
	trial_location => 'test_location',
	program => 'test',
	trial_description => "Test Genotyping Plate Upload",
	design_type => 'genotyping_plate',
	design => $design,
	trial_name => "test_genotyping_trial_upload",
	is_genotyping => 1,
	genotyping_user_id => $meta->{user_id} || "unknown",
	genotyping_project_name => $meta->{project_name} || "unknown",
    genotyping_facility_submitted => 'no',
    genotyping_facility => 'igd',
    genotyping_plate_format => '96',
    genotyping_plate_sample_type => 'DNA',
	operator => "janedoe"
	  });

my $save = $trial_create->save_trial();

ok($save->{'trial_id'}, "check that trial_create worked");
my $project_name = $c->bcs_schema()->resultset('Project::Project')->search({}, {order_by => { -desc => 'project_id' }})->first()->name();
ok($project_name == "test_genotyping_trial_upload", "check that trial_create really worked for igd trial");

my $project_desc = $c->bcs_schema()->resultset('Project::Project')->search({}, {order_by => { -desc => 'project_id' }})->first()->description();
ok($project_desc == "Test Genotyping Plate Upload", "check that trial_create really worked for igd trial");


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
ok($post2_project_prop_diff == 11, "check projectprop table after upload igd trial");

$post_stock_count = $c->bcs_schema->resultset('Stock::Stock')->search({})->count();
my $post2_stock_diff = $post_stock_count - $pre_stock_count;
print STDERR "Stock: ".$post2_stock_diff."\n";
ok($post2_stock_diff == 14, "check stock table after upload igd trial");

$post_stock_prop_count = $c->bcs_schema->resultset('Stock::Stockprop')->search({})->count();
my $post2_stock_prop_diff = $post_stock_prop_count - $pre_stock_prop_count;
print STDERR "Stockprop: ".$post2_stock_prop_diff."\n";
ok($post2_stock_prop_diff == 84, "check stockprop table after upload igd trial");

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


#############################
# Upload a trial with seedlot info filled

my %upload_metadata;
my $file_name = 't/data/trial/trial_layout_with_seedlot_example.xls';
my $time = DateTime->now();
my $timestamp = $time->ymd()."_".$time->hms();

#Test archive upload file
my $uploader = CXGN::UploadFile->new({
  tempfile => $file_name,
  subdirectory => 'temp_trial_upload',
  archive_path => '/tmp',
  archive_filename => 'trial_layout_with_seedlot_example.xls',
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


#parse uploaded file with appropriate plugin
$parser = CXGN::Trial::ParseUpload->new(chado_schema => $f->bcs_schema(), filename => $archived_filename_with_path);
$parser->load_plugin('TrialExcelFormat');
$parsed_data = $parser->parse();
ok($parsed_data, "Check if parse validate excel file works");
ok(!$parser->has_parse_errors(), "Check that parse returns no errors");

print STDERR Dumper $parsed_data;

my $parsed_data_check = {
          '7' => {
                   'is_a_control' => 0,
                   'num_seed_per_plot' => '12',
                   'block_number' => '2',
                   'rep_number' => '1',
                   'col_number' => '2',
                   'plot_name' => 'plot_with_seedlot_name7',
                   'stock_name' => 'test_accession4',
                   'seedlot_name' => 'test_accession4_001',
                   'plot_number' => '7',
                   'range_number' => '2',
                   'weight_gram_seed_per_plot' => 0,
                   'row_number' => '3'
                 },
          '4' => {
                   'row_number' => '4',
                   'weight_gram_seed_per_plot' => '5',
                   'range_number' => '1',
                   'seedlot_name' => 'test_accession2_001',
                   'plot_number' => '4',
                   'rep_number' => '2',
                   'num_seed_per_plot' => '12',
                   'block_number' => '1',
                   'is_a_control' => 0,
                   'stock_name' => 'test_accession2',
                   'plot_name' => 'plot_with_seedlot_name4',
                   'col_number' => '1'
                 },
          '1' => {
                   'row_number' => '1',
                   'weight_gram_seed_per_plot' => 0,
                   'range_number' => '1',
                   'seedlot_name' => 'test_accession1_001',
                   'plot_number' => '1',
                   'rep_number' => '1',
                   'num_seed_per_plot' => '12',
                   'block_number' => '1',
                   'is_a_control' => 0,
                   'stock_name' => 'test_accession1',
                   'plot_name' => 'plot_with_seedlot_name1',
                   'col_number' => '1'
                 },
          '5' => {
                   'range_number' => '2',
                   'row_number' => '1',
                   'weight_gram_seed_per_plot' => 0,
                   'plot_number' => '5',
                   'seedlot_name' => 'test_accession3_001',
                   'plot_name' => 'plot_with_seedlot_name5',
                   'col_number' => '2',
                   'stock_name' => 'test_accession3',
                   'rep_number' => '1',
                   'is_a_control' => 0,
                   'num_seed_per_plot' => '12',
                   'block_number' => '2'
                 },
          '2' => {
                   'block_number' => '1',
                   'num_seed_per_plot' => '12',
                   'is_a_control' => 0,
                   'rep_number' => '2',
                   'stock_name' => 'test_accession1',
                   'col_number' => '1',
                   'plot_name' => 'plot_with_seedlot_name2',
                   'plot_number' => '2',
                   'seedlot_name' => 'test_accession1_001',
                   'row_number' => '2',
                   'weight_gram_seed_per_plot' => 0,
                   'range_number' => '1'
                 },
          '3' => {
                   'weight_gram_seed_per_plot' => '4',
                   'row_number' => '3',
                   'range_number' => '1',
                   'plot_number' => '3',
                   'seedlot_name' => 'test_accession2_001',
                   'rep_number' => '1',
                   'block_number' => '1',
                   'num_seed_per_plot' => '12',
                   'is_a_control' => 0,
                   'stock_name' => 'test_accession2',
                   'plot_name' => 'plot_with_seedlot_name3',
                   'col_number' => '1'
                 },
          '6' => {
                   'col_number' => '2',
                   'plot_name' => 'plot_with_seedlot_name6',
                   'stock_name' => 'test_accession3',
                   'is_a_control' => 0,
                   'num_seed_per_plot' => '12',
                   'block_number' => '2',
                   'rep_number' => '2',
                   'seedlot_name' => 'test_accession3_001',
                   'plot_number' => '6',
                   'range_number' => '2',
                   'row_number' => '2',
                   'weight_gram_seed_per_plot' => 0
                 },
          '8' => {
                   'seedlot_name' => 'test_accession4_001',
                   'plot_number' => '8',
                   'weight_gram_seed_per_plot' => 0,
                   'row_number' => '4',
                   'range_number' => '2',
                   'block_number' => '2',
                   'num_seed_per_plot' => '12',
                   'is_a_control' => 0,
                   'rep_number' => '2',
                   'stock_name' => 'test_accession4',
                   'col_number' => '2',
                   'plot_name' => 'plot_with_seedlot_name8'
                 }
        };

is_deeply($parsed_data, $parsed_data_check, 'check trial excel parse data' );

my $trial_create = CXGN::Trial::TrialCreate
    ->new({
	   chado_schema => $c->bcs_schema(),
	   dbh => $c->dbh(),
	   owner_id => 41,
	   trial_year => "2016",
	   trial_description => "Trial Upload Test",
	   trial_location => "test_location",
	   trial_name => "Trial_upload_with_seedlot_test",
	   design_type => "RCBD",
	   design => $parsed_data,
	   program => "test",
	   upload_trial_file => $archived_filename_with_path,
	   operator => "janedoe"
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
ok($post1_project_diff == 3, "check project table after third upload excel trial");

my $post_nd_experiment_count = $c->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search({})->count();
my $post1_nd_experiment_diff = $post_nd_experiment_count - $pre_nd_experiment_count;
print STDERR "NdExperiment: ".$post1_nd_experiment_diff."\n";
ok($post1_nd_experiment_diff == 3, "check ndexperiment table after upload excel trial");

my $post_nd_experiment_proj_count = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentProject')->search({})->count();
my $post1_nd_experiment_proj_diff = $post_nd_experiment_proj_count - $pre_nd_experiment_proj_count;
print STDERR "NdExperimentProject: ".$post1_nd_experiment_proj_diff."\n";
ok($post1_nd_experiment_proj_diff == 3, "check ndexperimentproject table after upload excel trial");

my $post_nd_experimentprop_count = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentprop')->search({})->count();
my $post1_nd_experimentprop_diff = $post_nd_experimentprop_count - $pre_nd_experimentprop_count;
print STDERR "NdExperimentprop: ".$post1_nd_experimentprop_diff."\n";
ok($post1_nd_experimentprop_diff == 2, "check ndexperimentprop table after upload excel trial");

my $post_project_prop_count = $c->bcs_schema->resultset('Project::Projectprop')->search({})->count();
my $post1_project_prop_diff = $post_project_prop_count - $pre_project_prop_count;
print STDERR "Projectprop: ".$post1_project_prop_diff."\n";
ok($post1_project_prop_diff == 15, "check projectprop table after upload excel trial");

my $post_stock_count = $c->bcs_schema->resultset('Stock::Stock')->search({})->count();
my $post1_stock_diff = $post_stock_count - $pre_stock_count;
print STDERR "Stock: ".$post1_stock_diff."\n";
ok($post1_stock_diff == 22, "check stock table after upload excel trial");

my $post_stock_prop_count = $c->bcs_schema->resultset('Stock::Stockprop')->search({})->count();
my $post1_stock_prop_diff = $post_stock_prop_count - $pre_stock_prop_count;
print STDERR "Stockprop: ".$post1_stock_prop_diff."\n";
#ok($post1_stock_prop_diff == 133, "check stockprop table after upload excel trial");

my $post_stock_relationship_count = $c->bcs_schema->resultset('Stock::StockRelationship')->search({})->count();
my $post1_stock_relationship_diff = $post_stock_relationship_count - $pre_stock_relationship_count;
print STDERR "StockRelationship: ".$post1_stock_relationship_diff."\n";
ok($post1_stock_relationship_diff == 30, "check stockrelationship table after upload excel trial");

my $post_nd_experiment_stock_count = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentStock')->search({})->count();
my $post1_nd_experiment_stock_diff = $post_nd_experiment_stock_count - $pre_nd_experiment_stock_count;
print STDERR "NdExperimentStock: ".$post1_nd_experiment_stock_diff."\n";
ok($post1_nd_experiment_stock_diff == 22, "check ndexperimentstock table after upload excel trial");

my $post_project_relationship_count = $c->bcs_schema->resultset('Project::ProjectRelationship')->search({})->count();
my $post1_project_relationship_diff = $post_project_relationship_count - $pre_project_relationship_count;
print STDERR "ProjectRelationship: ".$post1_project_relationship_diff."\n";
ok($post1_project_relationship_diff == 3, "check projectrelationship table after upload excel trial");



my $mech = Test::WWW::Mechanize->new;
$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = decode_json $mech->content;
print STDERR Dumper $response;
my $sgn_session_id = $response->{access_token};
print STDERR $sgn_session_id."\n";

my $file = $f->config->{basepath}."/t/data/genotype_trial_upload/NewGenotypeUpload";
my $ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/breeders/parsegenotypetrial',
        Content_Type => 'form-data',
        Content => [
            genotyping_trial_layout_upload => [ $file, 'genotype_trial_upload', Content_Type => 'application/vnd.ms-excel', ],
            "sgn_session_id"=>$sgn_session_id,
            "genotyping_trial_name"=>'2018TestPlate02'
        ]
    );

#print STDERR Dumper $response;
ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = decode_json $message;
print STDERR Dumper $message_hash;

is_deeply($message_hash, {
          'success' => '1',
          'design' => {
                        'A01' => {
                                   'concentration' => '5',
                                   'acquisition_date' => '2018/02/16',
                                   'dna_person' => 'nmorales',
                                   'volume' => '10',
                                   'col_number' => '1',
                                   'plot_name' => '2018TestPlate02_A01',
                                   'ncbi_taxonomy_id' => '9001',
                                   'stock_name' => 'KASESE_TP2013_885',
                                   'notes' => 'test well A01',
                                   'is_blank' => 0,
                                   'extraction' => 'CTAB',
                                   'plot_number' => 'A01',
                                   'row_number' => 'A',
                                   'tissue_type' => 'leaf'
                                 },
                        'A03' => {
                                   'notes' => 'test well A03',
                                   'is_blank' => 0,
                                   'stock_name' => 'KASESE_TP2013_1671',
                                   'ncbi_taxonomy_id' => '9001',
                                   'plot_name' => '2018TestPlate02_A03',
                                   'tissue_type' => 'leaf',
                                   'row_number' => 'A',
                                   'plot_number' => 'A03',
                                   'extraction' => 'CTAB',
                                   'volume' => '10',
                                   'dna_person' => 'nmorales',
                                   'concentration' => '5',
                                   'acquisition_date' => '2018/02/16',
                                   'col_number' => '3'
                                 },
                        'A02' => {
                                   'extraction' => undef,
                                   'plot_number' => 'A02',
                                   'row_number' => 'A',
                                   'tissue_type' => 'stem',
                                   'stock_name' => 'BLANK',
                                   'notes' => 'test blank',
                                   'is_blank' => 1,
                                   'ncbi_taxonomy_id' => undef,
                                   'plot_name' => '2018TestPlate02_A02',
                                   'col_number' => '2',
                                   'volume' => undef,
                                   'acquisition_date' => '2018/02/16',
                                   'concentration' => undef,
                                   'dna_person' => 'nmorales'
                                 }
                      }
        });

my $project = $c->bcs_schema()->resultset("Project::Project")->find( { name => 'test' } );
my $location = $c->bcs_schema()->resultset("NaturalDiversity::NdGeolocation")->find( { description => 'test_location' } );

my $plate_data = {
    design => $message_hash->{design},
    genotyping_facility_submit => 'yes',
    project_name => 'NextGenCassava',
    description => 'test geno trial upload',
    location => $location->nd_geolocation_id,
    year => '2018',
    name => 'test_genotype_upload_trial1',
    breeding_program => $project->project_id,
    genotyping_facility => 'igd',
    sample_type => 'DNA',
    plate_format => '96'
};

$mech->post_ok('http://localhost:3010/ajax/breeders/storegenotypetrial', [ "sgn_session_id"=>$sgn_session_id, plate_data => encode_json($plate_data) ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;

ok($response->{trial_id});


my $file = $f->config->{basepath}."/t/data/genotype_trial_upload/CoordinateTemplate";
my $ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/breeders/parsegenotypetrial',
        Content_Type => 'form-data',
        Content => [
            genotyping_trial_layout_upload_coordinate_template => [ $file, 'genotype_trial_upload', Content_Type => 'application/vnd.ms-excel', ],
            "sgn_session_id"=>$sgn_session_id,
            "genotyping_trial_name"=>"18DNA00101"
        ]
    );

#print STDERR Dumper $response;
ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = decode_json $message;
print STDERR Dumper $message_hash;

is_deeply($message_hash, {
          'success' => '1',
          'design' => {
                        'B12' => {
                                   'notes' => 'newplate',
                                   'ncbi_taxonomy_id' => 'NA',
                                   'dna_person' => 'gbauchet',
                                   'is_blank' => 1,
                                   'concentration' => 'NA',
                                   'plot_number' => 'B12',
                                   'volume' => 'NA',
                                   'tissue_type' => 'leaf',
                                   'plot_name' => '18DNA00101_B12',
                                   'extraction' => 'NA',
                                   'row_number' => 'B',
                                   'col_number' => '12',
                                   'acquisition_date' => '8/23/2018',
                                   'stock_name' => 'BLANK'
                                 },
                        'A01' => {
                                   'stock_name' => 'KASESE_TP2013_1671',
                                   'acquisition_date' => '8/23/2018',
                                   'col_number' => '01',
                                   'row_number' => 'A',
                                   'extraction' => 'NA',
                                   'plot_name' => '18DNA00101_A01',
                                   'tissue_type' => 'leaf',
                                   'plot_number' => 'A01',
                                   'volume' => 'NA',
                                   'dna_person' => 'gbauchet',
                                   'is_blank' => 0,
                                   'concentration' => 'NA',
                                   'ncbi_taxonomy_id' => 'NA',
                                   'notes' => 'newplate'
                                 },
                        'B01' => {
                                   'plot_name' => '18DNA00101_B01',
                                   'extraction' => 'NA',
                                   'row_number' => 'B',
                                   'col_number' => '01',
                                   'stock_name' => 'KASESE_TP2013_1671',
                                   'acquisition_date' => '8/23/2018',
                                   'ncbi_taxonomy_id' => 'NA',
                                   'notes' => 'newplate',
                                   'dna_person' => 'gbauchet',
                                   'is_blank' => 0,
                                   'concentration' => 'NA',
                                   'plot_number' => 'B01',
                                   'volume' => 'NA',
                                   'tissue_type' => 'leaf'
                                 },
                        'C01' => {
                                   'col_number' => '01',
                                   'acquisition_date' => '8/23/2018',
                                   'stock_name' => 'KASESE_TP2013_885',
                                   'extraction' => 'NA',
                                   'row_number' => 'C',
                                   'plot_name' => '18DNA00101_C01',
                                   'tissue_type' => 'leaf',
                                   'is_blank' => 0,
                                   'dna_person' => 'gbauchet',
                                   'concentration' => 'NA',
                                   'plot_number' => 'C01',
                                   'volume' => 'NA',
                                   'ncbi_taxonomy_id' => 'NA',
                                   'notes' => 'newplate'
                                 },
                        'D01' => {
                                   'ncbi_taxonomy_id' => 'NA',
                                   'notes' => 'newplate',
                                   'plot_number' => 'D01',
                                   'volume' => 'NA',
                                   'dna_person' => 'gbauchet',
                                   'is_blank' => 0,
                                   'concentration' => 'NA',
                                   'tissue_type' => 'leaf',
                                   'plot_name' => '18DNA00101_D01',
                                   'row_number' => 'D',
                                   'extraction' => 'NA',
                                   'acquisition_date' => '8/23/2018',
                                   'stock_name' => 'KASESE_TP2013_885',
                                   'col_number' => '01'
                                 }
                      }
        }, 'test upload parse of coordinate genotyping plate');

my $plate_data = {
    design => $message_hash->{design},
    genotyping_facility_submit => 'no',
    project_name => 'NextGenCassava',
    description => 'test geno trial upload coordinate template',
    location => $location->nd_geolocation_id,
    year => '2018',
    name => 'test_genotype_upload_coordinate_trial101',
    breeding_program => $project->project_id,
    genotyping_facility => 'igd',
    sample_type => 'DNA',
    plate_format => '96'
};

$mech->post_ok('http://localhost:3010/ajax/breeders/storegenotypetrial', [ "sgn_session_id"=>$sgn_session_id, plate_data => encode_json($plate_data) ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;

ok($response->{trial_id});


my $file = $f->config->{basepath}."/t/data/genotype_trial_upload/CoordinatePlateUpload";
my $ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/breeders/parsegenotypetrial',
        Content_Type => 'form-data',
        Content => [
            genotyping_trial_layout_upload_coordinate => [ $file, 'genotype_trial_upload', Content_Type => 'application/vnd.ms-excel', ],
            "sgn_session_id"=>$sgn_session_id,
            "genotyping_trial_name"=>"18DNA00001"
        ]
    );

#print STDERR Dumper $response;
ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = decode_json $message;
print STDERR Dumper $message_hash;

is_deeply($message_hash, {
          'design' => {
                        'B01' => {
                                   'ncbi_taxonomy_id' => 'NA',
                                   'is_blank' => 0,
                                   'acquisition_date' => '2018-02-06',
                                   'plot_name' => '18DNA00001_B01',
                                   'col_number' => '01',
                                   'notes' => '',
                                   'extraction' => 'CTAB',
                                   'tissue_type' => 'leaf',
                                   'volume' => 'NA',
                                   'concentration' => 'NA',
                                   'stock_name' => 'test_accession1',
                                   'plot_number' => 'B01',
                                   'row_number' => 'B',
                                   'dna_person' => 'Trevor_Rife'
                                 },
                        'B04' => {
                                   'tissue_type' => 'leaf',
                                   'extraction' => 'CTAB',
                                   'notes' => '',
                                   'col_number' => '04',
                                   'acquisition_date' => '2018-02-06',
                                   'plot_name' => '18DNA00001_B04',
                                   'ncbi_taxonomy_id' => 'NA',
                                   'is_blank' => 1,
                                   'row_number' => 'B',
                                   'dna_person' => 'Trevor_Rife',
                                   'plot_number' => 'B04',
                                   'stock_name' => 'BLANK',
                                   'concentration' => 'NA',
                                   'volume' => 'NA'
                                 },
                        'C01' => {
                                   'is_blank' => 0,
                                   'ncbi_taxonomy_id' => 'NA',
                                   'plot_name' => '18DNA00001_C01',
                                   'acquisition_date' => '2018-02-06',
                                   'notes' => '',
                                   'col_number' => '01',
                                   'extraction' => 'CTAB',
                                   'tissue_type' => 'leaf',
                                   'volume' => 'NA',
                                   'concentration' => 'NA',
                                   'stock_name' => 'test_accession2',
                                   'plot_number' => 'C01',
                                   'dna_person' => 'Trevor_Rife',
                                   'row_number' => 'C'
                                 },
                        'C04' => {
                                   'ncbi_taxonomy_id' => 'NA',
                                   'is_blank' => 1,
                                   'plot_name' => '18DNA00001_C04',
                                   'acquisition_date' => '2018-02-06',
                                   'notes' => '',
                                   'col_number' => '04',
                                   'tissue_type' => 'leaf',
                                   'extraction' => 'CTAB',
                                   'volume' => 'NA',
                                   'stock_name' => 'BLANK',
                                   'concentration' => 'NA',
                                   'plot_number' => 'C04',
                                   'dna_person' => 'Trevor_Rife',
                                   'row_number' => 'C'
                                 },
                        'A01' => {
                                   'is_blank' => 0,
                                   'ncbi_taxonomy_id' => 'NA',
                                   'acquisition_date' => '2018-02-06',
                                   'plot_name' => '18DNA00001_A01',
                                   'notes' => '',
                                   'col_number' => '01',
                                   'extraction' => 'CTAB',
                                   'tissue_type' => 'leaf',
                                   'volume' => 'NA',
                                   'concentration' => 'NA',
                                   'stock_name' => 'test_accession1',
                                   'plot_number' => 'A01',
                                   'dna_person' => 'Trevor_Rife',
                                   'row_number' => 'A'
                                 },
                        'D01' => {
                                   'dna_person' => 'Trevor_Rife',
                                   'row_number' => 'D',
                                   'plot_number' => 'D01',
                                   'stock_name' => 'test_accession2',
                                   'concentration' => 'NA',
                                   'volume' => 'NA',
                                   'tissue_type' => 'leaf',
                                   'extraction' => 'CTAB',
                                   'col_number' => '01',
                                   'notes' => '',
                                   'acquisition_date' => '2018-02-06',
                                   'plot_name' => '18DNA00001_D01',
                                   'ncbi_taxonomy_id' => 'NA',
                                   'is_blank' => 0
                                 }
                      },
          'success' => '1'
      }, 'test upload parse of coordinate genotyping plate');

my $plate_data = {
    design => $message_hash->{design},
    genotyping_facility_submit => 'no',
    project_name => 'NextGenCassava',
    description => 'test geno trial upload coordinate',
    location => $location->nd_geolocation_id,
    year => '2018',
    name => 'test_genotype_upload_coordinate_trial1',
    breeding_program => $project->project_id,
    genotyping_facility => 'igd',
    sample_type => 'DNA',
    plate_format => '96'
};

$mech->post_ok('http://localhost:3010/ajax/breeders/storegenotypetrial', [ "sgn_session_id"=>$sgn_session_id, plate_data => encode_json($plate_data) ]);
$response = decode_json $mech->content;
print STDERR "RESPONSE: ".Dumper $response;

ok($response->{trial_id});
my $geno_trial_id = $response->{trial_id};
$mech->get_ok("http://localhost:3010/breeders/trial/$geno_trial_id/download/layout?format=intertekxls&dataLevel=plate");
my $intertek_download = $mech->content;
my $contents = ReadData $intertek_download;
print STDERR Dumper $contents;
is($contents->[0]->{'type'}, 'xls', "check that type of file is correct #1");
is($contents->[0]->{'sheets'}, '1', "check that type of file is correct #2");

my $columns = $contents->[1]->{'cell'};
#print STDERR Dumper scalar(@$columns);
ok(scalar(@$columns) == 7, "check number of col in created file.");

print STDERR Dumper $columns;
is_deeply($columns, [
          [],
          [
            undef,
            'Sample ID',
            '18DNA00001_A01|||test_accession1',
            '18DNA00001_B01|||test_accession1',
            '18DNA00001_B04|||BLANK',
            '18DNA00001_C01|||test_accession2',
            '18DNA00001_C04|||BLANK',
            '18DNA00001_D01|||test_accession2'
          ],
          [
            undef,
            'Plate ID',
            'test_genotype_upload_coordinate_trial1',
            'test_genotype_upload_coordinate_trial1',
            'test_genotype_upload_coordinate_trial1',
            'test_genotype_upload_coordinate_trial1',
            'test_genotype_upload_coordinate_trial1',
            'test_genotype_upload_coordinate_trial1'
          ],
          [
            undef,
            'Well location',
            'A01',
            'B01',
            'B04',
            'C01',
            'C04',
            'D01'
          ],
          [
            undef,
            'Subject Barcode',
            'test_accession1',
            'test_accession1',
            'BLANK',
            'test_accession2',
            'BLANK',
            'test_accession2'
          ],
          [
            undef,
            'Plate Barcode',
            'test_genotype_upload_coordinate_trial1',
            'test_genotype_upload_coordinate_trial1',
            'test_genotype_upload_coordinate_trial1',
            'test_genotype_upload_coordinate_trial1',
            'test_genotype_upload_coordinate_trial1',
            'test_genotype_upload_coordinate_trial1'
          ],
          [
            undef,
            'Comments',
            'Notes:  AcquisitionDate: 2018-02-06 Concentration: NA Volume: NA TissueType: leaf Person: Trevor_Rife Extraction: CTAB',
            'Notes:  AcquisitionDate: 2018-02-06 Concentration: NA Volume: NA TissueType: leaf Person: Trevor_Rife Extraction: CTAB',
            'Notes:  AcquisitionDate: 2018-02-06 Concentration: NA Volume: NA TissueType: leaf Person: Trevor_Rife Extraction: CTAB',
            'Notes:  AcquisitionDate: 2018-02-06 Concentration: NA Volume: NA TissueType: leaf Person: Trevor_Rife Extraction: CTAB',
            'Notes:  AcquisitionDate: 2018-02-06 Concentration: NA Volume: NA TissueType: leaf Person: Trevor_Rife Extraction: CTAB',
            'Notes:  AcquisitionDate: 2018-02-06 Concentration: NA Volume: NA TissueType: leaf Person: Trevor_Rife Extraction: CTAB'
          ]
        ], 'test intertek genotyping plate download');

$mech->get_ok("http://localhost:3010/breeders/trial/$geno_trial_id/download/layout?format=dartseqcsv&dataLevel=plate");
my $intertek_download = $mech->content;
print STDERR Dumper $intertek_download;
my @intertek_download = split "\n", $intertek_download;
print STDERR Dumper \@intertek_download;

is_deeply(\@intertek_download, [
          'PlateID,Row,Column,Organism,Species,Genotype,Tissue,Comments',
          'test_genotype_upload_coordinate_trial1,A,01,tomato,"Solanum lycopersicum",18DNA00001_A01|||test_accession1,leaf,"Notes: NA AcquisitionDate: 2018-02-06 Concentration: NA Volume: NA Person: Trevor_Rife Extraction: CTAB"',
          'test_genotype_upload_coordinate_trial1,B,01,tomato,"Solanum lycopersicum",18DNA00001_B01|||test_accession1,leaf,"Notes: NA AcquisitionDate: 2018-02-06 Concentration: NA Volume: NA Person: Trevor_Rife Extraction: CTAB"',
          'test_genotype_upload_coordinate_trial1,C,01,tomato,"Solanum lycopersicum",18DNA00001_C01|||test_accession2,leaf,"Notes: NA AcquisitionDate: 2018-02-06 Concentration: NA Volume: NA Person: Trevor_Rife Extraction: CTAB"',
          'test_genotype_upload_coordinate_trial1,D,01,tomato,"Solanum lycopersicum",18DNA00001_D01|||test_accession2,leaf,"Notes: NA AcquisitionDate: 2018-02-06 Concentration: NA Volume: NA Person: Trevor_Rife Extraction: CTAB"'
        ]);

done_testing();
