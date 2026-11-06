# Execute only after the root's fixture-writing phase has finished.
# Actual Native export, protocol persistence, archived bytes and metadata links.
use strict;
use warnings;
use Test::More;
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use Cwd qw(getcwd);
use File::Slurp qw(read_file write_file);
use Digest::MD5 qw(md5_hex);
use JSON qw(decode_json);
use lib 't/lib';
use SGN::Test::Fixture;
use SGN::Model::solGS::solGS;
use CXGN::Analysis::AnalysisCreate;

my $fixture=SGN::Test::Fixture->new();
my $schema=$fixture->bcs_schema;
# Standard product schema handles/autocommit; the root grants this test an
# exclusive fixture-write slot. Platform cleanup removes only newly added rows.
my $cleanup_needed=1;
END { eval {$fixture->clean_up_db()} if $cleanup_needed; }
my $dbh=$schema->storage->dbh;
my ($trial)=$dbh->selectrow_array(q{
  SELECT ep.project_id FROM nd_experiment_project ep
  JOIN nd_experiment_phenotype ph USING(nd_experiment_id)
  JOIN nd_experiment_stock es USING(nd_experiment_id)
  JOIN stock s ON s.stock_id=es.stock_id
  JOIN cvterm type ON type.cvterm_id=s.type_id
  WHERE type.name='plot' ORDER BY ep.project_id LIMIT 1
});
BAIL_OUT('No phenotype-bearing field trial in the isolated fixture') unless $trial;
my $base=$ENV{SGN_MODEL_ARCHIVE_OUTPUT} || tempdir('sgn-analysis-archive-XXXXXX',TMPDIR=>1,CLEANUP=>1);make_path($base);
my $model=SGN::Model::solGS::solGS->new({schema=>$schema,people_schema=>$fixture->people_schema});
my $native=$model->phenotype_data($trial);
ok($native && $$native =~ /germplasmName/,'actual Native phenotype exporter produced the training table');
my $training="$base/native_training.tsv";
write_file($training,{binmode=>':utf8'},$$native);
write_file("$base/model_control.txt","Synthetic archive control, not a fitted field model.\n");
my $expected_md5=md5_hex(scalar(read_file($training,binmode=>':raw')));
my $prefix='audit_model_archive_'.$$.'_';
for my $case ('training_only','model_and_training','missing_training','late_io_failure') {
    my $archive="$base/archive_$case";
    if($case eq 'late_io_failure') {write_file("$base/blocked_archive_target","not a directory\n");$archive="$base/blocked_archive_target";}
    my $creator=CXGN::Analysis::AnalysisCreate->new({
        bcs_schema=>$schema,people_schema=>$fixture->people_schema,
        metadata_schema=>$fixture->metadata_schema,phenome_schema=>$fixture->phenome_schema,
        archive_path=>$archive,base_path=>getcwd(),
        dbhost=>$fixture->config->{dbhost},dbname=>$fixture->config->{dbname},dbuser=>$fixture->config->{dbuser},dbpass=>$fixture->config->{dbpass},
        tempfile_for_deleting_nd_experiment_ids=>"$base/delete_ids",analysis_to_save_boolean=>'no',
        analysis_protocol=>'Native archive/protocol control',analysis_model_properties=>{engine=>'sommer'},
        analysis_model_type=>'mixed_model_lmer',analysis_model_name=>$prefix.$case,
        analysis_model_description=>'Disposable local integration control',analysis_model_language=>'R',analysis_model_is_public=>0,
        analysis_model_application_name=>'Breedbase Mixed Model Tool',analysis_model_application_version=>'0.01',
        analysis_model_file=>($case eq 'model_and_training'?"$base/model_control.txt":undef),analysis_model_file_type=>'mixed_model_object',
        analysis_model_training_data_file=>($case eq 'missing_training'?"$base/nonexistent_training.tsv":$training),analysis_model_training_data_file_type=>'mixed_model_input_data',
        user_id=>41,user_name=>'janedoe',user_role=>'curator'
    });
    my ($result,$exception);
    eval {$result=$creator->store();1} or $exception=$@;
    if ($case eq 'missing_training' || $case eq 'late_io_failure') {
        my $persisted=$schema->resultset('NaturalDiversity::NdProtocol')->find({name=>$prefix.$case});
        if($case eq 'missing_training') {
            ok(!$persisted,'known missing input is refused before protocol/model creation');
            ok(!$exception && $result && $result->{error} && !$result->{success},'known missing input returns a controlled preflight error');
        } else {
            ok($persisted,'late archive I/O failure leaves the already stored model/protocol present');
            ok(!$exception && $result && $result->{success} && $result->{archive_pending} && @{$result->{warnings}||[]},'late archive I/O failure returns saved IDs with explicit pending warning');
            is($result ? $result->{model_id} : undef,$persisted ? $persisted->nd_protocol_id : undef,'late archive I/O response returns the actual saved model ID');
        }
        diag($exception) if $exception;
        next;
    }
    die $exception if $exception;
    ok($result->{success},"actual $case protocol/archive operation succeeds");
    diag($result->{error}) if $result->{error};
    my $protocol=$schema->resultset('NaturalDiversity::NdProtocol')->find({nd_protocol_id=>$result->{model_id}});
    my $properties=decode_json($protocol->nd_protocolprops->first->value);
    is($properties->{protocol},'Native archive/protocol control',"$case persisted exact protocol");
    is($properties->{engine},'sommer',"$case persisted the actual engine property");
    my @files=$fixture->metadata_schema->resultset('MdFiles')->search({filetype=>'mixed_model_input_data',dirname=>{like=>$archive.'%'}})->all;
    is(scalar(@files),1,"$case persisted one Native training-file metadata record");
    if(@files) {
        my $file=$files[0]->dirname.'/'.$files[0]->basename;
        ok(-f $file,"$case archived training bytes exist");
        is(md5_hex(scalar(read_file($file,binmode=>':raw'))),$expected_md5,"$case archive bytes match actual Native exporter output");
        is($files[0]->md5checksum,$expected_md5,"$case stored checksum matches the archived bytes");
        my $links=$fixture->phenome_schema->resultset('NdExperimentMdFiles')->search({file_id=>$files[0]->file_id})->count;
        is($links,1,"$case links the archive file to its experiment/protocol");
    }
}
$fixture->clean_up_db();$cleanup_needed=0;
is($schema->resultset('NaturalDiversity::NdProtocol')->search({name=>{like=>$prefix.'%'}})->count,0,'all disposable protocol/metadata database changes removed by standard fixture cleanup');
done_testing;
