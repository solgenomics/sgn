
use strict;
use Test::More 'no_plan';
use Data::Dumper;
use lib 't/lib';
use SGN::Test::Fixture;
use CXGN::Dataset;
use CXGN::Analysis;
use CXGN::Analysis::AnalysisCreate;
use CXGN::AnalysisModel::GetModel;
use CXGN::BreederSearch;
use JSON;
use Test::WWW::Mechanize;
use File::Basename;

print STDERR "Starting test...\n";
my $t = SGN::Test::Fixture->new();
my $schema = $t->bcs_schema();
my $dbh = $t->dbh();
my $people_schema = $t->people_schema();
my $metadata_schema = $t->metadata_schema();
my $phenome_schema = $t->phenome_schema();

$dbh->begin_work();

my $mech = Test::WWW::Mechanize->new;

my $ds = CXGN::Dataset->new( people_schema => $t->people_schema(), schema => $t->bcs_schema());
$ds->accessions( [ 38913, 38914, 38915 ]);
$ds->years(['2012', '2013']);
$ds->traits([ 70666, 70741 ]);
$ds->trials([ 139, 144 ]);
$ds->plots( [ 40034, 40035 ]);
$ds->name("test");
$ds->description("test description");

$ds->name("test");
$ds->description("test description");
$ds->sp_person_id(41);

my $sp_dataset_id = $ds->store();

print STDERR "Dataset_id = $sp_dataset_id\n";

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};
print STDERR $sgn_session_id."\n";

my $field_trial_id = 165;
my $trait_ids = ['77559','77557'];
my $analysis_breeding_program_id = $schema->resultset("Project::Project")->find({name=>'test'})->project_id();

$mech->post_ok('http://localhost:3010/api/drone_imagery/calculate_statistics', [ "statistics_select"=> "lmer_germplasmname_replicate", "field_trial_id_list"=> encode_json [$field_trial_id], "observation_variable_id_list"=> encode_json $trait_ids ]);
my $response = decode_json $mech->content;
print STDERR Dumper $response;
ok($response->{stats_out_tempfile});
is($response->{analysis_model_type}, 'lmer_germplasmname_replicate');
is_deeply($response->{unique_accessions}, [
                                   'IITA-TMS-IBA011412',
                                   'IITA-TMS-IBA30572',
                                   'IITA-TMS-IBA980002',
                                   'IITA-TMS-IBA980581',
                                   'TMEB419',
                                   'TMEB693'
                                 ]);
is_deeply($response->{unique_traits}, [
                               'cass sink leaf|3-phosphoglyceric acid|ug/g|week 16|COMP:0000013',
                               'cass sink leaf|ADP alpha-D-glucoside|ug/g|week 16|COMP:0000011'
                             ]);
