
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
use CXGN::Phenotypes::PhenotypeMatrix;
use CXGN::BreederSearch;
use Spreadsheet::Read;
use CXGN::Trial::Download;
use DateTime;
use Test::WWW::Mechanize;
use JSON;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();

#######################################
#Find out table counts before adding anything, so that changes can be compared

my $phenotyping_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($f->bcs_schema, 'phenotyping_experiment', 'experiment_type')->cvterm_id();
my $experiment = $f->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search({type_id => $phenotyping_experiment_cvterm_id});
my $pre_experiment_count = $experiment->count();

my $phenotype_rs = $f->bcs_schema->resultset('Phenotype::Phenotype')->search({});
my $pre_phenotype_count = $phenotype_rs->count();

my $exp_prop_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentprop')->search({});
my $pre_exp_prop_count = $exp_prop_rs->count();

my $exp_stock_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentStock')->search({});
my $pre_exp_stock_count = $exp_stock_rs->count();

my $exp_proj_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentProject')->search({});
my $pre_exp_proj_count = $exp_proj_rs->count();

my $exp_pheno_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentPhenotype')->search({});
my $pre_exp_pheno_count = $exp_pheno_rs->count();

my $md_rs = $f->metadata_schema->resultset('MdMetadata')->search({});
my $pre_md_count = $md_rs->count();

my $md_files_rs = $f->metadata_schema->resultset('MdFiles')->search({});
my $pre_md_files_count = $md_files_rs->count();

my $exp_md_files_rs = $f->phenome_schema->resultset('NdExperimentMdFiles')->search({});
my $pre_exp_md_files_count = $exp_md_files_rs->count();


########################################
#Tests for phenotype spreadsheet parsing

my $filename = "t/data/trial/upload_phenotypin_spreadsheet.xls";
my $time = DateTime->now();
my $timestamp = $time->ymd()."_".$time->hms();

#Test archive upload file
my $uploader = CXGN::UploadFile->new({
  tempfile => $filename,
  subdirectory => 'temp_fieldbook',
  archive_path => '/tmp',
  archive_filename => 'upload_phenotypin_spreadsheet.xls',
  timestamp => $timestamp,
  user_id => 41, #janedoe in fixture
  user_role => 'curator'
});

## Store uploaded temporary file in archive
my $archived_filename_with_path = $uploader->archive();
my $md5 = $uploader->get_md5($archived_filename_with_path);
ok($archived_filename_with_path);
ok($md5);

#check that parse fails for fieldbook file when using phenotype spreadsheet parser
my $parser = CXGN::Phenotypes::ParseUpload->new();
my $filename = "t/data/fieldbook/fieldbook_phenotype_file.csv";
my $validate_file = $parser->validate('phenotype spreadsheet', $filename, 1, 'plots', $f->bcs_schema);
ok($validate_file != 1, "Check if parse validate phenotype spreadsheet fails for fieldbook");

#check that parse fails for datacollector file when using phenotype spreadsheet parser
$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/trial/data_collector_upload.xls";
$validate_file = $parser->validate('phenotype spreadsheet', $filename, 1, 'plots', $f->bcs_schema);
ok($validate_file != 1, "Check if parse validate phenotype spreadsheet fails for datacollector");

#Now parse phenotyping spreadsheet file using correct parser
$parser = CXGN::Phenotypes::ParseUpload->new();
$validate_file = $parser->validate('phenotype spreadsheet', $archived_filename_with_path, 1, 'plots', $f->bcs_schema);
ok($validate_file == 1, "Check if parse validate works for phenotype file");

my $parsed_file = $parser->parse('phenotype spreadsheet', $archived_filename_with_path, 1, 'plots', $f->bcs_schema);
ok($parsed_file, "Check if parse parse phenotype spreadsheet works");

print STDERR Dumper $parsed_file;

is_deeply($parsed_file, {'variables' => ['dry matter content|CO_334:0000092','fresh root weight|CO_334:0000012','fresh shoot weight|CO_334:0000016','harvest index|CO_334:0000015','notes'],'data' => {'test_trial23' => {'fresh shoot weight|CO_334:0000016' => ['22','2016-02-11 01:12:20-0500'],'fresh root weight|CO_334:0000012' => ['15','2016-01-15 01:12:20-0500'],'harvest index|CO_334:0000015' => ['2.8','2016-03-16 01:12:20-0500'],'dry matter content|CO_334:0000092' => ['38','2016-04-27 01:12:20-0500']},'test_trial25' => {'fresh root weight|CO_334:0000012' => ['15','2016-01-15 09:12:20-0500'],'harvest index|CO_334:0000015' => ['4.8','2016-03-16 09:12:20-0500'],'dry matter content|CO_334:0000092' => ['35','2016-04-27 09:12:20-0500'],'fresh shoot weight|CO_334:0000016' => ['24','2016-02-11 09:12:20-0500']},'test_trial24' => {'fresh shoot weight|CO_334:0000016' => ['23','2016-02-11 11:12:20-0500'],'harvest index|CO_334:0000015' => ['3.8','2016-03-16 11:12:20-0500'],'dry matter content|CO_334:0000092' => ['39','2016-04-27 11:12:20-0500'],'fresh root weight|CO_334:0000012' => ['15','2016-01-15 11:12:20-0500']},'test_trial22' => {'fresh root weight|CO_334:0000012' => ['15','2016-01-15 02:12:20-0500'],'notes' => ['testnote2',''],'harvest index|CO_334:0000015' => ['1.8','2016-03-16 02:12:20-0500'],'dry matter content|CO_334:0000092' => ['30','2016-04-27 02:12:20-0500'],'fresh shoot weight|CO_334:0000016' => ['21','2016-02-11 02:12:20-0500']},'test_trial210' => {'harvest index|CO_334:0000015' => ['9.8','2016-03-16 15:12:20-0500'],'dry matter content|CO_334:0000092' => ['30','2016-04-27 15:12:20-0500'],'fresh root weight|CO_334:0000012' => ['15','2016-01-15 15:12:20-0500'],'fresh shoot weight|CO_334:0000016' => ['29','2016-02-11 15:12:20-0500']},'test_trial26' => {'fresh shoot weight|CO_334:0000016' => ['25','2016-02-11 16:12:20-0500'],'fresh root weight|CO_334:0000012' => ['15','2016-01-15 16:12:20-0500'],'harvest index|CO_334:0000015' => ['5.8','2016-03-16 16:12:20-0500'],'dry matter content|CO_334:0000092' => ['30','2016-04-27 16:12:20-0500']},'test_trial211' => {'fresh shoot weight|CO_334:0000016' => ['30','2016-02-11 03:12:20-0500'],'harvest index|CO_334:0000015' => ['10.8','2016-03-16 03:12:20-0500'],'dry matter content|CO_334:0000092' => ['38','2016-04-27 03:12:20-0500'],'fresh root weight|CO_334:0000012' => ['15','2016-01-15 03:12:20-0500']},'test_trial29' => {'fresh root weight|CO_334:0000012' => ['15','2016-01-15 14:12:20-0500'],'harvest index|CO_334:0000015' => ['8.8','2016-03-16 14:12:20-0500'],'dry matter content|CO_334:0000092' => ['35','2016-04-27 14:12:20-0500'],'fresh shoot weight|CO_334:0000016' => ['28','2016-02-11 14:12:20-0500']},'test_trial28' => {'fresh shoot weight|CO_334:0000016' => ['27','2016-02-11 13:12:20-0500'],'fresh root weight|CO_334:0000012' => ['15','2016-01-15 13:12:20-0500'],'harvest index|CO_334:0000015' => ['7.8','2016-03-16 13:12:20-0500'],'dry matter content|CO_334:0000092' => ['39','2016-04-27 13:12:20-0500']},'test_trial27' => {'fresh shoot weight|CO_334:0000016' => ['26','2016-02-11 17:12:20-0500'],'harvest index|CO_334:0000015' => ['6.8','2016-03-16 17:12:20-0500'],'dry matter content|CO_334:0000092' => ['38','2016-04-27 17:12:20-0500'],'fresh root weight|CO_334:0000012' => ['15','2016-01-15 17:12:20-0500']},'test_trial21' => {'notes' => ['test note1',''],'fresh root weight|CO_334:0000012' => ['15','2016-01-15 12:12:20-0500'],'dry matter content|CO_334:0000092' => ['35','2016-04-27 12:12:20-0500'],'harvest index|CO_334:0000015' => ['0.8','2016-03-16 12:12:20-0500'],'fresh shoot weight|CO_334:0000016' => ['20','2016-02-11 12:12:20-0500']},'test_trial212' => {'fresh shoot weight|CO_334:0000016' => ['31','2016-02-11 21:12:20-0500'],'harvest index|CO_334:0000015' => ['11.8','2016-03-16 21:12:20-0500'],'dry matter content|CO_334:0000092' => ['39','2016-04-27 21:12:20-0500'],'fresh root weight|CO_334:0000012' => ['15','2016-01-15 21:12:20-0500']},'test_trial215' => {'fresh shoot weight|CO_334:0000016' => ['34','2016-02-11 19:12:20-0500'],'fresh root weight|CO_334:0000012' => ['15','2016-01-15 19:12:20-0500'],'dry matter content|CO_334:0000092' => ['38','2016-04-27 19:12:20-0500'],'harvest index|CO_334:0000015' => ['14.8','2016-03-16 19:12:20-0500']},'test_trial214' => {'fresh shoot weight|CO_334:0000016' => ['33','2016-02-11 23:12:20-0500'],'fresh root weight|CO_334:0000012' => ['15','2016-01-15 23:12:20-0500'],'dry matter content|CO_334:0000092' => ['30','2016-04-27 23:12:20-0500'],'harvest index|CO_334:0000015' => ['13.8','2016-03-16 23:12:20-0500']},'test_trial213' => {'harvest index|CO_334:0000015' => ['12.8','2016-03-16 22:12:20-0500'],'dry matter content|CO_334:0000092' => ['35','2016-04-27 22:12:20-0500'],'fresh root weight|CO_334:0000012' => ['15','2016-01-15 22:12:20-0500'],'fresh shoot weight|CO_334:0000016' => ['32','2016-02-11 22:12:20-0500']}},'units' => ['test_trial21','test_trial210','test_trial211','test_trial212','test_trial213','test_trial214','test_trial215','test_trial22','test_trial23','test_trial24','test_trial25','test_trial26','test_trial27','test_trial28','test_trial29']}, "Check parse phenotyping spreadsheet" );


my %phenotype_metadata;
$phenotype_metadata{'archived_file'} = $archived_filename_with_path;
$phenotype_metadata{'archived_file_type'}="spreadsheet phenotype file";
$phenotype_metadata{'operator'}="janedoe";
$phenotype_metadata{'date'}="2016-02-16_01:10:56";
my %parsed_data = %{$parsed_file->{'data'}};
my @plots = @{$parsed_file->{'units'}};
my @traits = @{$parsed_file->{'variables'}};

my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
    basepath=>$f->config->{basepath},
    dbhost=>$f->config->{dbhost},
    dbname=>$f->config->{dbname},
    dbuser=>$f->config->{dbuser},
    dbpass=>$f->config->{dbpass},
    temp_file_nd_experiment_id=>$f->config->{cluster_shared_tempdir}."/test_temp_nd_experiment_id_delete",
    bcs_schema=>$f->bcs_schema,
    metadata_schema=>$f->metadata_schema,
    phenome_schema=>$f->phenome_schema,
    user_id=>41,
    stock_list=>\@plots,
    trait_list=>\@traits,
    values_hash=>\%parsed_data,
    has_timestamps=>1,
    overwrite_values=>0,
    metadata_hash=>\%phenotype_metadata
);
my ($verified_warning, $verified_error) = $store_phenotypes->verify();
ok(!$verified_error);
my ($stored_phenotype_error_msg, $store_success) = $store_phenotypes->store();
ok(!$stored_phenotype_error_msg, "check that store pheno spreadsheet works");

my $tn = CXGN::Trial->new( { bcs_schema => $f->bcs_schema(),
				trial_id => 137 });

my $traits_assayed  = $tn->get_traits_assayed();
my @traits_assayed_sorted = sort {$a->[0] cmp $b->[0]} @$traits_assayed;
print STDERR Dumper @traits_assayed_sorted;
my @traits_assayed_check = ([70666,'fresh root weight|CO_334:0000012', [], 15,undef,undef], [70668,'harvest index variable|CO_334:0000015', [], 15,undef,undef], [70741,'dry matter content percentage|CO_334:0000092', [], 15,undef,undef], [70773,'fresh shoot weight measurement in kg|CO_334:0000016', [], 15,undef,undef]);
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


$experiment = $f->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search({type_id => $phenotyping_experiment_cvterm_id});
my $post1_experiment_count = $experiment->count();
my $post1_experiment_diff = $post1_experiment_count - $pre_experiment_count;
print STDERR "Experiment count: ".$post1_experiment_diff."\n";
ok($post1_experiment_diff == 15, "Check num rows in NdExperiment table after addition of phenotyping spreadsheet upload");

$phenotype_rs = $f->bcs_schema->resultset('Phenotype::Phenotype')->search({});
my $post1_phenotype_count = $phenotype_rs->count();
my $post1_phenotype_diff = $post1_phenotype_count - $pre_phenotype_count;
print STDERR "Phenotype count: ".$post1_phenotype_diff."\n";
ok($post1_phenotype_diff == 60, "Check num rows in Phenotype table after addition of phenotyping spreadsheet upload");

$exp_prop_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentprop')->search({});
my $post1_exp_prop_count = $exp_prop_rs->count();
my $post1_exp_prop_diff = $post1_exp_prop_count - $pre_exp_prop_count;
print STDERR "Experimentprop count: ".$post1_exp_prop_diff."\n";
ok($post1_exp_prop_diff == 30, "Check num rows in Experimentprop table after addition of phenotyping spreadsheet upload");

$exp_proj_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentProject')->search({});
my $post1_exp_proj_count = $exp_proj_rs->count();
my $post1_exp_proj_diff = $post1_exp_proj_count - $pre_exp_proj_count;
print STDERR "Experimentproject count: ".$post1_exp_proj_diff."\n";
ok($post1_exp_proj_diff == 15, "Check num rows in NdExperimentproject table after addition of phenotyping spreadsheet upload");

$exp_stock_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentStock')->search({});
my $post1_exp_stock_count = $exp_stock_rs->count();
my $post1_exp_stock_diff = $post1_exp_stock_count - $pre_exp_stock_count;
print STDERR "Experimentstock count: ".$post1_exp_stock_diff."\n";
ok($post1_exp_stock_diff == 15, "Check num rows in NdExperimentstock table after addition of phenotyping spreadsheet upload");

$exp_pheno_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentPhenotype')->search({});
my $post1_exp_pheno_count = $exp_pheno_rs->count();
my $post1_exp_pheno_diff = $post1_exp_pheno_count - $pre_exp_pheno_count;
print STDERR "Experimentphenotype count: ".$post1_exp_pheno_diff."\n";
ok($post1_exp_pheno_diff == 60, "Check num rows in NdExperimentphenotype table after addition of phenotyping spreadsheet upload");

$md_rs = $f->metadata_schema->resultset('MdMetadata')->search({});
my $post1_md_count = $md_rs->count();
my $post1_md_diff = $post1_md_count - $pre_md_count;
print STDERR "MdMetadata count: ".$post1_md_diff."\n";
ok($post1_md_diff == 1, "Check num rows in MdMetadata table after addition of phenotyping spreadsheet upload");

$md_files_rs = $f->metadata_schema->resultset('MdFiles')->search({});
my $post1_md_files_count = $md_files_rs->count();
my $post1_md_files_diff = $post1_md_files_count - $pre_md_files_count;
print STDERR "MdFiles count: ".$post1_md_files_diff."\n";
ok($post1_md_files_diff == 1, "Check num rows in MdFiles table after addition of phenotyping spreadsheet upload");

$exp_md_files_rs = $f->phenome_schema->resultset('NdExperimentMdFiles')->search({});
my $post1_exp_md_files_count = $exp_md_files_rs->count();
my $post1_exp_md_files_diff = $post1_exp_md_files_count - $pre_exp_md_files_count;
print STDERR "Experimentphenotype count: ".$post1_exp_md_files_diff."\n";
ok($post1_exp_md_files_diff == 15, "Check num rows in NdExperimentMdFIles table after addition of phenotyping spreadsheet upload");




#Check what happens on duplication of plot_name, trait, and value. timestamps must be unique or it will not be uploaded.

$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/trial/upload_phenotypin_spreadsheet_duplicate.xls";
$validate_file = $parser->validate('phenotype spreadsheet', $filename, 0, 'plots', $f->bcs_schema);
ok($validate_file == 1, "Check if parse validate works for phenotype file");

my $parsed_file = $parser->parse('phenotype spreadsheet', $filename, 0, 'plots', $f->bcs_schema);
ok($parsed_file, "Check if parse parse phenotype spreadsheet works");

my %phenotype_metadata;
$phenotype_metadata{'archived_file'} = $filename;
$phenotype_metadata{'archived_file_type'}="spreadsheet phenotype file";
$phenotype_metadata{'operator'}="janedoe";
$phenotype_metadata{'date'}="2016-02-22_01:10:56";
my %parsed_data = %{$parsed_file->{'data'}};
my @plots = @{$parsed_file->{'units'}};
my @traits = @{$parsed_file->{'variables'}};

my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
    basepath=>$f->config->{basepath},
    dbhost=>$f->config->{dbhost},
    dbname=>$f->config->{dbname},
    dbuser=>$f->config->{dbuser},
    dbpass=>$f->config->{dbpass},
    temp_file_nd_experiment_id=>$f->config->{cluster_shared_tempdir}."/test_temp_nd_experiment_id_delete",
    bcs_schema=>$f->bcs_schema,
    metadata_schema=>$f->metadata_schema,
    phenome_schema=>$f->phenome_schema,
    user_id=>41,
    stock_list=>\@plots,
    trait_list=>\@traits,
    values_hash=>\%parsed_data,
    has_timestamps=>0,
    overwrite_values=>0,
    metadata_hash=>\%phenotype_metadata
);
my ($verified_warning, $verified_error) = $store_phenotypes->verify();
#print STDERR Dumper $verified_error;
ok(!$verified_error);
my ($stored_phenotype_error_msg, $store_success) = $store_phenotypes->store();
ok(!$stored_phenotype_error_msg, "check that store pheno spreadsheet works");

my $traits_assayed  = $tn->get_traits_assayed();
my @traits_assayed_sorted = sort {$a->[0] cmp $b->[0]} @$traits_assayed;
print STDERR Dumper @traits_assayed_sorted;
my @traits_assayed_check = ([70666,'fresh root weight|CO_334:0000012', [], 30,undef,undef], [70668,'harvest index variable|CO_334:0000015', [], 30,undef,undef], [70741,'dry matter content percentage|CO_334:0000092', [], 30,undef,undef], [70773,'fresh shoot weight measurement in kg|CO_334:0000016', [], 30,undef,undef]);
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


$experiment = $f->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search({type_id => $phenotyping_experiment_cvterm_id});
my $post2_experiment_count = $experiment->count();
my $post2_experiment_diff = $post2_experiment_count - $pre_experiment_count;
print STDERR "Experiment count: ".$post2_experiment_diff."\n";
ok($post2_experiment_diff == 30, "Check num rows in NdExperiment table after second addition of phenotyping spreadsheet upload");

$phenotype_rs = $f->bcs_schema->resultset('Phenotype::Phenotype')->search({});
my $post2_phenotype_count = $phenotype_rs->count();
my $post2_phenotype_diff = $post2_phenotype_count - $pre_phenotype_count;
print STDERR "Phenotype count: ".$post2_phenotype_diff."\n";
ok($post2_phenotype_diff == 120, "Check num rows in Phenotype table after second addition of phenotyping spreadsheet upload");

$exp_prop_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentprop')->search({});
my $post2_exp_prop_count = $exp_prop_rs->count();
my $post2_exp_prop_diff = $post2_exp_prop_count - $pre_exp_prop_count;
print STDERR "Experimentprop count: ".$post2_exp_prop_diff."\n";
ok($post2_exp_prop_diff == 60, "Check num rows in Experimentprop table after second addition of phenotyping spreadsheet upload");

$exp_proj_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentProject')->search({});
my $post2_exp_proj_count = $exp_proj_rs->count();
my $post2_exp_proj_diff = $post2_exp_proj_count - $pre_exp_proj_count;
print STDERR "Experimentproject count: ".$post2_exp_proj_diff."\n";
ok($post2_exp_proj_diff == 30, "Check num rows in NdExperimentproject table after second addition of phenotyping spreadsheet upload");

$exp_stock_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentStock')->search({});
my $post2_exp_stock_count = $exp_stock_rs->count();
my $post2_exp_stock_diff = $post2_exp_stock_count - $pre_exp_stock_count;
print STDERR "Experimentstock count: ".$post2_exp_stock_diff."\n";
ok($post2_exp_stock_diff == 30, "Check num rows in NdExperimentstock table after second addition of phenotyping spreadsheet upload");

$exp_pheno_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentPhenotype')->search({});
my $post2_exp_pheno_count = $exp_pheno_rs->count();
my $post2_exp_pheno_diff = $post2_exp_pheno_count - $pre_exp_pheno_count;
print STDERR "Experimentphenotype count: ".$post2_exp_pheno_diff."\n";
ok($post2_exp_pheno_diff == 120, "Check num rows in NdExperimentphenotype table after second addition of phenotyping spreadsheet upload");

$md_rs = $f->metadata_schema->resultset('MdMetadata')->search({});
my $post2_md_count = $md_rs->count();
my $post2_md_diff = $post2_md_count - $pre_md_count;
print STDERR "MdMetadata count: ".$post2_md_diff."\n";
ok($post2_md_diff == 2, "Check num rows in MdMetadata table after second addition of phenotyping spreadsheet upload");

$md_files_rs = $f->metadata_schema->resultset('MdFiles')->search({});
my $post2_md_files_count = $md_files_rs->count();
my $post2_md_files_diff = $post2_md_files_count - $pre_md_files_count;
print STDERR "MdFiles count: ".$post2_md_files_diff."\n";
ok($post2_md_files_diff == 2, "Check num rows in MdFiles table after second addition of phenotyping spreadsheet upload");

