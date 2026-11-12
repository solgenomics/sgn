=head1 NAME

t/unit/SGN/I18N.t - gettext lookup, plurals, fallbacks and browser files of SGN::I18N

=head1 DESCRIPTION

Builds .mo files from the synthetic PO files in t/data/i18n/po with msgfmt and
reads them through libintl-perl. Skipped when libintl-perl or msgfmt is
missing. No database or server needed.

=cut

use strict;
use warnings;
use utf8;

use lib 't/lib';
use Test::More;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use JSON::PP;
use POSIX qw(setlocale LC_ALL LC_MESSAGES);
use SGN::Test::I18NFiles qw(missing_requirement build_translations);

BEGIN {
    my $missing = missing_requirement();
    plan skip_all => $missing if $missing;
}

use SGN::I18N;

my $dir = build_translations(tempdir(CLEANUP => 1));
my $json = JSON::PP->new->utf8->canonical;

sub translator { return SGN::I18N->new(locale => $_[0], dir => $dir) }

sub dies_like {
    my ($code, $pattern, $name) = @_;
    my $lived = eval { $code->(); 1 };
    ok(!$lived && $@ =~ $pattern, $name) or diag($@ || 'no error');
}

sub warnings_of {
    my ($code) = @_;
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, @_ };
    my @result = $code->();
    return (\@warnings, @result);
}

sub write_file {
    my ($path, $bytes) = @_;
    (my $parent = $path) =~ s{/[^/]+\z}{};
    make_path($parent);
    open(my $fh, '>:raw', $path) or die "Cannot write $path: $!";
    print $fh $bytes;
    close($fh);
}

subtest 'language selection and English fallback' => sub {
    my $uk = translator('UK-ua');
    is($uk->requested_locale, 'uk-UA', 'language tag is normalized');
    is($uk->locale, 'uk', 'a missing regional file falls back to its parent');
    is($uk->dir, 'ltr', 'Ukrainian is left to right');
    is($uk->language_name, 'Українська', 'native name from the .mo header');
    is(translator('ar')->dir, 'rtl', 'direction from the .mo header');
    is(translator('zz')->locale, 'en', 'a language without a file uses English');
    is(SGN::I18N->new(locale => 'uk')->p('controls.save', 'Save'), 'Save', 'without a directory: English');
    is(SGN::I18N->new->language_name, 'English', 'English has its own name');
    dies_like(sub { translator('../../etc') }, qr/Invalid locale/, 'a language tag cannot leave the directory');
};

subtest 'messages, context and placeholders' => sub {
    my $uk = translator('uk');
    is($uk->p('controls.save', 'Save'), 'Зберегти', 'translated message');
    is($uk->p('seedlots.save', 'Save'), 'Зберегти партію', 'the same English text in another context is a different message');
    is($uk->p('', 'Save'), 'Зберегти без контексту', 'empty context is allowed');
    is($uk->p('controls.save', 'Save changes'), 'Save changes', 'changed English text falls back to English');
    my $name = q{</script><img src=x onerror=alert(1)>};
    is($uk->p('trial.named', 'Created trial %{name}.', { name => $name }), "Створено дослід $name.",
        'values are inserted as plain text; escaping is done where the text is printed');
    is($uk->p('literal', 'Keep {braces} and %{name}.', { name => 'value' }), 'Keep {braces} and value.', 'bare braces stay');
    is($uk->p('literal', 'Value: %{name}', { name => '%{other}' }), 'Value: %{other}', 'values are substituted once');
    dies_like(sub { $uk->p('trial.named', 'Created trial %{name}.', {}) }, qr/Missing or invalid named variable/,
        'a value missing in the call is an error, as in English');
};

