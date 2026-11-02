use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use JSON::PP;
use URI;
use HTTP::Headers;
use Catalyst::Response;
use SGN::Controller::I18N;
{
    package Local::LocaleRequest;
    sub new { bless {params => {}, cookies => {}, headers => HTTP::Headers->new, method => 'POST', uri => URI->new('https://example.invalid/search/stocks?tag=A%26B&lang=en')}, shift }
    sub param { $_[0]{params}{$_[1]} }
    sub cookies { $_[0]{cookies} }
    sub headers { $_[0]{headers} }
    sub method { $_[0]{method} }
    sub uri { $_[0]{uri} }
    package Local::LocaleLog;
    sub warn { push @{$_[0]{warnings}}, $_[1] }
    package Local::LocaleContext;
    use Moose;
    has config => (is => 'ro', default => sub {{}});
    has stash => (is => 'ro', default => sub {{}});
    has req => (is => 'ro', default => sub { Local::LocaleRequest->new });
    has res => (is => 'ro', default => sub { Catalyst::Response->new });
    has log => (is => 'ro', default => sub { bless {warnings => []}, 'Local::LocaleLog' });
    with 'SGN::Role::Site::I18N';
}
my $root = tempdir(CLEANUP => 1);
open my $fh, '<:raw', 't/unit/SGN/i18n-fixtures.json' or die $!;
my $fixtures = JSON::PP->new->utf8->decode(do { local $/; <$fh> });
close $fh;
sub write_catalog {
    my ($locale, $text) = @_;
    make_path("$root/$locale");
    open my $out, '>:raw', "$root/$locale/sgn.json" or die $!;
    print {$out} defined($text) ? $text : JSON::PP->new->utf8->encode($fixtures->{catalogs}{$locale});
    close $out;
}
write_catalog('uk'); write_catalog('ar');
sub context {
    return Local::LocaleContext->new(config => {i18n_enabled => 1, i18n_catalog_dir => $root, i18n_enabled_locales => 'en,es,uk,ar', @_});
}
subtest 'missing and corrupt unselected languages are isolated' => sub {
    my $c = context();
    $c->req->headers->header('Accept-Language' => 'es;q=1,uk;q=0.8');
    is($c->i18n->locale, 'uk', 'Negotiation skips missing configured catalog');
    is_deeply([map {$_->{locale}} $c->i18n_locale_choices], ['en','uk','ar'], 'Selector offers installed catalogs only');
    write_catalog('ar', '{}');
    $c = context(); $c->req->{params}{lang} = 'en';
    is($c->i18n->locale, 'en', 'English request survives corrupt other catalog');
    is_deeply([map {$_->{locale}} $c->i18n_locale_choices], ['en','uk'], 'Corrupt language is omitted');
    is(scalar @{$c->log->{warnings}}, 1, 'Catalog failure is logged once per request');
    write_catalog('ar');
};
subtest 'explicit preference, cookie, regional fallback and disabled feature' => sub {
    my $c = context();
    $c->req->{params}{lang} = 'ar-EG';
    $c->req->headers->header('Accept-Language' => 'uk');
    is($c->i18n->locale, 'ar', 'Explicit regional tag matches configured parent');
    is($c->i18n->dir, 'rtl', 'Direction follows actual selected catalog');
    $c = context(i18n_enabled => 0);
    $c->req->{params}{lang} = 'ar';
    is($c->i18n->locale, 'en', 'Disabled feature retains English');
    write_catalog('en', '{}');
    $c = context(i18n_enabled => 0);
    is($c->i18n->locale, 'en', 'Disabled feature never reads an external English catalog');
    $c = context(); $c->req->{params}{lang} = 'en';
    is($c->i18n->locale, 'en', 'Explicit source language never reads an external English catalog');
    unlink "$root/en/sgn.json" or die $!;
};
subtest 'language POST retains local navigation and removes stale lang override' => sub {
    my $c = context();
    $c->req->{params} = {locale => 'uk', return_to => '/search/stocks?tag=A%26B&lang=en&tag=%D0%96#results'};
    SGN::Controller::I18N->language($c);
    is($c->res->status, 303, 'Native POST redirect');
    is($c->res->location, '/search/stocks?tag=A%26B&tag=%D0%96#results', 'Search bytes, repeated parameters and fragment retained');
    is($c->res->cookies->{sgn_locale}{value}, 'uk', 'Saved language is applied');
    ok($c->res->cookies->{sgn_locale}{httponly}, 'Cookie remains HTTP-only');
    for my $bad ('//evil.invalid', '/%2fevil.invalid', '/%252fevil.invalid', '/\\evil.invalid', '/ok%0d%0aLocation:x', " /evil", 'https://evil.invalid', '/foo%5cevil', "/foo\nbar") {
        is(SGN::Controller::I18N::_return_path($bad), '/', 'Unsafe return target rejected');
    }
    is(SGN::Controller::I18N::_return_path('/search/stocks?tag=x;lang=en'), '/search/stocks?tag=x', 'Semicolon query override is removed');
    is(SGN::Controller::I18N::_return_path('/search/stocks?lang=en;tag=x'), '/search/stocks?tag=x', 'Semicolon query data is retained');
    $c = context(); $c->req->{params}{locale} = 'es';
    SGN::Controller::I18N->language($c);
    is($c->res->status, 400, 'Missing package cannot be selected');
    ok(!exists $c->res->cookies->{sgn_locale}, 'Failed selection does not replace preference');
    $c = context(); $c->req->{method} = 'GET';
    SGN::Controller::I18N->language($c);
    is($c->res->status, 405, 'GET cannot change preference');
};
subtest 'manual links use published locales and safe English fallback' => sub {
    my $c = context(i18n_manual_locales => 'en,uk,ar');
    $c->req->{params}{lang} = 'uk';
    is($c->i18n_manual_url, 'https://solgenomics.github.io/sgn/uk/', 'Published matching manual');
    $c = context(); $c->req->{params}{lang} = 'uk';
    is($c->i18n_manual_url, 'https://solgenomics.github.io/sgn/', 'Unpublished manual retains English link');
};
done_testing;
