use strict;

use Test::More;
use lib 't/lib';
use SGN::Test::Fixture;
use Data::Dumper;

use SGN::Model::Cvterm;
use CXGN::Trial::TrialCreate;
use CXGN::Trial::ParseUpload;
use CXGN::Phenotypes::ParseUpload;
use CXGN::Phenotypes::PhenotypeMatrix;


my $fix = SGN::Test::Fixture->new();

for my $extension ("csv", "xls", "xlsx") {

    my $chado_schema = $fix->bcs_schema;
    my $metadata_schema = $fix->metadata_schema;
    my $phenome_schema = $fix->phenome_schema;
    my $dbh = $fix->dbh;

    #
    # UPLOAD THE TEST FILE
    #
    my $file_name = "t/data/trial/trial_layout_example_intercropping.$extension";
    my $time      = DateTime->now();
    my $timestamp = $time->ymd() . "_" . $time->hms();

    # Test Archive upload file
    my $uploader = CXGN::UploadFile->new({
        tempfile         => $file_name,
        subdirectory     => "trial_upload",
        archive_path     => '/tmp',
        archive_filename => "trial_layout_example_intercropping.$extension",
        timestamp        => $timestamp,
        user_id          => 41,
        user_role        => 'curator'
    });

    # store uploaded temprarly file info in archive
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    ok($archived_filename_with_path, "Uploaded file archived");
    ok($md5, "Uploaded file md5");

    # parse uploaded file with appropriate plugin
    my $parser  = CXGN::Trial::ParseUpload->new(chado_schema=> $chado_schema, filename => $archived_filename_with_path);
    $parser->load_plugin('MultipleTrialDesignGeneric');
    my $parsed_data = $parser->parse();

    # check for parsing errors
    ok(!$parsed_data->{error}, 'check if there are any parser errors');
    ok(!$parser->has_parse_errors, 'check if parser error occurs');

    # Check the contents of the parsed data to make sure intercropped accessions are included
    my $parsed_data_check = {
        'test_intercropping_trial' => {
            'design_type' => 'RCBD',
            'plot_length' => undef,
            'field_size' => undef,
            'year' => '2025',
            'plot_width' => undef,
            'breeding_program' => 'test',
            'trial_stock_type' => 'accession',
            'description' => 'Testing intercropping trial',
            'planting_date' => undef,
            'harvest_date' => undef,
            'design_details' => {
                '2' => {
                            'plot_number' => '1',
                            'plot_name' => 'test_intercropping_trial1',
                            'rep_number' => '1',
                            'row_number' => '1',
                            'block_number' => '1',
                            'intercrop_stock_name' => [
                                                        'UG120050'
                                                    ],
                            'stock_name' => 'test_accession1',
                            'col_number' => '1',
                            'is_a_control' => 0,
                            'range_number' => '1'
                        },
                '5' => {
                            'stock_name' => 'test_accession2',
                            'col_number' => '1',
                            'range_number' => '1',
                            'is_a_control' => 0,
                            'plot_name' => 'test_intercropping_trial4',
                            'plot_number' => '4',
                            'intercrop_stock_name' => [
                                                        'UG120053',
                                                        'UG120054'
                                                    ],
                            'row_number' => '4',
                            'block_number' => '1',
                            'rep_number' => '2'
                        },
                '8' => {
                            'intercrop_stock_name' => [
                                                        'UG120057'
                                                    ],
                            'row_number' => '3',
                            'block_number' => '2',
                            'rep_number' => '1',
                            'plot_name' => 'test_intercropping_trial7',
                            'plot_number' => '7',
                            'col_number' => '2',
                            'is_a_control' => 0,
                            'range_number' => '2',
                            'stock_name' => 'test_accession4'
                        },
                '9' => {
                            'row_number' => '4',
                            'block_number' => '2',
                            'intercrop_stock_name' => [
                                                        'UG120058',
                                                        'UG120059'
                                                    ],
                            'rep_number' => '2',
                            'plot_name' => 'test_intercropping_trial8',
                            'plot_number' => '8',
                            'range_number' => '2',
                            'col_number' => '2',
                            'is_a_control' => 0,
                            'stock_name' => 'test_accession4'
                        },
                '7' => {
                            'plot_name' => 'test_intercropping_trial6',
                            'plot_number' => '6',
                            'block_number' => '2',
                            'row_number' => '2',
                            'intercrop_stock_name' => [
                                                        'UG120056'
                                                    ],
                            'rep_number' => '2',
                            'stock_name' => 'test_accession3',
                            'range_number' => '2',
                            'col_number' => '2',
                            'is_a_control' => 0
                        },
                '6' => {
                            'stock_name' => 'test_accession3',
                            'col_number' => '2',
                            'range_number' => '2',
                            'is_a_control' => 0,
                            'plot_name' => 'test_intercropping_trial5',
                            'plot_number' => '5',
                            'block_number' => '2',
                            'row_number' => '1',
                            'intercrop_stock_name' => [
                                                        'UG120055'
                                                    ],
                            'rep_number' => '1'
                        },
                '4' => {
                            'rep_number' => '1',
                            'intercrop_stock_name' => [
                                                        'UG120052'
                                                    ],
                            'row_number' => '3',
                            'block_number' => '1',
                            'plot_number' => '3',
                            'plot_name' => 'test_intercropping_trial3',
                            'col_number' => '1',
                            'range_number' => '1',
                            'is_a_control' => 0,
                            'stock_name' => 'test_accession2'
                        },
                '3' => {
                            'col_number' => '1',
                            'is_a_control' => 0,
                            'range_number' => '1',
                            'stock_name' => 'test_accession1',
                            'row_number' => '2',
                            'block_number' => '1',
                            'intercrop_stock_name' => [
                                                        'UG120051'
                                                    ],
                            'rep_number' => '2',
                            'plot_name' => 'test_intercropping_trial2',
                            'plot_number' => '2'
                        }
            },
            'entry_numbers' => undef,
            'location' => 'test_location'
        }
    };
    is_deeply($parsed_data, $parsed_data_check, 'Check if parsed data is correct for excel file');

    #
    # SAVE TRIAL
    #
    foreach my $trial_name (keys %$parsed_data) {

        # Create and save trial to DB
        my $trial_data = $parsed_data->{$trial_name};
        my $trial_create = CXGN::Trial::TrialCreate->new({
            chado_schema 		=> $chado_schema,
            dbh 				=> $dbh,
            owner_id 			=> 41,
            trial_year 			=> $trial_data->{year},
            trial_description 	=> $trial_data->{description},
            trial_name 			=> $trial_name,
            design_type 		=> $trial_data->{design_type},
            design 				=> $trial_data->{design_details},
            program				=> $trial_data->{breeding_program},
            trial_location 		=> $trial_data->{location},
            operator 			=> "janedoe",
        });
        my $save = $trial_create->save_trial();
        ok($save->{'trial_id'}, "Test saving trial '$trial_name' with multiple trial designs");

        #
        # CHECK TRIAL LAYOUT
        #

        # Get trial object
        my $trial_id = $save->{trial_id};
        my $trial = CXGN::Trial->new({
            bcs_schema => $chado_schema,
            metadata_schema => $metadata_schema,
            phenome_schema => $phenome_schema,
            trial_id => $trial_id
        });

        # Get the trial layout
        my $trial_layout = $trial->get_layout();
        my $design = $trial_layout->{design};
        my $design_accessions = $trial_layout->{accession_names};

        # Check design to make sure it includes the intercropped accessions
        my $design_intercrop_accessions_check = {
          '4' => [
                    {
                        'accession_name' => 'UG120053',
                        'accession_id' => 38925
                    },
                    {
                        'accession_name' => 'UG120054',
                        'accession_id' => 38926
                    }
                ],
          '8' => [
                    {
                        'accession_name' => 'UG120058',
                        'accession_id' => 38929
                    },
                    {
                        'accession_id' => 38930,
                        'accession_name' => 'UG120059'
                    }
                ],
          '5' => [
                    {
                        'accession_id' => 38927,
                        'accession_name' => 'UG120055'
                    }
                ],
          '3' => [
                    {
                        'accession_id' => 39949,
                        'accession_name' => 'UG120052'
                    }
                ],
          '2' => [
                    {
                        'accession_id' => 38924,
                        'accession_name' => 'UG120051'
                    }
                ],
          '1' => [
                    {
                        'accession_name' => 'UG120050',
                        'accession_id' => 39948
                    }
                ],
          '6' => [
                    {
                        'accession_id' => 39950,
                        'accession_name' => 'UG120056'
                    }
                ],
          '7' => [
                    {
                        'accession_id' => 38928,
                        'accession_name' => 'UG120057'
                    }
                ],
        };
        foreach my $dk (keys %$design) {
            is_deeply($design->{$dk}->{'intercrop_accessions'}, $design_intercrop_accessions_check->{$dk}, "Check trial layout design intercrop accessions for key $dk");
        }

        # Check design accession list
        my $design_accessions_check = [
            {
                'accession_name' => 'UG120050',
                'stock_id' => 39948
            },
            {
                'accession_name' => 'UG120051',
                'stock_id' => 38924
            },
            {
                'accession_name' => 'UG120052',
                'stock_id' => 39949
            },
            {
                'accession_name' => 'UG120053',
                'stock_id' => 38925
            },
            {
                'stock_id' => 38926,
                'accession_name' => 'UG120054'
            },
            {
                'accession_name' => 'UG120055',
                'stock_id' => 38927
            },
            {
                'accession_name' => 'UG120056',
                'stock_id' => 39950
            },
            {
                'stock_id' => 38928,
                'accession_name' => 'UG120057'
            },
            {
                'stock_id' => 38929,
                'accession_name' => 'UG120058'
            },
            {
                'accession_name' => 'UG120059',
                'stock_id' => 38930
            },
            {
                'accession_name' => 'test_accession1',
                'stock_id' => 38840
            },
            {
                'accession_name' => 'test_accession2',
                'stock_id' => 38841
            },
            {
                'stock_id' => 38842,
                'accession_name' => 'test_accession3'
            },
            {
                'accession_name' => 'test_accession4',
                'stock_id' => 38843
            }
        ];
        is_deeply($design_accessions, $design_accessions_check, "Check trial design list of accessions");


        #
        # UPLOAD OBSERVATIONS
        #
        my $parser = CXGN::Phenotypes::ParseUpload->new();
        my $observations_file_name = "t/data/trial/upload_phenotyping_spreadsheet_intercropping.xlsx";
        my $validate_file = $parser->validate('phenotype spreadsheet simple generic', $observations_file_name, 0, 'plots', $chado_schema);
        ok($validate_file == 1, "Check phenotype upload file validation");

        my $parsed_file = $parser->parse('phenotype spreadsheet simple generic', $observations_file_name, 0, 'plots', $chado_schema);
        ok($parsed_file, "Check phenotype upload file parsing");

        # Check phenotype matrix results
        my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
            bcs_schema => $chado_schema,
            search_type => 'Native',
            data_level => 'plot',
            trial_list => [$trial_id],
            include_intercrop_stocks => 1
        );
        my @data = $phenotypes_search->get_phenotype_matrix();
        my $data_check = [
          [
            'studyYear',
            'programDbId',
            'programName',
            'programDescription',
            'studyDbId',
            'studyName',
            'studyDescription',
            'studyDesign',
            'plotWidth',
            'plotLength',
            'fieldSize',
            'fieldTrialIsPlannedToBeGenotyped',
            'fieldTrialIsPlannedToCross',
            'plantingDate',
            'harvestDate',
            'locationDbId',
            'locationName',
            'germplasmDbId',
            'germplasmName',
            'germplasmSynonyms',
            'observationLevel',
            'observationUnitDbId',
            'observationUnitName',
            'replicate',
            'blockNumber',
            'plotNumber',
            'rowNumber',
            'colNumber',
            'entryType',
            'plantNumber',
            'intercropGermplasmDbId',
            'intercropGermplasmName',
            'notes'
          ],
          [
            '2025',
            134,
            'test',
            'test',
            168,
            'test_intercropping_trial',
            'Testing intercropping trial',
            'RCBD',
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            '23',
            'test_location',
            38840,
            'test_accession1',
            'test_accession1_synonym1',
            'plot',
            41801,
            'test_intercropping_trial1',
            '1',
            '1',
            '1',
            '1',
            '1',
            'test',
            undef,
            '39948',
            'UG120050',
            undef
          ],
          [
            '2025',
            134,
            'test',
            'test',
            168,
            'test_intercropping_trial',
            'Testing intercropping trial',
            'RCBD',
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            '23',
            'test_location',
            38840,
            'test_accession1',
            'test_accession1_synonym1',
            'plot',
            41803,
            'test_intercropping_trial2',
            '2',
            '1',
            '2',
            '2',
            '1',
            'test',
            undef,
            '38924',
            'UG120051',
            undef
          ],
          [
            '2025',
            134,
            'test',
            'test',
            168,
            'test_intercropping_trial',
            'Testing intercropping trial',
            'RCBD',
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            '23',
            'test_location',
            38841,
            'test_accession2',
            'test_accession2_synonym1,test_accession2_synonym2',
            'plot',
            41802,
            'test_intercropping_trial3',
            '1',
            '1',
            '3',
            '3',
            '1',
            'test',
            undef,
            '39949',
            'UG120052',
            undef
          ],
          [
            '2025',
            134,
            'test',
            'test',
            168,
            'test_intercropping_trial',
            'Testing intercropping trial',
            'RCBD',
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            '23',
            'test_location',
            38841,
            'test_accession2',
            'test_accession2_synonym1,test_accession2_synonym2',
            'plot',
            41805,
            'test_intercropping_trial4',
            '2',
            '1',
            '4',
            '4',
            '1',
            'test',
            undef,
            '38925,38926',
            'UG120053,UG120054',
            undef
          ],
          [
            '2025',
            134,
            'test',
            'test',
            168,
            'test_intercropping_trial',
            'Testing intercropping trial',
            'RCBD',
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            '23',
            'test_location',
            38842,
            'test_accession3',
            'test_accession3_synonym1',
            'plot',
            41804,
            'test_intercropping_trial5',
            '1',
            '2',
            '5',
            '1',
            '2',
            'test',
            undef,
            '38927',
            'UG120055',
            undef
          ],
          [
            '2025',
            134,
            'test',
            'test',
            168,
            'test_intercropping_trial',
            'Testing intercropping trial',
            'RCBD',
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            '23',
            'test_location',
            38842,
            'test_accession3',
            'test_accession3_synonym1',
            'plot',
            41798,
            'test_intercropping_trial6',
            '2',
            '2',
            '6',
            '2',
            '2',
            'test',
            undef,
            '39950',
            'UG120056',
            undef
          ],
          [
            '2025',
            134,
            'test',
            'test',
            168,
            'test_intercropping_trial',
            'Testing intercropping trial',
            'RCBD',
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            '23',
            'test_location',
            38843,
            'test_accession4',
            '',
            'plot',
            41799,
            'test_intercropping_trial7',
            '1',
            '2',
            '7',
            '3',
            '2',
            'test',
            undef,
            '38928',
            'UG120057',
            undef
          ],
          [
            '2025',
            134,
            'test',
            'test',
            168,
            'test_intercropping_trial',
            'Testing intercropping trial',
            'RCBD',
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            '23',
            'test_location',
            38843,
            'test_accession4',
            '',
            'plot',
            41800,
            'test_intercropping_trial8',
            '2',
            '2',
            '8',
            '4',
            '2',
            'test',
            undef,
            '38929,38930',
            'UG120058,UG120059',
            undef
          ]
        ];

        while (my ($index, $d) = each @data) {
            my $c = $data_check->[$index];
            is_deeply($d->[22], $c->[22], 'check phenotype matrix plot names');
            is_deeply($d->[17], $c->[17], 'check phenotype matrix accession ids');
            is_deeply($d->[18], $c->[18], 'check phenotype matrix accession names');
            is_deeply($d->[30], $c->[30], 'check phenotype matrix intercrop accession ids');
            is_deeply($d->[31], $c->[31], 'check phenotype matrix intercrop accession names');
        }


        #
        # REMOVE TRIAL
        #
        $trial->delete_metadata();
        $trial->delete_field_layout();
        $trial->delete_project_entry();
        $fix->clean_up_db();
    }
}
done_testing();