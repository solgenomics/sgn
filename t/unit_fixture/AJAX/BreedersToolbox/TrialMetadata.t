
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
is($response->{'metadata'}->{'status'}->[2]->{'success'}, 'Login Successfull');

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
is_deeply($response, {'traits_assayed' => [[[70741,'dry matter content percentage|CO_334:0000092'],[70666,'fresh root weight|CO_334:0000012'],[70773,'fresh shoot weight measurement in kg|CO_334:0000016']]]});

my $trait_id = 70741;
$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/heatmap?selected='.$trait_id );
$response = decode_json $mech->content;
#print STDERR Dumper $response;
is_deeply($response->{phenotypes}->{stock}, ['UG120054','UG130026','UG130106','UG130034','UG120062','UG120251','UG130088','UG120022','UG120141','UG120161','UG130046','UG120017','UG120053','UG120239','UG130111','UG130011','UG130105','UG120163','UG120027','UG120195','UG130007','UG120300','UG120291','UG120196','UG130098','UG130099','UG130078','UG120109','UG120191','UG130003','UG120223','UG120243','UG120008','UG120115','UG120290','UG120270','UG130089','UG120143','UG130021','UG120148','UG130006','UG130022','UG130107','UG130085','UG130092','UG120194','UG120298','UG120026','UG120287','UG130032','UG120193','UG120057','UG130103','UG120157','UG130002','UG120009','UG120072','UG130068','UG130077','UG120005','UG130124','UG120098','UG130013','UG120198','UG130126','UG130116','UG130094','UG120028','UG130082','UG120242','UG130029','UG120247','UG120069','UG130005','UG120227','UG120268','UG120306','UG130102','UG120190','UG130008','UG130080','UG120116','UG120002','UG130104','UG120221','UG120146','UG130120','UG120063','UG120132','UG130118','UG120248','UG120101','UG120184','UG130128','UG130070','UG120096','UG130110','UG120013','UG130117','UG130139','UG120164','UG120253','UG120213','UG120018','UG120137','UG120187','UG120226','UG120034','UG130030','UG120264','UG120103','UG120220','UG130009','UG120061','UG120106','UG130018','UG120288','UG130097','UG130001','UG130004','UG130020','UG130143','UG120245','UG120289','UG130122','UG120238','UG120039','UG120102','UG130058','UG120166','UG120015','UG120278','UG120006','UG120156','UG120035','UG120011','UG130059','UG120001','UG120228','UG130123','UG120040','UG120064','UG130051','UG120235','UG120107','UG120262','UG120074','UG130125','UG120297','UG120078','UG120292','UG120004','UG130083','UG120175','UG130121','UG120208','UG120280','UG120215','UG130043','UG120014','UG130144','UG120019','UG120283','UG130073','UG120080','UG120036','UG120121','UG130069','UG120218','UG120173','UG120260','UG120185','UG120174','UG130044','UG120219','UG130087','UG120135','UG130086','UG120181','UG130024','UG120108','UG120296','UG120029','UG120189','UG120024','UG120225','UG120033','UG120031','UG120046','UG120183','UG130109','UG120192','UG130057','UG120267','UG130031','UG120144','UG120162','UG120211','UG130025','UG120071','UG120178','UG120305','UG130017','UG120286','UG120177','UG120126','UG130093','UG120158','UG130066','UG120222','UG120169','UG130045','UG120021','UG120113','UG120179','UG130119','UG120058','UG120165','UG120122','UG120207','UG120172','UG120150','UG120303','UG120067','UG120076','UG120085','UG120266','UG130090','UG130108','UG120154','UG120265','UG120007','UG130135','UG120093','UG130074','UG130028','UG120167','UG120095','UG120284','UG120244','UG120266','UG120151','UG120120','UG130050','UG120084','UG120202','UG130067','UG130133','UG120170','UG120087','UG130113','UG120229','UG120088','UG130023','UG120199','UG130081','UG120048','UG130052','UG120307','UG120060','UG120306','UG130034','UG120286','UG120243','UG120261','UG120251','UG120220','UG120005','UG120098','UG130101','UG120063','UG130111','UG130105','UG130020','UG120096','UG130019','UG130003','UG130029','UG130007','UG120291','UG120193','UG130098','UG120219','UG120072','UG120190','UG120009','UG130068','UG130124','UG120103','UG130009','UG120288','UG120239','UG120132','UG130116','UG120148','UG130107','UG130092','UG120242','UG120245','UG120070','UG120247','UG120253','UG120205','UG120287','UG130047','UG120057','UG120278','UG130087','UG130080','UG130030','UG130008','UG130002','UG130077','UG130071','UG120188','UG120022','UG130088','UG120061','UG120161','UG130120','UG130118','UG130089','UG130011','UG120234','UG120257','UG120195','UG120300','UG120196','UG130099','UG120238','UG130078','UG130083','UG120178','UG120034','UG120157','UG130102','UG120109','UG120166','UG120105','UG120221','UG120146','UG130018','UG130126','UG120053','UG120017','UG130021','UG130094','UG130085','UG120194','UG130117','UG130005','UG120305','UG120071','UG120191','UG120297','UG120223','UG120187','UG120264','UG120008','UG130106','UG120037','UG120002','UG120115','UG120106','UG120101','UG130070','UG120028','UG120065','UG130082','UG120013','UG130091','UG120289','UG120298','UG130122','UG120069','UG130032','UG120284','UG130074','UG120210','UG120171','UG120099','UG120030','UG130050','UG120081','UG120153','UG120095','UG130063','UG130145','UG120011','UG120228','UG130097','UG120208','UG120006','UG130062','UG130006','UG130093','UG130017','UG120267','UG120019','UG120055','UG120156','UG120021','UG120133','UG120160','UG120113','UG120024','UG120292','UG120015','UG120296','UG120135','UG130103','UG120080','UG120004','UG120262','UG130043','UG120012','UG120158','UG120274','UG120218','UG120260','UG130076','UG120222','UG120173','UG120211','UG130033','UG130025','UG130024','UG120186','UG130140','UG120177','UG120181','UG130086','UG130051','UG120283','UG120235','UG130059','UG120215','UG120001','UG120036','UG120089','UG120108','UG120225','UG120174','UG120165','UG130044','UG120189','UG120183','UG120293','UG120064','UG120176','UG120025','UG120272','UG120126','UG130073','UG130121','UG120097','UG120192','UG120185','UG120020','UG130123','UG120246','UG120018','UG120076','UG120093']);

