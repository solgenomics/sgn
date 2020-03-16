
# Tests all functions in SGN::Controller::AJAX::TrialMetadata. These are the functions called from Accessions.js when adding new accessions.

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;

#Needed to update IO::Socket::SSL
use Data::Dumper;
use JSON;
use URI::Encode qw(uri_encode uri_decode);
use CXGN::Chado::Stock;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $mech = Test::WWW::Mechanize->new;
my $response;
my $json = JSON->new->allow_nonref;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');

my $trial_id = $schema->resultset('Project::Project')->find({name=>'Kasese solgs trial'})->project_id();

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/phenotypes?display=plots');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'data' => [['<a href="/cvterm/70741/view">dry matter content percentage|CO_334:0000092</a>','25.01','16.30','39.90','5.06','20.24%',464,'32.95%','<a href="#raw_data_histogram_well" onclick="trait_summary_hist_change(70741)"><span class="glyphicon glyphicon-stats"></span></a>'],['<a href="/cvterm/70666/view">fresh root weight|CO_334:0000012</a>','5.91','0.04','38.76','5.37','90.80%',469,'32.23%','<a href="#raw_data_histogram_well" onclick="trait_summary_hist_change(70666)"><span class="glyphicon glyphicon-stats"></span></a>'],['<a href="/cvterm/70773/view">fresh shoot weight measurement in kg|CO_334:0000016</a>','13.23','0.50','83.00','10.70','80.88%',494,'28.61%','<a href="#raw_data_histogram_well" onclick="trait_summary_hist_change(70773)"><span class="glyphicon glyphicon-stats"></span></a>']]});

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/phenotypes?display=plots_accession');
$response = decode_json $mech->content;
my @response = @{$response->{data}};
my @last_n = @response[-4..-1];
print STDERR Dumper \@last_n;
is_deeply(\@last_n, [['<a href="/stock/38881/view">UG120004</a>','<a href="/cvterm/70773/view">fresh shoot weight measurement in kg|CO_334:0000016</a>','5.25','2.51','8.00','3.88','73.87%',2,'0%','<a href="#raw_data_histogram_well" onclick="trait_summary_hist_change(70773)"><span class="glyphicon glyphicon-stats"></span></a>'],['<a href="/stock/38880/view">UG120003</a>','<a href="/cvterm/70773/view">fresh shoot weight measurement in kg|CO_334:0000016</a>','5.25','4.50','6.00','1.06','20.21%',2,'0%','<a href="#raw_data_histogram_well" onclick="trait_summary_hist_change(70773)"><span class="glyphicon glyphicon-stats"></span></a>'],['<a href="/stock/38879/view">UG120002</a>','<a href="/cvterm/70773/view">fresh shoot weight measurement in kg|CO_334:0000016</a>','6.25','3.00','9.50','4.60','73.54%',2,'0%','<a href="#raw_data_histogram_well" onclick="trait_summary_hist_change(70773)"><span class="glyphicon glyphicon-stats"></span></a>'],['<a href="/stock/38878/view">UG120001</a>','<a href="/cvterm/70773/view">fresh shoot weight measurement in kg|CO_334:0000016</a>','20.00','12.00','28.00','11.31','56.57%',2,'0%','<a href="#raw_data_histogram_well" onclick="trait_summary_hist_change(70773)"><span class="glyphicon glyphicon-stats"></span></a>']]);

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/phenotypes_fully_uploaded');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'phenotypes_fully_uploaded'=>undef});

$mech->post_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/phenotypes_fully_uploaded', ['phenotypes_fully_uploaded'=>1]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'success' =>1});

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/phenotypes_fully_uploaded');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'phenotypes_fully_uploaded'=>1});

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/traits_assayed');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'traits_assayed' => [[[70741,'dry matter content percentage|CO_334:0000092', [], 464, undef, undef],[70666,'fresh root weight|CO_334:0000012', [], 469, undef, undef],[70773,'fresh shoot weight measurement in kg|CO_334:0000016', [], 494, undef, undef]]]});