$exp_md_files_rs = $f->phenome_schema->resultset('NdExperimentMdFiles')->search({});
my $post2_exp_md_files_count = $exp_md_files_rs->count();
my $post2_exp_md_files_diff = $post2_exp_md_files_count - $pre_exp_md_files_count;
print STDERR "Experimentphenotype count: ".$post2_exp_md_files_diff."\n";
ok($post2_exp_md_files_diff == 30, "Check num rows in NdExperimentMdFIles table after second addition of phenotyping spreadsheet upload");




#####################################
#Tests for fieldbook file parsing

#check that parse fails for spreadsheet file when using fieldbook parser
$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/trial/upload_phenotypin_spreadsheet.xls";
$validate_file = $parser->validate('field book', $filename, 1, 'plots', $f->bcs_schema);
ok($validate_file != 1, "Check if parse validate fieldbook fails for spreadsheet file");

#check that parse fails for datacollector file when using fieldbook parser
$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/trial/data_collector_upload.xls";
$validate_file = $parser->validate('field book', $filename, 1, 'plots', $f->bcs_schema);
ok($validate_file != 1, "Check if parse validate fieldbook fails for datacollector");

#Now parse fieldbook file using correct parser
$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/fieldbook/fieldbook_phenotype_file.csv";
$validate_file = $parser->validate('field book', $filename, 1, 'plots', $f->bcs_schema);
print STDERR Dumper $validate_file;
ok($validate_file == 1, "Check if parse validate works for fieldbook");

$parsed_file = $parser->parse('field book', $filename, 1, 'plots', $f->bcs_schema);
ok($parsed_file, "Check if parse parse fieldbook works");

print STDERR Dumper $parsed_file;

is_deeply($parsed_file, {'units' => ['test_trial21','test_trial210','test_trial211','test_trial212','test_trial213','test_trial214','test_trial215','test_trial22','test_trial23','test_trial24','test_trial25','test_trial26','test_trial27','test_trial28','test_trial29'],'data' => {'test_trial23' => {'dry yield|CO_334:0000014' => ['41','2016-01-07 12:08:27-0500','johndoe',''],'dry matter content|CO_334:0000092' => ['41','2016-01-07 12:08:27-0500','johndoe','']},'test_trial212' => {'dry matter content|CO_334:0000092' => ['42','2016-01-07 12:09:02-0500','johndoe',''],'dry yield|CO_334:0000014' => ['42','2016-01-07 12:09:02-0500','johndoe','']},'test_trial28' => {'dry yield|CO_334:0000014' => ['41','2016-01-07 12:08:53-0500','johndoe',''],'dry matter content|CO_334:0000092' => ['41','2016-01-07 12:08:53-0500','johndoe','']},'test_trial215' => {'dry matter content|CO_334:0000092' => ['31','2016-01-07 12:09:07-0500','johndoe',''],'dry yield|CO_334:0000014' => ['31','2016-01-07 12:09:07-0500','johndoe','']},'test_trial25' => {'dry matter content|CO_334:0000092' => ['25','2016-01-07 12:08:48-0500','johndoe',''],'dry yield|CO_334:0000014' => ['25','2016-01-07 12:08:48-0500','johndoe','']},'test_trial29' => {'dry matter content|CO_334:0000092' => ['','2016-01-07 12:08:55-0500','johndoe',''],'dry yield|CO_334:0000014' => ['24','2016-01-07 12:08:55-0500','johndoe','']},'test_trial26' => {'dry matter content|CO_334:0000092' => ['','2016-01-07 12:08:49-0500','johndoe',''],'dry yield|CO_334:0000014' => ['0','2016-01-07 12:08:49-0500','johndoe','']},'test_trial22' => {'fieldbook_image|CO_334:0010472' => ['/storage/emulated/0/fieldBook/plot_data/test_trial/photos/test_trial22_2016-09-12-11-15-26.jpg','2016-01-07 12:10:25-0500','johndoe',''],'dry yield|CO_334:0000014' => ['45','2016-01-07 12:08:26-0500','johndoe',''],'dry matter content|CO_334:0000092' => ['45','2016-01-07 12:08:26-0500','johndoe','']},'test_trial213' => {'dry matter content|CO_334:0000092' => ['35','2016-01-07 12:09:04-0500','johndoe',''],'dry yield|CO_334:0000014' => ['35','2016-01-07 12:09:04-0500','johndoe','']},'test_trial24' => {'dry yield|CO_334:0000014' => ['14','2016-01-07 12:08:46-0500','johndoe',''],'dry matter content|CO_334:0000092' => ['14','2016-01-07 12:08:46-0500','johndoe','']},'test_trial210' => {'dry yield|CO_334:0000014' => ['12','2016-01-07 12:08:56-0500','johndoe',''],'dry matter content|CO_334:0000092' => ['12','2016-01-07 12:08:56-0500','johndoe','']},'test_trial27' => {'dry matter content|CO_334:0000092' => ['52','2016-01-07 12:08:51-0500','johndoe',''],'dry yield|CO_334:0000014' => ['0','2016-01-07 12:08:51-0500','johndoe','']},'test_trial21' => {'dry yield|CO_334:0000014' => ['42','2016-01-07 12:08:24-0500','johndoe',''],'fieldbook_image|CO_334:0010472' => ['/storage/emulated/0/fieldBook/plot_data/test_trial/photos/test_trial21_2016-09-12-11-15-12.jpg','2016-01-07 12:10:24-0500','johndoe',''],'dry matter content|CO_334:0000092' => ['42','2016-01-07 12:08:24-0500','johndoe','']},'test_trial214' => {'dry yield|CO_334:0000014' => ['32','2016-01-07 12:09:05-0500','johndoe',''],'dry matter content|CO_334:0000092' => ['32','2016-01-07 12:09:05-0500','johndoe','']},'test_trial211' => {'dry matter content|CO_334:0000092' => ['13','2016-01-07 12:08:58-0500','johndoe',''],'dry yield|CO_334:0000014' => ['13','2016-01-07 12:08:58-0500','johndoe','']}},'variables' => ['dry matter content|CO_334:0000092','dry yield|CO_334:0000014','fieldbook_image|CO_334:0010472']}, "Check parse fieldbook");


$phenotype_metadata{'archived_file'} = $filename;
$phenotype_metadata{'archived_file_type'}="tablet phenotype file";
$phenotype_metadata{'operator'}="janedoe";
$phenotype_metadata{'date'}="2016-01-16_03:15:26";
%parsed_data = %{$parsed_file->{'data'}};
@plots = @{$parsed_file->{'units'}};
@traits = @{$parsed_file->{'variables'}};
my $user_id = 41;
my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
    basepath=>$f->config->{basepath},
    dbhost=>$f->config->{dbhost},
    dbname=>$f->config->{dbname},
    dbuser=>$f->config->{dbuser},
    dbpass=>$f->config->{dbpass},
    temp_file_nd_experiment_id=>$f->config->{cluster_shared_tempdir}."/test_temp_nd_experiment_id_delete",
    bcs_schema=>$f->bcs_schema,
    metadata_schema=>$f->metadata_schema,
    phenome_schema=>$f->phenome_schema,
    user_id=>41,
    stock_list=>\@plots,
    trait_list=>\@traits,
    values_hash=>\%parsed_data,
    has_timestamps=>1,
    overwrite_values=>0,
    metadata_hash=>\%phenotype_metadata,
	image_zipfile_path=>'t/data/fieldbook/photos.zip',
);
my $validate_phenotype_error_msg = $store_phenotypes->verify();
#print STDERR Dumper $validate_phenotype_error_msg;

my ($stored_phenotype_error_msg, $store_success) = $store_phenotypes->store();
ok(!$stored_phenotype_error_msg, "check that store fieldbook works");
my $image = SGN::Image->new( $f->dbh, undef, $f );
my $image_error = $image->upload_fieldbook_zipfile('t/data/fieldbook/photos.zip', $user_id);
print STDERR Dumper $image_error;
ok(!$image_error, "check no error in image upload");

$tn = CXGN::Trial->new( { bcs_schema => $f->bcs_schema(),
				trial_id => 137 });

$traits_assayed  = $tn->get_traits_assayed();
@traits_assayed_sorted = sort {$a->[0] cmp $b->[0]} @$traits_assayed;
print STDERR Dumper \@traits_assayed_sorted;
@traits_assayed_check = ([
          70666,
          'fresh root weight|CO_334:0000012', [], 30,undef,undef
        ],[
          70668,
          'harvest index variable|CO_334:0000015', [], 30,undef,undef
        ],[
          70727,
          'dry yield|CO_334:0000014', [], 15,undef,undef
        ],[
          70741,
          'dry matter content percentage|CO_334:0000092', [], 43,undef,undef
        ],[
          70773,
          'fresh shoot weight measurement in kg|CO_334:0000016', [], 30,undef,undef
        ],[
          77107,
          'fieldbook_image|CO_334:0010472', [], 2,undef,undef
        ]);
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


$experiment = $f->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search({type_id => $phenotyping_experiment_cvterm_id});
$post1_experiment_count = $experiment->count();
$post1_experiment_diff = $post1_experiment_count - $pre_experiment_count;
print STDERR "Experiment count: ".$post1_experiment_diff."\n";
ok($post1_experiment_diff == 45, "Check num rows in NdExperiment table after addition of fieldbook upload");

$phenotype_rs = $f->bcs_schema->resultset('Phenotype::Phenotype')->search({});
$post1_phenotype_count = $phenotype_rs->count();
$post1_phenotype_diff = $post1_phenotype_count - $pre_phenotype_count;
print STDERR "Phenotype count: ".$post1_phenotype_diff."\n";
ok($post1_phenotype_diff == 150, "Check num rows in Phenotype table after addition of fieldbook upload");

$exp_prop_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentprop')->search({});
$post1_exp_prop_count = $exp_prop_rs->count();
$post1_exp_prop_diff = $post1_exp_prop_count - $pre_exp_prop_count;
print STDERR "Experimentprop count: ".$post1_exp_prop_diff."\n";
ok($post1_exp_prop_diff == 90, "Check num rows in Experimentprop table after addition of fieldbook upload");

$exp_proj_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentProject')->search({});
$post1_exp_proj_count = $exp_proj_rs->count();
$post1_exp_proj_diff = $post1_exp_proj_count - $pre_exp_proj_count;
print STDERR "Experimentproject count: ".$post1_exp_proj_diff."\n";
ok($post1_exp_proj_diff == 45, "Check num rows in NdExperimentproject table after addition of fieldbook upload");

$exp_stock_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentStock')->search({});
$post1_exp_stock_count = $exp_stock_rs->count();
$post1_exp_stock_diff = $post1_exp_stock_count - $pre_exp_stock_count;
print STDERR "Experimentstock count: ".$post1_exp_stock_diff."\n";
ok($post1_exp_stock_diff == 45, "Check num rows in NdExperimentstock table after addition of fieldbook upload");

$exp_pheno_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentPhenotype')->search({});
my $post1_exp_pheno_count = $exp_pheno_rs->count();
my $post1_exp_pheno_diff = $post1_exp_pheno_count - $pre_exp_pheno_count;
print STDERR "Experimentphenotype count: ".$post1_exp_pheno_diff."\n";
ok($post1_exp_pheno_diff == 150, "Check num rows in NdExperimentphenotype table after addition of fieldbook upload");

$md_rs = $f->metadata_schema->resultset('MdMetadata')->search({});
my $post1_md_count = $md_rs->count();
my $post1_md_diff = $post1_md_count - $pre_md_count;
print STDERR "MdMetadata count: ".$post1_md_diff."\n";
ok($post1_md_diff == 5, "Check num rows in MdMetadata table after addition of fieldbook upload");

$md_files_rs = $f->metadata_schema->resultset('MdFiles')->search({});
my $post1_md_files_count = $md_files_rs->count();
my $post1_md_files_diff = $post1_md_files_count - $pre_md_files_count;
print STDERR "MdFiles count: ".$post1_md_files_diff."\n";
ok($post1_md_files_diff == 3, "Check num rows in MdFiles table after addition of fieldbook upload");

$exp_md_files_rs = $f->phenome_schema->resultset('NdExperimentMdFiles')->search({});
my $post1_exp_md_files_count = $exp_md_files_rs->count();
my $post1_exp_md_files_diff = $post1_exp_md_files_count - $pre_exp_md_files_count;
print STDERR "Experimentphenotype count: ".$post1_exp_md_files_diff."\n";
ok($post1_exp_md_files_diff == 45, "Check num rows in NdExperimentMdFIles table after addition fieldbook upload");




#####################################
#Tests for datacollector file parsing

#check that parse fails for spreadsheet file when using datacollector parser
$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/trial/upload_phenotypin_spreadsheet.xls";
$validate_file = $parser->validate('datacollector spreadsheet', $filename, 0, 'plots', $f->bcs_schema);
ok($validate_file != 1, "Check if parse validate datacollector fails for spreadsheet file");

#check that parse fails for fieldbook file when using datacollector parser
$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/fieldbook/fieldbook_phenotype_file.csv";
$validate_file = $parser->validate('datacollector spreadsheet', $filename, 0, 'plots', $f->bcs_schema);
ok($validate_file != 1, "Check if parse validate datacollector fails for fieldbook");

#Now parse datacollector file using correct parser
$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/trial/data_collector_upload.xls";
$validate_file = $parser->validate('datacollector spreadsheet', $filename, 0, 'plots', $f->bcs_schema);
ok($validate_file == 1, "Check if parse validate worksfor datacollector");

$parsed_file = $parser->parse('datacollector spreadsheet', $filename, 0, 'plots', $f->bcs_schema);
ok($parsed_file, "Check if parse parse datacollector works");

#print STDERR Dumper $parsed_file;

