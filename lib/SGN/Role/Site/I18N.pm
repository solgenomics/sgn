package SGN::Role::Site::I18N;
use Moose::Role;
use SGN::I18N;

=head1 NAME

SGN::Role::Site::I18N - request-scoped message translation for SGN

=head1 DESCRIPTION

The feature is opt-in. Language preferences are UI preferences only. This role
never changes authentication, process locale, dates, units or database values.
Set i18n_enabled, i18n_catalog_dir and i18n_enabled_locales in sgn_local.conf.
The optional i18n_default_locale defaults to English. Install packs before enabling them.

=cut

sub i18n_locales {
    my ($c) = @_;
    my $value = $c->config->{i18n_enabled_locales} || 'en';
    my @locales = ref($value) eq 'ARRAY' ? @$value : split /\s*,\s*/, $value;
    my %seen;
    return grep { /^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*$/ && !$seen{lc $_}++ }
        ('en', @locales);
}

=head2 i18n_locale_choices

Return enabled locale identifiers and native names read from language-pack
metadata. Display labels must be escaped by the caller; names never determine
filenames, permissions or locale negotiation. Legacy packs fall back to tags.

=cut

sub _i18n_translator {
    my ($c, $locale) = @_;
    my $available = $c->stash->{i18n_available} ||= {};
    return $available->{$locale} if exists $available->{$locale};
    if ($locale eq 'en') {
        $available->{$locale} = SGN::I18N->new(locale => 'en');
        return $available->{$locale};
    }
    my $root = $c->config->{i18n_catalog_dir} || $c->path_to('locale', 'build')->stringify;
    my $translator = eval { SGN::I18N->new(
        locale => $locale, domain => 'sgn',
        catalog_root => $root,
    ) };
    my $error = $@;
    if (!$translator || $translator->locale eq 'en') {
        $c->log->warn('Unavailable i18n catalog for ' . $locale . ' at ' . $root . ': '
            . ($error || 'no installed catalog')) if $c->can('log');
        $translator = undef;
    }
    $available->{$locale} = $translator;
    return $translator;
}

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

Resolve one locale for this request: explicit query, saved cookie,
Accept-Language, configured default, then English. Only installed/enabled
locale identifiers are accepted. Each request gets its own translator object.

=cut

sub initialize_i18n {
    my ($c) = @_;
    my @locales = $c->i18n_locales;
    my $locale = 'en';
    my $source = 'disabled';
    if ($c->config->{i18n_enabled}) {
        my $cookie = $c->req->cookies->{sgn_locale};
        my @preferences = (
            [$c->req->param('lang'), 'query'],
            [$c->req->headers->header('X-SGN-Locale'), 'explicit-header'],
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
                # An unavailable regional pack must not hide its usable parent.
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

Return the translator belonging to this request. Calling this method never
mutates another request's language.

=cut

sub i18n {
    my ($c) = @_;
    return $c->stash->{i18n} || $c->initialize_i18n;
}

=head2 i18n_manual_url

Return a published manual matching the effective UI locale, with English fallback.
Publishing a manual is independent of installing an interface language pack.

=cut

sub i18n_manual_url {
    my ($c) = @_;
    my $base = $c->config->{i18n_manual_base_url} || 'https://solgenomics.github.io/sgn';
    $base =~ s{/+$}{};
    my $value = $c->config->{i18n_manual_locales} || 'en';
    my @locales = ref($value) eq 'ARRAY' ? @$value : split /\s*,\s*/, $value;
    my $locale = _i18n_match_locale($c->i18n->locale, \@locales) || 'en';
    return $base . ($locale eq 'en' ? '/' : '/' . $locale . '/');
}

1;
