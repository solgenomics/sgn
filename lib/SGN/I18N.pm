package SGN::I18N;

use strict;
use warnings;
use utf8;
use Carp qw(croak);
use File::Spec;
use Digest::SHA ();
use JSON ();
use POSIX ();

our $VERSION = '0.02';

my $DOMAIN = 'sgn';
my $JSON = JSON->new->utf8;
my $MAX_INTEGER = 9007199254740991;
my $MAX_BROWSER_FILE = 2 * 1024 * 1024;
my $GETTEXT;      # undef: not loaded yet; 1: libintl-perl loaded; 0: missing
my %BOUND_DIR;    # message directory bound to the gettext domain
my %WARNED;       # warnings already given in this process
my %WORKFLOWS;    # path => [mtime, size, parsed locale/workflows.json]
my %VERSIONS;     # "dir\0locale" => [file signature, content digest]

sub _warn_once {
    my ($key, $message) = @_;
    warn "SGN::I18N: $message\n" unless $WARNED{$key}++;
    return;
}

# Load libintl-perl once. Without it the site stays English.
sub _gettext_available {
    return $GETTEXT if defined $GETTEXT;
    $GETTEXT = eval {
        require Locale::Messages;
        # The pure-Perl backend needs no system locales for the languages.
        Locale::Messages->select_package('gettext_pp');
        Locale::Messages::bind_textdomain_codeset($DOMAIN, 'UTF-8');
        1;
    } ? 1 : 0;
    _warn_once('libintl', 'Locale::Messages (libintl-perl) is not installed; the interface stays English')
        unless $GETTEXT;
    return $GETTEXT;
}

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