is_deeply($parsed_file, {
	'data' => {
	                      'test_trial22' => {
	                                          'fresh shoot weight|CO_334:0000016' => [
	                                                                               '11',
	                                                                               '',
	                                                                             ],
	                                          'fresh root weight|CO_334:0000012' => [
	                                                                              '37',
	                                                                              '',
	                                                                            ],
	                                          'dry matter content|CO_334:0000092' => [
	                                                                               '36',
	                                                                               '',
	                                                                             ],
	                                          'harvest index|CO_334:0000015' => [
	                                                                          '0.8',
	                                                                          '',
	                                                                        ]
	                                        },
	                      'test_trial214' => {
	                                           'fresh shoot weight|CO_334:0000016' => [
	                                                                                '23',
	                                                                                '',
	                                                                              ],
	                                           'dry matter content|CO_334:0000092' => [
	                                                                                '48',
	                                                                                '',
	                                                                              ],
	                                           'fresh root weight|CO_334:0000012' => [
	                                                                               '49',
	                                                                               '',
	                                                                             ],
	                                           'harvest index|CO_334:0000015' => [
	                                                                           '0.8',
	                                                                           '',
	                                                                         ]
	                                         },
	                      'test_trial24' => {
	                                          'fresh shoot weight|CO_334:0000016' => [
	                                                                               '13',
	                                                                               '',
	                                                                             ],
	                                          'dry matter content|CO_334:0000092' => [
	                                                                               '38',
	                                                                               '',
	                                                                             ],
	                                          'fresh root weight|CO_334:0000012' => [
	                                                                              '39',
	                                                                              '',
	                                                                            ],
	                                          'harvest index|CO_334:0000015' => [
	                                                                          '0',
	                                                                          '',
	                                                                        ]
	                                        },
	                      'test_trial215' => {
	                                           'fresh root weight|CO_334:0000012' => [
	                                                                               '50',
	                                                                               '',
	                                                                             ],
	                                           'dry matter content|CO_334:0000092' => [
	                                                                                '49',
	                                                                                '',
	                                                                              ],
	                                           'harvest index|CO_334:0000015' => [
	                                                                           '0.8',
	                                                                           '',
	                                                                         ],
	                                           'fresh shoot weight|CO_334:0000016' => [
	                                                                                '24',
	                                                                                '',
	                                                                              ]
	                                         },
	                      'test_trial212' => {
	                                           'dry matter content|CO_334:0000092' => [
	                                                                                '46',
	                                                                                '',
	                                                                              ],
	                                           'fresh root weight|CO_334:0000012' => [
	                                                                               '47',
	                                                                               '',
	                                                                             ],
	                                           'harvest index|CO_334:0000015' => [
	                                                                           '0.8',
	                                                                           '',
	                                                                         ],
	                                           'fresh shoot weight|CO_334:0000016' => [
	                                                                                '21',
	                                                                                '',
	                                                                              ]
	                                         },
	                      'test_trial211' => {
	                                           'harvest index|CO_334:0000015' => [
	                                                                           '0.8',
	                                                                           '',
	                                                                         ],
	                                           'dry matter content|CO_334:0000092' => [
	                                                                                '45',
	                                                                                '',
	                                                                              ],
	                                           'fresh root weight|CO_334:0000012' => [
	                                                                               '46',
	                                                                               '',
	                                                                             ],
	                                           'fresh shoot weight|CO_334:0000016' => [
	                                                                                '20',
	                                                                                '',
	                                                                              ]
	                                         },
	                      'test_trial25' => {
	                                          'dry matter content|CO_334:0000092' => [
	                                                                               '39',
	                                                                               '',
	                                                                             ],
	                                          'fresh root weight|CO_334:0000012' => [
	                                                                              '40',
	                                                                              '',
	                                                                            ],
	                                          'harvest index|CO_334:0000015' => [
	                                                                          '0.8',
	                                                                          '',
	                                                                        ],
	                                          'fresh shoot weight|CO_334:0000016' => [
	                                                                               '14',
	                                                                               '',
	                                                                             ]
	                                        },
	                      'test_trial213' => {
	                                           'fresh shoot weight|CO_334:0000016' => [
	                                                                                '22',
	                                                                                '',
	                                                                              ],
	                                           'harvest index|CO_334:0000015' => [
	                                                                           '0.8',
	                                                                           '',
	                                                                         ],
	                                           'fresh root weight|CO_334:0000012' => [
	                                                                               '48',
	                                                                               '',
	                                                                             ],
	                                           'dry matter content|CO_334:0000092' => [
	                                                                                '47',
	                                                                                '',
	                                                                              ]
	                                         },
	                      'test_trial28' => {
	                                          'fresh root weight|CO_334:0000012' => [
	                                                                              '43',
	                                                                              '',
	                                                                            ],
	                                          'dry matter content|CO_334:0000092' => [
	                                                                               '42',
	                                                                               '',
	                                                                             ],
	                                          'harvest index|CO_334:0000015' => [
	                                                                          '0.8',
	                                                                          '',
	                                                                        ],
	                                          'fresh shoot weight|CO_334:0000016' => [
	                                                                               '17',
	                                                                               '',
	                                                                             ]
	                                        },
	                      'test_trial27' => {
	                                          'fresh root weight|CO_334:0000012' => [
	                                                                              '42',
	                                                                              '',
	                                                                            ],
	                                          'dry matter content|CO_334:0000092' => [
	                                                                               '',
	                                                                               '',
	                                                                             ],
	                                          'harvest index|CO_334:0000015' => [
	                                                                          '0',
	                                                                          '',
	                                                                        ],
	                                          'fresh shoot weight|CO_334:0000016' => [
	                                                                               '16',
	                                                                               '',
	                                                                             ]
	                                        },
	                      'test_trial21' => {
	                                          'harvest index|CO_334:0000015' => [
	                                                                          '0.8',
	                                                                          '',
	                                                                        ],
	                                          'dry matter content|CO_334:0000092' => [
	                                                                               '35',
	                                                                               '',
	                                                                             ],
	                                          'fresh root weight|CO_334:0000012' => [
	                                                                              '36',
	                                                                              '',
	                                                                            ],
	                                          'fresh shoot weight|CO_334:0000016' => [
	                                                                               '10',
	                                                                               '',
	                                                                             ]
	                                        },
	                      'test_trial29' => {
	                                          'fresh shoot weight|CO_334:0000016' => [
	                                                                               '18',
	                                                                               '',
	                                                                             ],
	                                          'harvest index|CO_334:0000015' => [
	                                                                          '0.8',
	                                                                          '',
	                                                                        ],
	                                          'dry matter content|CO_334:0000092' => [
	                                                                               '43',
	                                                                               '',
	                                                                             ],
	                                          'fresh root weight|CO_334:0000012' => [
	                                                                              '',
	                                                                              '',
	                                                                            ]
	                                        },
	                      'test_trial26' => {
	                                          'fresh root weight|CO_334:0000012' => [
	                                                                              '41',
	                                                                              '',
	                                                                            ],
	                                          'dry matter content|CO_334:0000092' => [
	                                                                               '',
	                                                                               '',
	                                                                             ],
	                                          'harvest index|CO_334:0000015' => [
	                                                                          '0.8',
	                                                                          '',
	                                                                        ],
	                                          'fresh shoot weight|CO_334:0000016' => [
	                                                                               '15',
	                                                                               '',
	                                                                             ]
	                                        },
	                      'test_trial210' => {
	                                           'harvest index|CO_334:0000015' => [
	                                                                           '0.8',
	                                                                           '',
	                                                                         ],
	                                           'fresh root weight|CO_334:0000012' => [
	                                                                               '45',
	                                                                               '',
	                                                                             ],
	                                           'dry matter content|CO_334:0000092' => [
	                                                                                '44',
	                                                                                '',
	                                                                              ],
	                                           'fresh shoot weight|CO_334:0000016' => [
	                                                                                '19',
	                                                                                '',
	                                                                              ]
	                                         },
	                      'test_trial23' => {
	                                          'harvest index|CO_334:0000015' => [
	                                                                          '0.8',
	                                                                          '',
	                                                                        ],
	                                          'dry matter content|CO_334:0000092' => [
	                                                                               '37',
	                                                                               '',
	                                                                             ],
	                                          'fresh root weight|CO_334:0000012' => [
	                                                                              '38',
	                                                                              '',
	                                                                            ],
	                                          'fresh shoot weight|CO_334:0000016' => [
	                                                                               '12',
	                                                                               '',
	                                                                             ]
	                                        }
	                    },
	          'variables' => [
	                        'dry matter content|CO_334:0000092',
	                        'fresh root weight|CO_334:0000012',
	                        'fresh shoot weight|CO_334:0000016',
	                        'harvest index|CO_334:0000015'
	                      ],
	          'units' => [
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
@plots = @{$parsed_file->{'units'}};
@traits = @{$parsed_file->{'variables'}};

my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
    basepath=>$f->config->{basepath},
    dbhost=>$f->config->{dbhost},
    dbname=>$f->config->{dbname},
    dbuser=>$f->config->{dbuser},
    dbpass=>$f->config->{dbpass},
    temp_file_nd_experiment_id=>$f->config->{cluster_shared_tempdir}."/test_temp_nd_experiment_id_delete",
    bcs_schema=>$f->bcs_schema,
    metadata_schema=>$f->metadata_schema,
    phenome_schema=>$f->phenome_schema,
    user_id=>41,
    stock_list=>\@plots,
    trait_list=>\@traits,
    values_hash=>\%parsed_data,
    has_timestamps=>0,
    overwrite_values=>0,
    metadata_hash=>\%phenotype_metadata,
);
my ($verified_warning, $verified_error) = $store_phenotypes->verify();
print STDERR Dumper $verified_error;
ok(!$verified_error);
my ($stored_phenotype_error_msg, $store_success) = $store_phenotypes->store();
ok(!$stored_phenotype_error_msg, "check that store fieldbook works");

$tn = CXGN::Trial->new( { bcs_schema => $f->bcs_schema(),
				trial_id => 137 });

$traits_assayed  = $tn->get_traits_assayed();
@traits_assayed_sorted = sort {$a->[0] cmp $b->[0]} @$traits_assayed;
print STDERR Dumper \@traits_assayed_sorted;
@traits_assayed_check = ([
          70666,
          'fresh root weight|CO_334:0000012', [], 44,undef,undef
        ],[
          70668,
          'harvest index variable|CO_334:0000015', [], 45,undef,undef
        ],[
          70727,
          'dry yield|CO_334:0000014', [], 15,undef,undef
        ],[
          70741,
          'dry matter content percentage|CO_334:0000092', [], 56,undef,undef
        ],[
          70773,
          'fresh shoot weight measurement in kg|CO_334:0000016', [], 45,undef,undef
        ],[
          77107,
          'fieldbook_image|CO_334:0010472', [], 2,undef,undef
        ]);
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


$experiment = $f->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search({type_id => $phenotyping_experiment_cvterm_id});
$post1_experiment_count = $experiment->count();
$post1_experiment_diff = $post1_experiment_count - $pre_experiment_count;
print STDERR "Experiment count: ".$post1_experiment_diff."\n";
ok($post1_experiment_diff == 60, "Check num rows in NdExperiment table after addition of datacollector upload");

$phenotype_rs = $f->bcs_schema->resultset('Phenotype::Phenotype')->search({});
$post1_phenotype_count = $phenotype_rs->count();
$post1_phenotype_diff = $post1_phenotype_count - $pre_phenotype_count;
print STDERR "Phenotype count: ".$post1_phenotype_diff."\n";
ok($post1_phenotype_diff == 207, "Check num rows in Phenotype table after addition of datacollector upload");

$exp_prop_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentprop')->search({});
$post1_exp_prop_count = $exp_prop_rs->count();
$post1_exp_prop_diff = $post1_exp_prop_count - $pre_exp_prop_count;
print STDERR "Experimentprop count: ".$post1_exp_prop_diff."\n";
ok($post1_exp_prop_diff == 120, "Check num rows in Experimentprop table after addition of datacollector upload");

$exp_proj_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentProject')->search({});
$post1_exp_proj_count = $exp_proj_rs->count();
$post1_exp_proj_diff = $post1_exp_proj_count - $pre_exp_proj_count;
print STDERR "Experimentproject count: ".$post1_exp_proj_diff."\n";
ok($post1_exp_proj_diff == 60, "Check num rows in NdExperimentproject table after addition of datacollector upload");

$exp_stock_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentStock')->search({});
$post1_exp_stock_count = $exp_stock_rs->count();
$post1_exp_stock_diff = $post1_exp_stock_count - $pre_exp_stock_count;
print STDERR "Experimentstock count: ".$post1_exp_stock_diff."\n";
ok($post1_exp_stock_diff == 60, "Check num rows in NdExperimentstock table after addition of datacollector upload");

$exp_pheno_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentPhenotype')->search({});
my $post1_exp_pheno_count = $exp_pheno_rs->count();
my $post1_exp_pheno_diff = $post1_exp_pheno_count - $pre_exp_pheno_count;
print STDERR "Experimentphenotype count: ".$post1_exp_pheno_diff."\n";
ok($post1_exp_pheno_diff == 207, "Check num rows in NdExperimentphenotype table after addition of datacollector upload");

$md_rs = $f->metadata_schema->resultset('MdMetadata')->search({});
my $post1_md_count = $md_rs->count();
my $post1_md_diff = $post1_md_count - $pre_md_count;
print STDERR "MdMetadata count: ".$post1_md_diff."\n";
ok($post1_md_diff == 6, "Check num rows in MdMetadata table after addition of datacollector upload");

$md_files_rs = $f->metadata_schema->resultset('MdFiles')->search({});
my $post1_md_files_count = $md_files_rs->count();
my $post1_md_files_diff = $post1_md_files_count - $pre_md_files_count;
print STDERR "MdFiles count: ".$post1_md_files_diff."\n";
ok($post1_md_files_diff == 4, "Check num rows in MdFiles table after addition of datacollector upload");

$exp_md_files_rs = $f->phenome_schema->resultset('NdExperimentMdFiles')->search({});
my $post1_exp_md_files_count = $exp_md_files_rs->count();
my $post1_exp_md_files_diff = $post1_exp_md_files_count - $pre_exp_md_files_count;
print STDERR "Experimentphenotype count: ".$post1_exp_md_files_diff."\n";
ok($post1_exp_md_files_diff == 60, "Check num rows in NdExperimentMdFIles table after addition datacollector upload");



#Upload a large phenotyping spreadsheet (>100 entries)


$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/trial/upload_phenotypin_spreadsheet_large.xls";
$validate_file = $parser->validate('phenotype spreadsheet', $filename, 0, 'plots', $f->bcs_schema);
ok($validate_file == 1, "Check if parse validate works for large phenotype file");

$parsed_file = $parser->parse('phenotype spreadsheet', $filename, 0, 'plots', $f->bcs_schema);
ok($parsed_file, "Check if parse parse phenotype spreadsheet works");

print STDERR Dumper $parsed_file;

is_deeply($parsed_file, {
          'data' => {
                      'test_trial24' => {
                                          'flower|CO_334:0000111' => [
                                                                       '1',
                                                                       ''
                                                                     ],
                                          'fresh shoot weight|CO_334:0000016' => [
                                                                                   '23',
                                                                                   ''
                                                                                 ],
                                          'sprouting|CO_334:0000008' => [
                                                                          '78',
                                                                          ''
                                                                        ],
                                          'harvest index|CO_334:0000015' => [
                                                                              '3.8',
                                                                              ''
                                                                            ],
                                          'top yield|CO_334:0000017' => [
                                                                          '7',
                                                                          ''
                                                                        ],
                                          'fresh root weight|CO_334:0000012' => [
                                                                                  '15',
                                                                                  ''
                                                                                ],
                                          'root number|CO_334:0000011' => [
                                                                            '11',
                                                                            ''
                                                                          ],
                                          'dry matter content|CO_334:0000092' => [
                                                                                   '39',
                                                                                   ''
                                                                                 ]
                                        },
                      'test_trial21' => {
                                          'harvest index|CO_334:0000015' => [
                                                                              '0.8',
                                                                              ''
                                                                            ],
                                          'sprouting|CO_334:0000008' => [
                                                                          '45',
                                                                          ''
                                                                        ],
                                          'top yield|CO_334:0000017' => [
                                                                          '2',
                                                                          ''
                                                                        ],
                                          'fresh root weight|CO_334:0000012' => [
                                                                                  '15',
                                                                                  ''
                                                                                ],
                                          'dry matter content|CO_334:0000092' => [
                                                                                   '35',
                                                                                   ''
                                                                                 ],
                                          'root number|CO_334:0000011' => [
                                                                            '3',
                                                                            ''
                                                                          ],
                                          'fresh shoot weight|CO_334:0000016' => [
                                                                                   '20',
                                                                                   ''
                                                                                 ],
                                          'flower|CO_334:0000111' => [
                                                                       '0',
                                                                       ''
                                                                     ]
                                        },
                      'test_trial213' => {
                                           'flower|CO_334:0000111' => [
                                                                        '1',
                                                                        ''
                                                                      ],
                                           'fresh shoot weight|CO_334:0000016' => [
                                                                                    '32',
                                                                                    ''
                                                                                  ],
                                           'sprouting|CO_334:0000008' => [
                                                                           '8',
                                                                           ''
                                                                         ],
                                           'harvest index|CO_334:0000015' => [
                                                                               '12.8',
                                                                               ''
                                                                             ],
                                           'root number|CO_334:0000011' => [
                                                                             '8',
                                                                             ''
                                                                           ],
                                           'dry matter content|CO_334:0000092' => [
                                                                                    '35',
                                                                                    ''
                                                                                  ],
                                           'top yield|CO_334:0000017' => [
                                                                           '4.4',
                                                                           ''
                                                                         ],
                                           'fresh root weight|CO_334:0000012' => [
                                                                                   '15',
                                                                                   ''
                                                                                 ]
                                         },
                      'test_trial23' => {
                                          'fresh shoot weight|CO_334:0000016' => [
                                                                                   '22',
                                                                                   ''
                                                                                 ],
                                          'flower|CO_334:0000111' => [
                                                                       '1',
                                                                       ''
                                                                     ],
                                          'sprouting|CO_334:0000008' => [
                                                                          '23',
                                                                          ''
                                                                        ],
                                          'harvest index|CO_334:0000015' => [
                                                                              '2.8',
                                                                              ''
                                                                            ],
                                          'top yield|CO_334:0000017' => [
                                                                          '5',
                                                                          ''
                                                                        ],
                                          'fresh root weight|CO_334:0000012' => [
                                                                                  '15',
                                                                                  ''
                                                                                ],
                                          'root number|CO_334:0000011' => [
                                                                            '4',
                                                                            ''
                                                                          ],
                                          'dry matter content|CO_334:0000092' => [
                                                                                   '38',
                                                                                   ''
                                                                                 ]
                                        },
                      'test_trial26' => {
                                          'fresh shoot weight|CO_334:0000016' => [
                                                                                   '25',
                                                                                   ''
                                                                                 ],
                                          'flower|CO_334:0000111' => [
                                                                       '1',
                                                                       ''
                                                                     ],
                                          'sprouting|CO_334:0000008' => [
                                                                          '45',
                                                                          ''
                                                                        ],
                                          'harvest index|CO_334:0000015' => [
                                                                              '5.8',
                                                                              ''
                                                                            ],
                                          'top yield|CO_334:0000017' => [
                                                                          '4',
                                                                          ''
                                                                        ],
                                          'fresh root weight|CO_334:0000012' => [
                                                                                  '15',
                                                                                  ''
                                                                                ],
                                          'root number|CO_334:0000011' => [
                                                                            '4',
                                                                            ''
                                                                          ],
                                          'dry matter content|CO_334:0000092' => [
                                                                                   '30',
                                                                                   ''
                                                                                 ]
                                        },
                      'test_trial25' => {
                                          'fresh shoot weight|CO_334:0000016' => [
                                                                                   '24',
                                                                                   ''
                                                                                 ],
                                          'flower|CO_334:0000111' => [
                                                                       '1',
                                                                       ''
                                                                     ],
                                          'dry matter content|CO_334:0000092' => [
                                                                                   '35',
                                                                                   ''
                                                                                 ],
                                          'root number|CO_334:0000011' => [
                                                                            '6',
                                                                            ''
                                                                          ],
                                          'top yield|CO_334:0000017' => [
                                                                          '2',
                                                                          ''
                                                                        ],
                                          'fresh root weight|CO_334:0000012' => [
                                                                                  '15',
                                                                                  ''
                                                                                ],
                                          'harvest index|CO_334:0000015' => [
                                                                              '',
                                                                              ''
                                                                            ],
                                          'sprouting|CO_334:0000008' => [
                                                                          '56',
                                                                          ''
                                                                        ]
                                        },
                      'test_trial215' => {
                                           'flower|CO_334:0000111' => [
                                                                        '1',
                                                                        ''
                                                                      ],
                                           'fresh shoot weight|CO_334:0000016' => [
                                                                                    '34',
                                                                                    ''
                                                                                  ],
                                           'sprouting|CO_334:0000008' => [
                                                                           '25',
                                                                           ''
                                                                         ],
                                           'harvest index|CO_334:0000015' => [
                                                                               '14.8',
                                                                               ''
                                                                             ],
                                           'fresh root weight|CO_334:0000012' => [
                                                                                   '15',
                                                                                   ''
                                                                                 ],
                                           'top yield|CO_334:0000017' => [
                                                                           '7',
                                                                           ''
                                                                         ],
                                           'root number|CO_334:0000011' => [
                                                                             '5',
                                                                             ''
                                                                           ],
                                           'dry matter content|CO_334:0000092' => [
                                                                                    '38',
                                                                                    ''
                                                                                  ]
                                         },
                      'test_trial28' => {
                                          'flower|CO_334:0000111' => [
                                                                       '0',
                                                                       ''
                                                                     ],
                                          'fresh shoot weight|CO_334:0000016' => [
                                                                                   '27',
                                                                                   ''
                                                                                 ],
                                          'root number|CO_334:0000011' => [
                                                                            '9',
                                                                            ''
                                                                          ],
                                          'dry matter content|CO_334:0000092' => [
                                                                                   '39',
                                                                                   ''
                                                                                 ],
                                          'top yield|CO_334:0000017' => [
                                                                          '6',
                                                                          ''
                                                                        ],
                                          'fresh root weight|CO_334:0000012' => [
                                                                                  '15',
                                                                                  ''
                                                                                ],
                                          'sprouting|CO_334:0000008' => [
                                                                          '23',
                                                                          ''
                                                                        ],
                                          'harvest index|CO_334:0000015' => [
                                                                              '7.8',
                                                                              ''
                                                                            ]
                                        },
                      'test_trial29' => {
                                          'fresh shoot weight|CO_334:0000016' => [
                                                                                   '28',
                                                                                   ''
                                                                                 ],
                                          'flower|CO_334:0000111' => [
                                                                       '1',
                                                                       ''
                                                                     ],
                                          'root number|CO_334:0000011' => [
                                                                            '6',
                                                                            ''
                                                                          ],
                                          'dry matter content|CO_334:0000092' => [
                                                                                   '35',
                                                                                   ''
                                                                                 ],
                                          'top yield|CO_334:0000017' => [
                                                                          '3',
                                                                          ''
                                                                        ],
                                          'fresh root weight|CO_334:0000012' => [
                                                                                  '15',
                                                                                  ''
                                                                                ],
                                          'sprouting|CO_334:0000008' => [
                                                                          '76',
                                                                          ''
                                                                        ],
                                          'harvest index|CO_334:0000015' => [
                                                                              '8.8',
                                                                              ''
                                                                            ]
                                        },
                      'test_trial27' => {
                                          'fresh shoot weight|CO_334:0000016' => [
                                                                                   '26',
                                                                                   ''
                                                                                 ],
                                          'flower|CO_334:0000111' => [
                                                                       '1',
                                                                       ''
                                                                     ],
                                          'harvest index|CO_334:0000015' => [
                                                                              '6.8',
                                                                              ''
                                                                            ],
                                          'sprouting|CO_334:0000008' => [
                                                                          '34',
                                                                          ''
                                                                        ],
                                          'fresh root weight|CO_334:0000012' => [
                                                                                  '15',
                                                                                  ''
                                                                                ],
                                          'top yield|CO_334:0000017' => [
                                                                          '9',
                                                                          ''
                                                                        ],
                                          'dry matter content|CO_334:0000092' => [
                                                                                   '38',
                                                                                   ''
                                                                                 ],
                                          'root number|CO_334:0000011' => [
                                                                            '8',
                                                                            ''
                                                                          ]
                                        },
                      'test_trial210' => {
                                           'root number|CO_334:0000011' => [
                                                                             '',
                                                                             ''
                                                                           ],
                                           'dry matter content|CO_334:0000092' => [
                                                                                    '30',
                                                                                    ''
                                                                                  ],
                                           'fresh root weight|CO_334:0000012' => [
                                                                                   '15',
                                                                                   ''
                                                                                 ],
                                           'top yield|CO_334:0000017' => [
                                                                           '2',
                                                                           ''
                                                                         ],
                                           'sprouting|CO_334:0000008' => [
                                                                           '45',
                                                                           ''
                                                                         ],
                                           'harvest index|CO_334:0000015' => [
                                                                               '9.8',
                                                                               ''
                                                                             ],
                                           'fresh shoot weight|CO_334:0000016' => [
                                                                                    '29',
                                                                                    ''
                                                                                  ],
                                           'flower|CO_334:0000111' => [
                                                                        '0',
                                                                        ''
                                                                      ]
                                         },
                      'test_trial214' => {
                                           'top yield|CO_334:0000017' => [
                                                                           '7.5',
                                                                           ''
                                                                         ],
                                           'fresh root weight|CO_334:0000012' => [
                                                                                   '15',
                                                                                   ''
                                                                                 ],
                                           'root number|CO_334:0000011' => [
                                                                             '4',
                                                                             ''
                                                                           ],
                                           'dry matter content|CO_334:0000092' => [
                                                                                    '30',
                                                                                    ''
                                                                                  ],
                                           'sprouting|CO_334:0000008' => [
                                                                           '87',
                                                                           ''
                                                                         ],
                                           'harvest index|CO_334:0000015' => [
                                                                               '13.8',
                                                                               ''
                                                                             ],
                                           'flower|CO_334:0000111' => [
                                                                        '1',
                                                                        ''
                                                                      ],
                                           'fresh shoot weight|CO_334:0000016' => [
                                                                                    '33',
                                                                                    ''
                                                                                  ]
                                         },
                      'test_trial22' => {
                                          'fresh shoot weight|CO_334:0000016' => [
                                                                                   '21',
                                                                                   ''
                                                                                 ],
                                          'flower|CO_334:0000111' => [
                                                                       '1',
                                                                       ''
                                                                     ],
                                          'sprouting|CO_334:0000008' => [
                                                                          '43',
                                                                          ''
                                                                        ],
                                          'harvest index|CO_334:0000015' => [
                                                                              '1.8',
                                                                              ''
                                                                            ],
                                          'top yield|CO_334:0000017' => [
                                                                          '3',
                                                                          ''
                                                                        ],
                                          'fresh root weight|CO_334:0000012' => [
                                                                                  '15',
                                                                                  ''
                                                                                ],
                                          'root number|CO_334:0000011' => [
                                                                            '7',
                                                                            ''
                                                                          ],
                                          'dry matter content|CO_334:0000092' => [
                                                                                   '30',
                                                                                   ''
                                                                                 ]
                                        },
                      'test_trial212' => {
                                           'flower|CO_334:0000111' => [
                                                                        '0',
                                                                        ''
                                                                      ],
                                           'fresh shoot weight|CO_334:0000016' => [
                                                                                    '31',
                                                                                    ''
                                                                                  ],
                                           'top yield|CO_334:0000017' => [
                                                                           '7',
                                                                           ''
                                                                         ],
                                           'fresh root weight|CO_334:0000012' => [
                                                                                   '15',
                                                                                   ''
                                                                                 ],
                                           'dry matter content|CO_334:0000092' => [
                                                                                    '39',
                                                                                    ''
                                                                                  ],
                                           'root number|CO_334:0000011' => [
                                                                             '6',
                                                                             ''
                                                                           ],
                                           'harvest index|CO_334:0000015' => [
                                                                               '11.8',
                                                                               ''
                                                                             ],
                                           'sprouting|CO_334:0000008' => [
                                                                           '56',
                                                                           ''
                                                                         ]
                                         },
                      'test_trial211' => {
                                           'flower|CO_334:0000111' => [
                                                                        '0',
                                                                        ''
                                                                      ],
                                           'fresh shoot weight|CO_334:0000016' => [
                                                                                    '30',
                                                                                    ''
                                                                                  ],
                                           'harvest index|CO_334:0000015' => [
                                                                               '10.8',
                                                                               ''
                                                                             ],
                                           'sprouting|CO_334:0000008' => [
                                                                           '2',
                                                                           ''
                                                                         ],
                                           'dry matter content|CO_334:0000092' => [
                                                                                    '38',
                                                                                    ''
                                                                                  ],
                                           'root number|CO_334:0000011' => [
                                                                             '4',
                                                                             ''
                                                                           ],
                                           'fresh root weight|CO_334:0000012' => [
                                                                                   '15',
                                                                                   ''
                                                                                 ],
                                           'top yield|CO_334:0000017' => [
                                                                           '4',
                                                                           ''
                                                                         ]
                                         }
                    },
          'units' => [
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
          'variables' => [
                        'dry matter content|CO_334:0000092',
                        'flower|CO_334:0000111',
                        'fresh root weight|CO_334:0000012',
                        'fresh shoot weight|CO_334:0000016',
                        'harvest index|CO_334:0000015',
                        'root number|CO_334:0000011',
                        'sprouting|CO_334:0000008',
                        'top yield|CO_334:0000017'
                      ]
        }, "Check parse large phenotyping spreadsheet" );


$phenotype_metadata{'archived_file'} = $filename;
$phenotype_metadata{'archived_file_type'}="spreadsheet phenotype file";
$phenotype_metadata{'operator'}="janedoe";
$phenotype_metadata{'date'}="2016-02-16_05:55:55";
%parsed_data = %{$parsed_file->{'data'}};
@plots = @{$parsed_file->{'units'}};
@traits = @{$parsed_file->{'variables'}};

my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
    basepath=>$f->config->{basepath},
    dbhost=>$f->config->{dbhost},
    dbname=>$f->config->{dbname},
    dbuser=>$f->config->{dbuser},
    dbpass=>$f->config->{dbpass},
    temp_file_nd_experiment_id=>$f->config->{cluster_shared_tempdir}."/test_temp_nd_experiment_id_delete",
    bcs_schema=>$f->bcs_schema,
    metadata_schema=>$f->metadata_schema,
    phenome_schema=>$f->phenome_schema,
    user_id=>41,
    stock_list=>\@plots,
    trait_list=>\@traits,
    values_hash=>\%parsed_data,
    has_timestamps=>0,
    overwrite_values=>0,
    metadata_hash=>\%phenotype_metadata,
);
my ($verified_warning, $verified_error) = $store_phenotypes->verify();
ok(!$verified_error);
my ($stored_phenotype_error_msg, $store_success) = $store_phenotypes->store();
ok(!$stored_phenotype_error_msg, "check that store large pheno spreadsheet works");

$tn = CXGN::Trial->new( { bcs_schema => $f->bcs_schema(),
				trial_id => 137 });

$traits_assayed  = $tn->get_traits_assayed();
@traits_assayed_sorted = sort {$a->[0] cmp $b->[0]} @$traits_assayed;
print STDERR Dumper \@traits_assayed_sorted;
@traits_assayed_check = ([
          70666,
          'fresh root weight|CO_334:0000012', [], 59,undef,undef
        ],[
          70668,
          'harvest index variable|CO_334:0000015', [], 59,undef,undef
        ],[
          70681,
          'top yield|CO_334:0000017', [], 15,undef,undef
        ],[
          70700,
          'sprouting proportion|CO_334:0000008', [], 15,undef,undef
        ],[
          70706,
          'root number counting|CO_334:0000011', [], 14,undef,undef
        ],[
          70713,
          'flower|CO_334:0000111', [], 15,undef,undef
        ],[
          70727,
          'dry yield|CO_334:0000014', [], 15,undef,undef
        ],[
          70741,
          'dry matter content percentage|CO_334:0000092', [], 71,undef,undef
        ],[
          70773,
          'fresh shoot weight measurement in kg|CO_334:0000016', [], 60,undef,undef
        ],[
           77107,
           'fieldbook_image|CO_334:0010472', [], 2,undef,undef
         ]);
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



$experiment = $f->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search({type_id => $phenotyping_experiment_cvterm_id}, {order_by => {-asc => 'nd_experiment_id'}});
$post1_experiment_count = $experiment->count();
$post1_experiment_diff = $post1_experiment_count - $pre_experiment_count;
print STDERR "Experiment count: ".$post1_experiment_diff."\n";
ok($post1_experiment_diff == 75, "Check num rows in NdExperiment table after addition of large phenotyping spreadsheet upload");

my @nd_experiment_table;
my $nd_experiment_table_tail = $experiment->slice($post1_experiment_count-323, $post1_experiment_count);
while (my $rs = $nd_experiment_table_tail->next() ) {
      push @nd_experiment_table, [nd_experiment_id=> $rs->nd_experiment_id(), nd_geolocation_id=> $rs->nd_geolocation_id(), type_id=> $rs->type_id()];
}
#print STDERR Dumper \@nd_experiment_table;

$phenotype_rs = $f->bcs_schema->resultset('Phenotype::Phenotype')->search({});
$post1_phenotype_count = $phenotype_rs->count();
$post1_phenotype_diff = $post1_phenotype_count - $pre_phenotype_count;
print STDERR "Phenotype count: ".$post1_phenotype_diff."\n";
ok($post1_phenotype_diff == 325, "Check num rows in Phenotype table after addition of large phenotyping spreadsheet upload");

my @pheno_table;
my $pheno_table_tail = $phenotype_rs->slice($post1_phenotype_count-323, $post1_phenotype_count);
while (my $rs = $pheno_table_tail->next() ) {
      push @pheno_table, [phenotype_id=> $rs->phenotype_id(), observable_id=> $rs->observable_id(), attr_id=> $rs->attr_id(), value=> $rs->value(), cvalue_id=>$rs->cvalue_id(), assay_id=>$rs->assay_id()];
}
#print STDERR Dumper \@pheno_table;

$exp_prop_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentprop')->search({});
$post1_exp_prop_count = $exp_prop_rs->count();
$post1_exp_prop_diff = $post1_exp_prop_count - $pre_exp_prop_count;
print STDERR "Experimentprop count: ".$post1_exp_prop_diff."\n";
ok($post1_exp_prop_diff == 150, "Check num rows in Experimentprop table after addition of large phenotyping spreadsheet upload");

my @exp_prop_table;
my $exp_prop_table_tail = $exp_prop_rs->slice($post1_exp_prop_count-646, $post1_exp_prop_count);
while (my $rs = $exp_prop_table_tail->next() ) {
      push @exp_prop_table, [nd_experimentprop_id=> $rs->nd_experimentprop_id(), nd_experiment_id=> $rs->nd_experiment_id(), type_id=> $rs->type_id(), value=> $rs->value(), rank=> $rs->rank()];
}
#print STDERR Dumper \@exp_prop_table;

$exp_proj_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentProject')->search({});
$post1_exp_proj_count = $exp_proj_rs->count();
$post1_exp_proj_diff = $post1_exp_proj_count - $pre_exp_proj_count;
print STDERR "Experimentproject count: ".$post1_exp_proj_diff."\n";
ok($post1_exp_proj_diff == 75, "Check num rows in NdExperimentproject table after addition of large phenotyping spreadsheet upload");

my @exp_proj_table;
my $exp_proj_table_tail = $exp_proj_rs->slice($post1_exp_proj_count-323, $post1_exp_proj_count);
while (my $rs = $exp_proj_table_tail->next() ) {
      push @exp_proj_table, [nd_experiment_project_id=> $rs->nd_experiment_project_id(), nd_experiment_id=> $rs->nd_experiment_id(), project_id=> $rs->project_id()];
}
#print STDERR Dumper \@exp_proj_table;

$exp_stock_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentStock')->search({});
$post1_exp_stock_count = $exp_stock_rs->count();
$post1_exp_stock_diff = $post1_exp_stock_count - $pre_exp_stock_count;
print STDERR "Experimentstock count: ".$post1_exp_stock_diff."\n";
ok($post1_exp_stock_diff == 75, "Check num rows in NdExperimentstock table after addition of large phenotyping spreadsheet upload");

my @exp_stock_table;
my $exp_stock_table_tail = $exp_stock_rs->slice($post1_exp_stock_count-323, $post1_exp_stock_count);
while (my $rs = $exp_stock_table_tail->next() ) {
      push @exp_stock_table, [nd_experiment_stock_id=> $rs->nd_experiment_stock_id(), nd_experiment_id=> $rs->nd_experiment_id(), stock_id=> $rs->stock_id(), type_id=> $rs->type_id()];
}
#print STDERR Dumper \@exp_stock_table;

$exp_pheno_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentPhenotype')->search({});
$post1_exp_pheno_count = $exp_pheno_rs->count();
$post1_exp_pheno_diff = $post1_exp_pheno_count - $pre_exp_pheno_count;
print STDERR "Experimentphenotype count: ".$post1_exp_pheno_diff."\n";
ok($post1_exp_pheno_diff == 325, "Check num rows in NdExperimentphenotype table after addition of large phenotyping spreadsheet upload");

my @exp_pheno_table;
my $exp_pheno_table_tail = $exp_pheno_rs->slice($post1_exp_pheno_count-323, $post1_exp_pheno_count);
while (my $rs = $exp_pheno_table_tail->next() ) {
      push @exp_pheno_table, [nd_experiment_phenotype_id=> $rs->nd_experiment_phenotype_id(), nd_experiment_id=> $rs->nd_experiment_id(), phenotype_id=> $rs->phenotype_id()];
}
#print STDERR Dumper \@exp_pheno_table;

$md_rs = $f->metadata_schema->resultset('MdMetadata')->search({});
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

$md_files_rs = $f->metadata_schema->resultset('MdFiles')->search({});
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

$exp_md_files_rs = $f->phenome_schema->resultset('NdExperimentMdFiles')->search({});
$post1_exp_md_files_count = $exp_md_files_rs->count();
$post1_exp_md_files_diff = $post1_exp_md_files_count - $pre_exp_md_files_count;
print STDERR "Experimentphenotype count: ".$post1_exp_md_files_diff."\n";
ok($post1_exp_md_files_diff == 75, "Check num rows in NdExperimentMdFIles table after addition of large phenotyping spreadsheet upload");

my @exp_md_files_table;
my $exp_md_files_table_tail = $exp_md_files_rs->slice($post1_exp_md_files_count-324, $post1_exp_md_files_count-1);
while (my $rs = $exp_md_files_table_tail->next() ) {
      push @exp_md_files_table, [nd_experiment_md_files_id => $rs->nd_experiment_md_files_id(), nd_experiment_id=> $rs->nd_experiment_id(), file_id=> $rs->file_id()];
}
#print STDERR Dumper \@exp_md_files_table;

#For running this test in series with all other tests or alone.. AddPlants.t does this step earlier if tests done in series...
my $nd_experiment_stock_number;
if (!$tn->has_plant_entries) {
	$tn->create_plant_entities(2);
	$nd_experiment_stock_number = 135;
} else {
	$nd_experiment_stock_number = 105;
}

#check that parse fails for plant spreadsheet file when using plot parser
$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/trial/upload_phenotypin_spreadsheet_plants.xls";
$validate_file = $parser->validate('phenotype spreadsheet', $filename, 0, 'plots', $f->bcs_schema);
ok($validate_file != 1, "Check if parse validate plot fails for plant spreadsheet file");

$validate_file = $parser->validate('phenotype spreadsheet', $filename, 0, 'plants', $f->bcs_schema);
ok($validate_file == 1, "Check if parse validate works for plant spreadsheet file");

$parsed_file = $parser->parse('phenotype spreadsheet', $filename, 0, 'plants', $f->bcs_schema);
ok($parsed_file, "Check if parse parse phenotype plant spreadsheet works");

print STDERR Dumper $parsed_file;

is_deeply($parsed_file, {
          'variables' => [
                        'dry matter content percentage|CO_334:0000092',
                        'fresh root weight|CO_334:0000012'
                      ],
          'units' => [
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
                      'test_trial211_plant_1' => {
                                                   'fresh root weight|CO_334:0000012' => [
                                                                                           '40',
                                                                                           ''
                                                                                         ],
                                                   'dry matter content percentage|CO_334:0000092' => [
                                                                                                       '30',
                                                                                                       ''
                                                                                                     ]
                                                 },
                      'test_trial21_plant_1' => {
                                                  'dry matter content percentage|CO_334:0000092' => [
                                                                                                      '10',
                                                                                                      ''
                                                                                                    ],
                                                  'fresh root weight|CO_334:0000012' => [
                                                                                          '20',
                                                                                          ''
                                                                                        ]
                                                },
                      'test_trial25_plant_1' => {
                                                  'dry matter content percentage|CO_334:0000092' => [
                                                                                                      '18',
                                                                                                      ''
                                                                                                    ],
                                                  'fresh root weight|CO_334:0000012' => [
                                                                                          '28',
                                                                                          ''
                                                                                        ]
                                                },
                      'test_trial22_plant_2' => {
                                                  'dry matter content percentage|CO_334:0000092' => [
                                                                                                      '13',
                                                                                                      ''
                                                                                                    ],
                                                  'fresh root weight|CO_334:0000012' => [
                                                                                          '23',
                                                                                          ''
                                                                                        ]
                                                },
                      'test_trial29_plant_1' => {
                                                  'fresh root weight|CO_334:0000012' => [
                                                                                          '36',
                                                                                          ''
                                                                                        ],
                                                  'dry matter content percentage|CO_334:0000092' => [
                                                                                                      '26',
                                                                                                      ''
                                                                                                    ]
                                                },
                      'test_trial21_plant_2' => {
                                                  'dry matter content percentage|CO_334:0000092' => [
                                                                                                      '11',
                                                                                                      ''
                                                                                                    ],
                                                  'fresh root weight|CO_334:0000012' => [
                                                                                          '21',
                                                                                          ''
                                                                                        ]
                                                },
                      'test_trial27_plant_2' => {
                                                  'fresh root weight|CO_334:0000012' => [
                                                                                          '33',
                                                                                          ''
                                                                                        ],
                                                  'dry matter content percentage|CO_334:0000092' => [
                                                                                                      '23',
                                                                                                      ''
                                                                                                    ]
                                                },
                      'test_trial215_plant_2' => {
                                                   'fresh root weight|CO_334:0000012' => [
                                                                                           '49',
                                                                                           ''
                                                                                         ],
                                                   'dry matter content percentage|CO_334:0000092' => [
                                                                                                       '39',
                                                                                                       ''
                                                                                                     ]
                                                 },
                      'test_trial212_plant_2' => {
                                                   'dry matter content percentage|CO_334:0000092' => [
                                                                                                       '33',
                                                                                                       ''
                                                                                                     ],
                                                   'fresh root weight|CO_334:0000012' => [
                                                                                           '43',
                                                                                           ''
                                                                                         ]
                                                 },
                      'test_trial210_plant_1' => {
                                                   'fresh root weight|CO_334:0000012' => [
                                                                                           '38',
                                                                                           ''
                                                                                         ],
                                                   'dry matter content percentage|CO_334:0000092' => [
                                                                                                       '28',
                                                                                                       ''
                                                                                                     ]
                                                 },
                      'test_trial213_plant_1' => {
                                                   'fresh root weight|CO_334:0000012' => [
                                                                                           '44',
                                                                                           ''
                                                                                         ],
                                                   'dry matter content percentage|CO_334:0000092' => [
                                                                                                       '34',
                                                                                                       ''
                                                                                                     ]
                                                 },
                      'test_trial213_plant_2' => {
                                                   'fresh root weight|CO_334:0000012' => [
                                                                                           '45',
                                                                                           ''
                                                                                         ],
                                                   'dry matter content percentage|CO_334:0000092' => [
                                                                                                       '35',
                                                                                                       ''
                                                                                                     ]
                                                 },
                      'test_trial27_plant_1' => {
                                                  'fresh root weight|CO_334:0000012' => [
                                                                                          '32',
                                                                                          ''
                                                                                        ],
                                                  'dry matter content percentage|CO_334:0000092' => [
                                                                                                      '22',
                                                                                                      ''
                                                                                                    ]
                                                },
                      'test_trial23_plant_2' => {
                                                  'fresh root weight|CO_334:0000012' => [
                                                                                          '25',
                                                                                          ''
                                                                                        ],
                                                  'dry matter content percentage|CO_334:0000092' => [
                                                                                                      '15',
                                                                                                      ''
                                                                                                    ]
                                                },
                      'test_trial28_plant_1' => {
                                                  'fresh root weight|CO_334:0000012' => [
                                                                                          '34',
                                                                                          ''
                                                                                        ],
                                                  'dry matter content percentage|CO_334:0000092' => [
                                                                                                      '0',
                                                                                                      ''
                                                                                                    ]
                                                },
                      'test_trial214_plant_1' => {
                                                   'dry matter content percentage|CO_334:0000092' => [
                                                                                                       '36',
                                                                                                       ''
                                                                                                     ],
                                                   'fresh root weight|CO_334:0000012' => [
                                                                                           '46',
                                                                                           ''
                                                                                         ]
                                                 },
                      'test_trial215_plant_1' => {
                                                   'dry matter content percentage|CO_334:0000092' => [
                                                                                                       '38',
                                                                                                       ''
                                                                                                     ],
                                                   'fresh root weight|CO_334:0000012' => [
                                                                                           '48',
                                                                                           ''
                                                                                         ]
                                                 },
                      'test_trial212_plant_1' => {
                                                   'dry matter content percentage|CO_334:0000092' => [
                                                                                                       '32',
                                                                                                       ''
                                                                                                     ],
                                                   'fresh root weight|CO_334:0000012' => [
                                                                                           '42',
                                                                                           ''
                                                                                         ]
                                                 },
                      'test_trial29_plant_2' => {
                                                  'dry matter content percentage|CO_334:0000092' => [
                                                                                                      '27',
                                                                                                      ''
                                                                                                    ],
                                                  'fresh root weight|CO_334:0000012' => [
                                                                                          '37',
                                                                                          ''
                                                                                        ]
                                                },
                      'test_trial211_plant_2' => {
                                                   'dry matter content percentage|CO_334:0000092' => [
                                                                                                       '31',
                                                                                                       ''
                                                                                                     ],
                                                   'fresh root weight|CO_334:0000012' => [
                                                                                           '41',
                                                                                           ''
                                                                                         ]
                                                 },
                      'test_trial25_plant_2' => {
                                                  'dry matter content percentage|CO_334:0000092' => [
                                                                                                      '',
                                                                                                      ''
                                                                                                    ],
                                                  'fresh root weight|CO_334:0000012' => [
                                                                                          '29',
                                                                                          ''
                                                                                        ]
                                                },
                      'test_trial24_plant_2' => {
                                                  'dry matter content percentage|CO_334:0000092' => [
                                                                                                      '17',
                                                                                                      ''
                                                                                                    ],
                                                  'fresh root weight|CO_334:0000012' => [
                                                                                          '27',
                                                                                          ''
                                                                                        ]
                                                },
                      'test_trial26_plant_1' => {
                                                  'fresh root weight|CO_334:0000012' => [
                                                                                          '30',
                                                                                          ''
                                                                                        ],
                                                  'dry matter content percentage|CO_334:0000092' => [
                                                                                                      '20',
                                                                                                      ''
                                                                                                    ]
                                                },
                      'test_trial210_plant_2' => {
                                                   'fresh root weight|CO_334:0000012' => [
                                                                                           '',
                                                                                           ''
                                                                                         ],
                                                   'dry matter content percentage|CO_334:0000092' => [
                                                                                                       '29',
                                                                                                       ''
                                                                                                     ]
                                                 },
                      'test_trial26_plant_2' => {
                                                  'dry matter content percentage|CO_334:0000092' => [
                                                                                                      '21',
                                                                                                      ''
                                                                                                    ],
                                                  'fresh root weight|CO_334:0000012' => [
                                                                                          '0',
                                                                                          ''
                                                                                        ]
                                                },
                      'test_trial28_plant_2' => {
                                                  'fresh root weight|CO_334:0000012' => [
                                                                                          '35',
                                                                                          ''
                                                                                        ],
                                                  'dry matter content percentage|CO_334:0000092' => [
                                                                                                      '25',
                                                                                                      ''
                                                                                                    ]
                                                },
                      'test_trial23_plant_1' => {
                                                  'dry matter content percentage|CO_334:0000092' => [
                                                                                                      '14',
                                                                                                      ''
                                                                                                    ],
                                                  'fresh root weight|CO_334:0000012' => [
                                                                                          '24',
                                                                                          ''
                                                                                        ]
                                                },
                      'test_trial214_plant_2' => {
                                                   'fresh root weight|CO_334:0000012' => [
                                                                                           '47',
                                                                                           ''
                                                                                         ],
                                                   'dry matter content percentage|CO_334:0000092' => [
                                                                                                       '37',
                                                                                                       ''
                                                                                                     ]
                                                 },
                      'test_trial22_plant_1' => {
                                                  'dry matter content percentage|CO_334:0000092' => [
                                                                                                      '12',
                                                                                                      ''
                                                                                                    ],
                                                  'fresh root weight|CO_334:0000012' => [
                                                                                          '22',
                                                                                          ''
                                                                                        ]
                                                },
                      'test_trial24_plant_1' => {
                                                  'dry matter content percentage|CO_334:0000092' => [
                                                                                                      '16',
                                                                                                      ''
                                                                                                    ],
                                                  'fresh root weight|CO_334:0000012' => [
                                                                                          '26',
                                                                                          ''
                                                                                        ]
                                                }
                    }
        }, "check plant spreadsheet file was parsed");

$phenotype_metadata{'archived_file'} = $filename;
$phenotype_metadata{'archived_file_type'}="spreadsheet phenotype file";
$phenotype_metadata{'operator'}="janedoe";
$phenotype_metadata{'date'}="2016-02-16_05:15:21";
%parsed_data = %{$parsed_file->{'data'}};
@plots = @{$parsed_file->{'units'}};
@traits = @{$parsed_file->{'variables'}};

my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
    basepath=>$f->config->{basepath},
    dbhost=>$f->config->{dbhost},
    dbname=>$f->config->{dbname},
    dbuser=>$f->config->{dbuser},
    dbpass=>$f->config->{dbpass},
    temp_file_nd_experiment_id=>$f->config->{cluster_shared_tempdir}."/test_temp_nd_experiment_id_delete",
    bcs_schema=>$f->bcs_schema,
    metadata_schema=>$f->metadata_schema,
    phenome_schema=>$f->phenome_schema,
    user_id=>41,
    stock_list=>\@plots,
    trait_list=>\@traits,
    values_hash=>\%parsed_data,
    has_timestamps=>0,
    overwrite_values=>0,
    metadata_hash=>\%phenotype_metadata,
);
my ($verified_warning, $verified_error) = $store_phenotypes->verify();
ok(!$verified_error);
my ($stored_phenotype_error_msg, $store_success) = $store_phenotypes->store();
ok(!$stored_phenotype_error_msg, "check that store large pheno spreadsheet works");

$tn = CXGN::Trial->new( { bcs_schema => $f->bcs_schema(),
	trial_id => 137 });

$traits_assayed  = $tn->get_traits_assayed();
@traits_assayed_sorted = sort {$a->[0] cmp $b->[0]} @$traits_assayed;
print STDERR Dumper \@traits_assayed_sorted;
is_deeply(\@traits_assayed_sorted, [[
            70666,
            'fresh root weight|CO_334:0000012', [], 88,undef,undef
          ],
          [
            70668,
            'harvest index variable|CO_334:0000015', [], 59,undef,undef
          ],
          [
            70681,
            'top yield|CO_334:0000017', [], 15,undef,undef
          ],
          [
            70700,
            'sprouting proportion|CO_334:0000008', [], 15,undef,undef
          ],
          [
            70706,
            'root number counting|CO_334:0000011', [], 14,undef,undef
          ],
          [
            70713,
            'flower|CO_334:0000111', [], 15,undef,undef
          ],
          [
            70727,
            'dry yield|CO_334:0000014', [], 15,undef,undef
          ],
          [
            70741,
            'dry matter content percentage|CO_334:0000092', [], 100,undef,undef
          ],
          [
            70773,
            'fresh shoot weight measurement in kg|CO_334:0000016', [], 60,undef,undef
          ],
          [
            77107,
            'fieldbook_image|CO_334:0010472', [], 2,undef,undef
          ]], 'check traits assayed after plant upload' );

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


$experiment = $f->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search({type_id => $phenotyping_experiment_cvterm_id}, {order_by => {-asc => 'nd_experiment_id'}});
$post1_experiment_count = $experiment->count();
$post1_experiment_diff = $post1_experiment_count - $pre_experiment_count;
print STDERR "Experiment count: ".$post1_experiment_diff."\n";
ok($post1_experiment_diff == 105, "Check num rows in NdExperiment table after addition of large phenotyping spreadsheet upload");

my @nd_experiment_table;
my $nd_experiment_table_tail = $experiment->slice($post1_experiment_count-323, $post1_experiment_count);
while (my $rs = $nd_experiment_table_tail->next() ) {
  push @nd_experiment_table, [nd_experiment_id=> $rs->nd_experiment_id(), nd_geolocation_id=> $rs->nd_geolocation_id(), type_id=> $rs->type_id()];
}
#print STDERR Dumper \@nd_experiment_table;

$phenotype_rs = $f->bcs_schema->resultset('Phenotype::Phenotype')->search({});
$post1_phenotype_count = $phenotype_rs->count();
$post1_phenotype_diff = $post1_phenotype_count - $pre_phenotype_count;
print STDERR "Phenotype count: ".$post1_phenotype_diff."\n";
ok($post1_phenotype_diff == 383, "Check num rows in Phenotype table after addition of large phenotyping spreadsheet upload");

my @pheno_table;
my $pheno_table_tail = $phenotype_rs->slice($post1_phenotype_count-323, $post1_phenotype_count);
while (my $rs = $pheno_table_tail->next() ) {
  push @pheno_table, [phenotype_id=> $rs->phenotype_id(), observable_id=> $rs->observable_id(), attr_id=> $rs->attr_id(), value=> $rs->value(), cvalue_id=>$rs->cvalue_id(), assay_id=>$rs->assay_id()];
}
#print STDERR Dumper \@pheno_table;

$exp_prop_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentprop')->search({});
$post1_exp_prop_count = $exp_prop_rs->count();
$post1_exp_prop_diff = $post1_exp_prop_count - $pre_exp_prop_count;
print STDERR "Experimentprop count: ".$post1_exp_prop_diff."\n";
ok($post1_exp_prop_diff == 210, "Check num rows in Experimentprop table after addition of large phenotyping spreadsheet upload");

my @exp_prop_table;
my $exp_prop_table_tail = $exp_prop_rs->slice($post1_exp_prop_count-646, $post1_exp_prop_count);
while (my $rs = $exp_prop_table_tail->next() ) {
  push @exp_prop_table, [nd_experimentprop_id=> $rs->nd_experimentprop_id(), nd_experiment_id=> $rs->nd_experiment_id(), type_id=> $rs->type_id(), value=> $rs->value(), rank=> $rs->rank()];
}
#print STDERR Dumper \@exp_prop_table;

$exp_proj_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentProject')->search({});
$post1_exp_proj_count = $exp_proj_rs->count();
$post1_exp_proj_diff = $post1_exp_proj_count - $pre_exp_proj_count;
print STDERR "Experimentproject count: ".$post1_exp_proj_diff."\n";
ok($post1_exp_proj_diff == 105, "Check num rows in NdExperimentproject table after addition of large phenotyping spreadsheet upload");

my @exp_proj_table;
my $exp_proj_table_tail = $exp_proj_rs->slice($post1_exp_proj_count-323, $post1_exp_proj_count);
while (my $rs = $exp_proj_table_tail->next() ) {
  push @exp_proj_table, [nd_experiment_project_id=> $rs->nd_experiment_project_id(), nd_experiment_id=> $rs->nd_experiment_id(), project_id=> $rs->project_id()];
}
#print STDERR Dumper \@exp_proj_table;

$exp_stock_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentStock')->search({});
$post1_exp_stock_count = $exp_stock_rs->count();
$post1_exp_stock_diff = $post1_exp_stock_count - $pre_exp_stock_count;
print STDERR "Experimentstock count: ".$post1_exp_stock_diff."\n";
ok($post1_exp_stock_diff == $nd_experiment_stock_number, "Check num rows in NdExperimentstock table after addition of large phenotyping spreadsheet upload");

my @exp_stock_table;
my $exp_stock_table_tail = $exp_stock_rs->slice($post1_exp_stock_count-323, $post1_exp_stock_count);
while (my $rs = $exp_stock_table_tail->next() ) {
  push @exp_stock_table, [nd_experiment_stock_id=> $rs->nd_experiment_stock_id(), nd_experiment_id=> $rs->nd_experiment_id(), stock_id=> $rs->stock_id(), type_id=> $rs->type_id()];
}
#print STDERR Dumper \@exp_stock_table;

$exp_pheno_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentPhenotype')->search({});
$post1_exp_pheno_count = $exp_pheno_rs->count();
$post1_exp_pheno_diff = $post1_exp_pheno_count - $pre_exp_pheno_count;
print STDERR "Experimentphenotype count: ".$post1_exp_pheno_diff."\n";
ok($post1_exp_pheno_diff == 383, "Check num rows in NdExperimentphenotype table after addition of large phenotyping spreadsheet upload");

my @exp_pheno_table;
my $exp_pheno_table_tail = $exp_pheno_rs->slice($post1_exp_pheno_count-323, $post1_exp_pheno_count);
while (my $rs = $exp_pheno_table_tail->next() ) {
  push @exp_pheno_table, [nd_experiment_phenotype_id=> $rs->nd_experiment_phenotype_id(), nd_experiment_id=> $rs->nd_experiment_id(), phenotype_id=> $rs->phenotype_id()];
}
#print STDERR Dumper \@exp_pheno_table;

$md_rs = $f->metadata_schema->resultset('MdMetadata')->search({});
$post1_md_count = $md_rs->count();
$post1_md_diff = $post1_md_count - $pre_md_count;
print STDERR "MdMetadata count: ".$post1_md_diff."\n";
ok($post1_md_diff == 8, "Check num rows in MdMetadata table after addition of phenotyping spreadsheet upload");

my @md_table;
my $md_table_tail = $md_rs->slice($post1_md_count-5, $post1_md_count);
while (my $rs = $md_table_tail->next() ) {
  push @md_table, [metadata_id => $rs->metadata_id(), create_person_id=> $rs->create_person_id()];
}
#print STDERR Dumper \@md_table;

$md_files_rs = $f->metadata_schema->resultset('MdFiles')->search({});
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

$exp_md_files_rs = $f->phenome_schema->resultset('NdExperimentMdFiles')->search({});
$post1_exp_md_files_count = $exp_md_files_rs->count();
$post1_exp_md_files_diff = $post1_exp_md_files_count - $pre_exp_md_files_count;
print STDERR "Experimentphenotype count: ".$post1_exp_md_files_diff."\n";
ok($post1_exp_md_files_diff == 105, "Check num rows in NdExperimentMdFIles table after addition of large phenotyping spreadsheet upload");

my @exp_md_files_table;
my $exp_md_files_table_tail = $exp_md_files_rs->slice($post1_exp_md_files_count-324, $post1_exp_md_files_count-1);
while (my $rs = $exp_md_files_table_tail->next() ) {
  push @exp_md_files_table, [nd_experiment_md_files_id => $rs->nd_experiment_md_files_id(), nd_experiment_id=> $rs->nd_experiment_id(), file_id=> $rs->file_id()];
}
#print STDERR Dumper \@exp_md_files_table;



$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/fieldbook/fieldbook_phenotype_plants_file.csv";

$validate_file = $parser->validate('field book', $filename, 1, 'plants', $f->bcs_schema);
ok($validate_file == 1, "Check if parse validate works for plant fieldbook file");

$parsed_file = $parser->parse('field book', $filename, 1, 'plots', $f->bcs_schema);
ok($parsed_file, "Check if parse parse phenotype plant fieldbook works");

print STDERR Dumper $parsed_file;

is_deeply($parsed_file, {'variables' => ['dry matter content|CO_334:0000092','dry yield|CO_334:0000014'],'data' => {'test_trial21_plant_2' => {'dry matter content|CO_334:0000092' => ['42','2016-01-07 12:08:24-0500','johndoe',''],'dry yield|CO_334:0000014' => ['0','2016-01-07 12:08:24-0500','johndoe','']},'test_trial23_plant_1' => {'dry matter content|CO_334:0000092' => ['41','2016-01-07 12:08:27-0500','johndoe','']},'test_trial21_plant_1' => {'dry yield|CO_334:0000014' => ['42','2016-01-07 12:08:24-0500','johndoe',''],'dry matter content|CO_334:0000092' => ['42','2016-01-07 12:08:24-0500','johndoe','']},'test_trial22_plant_1' => {'dry matter content|CO_334:0000092' => ['45','2016-01-07 12:08:26-0500','johndoe',''],'dry yield|CO_334:0000014' => ['45','2016-01-07 12:08:26-0500','johndoe','']},'test_trial22_plant_2' => {'dry yield|CO_334:0000014' => ['0','2016-01-07 12:08:26-0500','johndoe',''],'dry matter content|CO_334:0000092' => ['45','2016-01-07 12:08:26-0500','johndoe','']},'test_trial23_plant_2' => {'dry matter content|CO_334:0000092' => ['41','2016-01-07 12:08:27-0500','johndoe','']}},'units' => ['test_trial21_plant_1','test_trial21_plant_2','test_trial22_plant_1','test_trial22_plant_2','test_trial23_plant_1','test_trial23_plant_2']}, "check parse fieldbook plant file");

$phenotype_metadata{'archived_file'} = $filename;
$phenotype_metadata{'archived_file_type'}="tablet phenotype file";
$phenotype_metadata{'operator'}="janedoe";
$phenotype_metadata{'date'}="2016-02-16_05:55:17";
%parsed_data = %{$parsed_file->{'data'}};
@plots = @{$parsed_file->{'units'}};
@traits = @{$parsed_file->{'variables'}};

my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
    basepath=>$f->config->{basepath},
    dbhost=>$f->config->{dbhost},
    dbname=>$f->config->{dbname},
    dbuser=>$f->config->{dbuser},
    dbpass=>$f->config->{dbpass},
    temp_file_nd_experiment_id=>$f->config->{cluster_shared_tempdir}."/test_temp_nd_experiment_id_delete",
    bcs_schema=>$f->bcs_schema,
    metadata_schema=>$f->metadata_schema,
    phenome_schema=>$f->phenome_schema,
    user_id=>41,
    stock_list=>\@plots,
    trait_list=>\@traits,
    values_hash=>\%parsed_data,
    has_timestamps=>1,
    overwrite_values=>0,
    metadata_hash=>\%phenotype_metadata,
);
my ($verified_warning, $verified_error) = $store_phenotypes->verify();
ok(!$verified_error);
my ($stored_phenotype_error_msg, $store_success) = $store_phenotypes->store();
ok(!$stored_phenotype_error_msg, "check that store fieldbook plants works");

