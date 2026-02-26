
# Tests all functions in SGN::Controller::AJAX::TrialMetadata. These are the functions called from Accessions.js when adding new accessions.

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;

#Needed to update IO::Socket::SSL
use Data::Dumper;
use JSON::XS;
use URI::Encode qw(uri_encode uri_decode);
use CXGN::Chado::Stock;
use CXGN::Trial;
use LWP::UserAgent;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $mech = Test::WWW::Mechanize->new;
my $response;
my $json = JSON::XS->new();

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ], "login post");
$response = decode_json $mech->content;
#print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};

my $trial_id = $schema->resultset('Project::Project')->find({name=>'Kasese solgs trial'})->project_id();

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/phenotypes?display=plots', "get phenotypes page for trial $trial_id");
$response = decode_json $mech->content;
#print STDERR Dumper $response;
is_deeply($response, {'data' => [['<a href="/cvterm/70741/view">dry matter content percentage|CO_334:0000092</a>','25.01','16.30','39.90','5.06','20.24%',464,'32.95%','<a href="#raw_data_histogram_well" onclick="trait_summary_hist_change(70741)"><span class="glyphicon glyphicon-stats"></span></a>'],['<a href="/cvterm/70666/view">fresh root weight|CO_334:0000012</a>','5.91','0.04','38.76','5.37','90.80%',469,'32.23%','<a href="#raw_data_histogram_well" onclick="trait_summary_hist_change(70666)"><span class="glyphicon glyphicon-stats"></span></a>'],['<a href="/cvterm/70773/view">fresh shoot weight measurement in kg|CO_334:0000016</a>','13.23','0.50','83.00','10.70','80.88%',494,'28.61%','<a href="#raw_data_histogram_well" onclick="trait_summary_hist_change(70773)"><span class="glyphicon glyphicon-stats"></span></a>']]}, "check trial detail page");

		#	  '<a href="/cvterm/70741/view">dry matter content percentage|CO_334:0000092</a>','26.02','15.00','500.00','22.61','86.89%',465,'32.8%','<a href="#raw_data_histogram_well" onclick="trait_summary_hist_change(70741)"><span class="glyphicon glyphicon-stats"></span></a>'],['<a href="/cvterm/70666/view">fresh root weight|CO_334:0000012</a>','5.91','0.04','38.76','5.37','90.80%',469,'32.23%','<a href="#raw_data_histogram_well" onclick="trait_summary_hist_change(70666)"><span class="glyphicon glyphicon-stats"></span></a>'],['<a href="/cvterm/70773/view">fresh shoot weight measurement in kg|CO_334:0000016</a>','14.33','0.50','555.00','26.62','185.78%',494,'28.61%','<a href="#raw_data_histogram_well" onclick="trait_summary_hist_change(70773)"><span class="glyphicon glyphicon-stats"></span></a>']]}, "check trial detail page");

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/phenotypes?display=plots_accession');
$response = decode_json $mech->content;
my @response = @{$response->{data}};
my @last_n = @response[-4..-1];
#print STDERR Dumper \@last_n;
is_deeply(\@last_n, [['<a href="/stock/38881/view">UG120004</a>','<a href="/cvterm/70773/view">fresh shoot weight measurement in kg|CO_334:0000016</a>','5.25','2.51','8.00','3.88','73.87%',2,'0%','<a href="#raw_data_histogram_well" onclick="trait_summary_hist_change(70773)"><span class="glyphicon glyphicon-stats"></span></a>'],['<a href="/stock/38880/view">UG120003</a>','<a href="/cvterm/70773/view">fresh shoot weight measurement in kg|CO_334:0000016</a>','5.25','4.50','6.00','1.06','20.21%',2,'0%','<a href="#raw_data_histogram_well" onclick="trait_summary_hist_change(70773)"><span class="glyphicon glyphicon-stats"></span></a>'],['<a href="/stock/38879/view">UG120002</a>','<a href="/cvterm/70773/view">fresh shoot weight measurement in kg|CO_334:0000016</a>','6.25','3.00','9.50','4.60','73.54%',2,'0%','<a href="#raw_data_histogram_well" onclick="trait_summary_hist_change(70773)"><span class="glyphicon glyphicon-stats"></span></a>'],['<a href="/stock/38878/view">UG120001</a>','<a href="/cvterm/70773/view">fresh shoot weight measurement in kg|CO_334:0000016</a>','20.00','12.00','28.00','11.31','56.57%',2,'0%','<a href="#raw_data_histogram_well" onclick="trait_summary_hist_change(70773)"><span class="glyphicon glyphicon-stats"></span></a>']], "check plots accessions");

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/phenotypes_fully_uploaded');
$response = decode_json $mech->content;
#print STDERR Dumper $response;
is_deeply($response, {'phenotypes_fully_uploaded'=>undef}, "get phenotype upload page");

