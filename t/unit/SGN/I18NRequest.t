=head1 NAME

t/unit/SGN/I18NRequest.t - language choice per request and the language selector action

=head1 DESCRIPTION

Tests SGN::Role::Site::I18N and SGN::Controller::I18N with a small fake
Catalyst context and .mo files built from the synthetic PO files in
t/data/i18n/po. Skipped when libintl-perl or msgfmt is missing.

=cut

package main;

use strict;
use warnings;
use utf8;

use lib 't/lib';
use Test::More;
use File::Temp qw(tempdir);
use Path::Class ();
use URI;
use HTTP::Headers;
use Catalyst::Response;
use SGN::Test::I18NFiles qw(missing_requirement build_translations);

BEGIN {
    my $missing = missing_requirement();
    plan skip_all => $missing if $missing;
}

use SGN::Controller::I18N;

{
    package Local::Request;
    sub new {
        return bless {
            params => {}, cookies => {}, headers => HTTP::Headers->new, method => 'POST',
            uri => URI->new('https://example.invalid/search/stocks?tag=A%26B&lang=en'),
        }, shift;
    }
    sub param   { return $_[0]{params}{ $_[1] } }
    sub cookies { return $_[0]{cookies} }
    sub headers { return $_[0]{headers} }
    sub method  { return $_[0]{method} }
    sub uri     { return $_[0]{uri} }

    package Local::Cookie;
    sub value { return $_[0]{value} }

    package Local::Log;
    sub warn { push @{ $_[0]{warnings} }, $_[1] }

    package Local::Context;
    use Moose;
    has config => (is => 'ro', default => sub { {} });
    has stash  => (is => 'ro', default => sub { {} });
    has req    => (is => 'ro', default => sub { Local::Request->new });
    has res    => (is => 'ro', default => sub { Catalyst::Response->new });
    has log    => (is => 'ro', default => sub { bless { warnings => [] }, 'Local::Log' });
    with 'SGN::Role::Site::I18N';
    sub path_to { shift; return Path::Class::dir('/nonexistent/sgn', @_) }
    sub throw_404 { die "404 not found\n" }
}

my $root = build_translations(tempdir(CLEANUP => 1));

# A second directory where the Arabic and Spanish files are not valid .mo files.
my $broken = build_translations(tempdir(CLEANUP => 1));
for my $locale (qw(ar es)) {
    my $messages = "$broken/LocaleData/$locale/LC_MESSAGES";
    Path::Class::dir($messages)->mkpath;
    Path::Class::file("$messages/sgn.mo")->spew('not a .mo file');
}

sub context {
    return Local::Context->new(config => {
        i18n_enabled => 1, i18n_dir => $root, i18n_enabled_locales => 'en,es,uk,ar', @_,
    });
}

subtest 'turned off: always English, no file is read' => sub {
    my $c = context(i18n_enabled => 0);
    $c->req->{params}{lang} = 'ar';
    $c->req->headers->header('Accept-Language' => 'uk');
    is($c->i18n->locale, 'en', 'English');
    is($c->stash->{i18n_locale_source}, 'disabled', 'reason recorded');
    is_deeply($c->log->{warnings}, [], 'nothing logged');
    for my $action (qw(runtime bootstrap)) {
        my $off = context(i18n_enabled => 0);
        my $lived = eval { SGN::Controller::I18N->$action($off); 1 };
        ok(!$lived && $@ =~ /^404/, "/i18n/$action.js is not found, as without this feature");
    }
};

subtest 'order of preferences' => sub {
    my $c = context();
    $c->req->headers->header('Accept-Language' => 'es;q=1, uk;q=0.8');
    is($c->i18n->locale, 'uk', 'browser preference, skipping a language without translations');
    is($c->stash->{i18n_locale_source}, 'header', 'source is the browser header');

    $c = context();
    $c->req->{cookies}{sgn_locale} = bless({ value => 'ar' }, 'Local::Cookie');
    $c->req->headers->header('Accept-Language' => 'uk');
    is($c->i18n->locale, 'ar', 'the saved cookie wins over the browser');

    $c = context();
    $c->req->{params}{lang} = 'ar-EG';
    $c->req->{cookies}{sgn_locale} = bless({ value => 'uk' }, 'Local::Cookie');
    is($c->i18n->locale, 'ar', 'the lang parameter wins and a regional tag uses its parent');
    is($c->i18n->dir, 'rtl', 'direction follows the language');

    # The browser runtime sends the page language with AJAX requests.
    $c = context();
    $c->req->headers->header('X-SGN-Locale' => 'uk');
    $c->req->headers->header('Accept-Language' => 'en');
    is($c->i18n->locale, 'uk', 'an AJAX request from a ?lang=uk page gets Ukrainian');
    is($c->stash->{i18n_locale_source}, 'explicit-header', 'source is the page header');

    $c = context();
    $c->req->headers->header('X-SGN-Locale' => 'de');
    $c->req->headers->header('Accept-Language' => 'ar');
    is($c->i18n->locale, 'ar', 'a header with a language that is not enabled is ignored');

    $c = context();
    $c->req->headers->header('X-SGN-Locale' => '../uk');
    is($c->i18n->locale, 'en', 'an invalid header is ignored');

    $c = context();
    $c->req->{params}{lang} = 'ar';
    $c->req->headers->header('X-SGN-Locale' => 'uk');
    is($c->i18n->locale, 'ar', 'the lang parameter wins over the header');

    $c = context(i18n_enabled => 0);
    $c->req->headers->header('X-SGN-Locale' => 'uk');
    is($c->i18n->locale, 'en', 'the header does nothing when translation is off');

    $c = context(i18n_default_locale => 'uk');
    is($c->i18n->locale, 'uk', 'site default when nothing else matches');

    $c = context();
    $c->req->{params}{lang} = 'en';
    is($c->i18n->locale, 'en', 'English is always available');
};

