
use strict;
use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use SimulateC;
use CXGN::UploadFile;
use CXGN::Phenotypes::ParseUpload;
use CXGN::Phenotypes::StorePhenotypes;
use CXGN::Trial;
use SGN::Model::Cvterm;
use DateTime;
use Data::Dumper;

my $f = SGN::Test::Fixture->new();

my $c = SimulateC->new( { dbh => $f->dbh(), 
			  bcs_schema => $f->bcs_schema(), 
			  metadata_schema => $f->metadata_schema(),
			  phenome_schema => $f->phenome_schema(),
			  sp_person_id => 41 });

#######################################
#Find out table counts before adding anything, so that changes can be compared

my $phenotyping_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($c->bcs_schema, 'phenotyping_experiment', 'experiment_type')->cvterm_id();
my $experiment = $c->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search({type_id => $phenotyping_experiment_cvterm_id});
my $pre_experiment_count = $experiment->count();

my $phenotype_rs = $c->bcs_schema->resultset('Phenotype::Phenotype')->search({});
my $pre_phenotype_count = $phenotype_rs->count();

my $exp_prop_rs = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentprop')->search({});
my $pre_exp_prop_count = $exp_prop_rs->count();

my $exp_stock_rs = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentStock')->search({});
my $pre_exp_stock_count = $exp_stock_rs->count();

my $exp_proj_rs = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentProject')->search({});
my $pre_exp_proj_count = $exp_proj_rs->count();

my $exp_pheno_rs = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentPhenotype')->search({});
my $pre_exp_pheno_count = $exp_pheno_rs->count();

my $md_rs = $c->metadata_schema->resultset('MdMetadata')->search({});
my $pre_md_count = $md_rs->count();

my $md_files_rs = $c->metadata_schema->resultset('MdFiles')->search({});
my $pre_md_files_count = $md_files_rs->count();

my $exp_md_files_rs = $c->phenome_schema->resultset('NdExperimentMdFiles')->search({});
my $pre_exp_md_files_count = $exp_md_files_rs->count();


########################################
#Tests for phenotype spreadsheet parsing

#check that parse fails for fieldbook file when using phenotype spreadsheet parser
my $parser = CXGN::Phenotypes::ParseUpload->new();
my $filename = "t/data/fieldbook/fieldbook_phenotype_file.csv";
my $validate_file = $parser->validate('phenotype spreadsheet', $filename, 1);
ok($validate_file != 1, "Check if parse validate phenotype spreadsheet fails for fieldbook");

#check that parse fails for datacollector file when using phenotype spreadsheet parser
$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/trial/data_collector_upload.xls";
$validate_file = $parser->validate('phenotype spreadsheet', $filename, 1);
ok($validate_file != 1, "Check if parse validate phenotype spreadsheet fails for datacollector");

#Now parse phenotyping spreadsheet file using correct parser
$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/trial/upload_phenotypin_spreadsheet.xls";
$validate_file = $parser->validate('phenotype spreadsheet', $filename, 1, 'plots');
ok($validate_file == 1, "Check if parse validate works for phenotype file");

my $parsed_file = $parser->parse('phenotype spreadsheet', $filename, 1, 'plots');
ok($parsed_file, "Check if parse parse phenotype spreadsheet works");

#print STDERR Dumper $parsed_file;

is_deeply($parsed_file, {
	'plots' => [
	                       'test_trial21',
	                       'test_trial210',
	                       'test_trial211',
	                       'test_trial212',
	                       'test_trial213',
	                       'test_trial214',
	                       'test_trial215',
	                       'test_trial22',
	                       'test_trial23',
	                       'test_trial24',
	                       'test_trial25',
	                       'test_trial26',
	                       'test_trial27',
	                       'test_trial28',
	                       'test_trial29'
	                     ],
	          'traits' => [
	                        'dry matter content|CO:0000092',
	                        'fresh root weight|CO:0000012',
	                        'fresh shoot weight|CO:0000016',
	                        'harvest index|CO:0000015'
	                      ],
	          'data' => {
	                      'test_trial24' => {
	                                          'fresh shoot weight|CO:0000016' => [
	                                                                               '23',
	                                                                               '2016-02-11 11:12:20-0500'
	                                                                             ],
	                                          'fresh root weight|CO:0000012' => [
	                                                                              '15',
	                                                                              '2016-01-15 11:12:20-0500'
	                                                                            ],
	                                          'harvest index|CO:0000015' => [
	                                                                          '3.8',
	                                                                          '2016-03-16 11:12:20-0500'
	                                                                        ],
	                                          'dry matter content|CO:0000092' => [
	                                                                               '39',
	                                                                               '2016-04-27 11:12:20-0500'
	                                                                             ]
	                                        },
	                      'test_trial215' => {
	                                           'dry matter content|CO:0000092' => [
	                                                                                '38',
	                                                                                '2016-04-27 19:12:20-0500'
	                                                                              ],
	                                           'fresh root weight|CO:0000012' => [
	                                                                               '15',
	                                                                               '2016-01-15 19:12:20-0500'
	                                                                             ],
	                                           'harvest index|CO:0000015' => [
	                                                                           '14.8',
	                                                                           '2016-03-16 19:12:20-0500'
	                                                                         ],
	                                           'fresh shoot weight|CO:0000016' => [
	                                                                                '34',
	                                                                                '2016-02-11 19:12:20-0500'
	                                                                              ]
	                                         },
	                      'test_trial25' => {
	                                          'fresh root weight|CO:0000012' => [
	                                                                              '15',
	                                                                              '2016-01-15 09:12:20-0500'
	                                                                            ],
	                                          'harvest index|CO:0000015' => [
	                                                                          '4.8',
	                                                                          '2016-03-16 09:12:20-0500'
	                                                                        ],
	                                          'fresh shoot weight|CO:0000016' => [
	                                                                               '24',
	                                                                               '2016-02-11 09:12:20-0500'
	                                                                             ],
	                                          'dry matter content|CO:0000092' => [
	                                                                               '35',
	                                                                               '2016-04-27 09:12:20-0500'
	                                                                             ]
	                                        },
	                      'test_trial26' => {
	                                          'dry matter content|CO:0000092' => [
	                                                                               '30',
	                                                                               '2016-04-27 16:12:20-0500'
	                                                                             ],
	                                          'fresh shoot weight|CO:0000016' => [
	                                                                               '25',
	                                                                               '2016-02-11 16:12:20-0500'
	                                                                             ],
	                                          'harvest index|CO:0000015' => [
	                                                                          '5.8',
	                                                                          '2016-03-16 16:12:20-0500'
	                                                                        ],
	                                          'fresh root weight|CO:0000012' => [
	                                                                              '15',
	                                                                              '2016-01-15 16:12:20-0500'
	                                                                            ]
	                                        },
	                      'test_trial29' => {
	                                          'dry matter content|CO:0000092' => [
	                                                                               '35',
	                                                                               '2016-04-27 14:12:20-0500'
	                                                                             ],
	                                          'harvest index|CO:0000015' => [
	                                                                          '8.8',
	                                                                          '2016-03-16 14:12:20-0500'
	                                                                        ],
	                                          'fresh root weight|CO:0000012' => [
	                                                                              '15',
	                                                                              '2016-01-15 14:12:20-0500'
	                                                                            ],
	                                          'fresh shoot weight|CO:0000016' => [
	                                                                               '28',
	                                                                               '2016-02-11 14:12:20-0500'
	                                                                             ]
	                                        },
	                      'test_trial211' => {
	                                           'fresh shoot weight|CO:0000016' => [
	                                                                                '30',
	                                                                                '2016-02-11 03:12:20-0500'
	                                                                              ],
	                                           'fresh root weight|CO:0000012' => [
	                                                                               '15',
	                                                                               '2016-01-15 03:12:20-0500'
	                                                                             ],
	                                           'harvest index|CO:0000015' => [
	                                                                           '10.8',
	                                                                           '2016-03-16 03:12:20-0500'
	                                                                         ],
	                                           'dry matter content|CO:0000092' => [
	                                                                                '38',
	                                                                                '2016-04-27 03:12:20-0500'
	                                                                              ]
	                                         },
	                      'test_trial23' => {
	                                          'fresh root weight|CO:0000012' => [
	                                                                              '15',
	                                                                              '2016-01-15 01:12:20-0500'
	                                                                            ],
	                                          'harvest index|CO:0000015' => [
	                                                                          '2.8',
	                                                                          '2016-03-16 01:12:20-0500'
	                                                                        ],
	                                          'fresh shoot weight|CO:0000016' => [
	                                                                               '22',
	                                                                               '2016-02-11 01:12:20-0500'
	                                                                             ],
	                                          'dry matter content|CO:0000092' => [
	                                                                               '38',
	                                                                               '2016-04-27 01:12:20-0500'
	                                                                             ]
	                                        },
	                      'test_trial21' => {
	                                          'harvest index|CO:0000015' => [
	                                                                          '0.8',
	                                                                          '2016-03-16 12:12:20-0500'
	                                                                        ],
	                                          'fresh root weight|CO:0000012' => [
	                                                                              '15',
	                                                                              '2016-01-15 12:12:20-0500'
	                                                                            ],
	                                          'fresh shoot weight|CO:0000016' => [
	                                                                               '20',
	                                                                               '2016-02-11 12:12:20-0500'
	                                                                             ],
	                                          'dry matter content|CO:0000092' => [
	                                                                               '35',
	                                                                               '2016-04-27 12:12:20-0500'
	                                                                             ]
	                                        },
	                      'test_trial213' => {
	                                           'fresh root weight|CO:0000012' => [
	                                                                               '15',
	                                                                               '2016-01-15 22:12:20-0500'
	                                                                             ],
	                                           'harvest index|CO:0000015' => [
	                                                                           '12.8',
	                                                                           '2016-03-16 22:12:20-0500'
	                                                                         ],
	                                           'fresh shoot weight|CO:0000016' => [
	                                                                                '32',
	                                                                                '2016-02-11 22:12:20-0500'
	                                                                              ],
	                                           'dry matter content|CO:0000092' => [
	                                                                                '35',
	                                                                                '2016-04-27 22:12:20-0500'
	                                                                              ]
	                                         },
	                      'test_trial212' => {
	                                           'dry matter content|CO:0000092' => [
	                                                                                '39',
	                                                                                '2016-04-27 21:12:20-0500'
	                                                                              ],
	                                           'fresh root weight|CO:0000012' => [
	                                                                               '15',
	                                                                               '2016-01-15 21:12:20-0500'
	                                                                             ],
	                                           'harvest index|CO:0000015' => [
	                                                                           '11.8',
	                                                                           '2016-03-16 21:12:20-0500'
	                                                                         ],
	                                           'fresh shoot weight|CO:0000016' => [
	                                                                                '31',
	                                                                                '2016-02-11 21:12:20-0500'
	                                                                              ]
	                                         },
	                      'test_trial22' => {
	                                          'fresh shoot weight|CO:0000016' => [
	                                                                               '21',
	                                                                               '2016-02-11 02:12:20-0500'
	                                                                             ],
	                                          'fresh root weight|CO:0000012' => [
	                                                                              '15',
	                                                                              '2016-01-15 02:12:20-0500'
	                                                                            ],
	                                          'harvest index|CO:0000015' => [
	                                                                          '1.8',
	                                                                          '2016-03-16 02:12:20-0500'
	                                                                        ],
	                                          'dry matter content|CO:0000092' => [
	                                                                               '30',
	                                                                               '2016-04-27 02:12:20-0500'
	                                                                             ]
	                                        },
	                      'test_trial27' => {
	                                          'dry matter content|CO:0000092' => [
	                                                                               '38',
	                                                                               '2016-04-27 17:12:20-0500'
	                                                                             ],
	                                          'harvest index|CO:0000015' => [
	                                                                          '6.8',
	                                                                          '2016-03-16 17:12:20-0500'
	                                                                        ],
	                                          'fresh root weight|CO:0000012' => [
	                                                                              '15',
	                                                                              '2016-01-15 17:12:20-0500'
	                                                                            ],
	                                          'fresh shoot weight|CO:0000016' => [
	                                                                               '26',
	                                                                               '2016-02-11 17:12:20-0500'
	                                                                             ]
	                                        },
	                      'test_trial28' => {
	                                          'dry matter content|CO:0000092' => [
	                                                                               '39',
	                                                                               '2016-04-27 13:12:20-0500'
	                                                                             ],
	                                          'fresh shoot weight|CO:0000016' => [
	                                                                               '27',
	                                                                               '2016-02-11 13:12:20-0500'
	                                                                             ],
	                                          'fresh root weight|CO:0000012' => [
	                                                                              '15',
	                                                                              '2016-01-15 13:12:20-0500'
	                                                                            ],
	                                          'harvest index|CO:0000015' => [
	                                                                          '7.8',
	                                                                          '2016-03-16 13:12:20-0500'
	                                                                        ]
	                                        },
	                      'test_trial214' => {
	                                           'dry matter content|CO:0000092' => [
	                                                                                '30',
	                                                                                '2016-04-27 23:12:20-0500'
	                                                                              ],
	                                           'fresh shoot weight|CO:0000016' => [
	                                                                                '33',
	                                                                                '2016-02-11 23:12:20-0500'
	                                                                              ],
	                                           'fresh root weight|CO:0000012' => [
	                                                                               '15',
	                                                                               '2016-01-15 23:12:20-0500'
	                                                                             ],
	                                           'harvest index|CO:0000015' => [
	                                                                           '13.8',
	                                                                           '2016-03-16 23:12:20-0500'
	                                                                         ]
	                                         },
	                      'test_trial210' => {
	                                           'dry matter content|CO:0000092' => [
	                                                                                '30',
	                                                                                '2016-04-27 15:12:20-0500'
	                                                                              ],
	                                           'fresh shoot weight|CO:0000016' => [
	                                                                                '29',
	                                                                                '2016-02-11 15:12:20-0500'
	                                                                              ],
	                                           'harvest index|CO:0000015' => [
	                                                                           '9.8',
	                                                                           '2016-03-16 15:12:20-0500'
	                                                                         ],
	                                           'fresh root weight|CO:0000012' => [
	                                                                               '15',
	                                                                               '2016-01-15 15:12:20-0500'
	                                                                             ]
	                                         }
	                    }
             }, "Check parse phenotyping spreadsheet" );


my %phenotype_metadata;
$phenotype_metadata{'archived_file'} = $filename;
$phenotype_metadata{'archived_file_type'}="spreadsheet phenotype file";
$phenotype_metadata{'operator'}="janedoe";
$phenotype_metadata{'date'}="2016-02-16_01:10:56";
my %parsed_data = %{$parsed_file->{'data'}};
my @plots = @{$parsed_file->{'plots'}};
my @traits = @{$parsed_file->{'traits'}};

my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new();
my $size = scalar(@plots) * scalar(@traits);
my $stored_phenotype_error_msg = $store_phenotypes->store($c,$size,\@plots,\@traits, \%parsed_data, \%phenotype_metadata, 'plots');
ok(!$stored_phenotype_error_msg, "check that store pheno spreadsheet works");

my $tn = CXGN::Trial->new( { bcs_schema => $f->bcs_schema(),
				trial_id => 137 });

my $traits_assayed  = $tn->get_traits_assayed();
my @traits_assayed_sorted = sort {$a->[0] cmp $b->[0]} @$traits_assayed;
#print STDERR Dumper @traits_assayed_sorted;
my @traits_assayed_check = ([70666,'Fresh root weight'], [70668,'Harvest index variable'], [70741,'Dry matter content percentage'], [70773,'Fresh shoot weight measurement in kg']);
is_deeply(\@traits_assayed_sorted, \@traits_assayed_check, 'check traits assayed from phenotyping spreadsheet upload' );