$mech->post_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/phenotypes_fully_uploaded', ['phenotypes_fully_uploaded'=>1], "post phenotype upload");
$response = decode_json $mech->content;
#print STDERR Dumper $response;
is_deeply($response, {'success' =>1});

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/phenotypes_fully_uploaded');
$response = decode_json $mech->content;
#print STDERR Dumper $response;
is_deeply($response, {'phenotypes_fully_uploaded'=>1}, "get upload feedback");

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/traits_assayed');
$response = decode_json $mech->content;
#print STDERR Dumper $response;
is_deeply($response, {'traits_assayed' => [[[70741,'dry matter content percentage|CO_334:0000092', [], 464, undef, undef],[70666,'fresh root weight|CO_334:0000012', [], 469, undef, undef],[70773,'fresh shoot weight measurement in kg|CO_334:0000016', [], 494, undef, undef]]]}, "check assayed trait uploaded" );

my $trait_id = 70741;
$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/heatmap?selected='.$trait_id );
$response = decode_json $mech->content;

my $q = "SELECT phenotype_id, value FROM project join nd_experiment_project using(project_id) join nd_experiment_phenotype using(nd_experiment_id) join phenotype using(phenotype_id) WHERE project.project_id =? and cvalue_id = ?";
my $h = $schema->storage->dbh()->prepare($q);

$h->execute($trial_id, $trait_id);
    
my @pheno_ids;
my @values;
while (my ($phenotype_id, $value)  = $h->fetchrow_array() ) {
    push @pheno_ids, $phenotype_id;
    if (defined($value)) { push @values, $value; }
}

#print STDERR "PHENO IDS = ".join(",",@pheno_ids)."\n";
#print STDERR "VALUES = ".join(",",@values)."\n";

#print STDERR "PHENO IDS: ".Dumper $response->{phenoID};
is_deeply([ sort( @{$response->{phenoID}}) ], [ sort(@pheno_ids) ], "phenotype id check for heatmap");

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/trait_histogram/70741');
$response = decode_json $mech->content;
#print STDERR "TRAIT HISTOGRAM DATA: ".Dumper $response;

my @sorted_data =  sort( { $a <=> $b } @{$response->{data}});
my @sorted_expected = sort({ $a <=> $b } @values);

#print STDERR "DATA = ".Dumper(\@sorted_data);
#print STDERR "EXP DATA = ".Dumper(\@sorted_expected);

is_deeply(\@sorted_data, \@sorted_expected, "check histogram data");

#Add phenotype to test deletion.
#$mech->post_ok('http://localhost:3010/ajax/phenotype/plot_phenotype_upload', [ "plot_name"=> "KASESE_TP2013_1619", "trait_list_option"=> "dry matter content percentage|CO_334:0000092", "trait_value"=> "29" ]);
$mech->post_ok('http://localhost:3010/ajax/phenotype/plot_phenotype_upload', [ "plot_name"=> "KASESE_TP2013_1619", "trait_list_option"=> "gari starch percentage|CO_334:0000238", "trait_value"=> "29" ]);

