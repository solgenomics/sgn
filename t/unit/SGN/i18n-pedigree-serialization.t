package main;
use strict;
use warnings;
use utf8;
use Test::More;
use File::Spec;
use FindBin;
use lib 'lib';
BEGIN {unshift @INC,$ENV{I18N_TEST_PRODUCT_LIB_ROOT} if $ENV{I18N_TEST_PRODUCT_LIB_ROOT};}
use JSON ();
use Encode qw(decode);
use Scalar::Util qw(refaddr);
use Catalyst;
use Catalyst::Response;
use Catalyst::Action::Serialize;
use Catalyst::Action::Serialize::JSON;
use SGN::Controller::AJAX::Pedigrees;
use SGN::Controller::AJAX::Cross;
use Plack::Test;
use HTTP::Request::Common qw(GET);
# Real controller source/config and real response/serializer/finalize classes.
# Minimal HTTP context only; no app, database, upload archive or model store.
{
 package OwnedPedigreeResponseContext;
 sub new {my $s=bless {stash=>{}},shift;$s->{response}=Catalyst::Response->new(_context=>$s);return $s;}
 sub res {shift->{response}} sub response {shift->{response}} sub stash {shift->{stash}}
 sub encoding {Encode::find_encoding('UTF-8')} sub _encode_check {Encode::FB_CROAK()|Encode::LEAVE_SRC()} ## no critic (Bangs::ProhibitBitwiseOperators) # Match Encode's required combined strict UTF-8/source-preservation flags.
}
my $owned_config=SGN::Controller::AJAX::Pedigrees->config;
my $peer_config=SGN::Controller::AJAX::Cross->config;
is_deeply($owned_config->{json_options_encode},{ascii=>1},'Whole real Pedigrees controller owns its ASCII JSON response option');
ok(!($peer_config->{json_options_encode}||{})->{ascii},'Independent crossing controller JSON policy remains unchanged');
isnt(refaddr($owned_config),refaddr($peer_config),'Whole actual controller configuration objects are independent');
my $owned_json=Catalyst::Action::Serialize::JSON->new(name=>'json',code=>sub{},class=>'SGN::Controller::AJAX::Pedigrees',namespace=>'ajax/pedigrees',reverse=>'ajax/pedigrees/json');
my $peer_json=Catalyst::Action::Serialize::JSON->new(name=>'json',code=>sub{},class=>'SGN::Controller::AJAX::Cross',namespace=>'ajax/cross',reverse=>'ajax/cross/json');
my $row={'progeny name'=>'Seedling_нащадок_é_試験_نسل_<b>A & B</b>_&amp;','female parent accession'=>'Female_Жіночий_é_母_تجربة','male parent accession'=>'Male_Чоловічий_é_父_تجربة',type=>'biparental',_row=>2};
my $error='Жіночий зразок é 母 не знайдено: <b>A & B</b><br>';
my $error_string='لم يتم العثور على الأب تجربة / 17.25 kg / <tag>literal</tag><br>';
my $inner=JSON::encode_json({pedigrees=>[$row]});
my $payload={pedigree_data=>$inner,error=>$error,error_string=>$error_string,scientific_values=>[17.25,-76.5,0,'0',undef,'kg']};
my $before=JSON->new->canonical->encode($payload);
my $app=sub {
 my $env=shift;my $ct=$env->{HTTP_ACCEPT};my $c=OwnedPedigreeResponseContext->new;
 $c->stash->{rest}=$payload;$c->res->content_type($ct);
 $owned_json->execute($owned_config,$c);
 ok(!$c->res->body||!utf8::is_utf8($c->res->body),'Actual JSON serializer emits octets');
 ok($c->res->body!~/[^\x00-\x7f]/,'Entire owned response wire is ASCII, including Unicode human fields');
 Catalyst::finalize_encoding($c);
 return [200,['Content-Type'=>$c->res->content_type],[$c->res->body]];
};
test_psgi $app,sub {
 my $cb=shift;
 for my $ct(qw(application/json text/html)){
  my $http=$cb->(GET('http://localhost/owned-pedigree-response',Accept=>$ct));
  is($http->code,200,'Actual HTTP roundtrip succeeds: '.$ct);
  like($http->header('Content-Type'),qr/^\Q$ct\E(?:; charset=UTF-8)?$/,'Original response media type/charset policy retained');
  my $outer=JSON::decode_json($http->content);
  is_deeply([sort keys %$outer],[sort keys %$payload],'Exact legacy response field schema remains');
  is($outer->{error},$error,'Whole Ukrainian error field survives: '.$ct);
  is($outer->{error_string},$error_string,'Whole Arabic validation error field survives: '.$ct);
  is($outer->{pedigree_data},$inner,'Nested machine JSON scalar reaches client unchanged: '.$ct);
  my $stored=JSON::decode_json($outer->{pedigree_data});
  is_deeply($stored->{pedigrees}[0],$row,'Existing store decode_json receives exact Unicode/literal canonical pedigree values: '.$ct);
  is_deeply($outer->{scientific_values},$payload->{scientific_values},'Decimals/sign/zero/string-zero/null/units untouched: '.$ct);
  is(JSON->new->canonical->encode($payload),$before,'Actual serializer/finalize does not mutate response data');
 }
};
ok($owned_json->encoder->get_ascii,'Owned JSON encoder applies existing controller option');
ok(!$peer_json->encoder->get_ascii,'Independent peer encoder is not mutated');
isnt(refaddr($owned_json->encoder),refaddr($peer_json->encoder),'Actual JSON encoder objects are independent');
done_testing;