my @pheno_for_trait = $tn->get_phenotypes_for_trait(70666);
my @pheno_for_trait_sorted = sort {$a <=> $b} @pheno_for_trait;
#print STDERR Dumper @pheno_for_trait_sorted;
my @pheno_for_trait_check = ('15','15','15','15','15','15','15','15','15','15','15','15','15','15','15');
is_deeply(\@pheno_for_trait_sorted, \@pheno_for_trait_check, 'check pheno traits 70666 from phenotyping spreadsheet upload' );

@pheno_for_trait = $tn->get_phenotypes_for_trait(70668);
@pheno_for_trait_sorted = sort {$a <=> $b} @pheno_for_trait;
#print STDERR Dumper @pheno_for_trait_sorted;
@pheno_for_trait_check = ('0.8','1.8','2.8','3.8','4.8','5.8','6.8','7.8','8.8','9.8','10.8','11.8','12.8','13.8','14.8');
is_deeply(\@pheno_for_trait_sorted, \@pheno_for_trait_check, 'check pheno traits 70668 from phenotyping spreadsheet upload' );

@pheno_for_trait = $tn->get_phenotypes_for_trait(70741);
@pheno_for_trait_sorted = sort {$a <=> $b} @pheno_for_trait;
#print STDERR Dumper @pheno_for_trait_sorted;
@pheno_for_trait_check = ('30','30','30','30','35','35','35','35','38','38','38','38','39','39','39');
is_deeply(\@pheno_for_trait_sorted, \@pheno_for_trait_check, 'check pheno traits 70741 from phenotyping spreadsheet upload' );

@pheno_for_trait = $tn->get_phenotypes_for_trait(70773);
@pheno_for_trait_sorted = sort {$a <=> $b} @pheno_for_trait;
#print STDERR Dumper @pheno_for_trait_sorted;
@pheno_for_trait_check = ('20','21','22','23','24','25','26','27','28','29','30','31','32','33','34');
is_deeply(\@pheno_for_trait_sorted, \@pheno_for_trait_check, 'check pheno traits 70773 from phenotyping spreadsheet upload' );


$experiment = $c->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search({type_id => $phenotyping_experiment_cvterm_id});
my $post1_experiment_count = $experiment->count();
my $post1_experiment_diff = $post1_experiment_count - $pre_experiment_count;
print STDERR "Experiment count: ".$post1_experiment_diff."\n";
ok($post1_experiment_diff == 60, "Check num rows in NdExperiment table after addition of phenotyping spreadsheet upload");

$phenotype_rs = $c->bcs_schema->resultset('Phenotype::Phenotype')->search({});
my $post1_phenotype_count = $phenotype_rs->count();
my $post1_phenotype_diff = $post1_phenotype_count - $pre_phenotype_count;
print STDERR "Phenotype count: ".$post1_phenotype_diff."\n";
ok($post1_phenotype_diff == 60, "Check num rows in Phenotype table after addition of phenotyping spreadsheet upload");

$exp_prop_rs = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentprop')->search({});
my $post1_exp_prop_count = $exp_prop_rs->count();
my $post1_exp_prop_diff = $post1_exp_prop_count - $pre_exp_prop_count;
print STDERR "Experimentprop count: ".$post1_exp_prop_diff."\n";
ok($post1_exp_prop_diff == 120, "Check num rows in Experimentprop table after addition of phenotyping spreadsheet upload");

$exp_proj_rs = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentProject')->search({});
my $post1_exp_proj_count = $exp_proj_rs->count();
my $post1_exp_proj_diff = $post1_exp_proj_count - $pre_exp_proj_count;
print STDERR "Experimentproject count: ".$post1_exp_proj_diff."\n";
ok($post1_exp_proj_diff == 60, "Check num rows in NdExperimentproject table after addition of phenotyping spreadsheet upload");

$exp_stock_rs = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentStock')->search({});
my $post1_exp_stock_count = $exp_stock_rs->count();
my $post1_exp_stock_diff = $post1_exp_stock_count - $pre_exp_stock_count;
print STDERR "Experimentstock count: ".$post1_exp_stock_diff."\n";
ok($post1_exp_stock_diff == 60, "Check num rows in NdExperimentstock table after addition of phenotyping spreadsheet upload");

$exp_pheno_rs = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentPhenotype')->search({});
my $post1_exp_pheno_count = $exp_pheno_rs->count();
my $post1_exp_pheno_diff = $post1_exp_pheno_count - $pre_exp_pheno_count;
print STDERR "Experimentphenotype count: ".$post1_exp_pheno_diff."\n";
ok($post1_exp_pheno_diff == 60, "Check num rows in NdExperimentphenotype table after addition of phenotyping spreadsheet upload");

$md_rs = $c->metadata_schema->resultset('MdMetadata')->search({});
my $post1_md_count = $md_rs->count();
my $post1_md_diff = $post1_md_count - $pre_md_count;
print STDERR "MdMetadata count: ".$post1_md_diff."\n";
ok($post1_md_diff == 1, "Check num rows in MdMetadata table after addition of phenotyping spreadsheet upload");

$md_files_rs = $c->metadata_schema->resultset('MdFiles')->search({});
my $post1_md_files_count = $md_files_rs->count();
my $post1_md_files_diff = $post1_md_files_count - $pre_md_files_count;
print STDERR "MdFiles count: ".$post1_md_files_diff."\n";
ok($post1_md_files_diff == 1, "Check num rows in MdFiles table after addition of phenotyping spreadsheet upload");

$exp_md_files_rs = $c->phenome_schema->resultset('NdExperimentMdFiles')->search({});
my $post1_exp_md_files_count = $exp_md_files_rs->count();
my $post1_exp_md_files_diff = $post1_exp_md_files_count - $pre_exp_md_files_count;
print STDERR "Experimentphenotype count: ".$post1_exp_md_files_diff."\n";
ok($post1_exp_md_files_diff == 60, "Check num rows in NdExperimentMdFIles table after addition of phenotyping spreadsheet upload");




#Check what happens on duplication of plot_name, trait, and value. timestamps must be unique or it will not be uploaded.

$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/trial/upload_phenotypin_spreadsheet_duplicate.xls";
$validate_file = $parser->validate('phenotype spreadsheet', $filename, 0, 'plots');
ok($validate_file == 1, "Check if parse validate works for phenotype file");

my $parsed_file = $parser->parse('phenotype spreadsheet', $filename, 0), 'plots';
ok($parsed_file, "Check if parse parse phenotype spreadsheet works");

my %phenotype_metadata;
$phenotype_metadata{'archived_file'} = $filename;
$phenotype_metadata{'archived_file_type'}="spreadsheet phenotype file";
$phenotype_metadata{'operator'}="janedoe";
$phenotype_metadata{'date'}="2016-02-22_01:10:56";
my %parsed_data = %{$parsed_file->{'data'}};
my @plots = @{$parsed_file->{'plots'}};
my @traits = @{$parsed_file->{'traits'}};

$store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new();
$stored_phenotype_error_msg = $store_phenotypes->store($c,$size,\@plots,\@traits, \%parsed_data, \%phenotype_metadata, 'plots');
ok(!$stored_phenotype_error_msg, "check that store pheno spreadsheet works");

my $traits_assayed  = $tn->get_traits_assayed();
my @traits_assayed_sorted = sort {$a->[0] cmp $b->[0]} @$traits_assayed;
#print STDERR Dumper @traits_assayed_sorted;
my @traits_assayed_check = ([70666,'Fresh root weight'], [70668,'Harvest index variable'], [70741,'Dry matter content percentage'], [70773,'Fresh shoot weight measurement in kg']);
is_deeply(\@traits_assayed_sorted, \@traits_assayed_check, 'check traits assayed from phenotyping spreadsheet upload' );

my @pheno_for_trait = $tn->get_phenotypes_for_trait(70666);
my @pheno_for_trait_sorted = sort {$a <=> $b} @pheno_for_trait;
#print STDERR Dumper @pheno_for_trait_sorted;
my @pheno_for_trait_check = ('15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15');
is_deeply(\@pheno_for_trait_sorted, \@pheno_for_trait_check, 'check pheno traits 70666 from phenotyping spreadsheet upload' );

@pheno_for_trait = $tn->get_phenotypes_for_trait(70668);
@pheno_for_trait_sorted = sort {$a <=> $b} @pheno_for_trait;
#print STDERR Dumper @pheno_for_trait_sorted;
@pheno_for_trait_check = ('0.8','0.8','1.8','1.8','2.8','2.8','3.8','3.8','4.8','4.8','5.8','5.8','6.8','6.8','7.8','7.8','8.8','8.8','9.8','9.8','10.8','10.8','11.8','11.8','12.8','12.8','13.8','13.8','14.8','14.8');
is_deeply(\@pheno_for_trait_sorted, \@pheno_for_trait_check, 'check pheno traits 70668 from phenotyping spreadsheet upload' );

@pheno_for_trait = $tn->get_phenotypes_for_trait(70741);
@pheno_for_trait_sorted = sort {$a <=> $b} @pheno_for_trait;
#print STDERR Dumper @pheno_for_trait_sorted;
@pheno_for_trait_check = ('30','30','30','30','30','30','30','30','35','35','35','35','35','35','35','35','38','38','38','38','38','38','38','38','39','39','39','39','39','39');
is_deeply(\@pheno_for_trait_sorted, \@pheno_for_trait_check, 'check pheno traits 70741 from phenotyping spreadsheet upload' );

@pheno_for_trait = $tn->get_phenotypes_for_trait(70773);
@pheno_for_trait_sorted = sort {$a <=> $b} @pheno_for_trait;
#print STDERR Dumper @pheno_for_trait_sorted;
@pheno_for_trait_check = ('20','20','21','21','22','22','23','23','24','24','25','25','26','26','27','27','28','28','29','29','30','30','31','31','32','32','33','33','34','34');
is_deeply(\@pheno_for_trait_sorted, \@pheno_for_trait_check, 'check pheno traits 70773 from phenotyping spreadsheet upload' );


$experiment = $c->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search({type_id => $phenotyping_experiment_cvterm_id});
my $post2_experiment_count = $experiment->count();
my $post2_experiment_diff = $post2_experiment_count - $pre_experiment_count;
print STDERR "Experiment count: ".$post2_experiment_diff."\n";
ok($post2_experiment_diff == 120, "Check num rows in NdExperiment table after second addition of phenotyping spreadsheet upload");

$phenotype_rs = $c->bcs_schema->resultset('Phenotype::Phenotype')->search({});
my $post2_phenotype_count = $phenotype_rs->count();
my $post2_phenotype_diff = $post2_phenotype_count - $pre_phenotype_count;
print STDERR "Phenotype count: ".$post2_phenotype_diff."\n";
ok($post2_phenotype_diff == 120, "Check num rows in Phenotype table after second addition of phenotyping spreadsheet upload");

$exp_prop_rs = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentprop')->search({});
my $post2_exp_prop_count = $exp_prop_rs->count();
my $post2_exp_prop_diff = $post2_exp_prop_count - $pre_exp_prop_count;
print STDERR "Experimentprop count: ".$post2_exp_prop_diff."\n";
ok($post2_exp_prop_diff == 240, "Check num rows in Experimentprop table after second addition of phenotyping spreadsheet upload");

$exp_proj_rs = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentProject')->search({});
my $post2_exp_proj_count = $exp_proj_rs->count();
my $post2_exp_proj_diff = $post2_exp_proj_count - $pre_exp_proj_count;
print STDERR "Experimentproject count: ".$post2_exp_proj_diff."\n";
ok($post2_exp_proj_diff == 120, "Check num rows in NdExperimentproject table after second addition of phenotyping spreadsheet upload");

$exp_stock_rs = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentStock')->search({});
my $post2_exp_stock_count = $exp_stock_rs->count();
my $post2_exp_stock_diff = $post2_exp_stock_count - $pre_exp_stock_count;
print STDERR "Experimentstock count: ".$post2_exp_stock_diff."\n";
ok($post2_exp_stock_diff == 120, "Check num rows in NdExperimentstock table after second addition of phenotyping spreadsheet upload");

$exp_pheno_rs = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentPhenotype')->search({});
my $post2_exp_pheno_count = $exp_pheno_rs->count();
my $post2_exp_pheno_diff = $post2_exp_pheno_count - $pre_exp_pheno_count;
print STDERR "Experimentphenotype count: ".$post2_exp_pheno_diff."\n";
ok($post2_exp_pheno_diff == 120, "Check num rows in NdExperimentphenotype table after second addition of phenotyping spreadsheet upload");

$md_rs = $c->metadata_schema->resultset('MdMetadata')->search({});
my $post2_md_count = $md_rs->count();
my $post2_md_diff = $post2_md_count - $pre_md_count;
print STDERR "MdMetadata count: ".$post2_md_diff."\n";
ok($post2_md_diff == 2, "Check num rows in MdMetadata table after second addition of phenotyping spreadsheet upload");

$md_files_rs = $c->metadata_schema->resultset('MdFiles')->search({});
my $post2_md_files_count = $md_files_rs->count();
my $post2_md_files_diff = $post2_md_files_count - $pre_md_files_count;
print STDERR "MdFiles count: ".$post2_md_files_diff."\n";
ok($post2_md_files_diff == 2, "Check num rows in MdFiles table after second addition of phenotyping spreadsheet upload");

$exp_md_files_rs = $c->phenome_schema->resultset('NdExperimentMdFiles')->search({});
my $post2_exp_md_files_count = $exp_md_files_rs->count();
my $post2_exp_md_files_diff = $post2_exp_md_files_count - $pre_exp_md_files_count;
print STDERR "Experimentphenotype count: ".$post2_exp_md_files_diff."\n";
ok($post2_exp_md_files_diff == 120, "Check num rows in NdExperimentMdFIles table after second addition of phenotyping spreadsheet upload");




#####################################
#Tests for fieldbook file parsing

#check that parse fails for spreadsheet file when using fieldbook parser
$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/trial/upload_phenotypin_spreadsheet.xls";
$validate_file = $parser->validate('field book', $filename, 1);
ok($validate_file != 1, "Check if parse validate fieldbook fails for spreadsheet file");

#check that parse fails for datacollector file when using fieldbook parser
$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/trial/data_collector_upload.xls";
$validate_file = $parser->validate('field book', $filename, 1);
ok($validate_file != 1, "Check if parse validate fieldbook fails for datacollector");

#Now parse fieldbook file using correct parser
$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/fieldbook/fieldbook_phenotype_file.csv";
$validate_file = $parser->validate('field book', $filename, 1);
ok($validate_file == 1, "Check if parse validate works for fieldbook");

$parsed_file = $parser->parse('field book', $filename, 1);
ok($parsed_file, "Check if parse parse fieldbook works");

#print STDERR Dumper $parsed_file;