$response = decode_json $mech->content;

#print STDERR "Add phenotype to test deletion response: ".Dumper $response;

is($response->{'success'}, 1, "upload phenotype to test deletion");

#my $phenotype_id = $schema->resultset('Phenotype::Phenotype')->search({observable_id=> '70741' },{'order_by'=>'phenotype_id'})->first->phenotype_id();
my $phenotype_id = $schema->resultset('Phenotype::Phenotype')->search({observable_id=> '76848' },{'order_by'=>'phenotype_id'})->first->phenotype_id();

my $pheno_id = encode_json [$phenotype_id];

$ENV{DBIC_TRACE} = 1;
#print STDERR "PHENO ID: ".Dumper $pheno_id;
$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/delete_single_trait?pheno_id='.$pheno_id);
$response = decode_json $mech->content;

is_deeply($response, {'success' =>1}, "check if successful");

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/folder');
$response = decode_json $mech->content;
#print STDERR Dumper $response;

my $frs = $schema->resultset("Project::Project")->search( { project_id => $trial_id }, { join => 'project_relationship_subject_projects', '+select' => 'project_relationship_subject_projects.object_project_id', '+as' => 'parent_project_id' } );

my $row = $frs->next();

my $prow = $schema->resultset("Project::Project")->find( { project_id => $row->get_column('parent_project_id') });

#print STDERR  "RETRIEVED PROJECT ID ".$row->get_column('parent_project_id');

#is_deeply($response, {'folder' => [134,'Peru Yield Trial 2020-1']}, "folder test");
is_deeply($response, {'folder' => [ $row->get_column('parent_project_id') , $prow->name() ]}, "folder test");

