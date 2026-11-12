=head1 NAME

t/unit/SGN/I18NSiteFrame.t - header, menus, login and footer with translation off and on

=head1 DESCRIPTION

Renders the real site frame components (mason/site/header.mas, toolbar,
login dialog and footer) with HTML::Mason and a small fake Catalyst context
that uses SGN::Role::Site::I18N. Components that need a database are replaced
by stubs. The .mo files are built from the synthetic PO files in
t/data/i18n/po; the translation-on checks are skipped when libintl-perl or
msgfmt is missing.

With translation off the English page must not change and must not load the
translation scripts, even when translations are installed. With translation on the
frame text, the page language and the language selector must follow the
chosen language.

=cut

package main;

use strict;
use warnings;
use utf8;

use lib 't/lib';
use Test::More;
use Cwd qw(abs_path);
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use HTML::Mason::Interp;
use Path::Class ();
use URI;
use HTTP::Headers;
use HTML::Entities qw(decode_entities);
use Catalyst::Response;
use SGN::Test::I18NFiles qw(missing_requirement build_translations);

# The translation-off checks need no translation files; the others do.
my $missing = missing_requirement();

{
    package Local::Request;
    sub new {
        my ($class, %args) = @_;
        return bless { params => $args{params} || {}, cookies => {}, headers => HTTP::Headers->new,
            uri => URI->new('http://localhost/breeders/trials?program=A%26B') }, $class;
    }
    sub param   { return $_[0]{params}{ $_[1] } }
    sub cookies { return $_[0]{cookies} }
    sub headers { return $_[0]{headers} }
    sub uri     { return $_[0]{uri} }
    sub path    { return 'breeders/trials' }

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
    sub user     { return }
    sub get_conf { return $_[0]->config->{ $_[1] } }
    sub path_to  { shift; return Path::Class::file(Cwd::abs_path('.'), @_) }
    sub finalize_headers { }
}

my $translations = $missing ? '/nonexistent' : build_translations(tempdir(CLEANUP => 1));

# Components that need a database or other services are not under test.
my $stubs = tempdir(CLEANUP => 1);
my %stub = (
    'util/import_css.mas'               => '',
    'util/import_javascript.mas'        => '<script src="/js/page-scripts.js"></script>',
    'site/header/local_head.mas'        => '',
    'site/header/analytics.mas'         => '',
    'site/header/browser_alert.mas'     => '',
    'system_message.mas'                => '',
    'cookie_popup.mas'                  => '',
    'site/list.mas'                     => '',
    'site/dataset.mas'                  => '',
    'calendar/events_by_user_role.mas'  => '',
);
for my $path (keys %stub) {
    my $file = "$stubs/$path";
    (my $dir = $file) =~ s{/[^/]+\z}{};
    make_path($dir);
    open(my $out, '>', $file) or die $!;
    print $out $stub{$path};
    close($out);
}

my $data_dir = tempdir(CLEANUP => 1);

sub render_frame {
    my (%args) = @_;
    my $c = Local::Context->new(
        config => {
            i18n_enabled => $args{enabled}, i18n_dir => $translations, i18n_enabled_locales => 'en,uk,ar',
            require_login => 0,
        },
        req => Local::Request->new(params => { lang => $args{lang} }),
    );
    my $html = '';
    my $interp = HTML::Mason::Interp->new(
        comp_root => [ [ stubs => $stubs ], [ main => abs_path('mason') ] ],
        data_dir => $data_dir, allow_globals => ['$c'], preamble => 'use utf8; ',
        autohandler_name => '', out_method => \$html,
    );
    $interp->set_global('$c', $c);
    $interp->exec('/site/header.mas');
    $interp->exec('/site/footer.mas');
    return $html;
}

my $english_location = '<span style="font-face:arial;font-size:10pt;color:darkgreen;font-weight:light;">'
    . 'BREE<b>DB</b>ASE</span> is located at the <a href="https://btiscience.org">Boyce Thompson Institute</a>.';

