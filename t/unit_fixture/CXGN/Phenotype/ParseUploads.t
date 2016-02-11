
use strict;
use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use SimulateC;
use CXGN::UploadFile;
use CXGN::Phenotypes::ParseUpload;

my $f = SGN::Test::Fixture->new();

########################################
#Tests for phenotype spreadsheet parsing

#check that parse fails for fieldbook file when using phenotype spreadsheet parser
my $parser = CXGN::Phenotypes::ParseUpload->new();
my $filename = "t/data/fieldbook/fieldbook_phenotype_file.csv";
my $validate_file = $parser->validate('phenotype spreadsheet', $filename);
ok(!$validate_file, "Check if parse validate phenotype spreadsheet fails for fieldbook");

#check that parse fails for datacollector file when using phenotype spreadsheet parser
$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/trial/data_collector_upload.xls";
$validate_file = $parser->validate('phenotype spreadsheet', $filename);
ok(!$validate_file, "Check if parse validate phenotype spreadsheet fails for datacollector");

#Now parse phenotyping spreadsheet file using correct parser
$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/trial/upload_phenotypin_spreadsheet.xls";
$validate_file = $parser->validate('phenotype spreadsheet', $filename);
ok($validate_file == 1, "Check if parse validate works for phenotype file");

my $parsed_file = $parser->parse('phenotype spreadsheet', $filename);
ok($parsed_file, "Check if parse parse phenotype spreadsheet works");

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
                           'test_trial29' => {
                                               'fresh root weight|CO:0000012' => '15',
                                               'dry matter content|CO:0000092' => '35',
                                               'fresh shoot weight|CO:0000016' => '28',
                                               'harvest index|CO:0000015' => '8.8'
                                             },
                           'test_trial22' => {
                                               'fresh root weight|CO:0000012' => '15',
                                               'dry matter content|CO:0000092' => '30',
                                               'fresh shoot weight|CO:0000016' => '21',
                                               'harvest index|CO:0000015' => '1.8'
                                             },
                           'test_trial214' => {
                                                'fresh root weight|CO:0000012' => '15',
                                                'dry matter content|CO:0000092' => '30',
                                                'fresh shoot weight|CO:0000016' => '33',
                                                'harvest index|CO:0000015' => '13.8'
                                              },
                           'test_trial211' => {
                                                'fresh root weight|CO:0000012' => '15',
                                                'dry matter content|CO:0000092' => '38',
                                                'fresh shoot weight|CO:0000016' => '30',
                                                'harvest index|CO:0000015' => '10.8'
                                              },
                           'test_trial21' => {
                                               'fresh root weight|CO:0000012' => '15',
                                               'dry matter content|CO:0000092' => '35',
                                               'fresh shoot weight|CO:0000016' => '20',
                                               'harvest index|CO:0000015' => '0.8'
                                             },
                           'test_trial215' => {
                                                'fresh root weight|CO:0000012' => '15',
                                                'dry matter content|CO:0000092' => '38',
                                                'fresh shoot weight|CO:0000016' => '34',
                                                'harvest index|CO:0000015' => '14.8'
                                              },
                           'test_trial210' => {
                                                'fresh root weight|CO:0000012' => '15',
                                                'dry matter content|CO:0000092' => '30',
                                                'fresh shoot weight|CO:0000016' => '29',
                                                'harvest index|CO:0000015' => '9.8'
                                              },
                           'test_trial213' => {
                                                'fresh root weight|CO:0000012' => '15',
                                                'dry matter content|CO:0000092' => '35',
                                                'fresh shoot weight|CO:0000016' => '32',
                                                'harvest index|CO:0000015' => '12.8'
                                              },
                           'test_trial27' => {
                                               'fresh root weight|CO:0000012' => '15',
                                               'dry matter content|CO:0000092' => '38',
                                               'fresh shoot weight|CO:0000016' => '26',
                                               'harvest index|CO:0000015' => '6.8'
                                             },
                           'test_trial28' => {
                                               'fresh root weight|CO:0000012' => '15',
                                               'dry matter content|CO:0000092' => '39',
                                               'fresh shoot weight|CO:0000016' => '27',
                                               'harvest index|CO:0000015' => '7.8'
                                             },
                           'test_trial23' => {
                                               'fresh root weight|CO:0000012' => '15',
                                               'dry matter content|CO:0000092' => '38',
                                               'fresh shoot weight|CO:0000016' => '22',
                                               'harvest index|CO:0000015' => '2.8'
                                             },
                           'test_trial25' => {
                                               'fresh root weight|CO:0000012' => '15',
                                               'dry matter content|CO:0000092' => '35',
                                               'fresh shoot weight|CO:0000016' => '24',
                                               'harvest index|CO:0000015' => '4.8'
                                             },
                           'test_trial26' => {
                                               'fresh root weight|CO:0000012' => '15',
                                               'dry matter content|CO:0000092' => '30',
                                               'fresh shoot weight|CO:0000016' => '25',
                                               'harvest index|CO:0000015' => '5.8'
                                             },
                           'test_trial24' => {
                                               'fresh root weight|CO:0000012' => '15',
                                               'dry matter content|CO:0000092' => '39',
                                               'fresh shoot weight|CO:0000016' => '23',
                                               'harvest index|CO:0000015' => '3.8'
                                             },
                           'test_trial212' => {
                                                'fresh root weight|CO:0000012' => '15',
                                                'dry matter content|CO:0000092' => '39',
                                                'fresh shoot weight|CO:0000016' => '31',
                                                'harvest index|CO:0000015' => '11.8'
                                              }
                         },
               'traits' => [
                             'dry matter content|CO:0000092',
                             'fresh root weight|CO:0000012',
                             'fresh shoot weight|CO:0000016',
                             'harvest index|CO:0000015'
                           ]
             }, "Check parse phenotyping spreadsheet" );