ok($response->{analysis_model_training_data_file_type});
is($response->{statistical_ontology_term}, 'Univariate linear mixed model genetic BLUPs using germplasmName computed using LMER R|SGNSTAT:0000002');
is($response->{application_name}, 'NickMorales Mixed Models');
ok($response->{application_version});
is($response->{analysis_model_language}, 'R');
is($response->{analysis_result_values_type}, 'analysis_result_values_match_accession_names');
ok($response->{stats_tempfile});
my %result_blup_genetic_data_no_timestamps;
while(my($k,$v) = each %{$response->{result_blup_genetic_data}}) {
    while(my($k1,$v1) = each %$v) {
        ok(defined($v1->[0]));
        $result_blup_genetic_data_no_timestamps{$k}->{$k1} = $v1->[0];
    }
}
is_deeply(\%result_blup_genetic_data_no_timestamps, {
                                          'IITA-TMS-IBA980002' => {
                                                                    'cass sink leaf|3-phosphoglyceric acid|ug/g|week 16|COMP:0000013' => '-66.8437119136587',
                                                                    'cass sink leaf|ADP alpha-D-glucoside|ug/g|week 16|COMP:0000011' => '0'
                                                                  },
                                          'TMEB419' => {
                                                         'cass sink leaf|ADP alpha-D-glucoside|ug/g|week 16|COMP:0000011' => '0',
                                                         'cass sink leaf|3-phosphoglyceric acid|ug/g|week 16|COMP:0000013' => '-63.0930280648434'
                                                       },
                                          'IITA-TMS-IBA30572' => {
                                                                   'cass sink leaf|ADP alpha-D-glucoside|ug/g|week 16|COMP:0000011' => '0',
                                                                   'cass sink leaf|3-phosphoglyceric acid|ug/g|week 16|COMP:0000013' => '73.0440483006472'
                                                                 },
                                          'IITA-TMS-IBA980581' => {
                                                                    'cass sink leaf|3-phosphoglyceric acid|ug/g|week 16|COMP:0000013' => '0.533200041783611',
                                                                    'cass sink leaf|ADP alpha-D-glucoside|ug/g|week 16|COMP:0000011' => '0'
                                                                  },
                                          'IITA-TMS-IBA011412' => {
                                                                    'cass sink leaf|3-phosphoglyceric acid|ug/g|week 16|COMP:0000013' => '77.8812579916274',
                                                                    'cass sink leaf|ADP alpha-D-glucoside|ug/g|week 16|COMP:0000011' => '0'
                                                                  },
                                          'TMEB693' => {
                                                         'cass sink leaf|ADP alpha-D-glucoside|ug/g|week 16|COMP:0000011' => '0',
                                                         'cass sink leaf|3-phosphoglyceric acid|ug/g|week 16|COMP:0000013' => '-21.5217663555557'
                                                       }
                                        });

my $protocol = 'lme(t1~replicate + 1|germplasmName, data=mat, na.action = na.omit)';

my @allowed_composed_cvs = split ',', $t->config->{composable_cvs};
my $composable_cvterm_delimiter = $t->config->{composable_cvterm_delimiter};
my $composable_cvterm_format = $t->config->{composable_cvterm_format};

print STDERR "Start add analysis...\n";

my $m = CXGN::Analysis::AnalysisCreate->new({
    bcs_schema=>$schema,
    people_schema=>$people_schema,
    metadata_schema=>$metadata_schema,
    phenome_schema=>$phenome_schema,
    archive_path=>$t->config->{archive_path},
    tempfile_for_deleting_nd_experiment_ids=>"/tmp/nd_experiment_id_del_file",
    base_path=>$t->config->{basepath},
    dbhost=>$t->config->{dbhost},
    dbname=>$t->config->{dbname},
    dbuser=>$t->config->{dbuser},
    dbpass=>$t->config->{dbpass},
    analysis_to_save_boolean=>'yes',
    analysis_name=>'analysis1',
    analysis_description=>'analysis description',
    analysis_year=>'2020',
    analysis_breeding_program_id=>$analysis_breeding_program_id,
    analysis_protocol=>$protocol,
    analysis_dataset_id=>undef,
    analysis_accession_names=>$response->{unique_accessions},
    analysis_trait_names=>$response->{unique_traits},
    analysis_statistical_ontology_term=>$response->{statistical_ontology_term},
    analysis_precomputed_design_optional=>undef,
    analysis_result_values=>$response->{result_blup_genetic_data},
    analysis_result_values_type=>$response->{analysis_result_values_type},
    analysis_result_summary=>{
        'genetic_variance'=>0.1,
        'res1'=>1
    },
    analysis_model_name=>'analysismodel1',
    analysis_model_description=>'analysis model description',
    analysis_model_is_public=>'yes',
    analysis_model_language=>$response->{analysis_model_language},
    analysis_model_type=>$response->{analysis_model_type},
    analysis_model_properties=>{
        'protocol'=>$protocol,
        'arbitrary_property'=>0.001
    },
    analysis_model_application_name=>$response->{application_name},
    analysis_model_application_version=>$response->{application_version},
    analysis_model_file=>undef,
    analysis_model_file_type=>undef,
    analysis_model_training_data_file=>$response->{stats_tempfile},
    analysis_model_training_data_file_type=>$response->{analysis_model_training_data_file_type},
    analysis_model_auxiliary_files=>[],
    allowed_composed_cvs=>\@allowed_composed_cvs,
    composable_cvterm_delimiter=>$composable_cvterm_delimiter,
    composable_cvterm_format=>$composable_cvterm_format,
    user_id=>41,
    user_name=>'janedoe',
    user_role=>'curator'
});

