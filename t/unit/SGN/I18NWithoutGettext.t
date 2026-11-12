=head1 NAME

t/unit/SGN/I18NWithoutGettext.t - without libintl-perl the site stays English

=head1 DESCRIPTION

Hides Locale::Messages (libintl-perl), installs a language file and checks
that SGN::I18N gives English with one warning instead of failing. Runs with
or without libintl-perl installed.

=cut

package main;

use strict;
use warnings;
use utf8;

use Test::More;
use File::Temp qw(tempdir);
use File::Path qw(make_path);

# Make "require Locale::Messages" fail as if libintl-perl were not installed.
BEGIN {
    unshift @INC, sub {
        my (undef, $file) = @_;
        die "Can't locate $file (hidden by the test)\n" if $file =~ m{\ALocale/};
        return;
    };
}
use SGN::I18N;

my $dir = tempdir(CLEANUP => 1);
make_path("$dir/LocaleData/uk/LC_MESSAGES");
open(my $mo, '>', "$dir/LocaleData/uk/LC_MESSAGES/sgn.mo") or die $!;
close($mo);

my @warnings;
local $SIG{__WARN__} = sub { push @warnings, @_ };

my $uk = SGN::I18N->new(locale => 'uk', dir => $dir);
is($uk->locale, 'en', 'the language falls back to English');
is($uk->p('navigation.manage.menu', 'Manage'), 'Manage', 'messages are English');
is($uk->np('trials.count', '%{count} trial', '%{count} trials', 2, { count => 2 }), '2 trials', 'plurals are English');
is(scalar @{ $uk->browser_catalog('global')->{catalogs} }, 0, 'the browser gets no messages');
SGN::I18N->new(locale => 'uk', dir => $dir) for 1 .. 3;
is(scalar @warnings, 1, 'one warning');
like($warnings[0], qr/libintl-perl\) is not installed/, 'the warning says what is missing');

# The site role adds no warning per language on top of it.
{
    package Local::Log;
    sub warn { push @{ $_[0]{warnings} }, $_[1] }

    package Local::Context;
    use Moose;
    has config => (is => 'ro', default => sub { {} });
    has stash  => (is => 'ro', default => sub { {} });
    has log    => (is => 'ro', default => sub { bless { warnings => [] }, 'Local::Log' });
    has req    => (is => 'ro', default => sub { Local::Request->new });
    with 'SGN::Role::Site::I18N';
    sub finalize_headers { }

    package Local::Request;
    use HTTP::Headers;
    sub new     { return bless { headers => HTTP::Headers->new }, shift }
    sub param   { return }
    sub cookies { return {} }
    sub headers { return $_[0]{headers} }
}
make_path("$dir/LocaleData/ar/LC_MESSAGES");
my $c = Local::Context->new(config => { i18n_enabled => 1, i18n_dir => $dir, i18n_enabled_locales => 'en,uk,ar' });
is_deeply([ map { $_->{locale} } $c->i18n_locale_choices ], ['en'], 'the selector offers English only');
is($c->i18n->locale, 'en', 'the page is English');
is_deeply($c->log->{warnings}, [], 'the site role logs nothing more');
is(scalar @warnings, 1, 'still one warning in this process');

done_testing();