sub _placeholders {
    my ($text) = @_;
    return $text =~ /%\{([A-Za-z_][A-Za-z0-9_]*)\}/g;
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

sub new {
    my ($class, %args) = @_;
    local ($_, $@, $!);
    my $requested = _locale($args{locale});
    my $self = bless {
        requested_locale => $requested,
        locale => 'en',
        dir => 'ltr',
        language_name => 'English',
        chain => [],
        root => $args{dir},
    }, $class;
    return $self if $requested eq 'en' || !defined $args{dir};
    croak 'Invalid translation directory' if ref $args{dir};

    # Installed languages for this request, most specific first: uk-UA, uk.
    my @installed;
    my $candidate = $requested;
    while (1) {
        my $mo = File::Spec->catfile($args{dir}, 'LocaleData', $candidate, 'LC_MESSAGES', "$DOMAIN.mo");
        push @installed, $candidate if -f $mo;
        last unless $candidate =~ s/-[^-]+$//;
    }
    return $self unless @installed && _gettext_available();

    # The .mo header (the translation of "") carries the name and direction.
    # A file without a header is not a usable .mo file.
    my %header;
    for my $locale (@installed) {
        my $header = _gettext($args{dir}, [$locale], undef, '') // '';
        if (length $header) {
            push @{ $self->{chain} }, $locale;
            $header{$locale} = $header;
        } else {
            _warn_once("unreadable\0$args{dir}\0$locale", "cannot read $args{dir}/LocaleData/$locale/LC_MESSAGES/$DOMAIN.mo");
        }
    }
    return $self unless @{ $self->{chain} };

    $self->{locale} = $self->{chain}[0];
    $self->{language_name} = $self->{locale};
    my $header = $header{ $self->{locale} };
    if ($header =~ /^X-SGN-Language-Name:[ \t]*([^\n]+?)[ \t]*$/m) {
        my $name = $1;
        $self->{language_name} = $name
            if length($name) <= 200 && $name !~ /[\x00-\x1f\x7f-\x9f\x{2028}\x{2029}]/;
    }
    $self->{dir} = 'rtl' if $header =~ /^X-SGN-Direction:[ \t]*rtl[ \t]*$/m;
    return $self;
}

sub locale { return $_[0]{locale}; }
sub dir { return $_[0]{dir}; }
sub requested_locale { return $_[0]{requested_locale}; }
sub language_name { return $_[0]{language_name}; }
sub version {
    my ($self) = @_;
    local ($_, $@, $!);
    return $self->{version} //= join '.', map { _content_version($self->{root}, $_) } @{ $self->{chain} };
}

# A digest of the .mo file and the browser files of one language. It is
# computed once per process, and again when one of the files is replaced
# or changes size or time.
sub _content_version {
    my ($root, $locale) = @_;
    my @files = (File::Spec->catfile($root, 'LocaleData', $locale, 'LC_MESSAGES', "$DOMAIN.mo"));
    my $js = File::Spec->catdir($root, 'js', $locale);
    if (opendir(my $dir, $js)) {
        push @files, map { File::Spec->catfile($js, $_) } sort grep { /\.json\z/ } readdir $dir;
        closedir($dir);
    }
    my $signature = join "\0", map { my @stat = stat $_; join ':', $_, @stat ? @stat[1, 7, 9] : '-' } @files;
    my $cached = $VERSIONS{"$root\0$locale"};
    return $cached->[1] if $cached && $cached->[0] eq $signature;
    my $sha = Digest::SHA->new(256);
    for my $file (@files) {
        $sha->add(substr($file, length $root), "\0");
        $sha->addfile($file, 'b') if -f $file;
    }
    my $digest = substr($sha->hexdigest, 0, 16);
    $VERSIONS{"$root\0$locale"} = [$signature, $digest];
    return $digest;
}

sub gettext_available { local ($_, $@, $!); return _gettext_available(); }

sub _lookup {
    my ($self, @message) = @_;
    return unless @{ $self->{chain} };
    return _gettext($self->{root}, $self->{chain}, @message);
}

# Ask gettext for one message in the given languages ($context undef: the
# header). Returns undef when gettext cannot be used; the caller shows English.
sub _gettext {
    my ($root, $chain, $context, $one, $many, $count) = @_;
    return unless _gettext_available();
    my $messages_dir = File::Spec->catdir($root, 'LocaleData');
    if (($BOUND_DIR{$DOMAIN} // '') ne $messages_dir) {
        Locale::Messages::bindtextdomain($DOMAIN, $messages_dir);
        $BOUND_DIR{$DOMAIN} = $messages_dir;
    }
    # gettext ignores LANGUAGE in the "C" locale. When the process has no
    # language locale (C, POSIX, C.UTF-8), use C.UTF-8 for LC_MESSAGES during
    # the lookup only. libintl-perl 1.36 and later then read the locale name
    # from LC_ALL, so set that too. Both are restored after the lookup.
    my $category = POSIX::LC_MESSAGES();
    my $process_locale = POSIX::setlocale($category);
    my $switched = !defined($process_locale) || $process_locale !~ /\A[a-z][a-z]/;
    if ($switched && !POSIX::setlocale($category, 'C.UTF-8')) {
        _warn_once('c-utf8', 'the C.UTF-8 locale is not available; the interface stays English');
        return;
    }
    local $ENV{LC_ALL} = 'C.UTF-8' if $switched;
    local $ENV{LANGUAGE} = join ':', @$chain;
    my $text = eval {
        defined $context
            ? (defined $many
                ? Locale::Messages::dnpgettext($DOMAIN, $context, $one, $many, $count)
                : Locale::Messages::dpgettext($DOMAIN, $context, $one))
            : Locale::Messages::dgettext($DOMAIN, $one);
    };
    my $error = $@;
    POSIX::setlocale($category, $process_locale // 'C') if $switched;
    if (!defined $text) {
        _warn_once("lookup\0$error", "gettext lookup failed: $error") if $error;
        return;
    }
    utf8::decode($text) unless utf8::is_utf8($text);
    return $text;
}

# Use the translation unless it is broken; never break the page for it.
sub _render {
    my ($self, $context, $translated, $english, $sources, $variables) = @_;
    my $english_text = _format($english, $variables);    # caller errors still die
    return $english_text if !defined($translated) || grep { $translated eq $_ } @$sources;
    my %allowed = map { $_ => 1 } map { _placeholders($_) } @$sources;
    my ($unknown) = grep { !$allowed{$_} } _placeholders($translated);
    my $text = defined($unknown) ? undef : eval { _format($translated, $variables) };
    return $text if defined $text;
    _warn_once("$self->{locale}\0$context\0$english", "using English for the $self->{locale} translation of \"$english\": "
        . (defined($unknown) ? "unknown placeholder %{$unknown}" : $@));
    return $english_text;
}

sub p {
    my ($self, $context, $text, $variables) = @_;
    local ($_, $@, $!);
    croak 'Translation context and text must be strings'
        if !defined($context) || ref($context) || !defined($text) || ref($text);
    return $self->_render($context, scalar $self->_lookup($context, $text), $text, [$text], $variables);
}

sub np {
    my ($self, $context, $one, $many, $count, $variables) = @_;
    local ($_, $@, $!);
    $count = _count($count);
    croak 'Translation context and texts must be strings' if grep { !defined($_) || ref($_) } ($context, $one, $many);
    my $english = $count == 1 ? $one : $many;
    return $self->_render($context, scalar $self->_lookup($context, $one, $many, $count), $english, [$one, $many], $variables);
}

sub browser_catalog {
    my ($self, $section) = @_;
    local ($_, $@, $!);
    my @sections = ('common');
    push @sections, $section if defined($section) && !ref($section)
        && $section =~ /\A[a-z][a-z0-9_]*\z/ && $section ne 'common';
    my @catalogs;
    for my $locale (@{ $self->{chain} }) {
        for my $name (@sections) {
            my $catalog = $self->_browser_file($locale, $name);
            push @catalogs, $catalog if $catalog;
        }
    }
    return {
        locale => $self->locale,
        requestedLocale => $self->requested_locale,
        languageName => $self->language_name,
        dir => $self->dir,
        domain => $DOMAIN,
        catalogs => \@catalogs,
    };
}

# Read <dir>/js/<locale>/<section>.json. A missing section is English; a
# broken file is logged and skipped. The browser runtime validates the rest.
sub _browser_file {
    my ($self, $locale, $section) = @_;
    my $path = File::Spec->catfile($self->{root}, 'js', $locale, "$section.json");
    return unless -f $path;
    my $catalog = eval {
        croak 'file is too large' if -s $path > $MAX_BROWSER_FILE;
        open(my $fh, '<:raw', $path) or croak "cannot open: $!";
        my $bytes = do { local $/; <$fh> };
        close($fh);
        my $data = $JSON->decode($bytes);
        croak 'not a schema 1 catalog' unless ref($data) eq 'HASH' && ($data->{schema} // 0) == 1;
        croak "catalog is for $data->{locale}" unless ($data->{locale} // '') eq $locale;
        $data;
    };
    _warn_once("browser\0$path", "ignoring browser messages $path: $@") unless $catalog;
    return $catalog;
}

sub workflow_for_source {
    my ($manifest, $request_path, @components) = @_;
    local ($_, $@, $!);
    my @stat = stat($manifest) or return;
    my $cached = $WORKFLOWS{$manifest};
    if (!$cached || $cached->[0] != $stat[9] || $cached->[1] != $stat[7]) {
        open(my $fh, '<:raw', $manifest) or return;
        my $config = $JSON->decode(do { local $/; <$fh> });
        close($fh);
        croak 'Invalid workflow source map' unless ref($config) eq 'HASH'
            && ($config->{schema} // 0) == 1 && ref($config->{source_workflows}) eq 'HASH';
        $cached = $WORKFLOWS{$manifest} = [$stat[9], $stat[7], $config];
    }
    my $config = $cached->[2];
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

1;

__END__

=head1 NAME

SGN::I18N - translate SGN interface messages for one request

=head1 SYNOPSIS

    my $i18n = SGN::I18N->new(locale => 'uk-UA', dir => '/srv/sgn-translations/build');

    my $label = $i18n->p('navigation.manage.menu', 'Manage');
    my $text  = $i18n->np('trial.count', '%{count} trial', '%{count} trials',
        $count, { count => $count });

In Catalyst and Mason code use the request translator instead:

    <% $c->i18n->p('navigation.manage.menu', 'Manage') |h %>

=head1 DESCRIPTION

Translations use standard GNU gettext. Each message has a context key
(C<msgctxt>) and its exact English text (C<msgid>). Server messages are read
with libintl-perl (L<Locale::Messages>, pure-Perl backend) from

    <dir>/LocaleData/<locale>/LC_MESSAGES/sgn.mo

The English text is the fallback: when no language file is installed, when a
message is not translated, or when its English text changed, the English text
is returned. Language files are built in the separate sgn-translations
repository. The C<.mo> header fields C<X-SGN-Language-Name> and
C<X-SGN-Direction> give the native language name and the text direction.

A regional tag falls back to its parent language: C<pt-BR> uses C<pt> when
there is no C<pt-BR> file, and a message missing from C<pt-BR> is looked up in
C<pt>. The language is set for each lookup only, so requests never share it,
and the process environment and locale are left as they were.

If libintl-perl is not installed, one warning is logged and every message is
English. A translation that uses a placeholder its English text does not have,
or that cannot be filled in, is replaced by the English text for that call,
with one warning; a broken translation never breaks a page.

All methods keep the caller's C<$_>, C<$@> and C<$!>, so they can be used
inside C<map>, C<grep> and error handlers without extra wrapping.

gettext_pp caches the C<.mo> files it has read; restart the server after
installing new language files.

=head1 METHODS

=head2 new(locale => $tag, dir => $directory)

Create a translator for one language. C<locale> defaults to C<en>. Without
C<dir>, or without an installed C<.mo> file, every message is English.
An invalid language tag makes C<new> die.

=head2 p($context, $english, \%variables)

Return the translation of a complete message. C<$context> may be an empty
string. Named C<%{name}> placeholders are replaced once with the scalar values
in C<\%variables>; a missing value is an error. Other braces are literal.

=head2 np($context, $one, $many, $count, \%variables)

Return the form for C<$count>, using the plural rule of the language file.
C<$count> must be a non-negative integer. Without a translation, English uses
C<$one> for 1 and C<$many> otherwise. As in GNU gettext, the message is found
by C<$context> and C<$one>: when only C<$many> changes, the old translation is
used until the translations are updated (C<make templates> marks it fuzzy).
The browser runtime does the same.

=head2 locale

The language actually used: the installed language, or C<en> on fallback.

=head2 requested_locale

The requested language tag, normalized (for example C<uk-UA>).

=head2 dir

Text direction of the language used: C<ltr> or C<rtl>.

=head2 language_name

Native name of the language (C<English> for English, the tag when the file
has no name). Escape it when you print it.

=head2 version

A short digest of the installed language files (the C<.mo> file and the
browser files of each language used); empty for English. It changes when
their content changes. The page puts it into the F</i18n/bootstrap.js>
address, so browsers can keep that file.

=head2 gettext_available

Class function: true when libintl-perl can be used. The first call without
it logs the one warning.

=head2 browser_catalog($section)

Return the browser messages of this language as data for the browser runtime
(C<new SGN.I18N(...)>, see F<static/js/sgn-i18n.js>): the files
C<< <dir>/js/<locale>/common.json >> and C<< <dir>/js/<locale>/<section>.json >>
for each installed language of the request. The caller serializes it to JSON.

=head2 workflow_for_source($manifest, $request_path, @components)

Return the section name that F<locale/workflows.json> assigns to the CGI script
or Mason components of the current page, or undef.

=head1 OUTPUT SAFETY

All results are plain Perl character strings, not HTML. Escape them where they
are printed: C<|h> in Mason, C<encode_entities> in Perl HTML, the JSON encoder
for JSON, and C<textContent> or jQuery C<.text()> in the browser.

=cut