print STDERR "Storing Analysis...\n";
my $saved_analysis_object = $m->store();


print STDERR Dumper $saved_analysis_object;
is_deeply($saved_analysis_object, {
          'model_id' => 3,
          'success' => 1,
          'analysis_id' => 166,
        });
print STDERR "End add analysis...\n";

my $m = CXGN::AnalysisModel::GetModel->new({
    bcs_schema=>$schema,
    metadata_schema=>$metadata_schema,
    phenome_schema=>$phenome_schema,
    nd_protocol_id=>$saved_analysis_object->{model_id}
});
my $saved_model_object = $m->get_model();
print STDERR Dumper $saved_model_object;
is($saved_model_object->{model_name}, 'analysismodel1');
is($saved_model_object->{model_description}, 'analysis model description');
is_deeply($saved_model_object->{model_properties}, {
                                  'model_is_public' => 'yes',
                                  'dataset_id' => undef,
                                  'protocol' => 'lme(t1~replicate + 1|germplasmName, data=mat, na.action = na.omit)',
                                  'application_version' => 'V1.01',
                                  'application_name' => 'NickMorales Mixed Models',
                                  'model_language' => 'R',
                                  'arbitrary_property' => '0.001'
                                });

sleep(5);
my $a = CXGN::Analysis->new({
    bcs_schema => $schema,
    people_schema => $people_schema,
    metadata_schema => $metadata_schema,
    phenome_schema => $phenome_schema,
    trial_id => $saved_analysis_object->{analysis_id}
});
my $stored_analysis_phenotypes = $a->get_phenotype_matrix();
print STDERR Dumper $stored_analysis_phenotypes;
is(scalar(@$stored_analysis_phenotypes), 7);

my $analysis_result_file = $t->config->{basepath}."/t/data/analysis/analysis_results_accessions.csv";
my $analysis_training_data_file_dummy = $t->config->{basepath}."/t/data/trial/upload_phenotypin_spreadsheet.xls";
my $ua = LWP::UserAgent->new;
my $response_upload_analysis = $ua->post(
        'http://localhost:3010/ajax/analysis/store/spreadsheet',
        Content_Type => 'form-data',
        Content => [
            "sgn_session_id"=>$sgn_session_id,
            "upload_new_analysis_name"=>"upload_analysis_01",
            "upload_new_analysis_description"=>"analysis description",
            "upload_new_analysis_year"=>"2020",
            "upload_new_analysis_breeding_program_id"=>$analysis_breeding_program_id,
            "upload_new_analysis_protocol"=>"lm(t1 ~ some formula to describe analysis)",
            "upload_new_analysis_dataset_id"=>"",
            upload_new_analysis_file => [ $analysis_result_file, basename($analysis_result_file) ],
            "upload_new_analysis_statistical_ontology_term"=>"Univariate linear mixed model genetic BLUPs using germplasmName computed using LMER R|SGNSTAT:0000002",
            "upload_new_analysis_result_values_type"=>"analysis_result_values_match_accession_names",
            "upload_new_analysis_result_summary_string"=>"variance:0.9,total:1.0",
            "upload_new_analysis_model_name"=>"upload_analysis_model_1",
            "upload_new_analysis_model_description"=>"upload_analysis_model_1 description",
            "upload_new_analysis_model_is_public"=>"yes",
            "upload_new_analysis_model_language"=>"R",
            "upload_new_analysis_model_properties_string"=>"arbitraryprop:1,protocol_id:1",
            "upload_new_analysis_model_application_name"=>"myPipeline",
            "upload_new_analysis_model_application_version"=>"v1",
            upload_new_analysis_model_training_data_file => [ $analysis_training_data_file_dummy, basename($analysis_training_data_file_dummy) ],
            "upload_new_analysis_model_training_data_file_type"=>"myPipelinev1_training_pheno_file",
            upload_new_analysis_model_auxiliary_file_1 => [ $analysis_training_data_file_dummy, basename($analysis_training_data_file_dummy) ],
            "upload_new_analysis_model_auxiliary_file_type_1"=>"myPipelinev1_log_file",
            upload_new_analysis_model_auxiliary_file_2 => [ $analysis_training_data_file_dummy, basename($analysis_training_data_file_dummy) ],
            "upload_new_analysis_model_auxiliary_file_type_2"=>"myPipelinev1_grm_file",
            upload_new_analysis_model_file => [ $analysis_training_data_file_dummy, basename($analysis_training_data_file_dummy) ],
            "upload_new_analysis_model_file_type"=>"myPipelinev1_model_weights_file",
        ]
    );