is_deeply($parsed_file, {
          'plots' => [
                       'test_trial21',
                       'test_trial210',
                       'test_trial211',
                       'test_trial212',
                       'test_trial213',
                       'test_trial214',
                       'test_trial215',
                       'test_trial22',
                       'test_trial23',
                       'test_trial24',
                       'test_trial25',
                       'test_trial26',
                       'test_trial27',
                       'test_trial28',
                       'test_trial29'
                     ],
          'data' => {
                      'test_trial22' => {
                                          'dry yield|CO:0000014' => [
                                                                      '45',
                                                                      '2016-01-07 12:08:26-0500'
                                                                    ],
                                          'dry matter content|CO:0000092' => [
                                                                               '45',
                                                                               '2016-01-07 12:08:26-0500'
                                                                             ]
                                        },
                      'test_trial27' => {
                                          'dry yield|CO:0000014' => [
                                                                      '0',
                                                                      '2016-01-07 12:08:51-0500'
                                                                    ],
                                          'dry matter content|CO:0000092' => [
                                                                               '52',
                                                                               '2016-01-07 12:08:51-0500'
                                                                             ]
                                        },
                      'test_trial214' => {
                                           'dry yield|CO:0000014' => [
                                                                       '32',
                                                                       '2016-01-07 12:09:05-0500'
                                                                     ],
                                           'dry matter content|CO:0000092' => [
                                                                                '32',
                                                                                '2016-01-07 12:09:05-0500'
                                                                              ]
                                         },
                      'test_trial21' => {
                                          'dry yield|CO:0000014' => [
                                                                      '42',
                                                                      '2016-01-07 12:08:24-0500'
                                                                    ],
                                          'dry matter content|CO:0000092' => [
                                                                               '42',
                                                                               '2016-01-07 12:08:24-0500'
                                                                             ]
                                        },
                      'test_trial28' => {
                                          'dry matter content|CO:0000092' => [
                                                                               '41',
                                                                               '2016-01-07 12:08:53-0500'
                                                                             ],
                                          'dry yield|CO:0000014' => [
                                                                      '41',
                                                                      '2016-01-07 12:08:53-0500'
                                                                    ]
                                        },
                      'test_trial23' => {
                                          'dry yield|CO:0000014' => [
                                                                      '41',
                                                                      '2016-01-07 12:08:27-0500'
                                                                    ],
                                          'dry matter content|CO:0000092' => [
                                                                               '41',
                                                                               '2016-01-07 12:08:27-0500'
                                                                             ]
                                        },
                      'test_trial215' => {
                                           'dry matter content|CO:0000092' => [
                                                                                '31',
                                                                                '2016-01-07 12:09:07-0500'
                                                                              ],
                                           'dry yield|CO:0000014' => [
                                                                       '31',
                                                                       '2016-01-07 12:09:07-0500'
                                                                     ]
                                         },
                      'test_trial24' => {
                                          'dry yield|CO:0000014' => [
                                                                      '14',
                                                                      '2016-01-07 12:08:46-0500'
                                                                    ],
                                          'dry matter content|CO:0000092' => [
                                                                               '14',
                                                                               '2016-01-07 12:08:46-0500'
                                                                             ]
                                        },
                      'test_trial213' => {
                                           'dry yield|CO:0000014' => [
                                                                       '35',
                                                                       '2016-01-07 12:09:04-0500'
                                                                     ],
                                           'dry matter content|CO:0000092' => [
                                                                                '35',
                                                                                '2016-01-07 12:09:04-0500'
                                                                              ]
                                         },
                      'test_trial212' => {
                                           'dry yield|CO:0000014' => [
                                                                       '42',
                                                                       '2016-01-07 12:09:02-0500'
                                                                     ],
                                           'dry matter content|CO:0000092' => [
                                                                                '42',
                                                                                '2016-01-07 12:09:02-0500'
                                                                              ]
                                         },
                      'test_trial210' => {
                                           'dry yield|CO:0000014' => [
                                                                       '12',
                                                                       '2016-01-07 12:08:56-0500'
                                                                     ],
                                           'dry matter content|CO:0000092' => [
                                                                                '12',
                                                                                '2016-01-07 12:08:56-0500'
                                                                              ]
                                         },
                      'test_trial25' => {
                                          'dry yield|CO:0000014' => [
                                                                      '25',
                                                                      '2016-01-07 12:08:48-0500'
                                                                    ],
                                          'dry matter content|CO:0000092' => [
                                                                               '25',
                                                                               '2016-01-07 12:08:48-0500'
                                                                             ]
                                        },
                      'test_trial211' => {
                                           'dry matter content|CO:0000092' => [
                                                                                '13',
                                                                                '2016-01-07 12:08:58-0500'
                                                                              ],
                                           'dry yield|CO:0000014' => [
                                                                       '13',
                                                                       '2016-01-07 12:08:58-0500'
                                                                     ]
                                         },
                      'test_trial29' => {
                                          'dry matter content|CO:0000092' => [
                                                                               '',
                                                                               '2016-01-07 12:08:55-0500'
                                                                             ],
                                          'dry yield|CO:0000014' => [
                                                                      '24',
                                                                      '2016-01-07 12:08:55-0500'
                                                                    ]
                                        },
                      'test_trial26' => {
                                          'dry matter content|CO:0000092' => [
                                                                               '',
                                                                               '2016-01-07 12:08:49-0500'
                                                                             ],
                                          'dry yield|CO:0000014' => [
                                                                      '0',
                                                                      '2016-01-07 12:08:49-0500'
                                                                    ]
                                        }
                    },
          'traits' => [
                        'dry matter content|CO:0000092',
                        'dry yield|CO:0000014'
                      ]
        }, "Check parse fieldbook");


$phenotype_metadata{'archived_file'} = $filename;
$phenotype_metadata{'archived_file_type'}="tablet phenotype file";
$phenotype_metadata{'operator'}="janedoe";
$phenotype_metadata{'date'}="2016-01-16_03:15:26";
%parsed_data = %{$parsed_file->{'data'}};
@plots = @{$parsed_file->{'plots'}};
@traits = @{$parsed_file->{'traits'}};

$store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new();
$size = scalar(@plots) * scalar(@traits);
$stored_phenotype_error_msg = $store_phenotypes->store($c,$size,\@plots,\@traits, \%parsed_data, \%phenotype_metadata, 'plots');
ok(!$stored_phenotype_error_msg, "check that store fieldbook works");

$tn = CXGN::Trial->new( { bcs_schema => $f->bcs_schema(),
				trial_id => 137 });

$traits_assayed  = $tn->get_traits_assayed();
@traits_assayed_sorted = sort {$a->[0] cmp $b->[0]} @$traits_assayed;
#print STDERR Dumper @traits_assayed_sorted;
@traits_assayed_check = ([70666,'Fresh root weight'], [70668,'Harvest index variable'], [70727, 'Dry yield'], [70741,'Dry matter content percentage'], [70773,'Fresh shoot weight measurement in kg']);
is_deeply(\@traits_assayed_sorted, \@traits_assayed_check, 'check traits assayed from phenotyping spreadsheet upload' );

my @pheno_for_trait = $tn->get_phenotypes_for_trait(70727);
my @pheno_for_trait_sorted = sort {$a <=> $b} @pheno_for_trait;
#print STDERR Dumper @pheno_for_trait_sorted;
@pheno_for_trait_check = ('0','0','12','13','14','24','25','31','32','35','41','41','42','42','45');
is_deeply(\@pheno_for_trait_sorted, \@pheno_for_trait_check, 'check pheno traits 70727 from phenotyping spreadsheet upload' );

my @pheno_for_trait = $tn->get_phenotypes_for_trait(70741);
my @pheno_for_trait_sorted = sort {$a <=> $b} @pheno_for_trait;
#print STDERR Dumper @pheno_for_trait_sorted;
@pheno_for_trait_check = ('12','13','14','25','30','30','30','30','30','30','30','30','31','32','35','35','35','35','35','35','35','35','35','38','38','38','38','38','38','38','38','39','39','39','39','39','39','41','41','42','42','45','52');
is_deeply(\@pheno_for_trait_sorted, \@pheno_for_trait_check, 'check pheno traits 70741 from phenotyping spreadsheet upload' );


$experiment = $c->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search({type_id => $phenotyping_experiment_cvterm_id});
$post1_experiment_count = $experiment->count();
$post1_experiment_diff = $post1_experiment_count - $pre_experiment_count;
print STDERR "Experiment count: ".$post1_experiment_diff."\n";
ok($post1_experiment_diff == 148, "Check num rows in NdExperiment table after addition of fieldbook upload");

$phenotype_rs = $c->bcs_schema->resultset('Phenotype::Phenotype')->search({});
$post1_phenotype_count = $phenotype_rs->count();
$post1_phenotype_diff = $post1_phenotype_count - $pre_phenotype_count;
print STDERR "Phenotype count: ".$post1_phenotype_diff."\n";
ok($post1_phenotype_diff == 148, "Check num rows in Phenotype table after addition of fieldbook upload");

$exp_prop_rs = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentprop')->search({});
$post1_exp_prop_count = $exp_prop_rs->count();
$post1_exp_prop_diff = $post1_exp_prop_count - $pre_exp_prop_count;
print STDERR "Experimentprop count: ".$post1_exp_prop_diff."\n";
ok($post1_exp_prop_diff == 296, "Check num rows in Experimentprop table after addition of fieldbook upload");

$exp_proj_rs = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentProject')->search({});
$post1_exp_proj_count = $exp_proj_rs->count();
$post1_exp_proj_diff = $post1_exp_proj_count - $pre_exp_proj_count;
print STDERR "Experimentproject count: ".$post1_exp_proj_diff."\n";
ok($post1_exp_proj_diff == 148, "Check num rows in NdExperimentproject table after addition of fieldbook upload");

$exp_stock_rs = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentStock')->search({});
$post1_exp_stock_count = $exp_stock_rs->count();
$post1_exp_stock_diff = $post1_exp_stock_count - $pre_exp_stock_count;
print STDERR "Experimentstock count: ".$post1_exp_stock_diff."\n";
ok($post1_exp_stock_diff == 148, "Check num rows in NdExperimentstock table after addition of fieldbook upload");

$exp_pheno_rs = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentPhenotype')->search({});
my $post1_exp_pheno_count = $exp_pheno_rs->count();
my $post1_exp_pheno_diff = $post1_exp_pheno_count - $pre_exp_pheno_count;
print STDERR "Experimentphenotype count: ".$post1_exp_pheno_diff."\n";
ok($post1_exp_pheno_diff == 148, "Check num rows in NdExperimentphenotype table after addition of fieldbook upload");

$md_rs = $c->metadata_schema->resultset('MdMetadata')->search({});
my $post1_md_count = $md_rs->count();
my $post1_md_diff = $post1_md_count - $pre_md_count;
print STDERR "MdMetadata count: ".$post1_md_diff."\n";
ok($post1_md_diff == 3, "Check num rows in MdMetadata table after addition of fieldbook upload");

$md_files_rs = $c->metadata_schema->resultset('MdFiles')->search({});
my $post1_md_files_count = $md_files_rs->count();
my $post1_md_files_diff = $post1_md_files_count - $pre_md_files_count;
print STDERR "MdFiles count: ".$post1_md_files_diff."\n";
ok($post1_md_files_diff == 3, "Check num rows in MdFiles table after addition of fieldbook upload");

$exp_md_files_rs = $c->phenome_schema->resultset('NdExperimentMdFiles')->search({});
my $post1_exp_md_files_count = $exp_md_files_rs->count();
my $post1_exp_md_files_diff = $post1_exp_md_files_count - $pre_exp_md_files_count;
print STDERR "Experimentphenotype count: ".$post1_exp_md_files_diff."\n";
ok($post1_exp_md_files_diff == 148, "Check num rows in NdExperimentMdFIles table after addition fieldbook upload");




#####################################
#Tests for datacollector file parsing

#check that parse fails for spreadsheet file when using datacollector parser
$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/trial/upload_phenotypin_spreadsheet.xls";
$validate_file = $parser->validate('datacollector spreadsheet', $filename, 0);
ok($validate_file != 1, "Check if parse validate datacollector fails for spreadsheet file");

#check that parse fails for fieldbook file when using datacollector parser
$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/fieldbook/fieldbook_phenotype_file.csv";
$validate_file = $parser->validate('datacollector spreadsheet', $filename, 0);
ok($validate_file != 1, "Check if parse validate datacollector fails for fieldbook");

#Now parse datacollector file using correct parser
$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/trial/data_collector_upload.xls";
$validate_file = $parser->validate('datacollector spreadsheet', $filename, 0);
ok($validate_file == 1, "Check if parse validate worksfor datacollector");

$parsed_file = $parser->parse('datacollector spreadsheet', $filename, 0);
ok($parsed_file, "Check if parse parse datacollector works");

#print STDERR Dumper $parsed_file;