subtest 'translation off: English page, no translation scripts, even with files installed' => sub {
    for my $lang (undef, 'uk') {
        my $label = defined $lang ? "?lang=$lang" : 'no language requested';
        my $html = render_frame(enabled => 0, lang => $lang);
        like($html, qr{<html>\n}, "$label: plain <html> element");
        unlike($html, qr{/i18n/}, "$label: no /i18n/ scripts or form");
        unlike($html, qr{sgn-language}, "$label: no language selector");
        unlike($html, qr{sendLocaleWithAjax}, "$label: AJAX requests get no language header");
        like($html, qr{>Manage</a>}, "$label: English menu");
        like($html, qr{>Kinship &amp; Inbreeding</a>}, "$label: menu text is HTML-escaped");
        like($html, qr{id="site_login_dialog_title">Login</h3>}, "$label: English login dialog");
        like($html, qr{\Q$english_location\E}, "$label: footer sentence keeps its HTML");
        like($html, qr{<strong>Version</strong>}, "$label: English footer");
        like($html, qr{confirm\(SGN\.t\('navigation\.login\.confirm_logout', 'Are you sure you want to log out\?'\)\)},
            "$label: logout question goes through SGN.t");
    }
};

subtest 'translation on: Ukrainian' => sub {
    plan skip_all => $missing if $missing;
    # Mason's |h writes non-ASCII letters as character references; compare text.
    my $html = decode_entities(render_frame(enabled => 1, lang => 'uk'));
    like($html, qr{<html lang="uk" dir="ltr" data-sgn-locale="uk">}, 'page language and direction');
    like($html, qr{/i18n/runtime\.js.*/i18n/bootstrap\.js\?lang=uk&workflow=.*/js/page-scripts\.js}s,
        'translation scripts load before the page scripts');
    like($html, qr{/i18n/bootstrap\.js\?lang=uk&workflow=&v=[0-9]+-[0-9]+"},
        'a page without its own section gets only the common messages; the address names the build');
    like($html, qr{<!-- INSERT_HEAD_POST_HTML -->\n<script>SGN\.I18N\.sendLocaleWithAjax\(jQuery, window\);</script>},
        'AJAX requests send the page language; set up after the marker where SGN inserts jQuery');
    like($html, qr{>Керування</a>}, 'menu translated');
    like($html, qr{>Пошук</a>}, 'search menu translated');
    like($html, qr{>Спорідненість і інбридинг</a>}, 'menu item translated');
    like($html, qr{>Accessions</a>}, 'a message without translation stays English');
    like($html, qr{id="site_login_dialog_title">Вхід</h3>}, 'login dialog translated');
    like($html, qr{<strong>Версія</strong>}, 'footer translated');
    like($html, qr{BREE<b>DB</b>ASE</span> розміщено в <a href="https://btiscience.org">Boyce Thompson Institute</a>\.},
        'footer sentence translated around its HTML parts');

    my $selector = index($html, 'id="sgn-language"');
    my $login = index($html, 'id="login_button_html_div"');
    ok($selector > 0 && $login > $selector, 'language selector comes before (left of) the login button');
    like($html, qr{<label for="sgn-language">Мова</label>}, 'selector label translated');
    like($html, qr{<option value="uk" selected="selected" lang="uk" dir="auto">Українська</option>},
        'current language selected, shown by its native name');
    like($html, qr{<option value="ar" lang="ar" dir="auto">العربية</option>}, 'other installed language offered');
    like($html, qr{name="return_to" value="/breeders/trials\?program=A%26B"}, 'selector returns to the same page');
    like($html, qr{SGN\.I18N\.keepSelectorLanguage\(select, window\)},
        'the selector keeps showing the page language when page scripts reset every <select>');
};

subtest 'translation on: Arabic is right to left' => sub {
    plan skip_all => $missing if $missing;
    my $html = decode_entities(render_frame(enabled => 1, lang => 'ar'));
    like($html, qr{<html lang="ar" dir="rtl" data-sgn-locale="ar">}, 'direction from the .mo header');
};

subtest 'translation on: English request' => sub {
    plan skip_all => $missing if $missing;
    my $html = render_frame(enabled => 1, lang => 'en');
    like($html, qr{<html lang="en" dir="ltr" data-sgn-locale="en">}, 'English page');
    like($html, qr{>Manage</a>}, 'English menu');
    like($html, qr{<option value="en" selected="selected" lang="en" dir="auto">English</option>}, 'English selected');
};

done_testing();