$tn = CXGN::Trial->new( { bcs_schema => $f->bcs_schema(),
	trial_id => 137 });

$traits_assayed  = $tn->get_traits_assayed();
@traits_assayed_sorted = sort {$a->[0] cmp $b->[0]} @$traits_assayed;
print STDERR Dumper \@traits_assayed_sorted;
is_deeply(\@traits_assayed_sorted, [
          [
            70666,
            'fresh root weight|CO_334:0000012', [], 88,undef,undef
          ],
          [
            70668,
            'harvest index variable|CO_334:0000015', [], 59,undef,undef
          ],
          [
            70681,
            'top yield|CO_334:0000017', [], 15,undef,undef
          ],
          [
            70700,
            'sprouting proportion|CO_334:0000008', [], 15,undef,undef
          ],
          [
            70706,
            'root number counting|CO_334:0000011', [], 14,undef,undef
          ],
          [
            70713,
            'flower|CO_334:0000111', [], 15,undef,undef
          ],
          [
            70727,
            'dry yield|CO_334:0000014', [], 19,undef,undef
          ],
          [
            70741,
            'dry matter content percentage|CO_334:0000092', [], 106,undef,undef
          ],
          [
            70773,
            'fresh shoot weight measurement in kg|CO_334:0000016', [], 60,undef,undef
          ],
          [
            77107,
            'fieldbook_image|CO_334:0010472', [], 2,undef,undef
          ]
        ], 'check traits assayed after plant upload' );


