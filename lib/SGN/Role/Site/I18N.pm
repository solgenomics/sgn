package SGN::Role::Site::I18N;
use Moose::Role;
use namespace::autoclean;

use I18N::LangTags qw( implicate_supers );
use I18N::LangTags::Detect;
use POSIX qw( setlocale LC_MESSAGES );
use Try::Tiny;

requires 'config', 'path_to';

=head1 NAME

SGN::Role::Site::I18N - choose the interface language for each request

=head1 DESCRIPTION

Off unless C<i18n_languages> (for example C<uk,es>) is set in the configuration.
libintl-perl (C<Locale::Messages>) is loaded only then, so a site without it still starts.
The gettext catalogs are C<< <i18n_locale_dir>/<language>/LC_MESSAGES/sgn.mo >>.
The language is C<?lang=>, then the C<lang> cookie, then Accept-Language.

=cut

sub i18n_languages {
    return grep { length && $_ ne 'en' } split /[\s,]+/, lc( shift->config->{i18n_languages} // '' );
}

after setup_finalize => sub {
    my $app = shift;
    # Texts come back as Perl characters in every mode, English too: their source is UTF-8,
    # and as bytes a non-ASCII letter would be escaped twice in the page ("\x{c2}\x{a0}" -> "&Acirc;&nbsp;").
    if ( eval { require Locale::Messages; 1 } ) {
        Locale::Messages->select_package('gettext_pp');    # the same catalog reader on every install
        Locale::Messages::bind_textdomain_codeset( sgn => 'utf-8' );
        Locale::Messages::bind_textdomain_filter( sgn => \&Locale::Messages::turn_utf_8_on );
    }
    my @languages = $app->i18n_languages or return;
    eval { require Locale::Messages; require Locale::Util; 1 } or die "i18n_languages needs libintl-perl: $@";
    my $dir       = $app->config->{i18n_locale_dir} // $app->path_to( '..', 'sgn-translations', 'locale' );
    delete $ENV{LANGUAGE};                             # gettext ranks LANGUAGE above the locale
    Locale::Messages::bindtextdomain( sgn => "$dir" );
    for my $language (@languages) {
        Locale::Util::set_locale( LC_MESSAGES, $language, undef, 'utf-8' ) or die "i18n_languages: no system locale for '$language'\n";
        Locale::Messages::dgettext( 'sgn', '' ) or die "i18n_languages: no gettext catalog $dir/$language/LC_MESSAGES/sgn.mo\n";
    }
    setlocale( LC_MESSAGES, 'C' );
};

before dispatch => sub {
    my $c       = shift;
    my @enabled = $c->i18n_languages or return;
    my $asked   = $c->req->param('lang');
    my $cookie  = $c->req->cookie('lang');
    my @wanted  = map { lc } grep { defined } $asked, ( $cookie ? $cookie->value : undef ),
        _requested_languages( $c->req->header('Accept-Language') );
    my ($language) = grep { my $tag = $_; grep { $_ eq $tag } @enabled, 'en' } @wanted;
    $language //= 'en';
    $c->res->cookies->{lang} = { value => $language, expires => '+1y' } if defined $asked && lc $asked eq $language;
    $c->stash->{language} = $language;
    Locale::Util::set_locale( LC_MESSAGES, $language, undef, 'utf-8' ) if $language ne 'en';
};

# A regional tag can imply a base language. Keep explicit exclusions when
# adding those base languages to the browser's preferences.
sub _requested_languages {
    my ($header) = @_;
    my (@accepted, %refused);
    for my $range (split /,/, $header // '') {
        if ($range =~ /^\s*([a-z0-9-]+)\s*;\s*q\s*=\s*0(?:\.0*)?\s*$/i) {
            $refused{lc $1} = 1;
        } else {
            push @accepted, $range;
        }
    }
    return grep { !$refused{lc $_} }
        implicate_supers( I18N::LangTags::Detect->http_accept_langs( join ',', @accepted ) );
}

# The locale belongs to the process: every request starts and ends in English, also when it dies.
sub _reset_language { setlocale( LC_MESSAGES, 'C' ) if shift->i18n_languages; return }
before prepare => \&_reset_language;
around handle_request => sub {
    my ( $orig, $class, @arguments ) = @_;
    return try { $class->$orig(@arguments) } finally { $class->_reset_language };
};

1;