my $trait_id = 70741;
$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/heatmap?selected='.$trait_id );
$response = decode_json $mech->content;
#print STDERR Dumper $response;
is_deeply($response->{phenoID}, [737570,737678,737975,738383,738593,738428,738119,738044,737720,737771,737684,738053,737987,738293,738491,738800,738998,737843,737780,738488,739097,737366,737123,738272,738638,737579,737345,738584,737807,738326,738569,737039,739022,738545,738368,738662,738875,737480,737834,738587,738260,737663,737360,738023,737852,737528,737321,738920,737948,738290,737735,738002,737627,737435,737162,739019,738713,737318,737861,738671,738626,738446,738155,737789,738101,737180,737633,738761,737522,738173,738857,738521,738212,737831,737810,738734,737942,737438,738740,739049,738497,738011,737327,737048,738719,737126,737933,737564,738506,738572,738257,738656,737234,737498,738839,738554,738899,737063,737315,737642,737531,737897,738140,738782,737657,737240,737840,738746,737471,738950,738644,737696,738263,737816,738509,738302,738869,738674,738872,738071,737186,738380,737603,738215,738350,738632,737225,739028,738455,738200,737900,737759,737453,738440,737819,738026,737519,737945,738983,737114,738941,738623,738419,738878,738107,738356,737090,737921,737177,737420,737912,737636,738710,738305,737618,737375,737348,737159,738887,738830,738398,737705,737357,738827,738335,738095,737981,737606,737384,737057,737609,737951,738233,738077,737408,737417,738731,739055,738164,738482,737750,738020,737075,738932,738659,737312,737066,737762,738152,738242,739016,738665,737282,738392,739058,737558,738197,738431,738284,737996,738605,738377,738365,738557,738032,737798,737474,738962,738347,738824,739046,737033,737219,737288,738668,738848,737516,737906,737645,737381,737246,738995,737768,738158,738500,738689,739025,737294,737888,738182,737309,737801,737045,738041,738755,737153,738329,739013,737756,737513,738401,738074,738776,738461,737339,738992,737963,737426,738230,738089,737687,737444,738617,738896,739094,738308,738338,737711,738008,738104,738908,737717,737660,737624,737456,737165,738968,738695,738860,738194,738038,738149,737969,737552,737423,737732,738698,737201,738512,737243,738143,737744,738650,738905,738764,739034,737918,738254,737486,737795,737972,737147,737138,737405,739067,738269,737714,738485,737333,737909,737672,737174,737135,738893,738791,738524,738386,737462,737573,737876,737867,738122,737591,738803,738737,738977,737999,738116,737837,737324,737306,739073,737336,737537,737990,737804,737483,737156,738581,737546,738836,739085,737099,737396,738758,738971,737864,738548,737189,738980,737594,737144,738035,737675,738902,738956,738131,738275,737600,737399,737102,738923,738608,737783,737882,738281,737858,737543,737492,737108,738866,738635,738185,739079,738341,737411,738536,737342,737111,737429,737849,737954,738527,738167,738359,738794,739001,737252,737588,738728,737741,737729,737651,737198,739004,738707,738476,738311,738218,738473,738374,738599,738851,738647,738884,737081,737330,738881,738188,737885,738614,738914,738767,739037,738161,738434,737708,738017,737054,738929,738692,737699,738464,737267,738083,738683,737447,738458,738239,738449,738056,738680,738467,737231,738986,738575,739031,738014,737654,738050,737753,737096,738965,738203,738470,738611,738854,737207,739088,737141,739040,737903,737648,738404,738944,738911,737504,737261,738065,737213,739091,737681,737459,738443,738749,737825,738191,738560,738221,738224,738890,737966,738815,737276,738314,739076,737915,737585,737087,737525,737441,737939,737582,737984,738320,738530,738779,737060,738938,738425,738098,738317,737540,737351,737450,738773,739007,738629,739100,738809,737468,737228,737291,737051,737873,737534,738974,737249,739064,737042,738395,738278,737930,737978,737621,737393,739010,737924,738371,738686,737183,737369,737549,737846,738266,738518,738947,738917,737132,737666,738287,738332,738701,737222,737432,737747,737765,738179,737828,738407,737555,738797,738206,737216,738602,737084,737927,738818,737477,737639,738248,737192,737957,737510,737168,739082,737204,737372,737561,737774,737036,738725,738752,738128,737264,737465,738833,738113,738170,738416,737567,737822,737855,737072,738494,738227,737105,737786,738716,738722,738551,738953,737738,738566,738413,737612,738590,738863,738641,739070,737879,737078,738362,737597,738209,738785,737285,737270,737489,737960,737576,738422,738137,738578,738620,737390,737195,737120,737303,739052,738323,738134,737693,738092,738437,738110,738452,737690,738047,737171,737495,738812,739061,738389,738821,738005,738653,737414,738926,739106,737726,738125,737669,738062,738353,738068,738344,737501,737870,737993,737237,738542,737273,737069,737378,738563,738806,737402,737702,738842,739043,738299,738479,737936,737615,738410,738176,738959,738677,738245,738515,738743,738935,738059,737258,737507,738845,738788,738596,737255,737117,737129,737300,738989,738704,738503,738251,738086,737723,738080,737813,737354,737210,737777,737894,737093,737363,738296,738533,737792,737891,737150,737387,737630,737279,739103,738770,738539,738146,738236,738029,737297]);