my $files_uploaded = $tn->get_phenotype_metadata();
my %file_names;
foreach (@$files_uploaded){
	$file_names{$_->[4]} = [$_->[4], $_->[6]];
}
#print STDERR Dumper \%file_names;
my $found_timestamp_name;
foreach (keys %file_names){
	if (index($_, '_upload_phenotypin_spreadsheet.xls') != -1) {
		$found_timestamp_name = 1;
		delete($file_names{$_});
	}
}
ok($found_timestamp_name);
is_deeply(\%file_names, {
          'fieldbook_phenotype_file.csv' => [
                                              'fieldbook_phenotype_file.csv',
                                              'tablet phenotype file'
                                            ],
          'upload_phenotypin_spreadsheet_large.xls' => [
                                                         'upload_phenotypin_spreadsheet_large.xls',
                                                         'spreadsheet phenotype file'
                                                       ],
          'upload_phenotypin_spreadsheet_plants.xls' => [
                                                          'upload_phenotypin_spreadsheet_plants.xls',
                                                          'spreadsheet phenotype file'
                                                        ],
          'data_collector_upload.xls' => [
                                           'data_collector_upload.xls',
                                           'tablet phenotype file'
                                         ],
          'fieldbook_phenotype_plants_file.csv' => [
                                                     'fieldbook_phenotype_plants_file.csv',
                                                     'tablet phenotype file'
                                                   ],
          'upload_phenotypin_spreadsheet_duplicate.xls' => [
                                                             'upload_phenotypin_spreadsheet_duplicate.xls',
                                                             'spreadsheet phenotype file'
                                                           ]
        }, "uploaded file metadata");

$experiment = $f->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search({type_id => $phenotyping_experiment_cvterm_id}, {order_by => {-asc => 'nd_experiment_id'}});
$post1_experiment_count = $experiment->count();
$post1_experiment_diff = $post1_experiment_count - $pre_experiment_count;
print STDERR "Experiment count: ".$post1_experiment_diff."\n";
ok($post1_experiment_diff == 111, "Check num rows in NdExperiment table after addition of large phenotyping spreadsheet upload");

my @nd_experiment_table;
my $nd_experiment_table_tail = $experiment->slice($post1_experiment_count-323, $post1_experiment_count);
while (my $rs = $nd_experiment_table_tail->next() ) {
  push @nd_experiment_table, [nd_experiment_id=> $rs->nd_experiment_id(), nd_geolocation_id=> $rs->nd_geolocation_id(), type_id=> $rs->type_id()];
}
#print STDERR Dumper \@nd_experiment_table;

$phenotype_rs = $f->bcs_schema->resultset('Phenotype::Phenotype')->search({});
$post1_phenotype_count = $phenotype_rs->count();
$post1_phenotype_diff = $post1_phenotype_count - $pre_phenotype_count;
print STDERR "Phenotype count: ".$post1_phenotype_diff."\n";
ok($post1_phenotype_diff == 393, "Check num rows in Phenotype table after addition of large phenotyping spreadsheet upload");

my @pheno_table;
my $pheno_table_tail = $phenotype_rs->slice($post1_phenotype_count-323, $post1_phenotype_count);
while (my $rs = $pheno_table_tail->next() ) {
  push @pheno_table, [phenotype_id=> $rs->phenotype_id(), observable_id=> $rs->observable_id(), attr_id=> $rs->attr_id(), value=> $rs->value(), cvalue_id=>$rs->cvalue_id(), assay_id=>$rs->assay_id()];
}
#print STDERR Dumper \@pheno_table;

$exp_prop_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentprop')->search({});
$post1_exp_prop_count = $exp_prop_rs->count();
$post1_exp_prop_diff = $post1_exp_prop_count - $pre_exp_prop_count;
print STDERR "Experimentprop count: ".$post1_exp_prop_diff."\n";
ok($post1_exp_prop_diff == 222, "Check num rows in Experimentprop table after addition of large phenotyping spreadsheet upload");

my @exp_prop_table;
my $exp_prop_table_tail = $exp_prop_rs->slice($post1_exp_prop_count-646, $post1_exp_prop_count);
while (my $rs = $exp_prop_table_tail->next() ) {
  push @exp_prop_table, [nd_experimentprop_id=> $rs->nd_experimentprop_id(), nd_experiment_id=> $rs->nd_experiment_id(), type_id=> $rs->type_id(), value=> $rs->value(), rank=> $rs->rank()];
}
#print STDERR Dumper \@exp_prop_table;

$exp_proj_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentProject')->search({});
$post1_exp_proj_count = $exp_proj_rs->count();
$post1_exp_proj_diff = $post1_exp_proj_count - $pre_exp_proj_count;
print STDERR "Experimentproject count: ".$post1_exp_proj_diff."\n";
ok($post1_exp_proj_diff == 111, "Check num rows in NdExperimentproject table after addition of large phenotyping spreadsheet upload");

my @exp_proj_table;
my $exp_proj_table_tail = $exp_proj_rs->slice($post1_exp_proj_count-323, $post1_exp_proj_count);
while (my $rs = $exp_proj_table_tail->next() ) {
  push @exp_proj_table, [nd_experiment_project_id=> $rs->nd_experiment_project_id(), nd_experiment_id=> $rs->nd_experiment_id(), project_id=> $rs->project_id()];
}
#print STDERR Dumper \@exp_proj_table;

$exp_stock_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentStock')->search({});
$post1_exp_stock_count = $exp_stock_rs->count();
$post1_exp_stock_diff = $post1_exp_stock_count - $pre_exp_stock_count;
print STDERR "Experimentstock count: ".$post1_exp_stock_diff."\n";
ok($post1_exp_stock_diff == $nd_experiment_stock_number+6, "Check num rows in NdExperimentstock table after addition of large phenotyping spreadsheet upload");

my @exp_stock_table;
my $exp_stock_table_tail = $exp_stock_rs->slice($post1_exp_stock_count-323, $post1_exp_stock_count);
while (my $rs = $exp_stock_table_tail->next() ) {
  push @exp_stock_table, [nd_experiment_stock_id=> $rs->nd_experiment_stock_id(), nd_experiment_id=> $rs->nd_experiment_id(), stock_id=> $rs->stock_id(), type_id=> $rs->type_id()];
}
#print STDERR Dumper \@exp_stock_table;

$exp_pheno_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentPhenotype')->search({});
$post1_exp_pheno_count = $exp_pheno_rs->count();
$post1_exp_pheno_diff = $post1_exp_pheno_count - $pre_exp_pheno_count;
print STDERR "Experimentphenotype count: ".$post1_exp_pheno_diff."\n";
ok($post1_exp_pheno_diff == 393, "Check num rows in NdExperimentphenotype table after addition of large phenotyping spreadsheet upload");

my @exp_pheno_table;
my $exp_pheno_table_tail = $exp_pheno_rs->slice($post1_exp_pheno_count-323, $post1_exp_pheno_count);
while (my $rs = $exp_pheno_table_tail->next() ) {
  push @exp_pheno_table, [nd_experiment_phenotype_id=> $rs->nd_experiment_phenotype_id(), nd_experiment_id=> $rs->nd_experiment_id(), phenotype_id=> $rs->phenotype_id()];
}
#print STDERR Dumper \@exp_pheno_table;

$md_rs = $f->metadata_schema->resultset('MdMetadata')->search({});
$post1_md_count = $md_rs->count();
$post1_md_diff = $post1_md_count - $pre_md_count;
print STDERR "MdMetadata count: ".$post1_md_diff."\n";
ok($post1_md_diff == 9, "Check num rows in MdMetadata table after addition of phenotyping spreadsheet upload");

my @md_table;
my $md_table_tail = $md_rs->slice($post1_md_count-5, $post1_md_count);
while (my $rs = $md_table_tail->next() ) {
  push @md_table, [metadata_id => $rs->metadata_id(), create_person_id=> $rs->create_person_id()];
}
#print STDERR Dumper \@md_table;

$md_files_rs = $f->metadata_schema->resultset('MdFiles')->search({});
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

$exp_md_files_rs = $f->phenome_schema->resultset('NdExperimentMdFiles')->search({});
$post1_exp_md_files_count = $exp_md_files_rs->count();
$post1_exp_md_files_diff = $post1_exp_md_files_count - $pre_exp_md_files_count;
print STDERR "Experimentphenotype count: ".$post1_exp_md_files_diff."\n";
ok($post1_exp_md_files_diff == 111, "Check num rows in NdExperimentMdFIles table after addition of large phenotyping spreadsheet upload");

my @exp_md_files_table;
my $exp_md_files_table_tail = $exp_md_files_rs->slice($post1_exp_md_files_count-324, $post1_exp_md_files_count-1);
while (my $rs = $exp_md_files_table_tail->next() ) {
  push @exp_md_files_table, [nd_experiment_md_files_id => $rs->nd_experiment_md_files_id(), nd_experiment_id=> $rs->nd_experiment_id(), file_id=> $rs->file_id()];
}
#print STDERR Dumper \@exp_md_files_table;

my @plots = (
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
);

my @accession_ids;
my @accessions = ('test_accession4', 'test_accession1', 'test_accession3');
foreach (@accessions) {
	my $stock_id = $f->bcs_schema->resultset('Stock::Stock')->find({uniquename=>$_})->stock_id();
	push @accession_ids, $stock_id;
}

my @plot_ids;
foreach my $plot (@plots) {
	my $stock_id = $f->bcs_schema->resultset('Stock::Stock')->find({uniquename=>$plot})->stock_id();
	push @plot_ids, $stock_id;
}

