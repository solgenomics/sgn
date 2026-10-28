package SGN::I18N;

use strict;
use warnings;
use utf8;
use Carp qw(croak);
use Digest::SHA qw(sha256_hex);
use File::Spec;
use Hash::Util qw(lock_hash_recurse);
use JSON ();

# Experimental offline backend. GNU PO is authoritative; Jed parses plural
# expressions at build time. This interpreter consumes only bounded JSON data.
our $VERSION = '0.01';
# Reuse SGN's pinned JSON backend: PP copies the remaining input per UTF-8 character.
my $JSON = JSON->new->utf8;
my %CATALOG_CACHE;
my @CATALOG_CACHE_ORDER;
my $CATALOG_CACHE_LIMIT = 8;
my %BINARY = map { $_ => 1 } qw(OR AND LT GT LTE GTE EQ NEQ MOD);
my $MAX_INTEGER = 9007199254740991;

sub _locale {
    my ($locale) = @_;
    $locale = 'en' unless defined $locale && length $locale;
    croak 'Invalid locale' if ref $locale || $locale !~ /\A[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*\z/;
    my @parts = split /-/, $locale;
    $parts[0] = lc $parts[0];
    for my $part (@parts[1 .. $#parts]) {
        $part = length($part) == 4 ? ucfirst lc $part
              : length($part) == 2 ? uc $part : lc $part;
    }
    return join '-', @parts;
}

sub _count {
    my ($count) = @_;
    croak 'Plural count must be a nonnegative safe integer'
        if !defined($count) || ref($count) || $count !~ /\A(?:0|[1-9][0-9]*)\z/ || $count > $MAX_INTEGER;
    return 0 + $count;
}

sub _validate_ast {
    my ($ast) = @_;
    my $size = 0;
    my $visit;
    $visit = sub {
        my ($node, $depth) = @_;
        croak 'Invalid or oversized plural AST' if ref($node) ne 'HASH' || ++$size > 128 || $depth > 24;
        my $type = $node->{type} // '';
        my @keys;
        if ($type eq 'VAR') { @keys = qw(type); }
        elsif ($type eq 'NUM') { _count($node->{val}); @keys = qw(type val); }
        elsif ($type eq 'GROUP') { @keys = qw(type expr); $visit->($node->{expr}, $depth + 1); }
        elsif ($type eq 'TERNARY') {
            @keys = qw(type expr truthy falsey);
            $visit->($node->{$_}, $depth + 1) for qw(expr truthy falsey);
        } elsif ($BINARY{$type}) {
            @keys = qw(type left right);
            $visit->($node->{$_}, $depth + 1) for qw(left right);
            croak 'Plural division by zero' if $type eq 'MOD' && $node->{right}{type} eq 'NUM' && !$node->{right}{val};
        } else { croak 'Unsupported plural AST operator'; }
        croak 'Unexpected plural AST field' unless join(',', sort keys %$node) eq join(',', sort @keys);
    };
    $visit->($ast, 0);
    return $ast;
}

sub _evaluate {
    my ($node, $n) = @_;
    my $type = $node->{type};
    return $n if $type eq 'VAR';
    return $node->{val} if $type eq 'NUM';
    return _evaluate($node->{expr}, $n) if $type eq 'GROUP';
    return _evaluate(_evaluate($node->{expr}, $n) ? $node->{truthy} : $node->{falsey}, $n) if $type eq 'TERNARY';
    my $left = _evaluate($node->{left}, $n);
    return 0 + (($left || _evaluate($node->{right}, $n)) ? 1 : 0) if $type eq 'OR';
    return 0 + (($left && _evaluate($node->{right}, $n)) ? 1 : 0) if $type eq 'AND';
    my $right = _evaluate($node->{right}, $n);
    return 0 + ($left < $right) if $type eq 'LT';
    return 0 + ($left > $right) if $type eq 'GT';
    return 0 + ($left <= $right) if $type eq 'LTE';
    return 0 + ($left >= $right) if $type eq 'GTE';
    return 0 + ($left == $right) if $type eq 'EQ';
    return 0 + ($left != $right) if $type eq 'NEQ';
    if ($type eq 'MOD') {
        croak 'Plural division by zero' unless $right;
        return $left % $right;
    }
    croak 'Unsupported plural AST operator';
}

sub _validate_catalog {
    my ($catalog, $locale) = @_;
    croak 'Unsupported catalog schema' if ref($catalog) ne 'HASH' || ($catalog->{schema} // 0) != 1 || ($catalog->{api} // 0) != 1;
    croak 'Catalog locale mismatch' unless _locale($catalog->{locale}) eq $locale;
    croak 'Invalid direction' unless ($catalog->{direction} // '') =~ /\A(?:ltr|rtl)\z/;
    if (exists $catalog->{languageName}) {
        my $name = $catalog->{languageName};
        croak 'Invalid native language name' if !defined($name) || ref($name)
            || !length($name) || length($name) > 200 || $name !~ /\S/
            || $name =~ /[\x00-\x1f\x7f-\x9f\x{2028}\x{2029}]/;
    }
    croak 'Invalid plural form count' unless defined($catalog->{nplurals}) && $catalog->{nplurals} =~ /\A[1-6]\z/;
    croak 'Invalid Plural-Forms metadata' unless defined($catalog->{pluralForms}) && !ref($catalog->{pluralForms}) && length($catalog->{pluralForms}) <= 2048
        && $catalog->{pluralForms} =~ /\A\s*nplurals\s*=\s*\Q$catalog->{nplurals}\E\s*;\s*plural\s*=\s*[^;]+;?\s*\z/;
    _validate_ast($catalog->{pluralAst});
    for my $count (0 .. 200, 999, 1000, 1001, 1000000, $MAX_INTEGER) {
        my $index = _evaluate($catalog->{pluralAst}, $count);
        croak 'Plural index outside catalog forms' if $index < 0 || $index >= $catalog->{nplurals} || int($index) != $index;
    }
    croak 'Invalid catalog messages' unless ref($catalog->{messages}) eq 'HASH';
    for my $key (keys %{$catalog->{messages}}) {
        my $message = $catalog->{messages}{$key};
        croak 'Invalid catalog message' unless ref($message) eq 'HASH' && exists($message->{plural}) && (!defined($message->{plural}) || !ref($message->{plural})) && ref($message->{forms}) eq 'ARRAY';
        my $expected = defined($message->{plural}) ? $catalog->{nplurals} : 1;
        croak 'Incomplete catalog message' unless @{$message->{forms}} == $expected;
        for my $form (@{$message->{forms}}) { croak 'Invalid catalog form' if !defined($form) || ref($form) || !length($form); }
    }
    # Preserve the JSON number type after regex metadata validation.
    $catalog->{nplurals} = 0 + $catalog->{nplurals};
    lock_hash_recurse(%$catalog);
    return $catalog;
}

sub _remember_catalog {
    my ($key, $catalog) = @_;
    @CATALOG_CACHE_ORDER = grep { $_ ne $key } @CATALOG_CACHE_ORDER;
    push @CATALOG_CACHE_ORDER, $key;
    $CATALOG_CACHE{$key} = $catalog;
    # Only the cache's reference is evicted. Active translators own their
    # immutable snapshots, including every member of a regional chain.
    while (@CATALOG_CACHE_ORDER > $CATALOG_CACHE_LIMIT) {
        delete $CATALOG_CACHE{shift @CATALOG_CACHE_ORDER};
    }
    return $catalog;
}

sub _load {
    my ($path, $locale) = @_;
    return unless -f $path;
    croak 'Oversized catalog' if -s $path > 4 * 1024 * 1024;
    open my $fh, '<:raw', $path or croak "Cannot open i18n catalog: $!";
    local $/;
    my $bytes = <$fh>;
    close $fh;
    my $digest = sha256_hex($bytes);
    my $cache_key = $locale . "\x00" . $digest;
    return _remember_catalog($cache_key, $CATALOG_CACHE{$cache_key}) if exists $CATALOG_CACHE{$cache_key};
    my $catalog = _validate_catalog($JSON->decode($bytes), $locale);
    return _remember_catalog($cache_key, $catalog);
}

sub _bounded_bytes {
    my ($path) = @_;
    return unless -f $path;
    croak 'Oversized catalog partition' if -s $path > 2 * 1024 * 1024;
    open my $fh, '<:raw', $path or croak "Cannot open catalog partition: $!";
    local $/;
    my $bytes = <$fh>;
    close $fh;
    return $bytes;
}

sub _load_bundle {
    my ($root, $locale, $domain) = @_;
    my $directory = File::Spec->catdir($root, $locale, $domain);
    my $bytes = _bounded_bytes(File::Spec->catfile($directory, 'index.json'));
    return unless defined $bytes;
    my $index = $JSON->decode($bytes);
    croak 'Invalid partition index' unless ref($index) eq 'HASH'
        && ($index->{schema} // 0) == 1 && ($index->{domain} // '') eq $domain
        && ref($index->{partitions}) eq 'ARRAY' && @{$index->{partitions}} <= 64;
    my (%seen, @parts);
    my $fingerprint = $bytes;
    for my $part (@{$index->{partitions}}) {
        croak 'Invalid catalog partition name' unless ref($part) eq 'HASH'
            && defined($part->{name}) && !ref($part->{name})
            && $part->{name} =~ /\A[a-z][a-z0-9_]*\z/ && !$seen{$part->{name}}++
            && ($part->{sha256} // '') =~ /\A[a-f0-9]{64}\z/;
        my $data = _bounded_bytes(File::Spec->catfile($directory, "$part->{name}.json"));
        $fingerprint .= "\0$part->{name}\0" . (defined($data) ? sha256_hex($data) : 'missing');
        next unless defined $data; # A missing section keeps its English fallback.
        croak 'Catalog partition hash mismatch' unless sha256_hex($data) eq $part->{sha256};
        push @parts, [$part->{name}, $data];
    }
    my $key = $locale . "\0bundle\0" . sha256_hex($fingerprint);
    return _remember_catalog($key, $CATALOG_CACHE{$key}) if exists $CATALOG_CACHE{$key};
    # Cache one immutable locale snapshot, not one slot per section. The eight
    # existing cache slots still bound generations; every file hash is checked.
    my $bundle = {sourceRevision => $index->{sourceRevision}, entries => [map { +{name => $_->[0], catalog =>
        _validate_catalog($JSON->decode($_->[1]), $locale)} } @parts]};
    return _remember_catalog($key, $bundle);
}

sub workflow_for_source {
    my ($manifest, $request_path, @components) = @_;
    local $_;
    local $@;
    local $!;
    my $bytes = _bounded_bytes($manifest);
    return unless defined $bytes;
    my $key = "workflows\0" . sha256_hex($bytes);
    my $config = $CATALOG_CACHE{$key};
    unless ($config) {
        $config = $JSON->decode($bytes);
        croak 'Invalid workflow source map' unless ref($config) eq 'HASH'
            && ($config->{schema} // 0) == 1 && ref($config->{source_workflows}) eq 'HASH';
    }
    _remember_catalog($key, $config);
    my @candidates;
    if (defined($request_path) && !ref($request_path)) {
        $request_path =~ s{\A/+}{};
        push @candidates, 'cgi-bin/' . $request_path;
    }
    for my $component (@components) {
        next unless defined($component) && !ref($component);
        $component =~ s{\A/+}{};
        $component = 'mason/' . $component unless $component =~ m{\Amason/};
        push @candidates, $component;
    }
    for my $path (@candidates) {
        my $group = $config->{source_workflows}{$path};
        return $group if defined($group) && !ref($group) && $group =~ /\A[a-z][a-z0-9_]*\z/;
    }
    return;
}

sub new {
    my ($class, %args) = @_;
    my $requested = _locale($args{locale});
    my $domain = $args{domain} // 'sgn';
    croak 'Invalid catalog domain' if ref($domain) || $domain !~ /\A[a-z][a-z0-9_-]*\z/;
    my (@catalogs, @partitions);
    my %source_revisions;
    my $partitioned = 0;
    if (defined $args{catalog_root}) {
        croak 'Invalid catalog root' if ref($args{catalog_root});
        my $candidate = $requested;
        while (1) {
            my $bundle = _load_bundle($args{catalog_root}, $candidate, $domain);
            if ($bundle) {
                $partitioned = 1;
                $source_revisions{$candidate} = $bundle->{sourceRevision} if defined $bundle->{sourceRevision};
                push @partitions, @{$bundle->{entries}};
                push @catalogs, map { $_->{catalog} } @{$bundle->{entries}};
            } else {
                my $path = File::Spec->catfile($args{catalog_root}, $candidate, "$domain.json");
                my $catalog = _load($path, $candidate);
                if ($catalog) {
                    push @catalogs, $catalog;
                    push @partitions, {name => undef, catalog => $catalog};
                }
            }
            last unless $candidate =~ s/-[^-]+$//;
        }
    }
    return bless {
        requested_locale => $requested,
        locale => @catalogs ? $catalogs[0]{locale} : 'en',
        dir => @catalogs ? $catalogs[0]{direction} : 'ltr',
        domain => $domain,
        catalogs => \@catalogs,
        partitions => \@partitions,
        partitioned => $partitioned,
        source_revisions => \%source_revisions,
    }, $class;
}

sub locale { return $_[0]{locale}; }
sub dir { return $_[0]{dir}; }
sub requested_locale { return $_[0]{requested_locale}; }

sub language_name {
    my ($self) = @_;
    if (@{$self->{catalogs}} && exists $self->{catalogs}[0]{languageName}) {
        return $self->{catalogs}[0]{languageName};
    }
    return $self->locale eq 'en' ? 'English' : $self->locale;
}

sub _format {
    my ($text, $variables) = @_;
    $variables //= {};
    croak 'Named variables must be a hash' unless ref($variables) eq 'HASH';
    $text =~ s/%\{([A-Za-z_][A-Za-z0-9_]*)\}/
        exists($variables->{$1}) && defined($variables->{$1}) && !ref($variables->{$1})
            ? $variables->{$1} : croak("Missing or invalid named variable: $1")
    /gex;
    return $text;
}

# Presentation boundary: snapshot interpolation arguments before calling this.
# With one argument, acquire a request/model translator under the same guard.
sub translate {
    local $_;
    local $@;
    local $!;
    my ($translator, $context, $english, $variables, $options) = @_;
    return $translator && $translator->can('i18n') ? $translator->i18n : undef
        if @_ == 1;
    $options //= {};
    my $text;
    if (!$translator && exists $options->{fallback}) {
        $text = $options->{fallback};
    } elsif (my $plural = $options->{plural}) {
        $text = $translator ? $translator->np($context, $english, @$plural, $variables)
            : _format($plural->[1] == 1 ? $english : $plural->[0], $variables);
    } else {
        $text = $translator ? $translator->p($context, $english, $variables)
            : _format($english, $variables);
    }
    if (exists $options->{entities}) {
        require HTML::Entities;
        $text = HTML::Entities::decode_entities($text) if $options->{decode};
        # An explicit empty character set preserves literal legacy CGI bytes.
        $text = HTML::Entities::encode_entities($text, $options->{entities})
            unless defined($options->{entities}) && $options->{entities} eq '';
    }
    return $text;
}

sub p {
    my ($self, $context, $text, $variables) = @_;
    croak 'Translation context and text must be strings' if !defined($context) || ref($context) || !defined($text) || ref($text);
    my $key = $context . "\x04" . $text;
    my $translated = $text;
    for my $catalog (@{$self->{catalogs}}) {
        next unless exists $catalog->{messages}{$key};
        my $message = $catalog->{messages}{$key};
        next if defined $message->{plural};
        $translated = $message->{forms}[0];
        last;
    }
    return _format($translated, $variables);
}

sub np {
    my ($self, $context, $one, $many, $count, $variables) = @_;
    $count = _count($count);
    croak 'Translation context and texts must be strings' if grep { !defined($_) || ref($_) } ($context, $one, $many);
    my $key = $context . "\x04" . $one;
    my $translated = $count == 1 ? $one : $many;
    for my $catalog (@{$self->{catalogs}}) {
        next unless exists $catalog->{messages}{$key};
        my $message = $catalog->{messages}{$key};
        next unless defined($message->{plural}) && $message->{plural} eq $many;
        my $index = _evaluate($catalog->{pluralAst}, $count);
        croak 'Plural index outside catalog forms' if $index < 0 || $index >= @{$message->{forms}};
        $translated = $message->{forms}[$index];
        last;
    }
    return _format($translated, $variables);
}

sub browser_catalog {
    my ($self, $workflow) = @_;
    my @catalogs = @{$self->{catalogs}};
    if ($self->{partitioned}) {
        my $known = defined($workflow) && !ref($workflow)
            && grep { defined($_->{name}) && $_->{name} eq $workflow } @{$self->{partitions}};
        @catalogs = $known ? map { $_->{catalog} } grep {
            !defined($_->{name}) || $_->{name} eq 'common' || $_->{name} eq $workflow
        } @{$self->{partitions}} : ();
    }
    my $locale = @catalogs ? $catalogs[0]{locale} : 'en';
    my $name = @catalogs && exists($catalogs[0]{languageName}) ? $catalogs[0]{languageName}
        : $locale eq 'en' ? 'English' : $locale;
    return $JSON->decode($JSON->encode({
        locale => $locale,
        requestedLocale => $self->requested_locale,
        languageName => $name,
        dir => @catalogs ? $catalogs[0]{direction} : 'ltr',
        domain => $self->{domain},
        catalogs => \@catalogs,
    }));
}
sub export_catalog {
    my ($self) = @_;
    my (@catalogs, %locale_index);
    for my $catalog (@{$self->{catalogs}}) {
        my $locale = $catalog->{locale};
        unless (exists $locale_index{$locale}) {
            $locale_index{$locale} = scalar @catalogs;
            push @catalogs, {%$catalog, messages => {}};
            $catalogs[-1]{sourceRevision} = $self->{source_revisions}{$locale}
                if exists $self->{source_revisions}{$locale};
        }
        my $messages = $catalogs[$locale_index{$locale}]{messages};
        for my $key (keys %{$catalog->{messages}}) {
            $messages->{$key} = $catalog->{messages}{$key} unless exists $messages->{$key};
        }
    }
    return $JSON->decode($JSON->encode({locale => $self->locale,
        requestedLocale => $self->requested_locale, languageName => $self->language_name,
        dir => $self->dir, domain => $self->{domain}, catalogs => \@catalogs}));
}

1;

__END__

=head1 NAME

SGN::I18N - request-local prototype message translation for SGN

=head1 SYNOPSIS

    my $i18n = SGN::I18N->new(
        locale       => 'uk-UA',
        catalog_root => '/srv/sgn/locale/build',
        domain       => 'sgn',
    );

    my $label = $i18n->p('trial.save', 'Save Changes');
    my $text = $i18n->np(
        'trial.count', '%{count} trial', '%{count} trials', 21,
        { count => 21 },
    );
    my $payload = $i18n->browser_catalog('trial_card');

=head1 DESCRIPTION

This module is the experimental Perl backend for the opt-in SGN localization
prototype. GNU gettext PO catalogs remain the translation source of truth.
The build tool uses the pinned Jed parser to compile the supported plural
expression grammar into bounded JSON AST data. This module never executes
catalog text, mutates the process locale, or writes user or breeding data.

Catalog files are loaded from C<catalog_root/locale/domain.json>. Progressive
BCP 47 parent fallbacks are searched in order: C<zh-Hant-TW>, C<zh-Hant>, then
C<zh>. Missing messages use their original English source text. Unknown or
uninstalled locales resolve to English. Each instance stores its own language
selection; decoded catalog hashes are shared internally by content digest and
expected locale. C<browser_catalog> returns an independent copy.

=head1 METHODS

=head2 new(locale => $tag, catalog_root => $directory, domain => $domain)

Create a translator. The default language is C<en> and the default domain is
C<sgn>. With no catalog directory, all messages fall back to English. Reject
invalid language tags, domain names, catalog schemas and plural AST data.

=head2 language_name

Return the native display name from optional C<languageName> catalog metadata.
Old catalogs use their resolved locale tag; the English source uses C<English>.
Names are plain text. Escape them at the HTML or attribute sink.

=head2 p($context, $english, \%variables)

Translate a complete English message in its explicit gettext context. Context
may be the empty string. Named C<%{name}> placeholders are replaced once with
scalar values. Missing or nonscalar values are errors. Bare braces are literal.

=head2 np($context, $one, $many, $count, \%variables)

Translate a complete singular/plural message with the catalog's GNU plural
indices. Both English source forms must match the compiled record. Count must
be a nonnegative integer no larger than C<9007199254740991>, matching JavaScript
safe integers. On a missing or stale translation, English uses C<$count == 1>
to select the singular form. Unsupported formulas must be rejected by the pack
compiler before installation.

=head2 locale

Return the installed effective language, or C<en> on English fallback.

=head2 requested_locale

Return the normalized requested BCP 47 language tag.

=head2 dir

Return C<ltr> or C<rtl> from the effective catalog; English defaults to C<ltr>.

=head2 browser_catalog

Return C<{ locale, requestedLocale, dir, domain, catalogs }> as a data-only
structure accepted by C<new SGN.I18N(payload)>. JSON serialization belongs to the
caller. Indexed catalogs require a workflow argument and return common plus
that workflow; an unknown section returns English. Legacy single-file catalogs
retain their existing behavior. Catalog and payload values must not be
concatenated into HTML.

=head2 export_catalog

Return a data-only native export with all server messages merged into one
catalog per locale. Indexed exports retain the complete bundle source revision.

=head1 OUTPUT SAFETY

All methods return plain Perl character strings. Escape at the final sink:
Mason HTML/attributes with C<|h> or C<encode_entities>, JSON through its encoder,
and browser output through C<textContent> or jQuery C<.text()>. Translation and
parameter formatting do not return trusted HTML. Scientific names, identifiers,
measurements, units of storage and machine exchange values are not translated
unless a caller deliberately passes them as an interface message.

=head1 PROTOTYPE LIMITS

The supported plural AST contains C<n>, nonnegative integer constants,
parentheses, conditional expressions, boolean operators, comparisons and
modulo. Arithmetic and unary operators are not supported in this prototype.
Maximums are six plural forms, 128 AST nodes and 24 levels below the root.
Catalog build and install tools validate formula/AST equivalence; the Perl
backend executes the validated AST data. The backend is not yet qualified as a
community-wide SGN localization implementation.

=cut
