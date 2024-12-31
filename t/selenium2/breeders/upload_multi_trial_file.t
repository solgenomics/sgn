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
use CXGN::BreedersToolbox::Projects;
use CXGN::Genotype::StoreGenotypingProject;
use DateTime;
use Test::WWW::Mechanize;
use LWP::UserAgent;
use JSON;
use Spreadsheet::Read;
use Text::CSV;

my $f = SGN::Test::Fixture->new();

for my $extension ("xlsx", "xls", "csv") {

    my $c = SimulateC->new({
		dbh 			=> $f->dbh(),
        bcs_schema      => $f->bcs_schema(),
        metadata_schema => $f->metadata_schema(),
        phenome_schema  => $f->phenome_schema(),
        sp_person_id    =>  41,
    });

    my $pre_project_count               = $c->bcs_schema->resultset('Project::Project')->search({})->count();
	my $pre_nd_experiment_count         = $c->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search({})->count();
	my $pre_nd_experimentprop_count     = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentprop')->search({})->count();
	my $pre_nd_experiment_proj_count    = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentProject')->search({})->count();
	my $pre_project_prop_count          = $c->bcs_schema->resultset('Project::Projectprop')->search({})->count();
	my $pre_stock_count                 = $c->bcs_schema->resultset('Stock::Stock')->search({})->count();
	my $pre_stock_prop_count            = $c->bcs_schema->resultset('Stock::Stockprop')->search({})->count();
	my $pre_stock_relationship_count    = $c->bcs_schema->resultset('Stock::StockRelationship')->search({})->count();
	my $pre_nd_experiment_stock_count   = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentStock')->search({})->count();
	my $pre_project_relationship_count  = $c->bcs_schema->resultset('Project::ProjectRelationship')->search({})->count();
	my $chado_schema 					= $c->bcs_schema();
    #first upload excel trial file with multiple trials
    my %upload_metadata;
    my $file_name = "t/data/trial/demo_multiple_trial_design.$extension";
    my $time      = DateTime->now();
    my $timestamp = $time->ymd() . "_" . $time->hms();

    #Test Archive upload file
    my $uploader = CXGN::UploadFile->new({
        tempfile         => $file_name,
        subdirectory     => "trial_upload",
        archive_path     => '/tmp',
        archive_filename => "demo_multiple_trial_design.$extension",
        timestamp        => $timestamp,
        user_id          => 41,
        user_role        => 'curator' 
    });

    ##store uploaded temprarly file info in archive
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    ok($archived_filename_with_path, "Uploaded file archived");
    ok($md5, "Uploaded file md5");

    $upload_metadata{'archived_file'}      = $archived_filename_with_path;
    $upload_metadata{'archived_file_type'} = 'trial phenotypes';
    $upload_metadata{'user_id'}            = $c->sp_person_id;
    $upload_metadata{'date'}               = "2018-02-14_10:10:10";

    #parse uploaded file with appropriate plugin
    my $parser  = CXGN::Trial::ParseUpload->new(chado_schema=> $chado_schema, filename => $archived_filename_with_path);
    $parser->load_plugin('MultipleTrialDesignGeneric');
    my $parsed_data = $parser->parse();
	print STDERR "Parsed data: " . Dumper($parsed_data);
    ok(!$parsed_data->{error}, 'check if parse validate igd file fails for excel file');
    ok(!$parser->has_parse_errors, 'check if parser error occurs');

    my $parsed_data_check = {
		'198667HBEPR_popa' => {
            'planting_date' => '1984-09-17',
            'plot_length'   => '5',
            'design_type'   => 'Augmented',
            'harvest_date'  => '1985-08-16',
            'year'          => '1999',
            'description'   => 'EPR',
            'entry_numbers' => undef,
            'design_details'=> {
                '16' => {
                    'plot_name'    => '198667HBEPR_popa_rep1_BRA33_9',
                    'range_number' => '6',
                    'is_a_control' => 1,
                    'plot_number'  => '9',
                    'stock_name'   => 'UG120022',
                    'rep_number'   => '1',
                    'block_number' => '1',
                    'row_number'   => '9',
                    'col_number'   => '3'
                },
                '15' => {
                    'is_a_control' => 1,
                    'plot_number'  => '8',
                    'stock_name'   => 'UG120021',
                    'rep_number'   => '1',
                    'block_number' => '1',
                    'row_number'   => '8',
                    'col_number'   => '3',
                    'range_number' => '6',
                    'plot_name'    => '198667HBEPR_popa_rep1_BRA131_8',
                    'range_number' => '6',
                    'row_number'   => '8',
                    'col_number'   => '3',
                    'block_number' => '1'
                },
                '14' => {
                    'stock_name'    => 'UG120019',
                    'rep_number'    => '1',
                    'plot_number'   => '7',
                    'is_a_control'  => 1,
                    'range_number'  => '6',
                    'plot_name'     => '198667HBEPR_popa_rep1_BRA30_7',
                    'col_number'    => '3',
                    'row_number'    => '7',
                    'block_number'  => '1'
                },
                '12' => {
                    'plot_name'     => '198667HBEPR_popa_rep1_BRA128_5',
                    'range_number'  => '6',
                    'is_a_control'  => 1,
                    'plot_number'   => '5',
                    'stock_name'    => 'UG120010',
                    'rep_number'    => '2',
                    'block_number'  => '1',
                    'row_number'    => '5',
                    'col_number'    => '3'
                },
                '13' => {
                    'range_number' => '6',
                    'plot_name'    => '198667HBEPR_popa_rep1_BRA28_6',
                    'rep_number'   => '2',
                    'stock_name'   => 'UG120017',
                    'is_a_control' => 1,
                    'plot_number'  => '6',
                    'block_number' => '1',
                    'col_number'   => '3',
                    'row_number'   => '6'
                }
            },
            'location'         => 'test_location',
            'trial_type'       => 76515,
            'breeding_program' => 'test',
            'plot_width'       => '5',
            'field_size'       => '8'
        },
        '199275HBEPR_stom' => {
            'breeding_program' => 'test',
            'plot_width'       => '5',
            'field_size'       => '8',
            'description'      => 'EPR',
            'entry_numbers'    => undef,
            'location'         => 'test_location',
            'design_details'   => {
                '20' => {
                    'row_number'   => '33',
                    'col_number'   => '2',
                    'block_number' => '1',
                    'plot_number'  => '33',
                    'is_a_control' => 1,
                    'rep_number'   => '1',
                    'stock_name'   => 'XG120071',
                    'plot_name'    => '199275HBEPR_stom_rep1_CG1420-1_33',
                    'range_number' => '6'
                },
                '18' => {
                    'range_number' => '6',
                    'plot_name'    => '199275HBEPR_stom_rep1_SOLITA_31',
                    'rep_number'   => '1',
                    'stock_name'   => 'XG120061',
                    'plot_number'  => '31',
                    'is_a_control' => 1,
                    'block_number' => '1',
                    'col_number'   => '2',
                    'row_number'   => '31'
                },
                '21' => {
                    'stock_name'   => 'XG120073',
                    'rep_number'   => '1',
                    'is_a_control' => 1,
                    'plot_number'  => '34',
                    'range_number' => '6',
                    'plot_name'    => '199275HBEPR_stom_rep1_CM1785-6_34',
                    'col_number'   => '3',
                    'row_number'   => '34',
                    'block_number' => '1'
                },
                '19' => {
                    'row_number'    => '32',
                    'col_number'    => '3',
                    'block_number'  => '1',
                    'is_a_control'  => 1,
                    'plot_number'   => '32',
                    'stock_name'    => 'XG120068',
                    'rep_number'    => '1',
                    'plot_name'     => '199275HBEPR_stom_rep1_CG917-5_32',
                    'range_number'  => '6'
                },
                '17' => {
                    'block_number'  => '1',
                    'col_number'    => '2',
                    'row_number'    => '30',
                    'range_number'  => '6',
                    'plot_name'     => '199275HBEPR_stom_rep1_CM3306-4_30',
                    'stock_name'    => 'XG120030',
                    'rep_number'    => '1',
                    'is_a_control'  => 1,
                    'plot_number'   => '30'
                }
            },
            'trial_type'    => 76515,
            'harvest_date'  => '1993-08-04',
            'year'          => '1999',
            'planting_date' => '1992-09-19',
            'plot_length'   => '5',
            'design_type'   => 'Augmented'
        },
        '199934HBEPR_cara' => {
            'description'    => 'EPR',
            'trial_type'     => 76515,
            'location'       => 'test_location',
            'design_details' => {
                '4' => {
                    'col_number'   => '3',
                    'row_number'   => '30',
                    'block_number' => '1',
                    'rep_number'   => '2',
                    'stock_name'   => 'UG120006',
                    'plot_number'  => '3',
                    'is_a_control' => 1,
                    'range_number' => '4',
                    'plot_name'    => '199934HBEPR_cara_rep1_UG120006_3'
                },
                '5' => {
                    'block_number' => '2',
                    'row_number'   => '40',
                    'col_number'   => '4',
                    'plot_name'    => '199934HBEPR_cara_rep1_UG120008_4',
                    'range_number' => '5',
                    'plot_number'  => '4',
                    'is_a_control' => 1,
                    'rep_number'   => '2',
                    'stock_name'   => 'UG120008'
                },
                '6' => {
                    'col_number'   => '5',
                    'row_number'   => '50',
                    'block_number' => '2',
                    'rep_number'   => '2',
                    'stock_name'   => 'UG120009',
                    'is_a_control' => 1,
                    'plot_number'  => '5',
                    'range_number' => '5',
                    'plot_name'    => '199934HBEPR_cara_rep1_UG120009_5'
                },
                '2' => {
                    'stock_name'   => 'UG120002',
                    'rep_number'   => '2',
                    'is_a_control' => 1,
                    'plot_number'  => '1',
                    'range_number' => '4',
                    'plot_name'    => '199934HBEPR_cara_rep1_UG120002_1',
                    'col_number'   => '1',
                    'row_number'   => '10',
                    'block_number' => '1'
                },
                '3' => {
                    'rep_number'   => '2',
                    'stock_name'   => 'UG120004',
                    'is_a_control' => 1,
                    'plot_number'  => '2',
                    'range_number' => '4',
                    'plot_name'    => '199934HBEPR_cara_rep1_UG120004_2',
                    'col_number'   => '2',
                    'row_number'   => '20',
                    'block_number' => '1'
                }
            },
            'entry_numbers'    => undef,
            'breeding_program' => 'test',
            'field_size'       => '8',
            'plot_width'       => '5',
            'planting_date'    => '1999-06-04',
            'design_type'      => 'Augmented',
            'plot_length'      => '5',
            'harvest_date'     => '2000-03-14',
            'year'             => '1999'
        },
        '199947HBEPR_mora' => {
            'year'         => '1999',
            'harvest_date' => '2000-10-19',
            'plot_length'  => '5',
            'design_type'  => 'Augmented',
            'planting_date'=> '1999-06-23',
            'plot_width'   => '5',
            'field_size'   => '8',
            'breeding_program' => 'test',
            'entry_numbers' => undef,
            'design_details'=> {
                '8' => {
                    'col_number'    => '6',
                    'row_number'    => '60',
                    'block_number'  => '1',
                    'stock_name'    => 'UG120158',
                    'rep_number'    => '2',
                    'plot_number'   => '2',
                    'is_a_control'  => 1,
                    'range_number'  => '6',
                    'plot_name'     => '199947HBEPR_mora_rep1_UG120158_2'
                },
                '10' => {
                    'block_number' => '1',
                    'row_number'   => '80',
                    'col_number'   => '8',
                    'plot_name'    => '199947HBEPR_mora_rep1_UG120160_4',
                    'range_number' => '8',
                    'is_a_control' => 1,
                    'plot_number'  => '4',
                    'rep_number'   => '2',
                    'stock_name'   => 'UG120160'
                },
                '9' => {
                    'row_number'   => '70',
                    'col_number'   => '7',
                    'block_number' => '1',
                    'is_a_control' => 1,
                    'plot_number'  => '3',
                    'stock_name'   => 'UG120159',
                    'rep_number'   => '2',
                    'plot_name'    => '199947HBEPR_mora_rep1_UG120159_3',
                    'range_number' => '7'
                },
                '7' => {
                    'plot_name'    => '199947HBEPR_mora_rep1_UG120157_1',
                    'range_number' => '6',
                    'plot_number'  => '1',
                    'is_a_control' => 1,
                    'rep_number'   => '2',
                    'stock_name'   => 'UG120157',
                    'block_number' => '1',
                    'row_number'   => '50',
                    'col_number'   => '5'
                },
                '11' => {
                    'range_number' => '8',
                    'plot_name'    => '199947HBEPR_mora_rep1_UG120161_5',
                    'rep_number'   => '2',
                    'stock_name'   => 'UG120161',
                    'is_a_control' => 1,
                    'plot_number'  => '5',
                    'block_number' => '1',
                    'col_number'   => '9',
                    'row_number'   => '90'
                }
            },
            'location'    => 'test_location',
            'trial_type'  => 76515,
            'description' => 'EPR'
        }
    };

	is_deeply($parsed_data, $parsed_data_check, 'Check if parsed data is correct for excel file');

	foreach my $trial_name (keys %$parsed_data) {
    	my $trial_data = $parsed_data->{$trial_name};

    	my $expected_project_name = $trial_name;
    	my $expected_project_description = $trial_data->{description} || 'EPR';

		my $trial_create = CXGN::Trial::TrialCreate->new({
    	    chado_schema 		=> $c->bcs_schema(),
    	    dbh 				=> $c->dbh(),
    	    owner_id 			=> 41,
        	trial_year 			=> $trial_data->{year},
        	trial_description 	=> $expected_project_description, #$trial_data->{description},
        	trial_name 			=> $trial_name,
        	design_type 		=> $trial_data->{design_type},
        	design 				=> $trial_data->{design_details},
        	program				=> $trial_data->{breeding_program},
			trial_location 		=> $trial_data->{location},
    	    operator 			=> "janedoe",
    	});

    	my $save = $trial_create->save_trial();
    	ok($save->{'trial_id'}, "Test saving trial '$trial_name' with multiple trial designs");

    	my $project = $c->bcs_schema()->resultset('Project::Project')->search({}, { order_by => { -desc => 'project_id'} })->first();
    	my $project_name = $project->name();
        print STDERR "Debug: actual project name: '$project_name'\n";
        ok($project_name eq $expected_project_name, "Test project name for trial '$trial_name' matches expected name");

        my $project = $c->bcs_schema()->resultset('Project::Project')->search({}, { order_by => { -desc => 'project_id'} })->first();
    	my $project_desc = $project->description();
        print STDERR "Debug: actual project desc: '$project_desc'\n";
        ok($project_desc eq $expected_project_description, "Test project description for trial '$trial_name' matches expected description");

    	my $post_project_count = $c->bcs_schema->resultset('Project::Project')->search({})->count();
    	my $post1_project_diff = $post_project_count - $pre_project_count;
    	print STDERR "Project diff: " . $post1_project_diff . "\n";
    	ok($post1_project_diff == 1, "Check if project count is correct for trial with multiple trial designs");

    	my $post_nd_experiment_count = $c->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search({})->count();
		my $post1_nd_experiment_diff = $post_nd_experiment_count - $pre_nd_experiment_count;
		print STDERR "NdExperiment: " . $post1_nd_experiment_diff . "\n";
		ok($post1_nd_experiment_diff == 1, "check ndexperiment table after upload excel trial");

		my $post_nd_experiment_proj_count = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentProject')->search({})->count();
		my $post1_nd_experiment_proj_diff = $post_nd_experiment_proj_count - $pre_nd_experiment_proj_count;
		print STDERR "NdExperimentProject: " . $post1_nd_experiment_proj_diff . "\n";
		ok($post1_nd_experiment_proj_diff == 1, "check ndexperimentproject table after upload excel trial");

    	my $post_nd_experimentprop_count = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentprop')->search({})->count();
		my $post1_nd_experimentprop_diff = $post_nd_experimentprop_count - $pre_nd_experimentprop_count;
		print STDERR "NdExperimentprop: " . $post1_nd_experimentprop_diff . "\n";
		ok($post1_nd_experimentprop_diff == 0, "check ndexperimentprop table after upload excel trial");

		my $post_project_prop_count = $c->bcs_schema->resultset('Project::Projectprop')->search({})->count();
		my $post1_project_prop_diff = $post_project_prop_count - $pre_project_prop_count;
		print STDERR "Projectprop: " . $post1_project_prop_diff . "\n";
		ok($post1_project_prop_diff == 4, "check projectprop table after upload excel trial");

		my $post_stock_count = $c->bcs_schema->resultset('Stock::Stock')->search({})->count();
		my $post1_stock_diff = $post_stock_count - $pre_stock_count;
		print STDERR "Stock: " . $post1_stock_diff . "\n";
		ok($post1_stock_diff == 5, "check stock table after upload excel trial");

		my $post_stock_prop_count = $c->bcs_schema->resultset('Stock::Stockprop')->search({})->count();
		my $post1_stock_prop_diff = $post_stock_prop_count - $pre_stock_prop_count;
		print STDERR "Stockprop: " . $post1_stock_prop_diff . "\n";
		ok($post1_stock_prop_diff == 35, "check stockprop table after upload excel trial");

		my $post_stock_relationship_count = $c->bcs_schema->resultset('Stock::StockRelationship')->search({})->count();
		my $post1_stock_relationship_diff = $post_stock_relationship_count - $pre_stock_relationship_count;
		print STDERR "StockRelationship: " . $post1_stock_relationship_diff . "\n";
		ok($post1_stock_relationship_diff == 5, "check stockrelationship table after upload excel trial");

		my $post_nd_experiment_stock_count = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentStock')->search({})->count();
		my $post1_nd_experiment_stock_diff = $post_nd_experiment_stock_count - $pre_nd_experiment_stock_count;
		print STDERR "NdExperimentStock: " . $post1_nd_experiment_stock_diff . "\n";
		ok($post1_nd_experiment_stock_diff == 5, "check ndexperimentstock table after upload excel trial");

		my $post_project_relationship_count = $c->bcs_schema->resultset('Project::ProjectRelationship')->search({})->count();
		my $post1_project_relationship_diff = $post_project_relationship_count - $pre_project_relationship_count;
		print STDERR "ProjectRelationship: " . $post1_project_relationship_diff . "\n";
		ok($post1_project_relationship_diff == 1, "check projectrelationship table after upload excel trial");

    	$f->clean_up_db();
	}
}

done_testing();