is_deeply($parsed_file, {
	'data' => {
	                      'test_trial22' => {
	                                          'fresh shoot weight|CO:0000016' => [
	                                                                               '11',
	                                                                               ''
	                                                                             ],
	                                          'fresh root weight|CO:0000012' => [
	                                                                              '37',
	                                                                              ''
	                                                                            ],
	                                          'dry matter content|CO:0000092' => [
	                                                                               '36',
	                                                                               ''
	                                                                             ],
	                                          'harvest index|CO:0000015' => [
	                                                                          '0.8',
	                                                                          ''
	                                                                        ]
	                                        },
	                      'test_trial214' => {
	                                           'fresh shoot weight|CO:0000016' => [
	                                                                                '23',
	                                                                                ''
	                                                                              ],
	                                           'dry matter content|CO:0000092' => [
	                                                                                '48',
	                                                                                ''
	                                                                              ],
	                                           'fresh root weight|CO:0000012' => [
	                                                                               '49',
	                                                                               ''
	                                                                             ],
	                                           'harvest index|CO:0000015' => [
	                                                                           '0.8',
	                                                                           ''
	                                                                         ]
	                                         },
	                      'test_trial24' => {
	                                          'fresh shoot weight|CO:0000016' => [
	                                                                               '13',
	                                                                               ''
	                                                                             ],
	                                          'dry matter content|CO:0000092' => [
	                                                                               '38',
	                                                                               ''
	                                                                             ],
	                                          'fresh root weight|CO:0000012' => [
	                                                                              '39',
	                                                                              ''
	                                                                            ],
	                                          'harvest index|CO:0000015' => [
	                                                                          '0',
	                                                                          ''
	                                                                        ]
	                                        },
	                      'test_trial215' => {
	                                           'fresh root weight|CO:0000012' => [
	                                                                               '50',
	                                                                               ''
	                                                                             ],
	                                           'dry matter content|CO:0000092' => [
	                                                                                '49',
	                                                                                ''
	                                                                              ],
	                                           'harvest index|CO:0000015' => [
	                                                                           '0.8',
	                                                                           ''
	                                                                         ],
	                                           'fresh shoot weight|CO:0000016' => [
	                                                                                '24',
	                                                                                ''
	                                                                              ]
	                                         },
	                      'test_trial212' => {
	                                           'dry matter content|CO:0000092' => [
	                                                                                '46',
	                                                                                ''
	                                                                              ],
	                                           'fresh root weight|CO:0000012' => [
	                                                                               '47',
	                                                                               ''
	                                                                             ],
	                                           'harvest index|CO:0000015' => [
	                                                                           '0.8',
	                                                                           ''
	                                                                         ],
	                                           'fresh shoot weight|CO:0000016' => [
	                                                                                '21',
	                                                                                ''
	                                                                              ]
	                                         },
	                      'test_trial211' => {
	                                           'harvest index|CO:0000015' => [
	                                                                           '0.8',
	                                                                           ''
	                                                                         ],
	                                           'dry matter content|CO:0000092' => [
	                                                                                '45',
	                                                                                ''
	                                                                              ],
	                                           'fresh root weight|CO:0000012' => [
	                                                                               '46',
	                                                                               ''
	                                                                             ],
	                                           'fresh shoot weight|CO:0000016' => [
	                                                                                '20',
	                                                                                ''
	                                                                              ]
	                                         },
	                      'test_trial25' => {
	                                          'dry matter content|CO:0000092' => [
	                                                                               '39',
	                                                                               ''
	                                                                             ],
	                                          'fresh root weight|CO:0000012' => [
	                                                                              '40',
	                                                                              ''
	                                                                            ],
	                                          'harvest index|CO:0000015' => [
	                                                                          '0.8',
	                                                                          ''
	                                                                        ],
	                                          'fresh shoot weight|CO:0000016' => [
	                                                                               '14',
	                                                                               ''
	                                                                             ]
	                                        },
	                      'test_trial213' => {
	                                           'fresh shoot weight|CO:0000016' => [
	                                                                                '22',
	                                                                                ''
	                                                                              ],
	                                           'harvest index|CO:0000015' => [
	                                                                           '0.8',
	                                                                           ''
	                                                                         ],
	                                           'fresh root weight|CO:0000012' => [
	                                                                               '48',
	                                                                               ''
	                                                                             ],
	                                           'dry matter content|CO:0000092' => [
	                                                                                '47',
	                                                                                ''
	                                                                              ]
	                                         },
	                      'test_trial28' => {
	                                          'fresh root weight|CO:0000012' => [
	                                                                              '43',
	                                                                              ''
	                                                                            ],
	                                          'dry matter content|CO:0000092' => [
	                                                                               '42',
	                                                                               ''
	                                                                             ],
	                                          'harvest index|CO:0000015' => [
	                                                                          '0.8',
	                                                                          ''
	                                                                        ],
	                                          'fresh shoot weight|CO:0000016' => [
	                                                                               '17',
	                                                                               ''
	                                                                             ]
	                                        },
	                      'test_trial27' => {
	                                          'fresh root weight|CO:0000012' => [
	                                                                              '42',
	                                                                              ''
	                                                                            ],
	                                          'dry matter content|CO:0000092' => [
	                                                                               '',
	                                                                               ''
	                                                                             ],
	                                          'harvest index|CO:0000015' => [
	                                                                          '0',
	                                                                          ''
	                                                                        ],
	                                          'fresh shoot weight|CO:0000016' => [
	                                                                               '16',
	                                                                               ''
	                                                                             ]
	                                        },
	                      'test_trial21' => {
	                                          'harvest index|CO:0000015' => [
	                                                                          '0.8',
	                                                                          ''
	                                                                        ],
	                                          'dry matter content|CO:0000092' => [
	                                                                               '35',
	                                                                               ''
	                                                                             ],
	                                          'fresh root weight|CO:0000012' => [
	                                                                              '36',
	                                                                              ''
	                                                                            ],
	                                          'fresh shoot weight|CO:0000016' => [
	                                                                               '10',
	                                                                               ''
	                                                                             ]
	                                        },
	                      'test_trial29' => {
	                                          'fresh shoot weight|CO:0000016' => [
	                                                                               '18',
	                                                                               ''
	                                                                             ],
	                                          'harvest index|CO:0000015' => [
	                                                                          '0.8',
	                                                                          ''
	                                                                        ],
	                                          'dry matter content|CO:0000092' => [
	                                                                               '43',
	                                                                               ''
	                                                                             ],
	                                          'fresh root weight|CO:0000012' => [
	                                                                              '',
	                                                                              ''
	                                                                            ]
	                                        },
	                      'test_trial26' => {
	                                          'fresh root weight|CO:0000012' => [
	                                                                              '41',
	                                                                              ''
	                                                                            ],
	                                          'dry matter content|CO:0000092' => [
	                                                                               '',
	                                                                               ''
	                                                                             ],
	                                          'harvest index|CO:0000015' => [
	                                                                          '0.8',
	                                                                          ''
	                                                                        ],
	                                          'fresh shoot weight|CO:0000016' => [
	                                                                               '15',
	                                                                               ''
	                                                                             ]
	                                        },
	                      'test_trial210' => {
	                                           'harvest index|CO:0000015' => [
	                                                                           '0.8',
	                                                                           ''
	                                                                         ],
	                                           'fresh root weight|CO:0000012' => [
	                                                                               '45',
	                                                                               ''
	                                                                             ],
	                                           'dry matter content|CO:0000092' => [
	                                                                                '44',
	                                                                                ''
	                                                                              ],
	                                           'fresh shoot weight|CO:0000016' => [
	                                                                                '19',
	                                                                                ''
	                                                                              ]
	                                         },
	                      'test_trial23' => {
	                                          'harvest index|CO:0000015' => [
	                                                                          '0.8',
	                                                                          ''
	                                                                        ],
	                                          'dry matter content|CO:0000092' => [
	                                                                               '37',
	                                                                               ''
	                                                                             ],
	                                          'fresh root weight|CO:0000012' => [
	                                                                              '38',
	                                                                              ''
	                                                                            ],
	                                          'fresh shoot weight|CO:0000016' => [
	                                                                               '12',
	                                                                               ''
	                                                                             ]
	                                        }
	                    },
	          'traits' => [
	                        'dry matter content|CO:0000092',
	                        'fresh root weight|CO:0000012',
	                        'fresh shoot weight|CO:0000016',
	                        'harvest index|CO:0000015'
	                      ],
	          'plots' => [
	                       'test_trial21',
	                       'test_trial210',
	                       'test_trial211',
	                       'test_trial212',
	                       'test_trial213',
	                       'test_trial214',
	                       'test_trial215',
	                       'test_trial22',
	                       'test_trial23',
	                       'test_trial24',
	                       'test_trial25',
	                       'test_trial26',
	                       'test_trial27',
	                       'test_trial28',
	                       'test_trial29'
	                     ]

        }, "Check datacollector parse");


$phenotype_metadata{'archived_file'} = $filename;
$phenotype_metadata{'archived_file_type'}="tablet phenotype file";
$phenotype_metadata{'operator'}="janedoe";
$phenotype_metadata{'date'}="2016-02-16_07:11:98";
%parsed_data = %{$parsed_file->{'data'}};
@plots = @{$parsed_file->{'plots'}};
@traits = @{$parsed_file->{'traits'}};

$store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new();
$size = scalar(@plots) * scalar(@traits);
$stored_phenotype_error_msg = $store_phenotypes->store($c,$size,\@plots,\@traits, \%parsed_data, \%phenotype_metadata, 'plots');
ok(!$stored_phenotype_error_msg, "check that store fieldbook works");

$tn = CXGN::Trial->new( { bcs_schema => $f->bcs_schema(),
				trial_id => 137 });

$traits_assayed  = $tn->get_traits_assayed();
@traits_assayed_sorted = sort {$a->[0] cmp $b->[0]} @$traits_assayed;
#print STDERR Dumper @traits_assayed_sorted;
@traits_assayed_check = ([70666,'Fresh root weight'], [70668,'Harvest index variable'], [70727, 'Dry yield'], [70741,'Dry matter content percentage'], [70773,'Fresh shoot weight measurement in kg']);
is_deeply(\@traits_assayed_sorted, \@traits_assayed_check, 'check traits assayed from phenotyping spreadsheet upload' );

my @pheno_for_trait = $tn->get_phenotypes_for_trait(70666);
my @pheno_for_trait_sorted = sort {$a <=> $b} @pheno_for_trait;
#print STDERR Dumper @pheno_for_trait_sorted;
my @pheno_for_trait_check = ('15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','36','37','38','39','40','41','42','43','45','46','47','48','49','50');
is_deeply(\@pheno_for_trait_sorted, \@pheno_for_trait_check, 'check pheno traits 70666 from phenotyping spreadsheet upload' );

@pheno_for_trait = $tn->get_phenotypes_for_trait(70668);
@pheno_for_trait_sorted = sort {$a <=> $b} @pheno_for_trait;
#print STDERR Dumper @pheno_for_trait_sorted;
@pheno_for_trait_check = ('0','0','0.8','0.8','0.8','0.8','0.8','0.8','0.8','0.8','0.8','0.8','0.8','0.8','0.8','0.8','0.8','1.8','1.8','2.8','2.8','3.8','3.8','4.8','4.8','5.8','5.8','6.8','6.8','7.8','7.8','8.8','8.8','9.8','9.8','10.8','10.8','11.8','11.8','12.8','12.8','13.8','13.8','14.8','14.8');
is_deeply(\@pheno_for_trait_sorted, \@pheno_for_trait_check, 'check pheno traits 70668 from phenotyping spreadsheet upload' );

@pheno_for_trait = $tn->get_phenotypes_for_trait(70741);
@pheno_for_trait_sorted = sort {$a <=> $b} @pheno_for_trait;
#print STDERR Dumper @pheno_for_trait_sorted;
@pheno_for_trait_check = ('12','13','14','25','30','30','30','30','30','30','30','30','31','32','35','35','35','35','35','35','35','35','35','35','36','37','38','38','38','38','38','38','38','38','38','39','39','39','39','39','39','39','41','41','42','42','42','43','44','45','45','46','47','48','49','52');
is_deeply(\@pheno_for_trait_sorted, \@pheno_for_trait_check, 'check pheno traits 70741 from phenotyping spreadsheet upload' );

@pheno_for_trait = $tn->get_phenotypes_for_trait(70773);
@pheno_for_trait_sorted = sort {$a <=> $b} @pheno_for_trait;
#print STDERR Dumper @pheno_for_trait_sorted;
@pheno_for_trait_check = ('10','11','12','13','14','15','16','17','18','19','20','20','20','21','21','21','22','22','22','23','23','23','24','24','24','25','25','26','26','27','27','28','28','29','29','30','30','31','31','32','32','33','33','34','34');
is_deeply(\@pheno_for_trait_sorted, \@pheno_for_trait_check, 'check pheno traits 70773 from phenotyping spreadsheet upload' );


$experiment = $c->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search({type_id => $phenotyping_experiment_cvterm_id});
$post1_experiment_count = $experiment->count();
$post1_experiment_diff = $post1_experiment_count - $pre_experiment_count;
print STDERR "Experiment count: ".$post1_experiment_diff."\n";
ok($post1_experiment_diff == 205, "Check num rows in NdExperiment table after addition of datacollector upload");

$phenotype_rs = $c->bcs_schema->resultset('Phenotype::Phenotype')->search({});
$post1_phenotype_count = $phenotype_rs->count();
$post1_phenotype_diff = $post1_phenotype_count - $pre_phenotype_count;
print STDERR "Phenotype count: ".$post1_phenotype_diff."\n";
ok($post1_phenotype_diff == 205, "Check num rows in Phenotype table after addition of datacollector upload");

$exp_prop_rs = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentprop')->search({});
$post1_exp_prop_count = $exp_prop_rs->count();
$post1_exp_prop_diff = $post1_exp_prop_count - $pre_exp_prop_count;
print STDERR "Experimentprop count: ".$post1_exp_prop_diff."\n";
ok($post1_exp_prop_diff == 410, "Check num rows in Experimentprop table after addition of datacollector upload");

$exp_proj_rs = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentProject')->search({});
$post1_exp_proj_count = $exp_proj_rs->count();
$post1_exp_proj_diff = $post1_exp_proj_count - $pre_exp_proj_count;
print STDERR "Experimentproject count: ".$post1_exp_proj_diff."\n";
ok($post1_exp_proj_diff == 205, "Check num rows in NdExperimentproject table after addition of datacollector upload");

$exp_stock_rs = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentStock')->search({});
$post1_exp_stock_count = $exp_stock_rs->count();
$post1_exp_stock_diff = $post1_exp_stock_count - $pre_exp_stock_count;
print STDERR "Experimentstock count: ".$post1_exp_stock_diff."\n";
ok($post1_exp_stock_diff == 205, "Check num rows in NdExperimentstock table after addition of datacollector upload");

$exp_pheno_rs = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentPhenotype')->search({});
my $post1_exp_pheno_count = $exp_pheno_rs->count();
my $post1_exp_pheno_diff = $post1_exp_pheno_count - $pre_exp_pheno_count;
print STDERR "Experimentphenotype count: ".$post1_exp_pheno_diff."\n";
ok($post1_exp_pheno_diff == 205, "Check num rows in NdExperimentphenotype table after addition of datacollector upload");

$md_rs = $c->metadata_schema->resultset('MdMetadata')->search({});
my $post1_md_count = $md_rs->count();
my $post1_md_diff = $post1_md_count - $pre_md_count;
print STDERR "MdMetadata count: ".$post1_md_diff."\n";
ok($post1_md_diff == 4, "Check num rows in MdMetadata table after addition of datacollector upload");

$md_files_rs = $c->metadata_schema->resultset('MdFiles')->search({});
my $post1_md_files_count = $md_files_rs->count();
my $post1_md_files_diff = $post1_md_files_count - $pre_md_files_count;
print STDERR "MdFiles count: ".$post1_md_files_diff."\n";
ok($post1_md_files_diff == 4, "Check num rows in MdFiles table after addition of datacollector upload");

$exp_md_files_rs = $c->phenome_schema->resultset('NdExperimentMdFiles')->search({});
my $post1_exp_md_files_count = $exp_md_files_rs->count();
my $post1_exp_md_files_diff = $post1_exp_md_files_count - $pre_exp_md_files_count;
print STDERR "Experimentphenotype count: ".$post1_exp_md_files_diff."\n";
ok($post1_exp_md_files_diff == 205, "Check num rows in NdExperimentMdFIles table after addition datacollector upload");



#Upload a large phenotyping spreadsheet (>100 entries)


$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/trial/upload_phenotypin_spreadsheet_large.xls";
$validate_file = $parser->validate('phenotype spreadsheet', $filename, 0, 'plots');
ok($validate_file == 1, "Check if parse validate works for large phenotype file");

$parsed_file = $parser->parse('phenotype spreadsheet', $filename, 0, 'plots');
ok($parsed_file, "Check if parse parse phenotype spreadsheet works");

#print STDERR Dumper $parsed_file;