$trial_id = $schema->resultset('Project::Project')->find({name=>'test_trial'})->project_id();

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/accessions', "check test trial");
$response = decode_json $mech->content;
#print STDERR Dumper $response;
my @accessions = @{$response->{accessions}->[0]};
@last_n = @accessions[-4..-1];
#print STDERR Dumper \@last_n;
is_deeply($response, {'accessions' => [[{'accession_name' => 'test_accession1','stock_id' => 38840, 'stock_type' => 'accession'},{'stock_id' => 38841,'accession_name' => 'test_accession2', 'stock_type' => 'accession'},{'stock_id' => 38842,'accession_name' => 'test_accession3', 'stock_type' => 'accession'},{'stock_id' => 38843,'accession_name' => 'test_accession4', 'stock_type' => 'accession'},{'stock_id' => 38844,'accession_name' => 'test_accession5', 'stock_type' => 'accession'}]]});

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/controls', "get controls");
$response = decode_json $mech->content;
#print STDERR Dumper $response;
is_deeply($response, {'accessions' => [[]]}, "check controls");

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/plots');
$response = decode_json $mech->content;
#print STDERR Dumper $response;
is_deeply($response, {'plots' => [[[38857,'test_trial21'],[38858,'test_trial22'],[38859,'test_trial23'],[38860,'test_trial24'],[38861,'test_trial25'],[38862,'test_trial26'],[38863,'test_trial27'],[38864,'test_trial28'],[38865,'test_trial29'],[38866,'test_trial210'],[38867,'test_trial211'],[38868,'test_trial212'],[38869,'test_trial213'],[38870,'test_trial214'],[38871,'test_trial215']]]}, "check plots");

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/plants');
$response = decode_json $mech->content;
#print STDERR Dumper $response;
is_deeply($response, {'plants' => [[]]}, "check plants");

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/controls_by_plot');
$response = decode_json $mech->content;
#print STDERR Dumper $response;
is_deeply($response, {'accessions' => [[]]}, "check controls_by_plot");

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/design');
$response = decode_json $mech->content;
#print STDERR Dumper $response;
is_deeply($response, {subplots_per_plot=>'', 'plot_width' => '','design' => {'3' => {'rep_number' => '1','plant_names' => [],'plot_name' => 'test_trial23','plot_number' => '3','plot_id' => 38859,'block_number' => '1','tissue_sample_index_numbers' => [],'plant_ids' => [],'accession_name' => 'test_accession3','accession_id' => 38842,'tissue_sample_names' => [],'plants_tissue_sample_names' => {},'plant_index_numbers' => [],'tissue_sample_ids' => []},'10' => {'rep_number' => '3','plot_name' => 'test_trial210','plant_names' => [],'block_number' => '1','plot_id' => 38866,'plot_number' => '10','plant_ids' => [],'tissue_sample_index_numbers' => [],'plants_tissue_sample_names' => {},'plant_index_numbers' => [],'accession_name' => 'test_accession3','tissue_sample_names' => [],'accession_id' => 38842,'tissue_sample_ids' => []},'9' => {'rep_number' => '1','plot_number' => '9','block_number' => '1','plot_id' => 38865,'plant_names' => [],'plot_name' => 'test_trial29','tissue_sample_index_numbers' => [],'plant_ids' => [],'tissue_sample_ids' => [],'accession_name' => 'test_accession2','tissue_sample_names' => [],'accession_id' => 38841,'plant_index_numbers' => [],'plants_tissue_sample_names' => {}},'13' => {'plant_ids' => [],'tissue_sample_index_numbers' => [],'tissue_sample_ids' => [],'plant_index_numbers' => [],'plants_tissue_sample_names' => {},'accession_id' => 38841,'accession_name' => 'test_accession2','tissue_sample_names' => [],'rep_number' => '2','block_number' => '1','plot_id' => 38869,'plot_number' => '13','plot_name' => 'test_trial213','plant_names' => []},'14' => {'block_number' => '1','plot_id' => 38870,'plot_number' => '14','plot_name' => 'test_trial214','plant_names' => [],'rep_number' => '3','tissue_sample_ids' => [],'plant_index_numbers' => [],'plants_tissue_sample_names' => {},'tissue_sample_names' => [],'accession_name' => 'test_accession4','accession_id' => 38843,'plant_ids' => [],'tissue_sample_index_numbers' => []},'12' => {'tissue_sample_ids' => [],'plant_index_numbers' => [],'plants_tissue_sample_names' => {},'accession_name' => 'test_accession5','tissue_sample_names' => [],'accession_id' => 38844,'plant_ids' => [],'tissue_sample_index_numbers' => [],'plot_id' => 38868,'block_number' => '1','plot_number' => '12','plant_names' => [],'plot_name' => 'test_trial212','rep_number' => '3'},'1' => {'plants_tissue_sample_names' => {},'plant_index_numbers' => [],'tissue_sample_names' => [],'accession_id' => 38843,'accession_name' => 'test_accession4','tissue_sample_ids' => [],'plant_ids' => [],'tissue_sample_index_numbers' => [],'plant_names' => [],'plot_name' => 'test_trial21','block_number' => '1','plot_id' => 38857,'plot_number' => '1','rep_number' => '1'},'6' => {'plant_ids' => [],'tissue_sample_index_numbers' => [],'tissue_sample_ids' => [],'plant_index_numbers' => [],'plants_tissue_sample_names' => {},'accession_id' => 38843,'tissue_sample_names' => [],'accession_name' => 'test_accession4','rep_number' => '2','block_number' => '1','plot_id' => 38862,'plot_number' => '6','plot_name' => 'test_trial26','plant_names' => []},'11' => {'rep_number' => '3','plant_names' => [],'plot_name' => 'test_trial211','block_number' => '1','plot_id' => 38867,'plot_number' => '11','plant_ids' => [],'tissue_sample_index_numbers' => [],'plants_tissue_sample_names' => {},'plant_index_numbers' => [],'accession_id' => 38840,'tissue_sample_names' => [],'accession_name' => 'test_accession1','tissue_sample_ids' => []},'7' => {'tissue_sample_index_numbers' => [],'plant_ids' => [],'tissue_sample_names' => [],'accession_id' => 38844,'accession_name' => 'test_accession5','plants_tissue_sample_names' => {},'plant_index_numbers' => [],'tissue_sample_ids' => [],'rep_number' => '2','plot_name' => 'test_trial27','plant_names' => [],'plot_number' => '7','block_number' => '1','plot_id' => 38863},'4' => {'plants_tissue_sample_names' => {},'plant_index_numbers' => [],'accession_id' => 38842,'tissue_sample_names' => [],'accession_name' => 'test_accession3','tissue_sample_ids' => [],'plant_ids' => [],'tissue_sample_index_numbers' => [],'plot_name' => 'test_trial24','plant_names' => [],'block_number' => '1','plot_id' => 38860,'plot_number' => '4','rep_number' => '2'},'8' => {'tissue_sample_ids' => [],'tissue_sample_names' => [],'accession_name' => 'test_accession1','accession_id' => 38840,'plant_index_numbers' => [],'plants_tissue_sample_names' => {},'tissue_sample_index_numbers' => [],'plant_ids' => [],'plot_number' => '8','plot_id' => 38864,'block_number' => '1','plant_names' => [],'plot_name' => 'test_trial28','rep_number' => '2'},'15' => {'tissue_sample_ids' => [],'plant_index_numbers' => [],'plants_tissue_sample_names' => {},'accession_name' => 'test_accession2','accession_id' => 38841,'tissue_sample_names' => [],'plant_ids' => [],'tissue_sample_index_numbers' => [],'plot_id' => 38871,'block_number' => '1','plot_number' => '15','plot_name' => 'test_trial215','plant_names' => [],'rep_number' => '3'},'5' => {'rep_number' => '1','plot_name' => 'test_trial25','plant_names' => [],'plot_number' => '5','plot_id' => 38861,'block_number' => '1','tissue_sample_index_numbers' => [],'plant_ids' => [],'accession_name' => 'test_accession1','tissue_sample_names' => [],'accession_id' => 38840,'plant_index_numbers' => [],'plants_tissue_sample_names' => {},'tissue_sample_ids' => []},'2' => {'tissue_sample_index_numbers' => [],'plant_ids' => [],'tissue_sample_names' => [],'accession_name' => 'test_accession5','accession_id' => 38844,'plant_index_numbers' => [],'plants_tissue_sample_names' => {},'tissue_sample_ids' => [],'rep_number' => '1','plant_names' => [],'plot_name' => 'test_trial22','plot_number' => '2','plot_id' => 38858,'block_number' => '1'}},'design_type' => 'CRD','num_blocks' => 1,'num_reps' => 3,'plants_per_plot' => '','total_number_plots' => 15,'plot_length' => ''}, "check design");

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/layout');
$response = decode_json $mech->content;
#print STDERR Dumper $response;
is_deeply($response, {'design' => {'8' => {'rep_number' => '2','plot_name' => 'test_trial28','plant_names' => [],'block_number' => '1','plot_id' => 38864,'plot_number' => '8','plant_ids' => [],'tissue_sample_index_numbers' => [],'plant_index_numbers' => [],'plants_tissue_sample_names' => {},'tissue_sample_names' => [],'accession_id' => 38840,'accession_name' => 'test_accession1','tissue_sample_ids' => []},'5' => {'plant_names' => [],'plot_name' => 'test_trial25','plot_number' => '5','block_number' => '1','plot_id' => 38861,'rep_number' => '1','tissue_sample_names' => [],'accession_id' => 38840,'accession_name' => 'test_accession1','plants_tissue_sample_names' => {},'plant_index_numbers' => [],'tissue_sample_ids' => [],'tissue_sample_index_numbers' => [],'plant_ids' => []},'15' => {'accession_id' => 38841,'tissue_sample_names' => [],'accession_name' => 'test_accession2','plants_tissue_sample_names' => {},'plant_index_numbers' => [],'tissue_sample_ids' => [],'tissue_sample_index_numbers' => [],'plant_ids' => [],'plot_name' => 'test_trial215','plant_names' => [],'plot_number' => '15','plot_id' => 38871,'block_number' => '1','rep_number' => '3'},'2' => {'rep_number' => '1','plot_name' => 'test_trial22','plant_names' => [],'plot_number' => '2','block_number' => '1','plot_id' => 38858,'tissue_sample_index_numbers' => [],'plant_ids' => [],'accession_id' => 38844,'tissue_sample_names' => [],'accession_name' => 'test_accession5','plant_index_numbers' => [],'plants_tissue_sample_names' => {},'tissue_sample_ids' => []},'10' => {'accession_id' => 38842,'accession_name' => 'test_accession3','tissue_sample_names' => [],'plant_index_numbers' => [],'plants_tissue_sample_names' => {},'tissue_sample_ids' => [],'tissue_sample_index_numbers' => [],'plant_ids' => [],'plant_names' => [],'plot_name' => 'test_trial210','plot_number' => '10','plot_id' => 38866,'block_number' => '1','rep_number' => '3'},'3' => {'tissue_sample_ids' => [],'plants_tissue_sample_names' => {},'plant_index_numbers' => [],'tissue_sample_names' => [],'accession_name' => 'test_accession3','accession_id' => 38842,'plant_ids' => [],'tissue_sample_index_numbers' => [],'block_number' => '1','plot_id' => 38859,'plot_number' => '3','plant_names' => [],'plot_name' => 'test_trial23','rep_number' => '1'},'13' => {'plant_ids' => [],'tissue_sample_index_numbers' => [],'plant_index_numbers' => [],'plants_tissue_sample_names' => {},'accession_name' => 'test_accession2','accession_id' => 38841,'tissue_sample_names' => [],'tissue_sample_ids' => [],'rep_number' => '2','plot_name' => 'test_trial213','plant_names' => [],'plot_id' => 38869,'block_number' => '1','plot_number' => '13'},'9' => {'tissue_sample_ids' => [],'plants_tissue_sample_names' => {},'plant_index_numbers' => [],'tissue_sample_names' => [],'accession_id' => 38841,'accession_name' => 'test_accession2','plant_ids' => [],'tissue_sample_index_numbers' => [],'block_number' => '1','plot_id' => 38865,'plot_number' => '9','plant_names' => [],'plot_name' => 'test_trial29','rep_number' => '1'},'14' => {'plants_tissue_sample_names' => {},'plant_index_numbers' => [],'accession_id' => 38843,'tissue_sample_names' => [],'accession_name' => 'test_accession4','tissue_sample_ids' => [],'plant_ids' => [],'tissue_sample_index_numbers' => [],'plant_names' => [],'plot_name' => 'test_trial214','plot_id' => 38870,'block_number' => '1','plot_number' => '14','rep_number' => '3'},'12' => {'plant_names' => [],'plot_name' => 'test_trial212','plot_number' => '12','plot_id' => 38868,'block_number' => '1','rep_number' => '3','accession_name' => 'test_accession5','accession_id' => 38844,'tissue_sample_names' => [],'plants_tissue_sample_names' => {},'plant_index_numbers' => [],'tissue_sample_ids' => [],'tissue_sample_index_numbers' => [],'plant_ids' => []},'1' => {'rep_number' => '1','plot_name' => 'test_trial21','plant_names' => [],'plot_id' => 38857,'block_number' => '1','plot_number' => '1','plant_ids' => [],'tissue_sample_index_numbers' => [],'plants_tissue_sample_names' => {},'plant_index_numbers' => [],'accession_id' => 38843,'accession_name' => 'test_accession4','tissue_sample_names' => [],'tissue_sample_ids' => []},'7' => {'tissue_sample_index_numbers' => [],'plant_ids' => [],'tissue_sample_names' => [],'accession_name' => 'test_accession5','accession_id' => 38844,'plants_tissue_sample_names' => {},'plant_index_numbers' => [],'tissue_sample_ids' => [],'rep_number' => '2','plant_names' => [],'plot_name' => 'test_trial27','plot_number' => '7','plot_id' => 38863,'block_number' => '1'},'4' => {'block_number' => '1','plot_id' => 38860,'plot_number' => '4','plant_names' => [],'plot_name' => 'test_trial24','rep_number' => '2','tissue_sample_ids' => [],'plant_index_numbers' => [],'plants_tissue_sample_names' => {},'accession_id' => 38842,'accession_name' => 'test_accession3','tissue_sample_names' => [],'plant_ids' => [],'tissue_sample_index_numbers' => []},'11' => {'rep_number' => '3','plot_name' => 'test_trial211','plant_names' => [],'plot_number' => '11','plot_id' => 38867,'block_number' => '1','tissue_sample_index_numbers' => [],'plant_ids' => [],'tissue_sample_names' => [],'accession_name' => 'test_accession1','accession_id' => 38840,'plant_index_numbers' => [],'plants_tissue_sample_names' => {},'tissue_sample_ids' => []},'6' => {'plant_index_numbers' => [],'plants_tissue_sample_names' => {},'tissue_sample_names' => [],'accession_id' => 38843,'accession_name' => 'test_accession4','tissue_sample_ids' => [],'plant_ids' => [],'tissue_sample_index_numbers' => [],'plant_names' => [],'plot_name' => 'test_trial26','plot_id' => 38862,'block_number' => '1','plot_number' => '6','rep_number' => '2'}}}, "check layout");

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/edit_management_factor_details?description=test&schedule=test&type=Fertilizer&completions=%5B%5D&start_date=&end_date=&action=add');
$response = decode_json $mech->content;
is_deeply($response, {'success' => 1}, "get add management factor page");