subtest 'missing or broken files are logged and skipped' => sub {
    my $c = context(i18n_dir => $broken);
    $c->req->{params}{lang} = 'ar';
    is($c->i18n->locale, 'en', 'a broken file falls back to English');
    is_deeply([ map { $_->{locale} } $c->i18n_locale_choices ], ['en', 'uk'], 'the selector lists only usable languages');
    is(scalar @{ $c->log->{warnings} }, 2, 'broken ar and es are each logged once');
    my $next = context(i18n_dir => $broken);
    $next->req->{params}{lang} = 'ar';
    is($next->i18n->locale, 'en', 'the next request also falls back');
    is(scalar @{ $next->log->{warnings} }, 0, '... without logging the same problem again');

    $c = context(i18n_dir => undef);
    $c->req->{params}{lang} = 'uk';
    is($c->i18n->locale, 'en', 'nothing at the default directory: English');
    like($c->log->{warnings}[0], qr{/nonexistent/sgn/\.\./sgn-translations/build}, 'the default directory is next to SGN');

    $c = context();
    is_deeply([ map { $_->{name} } $c->i18n_locale_choices ], ['English', 'Українська', 'العربية'],
        'the selector shows native names from the .mo headers');
};

subtest "the caller's \$_, \$\@ and \$! are preserved" => sub {
    my $c = context(i18n_dir => $broken);
    $c->req->{params}{lang} = 'es';
    local $_ = 'caller topic';
    local $@ = 'caller error';
    local $! = 2;
    my $errno = 0 + $!;
    my $translator = $c->i18n;
    is($translator->locale, 'en', 'the broken file was tried and skipped');
    is($_, 'caller topic', '$_ kept');
    is($@, 'caller error', '$@ kept');
    is(0 + $!, $errno, '$! kept');
};

subtest 'language selector action' => sub {
    my $c = context();
    $c->req->{params} = { locale => 'uk', return_to => '/search/stocks?tag=A%26B&lang=en&tag=%D0%96#results' };
    SGN::Controller::I18N->language($c);
    is($c->res->status, 303, 'redirect after POST');
    is($c->res->location, '/search/stocks?tag=A%26B&tag=%D0%96#results', 'back to the page, without the old lang');
    is($c->res->cookies->{sgn_locale}{value}, 'uk', 'choice saved');
    ok($c->res->cookies->{sgn_locale}{httponly}, 'cookie is HTTP only');

    for my $bad ('//evil.invalid', '/%2fevil.invalid', '/%252fevil.invalid', '/\\evil.invalid',
                 '/ok%0d%0aLocation:x', ' /evil', 'https://evil.invalid', "/foo\nbar") {
        is(SGN::Controller::I18N::_return_path($bad), '/', "unsafe return address rejected: $bad");
    }

    $c = context();
    $c->req->{params}{locale} = 'es';
    SGN::Controller::I18N->language($c);
    is($c->res->status, 400, 'a language without translations cannot be chosen');
    ok(!exists $c->res->cookies->{sgn_locale}, 'the old choice is kept');

    $c = context();
    $c->req->{method} = 'GET';
    SGN::Controller::I18N->language($c);
    is($c->res->status, 405, 'GET is refused');

    $c = context(i18n_enabled => 0);
    $c->req->{params}{locale} = 'uk';
    my $lived = eval { SGN::Controller::I18N->language($c); 1 };
    ok(!$lived && $@ =~ /^404/, '/i18n/language is not found when translation is off, as without this feature');
    ok(!exists $c->res->cookies->{sgn_locale}, '... and no cookie is set');
};

subtest 'browser messages can be kept per language and build' => sub {
    my $version = SGN::I18N->new(locale => 'uk', dir => $root)->version;
    like($version, qr/\A[0-9]+-[0-9]+\z/, 'the version is the time and size of the language file');
    is(SGN::I18N->new(locale => 'en', dir => $root)->version, '', 'English has no version');
    my $bootstrap = sub {
        my (%params) = @_;
        my $c = context();
        $c->req->{params} = { workflow => 'trial_card', %params };
        SGN::Controller::I18N->bootstrap($c);
        return $c->res->headers->header('Cache-Control');
    };
    is($bootstrap->(lang => 'uk', v => $version), 'private, max-age=31536000, immutable',
        'language from the address and the current version: the browser may keep it');
    is($bootstrap->(lang => 'uk'), 'private, no-store', 'no version: not stored');
    is($bootstrap->(lang => 'uk', v => '1-1'), 'private, no-store', 'an old version: not stored');
    is($bootstrap->(v => $version), 'private, no-store', 'language from the cookie or the browser: not stored');
};

done_testing();
