package SGN::Role::Site::I18N;
use Moose::Role;
use SGN::I18N;

=head1 NAME

SGN::Role::Site::I18N - choose the interface language for each request

=head1 DESCRIPTION

Interface translation is off by default. Translations are standard GNU
gettext files built in the sgn-translations repository. To turn it on, install
libintl-perl (Debian package C<libintl-perl>), build or install the language
files and set in F<sgn_local.conf>:

    i18n_enabled          1
    i18n_enabled_locales  en,uk,es
    i18n_dir              /absolute/path/to/sgn-translations/build

C<i18n_dir> defaults to F<../sgn-translations/build> next to the SGN checkout.
It holds F<LocaleData/E<lt>localeE<gt>/LC_MESSAGES/sgn.mo> for the server and
F<js/E<lt>localeE<gt>/E<lt>sectionE<gt>.json> for the browser.
C<i18n_default_locale> (default C<en>) is used when no user or browser
preference matches. With C<i18n_enabled 0> every request uses English and no
file is read.

The language preference changes only interface text. It never changes login,
the process locale, dates, units or stored data.

A response that used the translator gets C<Content-Language> and
C<Vary: Accept-Language, Cookie, X-SGN-Locale>.

=head1 METHODS

=head2 i18n_locales

Return the configured language tags, always starting with C<en>.

=cut

sub i18n_locales {
    my ($c) = @_;
    my $value = $c->config->{i18n_enabled_locales} || 'en';
    my @locales = ref($value) eq 'ARRAY' ? @$value : split /\s*,\s*/, $value;
    my %seen;
    return grep { /^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*$/ && !$seen{lc $_}++ }
        ('en', @locales);
}

my %logged_unavailable;    # "locale\0dir" already logged by this process

# Return the translator for one enabled language, or undef when it has no
# installed translation. Each problem is logged once per server process.
sub _i18n_translator {
    my ($c, $locale) = @_;
    my $available = $c->stash->{i18n_available} ||= {};
    return $available->{$locale} if exists $available->{$locale};
    if ($locale eq 'en') {
        $available->{$locale} = SGN::I18N->new(locale => 'en');
        return $available->{$locale};
    }
    my $dir = $c->config->{i18n_dir} || $c->path_to('..', 'sgn-translations', 'build')->stringify;
    my $translator = eval { SGN::I18N->new(locale => $locale, dir => $dir) };
    my $error = $@;
    if (!$translator || $translator->locale eq 'en') {
        # Without libintl-perl, SGN::I18N has already logged the one warning.
        $c->log->warn('Unavailable translation for ' . $locale . ' in ' . $dir . ': '
            . ($error || 'no installed sgn.mo'))
            if SGN::I18N::gettext_available() && $c->can('log') && !$logged_unavailable{"$locale\0$dir"}++;
        $translator = undef;
    }
    $available->{$locale} = $translator;
    return $translator;
}

=head2 i18n_locale_choices

Return C<< { locale => $tag, name => $native_name } >> for each enabled language
that has installed translations, for the language selector. Files without a native
name use their tag. Escape the names when you print them.

=cut

sub i18n_locale_choices {
    my ($c) = @_;
    my @choices;
    for my $locale ($c->i18n_locales) {
        my $translator = $c->_i18n_translator($locale);
        push @choices, {locale => $locale, name => $translator->language_name} if $translator;
    }
    return @choices;
}

sub _i18n_match_locale {
    my ($candidate, $locales) = @_;
    return unless defined $candidate && length($candidate) <= 100;
    return unless $candidate =~ /^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*$/;
    my %available = map { lc($_) => $_ } @$locales;
    while (length $candidate) {
        return $available{lc $candidate} if exists $available{lc $candidate};
        last unless $candidate =~ s/-[^-]+$//;
    }
    return;
}

=head2 initialize_i18n

Choose the language for this request and store its translator in the stash.
The order is: C<lang> query parameter, the C<X-SGN-Locale> request header
(sent by the browser runtime on same-site AJAX requests, so they use the
language of the page), the C<sgn_locale> cookie set by the language selector, the browser's
C<Accept-Language>, C<i18n_default_locale>, then English. Only enabled
languages with installed translations are accepted; a regional tag can use its
parent language.

=cut

sub initialize_i18n {
    my ($c) = @_;
    my @locales = $c->i18n_locales;
    my $locale = 'en';
    my $source = 'disabled';
    if ($c->config->{i18n_enabled}) {
        my $cookie = $c->req->cookies->{sgn_locale};
        # Scalar context: a missing parameter or header is undef, not an
        # empty list, and a repeated one does not shift the pairs.
        my @preferences = (
            [scalar $c->req->param('lang'), 'query'],
            [scalar $c->req->headers->header('X-SGN-Locale'), 'explicit-header'],
            [$cookie ? $cookie->value : undef, 'cookie'],
        );
        my $header = substr($c->req->headers->header('Accept-Language') || '', 0, 8192);
        my @ranges;
        my $order = 0;
        for my $range ((split /,/, $header)[0..31]) {
            next unless defined $range;
            next unless $range =~ /^\s*([A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*)\s*(?:;\s*q=(0(?:\.\d{1,3})?|1(?:\.0{1,3})?))?\s*$/;
            my ($tag, $q) = ($1, defined($2) ? 0+$2 : 1);
            push @ranges, [$tag, $q, $order++] if $q > 0;
        }
        push @preferences, map { [$_->[0], 'header'] }
            sort { $b->[1] <=> $a->[1] || $a->[2] <=> $b->[2] } @ranges;
        push @preferences, [$c->config->{i18n_default_locale} || 'en', 'default'], ['en', 'default'];
        PREFERENCE: for my $preference (@preferences) {
            my $candidate = $preference->[0];
            while (my $matched = _i18n_match_locale($candidate, \@locales)) {
                if ($c->_i18n_translator($matched)) {
                    ($locale, $source) = ($matched, $preference->[1]);
                    last PREFERENCE;
                }
                # An unavailable regional language must not hide its usable parent.
                $candidate = $matched;
                last unless $candidate =~ s/-[^-]+$//;
            }
        }
    }
    my $translator = $c->config->{i18n_enabled} ? $c->_i18n_translator($locale) : undef;
    $translator ||= SGN::I18N->new(locale => 'en');
    $c->stash->{i18n} = $translator;
    $c->stash->{i18n_locale_source} = $source;
    return $translator;
}

=head2 i18n

Return the translator of this request (an L<SGN::I18N> object). The first
call chooses the language. The caller's C<$_>, C<$@> and C<$!> are preserved.

=cut

sub i18n {
    my ($c) = @_;
    local ($_, $@, $!);
    return $c->stash->{i18n} || $c->initialize_i18n;
}

# Every response that used the translator (pages, and AJAX or JSON answers
# with translated messages) depends on the language: say so to browsers and
# caches. Responses that did not use it, and every response with
# translation off, are unchanged.
before finalize_headers => sub {
    my ($c) = @_;
    return unless $c->config->{i18n_enabled};
    my $translator = $c->stash->{i18n} or return;
    my $headers = $c->res->headers;
    # A server error can end with Catalyst's English debug page.
    $headers->header('Content-Language' => $translator->locale) if ($c->res->status || 200) < 500;
    my %vary = map { lc($_) => 1 } map { split /\s*,\s*/ } $headers->header('Vary');
    $headers->push_header('Vary', $_) for grep { !$vary{ lc $_ } } qw(Accept-Language Cookie X-SGN-Locale);
};

1;