my @phenosearch_test1_data = [
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
            'dry matter content percentage|CO_334:0000092',
            'dry yield|CO_334:0000014',
            'flower|CO_334:0000111',
            'fresh root weight|CO_334:0000012',
            'fresh shoot weight measurement in kg|CO_334:0000016',
            'harvest index variable|CO_334:0000015',
            'root number counting|CO_334:0000011',
            'sprouting proportion|CO_334:0000008',
            'top yield|CO_334:0000017'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38843,
            'test_accession4',
            '',
            'plot',
            38857,
            'test_trial21',
            '1',
            '1',
            '1',
            undef,
            undef,
            'test',
            undef,
            '35',
            '42',
            undef,
            '15',
            '20',
            undef,
            '3',
            '45',
            '2'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38842,
            'test_accession3',
            'test_accession3_synonym1',
            'plot',
            38866,
            'test_trial210',
            '3',
            '1',
            '10',
            undef,
            undef,
            'test',
            undef,
            '30',
            '12',
            undef,
            '15',
            '29',
            '9.8',
            undef,
            '45',
            '2'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38840,
            'test_accession1',
            'test_accession1_synonym1',
            'plot',
            38867,
            'test_trial211',
            '3',
            '1',
            '11',
            undef,
            undef,
            'test',
            undef,
            '38',
            '13',
            undef,
            '15',
            '30',
            '10.8',
            '4',
            '2',
            '4'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38844,
            'test_accession5',
            '',
            'plot',
            38868,
            'test_trial212',
            '3',
            '1',
            '12',
            undef,
            undef,
            'test',
            undef,
            '39',
            '42',
            undef,
            '15',
            '31',
            '11.8',
            '6',
            '56',
            '7'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38841,
            'test_accession2',
            'test_accession2_synonym1,test_accession2_synonym2',
            'plot',
            38869,
            'test_trial213',
            '2',
            '1',
            '13',
            undef,
            undef,
            'test',
            undef,
            '35',
            '35',
            '1',
            '15',
            '32',
            '12.8',
            '8',
            '8',
            '4.4'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38843,
            'test_accession4',
            '',
            'plot',
            38870,
            'test_trial214',
            '3',
            '1',
            '14',
            undef,
            undef,
            'test',
            undef,
            '30',
            '32',
            '1',
            '15',
            '33',
            '13.8',
            '4',
            '87',
            '7.5'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38841,
            'test_accession2',
            'test_accession2_synonym1,test_accession2_synonym2',
            'plot',
            38871,
            'test_trial215',
            '3',
            '1',
            '15',
            undef,
            undef,
            'test',
            undef,
            '38',
            '31',
            '1',
            '15',
            '34',
            '14.8',
            '5',
            '25',
            '7'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38844,
            'test_accession5',
            '',
            'plot',
            38858,
            'test_trial22',
            '1',
            '1',
            '2',
            undef,
            undef,
            'test',
            undef,
            '30',
            '45',
            '1',
            '15',
            '21',
            '1.8',
            '7',
            '43',
            '3'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38842,
            'test_accession3',
            'test_accession3_synonym1',
            'plot',
            38859,
            'test_trial23',
            '1',
            '1',
            '3',
            undef,
            undef,
            'test',
            undef,
            '38',
            '41',
            '1',
            '15',
            '22',
            '2.8',
            '4',
            '23',
            '5'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38842,
            'test_accession3',
            'test_accession3_synonym1',
            'plot',
            38860,
            'test_trial24',
            '2',
            '1',
            '4',
            undef,
            undef,
            'test',
            undef,
            '39',
            '14',
            '1',
            '15',
            '23',
            '3.8',
            '11',
            '78',
            '7'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38840,
            'test_accession1',
            'test_accession1_synonym1',
            'plot',
            38861,
            'test_trial25',
            '1',
            '1',
            '5',
            undef,
            undef,
            'test',
            undef,
            '35',
            '25',
            '1',
            '15',
            '24',
            '4.8',
            '6',
            '56',
            '2'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38843,
            'test_accession4',
            '',
            'plot',
            38862,
            'test_trial26',
            '2',
            '1',
            '6',
            undef,
            undef,
            'test',
            undef,
            '30',
            undef,
            '1',
            '15',
            '25',
            '5.8',
            '4',
            '45',
            '4'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38844,
            'test_accession5',
            '',
            'plot',
            38863,
            'test_trial27',
            '2',
            '1',
            '7',
            undef,
            undef,
            'test',
            undef,
            '38',
            undef,
            '1',
            '15',
            '26',
            '6.8',
            '8',
            '34',
            '9'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38840,
            'test_accession1',
            'test_accession1_synonym1',
            'plot',
            38864,
            'test_trial28',
            '2',
            '1',
            '8',
            undef,
            undef,
            'test',
            undef,
            '39',
            '41',
            undef,
            '15',
            '27',
            '7.8',
            '9',
            '23',
            '6'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38841,
            'test_accession2',
            'test_accession2_synonym1,test_accession2_synonym2',
            'plot',
            38865,
            'test_trial29',
            '1',
            '1',
            '9',
            undef,
            undef,
            'test',
            undef,
            '35',
            '24',
            '1',
            '15',
            '28',
            '8.8',
            '6',
            '76',
            '3'
          ]
        ];


my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
	search_type=>'Native',
	bcs_schema=>$f->bcs_schema,
	data_level=>'plot',
	trait_list=>[70666,70668,70681,70700,70706,70713,70727,70741,70773],
	trial_list=>[137],
	plot_list=>\@plot_ids,
	include_timestamp=>0,
	phenotype_min_value=>1,
	phenotype_max_value=>100,
);
my @data = $phenotypes_search->get_phenotype_matrix();
#print STDERR Dumper \@data;
is_deeply(\@data, @phenosearch_test1_data, 'pheno search test1 complete');

my $bs = CXGN::BreederSearch->new( { dbh=> $f->dbh() });
my $refresh = 'SELECT refresh_materialized_phenotype_jsonb_table()';
my $h = $f->dbh->prepare($refresh);
$h->execute();

my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
	search_type=>'MaterializedViewTable',
	bcs_schema=>$f->bcs_schema,
	data_level=>'plot',
	trait_list=>[70666,70668,70681,70700,70706,70713,70727,70741,70773],
	trial_list=>[137],
	plot_list=>\@plot_ids,
	include_timestamp=>0,
	phenotype_min_value=>1,
	phenotype_max_value=>100,
);
my @data = $phenotypes_search->get_phenotype_matrix();
print STDERR Dumper \@data;
is_deeply(\@data, [['studyYear','programDbId','programName','programDescription','studyDbId','studyName','studyDescription','studyDesign','plotWidth','plotLength','fieldSize','fieldTrialIsPlannedToBeGenotyped','fieldTrialIsPlannedToCross','plantingDate','harvestDate','locationDbId','locationName','germplasmDbId','germplasmName','germplasmSynonyms','observationLevel','observationUnitDbId','observationUnitName','replicate','blockNumber','plotNumber','rowNumber','colNumber','entryType','plantNumber','plantedSeedlotStockDbId','plantedSeedlotStockUniquename','plantedSeedlotCurrentCount','plantedSeedlotCurrentWeightGram','plantedSeedlotBoxName','plantedSeedlotTransactionCount','plantedSeedlotTransactionWeight','plantedSeedlotTransactionDescription','availableGermplasmSeedlotUniquenames','dry matter content percentage|CO_334:0000092','dry yield|CO_334:0000014','flower|CO_334:0000111','fresh root weight|CO_334:0000012','fresh shoot weight measurement in kg|CO_334:0000016','harvest index variable|CO_334:0000015','root number counting|CO_334:0000011','sprouting proportion|CO_334:0000008','top yield|CO_334:0000017','notes'],['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38843,'test_accession4','','plot',38857,'test_trial21','1','1','1',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','35','42','0','15','20','0.8','3','45','2','test note1 (Operator: janedoe, Time: )'],['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38842,'test_accession3','','plot',38866,'test_trial210','3','1','10',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','30','12','0','15','29','9.8',undef,'45','2',undef],['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38840,'test_accession1','','plot',38867,'test_trial211','3','1','11',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','38','13','0','15','30','10.8','4','2','4',undef],['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38844,'test_accession5','','plot',38868,'test_trial212','3','1','12',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','39','42','0','15','31','11.8','6','56','7',undef],['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38841,'test_accession2','','plot',38869,'test_trial213','2','1','13',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','35','35','1','15','32','12.8','8','8','4.4',undef],['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38843,'test_accession4','','plot',38870,'test_trial214','3','1','14',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','30','32','1','15','33','13.8','4','87','7.5',undef],['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38841,'test_accession2','','plot',38871,'test_trial215','3','1','15',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','38','31','1','15','34','14.8','5','25','7',undef],['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38844,'test_accession5','','plot',38858,'test_trial22','1','1','2',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','30','45','1','15','21','1.8','7','43','3','testnote2 (Operator: janedoe, Time: )'],['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38842,'test_accession3','','plot',38859,'test_trial23','1','1','3',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','38','41','1','15','22','2.8','4','23','5',undef],['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38842,'test_accession3','','plot',38860,'test_trial24','2','1','4',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','39','14','1','15','23','3.8','11','78','7',undef],['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38840,'test_accession1','','plot',38861,'test_trial25','1','1','5',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','35','25','1','15','24','0.8','6','56','2',undef],['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38843,'test_accession4','','plot',38862,'test_trial26','2','1','6',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','30','0','1','15','25','5.8','4','45','4',undef],['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38844,'test_accession5','','plot',38863,'test_trial27','2','1','7',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','38','0','1','15','26','6.8','8','34','9',undef],['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38840,'test_accession1','','plot',38864,'test_trial28','2','1','8',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','39','41','0','15','27','7.8','9','23','6',undef],['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38841,'test_accession2','','plot',38865,'test_trial29','1','1','9',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','35','24','1','15','28','8.8','6','76','3',undef]], 'mat table pheno search test1 complete');

my $bs = CXGN::BreederSearch->new( { dbh=> $f->dbh() });
my $refresh = 'SELECT refresh_materialized_views()';
my $h = $f->dbh->prepare($refresh);
$h->execute();


my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
	search_type=>'Native',
	bcs_schema=>$f->bcs_schema,
	data_level=>'plant',
	trait_list=>[70666,70668,70681,70700,70706,70713,70727,70741,70773],
	trial_list=>[137],
	accession_list=>\@accession_ids,
	include_timestamp=>1,
	trait_contains=>['r'],
	phenotype_min_value=>20,
	phenotype_max_value=>100,
);
my @data = $phenotypes_search->get_phenotype_matrix();
#print STDERR Dumper \@data;

#Retrieve and Remove variable plant stock_ids
my @test_result;
my @plant_ids;
foreach my $line (@data){
	my @line_array = @$line;
	push @plant_ids, $line_array[21];
	$line_array[21] = 'variable';
	push @test_result, \@line_array;
}
shift @plant_ids;

print STDERR Dumper \@test_result;
is_deeply(\@test_result, [
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
            'variable',
            'observationUnitName',
            'replicate',
            'blockNumber',
            'plotNumber',
            'rowNumber',
            'colNumber',
            'entryType',
            'plantNumber',
            'dry matter content percentage|CO_334:0000092',
            'dry yield|CO_334:0000014',
            'fresh root weight|CO_334:0000012'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38842,
            'test_accession3',
            'test_accession3_synonym1',
            'plant',
            'variable',
            'test_trial210_plant_1',
            '3',
            '1',
            '10',
            undef,
            undef,
            'test',
            undef,
            '28',
            undef,
            '38'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38842,
            'test_accession3',
            'test_accession3_synonym1',
            'plant',
            'variable',
            'test_trial210_plant_2',
            '3',
            '1',
            '10',
            undef,
            undef,
            'test',
            undef,
            '29',
            undef,
            undef
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38840,
            'test_accession1',
            'test_accession1_synonym1',
            'plant',
            'variable',
            'test_trial211_plant_1',
            '3',
            '1',
            '11',
            undef,
            undef,
            'test',
            undef,
            '30',
            undef,
            '40'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38840,
            'test_accession1',
            'test_accession1_synonym1',
            'plant',
            'variable',
            'test_trial211_plant_2',
            '3',
            '1',
            '11',
            undef,
            undef,
            'test',
            undef,
            '31',
            undef,
            '41'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38843,
            'test_accession4',
            '',
            'plant',
            'variable',
            'test_trial214_plant_1',
            '3',
            '1',
            '14',
            undef,
            undef,
            'test',
            undef,
            '36',
            undef,
            '46'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38843,
            'test_accession4',
            '',
            'plant',
            'variable',
            'test_trial214_plant_2',
            '3',
            '1',
            '14',
            undef,
            undef,
            'test',
            undef,
            '37',
            undef,
            '47'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38843,
            'test_accession4',
            '',
            'plant',
            'variable',
            'test_trial21_plant_1',
            '1',
            '1',
            '1',
            undef,
            undef,
            'test',
            undef,
            '42,2016-01-07 12:08:24',
            '42,2016-01-07 12:08:24',
            '20'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38843,
            'test_accession4',
            '',
            'plant',
            'variable',
            'test_trial21_plant_2',
            '1',
            '1',
            '1',
            undef,
            undef,
            'test',
            undef,
            '42,2016-01-07 12:08:24',
            undef,
            '21'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38842,
            'test_accession3',
            'test_accession3_synonym1',
            'plant',
            'variable',
            'test_trial23_plant_1',
            '1',
            '1',
            '3',
            undef,
            undef,
            'test',
            undef,
            '41,2016-01-07 12:08:27',
            undef,
            '24'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38842,
            'test_accession3',
            'test_accession3_synonym1',
            'plant',
            'variable',
            'test_trial23_plant_2',
            '1',
            '1',
            '3',
            undef,
            undef,
            'test',
            undef,
            '41,2016-01-07 12:08:27',
            undef,
            '25'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38842,
            'test_accession3',
            'test_accession3_synonym1',
            'plant',
            'variable',
            'test_trial24_plant_1',
            '2',
            '1',
            '4',
            undef,
            undef,
            'test',
            undef,
            undef,
            undef,
            '26'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38842,
            'test_accession3',
            'test_accession3_synonym1',
            'plant',
            'variable',
            'test_trial24_plant_2',
            '2',
            '1',
            '4',
            undef,
            undef,
            'test',
            undef,
            undef,
            undef,
            '27'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38840,
            'test_accession1',
            'test_accession1_synonym1',
            'plant',
            'variable',
            'test_trial25_plant_1',
            '1',
            '1',
            '5',
            undef,
            undef,
            'test',
            undef,
            undef,
            undef,
            '28'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38840,
            'test_accession1',
            'test_accession1_synonym1',
            'plant',
            'variable',
            'test_trial25_plant_2',
            '1',
            '1',
            '5',
            undef,
            undef,
            'test',
            undef,
            undef,
            undef,
            '29'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38843,
            'test_accession4',
            '',
            'plant',
            'variable',
            'test_trial26_plant_1',
            '2',
            '1',
            '6',
            undef,
            undef,
            'test',
            undef,
            '20',
            undef,
            '30'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38843,
            'test_accession4',
            '',
            'plant',
            'variable',
            'test_trial26_plant_2',
            '2',
            '1',
            '6',
            undef,
            undef,
            'test',
            undef,
            '21',
            undef,
            undef
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38840,
            'test_accession1',
            'test_accession1_synonym1',
            'plant',
            'variable',
            'test_trial28_plant_1',
            '2',
            '1',
            '8',
            undef,
            undef,
            'test',
            undef,
            undef,
            undef,
            '34'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38840,
            'test_accession1',
            'test_accession1_synonym1',
            'plant',
            'variable',
            'test_trial28_plant_2',
            '2',
            '1',
            '8',
            undef,
            undef,
            'test',
            undef,
            '25',
            undef,
            '35'
          ]
        ], 'pheno search test2');

my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
	search_type=>'Native',
	bcs_schema=>$f->bcs_schema,
	data_level=>'all',
	trait_list=>[70666,70668,70681,70700,70706,70713,70727,70741,70773],
	trial_list=>[137],
	accession_list=>\@accession_ids,
	plot_list=>\@plot_ids,
	plant_list=>\@plant_ids,
	include_timestamp=>1,
	trait_contains=>['r','t'],
	phenotype_min_value=>20,
	phenotype_max_value=>80,
);
my @data = $phenotypes_search->get_phenotype_matrix();
#print STDERR Dumper \@data;

#Remove variable plant stock_ids
my @test_result;
foreach my $line (@data){
	my @line_array = @$line;
	$line_array[21] = 'variable';
	push @test_result, \@line_array;
}
print STDERR Dumper \@test_result;

is_deeply(\@test_result, [
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
            'variable',
            'observationUnitName',
            'replicate',
            'blockNumber',
            'plotNumber',
            'rowNumber',
            'colNumber',
            'entryType',
            'plantNumber',
            'dry matter content percentage|CO_334:0000092',
            'fresh root weight|CO_334:0000012',
            'fresh shoot weight measurement in kg|CO_334:0000016',
            'sprouting proportion|CO_334:0000008'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38843,
            'test_accession4',
            '',
            'plot',
            'variable',
            'test_trial21',
            '1',
            '1',
            '1',
            undef,
            undef,
            'test',
            undef,
            '35,2016-04-27 12:12:20',
            '36',
            '20,2016-02-11 12:12:20',
            '45'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38842,
            'test_accession3',
            'test_accession3_synonym1',
            'plot',
            'variable',
            'test_trial210',
            '3',
            '1',
            '10',
            undef,
            undef,
            'test',
            undef,
            '30,2016-04-27 15:12:20',
            '45',
            '29,2016-02-11 15:12:20',
            '45'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38842,
            'test_accession3',
            'test_accession3_synonym1',
            'plant',
            'variable',
            'test_trial210_plant_1',
            '3',
            '1',
            '10',
            undef,
            undef,
            'test',
            undef,
            '28',
            '38',
            undef,
            undef
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38842,
            'test_accession3',
            'test_accession3_synonym1',
            'plant',
            'variable',
            'test_trial210_plant_2',
            '3',
            '1',
            '10',
            undef,
            undef,
            'test',
            undef,
            '29',
            undef,
            undef,
            undef
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38840,
            'test_accession1',
            'test_accession1_synonym1',
            'plot',
            'variable',
            'test_trial211',
            '3',
            '1',
            '11',
            undef,
            undef,
            'test',
            undef,
            '38,2016-04-27 03:12:20',
            '46',
            '30,2016-02-11 03:12:20',
            undef
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38840,
            'test_accession1',
            'test_accession1_synonym1',
            'plant',
            'variable',
            'test_trial211_plant_1',
            '3',
            '1',
            '11',
            undef,
            undef,
            'test',
            undef,
            '30',
            '40',
            undef,
            undef
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38840,
            'test_accession1',
            'test_accession1_synonym1',
            'plant',
            'variable',
            'test_trial211_plant_2',
            '3',
            '1',
            '11',
            undef,
            undef,
            'test',
            undef,
            '31',
            '41',
            undef,
            undef
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38843,
            'test_accession4',
            '',
            'plot',
            'variable',
            'test_trial214',
            '3',
            '1',
            '14',
            undef,
            undef,
            'test',
            undef,
            '30,2016-04-27 23:12:20',
            '49',
            '33,2016-02-11 23:12:20',
            undef
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38843,
            'test_accession4',
            '',
            'plant',
            'variable',
            'test_trial214_plant_1',
            '3',
            '1',
            '14',
            undef,
            undef,
            'test',
            undef,
            '36',
            '46',
            undef,
            undef
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38843,
            'test_accession4',
            '',
            'plant',
            'variable',
            'test_trial214_plant_2',
            '3',
            '1',
            '14',
            undef,
            undef,
            'test',
            undef,
            '37',
            '47',
            undef,
            undef
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38843,
            'test_accession4',
            '',
            'plant',
            'variable',
            'test_trial21_plant_1',
            '1',
            '1',
            '1',
            undef,
            undef,
            'test',
            undef,
            '42,2016-01-07 12:08:24',
            '20',
            undef,
            undef
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38843,
            'test_accession4',
            '',
            'plant',
            'variable',
            'test_trial21_plant_2',
            '1',
            '1',
            '1',
            undef,
            undef,
            'test',
            undef,
            '42,2016-01-07 12:08:24',
            '21',
            undef,
            undef
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38842,
            'test_accession3',
            'test_accession3_synonym1',
            'plot',
            'variable',
            'test_trial23',
            '1',
            '1',
            '3',
            undef,
            undef,
            'test',
            undef,
            '38,2016-04-27 01:12:20',
            '38',
            '22,2016-02-11 01:12:20',
            '23'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38842,
            'test_accession3',
            'test_accession3_synonym1',
            'plant',
            'variable',
            'test_trial23_plant_1',
            '1',
            '1',
            '3',
            undef,
            undef,
            'test',
            undef,
            '41,2016-01-07 12:08:27',
            '24',
            undef,
            undef
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38842,
            'test_accession3',
            'test_accession3_synonym1',
            'plant',
            'variable',
            'test_trial23_plant_2',
            '1',
            '1',
            '3',
            undef,
            undef,
            'test',
            undef,
            '41,2016-01-07 12:08:27',
            '25',
            undef,
            undef
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38842,
            'test_accession3',
            'test_accession3_synonym1',
            'plot',
            'variable',
            'test_trial24',
            '2',
            '1',
            '4',
            undef,
            undef,
            'test',
            undef,
            '39,2016-04-27 11:12:20',
            '39',
            '23,2016-02-11 11:12:20',
            '78'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38842,
            'test_accession3',
            'test_accession3_synonym1',
            'plant',
            'variable',
            'test_trial24_plant_1',
            '2',
            '1',
            '4',
            undef,
            undef,
            'test',
            undef,
            undef,
            '26',
            undef,
            undef
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38842,
            'test_accession3',
            'test_accession3_synonym1',
            'plant',
            'variable',
            'test_trial24_plant_2',
            '2',
            '1',
            '4',
            undef,
            undef,
            'test',
            undef,
            undef,
            '27',
            undef,
            undef
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38840,
            'test_accession1',
            'test_accession1_synonym1',
            'plot',
            'variable',
            'test_trial25',
            '1',
            '1',
            '5',
            undef,
            undef,
            'test',
            undef,
            '35,2016-04-27 09:12:20',
            '40',
            '24,2016-02-11 09:12:20',
            '56'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38840,
            'test_accession1',
            'test_accession1_synonym1',
            'plant',
            'variable',
            'test_trial25_plant_1',
            '1',
            '1',
            '5',
            undef,
            undef,
            'test',
            undef,
            undef,
            '28',
            undef,
            undef
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38840,
            'test_accession1',
            'test_accession1_synonym1',
            'plant',
            'variable',
            'test_trial25_plant_2',
            '1',
            '1',
            '5',
            undef,
            undef,
            'test',
            undef,
            undef,
            '29',
            undef,
            undef
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38843,
            'test_accession4',
            '',
            'plot',
            'variable',
            'test_trial26',
            '2',
            '1',
            '6',
            undef,
            undef,
            'test',
            undef,
            '30,2016-04-27 16:12:20',
            '41',
            '25,2016-02-11 16:12:20',
            '45'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38843,
            'test_accession4',
            '',
            'plant',
            'variable',
            'test_trial26_plant_1',
            '2',
            '1',
            '6',
            undef,
            undef,
            'test',
            undef,
            '20',
            '30',
            undef,
            undef
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38843,
            'test_accession4',
            '',
            'plant',
            'variable',
            'test_trial26_plant_2',
            '2',
            '1',
            '6',
            undef,
            undef,
            'test',
            undef,
            '21',
            undef,
            undef,
            undef
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38840,
            'test_accession1',
            'test_accession1_synonym1',
            'plot',
            'variable',
            'test_trial28',
            '2',
            '1',
            '8',
            undef,
            undef,
            'test',
            undef,
            '39,2016-04-27 13:12:20',
            '43',
            '27,2016-02-11 13:12:20',
            '23'
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38840,
            'test_accession1',
            'test_accession1_synonym1',
            'plant',
            'variable',
            'test_trial28_plant_1',
            '2',
            '1',
            '8',
            undef,
            undef,
            'test',
            undef,
            undef,
            '34',
            undef,
            undef
          ],
          [
            '2014',
            134,
            'test',
            'test',
            137,
            'test_trial',
            'test trial',
            'CRD',
            undef,
            undef,
            undef,
            undef,
            undef,
            '2017-July-04',
            '2017-July-21',
            '23',
            'test_location',
            38840,
            'test_accession1',
            'test_accession1_synonym1',
            'plant',
            'variable',
            'test_trial28_plant_2',
            '2',
            '1',
            '8',
            undef,
            undef,
            'test',
            undef,
            '25',
            '35',
            undef,
            undef
          ]
        ], 'pheno search test3');