$mech->post_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/replace_plot_accessions', ['old_accession' => 'test_accession3', 'new_accession' => 'test_accession1', 'old_plot_id' => '38866', 'old_plot_name' => 'test_trial210', 'new_plot_name' => "test_trial210_afterchange", 'override' => 'check']);
$response = decode_json $mech->content;
is_deeply($response, {success => 1});

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/plots');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'plots' => [[[38857,'test_trial21'],[38858,'test_trial22'],[38859,'test_trial23'],[38860,'test_trial24'],[38861,'test_trial25'],[38862,'test_trial26'],[38863,'test_trial27'],[38864,'test_trial28'],[38865,'test_trial29'],[38866,'test_trial210_afterchange'],[38867,'test_trial211'],[38868,'test_trial212'],[38869,'test_trial213'],[38870,'test_trial214'],[38871,'test_trial215']]]}, "check plots");

$mech->post_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/replace_plot_accessions', ['old_accession' => 'test_accession1', 'new_accession' => 'test_accession3', 'old_plot_id' => '38866', 'old_plot_name' => 'test_trial210_afterchange', 'new_plot_name' => "test_trial210", 'override' => 'check']);
$response = decode_json $mech->content;
is_deeply($response, {success => 1});

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$trial_id.'/get_management_regime');
$response = decode_json $mech->content;
is_deeply(decode_json $response->{data}, [
    {
        'schedule' => 'test',
        'description' => 'test',
        'completions' => [],
        'end_date' => '',
        'start_date' => '',
        'type' => 'Fertilizer',
    }
], "verify correct management regime");


#$treatment_project->delete_field_layout();
#$treatment_project->delete_project_entry();

$f->clean_up_db();

done_testing();