is_deeply($parsed_file, {
	'data' => {
	                      'test_trial213' => {
	                                           'fresh root weight|CO:0000012' => [
	                                                                               '15',
	                                                                               ''
	                                                                             ],
	                                           'flower|CO:0000111' => [
	                                                                    '1',
	                                                                    ''
	                                                                  ],
	                                           'fresh shoot weight|CO:0000016' => [
	                                                                                '32',
	                                                                                ''
	                                                                              ],
	                                           'sprouting|CO:0000008' => [
	                                                                       '8',
	                                                                       ''
	                                                                     ],
	                                           'harvest index|CO:0000015' => [
	                                                                           '12.8',
	                                                                           ''
	                                                                         ],
	                                           'dry matter content|CO:0000092' => [
	                                                                                '35',
	                                                                                ''
	                                                                              ],
	                                           'root number|CO:0000011' => [
	                                                                         '8',
	                                                                         ''
	                                                                       ],
	                                           'top yield|CO:0000017' => [
	                                                                       '4.4',
	                                                                       ''
	                                                                     ]
	                                         },
	                      'test_trial27' => {
	                                          'fresh root weight|CO:0000012' => [
	                                                                              '15',
	                                                                              ''
	                                                                            ],
	                                          'harvest index|CO:0000015' => [
	                                                                          '6.8',
	                                                                          ''
	                                                                        ],
	                                          'sprouting|CO:0000008' => [
	                                                                      '34',
	                                                                      ''
	                                                                    ],
	                                          'fresh shoot weight|CO:0000016' => [
	                                                                               '26',
	                                                                               ''
	                                                                             ],
	                                          'flower|CO:0000111' => [
	                                                                   '1',
	                                                                   ''
	                                                                 ],
	                                          'root number|CO:0000011' => [
	                                                                        '8',
	                                                                        ''
	                                                                      ],
	                                          'top yield|CO:0000017' => [
	                                                                      '9',
	                                                                      ''
	                                                                    ],
	                                          'dry matter content|CO:0000092' => [
	                                                                               '38',
	                                                                               ''
	                                                                             ]
	                                        },
	                      'test_trial212' => {
	                                           'fresh shoot weight|CO:0000016' => [
	                                                                                '31',
	                                                                                ''
	                                                                              ],
	                                           'flower|CO:0000111' => [
	                                                                    '0',
	                                                                    ''
	                                                                  ],
	                                           'sprouting|CO:0000008' => [
	                                                                       '56',
	                                                                       ''
	                                                                     ],
	                                           'harvest index|CO:0000015' => [
	                                                                           '11.8',
	                                                                           ''
	                                                                         ],
	                                           'dry matter content|CO:0000092' => [
	                                                                                '39',
	                                                                                ''
	                                                                              ],
	                                           'root number|CO:0000011' => [
	                                                                         '6',
	                                                                         ''
	                                                                       ],
	                                           'top yield|CO:0000017' => [
	                                                                       '7',
	                                                                       ''
	                                                                     ],
	                                           'fresh root weight|CO:0000012' => [
	                                                                               '15',
	                                                                               ''
	                                                                             ]
	                                         },
	                      'test_trial29' => {
	                                          'dry matter content|CO:0000092' => [
	                                                                               '35',
	                                                                               ''
	                                                                             ],
	                                          'top yield|CO:0000017' => [
	                                                                      '3',
	                                                                      ''
	                                                                    ],
	                                          'root number|CO:0000011' => [
	                                                                        '6',
	                                                                        ''
	                                                                      ],
	                                          'fresh shoot weight|CO:0000016' => [
	                                                                               '28',
	                                                                               ''
	                                                                             ],
	                                          'flower|CO:0000111' => [
	                                                                   '1',
	                                                                   ''
	                                                                 ],
	                                          'harvest index|CO:0000015' => [
	                                                                          '8.8',
	                                                                          ''
	                                                                        ],
	                                          'sprouting|CO:0000008' => [
	                                                                      '76',
	                                                                      ''
	                                                                    ],
	                                          'fresh root weight|CO:0000012' => [
	                                                                              '15',
	                                                                              ''
	                                                                            ]
	                                        },
	                      'test_trial25' => {
	                                          'fresh root weight|CO:0000012' => [
	                                                                              '15',
	                                                                              ''
	                                                                            ],
	                                          'root number|CO:0000011' => [
	                                                                        '6',
	                                                                        ''
	                                                                      ],
	                                          'top yield|CO:0000017' => [
	                                                                      '2',
	                                                                      ''
	                                                                    ],
	                                          'dry matter content|CO:0000092' => [
	                                                                               '35',
	                                                                               ''
	                                                                             ],
	                                          'sprouting|CO:0000008' => [
	                                                                      '56',
	                                                                      ''
	                                                                    ],
	                                          'harvest index|CO:0000015' => [
	                                                                          '',
	                                                                          ''
	                                                                        ],
	                                          'fresh shoot weight|CO:0000016' => [
	                                                                               '24',
	                                                                               ''
	                                                                             ],
	                                          'flower|CO:0000111' => [
	                                                                   '1',
	                                                                   ''
	                                                                 ]
	                                        },
	                      'test_trial23' => {
	                                          'fresh root weight|CO:0000012' => [
	                                                                              '15',
	                                                                              ''
	                                                                            ],
	                                          'harvest index|CO:0000015' => [
	                                                                          '2.8',
	                                                                          ''
	                                                                        ],
	                                          'sprouting|CO:0000008' => [
	                                                                      '23',
	                                                                      ''
	                                                                    ],
	                                          'flower|CO:0000111' => [
	                                                                   '1',
	                                                                   ''
	                                                                 ],
	                                          'fresh shoot weight|CO:0000016' => [
	                                                                               '22',
	                                                                               ''
	                                                                             ],
	                                          'top yield|CO:0000017' => [
	                                                                      '5',
	                                                                      ''
	                                                                    ],
	                                          'root number|CO:0000011' => [
	                                                                        '4',
	                                                                        ''
	                                                                      ],
	                                          'dry matter content|CO:0000092' => [
	                                                                               '38',
	                                                                               ''
	                                                                             ]
	                                        },
	                      'test_trial24' => {
	                                          'flower|CO:0000111' => [
	                                                                   '1',
	                                                                   ''
	                                                                 ],
	                                          'fresh shoot weight|CO:0000016' => [
	                                                                               '23',
	                                                                               ''
	                                                                             ],
	                                          'sprouting|CO:0000008' => [
	                                                                      '78',
	                                                                      ''
	                                                                    ],
	                                          'harvest index|CO:0000015' => [
	                                                                          '3.8',
	                                                                          ''
	                                                                        ],
	                                          'dry matter content|CO:0000092' => [
	                                                                               '39',
	                                                                               ''
	                                                                             ],
	                                          'top yield|CO:0000017' => [
	                                                                      '7',
	                                                                      ''
	                                                                    ],
	                                          'root number|CO:0000011' => [
	                                                                        '11',
	                                                                        ''
	                                                                      ],
	                                          'fresh root weight|CO:0000012' => [
	                                                                              '15',
	                                                                              ''
	                                                                            ]
	                                        },
	                      'test_trial210' => {
	                                           'dry matter content|CO:0000092' => [
	                                                                                '30',
	                                                                                ''
	                                                                              ],
	                                           'root number|CO:0000011' => [
	                                                                         '',
	                                                                         ''
	                                                                       ],
	                                           'top yield|CO:0000017' => [
	                                                                       '2',
	                                                                       ''
	                                                                     ],
	                                           'fresh shoot weight|CO:0000016' => [
	                                                                                '29',
	                                                                                ''
	                                                                              ],
	                                           'flower|CO:0000111' => [
	                                                                    '0',
	                                                                    ''
	                                                                  ],
	                                           'sprouting|CO:0000008' => [
	                                                                       '45',
	                                                                       ''
	                                                                     ],
	                                           'harvest index|CO:0000015' => [
	                                                                           '9.8',
	                                                                           ''
	                                                                         ],
	                                           'fresh root weight|CO:0000012' => [
	                                                                               '15',
	                                                                               ''
	                                                                             ]
	                                         },
	                      'test_trial215' => {
	                                           'dry matter content|CO:0000092' => [
	                                                                                '38',
	                                                                                ''
	                                                                              ],
	                                           'root number|CO:0000011' => [
	                                                                         '5',
	                                                                         ''
	                                                                       ],
	                                           'top yield|CO:0000017' => [
	                                                                       '7',
	                                                                       ''
	                                                                     ],
	                                           'fresh shoot weight|CO:0000016' => [
	                                                                                '34',
	                                                                                ''
	                                                                              ],
	                                           'flower|CO:0000111' => [
	                                                                    '1',
	                                                                    ''
	                                                                  ],
	                                           'harvest index|CO:0000015' => [
	                                                                           '14.8',
	                                                                           ''
	                                                                         ],
	                                           'sprouting|CO:0000008' => [
	                                                                       '25',
	                                                                       ''
	                                                                     ],
	                                           'fresh root weight|CO:0000012' => [
	                                                                               '15',
	                                                                               ''
	                                                                             ]
	                                         },
	                      'test_trial214' => {
	                                           'fresh root weight|CO:0000012' => [
	                                                                               '15',
	                                                                               ''
	                                                                             ],
	                                           'harvest index|CO:0000015' => [
	                                                                           '13.8',
	                                                                           ''
	                                                                         ],
	                                           'sprouting|CO:0000008' => [
	                                                                       '87',
	                                                                       ''
	                                                                     ],
	                                           'fresh shoot weight|CO:0000016' => [
	                                                                                '33',
	                                                                                ''
	                                                                              ],
	                                           'flower|CO:0000111' => [
	                                                                    '1',
	                                                                    ''
	                                                                  ],
	                                           'top yield|CO:0000017' => [
	                                                                       '7.5',
	                                                                       ''
	                                                                     ],
	                                           'root number|CO:0000011' => [
	                                                                         '4',
	                                                                         ''
	                                                                       ],
	                                           'dry matter content|CO:0000092' => [
	                                                                                '30',
	                                                                                ''
	                                                                              ]
	                                         },
	                      'test_trial28' => {
	                                          'fresh root weight|CO:0000012' => [
	                                                                              '15',
	                                                                              ''
	                                                                            ],
	                                          'dry matter content|CO:0000092' => [
	                                                                               '39',
	                                                                               ''
	                                                                             ],
	                                          'top yield|CO:0000017' => [
	                                                                      '6',
	                                                                      ''
	                                                                    ],
	                                          'root number|CO:0000011' => [
	                                                                        '9',
	                                                                        ''
	                                                                      ],
	                                          'flower|CO:0000111' => [
	                                                                   '0',
	                                                                   ''
	                                                                 ],
	                                          'fresh shoot weight|CO:0000016' => [
	                                                                               '27',
	                                                                               ''
	                                                                             ],
	                                          'sprouting|CO:0000008' => [
	                                                                      '23',
	                                                                      ''
	                                                                    ],
	                                          'harvest index|CO:0000015' => [
	                                                                          '7.8',
	                                                                          ''
	                                                                        ]
	                                        },
	                      'test_trial26' => {
	                                          'fresh root weight|CO:0000012' => [
	                                                                              '15',
	                                                                              ''
	                                                                            ],
	                                          'fresh shoot weight|CO:0000016' => [
	                                                                               '25',
	                                                                               ''
	                                                                             ],
	                                          'flower|CO:0000111' => [
	                                                                   '1',
	                                                                   ''
	                                                                 ],
	                                          'harvest index|CO:0000015' => [
	                                                                          '5.8',
	                                                                          ''
	                                                                        ],
	                                          'sprouting|CO:0000008' => [
	                                                                      '45',
	                                                                      ''
	                                                                    ],
	                                          'dry matter content|CO:0000092' => [
	                                                                               '30',
	                                                                               ''
	                                                                             ],
	                                          'root number|CO:0000011' => [
	                                                                        '4',
	                                                                        ''
	                                                                      ],
	                                          'top yield|CO:0000017' => [
	                                                                      '4',
	                                                                      ''
	                                                                    ]
	                                        },
	                      'test_trial21' => {
	                                          'fresh root weight|CO:0000012' => [
	                                                                              '15',
	                                                                              ''
	                                                                            ],
	                                          'harvest index|CO:0000015' => [
	                                                                          '0.8',
	                                                                          ''
	                                                                        ],
	                                          'sprouting|CO:0000008' => [
	                                                                      '45',
	                                                                      ''
	                                                                    ],
	                                          'flower|CO:0000111' => [
	                                                                   '0',
	                                                                   ''
	                                                                 ],
	                                          'fresh shoot weight|CO:0000016' => [
	                                                                               '20',
	                                                                               ''
	                                                                             ],
	                                          'root number|CO:0000011' => [
	                                                                        '3',
	                                                                        ''
	                                                                      ],
	                                          'top yield|CO:0000017' => [
	                                                                      '2',
	                                                                      ''
	                                                                    ],
	                                          'dry matter content|CO:0000092' => [
	                                                                               '35',
	                                                                               ''
	                                                                             ]
	                                        },
	                      'test_trial211' => {
	                                           'fresh root weight|CO:0000012' => [
	                                                                               '15',
	                                                                               ''
	                                                                             ],
	                                           'dry matter content|CO:0000092' => [
	                                                                                '38',
	                                                                                ''
	                                                                              ],
	                                           'top yield|CO:0000017' => [
	                                                                       '4',
	                                                                       ''
	                                                                     ],
	                                           'root number|CO:0000011' => [
	                                                                         '4',
	                                                                         ''
	                                                                       ],
	                                           'flower|CO:0000111' => [
	                                                                    '0',
	                                                                    ''
	                                                                  ],
	                                           'fresh shoot weight|CO:0000016' => [
	                                                                                '30',
	                                                                                ''
	                                                                              ],
	                                           'sprouting|CO:0000008' => [
	                                                                       '2',
	                                                                       ''
	                                                                     ],
	                                           'harvest index|CO:0000015' => [
	                                                                           '10.8',
	                                                                           ''
	                                                                         ]
	                                         },
	                      'test_trial22' => {
	                                          'fresh shoot weight|CO:0000016' => [
	                                                                               '21',
	                                                                               ''
	                                                                             ],
	                                          'flower|CO:0000111' => [
	                                                                   '1',
	                                                                   ''
	                                                                 ],
	                                          'harvest index|CO:0000015' => [
	                                                                          '1.8',
	                                                                          ''
	                                                                        ],
	                                          'sprouting|CO:0000008' => [
	                                                                      '43',
	                                                                      ''
	                                                                    ],
	                                          'dry matter content|CO:0000092' => [
	                                                                               '30',
	                                                                               ''
	                                                                             ],
	                                          'root number|CO:0000011' => [
	                                                                        '7',
	                                                                        ''
	                                                                      ],
	                                          'top yield|CO:0000017' => [
	                                                                      '3',
	                                                                      ''
	                                                                    ],
	                                          'fresh root weight|CO:0000012' => [
	                                                                              '15',
	                                                                              ''
	                                                                            ]
	                                        }
	                    },
	          'plots' => [
	                       'test_trial21',
	                       'test_trial210',
	                       'test_trial211',
	                       'test_trial212',
	                       'test_trial213',
	                       'test_trial214',
	                       'test_trial215',
	                       'test_trial22',
	                       'test_trial23',
	                       'test_trial24',
	                       'test_trial25',
	                       'test_trial26',
	                       'test_trial27',
	                       'test_trial28',
	                       'test_trial29'
	                     ],
	          'traits' => [
	                        'dry matter content|CO:0000092',
	                        'flower|CO:0000111',
	                        'fresh root weight|CO:0000012',
	                        'fresh shoot weight|CO:0000016',
	                        'harvest index|CO:0000015',
	                        'root number|CO:0000011',
	                        'sprouting|CO:0000008',
	                        'top yield|CO:0000017'
	                      ]
        }, "Check parse large phenotyping spreadsheet" );


$phenotype_metadata{'archived_file'} = $filename;
$phenotype_metadata{'archived_file_type'}="spreadsheet phenotype file";
$phenotype_metadata{'operator'}="janedoe";
$phenotype_metadata{'date'}="2016-02-16_05:55:55";
%parsed_data = %{$parsed_file->{'data'}};
@plots = @{$parsed_file->{'plots'}};
@traits = @{$parsed_file->{'traits'}};

$store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new();
$size = scalar(@plots) * scalar(@traits);
$stored_phenotype_error_msg = $store_phenotypes->store($c,$size,\@plots,\@traits, \%parsed_data, \%phenotype_metadata, 'plots');
ok(!$stored_phenotype_error_msg, "check that store large pheno spreadsheet works");

$tn = CXGN::Trial->new( { bcs_schema => $f->bcs_schema(),
				trial_id => 137 });

$traits_assayed  = $tn->get_traits_assayed();
@traits_assayed_sorted = sort {$a->[0] cmp $b->[0]} @$traits_assayed;
#print STDERR Dumper @traits_assayed_sorted;
@traits_assayed_check = ([70666,'Fresh root weight'], [70668,'Harvest index variable'], [70681, 'Top yield'], [70700, 'Sprouting proportion'], [70706, 'Root number counting'], [70713, 'Flower'], [70727, 'Dry yield'], [70741,'Dry matter content percentage'], [70773,'Fresh shoot weight measurement in kg']);
is_deeply(\@traits_assayed_sorted, \@traits_assayed_check, 'check traits assayed from large phenotyping spreadsheet upload' );

@pheno_for_trait = $tn->get_phenotypes_for_trait(70666);
@pheno_for_trait_sorted = sort {$a <=> $b} @pheno_for_trait;
#print STDERR Dumper @pheno_for_trait_sorted;
@pheno_for_trait_check = ('15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','15','36','37','38','39','40','41','42','43','45','46','47','48','49','50');
is_deeply(\@pheno_for_trait_sorted, \@pheno_for_trait_check, 'check pheno traits 70666 from large phenotyping spreadsheet upload' );