ok($response_upload_analysis->is_success);
my $message_uploaded_analysis = $response_upload_analysis->decoded_content;
my $message_hash_uploaded_analysis = decode_json $message_uploaded_analysis;
print STDERR Dumper $message_hash_uploaded_analysis;
ok($message_hash_uploaded_analysis->{analysis_id});

print STDERR "ANALYSIS IDS: $message_hash_uploaded_analysis->{analysis_id} $saved_analysis_object->{analysis_id}\n";

sleep(5);
my $a = CXGN::Analysis->new({
    bcs_schema => $schema,
    people_schema => $people_schema,
    metadata_schema => $metadata_schema,
    phenome_schema => $phenome_schema,
    trial_id => $message_hash_uploaded_analysis->{analysis_id}
});
my $stored_analysis_phenotypes = $a->get_phenotype_matrix();
print STDERR Dumper $stored_analysis_phenotypes;
is(scalar(@$stored_analysis_phenotypes), 6);

print STDERR "DELETE ANALYSIS & DATASET...\n";

$a->delete_phenotype_metadata($metadata_schema, $phenome_schema);

$a->delete_phenotype_data($t->config->{basepath}, $t->config->{dbhost}, $t->config->{dbname}, $t->config->{dbuser}, $t->config->{dbpass}, $t->config->{cluster_shared_tempdir}."/test_temp_nd_experiment_id_delete");

$a->delete_field_layout();

$a->delete_project_entry();


my $b = CXGN::Analysis->new({
    bcs_schema => $schema,
    people_schema => $people_schema,
    metadata_schema => $metadata_schema,
    phenome_schema => $phenome_schema,
    trial_id => $saved_analysis_object->{analysis_id}
});

$b->delete_phenotype_metadata($metadata_schema, $phenome_schema);

$b->delete_phenotype_data($t->config->{basepath}, $t->config->{dbhost}, $t->config->{dbname}, $t->config->{dbuser}, $t->config->{dbpass}, $t->config->{cluster_shared_tempdir}."/test_temp_nd_experiment_id_delete");

$b->delete_field_layout();

$b->delete_project_entry();




$ds->delete();

print STDERR "REFRESHING MATVIEWS...\n";

CXGN::BreederSearch->new( { dbh => $dbh })->refresh_matviews($t->config->{dbhost}, $t->config->{dbname},  $t->config->{dbuser}, $t->config->{dbpass}, 'fullview', 'basic', $t->config->{basepath});

CXGN::BreederSearch->new( { dbh => $dbh })->refresh_matviews($t->config->{dbhost}, $t->config->{dbname},  $t->config->{dbuser}, $t->config->{dbpass}, 'stockprops', 'basic', $t->config->{basepath});

print STDERR "Rolling back...\n";
$dbh->rollback();

done_testing();

