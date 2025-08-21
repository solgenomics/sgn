
use strict;
use Test::More;

use lib 't/lib';

use Data::Dumper;
use SGN::Test::Fixture;
use CXGN::Trial;
use CXGN::Phenotypes::ParseUpload;
use CXGN::Phenotypes::StorePhenotypes;

my $f = SGN::Test::Fixture->new();

my %phenotype_metadata;


my $tn = CXGN::Trial->new( { bcs_schema => $f->bcs_schema(), trial_id => 137 });

print STDERR "CREATING THE PLANT ENTRIES FOR THIS TRIAL...";
$tn->create_plant_entities(10);
print STDERR " Done.\n";

#######################################
#
# Find out table counts before adding anything, so that changes can be compared
#
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

# check that parse fails for plant spreadsheet file when using plot parser
#
my $parser = CXGN::Phenotypes::ParseUpload->new();
my $filename = "t/data/trial/upload_phenotypin_spreadsheet_plants.xlsx";
my $validate_file = $parser->validate('phenotype spreadsheet', $filename, 0, 'plots', $f->bcs_schema);
ok($validate_file != 1, "Check if parse validate plot fails for plant spreadsheet file");

$validate_file = $parser->validate('phenotype spreadsheet', $filename, 0, 'plants', $f->bcs_schema);
ok($validate_file == 1, "Check if parse validate works for plant spreadsheet file");

my $parsed_file = $parser->parse('phenotype spreadsheet', $filename, 0, 'plants', $f->bcs_schema);
ok($parsed_file, "Check if parse parse phenotype plant spreadsheet works");

print STDERR Dumper $parsed_file;