@pheno_for_trait = $tn->get_phenotypes_for_trait(70668);
@pheno_for_trait_sorted = sort {$a <=> $b} @pheno_for_trait;
#print STDERR Dumper @pheno_for_trait_sorted;
@pheno_for_trait_check = ('0','0','0.8','0.8','0.8','0.8','0.8','0.8','0.8','0.8','0.8','0.8','0.8','0.8','0.8','0.8','0.8','0.8','1.8','1.8','1.8','2.8','2.8','2.8','3.8','3.8','3.8','4.8','4.8','5.8','5.8','5.8','6.8','6.8','6.8','7.8','7.8','7.8','8.8','8.8','8.8','9.8','9.8','9.8','10.8','10.8','10.8','11.8','11.8','11.8','12.8','12.8','12.8','13.8','13.8','13.8','14.8','14.8','14.8');
is_deeply(\@pheno_for_trait_sorted, \@pheno_for_trait_check, 'check pheno traits 70668 from large phenotyping spreadsheet upload' );

@pheno_for_trait = $tn->get_phenotypes_for_trait(70741);
@pheno_for_trait_sorted = sort {$a <=> $b} @pheno_for_trait;
#print STDERR Dumper @pheno_for_trait_sorted;
@pheno_for_trait_check = ('12','13','14','25','30','30','30','30','30','30','30','30','30','30','30','30','31','32','35','35','35','35','35','35','35','35','35','35','35','35','35','35','36','37','38','38','38','38','38','38','38','38','38','38','38','38','38','39','39','39','39','39','39','39','39','39','39','41','41','42','42','42','43','44','45','45','46','47','48','49','52');
is_deeply(\@pheno_for_trait_sorted, \@pheno_for_trait_check, 'check pheno traits 70741 from large phenotyping spreadsheet upload' );

@pheno_for_trait = $tn->get_phenotypes_for_trait(70773);
@pheno_for_trait_sorted = sort {$a <=> $b} @pheno_for_trait;
#print STDERR Dumper @pheno_for_trait_sorted;
@pheno_for_trait_check = ('10','11','12','13','14','15','16','17','18','19','20','20','20','20','21','21','21','21','22','22','22','22','23','23','23','23','24','24','24','24','25','25','25','26','26','26','27','27','27','28','28','28','29','29','29','30','30','30','31','31','31','32','32','32','33','33','33','34','34','34');
is_deeply(\@pheno_for_trait_sorted, \@pheno_for_trait_check, 'check pheno traits 70773 from large phenotyping spreadsheet upload' );

@pheno_for_trait = $tn->get_phenotypes_for_trait(70681);
@pheno_for_trait_sorted = sort {$a <=> $b} @pheno_for_trait;
#print STDERR Dumper @pheno_for_trait_sorted;
@pheno_for_trait_check = ('2','2','2','3','3','4','4','4.4','5','6','7','7','7','7.5','9');
is_deeply(\@pheno_for_trait_sorted, \@pheno_for_trait_check, 'check pheno traits 70681 from large phenotyping spreadsheet upload' );

@pheno_for_trait = $tn->get_phenotypes_for_trait(70700);
@pheno_for_trait_sorted = sort {$a <=> $b} @pheno_for_trait;
#print STDERR Dumper @pheno_for_trait_sorted;
@pheno_for_trait_check = ('2','8','23','23','25','34','43','45','45','45','56','56','76','78','87');
is_deeply(\@pheno_for_trait_sorted, \@pheno_for_trait_check, 'check pheno traits 70700 from large phenotyping spreadsheet upload' );

@pheno_for_trait = $tn->get_phenotypes_for_trait(70713);
@pheno_for_trait_sorted = sort {$a <=> $b} @pheno_for_trait;
#print STDERR Dumper @pheno_for_trait_sorted;
@pheno_for_trait_check = ('0','0','0','0','0','1','1','1','1','1','1','1','1','1','1');
is_deeply(\@pheno_for_trait_sorted, \@pheno_for_trait_check, 'check pheno traits 70713 from large  phenotyping spreadsheet upload' );

@pheno_for_trait = $tn->get_phenotypes_for_trait(70706);
@pheno_for_trait_sorted = sort {$a <=> $b} @pheno_for_trait;
#print STDERR Dumper @pheno_for_trait_sorted;
@pheno_for_trait_check = ('3','4','4','4','4','5','6','6','6','7','8','8','9','11');
is_deeply(\@pheno_for_trait_sorted, \@pheno_for_trait_check, 'check pheno traits 70706 from large phenotyping spreadsheet upload' );



$experiment = $c->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search({type_id => $phenotyping_experiment_cvterm_id}, {order_by => {-asc => 'nd_experiment_id'}});
$post1_experiment_count = $experiment->count();
$post1_experiment_diff = $post1_experiment_count - $pre_experiment_count;
print STDERR "Experiment count: ".$post1_experiment_diff."\n";
ok($post1_experiment_diff == 323, "Check num rows in NdExperiment table after addition of large phenotyping spreadsheet upload");

my @nd_experiment_table;
my $nd_experiment_table_tail = $experiment->slice($post1_experiment_count-323, $post1_experiment_count);
while (my $rs = $nd_experiment_table_tail->next() ) {
      push @nd_experiment_table, [nd_experiment_id=> $rs->nd_experiment_id(), nd_geolocation_id=> $rs->nd_geolocation_id(), type_id=> $rs->type_id()];
}
#print STDERR Dumper \@nd_experiment_table;

$phenotype_rs = $c->bcs_schema->resultset('Phenotype::Phenotype')->search({});
$post1_phenotype_count = $phenotype_rs->count();
$post1_phenotype_diff = $post1_phenotype_count - $pre_phenotype_count;
print STDERR "Phenotype count: ".$post1_phenotype_diff."\n";
ok($post1_phenotype_diff == 323, "Check num rows in Phenotype table after addition of large phenotyping spreadsheet upload");

my @pheno_table;
my $pheno_table_tail = $phenotype_rs->slice($post1_phenotype_count-323, $post1_phenotype_count);
while (my $rs = $pheno_table_tail->next() ) {
      push @pheno_table, [phenotype_id=> $rs->phenotype_id(), observable_id=> $rs->observable_id(), attr_id=> $rs->attr_id(), value=> $rs->value(), cvalue_id=>$rs->cvalue_id(), assay_id=>$rs->assay_id()];
}
#print STDERR Dumper \@pheno_table;

$exp_prop_rs = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentprop')->search({});
$post1_exp_prop_count = $exp_prop_rs->count();
$post1_exp_prop_diff = $post1_exp_prop_count - $pre_exp_prop_count;
print STDERR "Experimentprop count: ".$post1_exp_prop_diff."\n";
ok($post1_exp_prop_diff == 646, "Check num rows in Experimentprop table after addition of large phenotyping spreadsheet upload");

my @exp_prop_table;
my $exp_prop_table_tail = $exp_prop_rs->slice($post1_exp_prop_count-646, $post1_exp_prop_count);
while (my $rs = $exp_prop_table_tail->next() ) {
      push @exp_prop_table, [nd_experimentprop_id=> $rs->nd_experimentprop_id(), nd_experiment_id=> $rs->nd_experiment_id(), type_id=> $rs->type_id(), value=> $rs->value(), rank=> $rs->rank()];
}
#print STDERR Dumper \@exp_prop_table;

$exp_proj_rs = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentProject')->search({});
$post1_exp_proj_count = $exp_proj_rs->count();
$post1_exp_proj_diff = $post1_exp_proj_count - $pre_exp_proj_count;
print STDERR "Experimentproject count: ".$post1_exp_proj_diff."\n";
ok($post1_exp_proj_diff == 323, "Check num rows in NdExperimentproject table after addition of large phenotyping spreadsheet upload");

my @exp_proj_table;
my $exp_proj_table_tail = $exp_proj_rs->slice($post1_exp_proj_count-323, $post1_exp_proj_count);
while (my $rs = $exp_proj_table_tail->next() ) {
      push @exp_proj_table, [nd_experiment_project_id=> $rs->nd_experiment_project_id(), nd_experiment_id=> $rs->nd_experiment_id(), project_id=> $rs->project_id()];
}
#print STDERR Dumper \@exp_proj_table;

$exp_stock_rs = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentStock')->search({});
$post1_exp_stock_count = $exp_stock_rs->count();
$post1_exp_stock_diff = $post1_exp_stock_count - $pre_exp_stock_count;
print STDERR "Experimentstock count: ".$post1_exp_stock_diff."\n";
ok($post1_exp_stock_diff == 323, "Check num rows in NdExperimentstock table after addition of large phenotyping spreadsheet upload");

my @exp_stock_table;
my $exp_stock_table_tail = $exp_stock_rs->slice($post1_exp_stock_count-323, $post1_exp_stock_count);
while (my $rs = $exp_stock_table_tail->next() ) {
      push @exp_stock_table, [nd_experiment_stock_id=> $rs->nd_experiment_stock_id(), nd_experiment_id=> $rs->nd_experiment_id(), stock_id=> $rs->stock_id(), type_id=> $rs->type_id()];
}
#print STDERR Dumper \@exp_stock_table;

$exp_pheno_rs = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentPhenotype')->search({});
$post1_exp_pheno_count = $exp_pheno_rs->count();
$post1_exp_pheno_diff = $post1_exp_pheno_count - $pre_exp_pheno_count;
print STDERR "Experimentphenotype count: ".$post1_exp_pheno_diff."\n";
ok($post1_exp_pheno_diff == 323, "Check num rows in NdExperimentphenotype table after addition of large phenotyping spreadsheet upload");

my @exp_pheno_table;
my $exp_pheno_table_tail = $exp_pheno_rs->slice($post1_exp_pheno_count-323, $post1_exp_pheno_count);
while (my $rs = $exp_pheno_table_tail->next() ) {
      push @exp_pheno_table, [nd_experiment_phenotype_id=> $rs->nd_experiment_phenotype_id(), nd_experiment_id=> $rs->nd_experiment_id(), phenotype_id=> $rs->phenotype_id()];
}
#print STDERR Dumper \@exp_pheno_table;

$md_rs = $c->metadata_schema->resultset('MdMetadata')->search({});
$post1_md_count = $md_rs->count();
$post1_md_diff = $post1_md_count - $pre_md_count;
print STDERR "MdMetadata count: ".$post1_md_diff."\n";
ok($post1_md_diff == 5, "Check num rows in MdMetadata table after addition of phenotyping spreadsheet upload");

my @md_table;
my $md_table_tail = $md_rs->slice($post1_md_count-5, $post1_md_count);
while (my $rs = $md_table_tail->next() ) {
      push @md_table, [metadata_id => $rs->metadata_id(), create_person_id=> $rs->create_person_id()];
}
#print STDERR Dumper \@md_table;

$md_files_rs = $c->metadata_schema->resultset('MdFiles')->search({});
$post1_md_files_count = $md_files_rs->count();
$post1_md_files_diff = $post1_md_files_count - $pre_md_files_count;
print STDERR "MdFiles count: ".$post1_md_files_diff."\n";
ok($post1_md_files_diff == 5, "Check num rows in MdFiles table after addition of large phenotyping spreadsheet upload");

my @md_files_table;
my $md_files_table_tail = $md_files_rs->slice($post1_md_files_count-5, $post1_md_files_count);
while (my $rs = $md_files_table_tail->next() ) {
      push @md_files_table, [file_id => $rs->file_id(), basename=> $rs->basename(), dirname=> $rs->dirname(), filetype=> $rs->filetype(), alt_filename=>$rs->alt_filename(), comment=>$rs->comment(), urlsource=>$rs->urlsource()];
}
#print STDERR Dumper \@md_files_table;

$exp_md_files_rs = $c->phenome_schema->resultset('NdExperimentMdFiles')->search({});
$post1_exp_md_files_count = $exp_md_files_rs->count();
$post1_exp_md_files_diff = $post1_exp_md_files_count - $pre_exp_md_files_count;
print STDERR "Experimentphenotype count: ".$post1_exp_md_files_diff."\n";
ok($post1_exp_md_files_diff == 323, "Check num rows in NdExperimentMdFIles table after addition of large phenotyping spreadsheet upload");

my @exp_md_files_table;
my $exp_md_files_table_tail = $exp_md_files_rs->slice($post1_exp_md_files_count-324, $post1_exp_md_files_count-1);
while (my $rs = $exp_md_files_table_tail->next() ) {
      push @exp_md_files_table, [nd_experiment_md_files_id => $rs->nd_experiment_md_files_id(), nd_experiment_id=> $rs->nd_experiment_id(), file_id=> $rs->file_id()];
}
#print STDERR Dumper \@exp_md_files_table;


if (!$tn->has_plant_entries) {
	$tn->create_plant_entities(2);
}

#check that parse fails for plant spreadsheet file when using plot parser
$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/trial/upload_phenotypin_spreadsheet_plants.xls";
$validate_file = $parser->validate('phenotype spreadsheet', $filename, 0, 'plots');
ok($validate_file != 1, "Check if parse validate plot fails for plant spreadsheet file");

$validate_file = $parser->validate('phenotype spreadsheet', $filename, 0, 'plants');
ok($validate_file == 1, "Check if parse validate works for plant spreadsheet file");

$parsed_file = $parser->parse('phenotype spreadsheet', $filename, 0, 'plants');
ok($parsed_file, "Check if parse parse phenotype plant spreadsheet works");

#print STDERR Dumper $parsed_file;