my $tempfile = '/tmp/test_download_search_pheno1.xls';
my $download = CXGN::Trial::Download->new({
	bcs_schema=>$f->bcs_schema,
	data_level=>'all',
	trait_list=>[70666,70668,70681,70700,70706,70713,70727,70741,70773],
	trial_list=>[137],
	year_list => [2014],
	location_list => [23],
	accession_list=>\@accession_ids,
	plot_list=>\@plot_ids,
	plant_list=>\@plant_ids,
	include_timestamp=>1,
	trait_contains=>['r','t'],
	phenotype_min_value=>20,
	phenotype_max_value=>80,
	search_type=>'complete',
	filename => $tempfile,
	format => 'TrialPhenotypeExcel'
});
my $error = $download->download();
my $contents = ReadData ($tempfile);
#print STDERR Dumper $contents;

is($contents->[0]->{'type'}, 'xls', "check that type of file is correct");
is($contents->[0]->{'sheets'}, '1', "check that type of file is correct");

my $columns = $contents->[1]->{'cell'};
#print STDERR Dumper scalar(@$columns);
is(scalar(@$columns),47);
if (exists($contents->[1]->{parser})){
    delete($contents->[1]->{parser});
}
#print STDERR Dumper scalar keys %{$contents->[1]};
#is(scalar keys %{$contents->[1]}, 490);


my $csv_response = ['
,,,,,,,,,,,,,,,,,,,,,variable','"studyYear","programDbId","programName","programDescription","studyDbId","studyName","studyDescription","studyDesign","plotWidth","plotLength","fieldSize","fieldTrialIsPlannedToBeGenotyped","fieldTrialIsPlannedToCross","plantingDate","harvestDate","locationDbId","locationName","germplasmDbId","germplasmName","germplasmSynonyms","observationLevel",variable,"observationUnitName","replicate","blockNumber","plotNumber","rowNumber","colNumber","entryType","plantNumber","plantedSeedlotStockDbId","plantedSeedlotStockUniquename","plantedSeedlotCurrentCount","plantedSeedlotCurrentWeightGram","plantedSeedlotBoxName","plantedSeedlotTransactionCount","plantedSeedlotTransactionWeight","plantedSeedlotTransactionDescription","availableGermplasmSeedlotUniquenames","dry matter content percentage|CO_334:0000092","fresh root weight|CO_334:0000012","fresh shoot weight measurement in kg|CO_334:0000016","harvest index variable|CO_334:0000015","root number counting|CO_334:0000011","sprouting proportion|CO_334:0000008","notes"
','"2014","134","test","test","137","test_trial","test trial","CRD","","","","","","2017-July-04","2017-July-21","23","test_location","38843","test_accession4","","plot",variable,"test_trial21","1","1","1","","","test","","","","","","","","","","","35","15","20","0.8","3","45","test note1 (Operator: janedoe, Time: )"
','"2014","134","test","test","137","test_trial","test trial","CRD","","","","","","2017-July-04","2017-July-21","23","test_location","38842","test_accession3","","plot",variable,"test_trial210","3","1","10","","","test","","","","","","","","","","","30","15","29","9.8","","45",""
','"2014","134","test","test","137","test_trial","test trial","CRD","","","","","","2017-July-04","2017-July-21","23","test_location","38842","test_accession3","","plant",variable,"test_trial210_plant_1","3","1","10","","","test","1","","","","","","","","","","28","38","","","","",""
','"2014","134","test","test","137","test_trial","test trial","CRD","","","","","","2017-July-04","2017-July-21","23","test_location","38842","test_accession3","","plant",variable,"test_trial210_plant_2","3","1","10","","","test","2","","","","","","","","","","29","","","","","",""
','"2014","134","test","test","137","test_trial","test trial","CRD","","","","","","2017-July-04","2017-July-21","23","test_location","38840","test_accession1","","plot",variable,"test_trial211","3","1","11","","","test","","","","","","","","","","","38","15","30","10.8","4","2",""
','"2014","134","test","test","137","test_trial","test trial","CRD","","","","","","2017-July-04","2017-July-21","23","test_location","38840","test_accession1","","plant",variable,"test_trial211_plant_1","3","1","11","","","test","1","","","","","","","","","","30","40","","","","",""
','"2014","134","test","test","137","test_trial","test trial","CRD","","","","","","2017-July-04","2017-July-21","23","test_location","38840","test_accession1","","plant",variable,"test_trial211_plant_2","3","1","11","","","test","2","","","","","","","","","","31","41","","","","",""
','"2014","134","test","test","137","test_trial","test trial","CRD","","","","","","2017-July-04","2017-July-21","23","test_location","38843","test_accession4","","plot",variable,"test_trial214","3","1","14","","","test","","","","","","","","","","","30","15","33","13.8","4","87",""
','"2014","134","test","test","137","test_trial","test trial","CRD","","","","","","2017-July-04","2017-July-21","23","test_location","38843","test_accession4","","plant",variable,"test_trial214_plant_1","3","1","14","","","test","1","","","","","","","","","","36","46","","","","",""
','"2014","134","test","test","137","test_trial","test trial","CRD","","","","","","2017-July-04","2017-July-21","23","test_location","38843","test_accession4","","plant",variable,"test_trial214_plant_2","3","1","14","","","test","2","","","","","","","","","","37","47","","","","",""
','"2014","134","test","test","137","test_trial","test trial","CRD","","","","","","2017-July-04","2017-July-21","23","test_location","38843","test_accession4","","plant",variable,"test_trial21_plant_1","1","1","1","","","test","1","","","","","","","","","","42,2016-01-07T12:08:24","20","","","","",""
','"2014","134","test","test","137","test_trial","test trial","CRD","","","","","","2017-July-04","2017-July-21","23","test_location","38843","test_accession4","","plant",variable,"test_trial21_plant_2","1","1","1","","","test","2","","","","","","","","","","42,2016-01-07T12:08:24","21","","","","",""
','"2014","134","test","test","137","test_trial","test trial","CRD","","","","","","2017-July-04","2017-July-21","23","test_location","38842","test_accession3","","plot",variable,"test_trial23","1","1","3","","","test","","","","","","","","","","","38","15","22","2.8","4","23",""
','"2014","134","test","test","137","test_trial","test trial","CRD","","","","","","2017-July-04","2017-July-21","23","test_location","38842","test_accession3","","plant",variable,"test_trial23_plant_1","1","1","3","","","test","1","","","","","","","","","","41,2016-01-07T12:08:27","24","","","","",""
','"2014","134","test","test","137","test_trial","test trial","CRD","","","","","","2017-July-04","2017-July-21","23","test_location","38842","test_accession3","","plant",variable,"test_trial23_plant_2","1","1","3","","","test","2","","","","","","","","","","41,2016-01-07T12:08:27","25","","","","",""
','"2014","134","test","test","137","test_trial","test trial","CRD","","","","","","2017-July-04","2017-July-21","23","test_location","38842","test_accession3","","plot",variable,"test_trial24","2","1","4","","","test","","","","","","","","","","","39","15","23","3.8","11","78",""
','"2014","134","test","test","137","test_trial","test trial","CRD","","","","","","2017-July-04","2017-July-21","23","test_location","38842","test_accession3","","plant",variable,"test_trial24_plant_1","2","1","4","","","test","1","","","","","","","","","","16","26","","","","",""
','"2014","134","test","test","137","test_trial","test trial","CRD","","","","","","2017-July-04","2017-July-21","23","test_location","38842","test_accession3","","plant",variable,"test_trial24_plant_2","2","1","4","","","test","2","","","","","","","","","","17","27","","","","",""
','"2014","134","test","test","137","test_trial","test trial","CRD","","","","","","2017-July-04","2017-July-21","23","test_location","38840","test_accession1","","plot",variable,"test_trial25","1","1","5","","","test","","","","","","","","","","","35","15","24","0.8","6","56",""
','"2014","134","test","test","137","test_trial","test trial","CRD","","","","","","2017-July-04","2017-July-21","23","test_location","38840","test_accession1","","plant",variable,"test_trial25_plant_1","1","1","5","","","test","1","","","","","","","","","","18","28","","","","",""
','"2014","134","test","test","137","test_trial","test trial","CRD","","","","","","2017-July-04","2017-July-21","23","test_location","38840","test_accession1","","plant",variable,"test_trial25_plant_2","1","1","5","","","test","2","","","","","","","","","","","29","","","","",""
','"2014","134","test","test","137","test_trial","test trial","CRD","","","","","","2017-July-04","2017-July-21","23","test_location","38843","test_accession4","","plot",variable,"test_trial26","2","1","6","","","test","","","","","","","","","","","30","15","25","5.8","4","45",""
','"2014","134","test","test","137","test_trial","test trial","CRD","","","","","","2017-July-04","2017-July-21","23","test_location","38843","test_accession4","","plant",variable,"test_trial26_plant_1","2","1","6","","","test","1","","","","","","","","","","20","30","","","","",""
','"2014","134","test","test","137","test_trial","test trial","CRD","","","","","","2017-July-04","2017-July-21","23","test_location","38843","test_accession4","","plant",variable,"test_trial26_plant_2","2","1","6","","","test","2","","","","","","","","","","21","0","","","","",""
','"2014","134","test","test","137","test_trial","test trial","CRD","","","","","","2017-July-04","2017-July-21","23","test_location","38840","test_accession1","","plot",variable,"test_trial28","2","1","8","","","test","","","","","","","","","","","39","15","27","7.8","9","23",""
','"2014","134","test","test","137","test_trial","test trial","CRD","","","","","","2017-July-04","2017-July-21","23","test_location","38840","test_accession1","","plant",variable,"test_trial28_plant_1","2","1","8","","","test","1","","","","","","","","","","0","34","","","","",""
','"2014","134","test","test","137","test_trial","test trial","CRD","","","","","","2017-July-04","2017-July-21","23","test_location","38840","test_accession1","","plant",variable,"test_trial28_plant_2","2","1","8","","","test","2","","","","","","","","","","25","35","","","","",""
'];

my $tempfile = '/tmp/test_download_search_pheno2.xls';
my $download = CXGN::Trial::Download->new({
	bcs_schema=>$f->bcs_schema,
	data_level=>'all',
	trait_list=>[70666,70668,70681,70700,70706,70713,70727,70741,70773],
	trial_list=>[137],
	year_list => [2014],
	location_list => [23],
	accession_list=>\@accession_ids,
	plot_list=>\@plot_ids,
	plant_list=>\@plant_ids,
	include_timestamp=>1,
	trait_contains=>['r','t'],
	phenotype_min_value=>20,
	phenotype_max_value=>80,
	search_type=>'complete',
	filename => $tempfile,
	format => 'TrialPhenotypeCSV',
    include_row_and_column_numbers => 1,
    exclude_phenotype_outlier => 1
});
my $error = $download->download();

my @data;
open my $fh, '<', $tempfile;
while(my $line = <$fh>){
	my @arr = split(',',$line);
	$arr[21]= 'variable';
	my $line = join(',',@arr);
	push @data, $line;
}
my $first_row = shift @data;
my $sec_row = shift @data;
print STDERR Dumper \@data;
is_deeply(\@data, $csv_response);


my $mech = Test::WWW::Mechanize->new;
my $response;
$mech->post_ok('http://localhost:3010/ajax/breeders/trial/generate_plot_phenotypes', [ "trial_id"=> 137, "trait_name"=> "dry matter content percentage|CO_334:0000092", "method"=> "arithmetic_mean", "rounding"=>"round" ]);
$response = decode_json $mech->content;
#print STDERR Dumper $response;
is_deeply($response->{info}, [
                      [
                        {
                          'value_to_store' => '27',
                          'plot_name' => 'test_trial21',
                          'output' => '26.25',
                          'plant_values' => '["10","11","42","42"]',
                          'notes' => ''
                        },
                        {
                          'output' => '28.75',
                          'plot_name' => 'test_trial22',
                          'notes' => '',
                          'plant_values' => '["12","13","45","45"]',
                          'value_to_store' => '29'
                        },
                        {
                          'value_to_store' => '28',
                          'plant_values' => '["14","15","41","41"]',
                          'notes' => '',
                          'plot_name' => 'test_trial23',
                          'output' => '27.75'
                        },
                        {
                          'value_to_store' => '17',
                          'plot_name' => 'test_trial24',
                          'output' => '16.5',
                          'plant_values' => '["16","17"]',
                          'notes' => ''
                        },
                        {
                          'value_to_store' => '18',
                          'notes' => '',
                          'plant_values' => '["18"]',
                          'plot_name' => 'test_trial25',
                          'output' => '18'
                        },
                        {
                          'value_to_store' => '21',
                          'notes' => '',
                          'plant_values' => '["20","21"]',
                          'output' => '20.5',
                          'plot_name' => 'test_trial26'
                        },
                        {
                          'plot_name' => 'test_trial27',
                          'output' => '22.5',
                          'plant_values' => '["22","23"]',
                          'notes' => '',
                          'value_to_store' => '23'
                        },
                        {
                          'value_to_store' => '13',
                          'plot_name' => 'test_trial28',
                          'output' => '12.5',
                          'plant_values' => '["0","25"]',
                          'notes' => ''
                        },
                        {
                          'value_to_store' => '27',
                          'notes' => '',
                          'plant_values' => '["26","27"]',
                          'output' => '26.5',
                          'plot_name' => 'test_trial29'
                        },
                        {
                          'notes' => '',
                          'plant_values' => '["28","29"]',
                          'plot_name' => 'test_trial210',
                          'output' => '28.5',
                          'value_to_store' => '29'
                        },
                        {
                          'plant_values' => '["30","31"]',
                          'notes' => '',
                          'plot_name' => 'test_trial211',
                          'output' => '30.5',
                          'value_to_store' => '31'
                        },
                        {
                          'value_to_store' => '33',
                          'plant_values' => '["32","33"]',
                          'notes' => '',
                          'plot_name' => 'test_trial212',
                          'output' => '32.5'
                        },
                        {
                          'plant_values' => '["34","35"]',
                          'notes' => '',
                          'plot_name' => 'test_trial213',
                          'output' => '34.5',
                          'value_to_store' => '35'
                        },
                        {
                          'plant_values' => '["36","37"]',
                          'notes' => '',
                          'plot_name' => 'test_trial214',
                          'output' => '36.5',
                          'value_to_store' => '37'
                        },
                        {
                          'output' => '38.5',
                          'plot_name' => 'test_trial215',
                          'notes' => '',
                          'plant_values' => '["38","39"]',
                          'value_to_store' => '39'
                        }
                      ]
                    ]);

my $store_data = decode_json $response->{store_data};
#print STDERR Dumper $store_data;
is_deeply($store_data, [
          {
            'test_trial215' => {
                                 'dry matter content percentage|CO_334:0000092' => [
                                                                                     39,
                                                                                     ''
                                                                                   ]
                               },
            'test_trial214' => {
                                 'dry matter content percentage|CO_334:0000092' => [
                                                                                     37,
                                                                                     ''
                                                                                   ]
                               },
            'test_trial22' => {
                                'dry matter content percentage|CO_334:0000092' => [
                                                                                    29,
                                                                                    ''
                                                                                  ]
                              },
            'test_trial213' => {
                                 'dry matter content percentage|CO_334:0000092' => [
                                                                                     35,
                                                                                     ''
                                                                                   ]
                               },
            'test_trial25' => {
                                'dry matter content percentage|CO_334:0000092' => [
                                                                                    18,
                                                                                    ''
                                                                                  ]
                              },
            'test_trial23' => {
                                'dry matter content percentage|CO_334:0000092' => [
                                                                                    28,
                                                                                    ''
                                                                                  ]
                              },
            'test_trial211' => {
                                 'dry matter content percentage|CO_334:0000092' => [
                                                                                     31,
                                                                                     ''
                                                                                   ]
                               },
            'test_trial26' => {
                                'dry matter content percentage|CO_334:0000092' => [
                                                                                    21,
                                                                                    ''
                                                                                  ]
                              },
            'test_trial28' => {
                                'dry matter content percentage|CO_334:0000092' => [
                                                                                    13,
                                                                                    ''
                                                                                  ]
                              },
            'test_trial29' => {
                                'dry matter content percentage|CO_334:0000092' => [
                                                                                    27,
                                                                                    ''
                                                                                  ]
                              },
            'test_trial212' => {
                                 'dry matter content percentage|CO_334:0000092' => [
                                                                                     33,
                                                                                     ''
                                                                                   ]
                               },
            'test_trial24' => {
                                'dry matter content percentage|CO_334:0000092' => [
                                                                                    17,
                                                                                    ''
                                                                                  ]
                              },
            'test_trial21' => {
                                'dry matter content percentage|CO_334:0000092' => [
                                                                                    27,
                                                                                    ''
                                                                                  ]
                              },
            'test_trial210' => {
                                 'dry matter content percentage|CO_334:0000092' => [
                                                                                     29,
                                                                                     ''
                                                                                   ]
                               },
            'test_trial27' => {
                                'dry matter content percentage|CO_334:0000092' => [
                                                                                    23,
                                                                                    ''
                                                                                  ]
                              }
          }
        ]);

$mech->post_ok('http://localhost:3010/ajax/breeders/trial/store_generated_plot_phenotypes', [ "overwrite_values"=> '', "store_data"=> $response->{store_data}, "store_plots"=> $response->{store_plots}, "store_traits"=>$response->{store_traits}, "user_id"=>41 ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {success=>1});

########################################
#Tests for phenotype spreadsheet parsing

my $filename = "t/data/trial/trial_phenotype_upload_file_simple.xls";
my $time = DateTime->now();
my $timestamp = $time->ymd()."_".$time->hms();

#Test archive upload file
my $uploader = CXGN::UploadFile->new({
  tempfile => $filename,
  subdirectory => 'temp_fieldbook',
  archive_path => '/tmp',
  archive_filename => 'trial_phenotype_upload_file_simple.xls',
  timestamp => $timestamp,
  user_id => 41, #janedoe in fixture
  user_role => 'curator'
});

## Store uploaded temporary file in archive
my $archived_filename_with_path = $uploader->archive();
my $md5 = $uploader->get_md5($archived_filename_with_path);
ok($archived_filename_with_path);
ok($md5);

#Now parse phenotyping spreadsheet file using correct parser
$parser = CXGN::Phenotypes::ParseUpload->new();
$validate_file = $parser->validate('phenotype spreadsheet simple', $archived_filename_with_path, 0, 'plots', $f->bcs_schema);
ok($validate_file == 1, "Check if parse validate works for phenotype file");

my $parsed_file = $parser->parse('phenotype spreadsheet simple', $archived_filename_with_path, 0, 'plots', $f->bcs_schema);
ok($parsed_file, "Check if parse parse phenotype spreadsheet works");

print STDERR Dumper $parsed_file;

is_deeply($parsed_file, {
    'data' => {
        'test_trial213' => {'CO_334:0000011' => ['',''],'sprout count|CO_334:0000213' => ['',''],'root weight in air|CO_334:0000157' => ['',''],'root weight in water|CO_334:0000158' => ['',''],'number of planted stakes counting|CO_334:0000159' => ['','']},
        'test_trial28' => {'number of planted stakes counting|CO_334:0000159' => ['20',''],'root weight in water|CO_334:0000158' => ['0.32',''],'sprout count|CO_334:0000213' => ['14',''],'root weight in air|CO_334:0000157' => ['3',''],'CO_334:0000011' => ['','']},
        'test_trial29' => {'number of planted stakes counting|CO_334:0000159' => ['',''],'root weight in water|CO_334:0000158' => ['',''],'sprout count|CO_334:0000213' => ['',''],'root weight in air|CO_334:0000157' => ['',''],'CO_334:0000011' => ['','']},
        'test_trial25' => {'CO_334:0000011' => ['',''],'root weight in air|CO_334:0000157' => ['3',''],'root weight in water|CO_334:0000158' => ['',''],'number of planted stakes counting|CO_334:0000159' => ['20','']},
        'test_trial212' => {'CO_334:0000011' => ['',''],'root weight in air|CO_334:0000157' => ['',''],'sprout count|CO_334:0000213' => ['',''],'root weight in water|CO_334:0000158' => ['',''],'number of planted stakes counting|CO_334:0000159' => ['','']},
        'test_trial214' => {'number of planted stakes counting|CO_334:0000159' => ['',''],'root weight in water|CO_334:0000158' => ['',''],'sprout count|CO_334:0000213' => ['',''],'root weight in air|CO_334:0000157' => ['',''],'CO_334:0000011' => ['','']},
        'test_trial210' => {'number of planted stakes counting|CO_334:0000159' => ['0',''],'root weight in water|CO_334:0000158' => ['',''],'root weight in air|CO_334:0000157' => ['',''],'sprout count|CO_334:0000213' => ['',''],'CO_334:0000011' => ['','']},
        'test_trial215' => {'CO_334:0000011' => ['',''],'sprout count|CO_334:0000213' => ['',''],'root weight in air|CO_334:0000157' => ['',''],'root weight in water|CO_334:0000158' => ['',''],'number of planted stakes counting|CO_334:0000159' => ['','']},
        'test_trial27' => {'number of planted stakes counting|CO_334:0000159' => ['20',''],'root weight in water|CO_334:0000158' => ['0.32',''],'sprout count|CO_334:0000213' => ['14',''],'root weight in air|CO_334:0000157' => ['3',''],'CO_334:0000011' => ['','']},
        'test_trial23' => {'number of planted stakes counting|CO_334:0000159' => ['20',''],'root weight in water|CO_334:0000158' => ['0.32',''],'sprout count|CO_334:0000213' => ['20',''],'root weight in air|CO_334:0000157' => ['3',''],'CO_334:0000011' => ['4','']},
        'test_trial211' => {'number of planted stakes counting|CO_334:0000159' => ['',''],'root weight in water|CO_334:0000158' => ['',''],'sprout count|CO_334:0000213' => ['0',''],'root weight in air|CO_334:0000157' => ['',''],'CO_334:0000011' => ['','']},
        'test_trial26' => {'CO_334:0000011' => ['',''],'root weight in air|CO_334:0000157' => ['3',''],'sprout count|CO_334:0000213' => ['18',''],'root weight in water|CO_334:0000158' => ['0.36',''],'number of planted stakes counting|CO_334:0000159' => ['20','']},
        'test_trial24' => {'number of planted stakes counting|CO_334:0000159' => ['20',''],'root weight in water|CO_334:0000158' => ['',''],'root weight in air|CO_334:0000157' => ['3',''],'sprout count|CO_334:0000213' => ['6',''],'CO_334:0000011' => ['','']},
        'test_trial22' => {'number of planted stakes counting|CO_334:0000159' => ['20',''],'root weight in water|CO_334:0000158' => ['',''],'sprout count|CO_334:0000213' => ['',''],'root weight in air|CO_334:0000157' => ['3',''],'CO_334:0000011' => ['3','']},
        'test_trial21' => {'CO_334:0000011' => ['2',''],'sprout count|CO_334:0000213' => ['18',''],'root weight in air|CO_334:0000157' => ['3',''],'root weight in water|CO_334:0000158' => ['0.3',''],'number of planted stakes counting|CO_334:0000159' => ['20','']}
    },
    'units' => ['test_trial21','test_trial210','test_trial211','test_trial212','test_trial213','test_trial214','test_trial215','test_trial22','test_trial23','test_trial24','test_trial25','test_trial26','test_trial27','test_trial28','test_trial29'],
    'variables' => ['CO_334:0000011','number of planted stakes counting|CO_334:0000159','root weight in air|CO_334:0000157','root weight in water|CO_334:0000158','sprout count|CO_334:0000213']}, 'check parse simple');

$phenotype_metadata{'archived_file'} = $archived_filename_with_path;
$phenotype_metadata{'archived_file_type'}="spreadsheet phenotype simple file";
$phenotype_metadata{'operator'}="janedoe";
$phenotype_metadata{'date'}="2016-02-26_05:55:21";
%parsed_data = %{$parsed_file->{'data'}};
@plots = @{$parsed_file->{'units'}};
@traits = @{$parsed_file->{'variables'}};

my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
    basepath=>$f->config->{basepath},
    dbhost=>$f->config->{dbhost},
    dbname=>$f->config->{dbname},
    dbuser=>$f->config->{dbuser},
    dbpass=>$f->config->{dbpass},
    temp_file_nd_experiment_id=>$f->config->{cluster_shared_tempdir}."/test_temp_nd_experiment_id_delete",
    bcs_schema=>$f->bcs_schema,
    metadata_schema=>$f->metadata_schema,
    phenome_schema=>$f->phenome_schema,
    user_id=>41,
    stock_list=>\@plots,
    trait_list=>\@traits,
    values_hash=>\%parsed_data,
    has_timestamps=>1,
    overwrite_values=>1,
    metadata_hash=>\%phenotype_metadata,
);
my ($verified_warning, $verified_error) = $store_phenotypes->verify();
ok(!$verified_error);
my ($stored_phenotype_error_msg, $store_success) = $store_phenotypes->store();
ok(!$stored_phenotype_error_msg, "check that store phenotype spreadsheet simple works");

my $bs = CXGN::BreederSearch->new( { dbh=>$f->bcs_schema->storage->dbh, dbname=>$f->config->{dbname} } );
my $refresh = $bs->refresh_matviews($f->config->{dbhost}, $f->config->{dbname}, $f->config->{dbuser}, $f->config->{dbpass}, 'fullview', 'concurrent', $f->config->{basepath});
sleep(20);

my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
	search_type=>'MaterializedViewTable',
	bcs_schema=>$f->bcs_schema,
	data_level=>'plot',
	trial_list=>[137],
	include_timestamp=>0,
);
my @data = $phenotypes_search->get_phenotype_matrix();
print STDERR Dumper \@data;
is_deeply(\@data, [
['studyYear','programDbId','programName','programDescription','studyDbId','studyName','studyDescription','studyDesign','plotWidth','plotLength','fieldSize','fieldTrialIsPlannedToBeGenotyped','fieldTrialIsPlannedToCross','plantingDate','harvestDate','locationDbId','locationName','germplasmDbId','germplasmName','germplasmSynonyms','observationLevel','observationUnitDbId','observationUnitName','replicate','blockNumber','plotNumber','rowNumber','colNumber','entryType','plantNumber','plantedSeedlotStockDbId','plantedSeedlotStockUniquename','plantedSeedlotCurrentCount','plantedSeedlotCurrentWeightGram','plantedSeedlotBoxName','plantedSeedlotTransactionCount','plantedSeedlotTransactionWeight','plantedSeedlotTransactionDescription','availableGermplasmSeedlotUniquenames','dry matter content percentage|CO_334:0000092','dry yield|CO_334:0000014','fieldbook_image|CO_334:0010472','flower|CO_334:0000111','fresh root weight|CO_334:0000012','fresh shoot weight measurement in kg|CO_334:0000016','harvest index variable|CO_334:0000015','number of planted stakes counting|CO_334:0000159','root number counting|CO_334:0000011','root weight in air|CO_334:0000157','root weight in water|CO_334:0000158','sprout count at one-month|CO_334:0000213','sprouting proportion|CO_334:0000008','top yield|CO_334:0000017','notes'],
['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38843,'test_accession4','','plot',38857,'test_trial21','1','1','1',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','27','42','/storage/emulated/0/fieldBook/plot_data/test_trial/photos/test_trial21_2016-09-12-11-15-12.jpg','0','15','20','0.8','20','2','3','0.3','18','45','2','test note1 (Operator: janedoe, Time: )'],
['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38842,'test_accession3','','plot',38866,'test_trial210','3','1','10',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','29','12',undef,'0','15','29','9.8','0',undef,undef,undef,undef,'45','2',undef],
['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38840,'test_accession1','','plot',38867,'test_trial211','3','1','11',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','31','13',undef,'0','15','30','10.8',undef,'4',undef,undef,'0','2','4',undef],
['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38844,'test_accession5','','plot',38868,'test_trial212','3','1','12',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','33','42',undef,'0','15','31','11.8',undef,'6',undef,undef,undef,'56','7',undef],
['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38841,'test_accession2','','plot',38869,'test_trial213','2','1','13',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','35','35',undef,'1','15','32','12.8',undef,'8',undef,undef,undef,'8','4.4',undef],
['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38843,'test_accession4','','plot',38870,'test_trial214','3','1','14',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','37','32',undef,'1','15','33','13.8',undef,'4',undef,undef,undef,'87','7.5',undef],
['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38841,'test_accession2','','plot',38871,'test_trial215','3','1','15',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','39','31',undef,'1','15','34','14.8',undef,'5',undef,undef,undef,'25','7',undef],
['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38844,'test_accession5','','plot',38858,'test_trial22','1','1','2',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','29','45','/storage/emulated/0/fieldBook/plot_data/test_trial/photos/test_trial22_2016-09-12-11-15-26.jpg','1','15','21','1.8','20','3','3',undef,undef,'43','3','testnote2 (Operator: janedoe, Time: )'],
['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38842,'test_accession3','','plot',38859,'test_trial23','1','1','3',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','28','41',undef,'1','15','22','2.8','20','4','3','0.32','20','23','5',undef],
['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38842,'test_accession3','','plot',38860,'test_trial24','2','1','4',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','17','14',undef,'1','15','23','3.8','20','11','3',undef,'6','78','7',undef],
['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38840,'test_accession1','','plot',38861,'test_trial25','1','1','5',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','18','25',undef,'1','15','24','0.8','20','6','3',undef,undef,'56','2',undef],
['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38843,'test_accession4','','plot',38862,'test_trial26','2','1','6',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','21','0',undef,'1','15','25','5.8','20','4','3','0.36','18','45','4',undef],
['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38844,'test_accession5','','plot',38863,'test_trial27','2','1','7',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','23','0',undef,'1','15','26','6.8','20','8','3','0.32','14','34','9',undef],
['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38840,'test_accession1','','plot',38864,'test_trial28','2','1','8',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','13','41',undef,'0','15','27','7.8','20','9','3','0.32','14','23','6',undef],
['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38841,'test_accession2','','plot',38865,'test_trial29','1','1','9',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','27','24',undef,'1','15','28','8.8',undef,'6',undef,undef,undef,'76','3',undef]]);

