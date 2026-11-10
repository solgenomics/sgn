=head1 NAME

t/unit/SGN/I18NWithoutGettext.t - without libintl-perl the site stays English

=head1 DESCRIPTION

Hides Locale::Messages (libintl-perl), installs a language file and checks
that SGN::I18N gives English with one warning instead of failing. Runs with
or without libintl-perl installed.

=cut

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

done_testing();