is_deeply($parsed_file,

{'units' => ['test_trial210_plant_1','test_trial210_plant_2','test_trial211_plant_1','test_trial211_plant_2','test_trial212_plant_1','test_trial212_plant_2','test_trial213_plant_1','test_trial213_plant_2','test_trial214_plant_1','test_trial214_plant_2','test_trial215_plant_1','test_trial215_plant_2','test_trial21_plant_1','test_trial21_plant_2','test_trial22_plant_1','test_trial22_plant_2','test_trial23_plant_1','test_trial23_plant_2','test_trial24_plant_1','test_trial24_plant_2','test_trial25_plant_1','test_trial25_plant_2','test_trial26_plant_1','test_trial26_plant_2','test_trial27_plant_1','test_trial27_plant_2','test_trial28_plant_1','test_trial28_plant_2','test_trial29_plant_1','test_trial29_plant_2'],'variables' => ['dry matter content percentage|CO_334:0000092','fresh root weight|CO_334:0000012'],'data' => {'test_trial23_plant_2' => {'fresh root weight|CO_334:0000012' => [['25','']],'dry matter content percentage|CO_334:0000092' => [['15','']]},'test_trial21_plant_2' => {'dry matter content percentage|CO_334:0000092' => [['11','']],'fresh root weight|CO_334:0000012' => [['21','']]},'test_trial22_plant_1' => {'fresh root weight|CO_334:0000012' => [['22','']],'dry matter content percentage|CO_334:0000092' => [['12','']]},'test_trial21_plant_1' => {'dry matter content percentage|CO_334:0000092' => [['10','']],'fresh root weight|CO_334:0000012' => [['20','']]},'test_trial22_plant_2' => {'fresh root weight|CO_334:0000012' => [['23','']],'dry matter content percentage|CO_334:0000092' => [['13','']]},'test_trial211_plant_2' => {'dry matter content percentage|CO_334:0000092' => [['31','']],'fresh root weight|CO_334:0000012' => [['41','']]},'test_trial23_plant_1' => {'fresh root weight|CO_334:0000012' => [['24','']],'dry matter content percentage|CO_334:0000092' => [['14','']]},'test_trial28_plant_2' => {'dry matter content percentage|CO_334:0000092' => [['25','']],'fresh root weight|CO_334:0000012' => [['35','']]},'test_trial215_plant_1' => {'fresh root weight|CO_334:0000012' => [['48','']],'dry matter content percentage|CO_334:0000092' => [['38','']]},'test_trial214_plant_1' => {'fresh root weight|CO_334:0000012' => [['46','']],'dry matter content percentage|CO_334:0000092' => [['36','']]},'test_trial29_plant_1' => {'dry matter content percentage|CO_334:0000092' => [['26','']],'fresh root weight|CO_334:0000012' => [['36','']]},'test_trial25_plant_1' => {'dry matter content percentage|CO_334:0000092' => [['18','']],'fresh root weight|CO_334:0000012' => [['28','']]},'test_trial29_plant_2' => {'fresh root weight|CO_334:0000012' => [['37','']],'dry matter content percentage|CO_334:0000092' => [['27','']]},'test_trial25_plant_2' => {'dry matter content percentage|CO_334:0000092' => [['','']],'fresh root weight|CO_334:0000012' => [['29','']]},'test_trial28_plant_1' => {'dry matter content percentage|CO_334:0000092' => [['0','']],'fresh root weight|CO_334:0000012' => [['34','']]},'test_trial213_plant_2' => {'dry matter content percentage|CO_334:0000092' => [['35','']],'fresh root weight|CO_334:0000012' => [['45','']]},'test_trial212_plant_1' => {'fresh root weight|CO_334:0000012' => [['42','']],'dry matter content percentage|CO_334:0000092' => [['32','']]},'test_trial210_plant_2' => {'fresh root weight|CO_334:0000012' => [['','']],'dry matter content percentage|CO_334:0000092' => [['29','']]},'test_trial211_plant_1' => {'fresh root weight|CO_334:0000012' => [['40','']],'dry matter content percentage|CO_334:0000092' => [['30','']]},'test_trial26_plant_1' => {'dry matter content percentage|CO_334:0000092' => [['20','']],'fresh root weight|CO_334:0000012' => [['30','']]},'test_trial210_plant_1' => {'dry matter content percentage|CO_334:0000092' => [['28','']],'fresh root weight|CO_334:0000012' => [['38','']]},'test_trial212_plant_2' => {'fresh root weight|CO_334:0000012' => [['43','']],'dry matter content percentage|CO_334:0000092' => [['33','']]},'test_trial213_plant_1' => {'dry matter content percentage|CO_334:0000092' => [['34','']],'fresh root weight|CO_334:0000012' => [['44','']]},'test_trial24_plant_1' => {'dry matter content percentage|CO_334:0000092' => [['16','']],'fresh root weight|CO_334:0000012' => [['26','']]},'test_trial27_plant_2' => {'fresh root weight|CO_334:0000012' => [['33','']],'dry matter content percentage|CO_334:0000092' => [['23','']]},'test_trial24_plant_2' => {'dry matter content percentage|CO_334:0000092' => [['17','']],'fresh root weight|CO_334:0000012' => [['27','']]},'test_trial215_plant_2' => {'fresh root weight|CO_334:0000012' => [['49','']],'dry matter content percentage|CO_334:0000092' => [['39','']]},'test_trial214_plant_2' => {'fresh root weight|CO_334:0000012' => [['47','']],'dry matter content percentage|CO_334:0000092' => [['37','']]},'test_trial27_plant_1' => {'fresh root weight|CO_334:0000012' => [['32','']],'dry matter content percentage|CO_334:0000092' => [['22','']]},'test_trial26_plant_2' => {'fresh root weight|CO_334:0000012' => [['0','']],'dry matter content percentage|CO_334:0000092' => [['21','']]}}},  "check plant spreadsheet file was parsed");

$phenotype_metadata{'archived_file'} = $filename;
$phenotype_metadata{'archived_file_type'}="spreadsheet phenotype file";
$phenotype_metadata{'operator'}="janedoe";
$phenotype_metadata{'date'}="2016-02-16_05:15:21";
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
    overwrite_values=>1,
    metadata_hash=>\%phenotype_metadata,
    composable_validation_check_name=>$f->config->{composable_validation_check_name}
    );