#####################################
#Tests for fieldbook file parsing

#check that parse fails for spreadsheet file when using fieldbook parser
$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/trial/upload_phenotypin_spreadsheet.xls";
$validate_file = $parser->validate('field book', $filename);
ok(!$validate_file, "Check if parse validate fieldbook fails for spreadsheet file");

#check that parse fails for datacollector file when using fieldbook parser
$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/trial/data_collector_upload.xls";
$validate_file = $parser->validate('field book', $filename);
ok(!$validate_file, "Check if parse validate fieldbook fails for datacollector");

#Now parse phenotyping spreadsheet file using correct parser
$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/fieldbook/fieldbook_phenotype_file.csv";
$validate_file = $parser->validate('field book', $filename);
ok($validate_file == 1, "Check if parse validate works for fieldbook");

$parsed_file = $parser->parse('field book', $filename);
ok($parsed_file, "Check if parse parse fieldbook works");

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
                           'test_trial29' => {
                                               'dry matter content|CO:0000092' => '24',
                                               'dry yield|CO:0000022' => '24'
                                             },
                           'test_trial22' => {
                                               'dry matter content|CO:0000092' => '45',
                                               'dry yield|CO:0000015' => '45'
                                             },
                           'test_trial214' => {
                                                'dry yield|CO:0000027' => '32',
                                                'dry matter content|CO:0000092' => '32'
                                              },
                           'test_trial211' => {
                                                'dry yield|CO:0000024' => '13',
                                                'dry matter content|CO:0000092' => '13'
                                              },
                           'test_trial21' => {
                                               'dry matter content|CO:0000092' => '42',
                                               'dry yield|CO:0000014' => '42'
                                             },
                           'test_trial215' => {
                                                'dry matter content|CO:0000092' => '31',
                                                'dry yield|CO:0000028' => '31'
                                              },
                           'test_trial210' => {
                                                'dry matter content|CO:0000092' => '12',
                                                'dry yield|CO:0000023' => '12'
                                              },
                           'test_trial213' => {
                                                'dry matter content|CO:0000092' => '35',
                                                'dry yield|CO:0000026' => '35'
                                              },
                           'test_trial27' => {
                                               'dry matter content|CO:0000092' => '52',
                                               'dry yield|CO:0000020' => '52'
                                             },
                           'test_trial28' => {
                                               'dry matter content|CO:0000092' => '41',
                                               'dry yield|CO:0000021' => '41'
                                             },
                           'test_trial26' => {
                                               'dry matter content|CO:0000092' => '35',
                                               'dry yield|CO:0000019' => '35'
                                             },
                           'test_trial25' => {
                                               'dry matter content|CO:0000092' => '25',
                                               'dry yield|CO:0000018' => '25'
                                             },
                           'test_trial23' => {
                                               'dry matter content|CO:0000092' => '41',
                                               'dry yield|CO:0000016' => '41'
                                             },
                           'test_trial24' => {
                                               'dry matter content|CO:0000092' => '14',
                                               'dry yield|CO:0000017' => '14'
                                             },
                           'test_trial212' => {
                                                'dry matter content|CO:0000092' => '42',
                                                'dry yield|CO:0000025' => '42'
                                              }
                         },
               'traits' => [
                             'dry matter content|CO:0000092',
                             'dry yield|CO:0000014',
                             'dry yield|CO:0000015',
                             'dry yield|CO:0000016',
                             'dry yield|CO:0000017',
                             'dry yield|CO:0000018',
                             'dry yield|CO:0000019',
                             'dry yield|CO:0000020',
                             'dry yield|CO:0000021',
                             'dry yield|CO:0000022',
                             'dry yield|CO:0000023',
                             'dry yield|CO:0000024',
                             'dry yield|CO:0000025',
                             'dry yield|CO:0000026',
                             'dry yield|CO:0000027',
                             'dry yield|CO:0000028'
                           ]
             }, "Check parse fieldbook");



#####################################
#Tests for datacollector file parsing

#check that parse fails for spreadsheet file when using datacollector parser
$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/trial/upload_phenotypin_spreadsheet.xls";
$validate_file = $parser->validate('datacollector spreadsheet', $filename);
ok(!$validate_file, "Check if parse validate datacollector fails for spreadsheet file");

