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

done_testing;