my ($verified_warning, $verified_error) = $store_phenotypes->verify();
ok(!$verified_error);
my ($stored_phenotype_error_msg, $store_success) = $store_phenotypes->store();
ok(!$stored_phenotype_error_msg, "check that store large pheno spreadsheet works");



my $traits_assayed  = $tn->get_traits_assayed();
my @traits_assayed_sorted = sort {$a->[0] cmp $b->[0]} @$traits_assayed;
print STDERR "TRAITS ASSAYED: ". Dumper \@traits_assayed_sorted;

my @traits_expected = (
          [
            70666,
            'fresh root weight|CO_334:0000012',
            [],
            29,
            undef,
            undef
          ],
          [
            70741,
            'dry matter content percentage|CO_334:0000092',
            [],
            29,
            undef,
            undef
          ]
    );

my @traits_expected_sorted = sort { $a->[0] cmp $b->[0] } @traits_expected;

print STDERR "TRAITS EXPECTED: ".Dumper(\@traits_expected_sorted);

is_deeply(\@traits_assayed_sorted, \@traits_expected_sorted, 'check traits assayed after plant upload' );

my @pheno_for_trait = $tn->get_phenotypes_for_trait(70666);
my @pheno_for_trait_sorted = sort {$a <=> $b} @pheno_for_trait;
print STDERR "TRAIT 70666: ".Dumper \@pheno_for_trait_sorted;

@traits_expected = (
          0,
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
          37,
          38,
          40,
          41,
          42,
          43,
          44,
          45,
          46,
          47,
          48,
          49
        );

@traits_expected_sorted = sort(@traits_expected);

is_deeply(\@pheno_for_trait_sorted, \@traits_expected_sorted,  'check pheno traits 70666 after plant upload' );

@pheno_for_trait = $tn->get_phenotypes_for_trait(70727);
@pheno_for_trait_sorted = sort {$a <=> $b} @pheno_for_trait;

print STDERR "TRAITS FOR 70727: ".Dumper \@pheno_for_trait_sorted;

is_deeply(\@pheno_for_trait_sorted, [], "check pheno trait 70727 after plant upload.");

# Upload a plant-based phenotyping file in Fieldbook format
#
$parser = CXGN::Phenotypes::ParseUpload->new();
$filename = "t/data/fieldbook/fieldbook_phenotype_plants_file.csv";

$validate_file = $parser->validate('field book', $filename, 1, 'plants', $f->bcs_schema);
ok($validate_file == 1, "Check if parse validate works for plant fieldbook file");

$parsed_file = $parser->parse('field book', $filename, 1, 'plots', $f->bcs_schema);
ok($parsed_file, "Check if parse parse phenotype plant fieldbook works");

print STDERR Dumper $parsed_file;

is_deeply($parsed_file, {'units' => ['test_trial21_plant_1','test_trial21_plant_2','test_trial22_plant_1','test_trial22_plant_2','test_trial23_plant_1','test_trial23_plant_2'],'data' => {'test_trial23_plant_2' => {'dry matter content|CO_334:0000092' => [['41','2016-01-07 12:08:27-0500','johndoe','']]},'test_trial23_plant_1' => {'dry matter content|CO_334:0000092' => [['41','2016-01-07 12:08:27-0500','johndoe','']]},'test_trial22_plant_1' => {'dry matter content|CO_334:0000092' => [['45','2016-01-07 12:08:26-0500','johndoe','']],'dry yield|CO_334:0000014' => [['45','2016-01-07 12:08:26-0500','johndoe','']]},'test_trial22_plant_2' => {'dry yield|CO_334:0000014' => [['0','2016-01-07 12:08:26-0500','johndoe','']],'dry matter content|CO_334:0000092' => [['45','2016-01-07 12:08:26-0500','johndoe','']]},'test_trial21_plant_1' => {'dry yield|CO_334:0000014' => [['42','2016-01-07 12:08:24-0500','johndoe','']],'dry matter content|CO_334:0000092' => [['42','2016-01-07 12:08:24-0500','johndoe','']]},'test_trial21_plant_2' => {'dry matter content|CO_334:0000092' => [['42','2016-01-07 12:08:24-0500','johndoe','']],'dry yield|CO_334:0000014' => [['0','2016-01-07 12:08:24-0500','johndoe','']]}},'variables' => ['dry matter content|CO_334:0000092','dry yield|CO_334:0000014']}, "check parse fieldbook plant file");

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
    overwrite_values=>1,
    metadata_hash=>\%phenotype_metadata,
    composable_validation_check_name=>$f->config->{composable_validation_check_name}
);
my ($verified_warning, $verified_error) = $store_phenotypes->verify();
ok(!$verified_error);
my ($stored_phenotype_error_msg, $store_success) = $store_phenotypes->store();
ok(!$stored_phenotype_error_msg, "check that store fieldbook plants works");

