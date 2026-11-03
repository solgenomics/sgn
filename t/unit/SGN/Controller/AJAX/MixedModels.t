use strict;
use warnings;
use Test::More;
use File::Path qw(make_path);
use File::Spec;
use File::Slurp qw(read_file);
use File::Temp qw(tempdir);
use CXGN::MixedModels;
use SGN::Controller::AJAX::MixedModels;

my $root = tempdir('sgn-mixedmodels-contract-XXXXXX', TMPDIR => 1, CLEANUP => 1);
make_path($root);
my @metadata = qw(studyYear programDbId programName programDescription studyDbId studyName studyDescription studyDesign plotWidth plotLength fieldSize fieldTrialIsPlannedToBeGenotyped fieldTrialIsPlannedToCross plantingDate harvestDate locationDbId locationName germplasmDbId germplasmName germplasmSynonyms observationLevel observationUnitDbId observationUnitName replicate blockNumber plotNumber rowNumber colNumber entryType plantNumber plantedSeedlotStockDbId plantedSeedlotStockUniquename plantedSeedlotCurrentCount plantedSeedlotCurrentWeightGram plantedSeedlotBoxName plantedSeedlotTransactionCount plantedSeedlotTransactionWeight plantedSeedlotTransactionDescription availableGermplasmSeedlotUniquenames);
is(scalar(@metadata),39,'fixture matches default MaterializedViewTable metadata width');
open my $f,'>',"$root/input_phenotype.txt" or die $!;
print $f join("\t",@metadata,'Yield|CO_343:0000001','notes'),"\n";
for my $n (1..6) {
    my %v = map {$_=>1} @metadata;
    @v{qw(studyDesign germplasmName replicate blockNumber rowNumber colNumber)} = ('Alpha','G'.(($n%3)+1),int(($n-1)/3)+1,$n,1,$n);
    print $f join("\t",map({$v{$_}} @metadata),50+$n,''),"\n";
}
close $f;

{
    package AuditRequest;
    sub param { my ($s,$k)=@_;return $s->{params}{$k} }
    sub params { return $_[0]->{params} }
    sub body_data { return $_[0]->{body} }
    package AuditPerson;
    sub get_sp_person_id {return 1}
    package AuditUser;
    sub get_object {return bless {},'AuditPerson'}
    package AuditContext;
    sub req {return $_[0]->{req}}
    sub user {return bless {},'AuditUser'}
    sub tempfiles_subdir {}
    sub tempfile {my($self,%options)=@_;return (undef,($options{TEMPLATE}||'') =~ /run_/ ? 'run_'.++$self->{run_sequence}.($options{SUFFIX}||'') : 'input')}
    sub path_to {return $_[0]->{config}{basepath}.'/'.$_[1]}
    sub dbic_schema {return undef}
    sub config {return $_[0]->{config}}
    sub stash {return $_[0]->{stash}}
    package AuditDataset;
    sub retrieve_phenotypes {return []}
}

my $ctx=bless {req=>bless({params=>{dataset_id=>1,dataset_trait_outliers=>1}},'AuditRequest'), config=>{basepath=>$root,cluster_shared_tempdir=>$root},stash=>{}},'AuditContext';
my $controller=SGN::Controller::AJAX::MixedModels->new;
my $constructor;
{
    no warnings 'redefine';
    local *CXGN::Dataset::File::new = sub {my ($class,%arg)=@_;$constructor=\%arg;return bless {},'AuditDataset'};
    $controller->prepare($ctx);
}
ok(grep($_ eq 'designReplicate',@{$ctx->stash->{rest}{factors}}),'actual prepare offers recorded designReplicate');
my %offered=map {$_=>1} @{$ctx->stash->{rest}{factors}};
ok($offered{designReplicate} && $offered{colNumber} && $offered{germplasmName},'all interaction, slope and multiple-random probe factors are actually offered');
ok(grep($_ eq 'blockNumber',@{$ctx->stash->{rest}{factors}}),'actual prepare offers multiple blockNumber levels');
is($constructor->{exclude_dataset_outliers},1,'actual prepare propagates dataset outlier checkbox');
is($constructor->{exclude_phenotype_outlier},1,'actual prepare propagates phenotype outlier checkbox');
open my $fp,'>',"$root/offered_factors.txt" or die $!;
print $fp join("\n",@{$ctx->stash->{rest}{factors}}),"\n";close $fp;

my $mm=CXGN::MixedModels->new;
$mm->dependent_variables(['Yield']);$mm->fixed_factors(['colNumber']);$mm->random_factors(['germplasmName','replicate']);
my ($multi,$error)=$mm->generate_model;
is($error,undef,'multiple random factor generation reports no error');
is($multi,'colNumber + (1|germplasmName) + (1|designReplicate)','each selected offered random factor is a separate additive grouping term');
open my $mf,'>',"$root/generated_random_model.txt" or die $!;print $mf "$multi\n";close $mf;