my $phenotype_id = $schema->resultset('Phenotype::Phenotype')->search({observable_id=> '70741' },{'order_by'=>'phenotype_id'})->first->phenotype_id();
my $pheno_id = encode_json [$phenotype_id];
print STDERR Dumper $pheno_id;
$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/delete_single_trait?pheno_id='.$pheno_id);
$response = decode_json $mech->content;
is_deeply($response, {'success' =>1});

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/trait_histogram/70741');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'data' => ['20.7','26.7','26.4','26.4','26.4','29.7','24.7','20.8',20,'31.7','33.6','24.5','32.3','17.5','20.4','22.1','24.5',32,'19.3','25.1','22.1','23.6','21.1','33.3','32.3','26.8','20.1','31.3','33.8','16.3','25.9','23.8','25.2','16.3','25.3','23.1','32.8',27,'20.4','30.9','22.5','28.2','21.4','16.3',21,'24.3','31.4','23.9','21.3','28.1',18,'24.3',21,'26.9',27,25,'30.8',21,'29.1',30,'31.6','16.3','20.5','31.5','21.9','21.9','18.8','29.9','27.3','30.1','23.7','28.3','30.4','16.3','21.5','25.1',31,'28.2','28.5','33.9','17.2','24.1','31.6','16.3','22.2',28,'26.4','27.8','27.1','20.6','25.2','19.8','18.6','28.3','21.7','17.5','26.7','24.6','26.5','18.2','25.7',33,'32.5','16.3',17,23,'21.5','16.8','30.2','30.2','18.3','25.8',32,'24.4','31.6','27.2','16.3','31.9','25.1','17.9',23,'26.3','25.8','16.3',22,'30.8','18.2','23.6','19.9','21.5','27.1','16.3',19,'29.2','17.1','23.2','17.1','27.9','29.1','29.6','27.1','28.1','39.1','23.6','31.5','18.3','30.1','27.8','16.8',25,'22.7','22.8','24.1','27.4','21.1','29.2','16.3','32.4','27.3','32.8',20,'24.4','18.8','21.3','26.8','29.8','26.4','22.7','21.7','19.6','16.3','24.2','22.2','20.6','28.3','28.1','24.7','22.6','17.9','26.7','29.8',30,'22.1','20.9','16.3','19.1','31.2','19.3','22.2',26,21,'29.3','25.7','21.5','30.4','16.3','25.9',25,'31.7','29.4','19.7','17.4','17.5','29.2','24.8','22.7','29.1','22.4','17.7','29.3','25.7','29.2','17.3','30.1',23,'23.8',22,'30.9','22.3','31.8','16.3','29.4','22.1','27.9','23.4','17.4','18.4','28.2','18.3','16.3','16.3','25.3','29.8','28.9','20.2','16.3','25.6','16.3',19,'27.8','23.5','28.3','34.1','28.1','29.9','28.1','27.4','16.3','16.3','19.7','19.6','23.2','25.8','28.3','29.4','29.4','29.9','22.5','29.2','27.7','28.6','27.2','32.6',34,'31.3','25.9',26,'16.3','28.5','32.5','20.2','30.4',27,'34.3','29.5','30.2','25.9',19,'16.3','26.5','33.7','21.4','28.9','26.6','21.4','25.9','22.4','30.4','29.3',22,28,'23.4','31.9','22.4','26.4','28.6','29.6','21.8','29.4','30.5','22.4','31.5','24.5','29.4','32.1','26.5','16.3','28.1',35,28,'27.3',27,'24.3','25.7','17.7','24.3','28.7','24.2','24.5',20,'29.5','16.3','30.7',19,'20.1','18.6','16.3',27,'34.4','29.7','28.6','21.1','26.3','29.4','27.6','19.9','26.9','30.8','30.4','21.2',21,'32.5','30.9','24.8',23,'26.1','23.2','16.3','24.2','26.2','23.9','30.3','26.6',26,'31.2','23.1','25.5','17.7','35.4','22.1',24,'31.9','30.4','29.4','28.5','16.3','39.9','33.9','22.4','31.7','23.8','21.8','27.5','20.3','18.3','16.3',30,'19.7','17.9','23.5','16.3','28.1','21.1','25.5','25.8','26.8','29.1',26,'19.2','19.2','29.7',23,'20.4','19.9','25.6','19.9','27.8','16.3','26.7','24.4','19.9','27.1','24.5',32,'30.6','29.8','16.3','24.5','22.6','16.3','29.6',30,'29.3','27.7','24.3','23.1','25.1','27.7','35.2','28.1',28,'23.1','20.4','23.4','33.4','29.6','30.8','28.6','35.1','23.7','21.8',24,'20.8','34.6','22.6','22.1',24,'16.8','21.7','27.1','20.4','29.9',37,'21.6','25.6','20.1','33.1','24.6','20.4','29.9',19,'24.5','23.4','27.4','17.8','26.8','22.1','23.3','28.9','22.8','17.2','28.1','32.7']});