subtest 'plural forms follow the rules of the language file' => sub {
    my $uk = translator('uk');
    my %ukrainian = (0 => 'дослідів', 1 => 'дослід', 2 => 'досліди', 5 => 'дослідів', 11 => 'дослідів',
        21 => 'дослід', 22 => 'досліди', 101 => 'дослід');
    for my $count (sort { $a <=> $b } keys %ukrainian) {
        is($uk->np('trials.count', '%{count} trial found', '%{count} trials found', $count, { count => $count }),
            "Знайдено $count $ukrainian{$count}", "Ukrainian, $count");
    }
    my $ar = translator('ar');
    for my $case ([0, 0], [1, 1], [2, 2], [3, 3], [11, 4], [100, 5]) {
        my ($count, $form) = @$case;
        is($ar->np('trials.count', '%{count} trial found', '%{count} trials found', $count, { count => $count }),
            "ar[$form] $count", "Arabic, $count uses form $form");
    }
    my $brazil = translator('pt-BR');
    is($brazil->np('trials.count', '%{count} trial found', '%{count} trials found', 0, { count => 0 }),
        'pt-BR[0] 0', 'Brazilian Portuguese: 0 is singular');
    is(translator('pt')->np('trials.count', '%{count} trial found', '%{count} trials found', 0, { count => 0 }),
        'pt[1] 0', 'Portuguese: 0 is plural');
    is($brazil->p('controls.save', 'Save'), 'Salvar (pt)', 'a message missing from pt-BR comes from pt');
    is($uk->np('missing', '%{count} trial', '%{count} trials', 21, { count => 21 }), '21 trials',
        'English fallback uses English plural rules');
    is($uk->np('missing', '%{count} trial', '%{count} trials', 1, { count => 1 }), '1 trial', '... singular');
    # As in GNU gettext, a message is found by its context and singular English
    # text; the browser runtime does the same (i18n-runtime.test.cjs).
    is($uk->np('trials.count', '%{count} trial found', '%{count} trials matched', 5, { count => 5 }),
        'Знайдено 5 дослідів', 'a changed English plural text alone keeps the translation, as in gettext');
    is($uk->p('trials.count', '%{count} trial found', { count => 1 }), 'Знайдено 1 дослід',
        'p on a plural message gives its first form');
    is($uk->np('controls.save', 'Save', 'Saves', 5), 'Зберегти', 'np on a message without plural forms gives its text');
    for my $bad (-1, 1.5, undef, 'many', '9007199254740992') {
        dies_like(sub { $uk->np('trials.count', 'one', 'many', $bad) }, qr/Plural count/, 'invalid count rejected');
    }
};

subtest 'a broken translation shows English and never breaks the page' => sub {
    my $uk = translator('uk');
    my ($warnings, $text) = warnings_of(sub { $uk->p('broken.placeholder', 'Menu') });
    is($text, 'Menu', 'a translation with an unknown placeholder is replaced by English');
    is(scalar @$warnings, 1, 'one warning');
    like($warnings->[0], qr/unknown placeholder %\{oops\}/, 'the warning names the placeholder');
    ($warnings) = warnings_of(sub { $uk->p('broken.placeholder', 'Menu') for 1 .. 3 });
    is(scalar @$warnings, 0, 'the same problem is not logged again');
    is($uk->np('broken.plural', '%{count} file', '%{count} files', 1, { count => 1 }), '1 файл',
        'the good forms of a plural message are used');
    ($warnings, $text) = warnings_of(sub { $uk->np('broken.plural', '%{count} file', '%{count} files', 2, { count => 2 }) });
    is($text, '2 files', 'a broken plural form is replaced by English');
    is(scalar @$warnings, 1, 'one warning');
};