$mm->fixed_factors_interaction([['replicate','colNumber']]);
for my $generator (qw(generate_model_sommer generate_model_spl2D)) {
    my ($model, $generation_error) = $mm->$generator();
    like($model->[0], qr/designReplicate:colNumber/, "$generator keeps selected fixed interactions in the fixed formula");
    unlike($model->[1], qr/designReplicate:colNumber/, "$generator does not turn a fixed interaction into a random effect");
}

# Execute modelstring and run owning methods. Only job execution/result reading
# is intercepted; no database, router, authentication, or actual R claim here.
my $request={engine=>'lme4',dependent_variables=>['Yield'],fixed_factors=>['replicate'],random_factors=>['germplasmName'],fixed_factors_interaction=>[['replicate','colNumber']],variable_slope_intersects=>[['replicate','germplasmName']]};
$ctx->{req}{body}=$request;
$controller->model_string($ctx);
my $preview=$ctx->stash->{rest}{model};
like($preview,qr/designReplicate\*colNumber/,'actual preview includes selected interaction of two offered factors');
$ctx->{req}{params}={%$request,'model'=>$preview,'tempfile'=>'input_phenotype.txt','dependent_variables[]'=>['Yield'],'fixed_factors[]'=>['replicate'],'random_factors[]'=>['germplasmName']};
$ctx->{req}{params}{fixed_factors_interaction}=JSON::Any->new->encode($request->{fixed_factors_interaction});
$ctx->{req}{params}{variable_slope_intersects}=JSON::Any->new->encode($request->{variable_slope_intersects});
my $run_model;
{
    no warnings 'redefine';
    local *CXGN::MixedModels::run_model=sub {my $self=shift;($run_model)=$self->generate_model;return 'Intentional test job interception; no model job submitted'};
    $controller->run($ctx);
}
is($run_model,$preview,'actual run rebuilds the same interaction/slope formula shown in preview');
open my $pr,'>',"$root/preview_vs_run.txt" or die $!;print $pr "preview: $preview\nrun: $run_model\n";close $pr;
# Invalid serialized collections must report a controlled validation error,
# before creating or submitting an R job.
{
    no warnings 'redefine';
    local *CXGN::MixedModels::run_model = sub { die "Invalid terms must not submit a model job" };
$ctx->{req}{params}{fixed_factors_interaction} = '{';
$controller->run($ctx);
like($ctx->stash->{rest}{error}, qr/Invalid model terms/, 'malformed serialized interaction data is refused');
$ctx->{req}{params}{fixed_factors_interaction} = 'null';
$controller->run($ctx);
like($ctx->stash->{rest}{error}, qr/Invalid factor collection/, 'null interaction collection is refused');
}
# Re-using a prepared data file must preserve its source headers/values and
# must not expose results from the previous selected model.
my $runner = CXGN::MixedModels->new({tempfile => "$root/input_phenotype.txt"});
$runner->dependent_variables(['Yield|CO_343:0000001']);
$runner->fixed_factors(['replicate']);
$runner->random_factors(['germplasmName']);
$runner->clean_file($runner->tempfile);
my $first_clean = read_file($runner->tempfile);
my $pristine = read_file($runner->tempfile.'.before_clean');
$runner->clean_file($runner->tempfile);
is(scalar(read_file($runner->tempfile)), $first_clean, 'second clean preserves every phenotype value and cleaned column');
is(scalar(read_file($runner->tempfile.'.before_clean')), $pristine, 'second clean preserves the original phenotype snapshot');
my $conversion = $runner->read_conversion_matrix($runner->tempfile.'.traits');
is($conversion->{Yield_CO_343_0000001}, 'Yield|CO_343:0000001', 'second clean retains original ontology trait names');

{
    package AuditModelJob;
    sub submit {
        my $self = shift;
        if (defined $self->{message}) {
            open my $error, '>', $self->{file} or die $!;
            print $error $self->{message}, "\n";
            close $error;
        }
    }
    sub alive {return 0}
    sub retrieve_finish_timestamp {return 1}
    sub update_status {}
}
my @result_suffixes = qw(.model_error .adjustedBLUPs .BLUPs .BLUEs .adjustedBLUEs .anova .varcomp);
for my $suffix (@result_suffixes) {
    open my $old, '>', $runner->tempfile.$suffix or die $!;
    print $old "stale result\n";
    close $old;
}
{
    no warnings 'redefine';
    local *SGN::Context::new = sub {return bless {}, 'AuditContext'};
    local *CXGN::Job::new = sub {return bless {}, 'AuditModelJob'};
    my $error = $runner->run_model('local','localhost',$root,{});
    is($error,undef,'owned run_model handoff completes with intercepted job');
    ok(!grep(-e $runner->tempfile.$_, @result_suffixes), 'a new model submission clears every old result type');
    local *CXGN::Job::new = sub {return bless {file=>$runner->tempfile.'.model_error',message=>'Unsupported test model output'}, 'AuditModelJob'};
    $error = $runner->run_model('local','localhost',$root,{});
    like($error,qr/Unsupported test model output/,'model capability error reaches the existing controller error contract');
}
done_testing;