is_deeply($parsed_file, {
          'plots' => [
                       'test_trial210_plant_1',
                       'test_trial210_plant_2',
                       'test_trial211_plant_1',
                       'test_trial211_plant_2',
                       'test_trial212_plant_1',
                       'test_trial212_plant_2',
                       'test_trial213_plant_1',
                       'test_trial213_plant_2',
                       'test_trial214_plant_1',
                       'test_trial214_plant_2',
                       'test_trial215_plant_1',
                       'test_trial215_plant_2',
                       'test_trial21_plant_1',
                       'test_trial21_plant_2',
                       'test_trial22_plant_1',
                       'test_trial22_plant_2',
                       'test_trial23_plant_1',
                       'test_trial23_plant_2',
                       'test_trial24_plant_1',
                       'test_trial24_plant_2',
                       'test_trial25_plant_1',
                       'test_trial25_plant_2',
                       'test_trial26_plant_1',
                       'test_trial26_plant_2',
                       'test_trial27_plant_1',
                       'test_trial27_plant_2',
                       'test_trial28_plant_1',
                       'test_trial28_plant_2',
                       'test_trial29_plant_1',
                       'test_trial29_plant_2'
                     ],
          'data' => {
                      'test_trial27_plant_2' => {
                                                  'dry matter content percentage|CO:0000092' => [
                                                                                                  '23',
                                                                                                  ''
                                                                                                ],
                                                  'fresh root weight|CO:0000012' => [
                                                                                      '33',
                                                                                      ''
                                                                                    ]
                                                },
                      'test_trial29_plant_1' => {
                                                  'fresh root weight|CO:0000012' => [
                                                                                      '36',
                                                                                      ''
                                                                                    ],
                                                  'dry matter content percentage|CO:0000092' => [
                                                                                                  '26',
                                                                                                  ''
                                                                                                ]
                                                },
                      'test_trial29_plant_2' => {
                                                  'dry matter content percentage|CO:0000092' => [
                                                                                                  '27',
                                                                                                  ''
                                                                                                ],
                                                  'fresh root weight|CO:0000012' => [
                                                                                      '37',
                                                                                      ''
                                                                                    ]
                                                },
                      'test_trial212_plant_1' => {
                                                   'dry matter content percentage|CO:0000092' => [
                                                                                                   '32',
                                                                                                   ''
                                                                                                 ],
                                                   'fresh root weight|CO:0000012' => [
                                                                                       '42',
                                                                                       ''
                                                                                     ]
                                                 },
                      'test_trial25_plant_1' => {
                                                  'dry matter content percentage|CO:0000092' => [
                                                                                                  '18',
                                                                                                  ''
                                                                                                ],
                                                  'fresh root weight|CO:0000012' => [
                                                                                      '28',
                                                                                      ''
                                                                                    ]
                                                },
                      'test_trial22_plant_2' => {
                                                  'fresh root weight|CO:0000012' => [
                                                                                      '23',
                                                                                      ''
                                                                                    ],
                                                  'dry matter content percentage|CO:0000092' => [
                                                                                                  '13',
                                                                                                  ''
                                                                                                ]
                                                },
                      'test_trial213_plant_1' => {
                                                   'dry matter content percentage|CO:0000092' => [
                                                                                                   '34',
                                                                                                   ''
                                                                                                 ],
                                                   'fresh root weight|CO:0000012' => [
                                                                                       '44',
                                                                                       ''
                                                                                     ]
                                                 },
                      'test_trial211_plant_2' => {
                                                   'dry matter content percentage|CO:0000092' => [
                                                                                                   '31',
                                                                                                   ''
                                                                                                 ],
                                                   'fresh root weight|CO:0000012' => [
                                                                                       '41',
                                                                                       ''
                                                                                     ]
                                                 },
                      'test_trial27_plant_1' => {
                                                  'dry matter content percentage|CO:0000092' => [
                                                                                                  '22',
                                                                                                  ''
                                                                                                ],
                                                  'fresh root weight|CO:0000012' => [
                                                                                      '32',
                                                                                      ''
                                                                                    ]
                                                },
                      'test_trial28_plant_2' => {
                                                  'fresh root weight|CO:0000012' => [
                                                                                      '35',
                                                                                      ''
                                                                                    ],
                                                  'dry matter content percentage|CO:0000092' => [
                                                                                                  '25',
                                                                                                  ''
                                                                                                ]
                                                },
                      'test_trial25_plant_2' => {
                                                  'dry matter content percentage|CO:0000092' => [
                                                                                                  '',
                                                                                                  ''
                                                                                                ],
                                                  'fresh root weight|CO:0000012' => [
                                                                                      '29',
                                                                                      ''
                                                                                    ]
                                                },
                      'test_trial210_plant_1' => {
                                                   'dry matter content percentage|CO:0000092' => [
                                                                                                   '28',
                                                                                                   ''
                                                                                                 ],
                                                   'fresh root weight|CO:0000012' => [
                                                                                       '38',
                                                                                       ''
                                                                                     ]
                                                 },
                      'test_trial212_plant_2' => {
                                                   'dry matter content percentage|CO:0000092' => [
                                                                                                   '33',
                                                                                                   ''
                                                                                                 ],
                                                   'fresh root weight|CO:0000012' => [
                                                                                       '43',
                                                                                       ''
                                                                                     ]
                                                 },
                      'test_trial21_plant_1' => {
                                                  'dry matter content percentage|CO:0000092' => [
                                                                                                  '10',
                                                                                                  ''
                                                                                                ],
                                                  'fresh root weight|CO:0000012' => [
                                                                                      '20',
                                                                                      ''
                                                                                    ]
                                                },
                      'test_trial24_plant_1' => {
                                                  'dry matter content percentage|CO:0000092' => [
                                                                                                  '16',
                                                                                                  ''
                                                                                                ],
                                                  'fresh root weight|CO:0000012' => [
                                                                                      '26',
                                                                                      ''
                                                                                    ]
                                                },
                      'test_trial210_plant_2' => {
                                                   'dry matter content percentage|CO:0000092' => [
                                                                                                   '29',
                                                                                                   ''
                                                                                                 ],
                                                   'fresh root weight|CO:0000012' => [
                                                                                       '',
                                                                                       ''
                                                                                     ]
                                                 },
                      'test_trial23_plant_2' => {
                                                  'dry matter content percentage|CO:0000092' => [
                                                                                                  '15',
                                                                                                  ''
                                                                                                ],
                                                  'fresh root weight|CO:0000012' => [
                                                                                      '25',
                                                                                      ''
                                                                                    ]
                                                },
                      'test_trial214_plant_1' => {
                                                   'fresh root weight|CO:0000012' => [
                                                                                       '46',
                                                                                       ''
                                                                                     ],
                                                   'dry matter content percentage|CO:0000092' => [
                                                                                                   '36',
                                                                                                   ''
                                                                                                 ]
                                                 },
                      'test_trial215_plant_2' => {
                                                   'fresh root weight|CO:0000012' => [
                                                                                       '49',
                                                                                       ''
                                                                                     ],
                                                   'dry matter content percentage|CO:0000092' => [
                                                                                                   '39',
                                                                                                   ''
                                                                                                 ]
                                                 },
                      'test_trial211_plant_1' => {
                                                   'fresh root weight|CO:0000012' => [
                                                                                       '40',
                                                                                       ''
                                                                                     ],
                                                   'dry matter content percentage|CO:0000092' => [
                                                                                                   '30',
                                                                                                   ''
                                                                                                 ]
                                                 },
                      'test_trial23_plant_1' => {
                                                  'dry matter content percentage|CO:0000092' => [
                                                                                                  '14',
                                                                                                  ''
                                                                                                ],
                                                  'fresh root weight|CO:0000012' => [
                                                                                      '24',
                                                                                      ''
                                                                                    ]
                                                },
                      'test_trial28_plant_1' => {
                                                  'dry matter content percentage|CO:0000092' => [
                                                                                                  '0',
                                                                                                  ''
                                                                                                ],
                                                  'fresh root weight|CO:0000012' => [
                                                                                      '34',
                                                                                      ''
                                                                                    ]
                                                },
                      'test_trial26_plant_2' => {
                                                  'dry matter content percentage|CO:0000092' => [
                                                                                                  '21',
                                                                                                  ''
                                                                                                ],
                                                  'fresh root weight|CO:0000012' => [
                                                                                      '0',
                                                                                      ''
                                                                                    ]
                                                },
                      'test_trial213_plant_2' => {
                                                   'dry matter content percentage|CO:0000092' => [
                                                                                                   '35',
                                                                                                   ''
                                                                                                 ],
                                                   'fresh root weight|CO:0000012' => [
                                                                                       '45',
                                                                                       ''
                                                                                     ]
                                                 },
                      'test_trial22_plant_1' => {
                                                  'fresh root weight|CO:0000012' => [
                                                                                      '22',
                                                                                      ''
                                                                                    ],
                                                  'dry matter content percentage|CO:0000092' => [
                                                                                                  '12',
                                                                                                  ''
                                                                                                ]
                                                },
                      'test_trial215_plant_1' => {
                                                   'dry matter content percentage|CO:0000092' => [
                                                                                                   '38',
                                                                                                   ''
                                                                                                 ],
                                                   'fresh root weight|CO:0000012' => [
                                                                                       '48',
                                                                                       ''
                                                                                     ]
                                                 },
                      'test_trial26_plant_1' => {
                                                  'dry matter content percentage|CO:0000092' => [
                                                                                                  '20',
                                                                                                  ''
                                                                                                ],
                                                  'fresh root weight|CO:0000012' => [
                                                                                      '30',
                                                                                      ''
                                                                                    ]
                                                },
                      'test_trial214_plant_2' => {
                                                   'dry matter content percentage|CO:0000092' => [
                                                                                                   '37',
                                                                                                   ''
                                                                                                 ],
                                                   'fresh root weight|CO:0000012' => [
                                                                                       '47',
                                                                                       ''
                                                                                     ]
                                                 },
                      'test_trial24_plant_2' => {
                                                  'dry matter content percentage|CO:0000092' => [
                                                                                                  '17',
                                                                                                  ''
                                                                                                ],
                                                  'fresh root weight|CO:0000012' => [
                                                                                      '27',
                                                                                      ''
                                                                                    ]
                                                },
                      'test_trial21_plant_2' => {
                                                  'fresh root weight|CO:0000012' => [
                                                                                      '21',
                                                                                      ''
                                                                                    ],
                                                  'dry matter content percentage|CO:0000092' => [
                                                                                                  '11',
                                                                                                  ''
                                                                                                ]
                                                }
                    },
          'traits' => [
                        'dry matter content percentage|CO:0000092',
                        'fresh root weight|CO:0000012'
                      ]
        }, "check plant spreadsheet file was parsed");

$phenotype_metadata{'archived_file'} = $filename;
$phenotype_metadata{'archived_file_type'}="spreadsheet phenotype file";
$phenotype_metadata{'operator'}="janedoe";
$phenotype_metadata{'date'}="2016-02-16_05:15:21";
%parsed_data = %{$parsed_file->{'data'}};
@plots = @{$parsed_file->{'plots'}};
@traits = @{$parsed_file->{'traits'}};

$store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new();
$size = scalar(@plots) * scalar(@traits);
$stored_phenotype_error_msg = $store_phenotypes->store($c,$size,\@plots,\@traits, \%parsed_data, \%phenotype_metadata, 'plants');
ok(!$stored_phenotype_error_msg, "check that store large pheno spreadsheet works");

$tn = CXGN::Trial->new( { bcs_schema => $f->bcs_schema(),
	trial_id => 137 });

$traits_assayed  = $tn->get_traits_assayed();
@traits_assayed_sorted = sort {$a->[0] cmp $b->[0]} @$traits_assayed;
#print STDERR Dumper \@traits_assayed_sorted;
is_deeply(\@traits_assayed_sorted, [[70666, 'Fresh root weight'], [70668, 'Harvest index variable'], [70681,'Top yield'], [ 70700, 'Sprouting proportion'], [70706,'Root number counting'],[70713,'Flower'],[  70727, 'Dry yield'  ], [70741,'Dry matter content percentage'  ], [ 70773, 'Fresh shoot weight measurement in kg' ] ], 'check traits assayed after plant upload' );

@pheno_for_trait = $tn->get_phenotypes_for_trait(70666);
@pheno_for_trait_sorted = sort {$a <=> $b} @pheno_for_trait;
#print STDERR Dumper \@pheno_for_trait_sorted;
is_deeply(\@pheno_for_trait_sorted, [
          0,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          15,
          20,
          21,
          22,
          23,
          24,
          25,
          26,
          27,
          28,
          29,
          30,
          32,
          33,
          34,
          35,
          36,
          36,
          37,
          37,
          38,
          38,
          39,
          40,
          40,
          41,
          41,
          42,
          42,
          43,
          43,
          44,
          45,
          45,
          46,
          46,
          47,
          47,
          48,
          48,
          49,
          49,
          50
        ], 'check pheno traits 70666 after plant upload' );

@pheno_for_trait = $tn->get_phenotypes_for_trait(70727);
@pheno_for_trait_sorted = sort {$a <=> $b} @pheno_for_trait;
#print STDERR Dumper \@pheno_for_trait_sorted;
is_deeply(\@pheno_for_trait_sorted, [
          0,
          0,
          12,
          13,
          14,
          24,
          25,
          31,
          32,
          35,
          41,
          41,
          42,
          42,
          45
        ], "check pheno trait 70727 after plant upload.");


$experiment = $c->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search({type_id => $phenotyping_experiment_cvterm_id}, {order_by => {-asc => 'nd_experiment_id'}});
$post1_experiment_count = $experiment->count();
$post1_experiment_diff = $post1_experiment_count - $pre_experiment_count;
print STDERR "Experiment count: ".$post1_experiment_diff."\n";
ok($post1_experiment_diff == 381, "Check num rows in NdExperiment table after addition of large phenotyping spreadsheet upload");

my @nd_experiment_table;
my $nd_experiment_table_tail = $experiment->slice($post1_experiment_count-323, $post1_experiment_count);
while (my $rs = $nd_experiment_table_tail->next() ) {
  push @nd_experiment_table, [nd_experiment_id=> $rs->nd_experiment_id(), nd_geolocation_id=> $rs->nd_geolocation_id(), type_id=> $rs->type_id()];
}
#print STDERR Dumper \@nd_experiment_table;

$phenotype_rs = $c->bcs_schema->resultset('Phenotype::Phenotype')->search({});
$post1_phenotype_count = $phenotype_rs->count();
$post1_phenotype_diff = $post1_phenotype_count - $pre_phenotype_count;
print STDERR "Phenotype count: ".$post1_phenotype_diff."\n";
ok($post1_phenotype_diff == 381, "Check num rows in Phenotype table after addition of large phenotyping spreadsheet upload");

my @pheno_table;
my $pheno_table_tail = $phenotype_rs->slice($post1_phenotype_count-323, $post1_phenotype_count);
while (my $rs = $pheno_table_tail->next() ) {
  push @pheno_table, [phenotype_id=> $rs->phenotype_id(), observable_id=> $rs->observable_id(), attr_id=> $rs->attr_id(), value=> $rs->value(), cvalue_id=>$rs->cvalue_id(), assay_id=>$rs->assay_id()];
}
#print STDERR Dumper \@pheno_table;

$exp_prop_rs = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentprop')->search({});
$post1_exp_prop_count = $exp_prop_rs->count();
$post1_exp_prop_diff = $post1_exp_prop_count - $pre_exp_prop_count;
print STDERR "Experimentprop count: ".$post1_exp_prop_diff."\n";
ok($post1_exp_prop_diff == 762, "Check num rows in Experimentprop table after addition of large phenotyping spreadsheet upload");

my @exp_prop_table;
my $exp_prop_table_tail = $exp_prop_rs->slice($post1_exp_prop_count-646, $post1_exp_prop_count);
while (my $rs = $exp_prop_table_tail->next() ) {
  push @exp_prop_table, [nd_experimentprop_id=> $rs->nd_experimentprop_id(), nd_experiment_id=> $rs->nd_experiment_id(), type_id=> $rs->type_id(), value=> $rs->value(), rank=> $rs->rank()];
}
#print STDERR Dumper \@exp_prop_table;

$exp_proj_rs = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentProject')->search({});
$post1_exp_proj_count = $exp_proj_rs->count();
$post1_exp_proj_diff = $post1_exp_proj_count - $pre_exp_proj_count;
print STDERR "Experimentproject count: ".$post1_exp_proj_diff."\n";
ok($post1_exp_proj_diff == 381, "Check num rows in NdExperimentproject table after addition of large phenotyping spreadsheet upload");

my @exp_proj_table;
my $exp_proj_table_tail = $exp_proj_rs->slice($post1_exp_proj_count-323, $post1_exp_proj_count);
while (my $rs = $exp_proj_table_tail->next() ) {
  push @exp_proj_table, [nd_experiment_project_id=> $rs->nd_experiment_project_id(), nd_experiment_id=> $rs->nd_experiment_id(), project_id=> $rs->project_id()];
}
#print STDERR Dumper \@exp_proj_table;

$exp_stock_rs = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentStock')->search({});
$post1_exp_stock_count = $exp_stock_rs->count();
$post1_exp_stock_diff = $post1_exp_stock_count - $pre_exp_stock_count;
print STDERR "Experimentstock count: ".$post1_exp_stock_diff."\n";
ok($post1_exp_stock_diff == 411, "Check num rows in NdExperimentstock table after addition of large phenotyping spreadsheet upload");

my @exp_stock_table;
my $exp_stock_table_tail = $exp_stock_rs->slice($post1_exp_stock_count-323, $post1_exp_stock_count);
while (my $rs = $exp_stock_table_tail->next() ) {
  push @exp_stock_table, [nd_experiment_stock_id=> $rs->nd_experiment_stock_id(), nd_experiment_id=> $rs->nd_experiment_id(), stock_id=> $rs->stock_id(), type_id=> $rs->type_id()];
}
#print STDERR Dumper \@exp_stock_table;

$exp_pheno_rs = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentPhenotype')->search({});
$post1_exp_pheno_count = $exp_pheno_rs->count();
$post1_exp_pheno_diff = $post1_exp_pheno_count - $pre_exp_pheno_count;
print STDERR "Experimentphenotype count: ".$post1_exp_pheno_diff."\n";
ok($post1_exp_pheno_diff == 381, "Check num rows in NdExperimentphenotype table after addition of large phenotyping spreadsheet upload");

