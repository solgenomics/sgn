package SGN::Role::Site::I18N;
use Moose::Role;
use SGN::I18N;

=head1 NAME

SGN::Role::Site::I18N - request-scoped message translation for SGN

=head1 DESCRIPTION

The feature is opt-in. Language preferences are UI preferences only. This role
never changes authentication, process locale, dates, units or database values.
Set i18n_enabled, i18n_catalog_dir, i18n_default_locale and
 i18n_enabled_locales in sgn_local.conf. Catalogs are built before startup.

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

sub i18n_locale_choices {
    my ($c) = @_;
    return map {
        my $locale = $_;
        my $translator = SGN::I18N->new(
            locale => $locale, domain => 'sgn',
            catalog_root => $c->config->{i18n_catalog_dir} || $c->path_to('locale', 'build')->stringify,
        );
        +{ locale => $locale, name => $translator->locale eq 'en' && lc($locale) ne 'en'
            ? $locale : $translator->language_name };
    } $c->i18n_locales;
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
        for my $preference (@preferences) {
            my $matched = _i18n_match_locale($preference->[0], \@locales);
            if ($matched) { ($locale, $source) = ($matched, $preference->[1]); last; }
        }
    }
    my $translator = SGN::I18N->new(
        locale => $locale,
        domain => 'sgn',
        catalog_root => $c->config->{i18n_catalog_dir} || $c->path_to('locale', 'build')->stringify,
    );
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

1;
