package main;
use strict;
use warnings;
use Test::More;
use JSON::PP;
use File::Slurp qw(read_file);
use File::Spec;
use List::MoreUtils qw(uniq);

# The actual controller and JSAN parser read the immutable image's real webpack
# mapping/legacy dependencies. Only the application path constructor and request
# stash are memory-only; no Catalyst app/server/database is bootstrapped.
BEGIN {
    package SGN;
    sub path_to { shift; File::Spec->catfile('/home/production/cxgn/sgn', @_) }
}
use SGN::Controller::JavaScript;
{
    package Local::JavaScriptDependencies::Context;
    sub new { bless {stash=>$_[1]},$_[0] }
    sub stash { $_[0]->{stash} }
    package Local::JavaScriptDependencies::Controller;
    use Moose;
    extends 'SGN::Controller::JavaScript';
    around '_resolve_jsan_dependencies' => sub {
        my ($orig,$self,$files)=@_;
        $self->{observed_normalized_dependencies}=[@$files];
        return $self->$orig($files);
    };
}
my $root=$ENV{I18N_TEST_JS_SOURCE_ROOT}||'/home/production/cxgn/sgn';
my $mapping_path=File::Spec->catfile($root,'js/build/mapping.json');
my $mapping=JSON::PP->new->decode(scalar read_file($mapping_path));
for my $entry(qw(sequenced_accessions fieldmap field_trial_linkage)) {
    ok(ref($mapping->{$entry}{files})eq'ARRAY'&&@{$mapping->{$entry}{files}},'Real immutable webpack fixture contains '.$entry);
}
my @entries=((map {'sequenced_accessions'} 1..19),'fieldmap','field_trial_linkage');
my @classes=('jquery','jquery.js','calendar.fullcalendar_min','solGS.heatMap','solGS.heatMap.js');
my $controller=Local::JavaScriptDependencies::Controller->new(dependency_json_path=>[$mapping_path],js_legacy_path=>[File::Spec->catdir($root,'js/source/legacy')]);
my $context=Local::JavaScriptDependencies::Context->new({jsan_classes=>[@classes],js_modules=>[@entries]});
my @raw_module_files=map {@{$mapping->{$_}{files}}} @entries;
my @raw_legacy=(@classes,map {@{$mapping->{$_}{legacy}}} @entries);
my @expected_normalized;my %seen_names;
for my $name(@raw_legacy){$name=~s/\.js$//;$name=~s!\.!/!g;push @expected_normalized,$name unless $seen_names{$name}++;}
my $jsan=$controller->new_jsan;for my $dependency (@expected_normalized){$jsan->add($dependency);}
my @raw_expected=($jsan->uris,map{File::Spec->catfile('/js/build/',$_)}@raw_module_files);
my @expected;my %first;
for my $uri(@raw_expected){push @expected,$uri unless $first{$uri}++;}
$controller->resolve_javascript_classes($context);
my $uris=$context->stash->{js_uris};
is_deeply($controller->{observed_normalized_dependencies},\@expected_normalized,'Aliases normalize before uniqueness and retain first occurrence');
is(scalar(grep{$_ eq 'jquery'}@{$controller->{observed_normalized_dependencies}}),1,'jquery/jquery.js requested once after normalization');
is(scalar(grep{$_ eq 'solGS/heatMap'}@{$controller->{observed_normalized_dependencies}}),1,'Dotted basename/.js aliases requested once after normalization');
is_deeply($uris,\@expected,'Real dependency union preserves every first-occurrence prerequisite position');
is(scalar(@$uris),scalar(uniq @$uris),'Every exact resolved URI is emitted once');
my @unique_expected=uniq @raw_expected;
is_deeply([sort @$uris],[sort @unique_expected],'Dependency/script membership unchanged');
for my $entry(qw(sequenced_accessions fieldmap field_trial_linkage)){
    for my $file(@{$mapping->{$entry}{files}}){ok(grep($_ eq '/js/build/'.$file,@$uris),'Real prerequisite remains included: '.$file);}
}
my ($runtime)=grep{/\/runtime\.min\.js$/}@$uris;
ok(defined $runtime,'Real webpack runtime is included');
is(scalar(grep{$_ eq $runtime}@$uris),1,'Nineteen repeated sections cannot reinitialize the runtime');
# Execute the exact resolved URI inclusion stream with inert sentinels in Node.
# The runtime sentinel deliberately clears simulated module state when reloaded:
# this checks real output order/count without starting a browser or calling app UI.
my $program=<<'JS';
const fs=require('node:fs');const input=JSON.parse(fs.readFileSync(0,'utf8'));let count=0,state={};
for(const uri of input.uris){if(uri===input.runtime){count++;state={};}else if(uri.endsWith('/sequenced_accessions.min.js'))state.sequenced=true;else if(uri.endsWith('/fieldmap.min.js'))state.fieldmap=true;else if(uri.endsWith('/field_trial_linkage.min.js'))state.linkage=true;}
process.stdout.write(JSON.stringify({runtimeExecutions:count,modules:state}));
JS
require IPC::Open3;require Symbol;
my $error=Symbol::gensym;my $pid=IPC::Open3::open3(my $in,my $out,$error,'node','-e',$program);
print {$in} JSON::PP->new->encode({uris=>$uris,runtime=>$runtime});close $in;my $result=do{local $/;<$out>};my $stderr=do{local $/;<$error>};waitpid($pid,0);
is($?,0,'Runtime reset sentinel executes without application source');
my $counter_result=JSON::PP->new->decode($result);
is($counter_result->{runtimeExecutions},1,'Actual resolved script stream executes runtime once');
is_deeply($counter_result->{modules},{sequenced=>JSON::PP::true,fieldmap=>JSON::PP::true,linkage=>JSON::PP::true},'Stable union retains all required module registrations after runtime');
# Pure legacy aliases, without entry modules, still preserve native script order.
my $legacy=Local::JavaScriptDependencies::Context->new({jsan_classes=>['jquery.js','jquery','calendar.fullcalendar_min'],js_modules=>[]});
$controller->resolve_javascript_classes($legacy);
is_deeply($controller->{observed_normalized_dependencies},['jquery','calendar/fullcalendar_min'],'Legacy-only alias order stays stable');
ok(grep(/calendar\/fullcalendar_min\.js$/,@{$legacy->stash->{js_uris}}),'Original calendar plugin remains present');
my $prototype=Local::JavaScriptDependencies::Context->new({jsan_classes=>['jquery','Prototype.js','Prototype'],js_modules=>[]});
$controller->resolve_javascript_classes($prototype);
is_deeply($controller->{observed_normalized_dependencies},['Prototype','jquery'],'Original Prototype-before-jQuery policy remains intact after alias normalization');
is($prototype->stash->{js_uris}[0],'/js/legacy/Prototype.js','Actual Prototype dependency remains first');
done_testing;