$tn = CXGN::Trial->new( { bcs_schema => $f->bcs_schema(),
	trial_id => 137 });

$traits_assayed  = $tn->get_traits_assayed();
@traits_assayed_sorted = sort {$a->[0] cmp $b->[0]} @$traits_assayed;
print STDERR "TRAITS ASSAYED NOW: ".Dumper \@traits_assayed_sorted;

is_deeply(\@traits_assayed_sorted, [
          [
            70666,
            'fresh root weight|CO_334:0000012',
            [],
            29,
            undef,
            undef
          ],
          [
            70727,
            'dry yield|CO_334:0000014',
            [],
            4,
            undef,
            undef
          ],
          [
            70741,
            'dry matter content percentage|CO_334:0000092',
            [],
            29,
            undef,
            undef
          ]
	  ]


#	  [[70666,'fresh root weight|CO_334:0000012',[],45,undef,undef],[70668,'harvest index variable|CO_334:0000015',[],15,undef,undef],[70681,'top yield|CO_334:0000017',[],15,undef,undef],[70700,'sprouting proportion|CO_334:0000008',[],15,undef,undef],[70706,'root number counting|CO_334:0000011',[],14,undef,undef],[70713,'flower|CO_334:0000111',[],15,undef,undef],[70727,'dry yield|CO_334:0000014',[],19,undef,undef],[70741,'dry matter content percentage|CO_334:0000092',[],44,undef,undef],[70773,'fresh shoot weight measurement in kg|CO_334:0000016',[],15,undef,undef]]

	  , 'check traits assayed after plant upload 2' );

my $files_uploaded = $tn->get_phenotype_metadata();
my %file_names;
foreach (@$files_uploaded){
    $file_names{$_->[4]} = [$_->[4], $_->[6]];
}

#print STDERR Dumper \%file_names;
my $found_timestamp_name;
foreach (keys %file_names){
    if (index($_, '_upload_phenotypin_spreadsheet.xlsx') != -1) {
	$found_timestamp_name = 1;
	delete($file_names{$_});
    }
}
#ok($found_timestamp_name);

print STDERR "UPLOAD METADATA: ".Dumper(\%file_names);

is(scalar(keys(%file_names)), 2, "check uploaded file count");

# my $experiment = $f->bcs_schema->resultset('NaturalDiversity::NdExperiment')->search({type_id => $phenotyping_experiment_cvterm_id}, {order_by => {-asc => 'nd_experiment_id'}});
# my $post1_experiment_count = $experiment->count();
# my $post1_experiment_diff = $post1_experiment_count - $pre_experiment_count;
# print STDERR "Experiment count: ".$post1_experiment_diff."\n";
# ok($post1_experiment_diff == 113, "Check num rows in NdExperiment table after addition of tablet file with plants upload");

# my @nd_experiment_table;
# my $nd_experiment_table_tail = $experiment->slice($post1_experiment_count-323, $post1_experiment_count);
# while (my $rs = $nd_experiment_table_tail->next() ) {
#   push @nd_experiment_table, [nd_experiment_id=> $rs->nd_experiment_id(), nd_geolocation_id=> $rs->nd_geolocation_id(), type_id=> $rs->type_id()];
# }
# #print STDERR Dumper \@nd_experiment_table;