my @exp_pheno_table;
my $exp_pheno_table_tail = $exp_pheno_rs->slice($post1_exp_pheno_count-323, $post1_exp_pheno_count);
while (my $rs = $exp_pheno_table_tail->next() ) {
  push @exp_pheno_table, [nd_experiment_phenotype_id=> $rs->nd_experiment_phenotype_id(), nd_experiment_id=> $rs->nd_experiment_id(), phenotype_id=> $rs->phenotype_id()];
}
#print STDERR Dumper \@exp_pheno_table;

$md_rs = $c->metadata_schema->resultset('MdMetadata')->search({});
$post1_md_count = $md_rs->count();
$post1_md_diff = $post1_md_count - $pre_md_count;
print STDERR "MdMetadata count: ".$post1_md_diff."\n";
ok($post1_md_diff == 6, "Check num rows in MdMetadata table after addition of phenotyping spreadsheet upload");

my @md_table;
my $md_table_tail = $md_rs->slice($post1_md_count-5, $post1_md_count);
while (my $rs = $md_table_tail->next() ) {
  push @md_table, [metadata_id => $rs->metadata_id(), create_person_id=> $rs->create_person_id()];
}
#print STDERR Dumper \@md_table;

$md_files_rs = $c->metadata_schema->resultset('MdFiles')->search({});
$post1_md_files_count = $md_files_rs->count();
$post1_md_files_diff = $post1_md_files_count - $pre_md_files_count;
print STDERR "MdFiles count: ".$post1_md_files_diff."\n";
ok($post1_md_files_diff == 6, "Check num rows in MdFiles table after addition of large phenotyping spreadsheet upload");

my @md_files_table;
my $md_files_table_tail = $md_files_rs->slice($post1_md_files_count-5, $post1_md_files_count);
while (my $rs = $md_files_table_tail->next() ) {
  push @md_files_table, [file_id => $rs->file_id(), basename=> $rs->basename(), dirname=> $rs->dirname(), filetype=> $rs->filetype(), alt_filename=>$rs->alt_filename(), comment=>$rs->comment(), urlsource=>$rs->urlsource()];
}
#print STDERR Dumper \@md_files_table;

$exp_md_files_rs = $c->phenome_schema->resultset('NdExperimentMdFiles')->search({});
$post1_exp_md_files_count = $exp_md_files_rs->count();
$post1_exp_md_files_diff = $post1_exp_md_files_count - $pre_exp_md_files_count;
print STDERR "Experimentphenotype count: ".$post1_exp_md_files_diff."\n";
ok($post1_exp_md_files_diff == 381, "Check num rows in NdExperimentMdFIles table after addition of large phenotyping spreadsheet upload");

my @exp_md_files_table;
my $exp_md_files_table_tail = $exp_md_files_rs->slice($post1_exp_md_files_count-324, $post1_exp_md_files_count-1);
while (my $rs = $exp_md_files_table_tail->next() ) {
  push @exp_md_files_table, [nd_experiment_md_files_id => $rs->nd_experiment_md_files_id(), nd_experiment_id=> $rs->nd_experiment_id(), file_id=> $rs->file_id()];
}
#print STDERR Dumper \@exp_md_files_table;



$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/fieldbook/fieldbook_phenotype_plants_file.csv";

$validate_file = $parser->validate('field book', $filename, 1);
ok($validate_file == 1, "Check if parse validate works for plant fieldbook file");

$parsed_file = $parser->parse('field book', $filename, 1);
ok($parsed_file, "Check if parse parse phenotype plant fieldbook works");

#print STDERR Dumper $parsed_file;

is_deeply($parsed_file, {
          'data' => {
                      'test_trial23_plant_1' => {
                                                  'dry matter content|CO:0000092' => [
                                                                                       '41',
                                                                                       '2016-01-07 12:08:27-0500'
                                                                                     ]
                                                },
                      'test_trial22_plant_2' => {
                                                  'dry yield|CO:0000014' => [
                                                                              '0',
                                                                              '2016-01-07 12:08:26-0500'
                                                                            ],
                                                  'dry matter content|CO:0000092' => [
                                                                                       '45',
                                                                                       '2016-01-07 12:08:26-0500'
                                                                                     ]
                                                },
                      'test_trial21_plant_2' => {
                                                  'dry matter content|CO:0000092' => [
                                                                                       '42',
                                                                                       '2016-01-07 12:08:24-0500'
                                                                                     ],
                                                  'dry yield|CO:0000014' => [
                                                                              '0',
                                                                              '2016-01-07 12:08:24-0500'
                                                                            ]
                                                },
                      'test_trial21_plant_1' => {
                                                  'dry yield|CO:0000014' => [
                                                                              '42',
                                                                              '2016-01-07 12:08:24-0500'
                                                                            ],
                                                  'dry matter content|CO:0000092' => [
                                                                                       '42',
                                                                                       '2016-01-07 12:08:24-0500'
                                                                                     ]
                                                },
                      'test_trial23_plant_2' => {
                                                  'dry matter content|CO:0000092' => [
                                                                                       '41',
                                                                                       '2016-01-07 12:08:27-0500'
                                                                                     ]
                                                },
                      'test_trial22_plant_1' => {
                                                  'dry yield|CO:0000014' => [
                                                                              '45',
                                                                              '2016-01-07 12:08:26-0500'
                                                                            ],
                                                  'dry matter content|CO:0000092' => [
                                                                                       '45',
                                                                                       '2016-01-07 12:08:26-0500'
                                                                                     ]
                                                }
                    },
          'traits' => [
                        'dry matter content|CO:0000092',
                        'dry yield|CO:0000014'
                      ],
          'plots' => [
                       'test_trial21_plant_1',
                       'test_trial21_plant_2',
                       'test_trial22_plant_1',
                       'test_trial22_plant_2',
                       'test_trial23_plant_1',
                       'test_trial23_plant_2'
                     ]
        }, "check parse fieldbook plant file");

$phenotype_metadata{'archived_file'} = $filename;
$phenotype_metadata{'archived_file_type'}="tablet phenotype file";
$phenotype_metadata{'operator'}="janedoe";
$phenotype_metadata{'date'}="2016-02-16_05:55:17";
%parsed_data = %{$parsed_file->{'data'}};
@plots = @{$parsed_file->{'plots'}};
@traits = @{$parsed_file->{'traits'}};

$store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new();
$size = scalar(@plots) * scalar(@traits);
$stored_phenotype_error_msg = $store_phenotypes->store($c,$size,\@plots,\@traits, \%parsed_data, \%phenotype_metadata, 'plants');
ok(!$stored_phenotype_error_msg, "check that store fieldbook plants works");

$tn = CXGN::Trial->new( { bcs_schema => $f->bcs_schema(),
	trial_id => 137 });

$traits_assayed  = $tn->get_traits_assayed();
@traits_assayed_sorted = sort {$a->[0] cmp $b->[0]} @$traits_assayed;
#print STDERR Dumper \@traits_assayed_sorted;
is_deeply(\@traits_assayed_sorted, [[70666, 'Fresh root weight'], [70668, 'Harvest index variable'], [70681,'Top yield'], [ 70700, 'Sprouting proportion'], [70706,'Root number counting'],[70713,'Flower'],[  70727, 'Dry yield'  ], [70741,'Dry matter content percentage'  ], [ 70773, 'Fresh shoot weight measurement in kg' ] ], 'check traits assayed after plant upload' );

$experiment = $c->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search({type_id => $phenotyping_experiment_cvterm_id}, {order_by => {-asc => 'nd_experiment_id'}});
$post1_experiment_count = $experiment->count();
$post1_experiment_diff = $post1_experiment_count - $pre_experiment_count;
print STDERR "Experiment count: ".$post1_experiment_diff."\n";
ok($post1_experiment_diff == 391, "Check num rows in NdExperiment table after addition of large phenotyping spreadsheet upload");

my @nd_experiment_table;
my $nd_experiment_table_tail = $experiment->slice($post1_experiment_count-323, $post1_experiment_count);
while (my $rs = $nd_experiment_table_tail->next() ) {
  push @nd_experiment_table, [nd_experiment_id=> $rs->nd_experiment_id(), nd_geolocation_id=> $rs->nd_geolocation_id(), type_id=> $rs->type_id()];
}
#print STDERR Dumper \@nd_experiment_table;

$phenotype_rs = $c->bcs_schema->resultset('Phenotype::Phenotype')->search({});
$post1_phenotype_count = $phenotype_rs->count();
$post1_phenotype_diff = $post1_phenotype_count - $pre_phenotype_count;
print STDERR "Phenotype count: ".$post1_phenotype_diff."\n";
ok($post1_phenotype_diff == 391, "Check num rows in Phenotype table after addition of large phenotyping spreadsheet upload");

my @pheno_table;
my $pheno_table_tail = $phenotype_rs->slice($post1_phenotype_count-323, $post1_phenotype_count);
while (my $rs = $pheno_table_tail->next() ) {
  push @pheno_table, [phenotype_id=> $rs->phenotype_id(), observable_id=> $rs->observable_id(), attr_id=> $rs->attr_id(), value=> $rs->value(), cvalue_id=>$rs->cvalue_id(), assay_id=>$rs->assay_id()];
}
#print STDERR Dumper \@pheno_table;

$exp_prop_rs = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentprop')->search({});
$post1_exp_prop_count = $exp_prop_rs->count();
$post1_exp_prop_diff = $post1_exp_prop_count - $pre_exp_prop_count;
print STDERR "Experimentprop count: ".$post1_exp_prop_diff."\n";
ok($post1_exp_prop_diff == 782, "Check num rows in Experimentprop table after addition of large phenotyping spreadsheet upload");

my @exp_prop_table;
my $exp_prop_table_tail = $exp_prop_rs->slice($post1_exp_prop_count-646, $post1_exp_prop_count);
while (my $rs = $exp_prop_table_tail->next() ) {
  push @exp_prop_table, [nd_experimentprop_id=> $rs->nd_experimentprop_id(), nd_experiment_id=> $rs->nd_experiment_id(), type_id=> $rs->type_id(), value=> $rs->value(), rank=> $rs->rank()];
}
#print STDERR Dumper \@exp_prop_table;

$exp_proj_rs = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentProject')->search({});
$post1_exp_proj_count = $exp_proj_rs->count();
$post1_exp_proj_diff = $post1_exp_proj_count - $pre_exp_proj_count;
print STDERR "Experimentproject count: ".$post1_exp_proj_diff."\n";
ok($post1_exp_proj_diff == 391, "Check num rows in NdExperimentproject table after addition of large phenotyping spreadsheet upload");

my @exp_proj_table;
my $exp_proj_table_tail = $exp_proj_rs->slice($post1_exp_proj_count-323, $post1_exp_proj_count);
while (my $rs = $exp_proj_table_tail->next() ) {
  push @exp_proj_table, [nd_experiment_project_id=> $rs->nd_experiment_project_id(), nd_experiment_id=> $rs->nd_experiment_id(), project_id=> $rs->project_id()];
}
#print STDERR Dumper \@exp_proj_table;

$exp_stock_rs = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentStock')->search({});
$post1_exp_stock_count = $exp_stock_rs->count();
$post1_exp_stock_diff = $post1_exp_stock_count - $pre_exp_stock_count;
print STDERR "Experimentstock count: ".$post1_exp_stock_diff."\n";
ok($post1_exp_stock_diff == 421, "Check num rows in NdExperimentstock table after addition of large phenotyping spreadsheet upload");

my @exp_stock_table;
my $exp_stock_table_tail = $exp_stock_rs->slice($post1_exp_stock_count-323, $post1_exp_stock_count);
while (my $rs = $exp_stock_table_tail->next() ) {
  push @exp_stock_table, [nd_experiment_stock_id=> $rs->nd_experiment_stock_id(), nd_experiment_id=> $rs->nd_experiment_id(), stock_id=> $rs->stock_id(), type_id=> $rs->type_id()];
}
#print STDERR Dumper \@exp_stock_table;

$exp_pheno_rs = $c->bcs_schema->resultset('NaturalDiversity::NdExperimentPhenotype')->search({});
$post1_exp_pheno_count = $exp_pheno_rs->count();
$post1_exp_pheno_diff = $post1_exp_pheno_count - $pre_exp_pheno_count;
print STDERR "Experimentphenotype count: ".$post1_exp_pheno_diff."\n";
ok($post1_exp_pheno_diff == 391, "Check num rows in NdExperimentphenotype table after addition of large phenotyping spreadsheet upload");

my @exp_pheno_table;
my $exp_pheno_table_tail = $exp_pheno_rs->slice($post1_exp_pheno_count-323, $post1_exp_pheno_count);
while (my $rs = $exp_pheno_table_tail->next() ) {
  push @exp_pheno_table, [nd_experiment_phenotype_id=> $rs->nd_experiment_phenotype_id(), nd_experiment_id=> $rs->nd_experiment_id(), phenotype_id=> $rs->phenotype_id()];
}
#print STDERR Dumper \@exp_pheno_table;

$md_rs = $c->metadata_schema->resultset('MdMetadata')->search({});
$post1_md_count = $md_rs->count();
$post1_md_diff = $post1_md_count - $pre_md_count;
print STDERR "MdMetadata count: ".$post1_md_diff."\n";
ok($post1_md_diff == 7, "Check num rows in MdMetadata table after addition of phenotyping spreadsheet upload");

my @md_table;
my $md_table_tail = $md_rs->slice($post1_md_count-5, $post1_md_count);
while (my $rs = $md_table_tail->next() ) {
  push @md_table, [metadata_id => $rs->metadata_id(), create_person_id=> $rs->create_person_id()];
}
#print STDERR Dumper \@md_table;

$md_files_rs = $c->metadata_schema->resultset('MdFiles')->search({});
$post1_md_files_count = $md_files_rs->count();
$post1_md_files_diff = $post1_md_files_count - $pre_md_files_count;
print STDERR "MdFiles count: ".$post1_md_files_diff."\n";
ok($post1_md_files_diff == 7, "Check num rows in MdFiles table after addition of large phenotyping spreadsheet upload");

my @md_files_table;
my $md_files_table_tail = $md_files_rs->slice($post1_md_files_count-5, $post1_md_files_count);
while (my $rs = $md_files_table_tail->next() ) {
  push @md_files_table, [file_id => $rs->file_id(), basename=> $rs->basename(), dirname=> $rs->dirname(), filetype=> $rs->filetype(), alt_filename=>$rs->alt_filename(), comment=>$rs->comment(), urlsource=>$rs->urlsource()];
}
#print STDERR Dumper \@md_files_table;

$exp_md_files_rs = $c->phenome_schema->resultset('NdExperimentMdFiles')->search({});
$post1_exp_md_files_count = $exp_md_files_rs->count();
$post1_exp_md_files_diff = $post1_exp_md_files_count - $pre_exp_md_files_count;
print STDERR "Experimentphenotype count: ".$post1_exp_md_files_diff."\n";
ok($post1_exp_md_files_diff == 391, "Check num rows in NdExperimentMdFIles table after addition of large phenotyping spreadsheet upload");

my @exp_md_files_table;
my $exp_md_files_table_tail = $exp_md_files_rs->slice($post1_exp_md_files_count-324, $post1_exp_md_files_count-1);
while (my $rs = $exp_md_files_table_tail->next() ) {
  push @exp_md_files_table, [nd_experiment_md_files_id => $rs->nd_experiment_md_files_id(), nd_experiment_id=> $rs->nd_experiment_id(), file_id=> $rs->file_id()];
}
#print STDERR Dumper \@exp_md_files_table;


done_testing();

