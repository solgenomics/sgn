use strict;
use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
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
use CXGN::BreedersToolbox::Projects;
use CXGN::Genotype::StoreGenotypingProject;
use DateTime;
use Test::WWW::Mechanize;
use LWP::UserAgent;
use JSON;
use Spreadsheet::Read;
use Text::CSV;
use CXGN::Trait::Treatment;

my $f = SGN::Test::Fixture->new();

for my $extension ("xls", "xlsx", "csv") {

	#######################################
	#Find out table counts before adding anything, so that changes can be compared

	my $pre_project_count = $f->bcs_schema->resultset('Project::Project')->search({})->count();
	my $pre_nd_experiment_count = $f->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search({})->count();
	my $pre_nd_experimentprop_count = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentprop')->search({})->count();
	my $pre_nd_experiment_proj_count = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentProject')->search({})->count();
	my $pre_project_prop_count = $f->bcs_schema->resultset('Project::Projectprop')->search({})->count();
	my $pre_stock_count = $f->bcs_schema->resultset('Stock::Stock')->search({})->count();
	my $pre_stock_prop_count = $f->bcs_schema->resultset('Stock::Stockprop')->search({})->count();
	my $pre_stock_relationship_count = $f->bcs_schema->resultset('Stock::StockRelationship')->search({})->count();
	my $pre_nd_experiment_stock_count = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentStock')->search({})->count();
	my $pre_project_relationship_count = $f->bcs_schema->resultset('Project::ProjectRelationship')->search({})->count();


	#First Upload Excel Trial File


	my %upload_metadata;
	my $file_name = "t/data/trial/trial_layout_example.$extension";
	my $time = DateTime->now();
	my $timestamp = $time->ymd() . "_" . $time->hms();

	#Test archive upload file
	my $uploader = CXGN::UploadFile->new({
		tempfile         => $file_name,
		subdirectory     => 'temp_trial_upload',
		archive_path     => '/tmp',
		archive_filename => "trial_layout_example.$extension",
		timestamp        => $timestamp,
		user_id          => 41, #janedoe in fixture
		user_role        => 'curator'
	});

	## Store uploaded temporary file in archive
	my $archived_filename_with_path = $uploader->archive();
	my $md5 = $uploader->get_md5($archived_filename_with_path);
	ok($archived_filename_with_path);
	ok($md5);

	$upload_metadata{'archived_file'} = $archived_filename_with_path;
	$upload_metadata{'archived_file_type'} = "trial upload file";
	$upload_metadata{'user_id'} = 41;
	$upload_metadata{'date'} = "2014-02-14_09:10:11";


	#parse uploaded file with wrong plugin
	my $parser = CXGN::Trial::ParseUpload->new(chado_schema => $f->bcs_schema(), filename => $archived_filename_with_path);
	$parser->load_plugin('ParseIGDFile');
	my $parsed_data = $parser->parse();
	ok(!$parsed_data, "Check if parse validate igd file fails for excel");
	ok($parser->has_parse_errors(), "Check that parser errors occur");

	#parse uploaded file with appropriate plugin
	$parser = CXGN::Trial::ParseUpload->new(chado_schema => $f->bcs_schema(), filename => $archived_filename_with_path);
	$parser->load_plugin('TrialGeneric');
	$parsed_data = $parser->parse()->{'design'};
	ok($parsed_data, "Check if parse validate excel file works");
	ok(!$parser->has_parse_errors(), "Check that parse returns no errors");

	#print STDERR Dumper $parsed_data;

	my $parsed_data_check = {
		'2' => {
			'plot_name'    => 'plot_name1',
			'stock_name'   => 'test_accession1',
			'col_number'   => '1',
			'is_a_control' => 0,
			'rep_number'   => '1',
			'block_number' => '1',
			'range_number' => '1',
			'row_number'   => '1',
			'plot_number'  => '1'
		},
		'7' => {
			'rep_number'   => '2',
			'is_a_control' => 0,
			'block_number' => '2',
			'plot_name'    => 'plot_name6',
			'stock_name'   => 'test_accession3',
			'col_number'   => '2',
			'range_number' => '2',
			'row_number'   => '2',
			'plot_number'  => '6'
		},
		'8' => {
			'range_number' => '2',
			'row_number'   => '3',
			'plot_number'  => '7',
			'plot_name'    => 'plot_name7',
			'stock_name'   => 'test_accession4',
			'col_number'   => '2',
			'rep_number'   => '1',
			'is_a_control' => 0,
			'block_number' => '2'
		},
		'5' => {
			'range_number' => '1',
			'plot_number'  => '4',
			'row_number'   => '4',
			'is_a_control' => 0,
			'rep_number'   => '2',
			'block_number' => '1',
			'plot_name'    => 'plot_name4',
			'col_number'   => '1',
			'stock_name'   => 'test_accession2'
		},
		'9' => {
			'range_number' => '2',
			'row_number'   => '4',
			'plot_number'  => '8',
			'plot_name'    => 'plot_name8',
			'stock_name'   => 'test_accession4',
			'col_number'   => '2',
			'rep_number'   => '2',
			'is_a_control' => 0,
			'block_number' => '2'
		},
		'3' => {
			'range_number' => '1',
			'plot_number'  => '2',
			'row_number'   => '2',
			'plot_name'    => 'plot_name2',
			'col_number'   => '1',
			'stock_name'   => 'test_accession1',
			'is_a_control' => 0,
			'rep_number'   => '2',
			'block_number' => '1'
		},
		'6' => {
			'range_number' => '2',
			'row_number'   => '1',
			'plot_number'  => '5',
			'plot_name'    => 'plot_name5',
			'stock_name'   => 'test_accession3',
			'col_number'   => '2',
			'is_a_control' => 0,
			'rep_number'   => '1',
			'block_number' => '2'
		},
		'4' => {
			'stock_name'   => 'test_accession2',
			'col_number'   => '1',
			'plot_name'    => 'plot_name3',
			'block_number' => '1',
			'is_a_control' => 0,
			'rep_number'   => '1',
			'row_number'   => '3',
			'plot_number'  => '3',
			'range_number' => '1'
		}
	};

	is_deeply($parsed_data, $parsed_data_check, 'check trial excel parse data');

	my $trial_create = CXGN::Trial::TrialCreate
		->new({
		chado_schema      => $f->bcs_schema(),
		dbh               => $f->dbh(),
		owner_id          => 41,
		trial_year        => "2016",
		trial_description => "Trial Upload Test",
		trial_location    => "test_location",
		trial_name        => "Trial_upload_test",
		design_type       => "RCBD",
		design            => $parsed_data,
		program           => "test",
		upload_trial_file => $archived_filename_with_path,
		operator          => "janedoe"
	});

	my $save = $trial_create->save_trial();

	ok($save->{'trial_id'}, "check that trial_create worked");
	my $project_name = $f->bcs_schema()->resultset('Project::Project')->search({}, { order_by => { -desc => 'project_id' } })->first()->name();
	ok($project_name == "Trial_upload_test", "check that trial_create really worked");

	my $project_desc = $f->bcs_schema()->resultset('Project::Project')->search({}, { order_by => { -desc => 'project_id' } })->first()->description();
	ok($project_desc == "Trial Upload Test", "check that trial_create really worked");

	my $post_project_count = $f->bcs_schema->resultset('Project::Project')->search({})->count();
	my $post1_project_diff = $post_project_count - $pre_project_count;
	print STDERR "Project: " . $post1_project_diff . "\n";
	ok($post1_project_diff == 1, "check project table after upload excel trial");

	my $post_nd_experiment_count = $f->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search({})->count();
	my $post1_nd_experiment_diff = $post_nd_experiment_count - $pre_nd_experiment_count;
	print STDERR "NdExperiment: " . $post1_nd_experiment_diff . "\n";
	ok($post1_nd_experiment_diff == 1, "check ndexperiment table after upload excel trial");

	my $post_nd_experiment_proj_count = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentProject')->search({})->count();
	my $post1_nd_experiment_proj_diff = $post_nd_experiment_proj_count - $pre_nd_experiment_proj_count;
	print STDERR "NdExperimentProject: " . $post1_nd_experiment_proj_diff . "\n";
	ok($post1_nd_experiment_proj_diff == 1, "check ndexperimentproject table after upload excel trial");

	my $post_nd_experimentprop_count = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentprop')->search({})->count();
	my $post1_nd_experimentprop_diff = $post_nd_experimentprop_count - $pre_nd_experimentprop_count;
	print STDERR "NdExperimentprop: " . $post1_nd_experimentprop_diff . "\n";
	ok($post1_nd_experimentprop_diff == 0, "check ndexperimentprop table after upload excel trial");

	my $post_project_prop_count = $f->bcs_schema->resultset('Project::Projectprop')->search({})->count();
	my $post1_project_prop_diff = $post_project_prop_count - $pre_project_prop_count;
	print STDERR "Projectprop: " . $post1_project_prop_diff . "\n";
	ok($post1_project_prop_diff == 4, "check projectprop table after upload excel trial");

	my $post_stock_count = $f->bcs_schema->resultset('Stock::Stock')->search({})->count();
	my $post1_stock_diff = $post_stock_count - $pre_stock_count;
	print STDERR "Stock: " . $post1_stock_diff . "\n";
	ok($post1_stock_diff == 8, "check stock table after upload excel trial");

	my $post_stock_prop_count = $f->bcs_schema->resultset('Stock::Stockprop')->search({})->count();
	my $post1_stock_prop_diff = $post_stock_prop_count - $pre_stock_prop_count;
	print STDERR "Stockprop: " . $post1_stock_prop_diff . "\n";
	ok($post1_stock_prop_diff == 48, "check stockprop table after upload excel trial");

	my $post_stock_relationship_count = $f->bcs_schema->resultset('Stock::StockRelationship')->search({})->count();
	my $post1_stock_relationship_diff = $post_stock_relationship_count - $pre_stock_relationship_count;
	print STDERR "StockRelationship: " . $post1_stock_relationship_diff . "\n";
	ok($post1_stock_relationship_diff == 8, "check stockrelationship table after upload excel trial");

	my $post_nd_experiment_stock_count = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentStock')->search({})->count();
	my $post1_nd_experiment_stock_diff = $post_nd_experiment_stock_count - $pre_nd_experiment_stock_count;
	print STDERR "NdExperimentStock: " . $post1_nd_experiment_stock_diff . "\n";
	ok($post1_nd_experiment_stock_diff == 8, "check ndexperimentstock table after upload excel trial");

	my $post_project_relationship_count = $f->bcs_schema->resultset('Project::ProjectRelationship')->search({})->count();
	my $post1_project_relationship_diff = $post_project_relationship_count - $pre_project_relationship_count;
	print STDERR "ProjectRelationship: " . $post1_project_relationship_diff . "\n";
	ok($post1_project_relationship_diff == 1, "check projectrelationship table after upload excel trial");


	#Upload IGD Trial File

	$file_name = 't/data/genotype_trial_upload/CASSAVA_GS_74Template.csv';
	#parse uploaded file with wrong plugin
	$parser = CXGN::Trial::ParseUpload->new(chado_schema => $f->bcs_schema(), filename => $file_name);
	$parser->load_plugin('TrialGeneric');
	my $rtn = $parser->parse();
	$parsed_data = $rtn->{'design'};
	ok(!$parsed_data, "Check if parse validate excel fails for igd parser");
	ok($parser->has_parse_errors(), "Check that parser errors occur");

	#parse uploaded file with appropriate plugin
	$parser = CXGN::Trial::ParseUpload->new(chado_schema => $f->bcs_schema(), filename => $file_name);
	$parser->load_plugin('ParseIGDFile');
	my $meta = $parser->parse();
	ok($meta, "Check if parse validate excel file works");

	print STDERR "CHECK =" . Dumper($meta) . "\n";

	my $parsed_data_check = {
		'blank_well'   => 'F05',
		'trial_name'   => 'CASSAVA_GS_74',
		'user_id'      => 'I.Rabbi@cgiar.org',
		'project_name' => 'NEXTGENCASSAVA'
	};

	is_deeply($meta, $parsed_data_check, 'check igd file parse data');

	my $list_id = 4;
	my $list = CXGN::List->new({ dbh => $f->dbh(), list_id => $list_id });
	my $elements = $list->elements();

	my $slu = CXGN::Stock::StockLookup->new({ schema => $f->bcs_schema });

	# remove non-word characters from names as required by
	# IGD naming conventions. Store new names as synonyms.
	#

	foreach my $e (@$elements) {
		my $submission_name = $e;
		$submission_name =~ s/\W/\_/g;

		print STDERR "Replacing element $e with $submission_name\n";
		$slu->set_stock_name($e);
		my $s = $slu->get_stock();
		$slu->set_stock_name($submission_name);

		print STDERR "Storing synonym $submission_name for $e\n";
		$slu->set_stock_name($e);
		eval {
			#my $rs = $slu->_get_stock_resultset();
			$s->create_stockprops(
				{ igd_synonym => $submission_name },
				{ autocreate  => 1,
					'cv.name' => 'local',
				});
		};
	}

	my $td = CXGN::Trial::TrialDesign->new({ schema => $f->bcs_schema });

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
		'A05' => {
			'stock_name'  => 'test_accession5',
			'col_number'  => 5,
			'is_blank'    => 0,
			'row_number'  => 'A',
			'plot_number' => 'A05',
			'plot_name'   => 'CASSAVA_GS_74_A05'
		},
		'A04' => {
			'plot_number' => 'A04',
			'plot_name'   => 'CASSAVA_GS_74_A04',
			'col_number'  => 4,
			'stock_name'  => 'test_accession4',
			'is_blank'    => 0,
			'row_number'  => 'A'
		},
		'A02' => {
			'is_blank'    => 0,
			'row_number'  => 'A',
			'col_number'  => 2,
			'stock_name'  => 'test_accession2',
			'plot_name'   => 'CASSAVA_GS_74_A02',
			'plot_number' => 'A02'
		},
		'A01' => {
			'stock_name'  => 'test_accession1',
			'col_number'  => 1,
			'row_number'  => 'A',
			'is_blank'    => 0,
			'plot_name'   => 'CASSAVA_GS_74_A01',
			'plot_number' => 'A01'
		},
		'F05' => {
			'plot_name'   => 'CASSAVA_GS_74_F05_BLANK',
			'plot_number' => 'F05',
			'is_blank'    => 1,
			'row_number'  => 'F',
			'stock_name'  => 'BLANK',
			'col_number'  => 5
		},
		'A03' => {
			'plot_name'   => 'CASSAVA_GS_74_A03',
			'plot_number' => 'A03',
			'stock_name'  => 'test_accession3',
			'col_number'  => 3,
			'row_number'  => 'A',
			'is_blank'    => 0
		}
	};

	is_deeply($design, $igd_design_check, "check igd design");

	#genotyping project for igd
	my $fhado_schema = $f->bcs_schema;
	my $location_rs = $fhado_schema->resultset('NaturalDiversity::NdGeolocation')->search({ description => 'Cornell Biotech' });
	my $location_id = $location_rs->first->nd_geolocation_id;

	my $bp_rs = $fhado_schema->resultset('Project::Project')->find({ name => 'test' });
	my $breeding_program_id = $bp_rs->project_id();

	my $add_genotyping_project = CXGN::Genotype::StoreGenotypingProject->new({
		chado_schema        => $fhado_schema,
		dbh                 => $f->dbh(),
		project_name        => 'test_genotyping_project_2',
		breeding_program_id => $breeding_program_id,
		project_facility    => 'igd',
		data_type           => 'snp',
		year                => '2022',
		project_description => 'genotyping project for test',
		nd_geolocation_id   => $location_id,
		owner_id            => 41
	});
	ok(my $store_return = $add_genotyping_project->store_genotyping_project(), "store genotyping project");

	my $gp_rs = $fhado_schema->resultset('Project::Project')->find({ name => 'test_genotyping_project_2' });
	my $genotyping_project_id = $gp_rs->project_id();
	my $trial = CXGN::Trial->new({ bcs_schema => $fhado_schema, trial_id => $genotyping_project_id });

	#editing genotyping project details
	my $new_year = '2021';
	my $new_description = 'new genotyping project for test';
	$trial->set_year($new_year);
	$trial->set_description($new_description);

	my $location_data = $trial->get_location();
	my $location_name = $location_data->[1];
	my $description = $trial->get_description();
	my $genotyping_facility = $trial->get_genotyping_facility();
	my $plate_year = $trial->get_year();
	is($plate_year, '2021');
	is($description, 'new genotyping project for test');

	my $program_object = CXGN::BreedersToolbox::Projects->new({ schema => $fhado_schema });
	my $breeding_program_data = $program_object->get_breeding_programs_by_trial($genotyping_project_id);
	my $breeding_program_name = $breeding_program_data->[0]->[1];

	my $trial_create = CXGN::Trial::TrialCreate
		->new({
		chado_schema                  => $fhado_schema,
		dbh                           => $f->dbh(),
		owner_id                      => 41,
		trial_year                    => $plate_year,
		trial_location                => $location_name,
		program                       => $breeding_program_name,
		trial_description             => "Test Genotyping Plate Upload",
		design_type                   => 'genotyping_plate',
		design                        => $design,
		trial_name                    => "test_genotyping_trial_upload",
		is_genotyping                 => 1,
		genotyping_user_id            => $meta->{user_id} || "unknown",
		genotyping_project_id         => $genotyping_project_id,
		genotyping_facility_submitted => 'no',
		genotyping_facility           => $genotyping_facility,
		genotyping_plate_format       => '96',
		genotyping_plate_sample_type  => 'DNA',
		operator                      => "janedoe"
	});

	my $save = $trial_create->save_trial();

	ok($save->{'trial_id'}, "check that trial_create worked");
	my $project_name = $f->bcs_schema()->resultset('Project::Project')->search({}, { order_by => { -desc => 'project_id' } })->first()->name();
	ok($project_name == "test_genotyping_trial_upload", "check that trial_create really worked for igd trial");

	my $project_desc = $f->bcs_schema()->resultset('Project::Project')->search({}, { order_by => { -desc => 'project_id' } })->first()->description();
	ok($project_desc == "Test Genotyping Plate Upload", "check that trial_create really worked for igd trial");

	$post_project_count = $f->bcs_schema->resultset('Project::Project')->search({})->count();
	my $post2_project_diff = $post_project_count - $pre_project_count;
	print STDERR "Project: " . $post2_project_diff . "\n";
	ok($post2_project_diff == 3, "check project table after upload igd trial");

	$post_nd_experiment_count = $f->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search({})->count();
	my $post2_nd_experiment_diff = $post_nd_experiment_count - $pre_nd_experiment_count;
	print STDERR "NdExperiment: " . $post2_nd_experiment_diff . "\n";
	ok($post2_nd_experiment_diff == 2, "check ndexperiment table after upload igd trial");

	$post_nd_experiment_proj_count = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentProject')->search({})->count();
	my $post2_nd_experiment_proj_diff = $post_nd_experiment_proj_count - $pre_nd_experiment_proj_count;
	print STDERR "NdExperimentProject: " . $post2_nd_experiment_proj_diff . "\n";
	ok($post2_nd_experiment_proj_diff == 2, "check ndexperimentproject table after upload igd trial");

	$post_nd_experimentprop_count = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentprop')->search({})->count();
	my $post2_nd_experimentprop_diff = $post_nd_experimentprop_count - $pre_nd_experimentprop_count;
	print STDERR "NdExperimentprop: " . $post2_nd_experimentprop_diff . "\n";
	ok($post2_nd_experimentprop_diff == 1, "check ndexperimentprop table after upload igd trial");

	$post_project_prop_count = $f->bcs_schema->resultset('Project::Projectprop')->search({})->count();
	my $post2_project_prop_diff = $post_project_prop_count - $pre_project_prop_count;
	print STDERR "Projectprop: " . $post2_project_prop_diff . "\n";
	ok($post2_project_prop_diff == 15, "check projectprop table after adding genotyping project and uploading igd trial");

	$post_stock_count = $f->bcs_schema->resultset('Stock::Stock')->search({})->count();
	my $post2_stock_diff = $post_stock_count - $pre_stock_count;
	print STDERR "Stock: " . $post2_stock_diff . "\n";
	ok($post2_stock_diff == 14, "check stock table after upload igd trial");

	$post_stock_prop_count = $f->bcs_schema->resultset('Stock::Stockprop')->search({})->count();
	my $post2_stock_prop_diff = $post_stock_prop_count - $pre_stock_prop_count;
	print STDERR "Stockprop: " . $post2_stock_prop_diff . "\n";
	ok($post2_stock_prop_diff == 84, "check stockprop table after upload igd trial");

	$post_stock_relationship_count = $f->bcs_schema->resultset('Stock::StockRelationship')->search({})->count();
	my $post2_stock_relationship_diff = $post_stock_relationship_count - $pre_stock_relationship_count;
	print STDERR "StockRelationship: " . $post2_stock_relationship_diff . "\n";
	ok($post2_stock_relationship_diff == 14, "check stockrelationship table after upload igd trial");

	$post_nd_experiment_stock_count = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentStock')->search({})->count();
	my $post2_nd_experiment_stock_diff = $post_nd_experiment_stock_count - $pre_nd_experiment_stock_count;
	print STDERR "NdExperimentStock: " . $post2_nd_experiment_stock_diff . "\n";
	ok($post2_nd_experiment_stock_diff == 14, "check ndexperimentstock table after upload igd trial");

	$post_project_relationship_count = $f->bcs_schema->resultset('Project::ProjectRelationship')->search({})->count();
	my $post2_project_relationship_diff = $post_project_relationship_count - $pre_project_relationship_count;
	print STDERR "ProjectRelationship: " . $post2_project_relationship_diff . "\n";
	ok($post2_project_relationship_diff == 4, "check projectrelationship table after adding genotyping project and uploading igd trial");


	#############################
	# Upload a trial with seedlot info filled

	my %upload_metadata;
	my $file_name = "t/data/trial/trial_layout_with_seedlot_example.$extension";
	my $time = DateTime->now();
	my $timestamp = $time->ymd() . "_" . $time->hms();

	#Test archive upload file
	my $uploader = CXGN::UploadFile->new({
		tempfile         => $file_name,
		subdirectory     => 'temp_trial_upload',
		archive_path     => '/tmp',
		archive_filename => "trial_layout_with_seedlot_example.$extension",
		timestamp        => $timestamp,
		user_id          => 41, #janedoe in fixture
		user_role        => 'curator'
	});

	## Store uploaded temporary file in archive
	my $archived_filename_with_path = $uploader->archive();
	my $md5 = $uploader->get_md5($archived_filename_with_path);
	ok($archived_filename_with_path);
	ok($md5);

	$upload_metadata{'archived_file'} = $archived_filename_with_path;
	$upload_metadata{'archived_file_type'} = "trial upload file";
	$upload_metadata{'user_id'} = 41;
	$upload_metadata{'date'} = "2014-02-14_09:10:11";


	#parse uploaded file with appropriate plugin
	$parser = CXGN::Trial::ParseUpload->new(chado_schema => $f->bcs_schema(), filename => $archived_filename_with_path);
	$parser->load_plugin('TrialGeneric');
	$rtn = $parser->parse();
	$parsed_data = $rtn->{'design'};
	ok($parsed_data, "Check if parse validate excel file works");
	ok(!$parser->has_parse_errors(), "Check that parse returns no errors");

	#print STDERR Dumper $parsed_data;

	my $parsed_data_check = {
		'8' => {
			'is_a_control'              => 0,
			'num_seed_per_plot'         => '12',
			'block_number'              => '2',
			'rep_number'                => '1',
			'col_number'                => '2',
			'plot_name'                 => 'plot_with_seedlot_name7',
			'stock_name'                => 'test_accession4',
			'seedlot_name'              => 'test_accession4_001',
			'plot_number'               => '7',
			'range_number'              => '2',
			'weight_gram_seed_per_plot' => 0,
			'row_number'                => '3'
		},
		'5' => {
			'row_number'                => '4',
			'weight_gram_seed_per_plot' => '5',
			'range_number'              => '1',
			'seedlot_name'              => 'test_accession2_001',
			'plot_number'               => '4',
			'rep_number'                => '2',
			'num_seed_per_plot'         => '12',
			'block_number'              => '1',
			'is_a_control'              => 0,
			'stock_name'                => 'test_accession2',
			'plot_name'                 => 'plot_with_seedlot_name4',
			'col_number'                => '1'
		},
		'2' => {
			'row_number'                => '1',
			'weight_gram_seed_per_plot' => 0,
			'range_number'              => '1',
			'seedlot_name'              => 'test_accession1_001',
			'plot_number'               => '1',
			'rep_number'                => '1',
			'num_seed_per_plot'         => '12',
			'block_number'              => '1',
			'is_a_control'              => 0,
			'stock_name'                => 'test_accession1',
			'plot_name'                 => 'plot_with_seedlot_name1',
			'col_number'                => '1'
		},
		'6' => {
			'range_number'              => '2',
			'row_number'                => '1',
			'weight_gram_seed_per_plot' => 0,
			'plot_number'               => '5',
			'seedlot_name'              => 'test_accession3_001',
			'plot_name'                 => 'plot_with_seedlot_name5',
			'col_number'                => '2',
			'stock_name'                => 'test_accession3',
			'rep_number'                => '1',
			'is_a_control'              => 0,
			'num_seed_per_plot'         => '12',
			'block_number'              => '2'
		},
		'3' => {
			'block_number'              => '1',
			'num_seed_per_plot'         => '12',
			'is_a_control'              => 0,
			'rep_number'                => '2',
			'stock_name'                => 'test_accession1',
			'col_number'                => '1',
			'plot_name'                 => 'plot_with_seedlot_name2',
			'plot_number'               => '2',
			'seedlot_name'              => 'test_accession1_001',
			'row_number'                => '2',
			'weight_gram_seed_per_plot' => 0,
			'range_number'              => '1'
		},
		'4' => {
			'weight_gram_seed_per_plot' => '4',
			'row_number'                => '3',
			'range_number'              => '1',
			'plot_number'               => '3',
			'seedlot_name'              => 'test_accession2_001',
			'rep_number'                => '1',
			'block_number'              => '1',
			'num_seed_per_plot'         => '12',
			'is_a_control'              => 0,
			'stock_name'                => 'test_accession2',
			'plot_name'                 => 'plot_with_seedlot_name3',
			'col_number'                => '1'
		},
		'7' => {
			'col_number'                => '2',
			'plot_name'                 => 'plot_with_seedlot_name6',
			'stock_name'                => 'test_accession3',
			'is_a_control'              => 0,
			'num_seed_per_plot'         => '12',
			'block_number'              => '2',
			'rep_number'                => '2',
			'seedlot_name'              => 'test_accession3_001',
			'plot_number'               => '6',
			'range_number'              => '2',
			'row_number'                => '2',
			'weight_gram_seed_per_plot' => 0
		},
		'9' => {
			'seedlot_name'              => 'test_accession4_001',
			'plot_number'               => '8',
			'weight_gram_seed_per_plot' => 0,
			'row_number'                => '4',
			'range_number'              => '2',
			'block_number'              => '2',
			'num_seed_per_plot'         => '12',
			'is_a_control'              => 0,
			'rep_number'                => '2',
			'stock_name'                => 'test_accession4',
			'col_number'                => '2',
			'plot_name'                 => 'plot_with_seedlot_name8'
		}
	};

	is_deeply($parsed_data, $parsed_data_check, 'check trial excel parse data');

	my $trial_create = CXGN::Trial::TrialCreate
		->new({
		chado_schema      => $f->bcs_schema(),
		dbh               => $f->dbh(),
		owner_id          => 41,
		trial_year        => "2016",
		trial_description => "Trial Upload Test",
		trial_location    => "test_location",
		trial_name        => "Trial_upload_with_seedlot_test",
		design_type       => "RCBD",
		design            => $parsed_data,
		program           => "test",
		upload_trial_file => $archived_filename_with_path,
		operator          => "janedoe"
	});

	$trial_create->save_trial();

	ok($trial_create, "check that trial_create worked");
	my $project_name = $f->bcs_schema()->resultset('Project::Project')->search({}, { order_by => { -desc => 'project_id' } })->first()->name();
	ok($project_name == "Trial_upload_test", "check that trial_create really worked");

	my $project_desc = $f->bcs_schema()->resultset('Project::Project')->search({}, { order_by => { -desc => 'project_id' } })->first()->description();
	ok($project_desc == "Trial Upload Test", "check that trial_create really worked");

	my $post_project_count = $f->bcs_schema->resultset('Project::Project')->search({})->count();
	my $post1_project_diff = $post_project_count - $pre_project_count;
	print STDERR "Project: " . $post1_project_diff . "\n";
	ok($post1_project_diff == 4, "check project table after third upload excel trial");

	my $post_nd_experiment_count = $f->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search({})->count();
	my $post1_nd_experiment_diff = $post_nd_experiment_count - $pre_nd_experiment_count;
	print STDERR "NdExperiment: " . $post1_nd_experiment_diff . "\n";
	ok($post1_nd_experiment_diff == 3, "check ndexperiment table after upload excel trial");

	my $post_nd_experiment_proj_count = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentProject')->search({})->count();
	my $post1_nd_experiment_proj_diff = $post_nd_experiment_proj_count - $pre_nd_experiment_proj_count;
	print STDERR "NdExperimentProject: " . $post1_nd_experiment_proj_diff . "\n";
	ok($post1_nd_experiment_proj_diff == 3, "check ndexperimentproject table after upload excel trial");

	my $post_nd_experimentprop_count = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentprop')->search({})->count();
	my $post1_nd_experimentprop_diff = $post_nd_experimentprop_count - $pre_nd_experimentprop_count;
	print STDERR "NdExperimentprop: " . $post1_nd_experimentprop_diff . "\n";
	ok($post1_nd_experimentprop_diff == 1, "check ndexperimentprop table after upload excel trial");

	my $post_project_prop_count = $f->bcs_schema->resultset('Project::Projectprop')->search({})->count();
	my $post1_project_prop_diff = $post_project_prop_count - $pre_project_prop_count;
	print STDERR "Projectprop: " . $post1_project_prop_diff . "\n";
	ok($post1_project_prop_diff == 19, "check projectprop table after upload excel trial");

	my $post_stock_count = $f->bcs_schema->resultset('Stock::Stock')->search({})->count();
	my $post1_stock_diff = $post_stock_count - $pre_stock_count;
	print STDERR "Stock: " . $post1_stock_diff . "\n";
	ok($post1_stock_diff == 22, "check stock table after upload excel trial");

	my $post_stock_prop_count = $f->bcs_schema->resultset('Stock::Stockprop')->search({})->count();
	my $post1_stock_prop_diff = $post_stock_prop_count - $pre_stock_prop_count;
	print STDERR "Stockprop: " . $post1_stock_prop_diff . "\n";
	#ok($post1_stock_prop_diff == 133, "check stockprop table after upload excel trial");

	my $post_stock_relationship_count = $f->bcs_schema->resultset('Stock::StockRelationship')->search({})->count();
	my $post1_stock_relationship_diff = $post_stock_relationship_count - $pre_stock_relationship_count;
	print STDERR "StockRelationship: " . $post1_stock_relationship_diff . "\n";
	ok($post1_stock_relationship_diff == 30, "check stockrelationship table after upload excel trial");

	my $post_nd_experiment_stock_count = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentStock')->search({})->count();
	my $post1_nd_experiment_stock_diff = $post_nd_experiment_stock_count - $pre_nd_experiment_stock_count;
	print STDERR "NdExperimentStock: " . $post1_nd_experiment_stock_diff . "\n";
	ok($post1_nd_experiment_stock_diff == 22, "check ndexperimentstock table after upload excel trial");

	my $post_project_relationship_count = $f->bcs_schema->resultset('Project::ProjectRelationship')->search({})->count();
	my $post1_project_relationship_diff = $post_project_relationship_count - $pre_project_relationship_count;
	print STDERR "ProjectRelationship: " . $post1_project_relationship_diff . "\n";
	ok($post1_project_relationship_diff == 5, "check projectrelationship table after upload excel trial");

	#adding new genotyping project
	my $add_genotyping_project_2 = CXGN::Genotype::StoreGenotypingProject->new({
		chado_schema        => $fhado_schema,
		dbh                 => $f->dbh(),
		project_name        => 'test_genotyping_project_4',
		breeding_program_id => $breeding_program_id,
		project_facility    => 'igd',
		data_type           => 'snp',
		year                => '2022',
		project_description => 'genotyping project for test',
		nd_geolocation_id   => $location_id,
		owner_id            => 41
	});
	ok(my $store_return_2 = $add_genotyping_project_2->store_genotyping_project(), "store genotyping project");

	my $gp_rs_2 = $fhado_schema->resultset('Project::Project')->find({ name => 'test_genotyping_project_4' });
	my $genotyping_project_id_2 = $gp_rs_2->project_id();

	my $mech = Test::WWW::Mechanize->new;
	$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username" => "janedoe", "password" => "secretpw", "grant_type" => "password" ]);
	my $response = decode_json $mech->content;
	print STDERR Dumper $response;
	my $sgn_session_id = $response->{access_token};
	print STDERR $sgn_session_id . "\n";

	# Genotype trial upload does not yet support CSV files
	if ( $extension ne 'csv' ) {
		my $file = $f->config->{basepath} . "/t/data/genotype_trial_upload/genotype_trial_upload.$extension";
		my $ua = LWP::UserAgent->new;
		$response = $ua->post(
			'http://localhost:3010/ajax/breeders/parsegenotypetrial',
			Content_Type => 'form-data',
			Content      => [
				genotyping_trial_layout_upload => [
					$file,
					"genotype_trial_upload.$extension",
					Content_Type => ($extension eq "xls") ? 'application/vnd.ms-excel' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
				],
				"sgn_session_id"               => $sgn_session_id,
				"genotyping_trial_name"        => '2018TestPlate02'
			]
		);

		ok($response->is_success);
		my $message = $response->decoded_content;
		my $message_hash = decode_json $message;

		is_deeply($message_hash, {
			'success' => '1',
			'design'  => {
				'A01' => {
					'concentration'       => '5',
					'acquisition_date'    => '2018/02/16',
					'dna_person'          => 'nmorales',
					'volume'              => '10',
					'col_number'          => '1',
					'plot_name'           => '2018TestPlate02_A01',
					'ncbi_taxonomy_id'    => '9001',
					'stock_name'          => 'KASESE_TP2013_885',
					'notes'               => 'test well A01',
					'is_blank'            => 0,
					'extraction'          => 'CTAB',
					'plot_number'         => 'A01',
					'row_number'          => 'A',
					'tissue_type'         => 'leaf',
					'facility_identifier' => undef
				},
				'A03' => {
					'notes'               => 'test well A03',
					'is_blank'            => 0,
					'stock_name'          => 'KASESE_TP2013_1671',
					'ncbi_taxonomy_id'    => '9001',
					'plot_name'           => '2018TestPlate02_A03',
					'tissue_type'         => 'leaf',
					'row_number'          => 'A',
					'plot_number'         => 'A03',
					'extraction'          => 'CTAB',
					'volume'              => '10',
					'dna_person'          => 'nmorales',
					'concentration'       => '5',
					'acquisition_date'    => '2018/02/16',
					'col_number'          => '3',
					'facility_identifier' => undef
				},
				'A02' => {
					'extraction'          => undef,
					'plot_number'         => 'A02',
					'row_number'          => 'A',
					'tissue_type'         => 'stem',
					'stock_name'          => 'BLANK',
					'notes'               => 'test blank',
					'is_blank'            => 1,
					'ncbi_taxonomy_id'    => undef,
					'plot_name'           => '2018TestPlate02_A02',
					'col_number'          => '2',
					'volume'              => undef,
					'acquisition_date'    => '2018/02/16',
					'concentration'       => undef,
					'dna_person'          => 'nmorales',
					'facility_identifier' => undef
				}
			}
		});

		my $project = $f->bcs_schema()->resultset("Project::Project")->find({ name => 'test' });
		my $location = $f->bcs_schema()->resultset("NaturalDiversity::NdGeolocation")->find({ description => 'test_location' });

		my $plate_data = {
			design                     => $message_hash->{design},
			genotyping_facility_submit => 'yes',
			name                       => 'test_genotype_upload_trial1',
			genotyping_project_id      => $genotyping_project_id_2,
			sample_type                => 'DNA',
			plate_format               => '96'
		};

		$mech->post_ok('http://localhost:3010/ajax/breeders/storegenotypetrial', [ "sgn_session_id" => $sgn_session_id, plate_data => encode_json($plate_data) ]);
		$response = decode_json $mech->content;
		#print STDERR Dumper $response;

		ok($response->{trial_id});
	}

	my $file = $f->config->{basepath} . "/t/data/genotype_trial_upload/CoordinateTemplate.csv";
	my $ua = LWP::UserAgent->new;
	$response = $ua->post(
		'http://localhost:3010/ajax/breeders/parsegenotypetrial',
		Content_Type => 'form-data',
		Content      => [
			genotyping_trial_layout_upload_coordinate_template => [ $file, 'genotype_trial_upload', Content_Type => 'application/vnd.ms-excel', ],
			"sgn_session_id"                                   => $sgn_session_id,
			"genotyping_trial_name"                            => "18DNA00101"
		]
	);

	#print STDERR Dumper $response;
	ok($response->is_success);
	my $message = $response->decoded_content;
	my $message_hash = decode_json $message;
	#print STDERR Dumper $message_hash;

	is_deeply($message_hash, {
		'success' => '1',
		'design'  => {
			'B12' => {
				'notes'               => 'newplate',
				'ncbi_taxonomy_id'    => 'NA',
				'dna_person'          => 'gbauchet',
				'is_blank'            => 1,
				'concentration'       => 'NA',
				'plot_number'         => 'B12',
				'volume'              => 'NA',
				'tissue_type'         => 'leaf',
				'plot_name'           => '18DNA00101_B12',
				'extraction'          => 'NA',
				'row_number'          => 'B',
				'col_number'          => '12',
				'acquisition_date'    => '8/23/2018',
				'stock_name'          => 'BLANK',
				'facility_identifier' => undef
			},
			'A01' => {
				'stock_name'          => 'KASESE_TP2013_1671',
				'acquisition_date'    => '8/23/2018',
				'col_number'          => '01',
				'row_number'          => 'A',
				'extraction'          => 'NA',
				'plot_name'           => '18DNA00101_A01',
				'tissue_type'         => 'leaf',
				'plot_number'         => 'A01',
				'volume'              => 'NA',
				'dna_person'          => 'gbauchet',
				'is_blank'            => 0,
				'concentration'       => 'NA',
				'ncbi_taxonomy_id'    => 'NA',
				'notes'               => 'newplate',
				'facility_identifier' => undef
			},
			'B01' => {
				'plot_name'           => '18DNA00101_B01',
				'extraction'          => 'NA',
				'row_number'          => 'B',
				'col_number'          => '01',
				'stock_name'          => 'KASESE_TP2013_1671',
				'acquisition_date'    => '8/23/2018',
				'ncbi_taxonomy_id'    => 'NA',
				'notes'               => 'newplate',
				'dna_person'          => 'gbauchet',
				'is_blank'            => 0,
				'concentration'       => 'NA',
				'plot_number'         => 'B01',
				'volume'              => 'NA',
				'tissue_type'         => 'leaf',
				'facility_identifier' => undef
			},
			'C01' => {
				'col_number'          => '01',
				'acquisition_date'    => '8/23/2018',
				'stock_name'          => 'KASESE_TP2013_885',
				'extraction'          => 'NA',
				'row_number'          => 'C',
				'plot_name'           => '18DNA00101_C01',
				'tissue_type'         => 'leaf',
				'is_blank'            => 0,
				'dna_person'          => 'gbauchet',
				'concentration'       => 'NA',
				'plot_number'         => 'C01',
				'volume'              => 'NA',
				'ncbi_taxonomy_id'    => 'NA',
				'notes'               => 'newplate',
				'facility_identifier' => undef
			},
			'D01' => {
				'ncbi_taxonomy_id'    => 'NA',
				'notes'               => 'newplate',
				'plot_number'         => 'D01',
				'volume'              => 'NA',
				'dna_person'          => 'gbauchet',
				'is_blank'            => 0,
				'concentration'       => 'NA',
				'tissue_type'         => 'leaf',
				'plot_name'           => '18DNA00101_D01',
				'row_number'          => 'D',
				'extraction'          => 'NA',
				'acquisition_date'    => '8/23/2018',
				'stock_name'          => 'KASESE_TP2013_885',
				'col_number'          => '01',
				'facility_identifier' => undef
			}
		}
	}, 'test upload parse of coordinate genotyping plate');

	my $plate_data = {
		design                     => $message_hash->{design},
		genotyping_facility_submit => 'no',
		name                       => 'test_genotype_upload_coordinate_trial101',
		genotyping_project_id      => $genotyping_project_id_2,
		sample_type                => 'DNA',
		plate_format               => '96'
	};


	$mech->post_ok('http://localhost:3010/ajax/breeders/storegenotypetrial', [ "sgn_session_id" => $sgn_session_id, plate_data => encode_json($plate_data) ]);
	$response = decode_json $mech->content;
	#print STDERR Dumper $response;

	ok($response->{trial_id});

	my $file = $f->config->{basepath} . "/t/data/genotype_trial_upload/CoordinatePlateUpload.csv";
	my $ua = LWP::UserAgent->new;
	$response = $ua->post(
		'http://localhost:3010/ajax/breeders/parsegenotypetrial',
		Content_Type => 'form-data',
		Content      => [
			genotyping_trial_layout_upload_coordinate => [ $file, 'genotype_trial_upload', Content_Type => 'application/vnd.ms-excel', ],
			"sgn_session_id"                          => $sgn_session_id,
			"genotyping_trial_name"                   => "18DNA00001"
		]
	);

	#print STDERR Dumper $response;
	ok($response->is_success);
	my $message = $response->decoded_content;
	my $message_hash = decode_json $message;
	#print STDERR Dumper $message_hash;

	is_deeply($message_hash, {
		'design'  => {
			'B01' => {
				'ncbi_taxonomy_id'    => 'NA',
				'is_blank'            => 0,
				'acquisition_date'    => '2018-02-06',
				'plot_name'           => '18DNA00001_B01',
				'col_number'          => '01',
				'notes'               => '',
				'extraction'          => 'CTAB',
				'tissue_type'         => 'leaf',
				'volume'              => 'NA',
				'concentration'       => 'NA',
				'stock_name'          => 'test_accession1',
				'plot_number'         => 'B01',
				'row_number'          => 'B',
				'dna_person'          => 'Trevor_Rife',
				'facility_identifier' => undef
			},
			'B04' => {
				'tissue_type'         => 'leaf',
				'extraction'          => 'CTAB',
				'notes'               => '',
				'col_number'          => '04',
				'acquisition_date'    => '2018-02-06',
				'plot_name'           => '18DNA00001_B04',
				'ncbi_taxonomy_id'    => 'NA',
				'is_blank'            => 1,
				'row_number'          => 'B',
				'dna_person'          => 'Trevor_Rife',
				'plot_number'         => 'B04',
				'stock_name'          => 'BLANK',
				'concentration'       => 'NA',
				'volume'              => 'NA',
				'facility_identifier' => undef
			},
			'C01' => {
				'is_blank'            => 0,
				'ncbi_taxonomy_id'    => 'NA',
				'plot_name'           => '18DNA00001_C01',
				'acquisition_date'    => '2018-02-06',
				'notes'               => '',
				'col_number'          => '01',
				'extraction'          => 'CTAB',
				'tissue_type'         => 'leaf',
				'volume'              => 'NA',
				'concentration'       => 'NA',
				'stock_name'          => 'test_accession2',
				'plot_number'         => 'C01',
				'dna_person'          => 'Trevor_Rife',
				'row_number'          => 'C',
				'facility_identifier' => undef
			},
			'C04' => {
				'ncbi_taxonomy_id'    => 'NA',
				'is_blank'            => 1,
				'plot_name'           => '18DNA00001_C04',
				'acquisition_date'    => '2018-02-06',
				'notes'               => '',
				'col_number'          => '04',
				'tissue_type'         => 'leaf',
				'extraction'          => 'CTAB',
				'volume'              => 'NA',
				'stock_name'          => 'BLANK',
				'concentration'       => 'NA',
				'plot_number'         => 'C04',
				'dna_person'          => 'Trevor_Rife',
				'row_number'          => 'C',
				'facility_identifier' => undef
			},
			'A01' => {
				'is_blank'            => 0,
				'ncbi_taxonomy_id'    => 'NA',
				'acquisition_date'    => '2018-02-06',
				'plot_name'           => '18DNA00001_A01',
				'notes'               => '',
				'col_number'          => '01',
				'extraction'          => 'CTAB',
				'tissue_type'         => 'leaf',
				'volume'              => 'NA',
				'concentration'       => 'NA',
				'stock_name'          => 'test_accession1',
				'plot_number'         => 'A01',
				'dna_person'          => 'Trevor_Rife',
				'row_number'          => 'A',
				'facility_identifier' => undef
			},
			'D01' => {
				'dna_person'          => 'Trevor_Rife',
				'row_number'          => 'D',
				'plot_number'         => 'D01',
				'stock_name'          => 'test_accession2',
				'concentration'       => 'NA',
				'volume'              => 'NA',
				'tissue_type'         => 'leaf',
				'extraction'          => 'CTAB',
				'col_number'          => '01',
				'notes'               => '',
				'acquisition_date'    => '2018-02-06',
				'plot_name'           => '18DNA00001_D01',
				'ncbi_taxonomy_id'    => 'NA',
				'is_blank'            => 0,
				'facility_identifier' => undef
			}
		},
		'success' => '1'
	}, 'test upload parse of coordinate genotyping plate');

	my $plate_data = {
		design                     => $message_hash->{design},
		genotyping_facility_submit => 'no',
		name                       => 'test_genotype_upload_coordinate_trial1',
		genotyping_project_id      => $genotyping_project_id,
		sample_type                => 'DNA',
		plate_format               => '96'
	};

	$mech->post_ok('http://localhost:3010/ajax/breeders/storegenotypetrial', [ "sgn_session_id" => $sgn_session_id, plate_data => encode_json($plate_data) ]);
	$response = decode_json $mech->content;
	#print STDERR "RESPONSE: ".Dumper $response;

	ok($response->{trial_id});
	my $geno_trial_id = $response->{trial_id};
	$mech->get_ok("http://localhost:3010/breeders/trial/$geno_trial_id/download/layout?format=intertekxls&dataLevel=plate");
	my $intertek_download = $mech->content;
	my $fontents = ReadData $intertek_download;
	#print STDERR Dumper $fontents;
	is($fontents->[0]->{'type'}, 'xls', "check that type of file is correct #1");
	is($fontents->[0]->{'sheets'}, '1', "check that type of file is correct #2");

	my $folumns = $fontents->[1]->{'cell'};
	#print STDERR Dumper scalar(@$folumns);
	ok(scalar(@$folumns) == 7, "check number of col in created file.");

	#print STDERR Dumper $folumns;
	is_deeply($folumns, [
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
			'Notes:  AcquisitionDate: 2018-02-06 Concentration: NA Volume: NA TissueType: leaf Person: Trevor_Rife Extraction: CTAB Facility Identifier: ',
			'Notes:  AcquisitionDate: 2018-02-06 Concentration: NA Volume: NA TissueType: leaf Person: Trevor_Rife Extraction: CTAB Facility Identifier: ',
			'Notes:  AcquisitionDate: 2018-02-06 Concentration: NA Volume: NA TissueType: leaf Person: Trevor_Rife Extraction: CTAB Facility Identifier: ',
			'Notes:  AcquisitionDate: 2018-02-06 Concentration: NA Volume: NA TissueType: leaf Person: Trevor_Rife Extraction: CTAB Facility Identifier: ',
			'Notes:  AcquisitionDate: 2018-02-06 Concentration: NA Volume: NA TissueType: leaf Person: Trevor_Rife Extraction: CTAB Facility Identifier: ',
			'Notes:  AcquisitionDate: 2018-02-06 Concentration: NA Volume: NA TissueType: leaf Person: Trevor_Rife Extraction: CTAB Facility Identifier: '
		]
	], 'test intertek genotyping plate download');

	$mech->get_ok("http://localhost:3010/breeders/trial/$geno_trial_id/download/layout?format=dartseqcsv&dataLevel=plate");
	my $intertek_download = $mech->content;
	#print STDERR Dumper $intertek_download;
	my @intertek_download = split "\n", $intertek_download;
	#print STDERR Dumper \@intertek_download;

	is_deeply(\@intertek_download, [
		'PlateID,Row,Column,Organism,Species,Genotype,Tissue,Comments',
		'test_genotype_upload_coordinate_trial1,A,01,tomato,"Solanum lycopersicum",18DNA00001_A01|||test_accession1,leaf,"Notes: NA AcquisitionDate: 2018-02-06 Concentration: NA Volume: NA Person: Trevor_Rife Extraction: CTAB Facility Identifier: NA"',
		'test_genotype_upload_coordinate_trial1,B,01,tomato,"Solanum lycopersicum",18DNA00001_B01|||test_accession1,leaf,"Notes: NA AcquisitionDate: 2018-02-06 Concentration: NA Volume: NA Person: Trevor_Rife Extraction: CTAB Facility Identifier: NA"',
		'test_genotype_upload_coordinate_trial1,C,01,tomato,"Solanum lycopersicum",18DNA00001_C01|||test_accession2,leaf,"Notes: NA AcquisitionDate: 2018-02-06 Concentration: NA Volume: NA Person: Trevor_Rife Extraction: CTAB Facility Identifier: NA"',
		'test_genotype_upload_coordinate_trial1,D,01,tomato,"Solanum lycopersicum",18DNA00001_D01|||test_accession2,leaf,"Notes: NA AcquisitionDate: 2018-02-06 Concentration: NA Volume: NA Person: Trevor_Rife Extraction: CTAB Facility Identifier: NA"'
	]);

	#treatment name will be test treatment|EXPERIMENT_TREATMENT:0000002

	ok(my $test_treatment = CXGN::Trait::Treatment->new({
		bcs_schema => $f->bcs_schema,
		name => 'test treatment',
		definition => 'A dummy treatment object to run fixture tests.',
		format => 'numeric'
	}), 'create a test treatment');

	my $exp_treatment_root_term = 'Experimental treatment ontology|EXPERIMENT_TREATMENT:0000000';

	ok(my $test_treatment_row = $test_treatment->store($exp_treatment_root_term), 'store test treatment');

	ok($test_treatment_row->dbxref_id, "test treatment storage step should have worked");
	ok($test_treatment_row->name eq "test treatment", "test treatment storage step should have worked");
	ok($test_treatment_row->cvterm_id, "test treatment storage step should have worked");

	ok($test_treatment->display_name() eq 'test treatment|EXPERIMENT_TREATMENT:0000002', 'test treatment should have correct display name');

	$test_treatment_row = $f->bcs_schema->resultset("Cv::Cvterm")->find({
		cvterm_id => $test_treatment_row->cvterm_id()
	});

	ok($test_treatment_row->cvterm_id, "Make sure test treatment row was saved");
	ok($test_treatment_row->name eq "test treatment", "Make sure test treatment row was saved");
	

	#Upload trial with Treatments
	my $file_name_with_treatment = "t/data/trial/trial_layout_example_with_treatment.$extension";

	#Test archive upload file
	my $uploader = CXGN::UploadFile->new({
		tempfile         => $file_name_with_treatment,
		subdirectory     => 'temp_trial_upload',
		archive_path     => '/tmp',
		archive_filename => "trial_layout_example_with_treatment.$extension",
		timestamp        => $timestamp,
		user_id          => 41, #janedoe in fixture
		user_role        => 'curator'
	});

	## Store uploaded temporary file in archive
	my $treatment_archived_filename_with_path = $uploader->archive();
	my $md5_treatment = $uploader->get_md5($treatment_archived_filename_with_path);
	ok($treatment_archived_filename_with_path);
	ok($md5_treatment);

	$parser = CXGN::Trial::ParseUpload->new(chado_schema => $f->bcs_schema(), filename => $treatment_archived_filename_with_path);
	$parser->load_plugin('TrialGeneric');
	$rtn = $parser->parse();
	$parsed_data = $rtn->{'design'};
	ok($parsed_data, "Check if parse validate excel file works");
	ok(!$parser->has_parse_errors(), "Check that parse returns no errors");

	#print STDERR Dumper $parsed_data;

	my $parsed_data_check_with_treatment = {
		'8'          => {
			'plot_number'  => '7',
			'col_number'   => '2',
			'block_number' => '2',
			'rep_number'   => '1',
			'is_a_control' => 0,
			'stock_name'   => 'test_accession4',
			'row_number'   => '3',
			'range_number' => '2',
			'plot_name'    => 'trial_treatment_plot_name7'
		},
		'6'          => {
			'col_number'   => '2',
			'plot_number'  => '5',
			'rep_number'   => '1',
			'block_number' => '2',
			'is_a_control' => 0,
			'stock_name'   => 'test_accession3',
			'row_number'   => '1',
			'range_number' => '2',
			'plot_name'    => 'trial_treatment_plot_name5'
		},
		'4'          => {
			'block_number' => '1',
			'rep_number'   => '1',
			'plot_number'  => '3',
			'col_number'   => '1',
			'range_number' => '1',
			'plot_name'    => 'trial_treatment_plot_name3',
			'row_number'   => '3',
			'stock_name'   => 'test_accession2',
			'is_a_control' => 0
		},
		'5'          => {
			'stock_name'   => 'test_accession2',
			'is_a_control' => 0,
			'row_number'   => '4',
			'plot_name'    => 'trial_treatment_plot_name4',
			'range_number' => '1',
			'col_number'   => '1',
			'plot_number'  => '4',
			'block_number' => '1',
			'rep_number'   => '2'
		},
		'9'          => {
			'rep_number'   => '2',
			'block_number' => '2',
			'plot_number'  => '8',
			'col_number'   => '2',
			'row_number'   => '4',
			'range_number' => '2',
			'plot_name'    => 'trial_treatment_plot_name8',
			'stock_name'   => 'test_accession4',
			'is_a_control' => 0
		},
		'2'          => {
			'block_number' => '1',
			'rep_number'   => '1',
			'plot_number'  => '1',
			'col_number'   => '1',
			'is_a_control' => 0,
			'stock_name'   => 'test_accession1',
			'plot_name'    => 'trial_treatment_plot_name1',
			'range_number' => '1',
			'row_number'   => '1'
		},
		'3'          => {
			'plot_name'    => 'trial_treatment_plot_name2',
			'range_number' => '1',
			'row_number'   => '2',
			'stock_name'   => 'test_accession1',
			'is_a_control' => 0,
			'plot_number'  => '2',
			'col_number'   => '1',
			'block_number' => '1',
			'rep_number'   => '2'
		},
		# 'treatments' => {
		# 	'test treatment|EXPERIMENT_TREATMENT:0000002' => {
		# 		'new_treatment_stocks' => [
		# 			'trial_treatment_plot_name1',
		# 			'trial_treatment_plot_name2',
		# 			'trial_treatment_plot_name3',
		# 			'trial_treatment_plot_name4'
		# 		]
		# 	}
		# }, #this got moved to a different location in the hash
		'7'          => {
			'row_number'   => '2',
			'range_number' => '2',
			'plot_name'    => 'trial_treatment_plot_name6',
			'stock_name'   => 'test_accession3',
			'is_a_control' => 0,
			'plot_number'  => '6',
			'col_number'   => '2',
			'rep_number'   => '2',
			'block_number' => '2'
		}
	};

	is_deeply($parsed_data, $parsed_data_check_with_treatment, 'check trial excel parse data');

	my $trial_create_with_treatment = CXGN::Trial::TrialCreate->new({
		chado_schema      => $f->bcs_schema(),
		dbh               => $f->dbh(),
		trial_year        => "2016",
		trial_description => "Trial Upload Test with Treatments",
		trial_location    => "test_location",
		trial_name        => "Trial_upload_test_with_treatment",
		design_type       => "RCBD",
		design            => $parsed_data,
		program           => "test",
		upload_trial_file => $treatment_archived_filename_with_path,
		operator          => "janedoe",
		owner_id          => 41
	});

	my $save_with_treatment = $trial_create_with_treatment->save_trial();

	ok($save_with_treatment->{'trial_id'}, "check that trial_create worked with treatment");
	my $project_name_with_treatment = $f->bcs_schema()->resultset('Project::Project')->find({ project_id => $save_with_treatment->{'trial_id'} })->name();
	ok($project_name_with_treatment == "Trial_upload_test_with_treatment", "check that trial_create really worked");

	# my $trial_with_treatment = CXGN::Trial->new({ bcs_schema => $f->bcs_schema, trial_id => $save_with_treatment->{'trial_id'} });
	# my $treatments = $trial_with_treatment->get_treatments();
	# is(scalar(@$treatments), 1);

	# my $treatment_name1 = $treatments->[0]->{trait_name};
	# is($treatment_name1, "test treatment|EXPERIMENT_TREATMENT:0000002");
	# my $treatment_count1 = $treatments->[0]->{count};
	# is($treatment_count1, 4);
	# these tests don't work because treatments are stored separately after the trial design is stored. This functionality is tested elsewhere (in TrialCreate.t) and does not need to be tested here.
	# Checking that the trial design contained the treatment info is sufficient. 

	#test deleting genotyping project with genotyping plate
	my $schema = $f->bcs_schema();
	my $before_deleting_genotyping_project = $schema->resultset("Project::Project")->search({})->count();

	$mech->get_ok('http://localhost:3010/ajax/breeders/trial/' . $genotyping_project_id . '/delete/genotyping_project');
	$response = decode_json $mech->content;
	is($response->{'error'}, 'Cannot delete genotyping project with associated genotyping plates.');

	my $after_deleting_genotyping_project = $schema->resultset("Project::Project")->search({})->count();
	is($after_deleting_genotyping_project, $before_deleting_genotyping_project);

	#test deleting empty genotyping project
	#first deleting associated genotyping plates
	my $genotyping_plate_id_1 = $schema->resultset("Project::Project")->find({ name => 'test_genotyping_trial_upload' })->project_id;
	$mech->get_ok('http://localhost:3010/ajax/breeders/trial/' . $genotyping_plate_id_1 . '/delete/layout');
	$response = decode_json $mech->content;
	is($response->{'success'}, '1');

	my $genotyping_plate_id_4 = $schema->resultset("Project::Project")->find({ name => 'test_genotype_upload_coordinate_trial1' })->project_id;
	$mech->get_ok('http://localhost:3010/ajax/breeders/trial/' . $genotyping_plate_id_4 . '/delete/layout');
	$response = decode_json $mech->content;
	is($response->{'success'}, '1');

	#delete empty genotyping_project
	$mech->get_ok('http://localhost:3010/ajax/breeders/trial/' . $genotyping_project_id . '/delete/genotyping_project');
	$response = decode_json $mech->content;
	is($response->{'success'}, '1');

	my $after_deleting_empty_genotyping_project = $schema->resultset("Project::Project")->search({})->count();
	#deleting 2 associated genotyping plates and genotyping project
	is($after_deleting_empty_genotyping_project, $before_deleting_genotyping_project - 3);


	#Upload Trial with flexible column headers, entry Numbers, and auto generating plot names
	my %upload_metadata;
	my $file_name = "t/data/trial/trial_layout_example_flexible.$extension";
	my $time = DateTime->now();
	my $timestamp = $time->ymd() . "_" . $time->hms();
	my $trial_name = "Trial_upload_test_flexible";

	#Test archive upload file
	my $uploader = CXGN::UploadFile->new({
		tempfile         => $file_name,
		subdirectory     => 'temp_trial_upload',
		archive_path     => '/tmp',
		archive_filename => "trial_layout_example_flexible.$extension",
		timestamp        => $timestamp,
		user_id          => 41, #janedoe in fixture
		user_role        => 'curator'
	});

	## Store uploaded temporary file in archive
	my $archived_filename_with_path = $uploader->archive();
	my $md5 = $uploader->get_md5($archived_filename_with_path);
	ok($archived_filename_with_path);
	ok($md5);

	$upload_metadata{'archived_file'} = $archived_filename_with_path;
	$upload_metadata{'archived_file_type'} = "trial upload file";
	$upload_metadata{'user_id'} = 41;
	$upload_metadata{'date'} = "2014-02-14_09:10:11";

	#parse uploaded file with appropriate plugin
	$parser = CXGN::Trial::ParseUpload->new(chado_schema => $f->bcs_schema(), filename => $archived_filename_with_path, trial_name => $trial_name);
	$parser->load_plugin('TrialGeneric');
	my $p = $parser->parse();
	$parsed_data = $p->{'design'};
	my $entry_numbers = $p->{'entry_numbers'};
	ok($parsed_data, "Check if parse validate excel file works");
	ok(!$parser->has_parse_errors(), "Check that parse returns no errors");

	my $parsed_data_check = {
		'2' => {
			'plot_name'    => 'Trial_upload_test_flexible-PLOT_1',
			'stock_name'   => 'test_accession1',
			'col_number'   => '1',
			'is_a_control' => 0,
			'rep_number'   => '1',
			'block_number' => '1',
			'range_number' => '1',
			'row_number'   => '1',
			'plot_number'  => '1'
		},
		'7' => {
			'rep_number'   => '2',
			'is_a_control' => 0,
			'block_number' => '2',
			'plot_name'    => 'Trial_upload_test_flexible-PLOT_6',
			'stock_name'   => 'test_accession3',
			'col_number'   => '2',
			'range_number' => '2',
			'row_number'   => '2',
			'plot_number'  => '6'
		},
		'8' => {
			'range_number' => '2',
			'row_number'   => '3',
			'plot_number'  => '7',
			'plot_name'    => 'Trial_upload_test_flexible-PLOT_7',
			'stock_name'   => 'test_accession4',
			'col_number'   => '2',
			'rep_number'   => '1',
			'is_a_control' => 0,
			'block_number' => '2'
		},
		'5' => {
			'range_number' => '1',
			'plot_number'  => '4',
			'row_number'   => '4',
			'is_a_control' => 0,
			'rep_number'   => '2',
			'block_number' => '1',
			'plot_name'    => 'Trial_upload_test_flexible-PLOT_4',
			'col_number'   => '1',
			'stock_name'   => 'test_accession2'
		},
		'9' => {
			'range_number' => '2',
			'row_number'   => '4',
			'plot_number'  => '8',
			'plot_name'    => 'Trial_upload_test_flexible-PLOT_8',
			'stock_name'   => 'test_accession4',
			'col_number'   => '2',
			'rep_number'   => '2',
			'is_a_control' => 0,
			'block_number' => '2'
		},
		'3' => {
			'range_number' => '1',
			'plot_number'  => '2',
			'row_number'   => '2',
			'plot_name'    => 'Trial_upload_test_flexible-PLOT_2',
			'col_number'   => '1',
			'stock_name'   => 'test_accession1',
			'is_a_control' => 0,
			'rep_number'   => '2',
			'block_number' => '1'
		},
		'6' => {
			'range_number' => '2',
			'row_number'   => '1',
			'plot_number'  => '5',
			'plot_name'    => 'Trial_upload_test_flexible-PLOT_5',
			'stock_name'   => 'test_accession3',
			'col_number'   => '2',
			'is_a_control' => 0,
			'rep_number'   => '1',
			'block_number' => '2'
		},
		'4' => {
			'stock_name'   => 'test_accession2',
			'col_number'   => '1',
			'plot_name'    => 'Trial_upload_test_flexible-PLOT_3',
			'block_number' => '1',
			'is_a_control' => 0,
			'rep_number'   => '1',
			'row_number'   => '3',
			'plot_number'  => '3',
			'range_number' => '1'
		}
	};
	my $entry_numbers_check = {
		'test_accession4' => '4',
		'test_accession2' => '2',
		'test_accession3' => '3',
		'test_accession1' => '1'
	};

	is_deeply($parsed_data, $parsed_data_check, 'check trial excel parse data');
	is_deeply($entry_numbers, $entry_numbers_check, 'check trial excel entry numbers');

	my $trial_create = CXGN::Trial::TrialCreate
		->new({
		chado_schema      => $f->bcs_schema(),
		dbh               => $f->dbh(),
		owner_id          => 41,
		trial_year        => "2016",
		trial_description => "Trial Upload Test Flexible",
		trial_location    => "test_location",
		trial_name        => $trial_name,
		design_type       => "RCBD",
		design            => $parsed_data,
		program           => "test",
		upload_trial_file => $archived_filename_with_path,
		operator          => "janedoe"
	});

	my $save = $trial_create->save_trial();

	ok($save->{'trial_id'}, "check that trial_create worked");
	my $project_name = $f->bcs_schema()->resultset('Project::Project')->search({}, { order_by => { -desc => 'project_id' } })->first()->name();
	ok($project_name == $trial_name, "check that trial_create really worked");

	my $project_desc = $f->bcs_schema()->resultset('Project::Project')->search({}, { order_by => { -desc => 'project_id' } })->first()->description();
	ok($project_desc == "Trial Upload Test Flexible", "check that trial_create really worked");

	ok($test_treatment->delete(), "Test treatment deletion");

	$f->clean_up_db();
}

done_testing();