subtest 'browser files: common plus the section of the page' => sub {
    my $section = $json->decode($json->encode(translator('uk')->browser_catalog->{catalogs}[0]));
    $section->{messages} = { "trials.count\x04%{count} trial found" => $section->{messages}{"trials.count\x04%{count} trial found"} };
    write_file("$dir/js/uk/trial_card.json", $json->encode($section));
    my $uk = translator('uk-UA');

    my $page = $uk->browser_catalog('trial_card');
    is($page->{locale}, 'uk', 'language used');
    is($page->{requestedLocale}, 'uk-UA', 'language requested');
    is($page->{languageName}, 'Українська', 'native name');
    is(scalar @{ $page->{catalogs} }, 2, 'common and the page section');
    for my $other (undef, '', '../../etc/passwd', 'common') {
        is(scalar @{ $uk->browser_catalog($other)->{catalogs} }, 1, 'otherwise only common: ' . ($other // 'undef'));
    }
    is(scalar @{ SGN::I18N->new->browser_catalog('trial_card')->{catalogs} }, 0, 'English sends no messages');

    write_file("$dir/js/uk/seedlots.json", '{broken');
    my ($warnings, $broken) = warnings_of(sub { $uk->browser_catalog('seedlots') });
    is(scalar @{ $broken->{catalogs} }, 1, 'a broken section file is skipped');
    like($warnings->[0], qr/ignoring browser messages .*seedlots\.json/, 'and logged');
    write_file("$dir/js/uk/seedlots.json", $json->encode({ %$section, locale => 'ar' }));
    ($warnings, $broken) = warnings_of(sub { $uk->browser_catalog('seedlots') });
    is(scalar @{ $broken->{catalogs} }, 1, 'a file of another language is skipped');
    unlink("$dir/js/uk/trial_card.json", "$dir/js/uk/seedlots.json");
};

subtest 'section of a page from locale/workflows.json' => sub {
    my $manifest = "$dir/workflows.json";
    write_file($manifest, $json->encode({ schema => 1, source_workflows => {
        'cgi-bin/maps/vector.pl' => 'transformation', 'mason/trial/card.mas' => 'trial_card',
        'mason/page/default.mas' => 'global' } }));
    is(SGN::I18N::workflow_for_source($manifest, '/maps/vector.pl', '/page/default.mas'), 'transformation',
        'the CGI script wins over the page wrapper');
    is(SGN::I18N::workflow_for_source($manifest, '/breeders/trial/1', '/trial/card.mas'), 'trial_card',
        'the page template gives the section');
    is(SGN::I18N::workflow_for_source($manifest, '/unknown', '/unknown.mas'), undef, 'an unregistered page has no section');
};

subtest "the caller's \$_, \$\@ and \$! are preserved" => sub {
    my $uk = translator('uk');
    my @calls = (
        [ 'new', sub { translator('uk') } ],
        [ 'new for a missing language', sub { translator('zz') } ],
        [ 'p', sub { $uk->p('controls.save', 'Save') } ],
        [ 'np', sub { $uk->np('trials.count', '%{count} trial found', '%{count} trials found', 2, { count => 2 }) } ],
        [ 'browser_catalog', sub { $uk->browser_catalog('trial_card') } ],
    );
    for my $call (@calls) {
        my ($name, $code) = @$call;
        local $_ = 'caller topic';
        local $@ = 'caller error';
        local $! = 2;
        my $errno = 0 + $!;
        $code->();
        is($_, 'caller topic', "$name keeps \$_");
        is($@, 'caller error', "$name keeps \$\@");
        is(0 + $!, $errno, "$name keeps \$!");
    }
    my @labels = map { $uk->p('controls.save', $_) } ('Save', 'Other');
    is_deeply(\@labels, ['Зберегти', 'Other'], 'p can be called inside map');
};

subtest 'requests do not share a language, and the process is not changed' => sub {
    my %env = %ENV;
    my $process_locale = setlocale(LC_ALL);
    my ($uk, $en, $ar) = (translator('uk'), translator('en'), translator('ar'));
    for (1 .. 3) {
        is($uk->p('controls.save', 'Save'), 'Зберегти', 'Ukrainian request');
        is($en->p('controls.save', 'Save'), 'Save', 'English request in between');
        is($ar->np('trials.count', '%{count} trial found', '%{count} trials found', 3, { count => 3 }), 'ar[3] 3',
            'Arabic request in between');
    }
    is_deeply(\%ENV, \%env, 'environment unchanged (LANGUAGE is set only during a lookup)');
    is(setlocale(LC_ALL), $process_locale, 'process locale unchanged');

    my $messages_locale = setlocale(LC_MESSAGES);
    setlocale(LC_MESSAGES, 'C');
    is(translator('uk')->p('controls.save', 'Save'), 'Зберегти', 'also translated when the process locale is C');
    is(setlocale(LC_MESSAGES), 'C', '... and the C locale is restored');
    setlocale(LC_MESSAGES, $messages_locale);
};

done_testing();