# my $phenotype_rs = $f->bcs_schema->resultset('Phenotype::Phenotype')->search({});
# my $post1_phenotype_count = $phenotype_rs->count();
# my $post1_phenotype_diff = $post1_phenotype_count - $pre_phenotype_count;
# print STDERR "Phenotype count: ".$post1_phenotype_diff."\n";
# ok($post1_phenotype_diff == 196, "Check num rows in Phenotype table after addition of tablet file with plants upload");

# my @pheno_table;
# my $pheno_table_tail = $phenotype_rs->slice($post1_phenotype_count-323, $post1_phenotype_count);
# while (my $rs = $pheno_table_tail->next() ) {
#   push @pheno_table, [phenotype_id=> $rs->phenotype_id(), observable_id=> $rs->observable_id(), attr_id=> $rs->attr_id(), value=> $rs->value(), cvalue_id=>$rs->cvalue_id(), assay_id=>$rs->assay_id()];
# }
# #print STDERR Dumper \@pheno_table;

# my $exp_prop_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentprop')->search({});
# my $post1_exp_prop_count = $exp_prop_rs->count();
# my $post1_exp_prop_diff = $post1_exp_prop_count - $pre_exp_prop_count;
# print STDERR "Experimentprop count: ".$post1_exp_prop_diff."\n";
# ok($post1_exp_prop_diff == 226, "Check num rows in Experimentprop table after addition of tablet file with plants upload");

# my @exp_prop_table;
# my $exp_prop_table_tail = $exp_prop_rs->slice($post1_exp_prop_count-646, $post1_exp_prop_count);
# while (my $rs = $exp_prop_table_tail->next() ) {
#   push @exp_prop_table, [nd_experimentprop_id=> $rs->nd_experimentprop_id(), nd_experiment_id=> $rs->nd_experiment_id(), type_id=> $rs->type_id(), value=> $rs->value(), rank=> $rs->rank()];
# }
# #print STDERR Dumper \@exp_prop_table;

# my $exp_proj_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentProject')->search({});
# my $post1_exp_proj_count = $exp_proj_rs->count();
# my $post1_exp_proj_diff = $post1_exp_proj_count - $pre_exp_proj_count;
# print STDERR "Experimentproject count: ".$post1_exp_proj_diff."\n";
# ok($post1_exp_proj_diff == 113, "Check num rows in NdExperimentproject table after addition of tablet file with plants upload");

# my @exp_proj_table;
# my $exp_proj_table_tail = $exp_proj_rs->slice($post1_exp_proj_count-323, $post1_exp_proj_count);
# while (my $rs = $exp_proj_table_tail->next() ) {
#   push @exp_proj_table, [nd_experiment_project_id=> $rs->nd_experiment_project_id(), nd_experiment_id=> $rs->nd_experiment_id(), project_id=> $rs->project_id()];
# }
# #print STDERR Dumper \@exp_proj_table;

# my $exp_stock_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentStock')->search({});
# my $post1_exp_stock_count = $exp_stock_rs->count();
# my $post1_exp_stock_diff = $post1_exp_stock_count - $pre_exp_stock_count;
# print STDERR "Experimentstock count: ".$post1_exp_stock_diff."\n";
# #ok($post1_exp_stock_diff == $nd_experiment_stock_number+6, "Check num rows in NdExperimentstock table after addition of tablet file with plants upload");

# my @exp_stock_table;
# my $exp_stock_table_tail = $exp_stock_rs->slice($post1_exp_stock_count-323, $post1_exp_stock_count);
# while (my $rs = $exp_stock_table_tail->next() ) {
#   push @exp_stock_table, [nd_experiment_stock_id=> $rs->nd_experiment_stock_id(), nd_experiment_id=> $rs->nd_experiment_id(), stock_id=> $rs->stock_id(), type_id=> $rs->type_id()];
# }
# #print STDERR Dumper \@exp_stock_table;

