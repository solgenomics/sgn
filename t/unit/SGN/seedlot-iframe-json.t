package main;
use strict;
use warnings;
use utf8;
use Test::More;
use Encode qw(encode);
use File::Spec;
use FindBin;
use Digest::SHA qw(sha256_hex);
use Scalar::Util qw(refaddr);
use lib 'lib';
BEGIN {unshift @INC,$ENV{I18N_TEST_PRODUCT_LIB_ROOT} if $ENV{I18N_TEST_PRODUCT_LIB_ROOT};}
use JSON::MaybeXS ();
use Catalyst::Response;
use Catalyst::Action::Serialize::JSON;
use Catalyst::Action::Serialize::Callback;
use Catalyst::Action::Deserialize::JSON;
use Catalyst::Action::Deserialize::Callback;
use SGN::Controller::AJAX::Seedlot;
use SGN::Controller::AJAX::Cross;

# Actual whole controller/configuration and installed codec/actions. The context
# supplies only transport data; no app, HTTP request, database or model is run.
{
    package SeedlotIframeRequest;
    sub body {shift->{body}}
    sub data {my $s=shift;$s->{data}=shift if @_;return $s->{data}}
    package SeedlotIframeLogger;
    sub debug {}
    package SeedlotIframeContext;
    sub new {my ($class,$body)=@_;my $s=bless {stash=>{},request=>bless({body=>$body},'SeedlotIframeRequest')},$class;$s->{response}=Catalyst::Response->new(_context=>$s);$s->{response}->status(200);$s->{response}->content_type('text/html');return $s}
    sub stash {shift->{stash}} sub response {shift->{response}} sub res {shift->{response}}
    sub request {shift->{request}} sub req {shift->{request}} sub debug {0}
    sub log {bless {},'SeedlotIframeLogger'}
    package SeedlotIframeBlessed;
    sub TO_JSON {{name=>$_[0]{name},value=>0}}
}
my $config=SGN::Controller::AJAX::Seedlot->config;
is($config->{default},'application/json','Native default media type remains JSON');
is($config->{map}{'application/json'},'JSON','Raw AJAX/API JSON retains original serializer');
is($config->{map}{'text/html'}[0],'Callback','Only the iframe HTML carrier uses the native Callback adapter');
my $callbacks=$config->{map}{'text/html'}[1];
is(refaddr($callbacks->{serialize}),refaddr(\&SGN::Controller::AJAX::Seedlot::_sgn_seedlot_iframe_json),'Map binds the actual source encoder');
is(refaddr($callbacks->{deserialize}),refaddr(\&SGN::Controller::AJAX::Seedlot::_sgn_seedlot_iframe_decode),'Map binds the actual source decoder');
is(SGN::Controller::AJAX::Cross->config->{map}{'text/html'},'JSON','Independent crossing controller policy remains original');
is($Catalyst::Action::Serialize::JSON::VERSION,'1.21','Installed native JSON serializer is the reviewed version');
is($Catalyst::Action::Serialize::Callback::VERSION,'1.21','Installed native Callback serializer is the reviewed version');
is($Catalyst::Action::Deserialize::JSON::VERSION,'1.21','Installed native JSON decoder is the reviewed version');
is($Catalyst::Action::Deserialize::Callback::VERSION,'1.21','Installed native Callback decoder is the reviewed version');
sub action {my ($class)=@_;$class->new(name=>'json',code=>sub{},class=>'SGN::Controller::AJAX::Seedlot',namespace=>'ajax/seedlot',reverse=>'ajax/seedlot/json')}
sub serialized {
    my ($class,$cfg,$entity)=@_;my $c=SeedlotIframeContext->new;$c->stash->{rest}=$entity;
    my $rc=action($class)->execute($cfg,$c,$callbacks);
    is($rc,1,'Actual installed serializer completes');
    is($c->res->status,200,'Serialization leaves response status untouched');
    is($c->res->content_type,'text/html','Serialization leaves original media type untouched');
    return $c->res->body;
}
sub decoded {
    my ($class,$cfg,$body)=@_;my $c=SeedlotIframeContext->new($body);
    my $rc=action($class)->execute($cfg,$c,$callbacks);
    return ($rc,$c->req->data);
}
my $codec=JSON::MaybeXS::JSON()->new->utf8->convert_blessed->canonical;
my $literal='é_Жито_試験_دفعة_<br>_<strong>_&amp;_%{columns}_"_\_</script>_<script>window.sgnSeedlotInjected=1</script>';
my $plain_error='Не розпізнано стовпець: '.$literal.'. LONG SEEDLOT LABEL WITH MANY WORDS <img src=x onerror="window.sgnSeedlotInjected=1">';
my $entity={error_string=>SGN::Controller::AJAX::Seedlot::_sgn_seedlot_error_html($plain_error).'<br>',missing_accessions=>undef,missing_crosses=>undef,
    scientific_strings=>[$literal,'0','NA','g',"separator_\x{2028}_\x{2029}"],scientific_values=>[0,17.25,undef],
    canonical_headers=>[qw(seedlot_name accession_name operator_name box_name amount weight_gram description quality)],
    boolean=>JSON::MaybeXS::JSON()->new->allow_nonref->decode('true'),blessed=>bless({name=>$literal},'SeedlotIframeBlessed')};
