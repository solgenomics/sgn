
use strict;
use Test::More 'no_plan';
use Data::Dumper;
use lib 't/lib';
use SGN::Test::Fixture;
use CXGN::Analysis;
use CXGN::Analysis::AnalysisCreate;
use JSON;
use Test::WWW::Mechanize;

print STDERR "Starting test...\n";
my $t = SGN::Test::Fixture->new();
my $schema = $t->bcs_schema();
my $dbh = $t->dbh();
my $people_schema = $t->people_schema();
my $metadata_schema = $t->metadata_schema();
my $phenome_schema = $t->phenome_schema();

my $mech = Test::WWW::Mechanize->new;

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
    analysis_statistical_ontology_term=>"Univariate linear mixed model genetic BLUPs using germplasmName computed using LMER R|SGNSTAT:0000002",
    analysis_precomputed_design_optional=>undef,
    analysis_result_values=>$response->{result_blup_genetic_data},
    analysis_result_values_type=>'analysis_result_values_match_accession_names',
    analysis_result_summary=>{'genetic_variance'=>0.1, 'res1'=>1},
    analysis_model_name=>'analysismodel1',
    analysis_model_description=>'analysis model description',
    analysis_model_is_public=>'yes',
    analysis_model_language=>'R',
    analysis_model_type=>'lmer_germplasmname_replicate',
    analysis_model_properties=>{
        'protocol'=>$protocol,
        'arbitrary_property'=>0.001
    },
    analysis_model_application_name=>'NickMorales Mixed Models',
    analysis_model_application_version=>'V1.01',
    analysis_model_file=>undef,
    analysis_model_file_type=>undef,
    analysis_model_training_data_file=>$response->{stats_tempfile},
    analysis_model_training_data_file_type=>'nicksmixedmodels_v1.01_lmer_germplasmname_replicate_phenotype_file',
    analysis_model_auxiliary_files=>[],
    allowed_composed_cvs=>\@allowed_composed_cvs,
    composable_cvterm_delimiter=>$composable_cvterm_delimiter,
    composable_cvterm_format=>$composable_cvterm_format,
    user_id=>41,
    user_name=>'janedoe',
    user_role=>'curator'
});
my $saved_analysis_object = $m->store();
print STDERR Dumper $saved_analysis_object;
is($saved_analysis_object->{success}, 1);
print STDERR "End add analysis...\n";

print STDERR "Rolling back...\n";
$dbh->rollback();

done_testing();

