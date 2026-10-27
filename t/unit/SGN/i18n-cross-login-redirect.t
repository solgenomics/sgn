package main;
use strict;
use warnings;
use utf8;
use lib 'lib';
BEGIN {unshift @INC,$ENV{I18N_TEST_PRODUCT_LIB_ROOT} if $ENV{I18N_TEST_PRODUCT_LIB_ROOT};}
use Test::More;
use Catalyst::Request;
use Catalyst::Response;
use Catalyst::Log;
use URI;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use JSON::PP;
use SGN::I18N;
use SGN::Controller::BreedersToolbox;
# Invoke the whole actual controller method. Only its unauthenticated request
# context is controlled; any attempted database/config/model work is fatal.
{
    package OwnedCrossLoginContext;
    sub new {
        my ($class,$url,$translator)=@_;
        my $self=bless {translator=>$translator,db_calls=>0},$class;
        $self->{request}=Catalyst::Request->new(uri=>URI->new($url),_context=>$self,_log=>Catalyst::Log->new);
        $self->{response}=Catalyst::Response->new(_context=>$self);
        return $self;
    }
    sub req {shift->{request}}
    sub res {shift->{response}}
    sub i18n {shift->{translator}}
    sub user {return undef}
    sub dbic_schema {++$_[0]{db_calls};die 'Unauthenticated redirect must not touch a database'}
    sub config {die 'Unauthenticated redirect must not read application/role configuration'}
    sub stash {die 'Unauthenticated redirect must not enter the authorized page model'}
    sub debug {return 0}
}
my $catalog_root;
if ($ENV{I18N_TEST_CATALOG_ROOT}) {
    $catalog_root = $ENV{I18N_TEST_CATALOG_ROOT};
} elsif (-f 'locale/build/uk/sgn.json' && -f 'locale/build/ar/sgn.json') {
    $catalog_root = 'locale/build';
} else {
    # The source checkout does not commit compiled catalogs. Keep the redirect
    # integration test deterministic in native CI by using the unit locale packs.
    my $fixture_path = 't/unit/SGN/i18n-fixtures.json';
    open my $fixture_file, '<:raw', $fixture_path or die $!;
    my $fixtures = JSON::PP->new->utf8->decode(do { local $/; <$fixture_file> });
    close $fixture_file;
    $catalog_root = tempdir(CLEANUP => 1);
    for my $locale (qw(uk ar pt-BR pt-PT)) {
        make_path("$catalog_root/$locale");
        open my $catalog, '>:raw', "$catalog_root/$locale/sgn.json" or die $!;
        print {$catalog} JSON::PP->new->utf8->canonical->encode($fixtures->{catalogs}{$locale});
        close $catalog;
    }
}
my $missing_root=tempdir(CLEANUP=>1);
my $controller='SGN::Controller::BreedersToolbox';
for my $case(['en',$catalog_root,'en','ltr'],['uk',$catalog_root,'uk','ltr'],
    ['ar',$catalog_root,'ar','rtl'],['ar-EG',$catalog_root,'ar','rtl'],['pt-BR',$missing_root,'en','ltr']) {
    my ($requested,$packs,$effective,$direction)=@$case;
    my $translator=SGN::I18N->new(locale=>$requested,catalog_root=>$packs,domain=>'sgn');
    is($translator->locale,$effective,'Real source request locale resolves as expected: '.$requested);
    is($translator->dir,$direction,'Real source request direction resolves as expected: '.$requested);
    my $url='http://127.0.0.1:3010/breeders/crosses?lang='.$requested.'&tag=A%26B%2B17&field=%D0%96%D1%96%D0%BD%D0%BE%D1%87%D0%B8%D0%B9';
    my $c=OwnedCrossLoginContext->new($url,$translator);
    my $path_query=$c->req->uri->path_query;
    my $result=eval {$controller->manage_crosses($c)};
    is($@,'','Whole actual unauthenticated method returns without database work: '.$requested);
    is($result,undef,'Original unauthenticated early-return result is retained');
    is($c->res->status,302,'Original native login redirect status is retained');
    my $location=URI->new($c->res->location);
    is($location->path,'/user/login','Original native login destination is retained');
    my %query=$location->query_form;
    is($query{goto_url},$path_query,'Return path/query bytes, Unicode escapes and delimiters are unchanged');
    is($query{lang},$requested,'Requested locale travels separately to the native login page: '.$requested);
    is_deeply([sort keys %query],[qw(goto_url lang)],'Only return path and presentation locale are carried');
    my $target=SGN::I18N->new(locale=>$query{lang},catalog_root=>$packs,domain=>'sgn');
    is($target->requested_locale,$requested,'Real target translator retains the requested locale, including regional/missing packs');
    is($target->locale,$effective,'Real target HTML locale follows the existing catalog fallback policy');
    is($target->dir,$direction,'Real target HTML direction follows the existing catalog fallback policy');
    is($c->{db_calls},0,'No DB/CV/schema/role/model call occurs at the redirect boundary');
}
done_testing;