my $phenotype_id = $schema->resultset('Phenotype::Phenotype')->find({observable_id=> '70741' })->phenotype_id();
my $pheno_id = encode_json [$phenotype_id];
$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/delete_single_trait?pheno_id='.$pheno_id);
$response = decode_json $mech->content;
is_deeply($response, {'success' =>1});

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/trait_histogram/70741');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'data' => ['20.7','26.7','26.4','26.4','26.4','29.7','24.7','20.8',20,'31.7','33.6','24.5','32.3','17.5','20.4','22.1','24.5',32,'19.3','25.1','22.1','23.6','21.1','33.3','32.3','26.8','20.1','31.3','33.8','16.3','25.9','23.8','25.2','16.3','25.3','23.1','32.8',27,'20.4','30.9','22.5','28.2','21.4','16.3',21,'24.3','31.4','23.9','21.3','28.1',18,'24.3',21,'26.9',27,25,'30.8',21,'29.1',30,'31.6','16.3','20.5','31.5','21.9','21.9','18.8','29.9','27.3','30.1','23.7','28.3','30.4','16.3','21.5','25.1',31,'28.2','28.5','33.9','17.2','24.1','31.6','16.3','22.2',28,'26.4','27.8','27.1','20.6','25.2','19.8','18.6','28.3','21.7','17.5','26.7','24.6','26.5','18.2','25.7',33,'32.5','16.3',17,23,'21.5','16.8','30.2','30.2','18.3','25.8',32,'24.4','31.6','27.2','16.3','31.9','25.1','17.9',23,'26.3','25.8','16.3',22,'30.8','18.2','23.6','19.9','21.5','27.1','16.3',19,'29.2','17.1','23.2','17.1','27.9','29.1','29.6','27.1','28.1','39.1','23.6','31.5','18.3','30.1','27.8','16.8',25,'22.7','22.8','24.1','27.4','21.1','29.2','16.3','32.4','27.3','32.8',20,'24.4','18.8','21.3','26.8','29.8','26.4','22.7','21.7','19.6','16.3','24.2','22.2','20.6','28.3','28.1','24.7','22.6','17.9','26.7','29.8',30,'22.1','20.9','16.3','19.1','31.2','19.3','22.2',26,21,'29.3','25.7','21.5','30.4','16.3','25.9',25,'31.7','29.4','19.7','17.4','17.5','29.2','24.8','22.7','29.1','22.4','17.7','29.3','25.7','29.2','17.3','30.1',23,'23.8',22,'30.9','22.3','31.8','16.3','29.4','22.1','27.9','23.4','17.4','18.4','28.2','18.3','16.3','16.3','25.3','29.8','28.9','20.2','16.3','25.6','16.3',19,'27.8','23.5','28.3','34.1','28.1','29.9','28.1','27.4','16.3','16.3','19.7','19.6','23.2','25.8','28.3','29.4','29.4','29.9','22.5','29.2','27.7','28.6','27.2','32.6',34,'31.3','25.9',26,'16.3','28.5','32.5','20.2','30.4',27,'34.3','29.5','30.2','25.9',19,'16.3','26.5','33.7','21.4','28.9','26.6','21.4','25.9','22.4','30.4','29.3',22,28,'23.4','31.9','22.4','26.4','28.6','29.6','21.8','29.4','30.5','22.4','31.5','24.5','29.4','32.1','26.5','16.3','28.1',35,28,'27.3',27,'24.3','25.7','17.7','24.3','28.7','24.2','24.5',20,'29.5','16.3','30.7',19,'20.1','18.6','16.3',27,'34.4','29.7','28.6','21.1','26.3','29.4','27.6','19.9','26.9','30.8','30.4','21.2',21,'32.5','30.9','24.8',23,'26.1','23.2','16.3','24.2','26.2','23.9','30.3','26.6',26,'31.2','23.1','25.5','17.7','35.4','22.1',24,'31.9','30.4','29.4','28.5','16.3','39.9','33.9','22.4','31.7','23.8','21.8','27.5','20.3','18.3','16.3',30,'19.7','17.9','23.5','16.3','28.1','21.1','25.5','25.8','26.8','29.1',26,'19.2','19.2','29.7',23,'20.4','19.9','25.6','19.9','27.8','16.3','26.7','24.4','19.9','27.1','24.5',32,'30.6','29.8','16.3','24.5','22.6','16.3','29.6',30,'29.3','27.7','24.3','23.1','25.1','27.7','35.2','28.1',28,'23.1','20.4','23.4','33.4','29.6','30.8','28.6','35.1','23.7','21.8',24,'20.8','34.6','22.6','22.1',24,'16.8','21.7','27.1','20.4','29.9',37,'21.6','25.6','20.1','33.1','24.6','20.4','29.9',19,'24.5','23.4','27.4','17.8','26.8','22.1','23.3','28.9','22.8','17.2','28.1','32.7']});

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
is_deeply($response, {'accessions' => [[{'accession_name' => 'test_accession1','stock_id' => 38840},{'stock_id' => 38841,'accession_name' => 'test_accession2'},{'stock_id' => 38842,'accession_name' => 'test_accession3'},{'stock_id' => 38843,'accession_name' => 'test_accession4'},{'stock_id' => 38844,'accession_name' => 'test_accession5'}]]});

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/controls');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'accessions' => [[]]});

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/plots');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'plots' => [[[38857,'test_trial21'],[38866,'test_trial210'],[38867,'test_trial211'],[38868,'test_trial212'],[38869,'test_trial213'],[38870,'test_trial214'],[38871,'test_trial215'],[38858,'test_trial22'],[38859,'test_trial23'],[38860,'test_trial24'],[38861,'test_trial25'],[38862,'test_trial26'],[38863,'test_trial27'],[38864,'test_trial28'],[38865,'test_trial29']]]});

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
is_deeply($response, {'design' => {'9' => {'plant_names' => [],'accession_name' => 'test_accession2','block_number' => '1','accession_id' => 38841,'plot_id' => 38865,'rep_number' => '1','plant_ids' => [],'plot_name' => 'test_trial29','plot_number' => '9'},'1' => {'plot_number' => '1','plot_name' => 'test_trial21','rep_number' => '1','plant_ids' => [],'plot_id' => 38857,'block_number' => '1','accession_id' => 38843,'accession_name' => 'test_accession4','plant_names' => []},'13' => {'plant_names' => [],'accession_name' => 'test_accession2','accession_id' => 38841,'block_number' => '1','plot_id' => 38869,'plant_ids' => [],'rep_number' => '2','plot_name' => 'test_trial213','plot_number' => '13'},'10' => {'plot_id' => 38866,'block_number' => '1','accession_id' => 38842,'accession_name' => 'test_accession3','plant_names' => [],'plot_number' => '10','plot_name' => 'test_trial210','rep_number' => '3','plant_ids' => []},'12' => {'plot_id' => 38868,'accession_id' => 38844,'block_number' => '1','accession_name' => 'test_accession5','plant_names' => [],'plot_number' => '12','plot_name' => 'test_trial212','plant_ids' => [],'rep_number' => '3'},'11' => {'plot_number' => '11','plot_name' => 'test_trial211','plant_ids' => [],'rep_number' => '3','plot_id' => 38867,'accession_id' => 38840,'block_number' => '1','accession_name' => 'test_accession1','plant_names' => []},'4' => {'plot_id' => 38860,'block_number' => '1','accession_id' => 38842,'accession_name' => 'test_accession3','plant_names' => [],'plot_number' => '4','plot_name' => 'test_trial24','rep_number' => '2','plant_ids' => []},'5' => {'rep_number' => '1','plant_ids' => [],'plot_number' => '5','plot_name' => 'test_trial25','accession_name' => 'test_accession1','plant_names' => [],'plot_id' => 38861,'accession_id' => 38840,'block_number' => '1'},'3' => {'plot_id' => 38859,'block_number' => '1','accession_id' => 38842,'accession_name' => 'test_accession3','plant_names' => [],'plot_number' => '3','plot_name' => 'test_trial23','rep_number' => '1','plant_ids' => []},'8' => {'plant_names' => [],'accession_name' => 'test_accession1','block_number' => '1','accession_id' => 38840,'plot_id' => 38864,'plant_ids' => [],'rep_number' => '2','plot_name' => 'test_trial28','plot_number' => '8'},'6' => {'plant_ids' => [],'rep_number' => '2','plot_number' => '6','plot_name' => 'test_trial26','accession_name' => 'test_accession4','plant_names' => [],'plot_id' => 38862,'block_number' => '1','accession_id' => 38843},'14' => {'plant_names' => [],'accession_name' => 'test_accession4','block_number' => '1','accession_id' => 38843,'plot_id' => 38870,'rep_number' => '3','plant_ids' => [],'plot_name' => 'test_trial214','plot_number' => '14'},'15' => {'plot_name' => 'test_trial215','plot_number' => '15','rep_number' => '3','plant_ids' => [],'accession_id' => 38841,'block_number' => '1','plot_id' => 38871,'plant_names' => [],'accession_name' => 'test_accession2'},'7' => {'rep_number' => '2','plant_ids' => [],'plot_name' => 'test_trial27','plot_number' => '7','plant_names' => [],'accession_name' => 'test_accession5','block_number' => '1','accession_id' => 38844,'plot_id' => 38863},'2' => {'accession_name' => 'test_accession5','plant_names' => [],'plot_id' => 38858,'block_number' => '1','accession_id' => 38844,'plant_ids' => [],'rep_number' => '1','plot_number' => '2','plot_name' => 'test_trial22'}},'plot_length' => '','plants_per_plot' => '','num_reps' => 3,'plot_width' => '','design_type' => 'CRD','num_blocks' => 1});

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/layout');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'design' => {'9' => {'plant_names' => [],'accession_name' => 'test_accession2','block_number' => '1','accession_id' => 38841,'plot_id' => 38865,'rep_number' => '1','plant_ids' => [],'plot_name' => 'test_trial29','plot_number' => '9'},'1' => {'plot_number' => '1','plot_name' => 'test_trial21','rep_number' => '1','plant_ids' => [],'plot_id' => 38857,'block_number' => '1','accession_id' => 38843,'accession_name' => 'test_accession4','plant_names' => []},'13' => {'plant_names' => [],'accession_name' => 'test_accession2','accession_id' => 38841,'block_number' => '1','plot_id' => 38869,'plant_ids' => [],'rep_number' => '2','plot_name' => 'test_trial213','plot_number' => '13'},'10' => {'plot_id' => 38866,'block_number' => '1','accession_id' => 38842,'accession_name' => 'test_accession3','plant_names' => [],'plot_number' => '10','plot_name' => 'test_trial210','rep_number' => '3','plant_ids' => []},'12' => {'plot_id' => 38868,'accession_id' => 38844,'block_number' => '1','accession_name' => 'test_accession5','plant_names' => [],'plot_number' => '12','plot_name' => 'test_trial212','plant_ids' => [],'rep_number' => '3'},'11' => {'plot_number' => '11','plot_name' => 'test_trial211','plant_ids' => [],'rep_number' => '3','plot_id' => 38867,'accession_id' => 38840,'block_number' => '1','accession_name' => 'test_accession1','plant_names' => []},'4' => {'plot_id' => 38860,'block_number' => '1','accession_id' => 38842,'accession_name' => 'test_accession3','plant_names' => [],'plot_number' => '4','plot_name' => 'test_trial24','rep_number' => '2','plant_ids' => []},'5' => {'rep_number' => '1','plant_ids' => [],'plot_number' => '5','plot_name' => 'test_trial25','accession_name' => 'test_accession1','plant_names' => [],'plot_id' => 38861,'accession_id' => 38840,'block_number' => '1'},'3' => {'plot_id' => 38859,'block_number' => '1','accession_id' => 38842,'accession_name' => 'test_accession3','plant_names' => [],'plot_number' => '3','plot_name' => 'test_trial23','rep_number' => '1','plant_ids' => []},'8' => {'plant_names' => [],'accession_name' => 'test_accession1','block_number' => '1','accession_id' => 38840,'plot_id' => 38864,'plant_ids' => [],'rep_number' => '2','plot_name' => 'test_trial28','plot_number' => '8'},'6' => {'plant_ids' => [],'rep_number' => '2','plot_number' => '6','plot_name' => 'test_trial26','accession_name' => 'test_accession4','plant_names' => [],'plot_id' => 38862,'block_number' => '1','accession_id' => 38843},'14' => {'plant_names' => [],'accession_name' => 'test_accession4','block_number' => '1','accession_id' => 38843,'plot_id' => 38870,'rep_number' => '3','plant_ids' => [],'plot_name' => 'test_trial214','plot_number' => '14'},'15' => {'plot_name' => 'test_trial215','plot_number' => '15','rep_number' => '3','plant_ids' => [],'accession_id' => 38841,'block_number' => '1','plot_id' => 38871,'plant_names' => [],'accession_name' => 'test_accession2'},'7' => {'rep_number' => '2','plant_ids' => [],'plot_name' => 'test_trial27','plot_number' => '7','plant_names' => [],'accession_name' => 'test_accession5','block_number' => '1','accession_id' => 38844,'plot_id' => 38863},'2' => {'accession_name' => 'test_accession5','plant_names' => [],'plot_id' => 38858,'block_number' => '1','accession_id' => 38844,'plant_ids' => [],'rep_number' => '1','plot_number' => '2','plot_name' => 'test_trial22'}}});

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


done_testing();
