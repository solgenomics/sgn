# Actual producer/controller/R/store/Native-readback qualification.
# Only queue dispatch/status and asynchronous matview refresh are injected:
# the installed synchronous Tools::Run executes the real R command locally.
use strict;
use warnings;
use Test::More;
use File::Path qw(make_path);
use File::Temp qw(tempfile tempdir);
use File::Basename qw(basename);
use File::Slurp qw(read_file write_file);
use Scalar::Util qw(looks_like_number);
use Digest::MD5 qw(md5_hex);
use Cwd qw(getcwd);
use JSON::Any;
use lib 't/lib';
use SGN::Test::Fixture;
use CXGN::Dataset::File;
use CXGN::Analysis::AnalysisCreate;
use CXGN::Phenotypes::PhenotypeMatrix;
use SGN::Controller::AJAX::MixedModels;

my ($rscript)=grep {-x $_} map {"$_/Rscript"} split /:/,$ENV{PATH};
plan skip_all=>'R is not installed' unless $rscript;
BAIL_OUT('Native queue qualifier requires local direct execution, not podman') if $ENV{RUN_NATIVE_QUEUE} && $ENV{BB_JOB_PODMAN_URL};
my $fixture=SGN::Test::Fixture->new;
my $schema=$fixture->bcs_schema;
my @native_jobs;
my $native_new=CXGN::Job->can("new");
my $cleanup_needed=1;
sub cleanup_owned_jobs {
    for my $job (@native_jobs) {
        next unless $job->has_sp_job_id;
        my $row=$fixture->people_schema->resultset('SpJob')->find({sp_job_id=>$job->sp_job_id});
        $row->delete if $row;
    }
}
END {eval {cleanup_owned_jobs()};eval {$fixture->clean_up_db} if $cleanup_needed;}
my $root=getcwd();my $tag='audit_numeric_'.$$;
my $work="$root/static/documents/tempfiles/$tag";make_path($work);
my $artifacts=$ENV{SGN_NUMERIC_PIPELINE_OUTPUT} || tempdir('sgn-numeric-pipeline-XXXXXX',TMPDIR=>1,CLEANUP=>1);make_path($artifacts);
my ($trial)=$schema->storage->dbh->selectrow_array(q{SELECT p.project_id FROM nd_experiment_project p JOIN nd_experiment_phenotype USING(nd_experiment_id) JOIN nd_experiment_stock USING(nd_experiment_id) JOIN stock s USING(stock_id) JOIN cvterm t ON t.cvterm_id=s.type_id WHERE t.name='plot' ORDER BY p.project_id LIMIT 1});
my $all=CXGN::Dataset::File->new({schema=>$schema,people_schema=>$fixture->people_schema,file_name=>"$work/all",quotes=>0});
$all->trials([$trial]);my $matrix=$all->retrieve_phenotypes();
my @header=@{$matrix->[0]};my %column;@column{@header}=(0..$#header);
my ($trait,@accessions);
my @candidate=grep {$header[$_] =~ /\|CO_/} 39..$#header;
@candidate=sort {($header[$b] =~ /fresh root weight/i)<=>($header[$a] =~ /fresh root weight/i)} @candidate;
for my $index (@candidate) {
    my %count;
    for my $row (@$matrix[1..$#$matrix]) {
        my $v=$row->[$index];
        next unless defined($v)&&$v ne ''&&looks_like_number($v)&&$v !~ /inf|nan/i;
        $count{$row->[$column{germplasmDbId}]}++;
    }
    my @ids=sort {$a<=>$b} grep {$count{$_}>=2} keys %count;
    if(@ids>=8){$trait=$header[$index];@accessions=@ids[0..7];last;}
}
BAIL_OUT('Fixture trial lacks eight repeated accessions for one numeric trait') unless $trait;
my $trait_id=SGN::Model::Cvterm->get_cvterm_row_from_trait_name($schema,$trait)->cvterm_id;
my $producer=CXGN::Dataset::File->new({schema=>$schema,people_schema=>$fixture->people_schema,file_name=>"$work/prepared",quotes=>0});
$producer->trials([$trial]);$producer->accessions(\@accessions);$producer->traits([$trait_id]);
my $selected=$producer->retrieve_phenotypes();
ok(@$selected>8,'actual MixedModels DatasetFile producer emitted repeated field observations');
note('trial='.$trial.' trait='.$trait.' accessions='.scalar(@accessions).' rows='.(@$selected-1));
{
    package NumericReq; ## no critic (Modules::RequireFilenameMatchesPackage) -- This test embeds its named test double beside the assertions.
    sub params {return $_[0]}
    sub param {return $_[0]->{$_[1]}}
    package NumericActor;
    sub get_sp_person_id {return 41}
    sub get_first_name {return 'Test'}
    sub get_last_name {return 'Operator'}
    package NumericUser;
    sub get_object {return bless {},'NumericActor'}
    package NumericContext;
    sub path_to {return $root."/".$_[1]}
    sub req {return $_[0]->{req}}
    sub config {return $_[0]->{config}}
    sub stash {return $_[0]->{stash}}
    sub user {return bless {},'NumericUser'}
    sub dbic_schema {return $_[1] eq 'CXGN::People::Schema' ? $fixture->people_schema : $fixture->bcs_schema}
    sub tempfiles_subdir {my($self,$sub)=@_;File::Path::make_path("$root/static/documents/tempfiles/$sub")}
    sub tempfile {
        my($self,%options)=@_;
        my $template=$options{TEMPLATE}||'mixedmodels/run_XXXXX';
        my $directory=$template; $directory=~s{/[^/]+$}{};
        File::Path::make_path("$root/static/documents/tempfiles/$directory");
        my($fh,$file)=File::Temp::tempfile(File::Basename::basename($template),DIR=>"$root/static/documents/tempfiles/$directory",SUFFIX=>($options{SUFFIX}||''),UNLINK=>0);
        $file=~s/^\Q$root\E\///;
        return($fh,$file);
    }
}
my $ctx=bless {config=>{%{$fixture->config},basepath=>$root,backend=>'Tsp',cluster_host=>'localhost',cluster_shared_tempdir=>$work},stash=>{}},'NumericContext';
my $controller=SGN::Controller::AJAX::MixedModels->new;
my @responses;
for my $model ('random','fixed') {
    $ctx->{req}=bless {tempfile=>"static/documents/tempfiles/$tag/prepared_phenotype.txt",engine=>'lme4','dependent_variables[]'=>[$trait],
        'fixed_factors[]'=>[$model eq 'random'?'replicate':'germplasmName'],
        'random_factors[]'=>[$model eq 'random'?'germplasmName':'replicate']},'NumericReq';
    if ($ENV{RUN_NATIVE_QUEUE}) {
        no warnings 'redefine';
        local *CXGN::Job::new=sub {my $job=$native_new->(@_);push @native_jobs,$job;return $job};
        $controller->run($ctx);
    } else {
        no warnings 'redefine';
        local *CXGN::Job::submit=sub {
            my $job=shift;
            my $runner=CXGN::Tools::Run->new({temp_base=>$work,do_cleanup=>1});
            $runner->run('bash','-c',"cd '$root' && ".$job->cmd);
            return 1;
        };
        local *CXGN::Job::alive=sub{return 0};
        local *CXGN::Job::retrieve_finish_timestamp=sub{return 'completed-local-command'};
        local *CXGN::Job::update_status=sub{return 1};
        $controller->run($ctx);
    }
    my $raw_response=$ctx->stash->{rest};
    ok(!$raw_response->{error},"actual controller and real local R complete $model genotype model");
    diag("".$raw_response->{error}) if $raw_response->{error};
    BAIL_OUT('R/controller prerequisite failed') if $raw_response->{error};
    my $response=JSON::Any->decode(JSON::Any->encode($raw_response));
    ok(-s $response->{input_file},"$model response points to a nonempty actual training table");
    write_file("$artifacts/$model.json",JSON::Any->encode($response));
    push @responses,$response;
}
isnt($responses[0]{input_file},$responses[1]{input_file},'two runs of one prepared table have independent input/output namespaces'); # codespell:ignore isnt
my $response=$responses[0];
my $program=$schema->resultset('Project::Project')->find({name=>'test'})->project_id;
my @allowed=split /,/,$fixture->config->{composable_cvs};
my $creator=CXGN::Analysis::AnalysisCreate->new({
    bcs_schema=>$schema,people_schema=>$fixture->people_schema,metadata_schema=>$fixture->metadata_schema,phenome_schema=>$fixture->phenome_schema,
    archive_path=>"$artifacts/archive",base_path=>$root,dbhost=>$fixture->config->{dbhost},dbname=>$fixture->config->{dbname},dbuser=>$fixture->config->{dbuser},dbpass=>$fixture->config->{dbpass},tempfile_for_deleting_nd_experiment_ids=>"$artifacts/delete_ids",
    analysis_to_save_boolean=>'yes',analysis_name=>$tag,analysis_description=>'Actual numeric pipeline control, not field acceptance',analysis_year=>'2026',analysis_breeding_program_id=>$program,
    analysis_protocol=>'replicate + (1|germplasmName)',analysis_accession_names=>$response->{accession_names},analysis_trait_names=>$response->{traits},analysis_statistical_ontology_term=>'Adjusted means from BLUPs using LMER R|SGNSTAT:0000034',
    analysis_result_values=>$response->{adjusted_blups_data},analysis_result_values_type=>'analysis_result_values_match_accession_names',analysis_model_name=>$tag.'_model',analysis_model_description=>'Local numeric qualification',analysis_model_is_public=>0,analysis_model_language=>'R',analysis_model_type=>'mixed_model_lmer',analysis_model_properties=>{engine=>'lme4'},analysis_model_application_name=>'Breedbase Mixed Model Tool',analysis_model_application_version=>'0.01',
    analysis_model_file=>undef,analysis_model_file_type=>undef,analysis_model_training_data_file=>$response->{input_file},analysis_model_training_data_file_type=>'mixed_model_input_data',analysis_model_auxiliary_files=>[],allowed_composed_cvs=>\@allowed,composable_cvterm_delimiter=>$fixture->config->{composable_cvterm_delimiter},composable_cvterm_format=>$fixture->config->{composable_cvterm_format},user_id=>41,user_name=>'janedoe',user_role=>'curator'
});
my $stored;
{
    no warnings 'redefine';
    # Readback is Native/raw; cache-refresh scheduling is separately tested.
    local *CXGN::Analysis::AnalysisCreate::_refresh_matviews=sub{return {message=>'Native readback selected'}};
    $stored=$creator->store;
}
ok($stored->{success},'actual AnalysisCreate persists the computed genotype values');
diag($stored->{error}) if $stored->{error};
BAIL_OUT('Analysis storage prerequisite failed') unless $stored->{success};
my @readback=CXGN::Phenotypes::PhenotypeMatrix->new({bcs_schema=>$schema,search_type=>'Native',data_level=>'analysis_instance',experiment_type=>'analysis_experiment',trial_list=>[$stored->{analysis_id}]})->get_phenotype_matrix;
my $header=shift @readback;my %index;@index{@$header}=(0..$#$header);
my %expected=map {$_=>$response->{adjusted_blups_data}{$_}{$trait}[0]} @{$response->{accession_names}};
is(scalar(@readback),scalar(keys %expected),'Native analysis readback retains every computed genotype');
my $all_match=1;
for my $row (@readback){my $name=$row->[$index{germplasmName}];$all_match=0 if !exists($expected{$name})||!defined($row->[30])||abs($row->[30]-$expected{$name})>1e-8;}
ok($all_match,'stored Native genotype values equal actual controller/R values by genotype ID/name');
my @files=$fixture->metadata_schema->resultset('MdFiles')->search({filetype=>'mixed_model_input_data',dirname=>{like=>"$artifacts/archive%"}})->all;
is(scalar(@files),1,'actual controller training pointer produces one archive metadata record');
if(@files){is(md5_hex(scalar(read_file($files[0]->dirname.'/'.$files[0]->basename,binmode=>':raw'))),md5_hex(scalar(read_file($response->{input_file},binmode=>':raw'))),'archived training bytes exactly match the actual controller response input');}
write_file("$artifacts/stored.json",JSON::Any->encode($stored));
if ($ENV{RUN_NATIVE_QUEUE}) {
    my @recorded;
    for my $job (@native_jobs) {
        ok($job->has_sp_job_id,'native queue stored a real job record');
        my $row=$fixture->people_schema->resultset('SpJob')->find({sp_job_id=>$job->sp_job_id});
        ok($row,'native queue job metadata exists in the database');
        is($row->status,'finished','native queue job metadata reports actual completion');
        push @recorded,{sp_job_id=>$row->sp_job_id,status=>$row->status,backend_id=>$job->backend_id};
        $row->delete;
    }
    write_file("$artifacts/native_queue_jobs.json",JSON::Any->encode(\@recorded));
}
$fixture->clean_up_db;$cleanup_needed=0;
is($schema->resultset('Project::Project')->search({name=>$tag})->count,0,'standard cleanup removes the disposable numeric analysis');
done_testing;