my $before_entity=$codec->encode($entity);
my $before=serialized('Catalyst::Action::Serialize::JSON',$config,$entity);
my $after=serialized('Catalyst::Action::Serialize::Callback',$config,$entity);
ok(!utf8::is_utf8($after),'Native UTF-8 response remains octets');
ok(index($after,encode('UTF-8','Жито'))>=0,'Scientific Unicode remains UTF-8; no ASCII normalization is added');
like($before,qr/&quot;/,'Original serializer retains HTML entities which the HTML document would decode');
unlike($after,qr/[<>&]/,'Iframe wire has no HTML delimiters or entity introducers');
my ($rc,$data)=decoded('Catalyst::Action::Deserialize::JSON',$config,$after);
is($rc,1,'Original JSON decoder accepts corrected iframe wire');
is($codec->encode($data),$before_entity,'Decoded reply preserves every scientific value, header, boolean and converted blessed value exactly');
is($data->{error_string},$entity->{error_string},'Error HTML layer is restored exactly after JSON decode');
is($codec->encode($entity),$before_entity,'Serializer never mutates the source entity');
my ($callback_rc,$callback_data)=decoded('Catalyst::Action::Deserialize::Callback',$config,$before);
is($callback_rc,1,'Callback decoder accepts original JSON body');
is($codec->encode($callback_data),$before_entity,'Callback decode retains original JSON semantics');
open my $handle,'<',\$after or die $!;
read($handle,my $discard,9);
my ($handle_rc,$handle_data)=decoded('Catalyst::Action::Deserialize::Callback',$config,$handle);
is($handle_rc,1,'Actual Callback rewinds and reads incoming filehandle');
is($codec->encode($handle_data),$before_entity,'Filehandle decode preserves complete body');
close $handle;
for my $class(qw(Catalyst::Action::Deserialize::JSON Catalyst::Action::Deserialize::Callback)) {
    my ($bad_rc,$bad_data)=decoded($class,$config,'{"broken":');
    isnt($bad_rc,1,'Malformed input retains installed decoder error branch');
    ok(!defined($bad_data),'Malformed JSON does not produce request data');
    my ($empty_rc,$empty_data)=decoded($class,$config,'');
    is($empty_rc,1,'Empty input retains original no-data completion');
    ok(!defined($empty_data),'Empty input does not invent request data');
}
my $encode_options={%$config,json_options_encode=>{canonical=>1,allow_nonref=>1}};
my $scalar='raw_é_"_\_<br>_&amp;';
my $scalar_wire=serialized('Catalyst::Action::Serialize::Callback',$encode_options,$scalar);
my $decode_options={%$config,json_options=>{allow_nonref=>1}};
for my $class(qw(Catalyst::Action::Deserialize::JSON Catalyst::Action::Deserialize::Callback)) {
    my ($opt_rc,$opt_data)=decoded($class,$decode_options,$scalar_wire);
    is($opt_rc,1,'Actual decoder applies original json_options');is($opt_data,$scalar,'Configured scalar decode retains raw scientific string');
}
my $ascii_options={%$config,json_options_encode=>{ascii=>1,canonical=>1}};
my $ascii_wire=serialized('Catalyst::Action::Serialize::Callback',$ascii_options,$entity);
unlike($ascii_wire,qr/[^\x00-\x7f]/,'Existing encode option is honored when explicitly configured');
my $next_wire=serialized('Catalyst::Action::Serialize::Callback',$config,$entity);
ok(index($next_wire,encode('UTF-8','Жито'))>=0,'A configured call does not leak options into the next default call');

if(my $dir=$ENV{I18N_SEEDLOT_IFRAME_JSON_EVIDENCE}) {
    die 'Evidence directory must already exist outside the source checkout' unless File::Spec->file_name_is_absolute($dir)&&-d $dir;
    my $product_root=$ENV{I18N_TEST_PRODUCT_ROOT}||File::Spec->rel2abs(File::Spec->catdir($FindBin::Bin,'..','..','..'));
    die 'Evidence must stay outside the checkout' if index(File::Spec->canonpath($dir).'/',File::Spec->canonpath($product_root).'/')==0;
    my %files=('wire-before.json'=>$before,'wire-after.json'=>$after,'expected-payload.json'=>$before_entity,'plain-error.txt'=>encode('UTF-8',$plain_error));
    for my $name(sort keys %files){open my $fh,'>:raw',File::Spec->catfile($dir,$name) or die $!;print {$fh}$files{$name};close $fh;}
    my $source_hash=sub {my $path=shift;open my $fh,'<:raw',$path or die $!;my $bytes=do {local $/;<$fh>};close $fh;return sha256_hex($bytes)};
    my $controller_path=$INC{'SGN/Controller/AJAX/Seedlot.pm'};
    my %framework=map {my $key=$_;my $path=$INC{$key};$key=>{path=>$path,sha256=>$source_hash->($path)}} qw(Catalyst/Action/Serialize/JSON.pm Catalyst/Action/Serialize/Callback.pm Catalyst/Action/Deserialize/JSON.pm Catalyst/Action/Deserialize/Callback.pm);
    my $proof={controllerPath=>$controller_path,controllerSHA=>$source_hash->($controller_path),frameworkSources=>\%framework,testSourceSHA=>$source_hash->(__FILE__),schema=>1,status=>Test::More->builder->is_passing?'PASS':'FAIL',scope=>'Actual installed Catalyst transport source unit; no native workflow qualification',nativeSGNWorkflowQualified=>JSON::MaybeXS::JSON()->new->allow_nonref->decode('false'),framework_version=>$Catalyst::Action::Serialize::Callback::VERSION,backend=>JSON::MaybeXS::JSON(),files=>{map {$_=>sha256_hex($files{$_})} keys %files}};
    open my $fh,'>:raw',File::Spec->catfile($dir,'serializer-source-proof.json') or die $!;print {$fh}$codec->encode($proof);close $fh;
}
done_testing;