$mech->get_ok('http://localhost:3010/ajax/search/images?image_description_filename_composite=26');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{recordsTotal}, 1);
is($response->{data}[0][4], 'Stock (plot): <a href=\'/stock/38858/view\' >test_trial22</a>');

$mech->get_ok('http://localhost:3010/ajax/search/images');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{recordsTotal}, 2);
is($response->{data}[0][4], 'Stock (plot): <a href=\'/stock/38858/view\' >test_trial22</a>');
is($response->{data}[1][4], 'Stock (plot): <a href=\'/stock/38857/view\' >test_trial21</a>');

$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/phenotypes_associated_images/4picsimagephenotypespreadsheet.xls";
my $image_zipfile_filename = "t/data/phenotypes_associated_images/4pics.zip";

$validate_file = $parser->validate('phenotype spreadsheet associated_images', $filename, 1, 'plots', $f->bcs_schema, $image_zipfile_filename);
ok($validate_file == 1, "Check if parse validate works for associated_images phenotype spreadsheet file");

$parsed_file = $parser->parse('phenotype spreadsheet associated_images', $filename, 1, 'plots', $f->bcs_schema, $image_zipfile_filename, 41, $f);
ok($parsed_file, "Check if parse parse associated_images phenotype spreadsheet works");

print STDERR Dumper $parsed_file;

is_deeply($parsed_file, {'data' => {'test_trial22' => {'CO_334:0000011' => ['0','','','',2429],'CO_334:0000010' => ['5','','nmorales','',2429]},'test_trial21' => {'CO_334:0000008' => ['12','','nmorales','',2430],'CO_334:0000013' => ['23','','','',2430]}},'variables' => ['CO_334:0000008','CO_334:0000010','CO_334:0000011','CO_334:0000013'],'units' => ['test_trial21','test_trial22']}, "check parse associated_images phenotype spreadsheet file");

$phenotype_metadata{'archived_file'} = $filename;
$phenotype_metadata{'archived_file_type'}="spreadsheet phenotype associated_images file";
$phenotype_metadata{'operator'}="janedoe";
$phenotype_metadata{'date'}="2016-02-26_05:55:17";
%parsed_data = %{$parsed_file->{'data'}};
@plots = @{$parsed_file->{'units'}};
@traits = @{$parsed_file->{'variables'}};

my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
    basepath=>$f->config->{basepath},
    dbhost=>$f->config->{dbhost},
    dbname=>$f->config->{dbname},
    dbuser=>$f->config->{dbuser},
    dbpass=>$f->config->{dbpass},
    temp_file_nd_experiment_id=>$f->config->{cluster_shared_tempdir}."/test_temp_nd_experiment_id_delete",
    bcs_schema=>$f->bcs_schema,
    metadata_schema=>$f->metadata_schema,
    phenome_schema=>$f->phenome_schema,
    user_id=>41,
    stock_list=>\@plots,
    trait_list=>\@traits,
    values_hash=>\%parsed_data,
    has_timestamps=>1,
    overwrite_values=>1,
    metadata_hash=>\%phenotype_metadata,
);
my ($verified_warning, $verified_error) = $store_phenotypes->verify();
ok(!$verified_error);
my ($stored_phenotype_error_msg, $store_success) = $store_phenotypes->store();
ok(!$stored_phenotype_error_msg, "check that store phenotype spreadsheet associated_images works");

my $bs = CXGN::BreederSearch->new( { dbh=>$f->bcs_schema->storage->dbh, dbname=>$f->config->{dbname} } );
my $refresh = $bs->refresh_matviews($f->config->{dbhost}, $f->config->{dbname}, $f->config->{dbuser}, $f->config->{dbpass}, 'fullview', 'concurrent', $f->config->{basepath});
sleep(20);

$mech->get_ok('http://localhost:3010/ajax/search/images');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{recordsTotal}, 6);
is($response->{data}[0][4], 'Stock (plot): <a href=\'/stock/38858/view\' >test_trial22</a>');
is($response->{data}[1][4], 'Stock (plot): <a href=\'/stock/38857/view\' >test_trial21</a>');
is($response->{data}[2][4], 'Stock (plot): <a href=\'/stock/38858/view\' >test_trial22</a><br/>Project (phenotype_spreadsheet_associated_images): <a href=\'/breeders/trial/137\' >test_trial</a>');

my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
	search_type=>'MaterializedViewTable',
	bcs_schema=>$f->bcs_schema,
	data_level=>'plot',
	trial_list=>[137],
	include_timestamp=>0,
);
my @data = $phenotypes_search->get_phenotype_matrix();
print STDERR Dumper \@data;
is_deeply(\@data, [
['studyYear','programDbId','programName','programDescription','studyDbId','studyName','studyDescription','studyDesign','plotWidth','plotLength','fieldSize','fieldTrialIsPlannedToBeGenotyped','fieldTrialIsPlannedToCross','plantingDate','harvestDate','locationDbId','locationName','germplasmDbId','germplasmName','germplasmSynonyms','observationLevel','observationUnitDbId','observationUnitName','replicate','blockNumber','plotNumber','rowNumber','colNumber','entryType','plantNumber','plantedSeedlotStockDbId','plantedSeedlotStockUniquename','plantedSeedlotCurrentCount','plantedSeedlotCurrentWeightGram','plantedSeedlotBoxName','plantedSeedlotTransactionCount','plantedSeedlotTransactionWeight','plantedSeedlotTransactionDescription','availableGermplasmSeedlotUniquenames','dry matter content percentage|CO_334:0000092','dry yield|CO_334:0000014','fieldbook_image|CO_334:0010472','flower|CO_334:0000111','fresh root weight|CO_334:0000012','fresh root yield|CO_334:0000013','fresh shoot weight measurement in kg|CO_334:0000016','harvest index variable|CO_334:0000015','number of planted stakes counting|CO_334:0000159','plant stands harvested counting|CO_334:0000010','root number counting|CO_334:0000011','root weight in air|CO_334:0000157','root weight in water|CO_334:0000158','sprout count at one-month|CO_334:0000213','sprouting proportion|CO_334:0000008','top yield|CO_334:0000017','notes'],
['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38843,'test_accession4','','plot',38857,'test_trial21','1','1','1',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','27','42','/storage/emulated/0/fieldBook/plot_data/test_trial/photos/test_trial21_2016-09-12-11-15-12.jpg','0','15','23','20','0.8','20',undef,undef,'3','0.3','18','12','2','test note1 (Operator: janedoe, Time: )'],
['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38842,'test_accession3','','plot',38866,'test_trial210','3','1','10',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','29','12',undef,'0','15',undef,'29','9.8','0',undef,undef,undef,undef,undef,'45','2',undef],
['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38840,'test_accession1','','plot',38867,'test_trial211','3','1','11',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','31','13',undef,'0','15',undef,'30','10.8',undef,undef,'4',undef,undef,'0','2','4',undef],
['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38844,'test_accession5','','plot',38868,'test_trial212','3','1','12',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','33','42',undef,'0','15',undef,'31','11.8',undef,undef,'6',undef,undef,undef,'56','7',undef],
['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38841,'test_accession2','','plot',38869,'test_trial213','2','1','13',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','35','35',undef,'1','15',undef,'32','12.8',undef,undef,'8',undef,undef,undef,'8','4.4',undef],
['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38843,'test_accession4','','plot',38870,'test_trial214','3','1','14',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','37','32',undef,'1','15',undef,'33','13.8',undef,undef,'4',undef,undef,undef,'87','7.5',undef],
['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38841,'test_accession2','','plot',38871,'test_trial215','3','1','15',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','39','31',undef,'1','15',undef,'34','14.8',undef,undef,'5',undef,undef,undef,'25','7',undef],
['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38844,'test_accession5','','plot',38858,'test_trial22','1','1','2',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','29','45','/storage/emulated/0/fieldBook/plot_data/test_trial/photos/test_trial22_2016-09-12-11-15-26.jpg','1','15',undef,'21','1.8','20','5','0','3',undef,undef,undef,'3','testnote2 (Operator: janedoe, Time: )'],
['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38842,'test_accession3','','plot',38859,'test_trial23','1','1','3',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','28','41',undef,'1','15',undef,'22','2.8','20',undef,'4','3','0.32','20','23','5',undef],
['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38842,'test_accession3','','plot',38860,'test_trial24','2','1','4',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','17','14',undef,'1','15',undef,'23','3.8','20',undef,'11','3',undef,'6','78','7',undef],
['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38840,'test_accession1','','plot',38861,'test_trial25','1','1','5',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','18','25',undef,'1','15',undef,'24','0.8','20',undef,'6','3',undef,undef,'56','2',undef],
['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38843,'test_accession4','','plot',38862,'test_trial26','2','1','6',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','21','0',undef,'1','15',undef,'25','5.8','20',undef,'4','3','0.36','18','45','4',undef],
['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38844,'test_accession5','','plot',38863,'test_trial27','2','1','7',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','23','0',undef,'1','15',undef,'26','6.8','20',undef,'8','3','0.32','14','34','9',undef],
['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38840,'test_accession1','','plot',38864,'test_trial28','2','1','8',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','13','41',undef,'0','15',undef,'27','7.8','20',undef,'9','3','0.32','14','23','6',undef],
['2014',134,'test','test',137,'test_trial','test trial','CRD',undef,undef,undef,undef,undef,'2017-July-04','2017-July-21','23','test_location',38841,'test_accession2','','plot',38865,'test_trial29','1','1','9',undef,undef,'test',undef,undef,undef,undef,undef,undef,undef,undef,undef,'','27','24',undef,'1','15',undef,'28','8.8',undef,undef,'6',undef,undef,undef,'76','3',undef]
]);

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};
print STDERR $sgn_session_id."\n";

my $stored_image_ids = [2429,2430];
my $stored_image_ids_string = encode_json $stored_image_ids;
$mech->post_ok('http://localhost:3010/ajax/image_analysis/submit?service=necrosis&selected_image_ids='.$stored_image_ids_string.'&sgn_session_id='.$sgn_session_id);
$response = decode_json $mech->content;
print STDERR Dumper $response;
is(scalar(@{$response->{results}}), 1);
is(scalar(@{$response->{results}->[0]->{details}}), 1);

my $stored_image_ids_string = encode_json $stored_image_ids;
$mech->post_ok('http://localhost:3010/ajax/image_analysis/submit?service=whitefly_count&selected_image_ids='.$stored_image_ids_string.'&sgn_session_id='.$sgn_session_id);
$response = decode_json $mech->content;
print STDERR Dumper $response;
# is(scalar(@{$response->{results}}), 1);
# is(scalar(@{$response->{results}->[0]->{details}}), 1);

my $python_dependencies_installed = `locate keras.py`;

#print STDERR "PYTHON DEPENDENCIES INSTALLED=".Dumper($python_dependencies_installed)."\n";

SKIP: {
    skip 'missing pyhton dependencies', 1 unless $python_dependencies_installed;
    my $stored_image_ids_string = encode_json $stored_image_ids;
    $mech->post_ok('http://localhost:3010/ajax/image_analysis/submit?service=largest_contour_percent&selected_image_ids='.$stored_image_ids_string.'&sgn_session_id='.$sgn_session_id);
    $response = decode_json $mech->content;
    print STDERR Dumper $response;
    is(scalar(@{$response->{results}}), 2);
    is(scalar(@{$response->{results}->[1]->{observations_array}}), 2);
    ok($response->{results}->[0]->{result}->{image_link});
    ok($response->{results}->[1]->{result}->{image_link});
}

done_testing();