# my $exp_pheno_rs = $f->bcs_schema->resultset('NaturalDiversity::NdExperimentPhenotype')->search({});
# my $post1_exp_pheno_count = $exp_pheno_rs->count();
# my $post1_exp_pheno_diff = $post1_exp_pheno_count - $pre_exp_pheno_count;
# print STDERR "Experimentphenotype count: ".$post1_exp_pheno_diff."\n";
# ok($post1_exp_pheno_diff == 196, "Check num rows in NdExperimentphenotype table after addition of tablet file with plants upload");

# my @exp_pheno_table;
# my $exp_pheno_table_tail = $exp_pheno_rs->slice($post1_exp_pheno_count-323, $post1_exp_pheno_count);
# while (my $rs = $exp_pheno_table_tail->next() ) {
#   push @exp_pheno_table, [nd_experiment_phenotype_id=> $rs->nd_experiment_phenotype_id(), nd_experiment_id=> $rs->nd_experiment_id(), phenotype_id=> $rs->phenotype_id()];
# }
# #print STDERR Dumper \@exp_pheno_table;

# my $md_rs = $f->metadata_schema->resultset('MdMetadata')->search({});
# my $post1_md_count = $md_rs->count();
# my $post1_md_diff = $post1_md_count - $pre_md_count;
# print STDERR "MdMetadata count: ".$post1_md_diff."\n";
# ok($post1_md_diff == 10, "Check num rows in MdMetadata table after addition of tablet file with plants upload");

# my @md_table;
# my $md_table_tail = $md_rs->slice($post1_md_count-5, $post1_md_count);
# while (my $rs = $md_table_tail->next() ) {
#   push @md_table, [metadata_id => $rs->metadata_id(), create_person_id=> $rs->create_person_id()];
# }
# #print STDERR Dumper \@md_table;

# my $md_files_rs = $f->metadata_schema->resultset('MdFiles')->search({});
# my $post1_md_files_count = $md_files_rs->count();
# my $post1_md_files_diff = $post1_md_files_count - $pre_md_files_count;
# print STDERR "MdFiles count: ".$post1_md_files_diff."\n";
# ok($post1_md_files_diff == 8, "Check num rows in MdFiles table after addition of tablet file with plants upload");

# my @md_files_table;
# my $md_files_table_tail = $md_files_rs->slice($post1_md_files_count-5, $post1_md_files_count);
# while (my $rs = $md_files_table_tail->next() ) {
#   push @md_files_table, [file_id => $rs->file_id(), basename=> $rs->basename(), dirname=> $rs->dirname(), filetype=> $rs->filetype(), alt_filename=>$rs->alt_filename(), comment=>$rs->comment(), urlsource=>$rs->urlsource()];
# }
# #print STDERR Dumper \@md_files_table;

# my $exp_md_files_rs = $f->phenome_schema->resultset('NdExperimentMdFiles')->search({});
# my $post1_exp_md_files_count = $exp_md_files_rs->count();
# my $post1_exp_md_files_diff = $post1_exp_md_files_count - $pre_exp_md_files_count;
# print STDERR "Experimentphenotype count: ".$post1_exp_md_files_diff."\n";
# ok($post1_exp_md_files_diff == 113, "Check num rows in NdExperimentMdFIles table after addition of tablet file with plants upload");

# my @exp_md_files_table;
# my $exp_md_files_table_tail = $exp_md_files_rs->slice($post1_exp_md_files_count-324, $post1_exp_md_files_count-1);
# while (my $rs = $exp_md_files_table_tail->next() ) {
#   push @exp_md_files_table, [nd_experiment_md_files_id => $rs->nd_experiment_md_files_id(), nd_experiment_id=> $rs->nd_experiment_id(), file_id=> $rs->file_id()];
# }
#print STDERR Dumper \@exp_md_files_table;

#if ($@) {
#    print STDERR "An error occurred: $@\n";
#}

#$f->dbh()->rollback();

done_testing();

$f->clean_up_db();