#Add phenotype that was deleted again so that tests pass downstream.
$mech->post_ok('http://localhost:3010/ajax/phenotype/plot_phenotype_upload', [ "plot_name"=> "KASESE_TP2013_1619", "trait"=> "dry matter content percentage|CO_334:0000092", "trait_value"=> "29", trait_list_option => 1 ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'success'}, 1);

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/folder');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'folder' => [134,'test']});

$trial_id = $schema->resultset('Project::Project')->find({name=>'test_trial'})->project_id();

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/accessions');
$response = decode_json $mech->content;
print STDERR Dumper $response;
my @accessions = @{$response->{accessions}->[0]};
@last_n = @accessions[-4..-1];
print STDERR Dumper \@last_n;
is_deeply($response, {'accessions' => [[{'accession_name' => 'test_accession1','stock_id' => 38840, 'stock_type' => 'accession'},{'stock_id' => 38841,'accession_name' => 'test_accession2', 'stock_type' => 'accession'},{'stock_id' => 38842,'accession_name' => 'test_accession3', 'stock_type' => 'accession'},{'stock_id' => 38843,'accession_name' => 'test_accession4', 'stock_type' => 'accession'},{'stock_id' => 38844,'accession_name' => 'test_accession5', 'stock_type' => 'accession'}]]});

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/controls');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'accessions' => [[]]});

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/plots');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'plots' => [[[38857,'test_trial21'],[38858,'test_trial22'],[38859,'test_trial23'],[38860,'test_trial24'],[38861,'test_trial25'],[38862,'test_trial26'],[38863,'test_trial27'],[38864,'test_trial28'],[38865,'test_trial29'],[38866,'test_trial210'],[38867,'test_trial211'],[38868,'test_trial212'],[38869,'test_trial213'],[38870,'test_trial214'],[38871,'test_trial215']]]} );

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/plants');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'plants' => [[]]});

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/controls_by_plot');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'accessions' => [[]]});

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/design');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'plot_width' => '','design' => {'3' => {'rep_number' => '1','plant_names' => [],'plot_name' => 'test_trial23','plot_number' => '3','plot_id' => 38859,'block_number' => '1','tissue_sample_index_numbers' => [],'plant_ids' => [],'accession_name' => 'test_accession3','accession_id' => 38842,'tissue_sample_names' => [],'plants_tissue_sample_names' => {},'plant_index_numbers' => [],'tissue_sample_ids' => []},'10' => {'rep_number' => '3','plot_name' => 'test_trial210','plant_names' => [],'block_number' => '1','plot_id' => 38866,'plot_number' => '10','plant_ids' => [],'tissue_sample_index_numbers' => [],'plants_tissue_sample_names' => {},'plant_index_numbers' => [],'accession_name' => 'test_accession3','tissue_sample_names' => [],'accession_id' => 38842,'tissue_sample_ids' => []},'9' => {'rep_number' => '1','plot_number' => '9','block_number' => '1','plot_id' => 38865,'plant_names' => [],'plot_name' => 'test_trial29','tissue_sample_index_numbers' => [],'plant_ids' => [],'tissue_sample_ids' => [],'accession_name' => 'test_accession2','tissue_sample_names' => [],'accession_id' => 38841,'plant_index_numbers' => [],'plants_tissue_sample_names' => {}},'13' => {'plant_ids' => [],'tissue_sample_index_numbers' => [],'tissue_sample_ids' => [],'plant_index_numbers' => [],'plants_tissue_sample_names' => {},'accession_id' => 38841,'accession_name' => 'test_accession2','tissue_sample_names' => [],'rep_number' => '2','block_number' => '1','plot_id' => 38869,'plot_number' => '13','plot_name' => 'test_trial213','plant_names' => []},'14' => {'block_number' => '1','plot_id' => 38870,'plot_number' => '14','plot_name' => 'test_trial214','plant_names' => [],'rep_number' => '3','tissue_sample_ids' => [],'plant_index_numbers' => [],'plants_tissue_sample_names' => {},'tissue_sample_names' => [],'accession_name' => 'test_accession4','accession_id' => 38843,'plant_ids' => [],'tissue_sample_index_numbers' => []},'12' => {'tissue_sample_ids' => [],'plant_index_numbers' => [],'plants_tissue_sample_names' => {},'accession_name' => 'test_accession5','tissue_sample_names' => [],'accession_id' => 38844,'plant_ids' => [],'tissue_sample_index_numbers' => [],'plot_id' => 38868,'block_number' => '1','plot_number' => '12','plant_names' => [],'plot_name' => 'test_trial212','rep_number' => '3'},'1' => {'plants_tissue_sample_names' => {},'plant_index_numbers' => [],'tissue_sample_names' => [],'accession_id' => 38843,'accession_name' => 'test_accession4','tissue_sample_ids' => [],'plant_ids' => [],'tissue_sample_index_numbers' => [],'plant_names' => [],'plot_name' => 'test_trial21','block_number' => '1','plot_id' => 38857,'plot_number' => '1','rep_number' => '1'},'6' => {'plant_ids' => [],'tissue_sample_index_numbers' => [],'tissue_sample_ids' => [],'plant_index_numbers' => [],'plants_tissue_sample_names' => {},'accession_id' => 38843,'tissue_sample_names' => [],'accession_name' => 'test_accession4','rep_number' => '2','block_number' => '1','plot_id' => 38862,'plot_number' => '6','plot_name' => 'test_trial26','plant_names' => []},'11' => {'rep_number' => '3','plant_names' => [],'plot_name' => 'test_trial211','block_number' => '1','plot_id' => 38867,'plot_number' => '11','plant_ids' => [],'tissue_sample_index_numbers' => [],'plants_tissue_sample_names' => {},'plant_index_numbers' => [],'accession_id' => 38840,'tissue_sample_names' => [],'accession_name' => 'test_accession1','tissue_sample_ids' => []},'7' => {'tissue_sample_index_numbers' => [],'plant_ids' => [],'tissue_sample_names' => [],'accession_id' => 38844,'accession_name' => 'test_accession5','plants_tissue_sample_names' => {},'plant_index_numbers' => [],'tissue_sample_ids' => [],'rep_number' => '2','plot_name' => 'test_trial27','plant_names' => [],'plot_number' => '7','block_number' => '1','plot_id' => 38863},'4' => {'plants_tissue_sample_names' => {},'plant_index_numbers' => [],'accession_id' => 38842,'tissue_sample_names' => [],'accession_name' => 'test_accession3','tissue_sample_ids' => [],'plant_ids' => [],'tissue_sample_index_numbers' => [],'plot_name' => 'test_trial24','plant_names' => [],'block_number' => '1','plot_id' => 38860,'plot_number' => '4','rep_number' => '2'},'8' => {'tissue_sample_ids' => [],'tissue_sample_names' => [],'accession_name' => 'test_accession1','accession_id' => 38840,'plant_index_numbers' => [],'plants_tissue_sample_names' => {},'tissue_sample_index_numbers' => [],'plant_ids' => [],'plot_number' => '8','plot_id' => 38864,'block_number' => '1','plant_names' => [],'plot_name' => 'test_trial28','rep_number' => '2'},'15' => {'tissue_sample_ids' => [],'plant_index_numbers' => [],'plants_tissue_sample_names' => {},'accession_name' => 'test_accession2','accession_id' => 38841,'tissue_sample_names' => [],'plant_ids' => [],'tissue_sample_index_numbers' => [],'plot_id' => 38871,'block_number' => '1','plot_number' => '15','plot_name' => 'test_trial215','plant_names' => [],'rep_number' => '3'},'5' => {'rep_number' => '1','plot_name' => 'test_trial25','plant_names' => [],'plot_number' => '5','plot_id' => 38861,'block_number' => '1','tissue_sample_index_numbers' => [],'plant_ids' => [],'accession_name' => 'test_accession1','tissue_sample_names' => [],'accession_id' => 38840,'plant_index_numbers' => [],'plants_tissue_sample_names' => {},'tissue_sample_ids' => []},'2' => {'tissue_sample_index_numbers' => [],'plant_ids' => [],'tissue_sample_names' => [],'accession_name' => 'test_accession5','accession_id' => 38844,'plant_index_numbers' => [],'plants_tissue_sample_names' => {},'tissue_sample_ids' => [],'rep_number' => '1','plant_names' => [],'plot_name' => 'test_trial22','plot_number' => '2','plot_id' => 38858,'block_number' => '1'}},'design_type' => 'CRD','num_blocks' => 1,'num_reps' => 3,'plants_per_plot' => '','total_number_plots' => 15,'plot_length' => ''});

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/layout');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'design' => {'8' => {'rep_number' => '2','plot_name' => 'test_trial28','plant_names' => [],'block_number' => '1','plot_id' => 38864,'plot_number' => '8','plant_ids' => [],'tissue_sample_index_numbers' => [],'plant_index_numbers' => [],'plants_tissue_sample_names' => {},'tissue_sample_names' => [],'accession_id' => 38840,'accession_name' => 'test_accession1','tissue_sample_ids' => []},'5' => {'plant_names' => [],'plot_name' => 'test_trial25','plot_number' => '5','block_number' => '1','plot_id' => 38861,'rep_number' => '1','tissue_sample_names' => [],'accession_id' => 38840,'accession_name' => 'test_accession1','plants_tissue_sample_names' => {},'plant_index_numbers' => [],'tissue_sample_ids' => [],'tissue_sample_index_numbers' => [],'plant_ids' => []},'15' => {'accession_id' => 38841,'tissue_sample_names' => [],'accession_name' => 'test_accession2','plants_tissue_sample_names' => {},'plant_index_numbers' => [],'tissue_sample_ids' => [],'tissue_sample_index_numbers' => [],'plant_ids' => [],'plot_name' => 'test_trial215','plant_names' => [],'plot_number' => '15','plot_id' => 38871,'block_number' => '1','rep_number' => '3'},'2' => {'rep_number' => '1','plot_name' => 'test_trial22','plant_names' => [],'plot_number' => '2','block_number' => '1','plot_id' => 38858,'tissue_sample_index_numbers' => [],'plant_ids' => [],'accession_id' => 38844,'tissue_sample_names' => [],'accession_name' => 'test_accession5','plant_index_numbers' => [],'plants_tissue_sample_names' => {},'tissue_sample_ids' => []},'10' => {'accession_id' => 38842,'accession_name' => 'test_accession3','tissue_sample_names' => [],'plant_index_numbers' => [],'plants_tissue_sample_names' => {},'tissue_sample_ids' => [],'tissue_sample_index_numbers' => [],'plant_ids' => [],'plant_names' => [],'plot_name' => 'test_trial210','plot_number' => '10','plot_id' => 38866,'block_number' => '1','rep_number' => '3'},'3' => {'tissue_sample_ids' => [],'plants_tissue_sample_names' => {},'plant_index_numbers' => [],'tissue_sample_names' => [],'accession_name' => 'test_accession3','accession_id' => 38842,'plant_ids' => [],'tissue_sample_index_numbers' => [],'block_number' => '1','plot_id' => 38859,'plot_number' => '3','plant_names' => [],'plot_name' => 'test_trial23','rep_number' => '1'},'13' => {'plant_ids' => [],'tissue_sample_index_numbers' => [],'plant_index_numbers' => [],'plants_tissue_sample_names' => {},'accession_name' => 'test_accession2','accession_id' => 38841,'tissue_sample_names' => [],'tissue_sample_ids' => [],'rep_number' => '2','plot_name' => 'test_trial213','plant_names' => [],'plot_id' => 38869,'block_number' => '1','plot_number' => '13'},'9' => {'tissue_sample_ids' => [],'plants_tissue_sample_names' => {},'plant_index_numbers' => [],'tissue_sample_names' => [],'accession_id' => 38841,'accession_name' => 'test_accession2','plant_ids' => [],'tissue_sample_index_numbers' => [],'block_number' => '1','plot_id' => 38865,'plot_number' => '9','plant_names' => [],'plot_name' => 'test_trial29','rep_number' => '1'},'14' => {'plants_tissue_sample_names' => {},'plant_index_numbers' => [],'accession_id' => 38843,'tissue_sample_names' => [],'accession_name' => 'test_accession4','tissue_sample_ids' => [],'plant_ids' => [],'tissue_sample_index_numbers' => [],'plant_names' => [],'plot_name' => 'test_trial214','plot_id' => 38870,'block_number' => '1','plot_number' => '14','rep_number' => '3'},'12' => {'plant_names' => [],'plot_name' => 'test_trial212','plot_number' => '12','plot_id' => 38868,'block_number' => '1','rep_number' => '3','accession_name' => 'test_accession5','accession_id' => 38844,'tissue_sample_names' => [],'plants_tissue_sample_names' => {},'plant_index_numbers' => [],'tissue_sample_ids' => [],'tissue_sample_index_numbers' => [],'plant_ids' => []},'1' => {'rep_number' => '1','plot_name' => 'test_trial21','plant_names' => [],'plot_id' => 38857,'block_number' => '1','plot_number' => '1','plant_ids' => [],'tissue_sample_index_numbers' => [],'plants_tissue_sample_names' => {},'plant_index_numbers' => [],'accession_id' => 38843,'accession_name' => 'test_accession4','tissue_sample_names' => [],'tissue_sample_ids' => []},'7' => {'tissue_sample_index_numbers' => [],'plant_ids' => [],'tissue_sample_names' => [],'accession_name' => 'test_accession5','accession_id' => 38844,'plants_tissue_sample_names' => {},'plant_index_numbers' => [],'tissue_sample_ids' => [],'rep_number' => '2','plant_names' => [],'plot_name' => 'test_trial27','plot_number' => '7','plot_id' => 38863,'block_number' => '1'},'4' => {'block_number' => '1','plot_id' => 38860,'plot_number' => '4','plant_names' => [],'plot_name' => 'test_trial24','rep_number' => '2','tissue_sample_ids' => [],'plant_index_numbers' => [],'plants_tissue_sample_names' => {},'accession_id' => 38842,'accession_name' => 'test_accession3','tissue_sample_names' => [],'plant_ids' => [],'tissue_sample_index_numbers' => []},'11' => {'rep_number' => '3','plot_name' => 'test_trial211','plant_names' => [],'plot_number' => '11','plot_id' => 38867,'block_number' => '1','tissue_sample_index_numbers' => [],'plant_ids' => [],'tissue_sample_names' => [],'accession_name' => 'test_accession1','accession_id' => 38840,'plant_index_numbers' => [],'plants_tissue_sample_names' => {},'tissue_sample_ids' => []},'6' => {'plant_index_numbers' => [],'plants_tissue_sample_names' => {},'tissue_sample_names' => [],'accession_id' => 38843,'accession_name' => 'test_accession4','tissue_sample_ids' => [],'plant_ids' => [],'tissue_sample_index_numbers' => [],'plant_names' => [],'plot_name' => 'test_trial26','plot_id' => 38862,'block_number' => '1','plot_number' => '6','rep_number' => '2'}}});

my %design_treatment = (
    'treatments' => {
        'treatmentname1' => [
            'test_trial22',
            'test_trial29'
        ]
    }
);

$mech->post_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/add_treatment', ["design"=>$json->encode(\%design_treatment)]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'success' => 1});

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/treatments');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'treatments'}->[0]->[1], 'test_trial_treatmentname1');

my $management_factor_project_id = $schema->resultset("Project::Project")->find({name=>'test_trial_treatmentname1'})->project_id();
$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$management_factor_project_id.'/plots');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'plots' => [[[38858,'test_trial22'],[38865,'test_trial29']]]});

done_testing();