#check that parse fails for fieldbook file when using datacollector parser
$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/fieldbook/fieldbook_phenotype_file.csv";
$validate_file = $parser->validate('datacollector spreadsheet', $filename);
ok(!$validate_file, "Check if parse validate datacollector fails for fieldbook");

#Now parse datacollector file using correct parser
$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/trial/data_collector_upload.xls";
$validate_file = $parser->validate('datacollector spreadsheet', $filename);
ok($validate_file == 1, "Check if parse validate worksfor datacollector");

$parsed_file = $parser->parse('datacollector spreadsheet', $filename);
ok($parsed_file, "Check if parse parse datacollector works");

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
                           'test_trial29' => {
                                               'fresh root weight|CO:0000012' => '44',
                                               'dry matter content|CO:0000092' => '43',
                                               'fresh shoot weight|CO:0000016' => '18',
                                               'harvest index|CO:0000015' => '0.8'
                                             },
                           'test_trial22' => {
                                               'fresh root weight|CO:0000012' => '37',
                                               'dry matter content|CO:0000092' => '36',
                                               'fresh shoot weight|CO:0000016' => '11',
                                               'harvest index|CO:0000015' => '0.8'
                                             },
                           'test_trial214' => {
                                                'fresh root weight|CO:0000012' => '49',
                                                'dry matter content|CO:0000092' => '48',
                                                'fresh shoot weight|CO:0000016' => '23',
                                                'harvest index|CO:0000015' => '0.8'
                                              },
                           'test_trial211' => {
                                                'fresh root weight|CO:0000012' => '46',
                                                'dry matter content|CO:0000092' => '45',
                                                'fresh shoot weight|CO:0000016' => '20',
                                                'harvest index|CO:0000015' => '0.8'
                                              },
                           'test_trial21' => {
                                               'fresh root weight|CO:0000012' => '36',
                                               'dry matter content|CO:0000092' => '35',
                                               'fresh shoot weight|CO:0000016' => '10',
                                               'harvest index|CO:0000015' => '0.8'
                                             },
                           'test_trial215' => {
                                                'fresh root weight|CO:0000012' => '50',
                                                'dry matter content|CO:0000092' => '49',
                                                'fresh shoot weight|CO:0000016' => '24',
                                                'harvest index|CO:0000015' => '0.8'
                                              },
                           'test_trial210' => {
                                                'fresh root weight|CO:0000012' => '45',
                                                'dry matter content|CO:0000092' => '44',
                                                'fresh shoot weight|CO:0000016' => '19',
                                                'harvest index|CO:0000015' => '0.8'
                                              },
                           'test_trial213' => {
                                                'fresh root weight|CO:0000012' => '48',
                                                'dry matter content|CO:0000092' => '47',
                                                'fresh shoot weight|CO:0000016' => '22',
                                                'harvest index|CO:0000015' => '0.8'
                                              },
                           'test_trial27' => {
                                               'fresh root weight|CO:0000012' => '42',
                                               'dry matter content|CO:0000092' => '41',
                                               'fresh shoot weight|CO:0000016' => '16',
                                               'harvest index|CO:0000015' => '0.8'
                                             },
                           'test_trial28' => {
                                               'fresh root weight|CO:0000012' => '43',
                                               'dry matter content|CO:0000092' => '42',
                                               'fresh shoot weight|CO:0000016' => '17',
                                               'harvest index|CO:0000015' => '0.8'
                                             },
                           'test_trial23' => {
                                               'fresh root weight|CO:0000012' => '38',
                                               'dry matter content|CO:0000092' => '37',
                                               'fresh shoot weight|CO:0000016' => '12',
                                               'harvest index|CO:0000015' => '0.8'
                                             },
                           'test_trial25' => {
                                               'fresh root weight|CO:0000012' => '40',
                                               'dry matter content|CO:0000092' => '39',
                                               'fresh shoot weight|CO:0000016' => '14',
                                               'harvest index|CO:0000015' => '0.8'
                                             },
                           'test_trial26' => {
                                               'fresh root weight|CO:0000012' => '41',
                                               'dry matter content|CO:0000092' => '40',
                                               'fresh shoot weight|CO:0000016' => '15',
                                               'harvest index|CO:0000015' => '0.8'
                                             },
                           'test_trial24' => {
                                               'fresh root weight|CO:0000012' => '39',
                                               'dry matter content|CO:0000092' => '38',
                                               'fresh shoot weight|CO:0000016' => '13',
                                               'harvest index|CO:0000015' => '0.8'
                                             },
                           'test_trial212' => {
                                                'fresh root weight|CO:0000012' => '47',
                                                'dry matter content|CO:0000092' => '46',
                                                'fresh shoot weight|CO:0000016' => '21',
                                                'harvest index|CO:0000015' => '0.8'
                                              }
                         },
               'traits' => [
                             'dry matter content|CO:0000092',
                             'fresh root weight|CO:0000012',
                             'fresh shoot weight|CO:0000016',
                             'harvest index|CO:0000015'
                           ]
             }, "Check datacollector parse");


done_testing();

