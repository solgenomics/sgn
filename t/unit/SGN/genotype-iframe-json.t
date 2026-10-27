package main;
use strict;
use warnings;
use utf8;
use Test::More;
use Encode qw(encode);
use JSON::MaybeXS ();
use Catalyst;
use Catalyst::Response;
use Catalyst::Action::Serialize::JSON;
use Catalyst::Action::Serialize::Callback;
use Catalyst::Action::Deserialize::JSON;
use Catalyst::Action::Deserialize::Callback;
use lib 'lib';
BEGIN {unshift @INC,$ENV{I18N_TEST_PRODUCT_LIB_ROOT} if $ENV{I18N_TEST_PRODUCT_LIB_ROOT};}
use SGN::Controller::AJAX::GenotypingTrial;
use SGN::Controller::AJAX::Cross;
{
 package GenotypeIframeRequest;
 sub body {shift->{body}} sub data {my $s=shift;$s->{data}=shift if @_;$s->{data}}
 package GenotypeIframeLog;sub debug {}
 package GenotypeIframeContext;
 sub new {my($class,$mime,$body)=@_;my $s=bless{stash=>{},req=>bless({body=>$body},'GenotypeIframeRequest')},$class;$s->{res}=Catalyst::Response->new(_context=>$s);$s->{res}->status(200);$s->{res}->content_type($mime);$s}
 sub stash {shift->{stash}} sub response {shift->{res}} sub res {shift->{res}}
 sub req {shift->{req}} sub request {shift->{req}} sub debug {0} sub log {bless{},'GenotypeIframeLog'}
 sub encoding {Encode::find_encoding('UTF-8')} sub _encode_check {Encode::FB_CROAK()|Encode::LEAVE_SRC()} ## no critic (Bangs::ProhibitBitwiseOperators) # Match Encode's required combined strict UTF-8/source-preservation flags.
 package GenotypeIframeBlessed;sub TO_JSON {{name=>$_[0]{name},value=>0}}
}
my $cfg=SGN::Controller::AJAX::GenotypingTrial->config;
is($cfg->{map}{'application/json'},'JSON','Original API serializer retained');
is($cfg->{map}{'text/html'}[0],'Callback','Iframe uses controller-local existing Callback adapter');
is(SGN::Controller::AJAX::Cross->config->{map}{'text/html'},'JSON','Peer controller unchanged');
my $callbacks=$cfg->{map}{'text/html'}[1];
sub action {shift->new(name=>'json',code=>sub{},class=>'SGN::Controller::AJAX::GenotypingTrial',namespace=>'ajax/genotypingtrial',reverse=>'ajax/genotypingtrial/json')}
my $codec=JSON::MaybeXS::JSON()->new->utf8->canonical->convert_blessed;
my $literal='Поле Київ, "зразок" <b>raw</b> &amp; %{error} 0007 1.25e-3 é العربية 零 😀 </script><img src=x onerror="window.genotypeInjected=1">';
my $entity={success=>'1',design=>{A01=>{dna_person=>'Олена_Їжак',notes=>$literal,plot_number=>'A01',stock_name=>'Жито_0007',concentration=>'1.25e-3'}},machine=>['0007','1.25e-3',0,17.25,undef,'kg',JSON::MaybeXS::JSON()->new->allow_nonref->decode('true')],blessed=>bless({name=>$literal},'GenotypeIframeBlessed')};
my $expected=$codec->encode($entity);my %wires;
for my $mode(qw(baseline-html api iframe)) {
 my $mime=$mode eq 'api'?'application/json':'text/html';my $c=GenotypeIframeContext->new($mime);
 $c->stash->{rest}=$entity;my $class=$mode eq 'iframe'?'Catalyst::Action::Serialize::Callback':'Catalyst::Action::Serialize::JSON';
 is(action($class)->execute($cfg,$c,$callbacks),1,'Actual installed serializer completes: '.$mode);
 Catalyst::finalize_encoding($c);$wires{$mode}=$c->res->body;
 is($c->res->status,200,'Status preserved: '.$mode);
 like($c->res->content_type,qr/^\Q$mime\E(?:; charset=UTF-8)?$/,'Media type preserved: '.$mode);
 my $actual=$codec->encode($codec->decode($wires{$mode}));
 if($mode eq 'baseline-html'){isnt($actual,$expected,'Actual uncorrected serializer/finalizer reproduces Unicode corruption');}
 else {is($actual,$expected,'Every decoded value/type/key preserved through actual finalizer: '.$mode);}
 is($codec->encode($entity),$expected,'Source entity never mutated: '.$mode);
}
unlike($wires{iframe},qr/[^\x00-\x7f]|[<>&]/,'Iframe wire cannot be double UTF-8 encoded or interpreted as HTML/entities');
for my $class(qw(Catalyst::Action::Deserialize::JSON Catalyst::Action::Deserialize::Callback)) {
 for my $body($expected,'{"broken":','') {
  my $c=GenotypeIframeContext->new('text/html',$body);my $rc=action($class)->execute($cfg,$c,$callbacks);
  if($body eq $expected){is($rc,1,'Actual decoder accepts original request');is($codec->encode($c->req->data),$expected,'Original request values preserved');}
  elsif(length $body){isnt($rc,1,'Malformed request rejected');ok(!defined $c->req->data,'Malformed data not invented');}
  else {is($rc,1,'Empty body retains no-data completion');ok(!defined $c->req->data,'Empty body has no data');}
 }
}
my $scalar='Олена_Їжак_<b>raw</b>_&amp;';my $options={%$cfg,json_options_encode=>{allow_nonref=>1,ascii=>0},json_options=>{allow_nonref=>1}};
my $wire=$callbacks->{serialize}->($scalar,$options,undef);
unlike($wire,qr/[^\x00-\x7f]|[<>&]/,'Configured scalar still has safe iframe carrier');
is($callbacks->{deserialize}->($wire,$options,undef),$scalar,'Configured decoder retains scalar semantics');
if(my $dir=$ENV{I18N_GENOTYPE_IFRAME_EVIDENCE}) {
 die 'Existing external absolute evidence path required' unless $dir=~m{^/}&&-d $dir;
 for my $key(keys %wires){open my $f,'>:raw',"$dir/$key.json" or die $!;print {$f}$wires{$key};close $f;}
 open my $f,'>:raw',"$dir/expected.json" or die $!;print {$f}$expected;close $f;
}
done_testing;
