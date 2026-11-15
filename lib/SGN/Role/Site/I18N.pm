package SGN::Role::Site::I18N;
use Moose::Role;
use namespace::autoclean;

use I18N::LangTags qw( implicate_supers );
use I18N::LangTags::Detect;
use Locale::Messages qw( bindtextdomain bind_textdomain_codeset bind_textdomain_filter dgettext );
use Locale::Util qw( set_locale );
use POSIX qw( setlocale LC_MESSAGES );
use Try::Tiny;

requires 'config', 'path_to';

=head1 NAME

SGN::Role::Site::I18N - choose the interface language for each request

=head1 DESCRIPTION

Off unless C<i18n_languages> (for example C<uk,es>) is set in the configuration.
The gettext catalogs are C<< <i18n_locale_dir>/<language>/LC_MESSAGES/sgn.mo >>.
The language is C<?lang=>, then the C<lang> cookie, then Accept-Language.

=cut

sub i18n_languages {
    return grep { length && $_ ne 'en' } split /[\s,]+/, lc( shift->config->{i18n_languages} // '' );
}

after setup_finalize => sub {
    my $app       = shift;
    my @languages = $app->i18n_languages or return;
    my $dir       = $app->config->{i18n_locale_dir} // $app->path_to( '..', 'sgn-translations', 'locale' );
    Locale::Messages->select_package('gettext_pp');    # the same catalog reader on every install
    delete $ENV{LANGUAGE};                             # gettext ranks LANGUAGE above the locale
    bindtextdomain( sgn => "$dir" );
    bind_textdomain_codeset( sgn => 'utf-8' );
    bind_textdomain_filter( sgn => \&Locale::Messages::turn_utf_8_on );
    for my $language (@languages) {
        set_locale( LC_MESSAGES, $language, undef, 'utf-8' ) or die "i18n_languages: no system locale for '$language'\n";
        dgettext( 'sgn', '' ) or die "i18n_languages: no gettext catalog $dir/$language/LC_MESSAGES/sgn.mo\n";
    }
    setlocale( LC_MESSAGES, 'C' );
};

before dispatch => sub {
    my $c       = shift;
    my @enabled = $c->i18n_languages or return;
    my $asked   = $c->req->param('lang');
    my $cookie  = $c->req->cookie('lang');
    my @wanted  = map { lc } grep { defined } $asked, ( $cookie ? $cookie->value : undef ),
        implicate_supers( I18N::LangTags::Detect->http_accept_langs( _accepted( $c->req->header('Accept-Language') ) ) );
    my ($language) = grep { my $tag = $_; grep { $_ eq $tag } @enabled, 'en' } @wanted;
    $language //= 'en';
    $c->res->cookies->{lang} = { value => $language, expires => '+1y' } if defined $asked && lc $asked eq $language;
    $c->stash->{language} = $language;
    set_locale( LC_MESSAGES, $language, undef, 'utf-8' ) if $language ne 'en';
};

# Accept-Language without the languages the browser refuses (q=0).
sub _accepted { return join ',', grep { !/;\s*q\s*=\s*0(?:\.0*)?\s*$/i } split /,/, shift // '' }

# The locale belongs to the process: every request starts and ends in English, also when it dies.
sub _reset_language { setlocale( LC_MESSAGES, 'C' ) if shift->i18n_languages; return }
before prepare => \&_reset_language;
around handle_request => sub {
    my ( $orig, $class, @arguments ) = @_;
    return try { $class->$orig(@arguments) } finally { $class->_reset_language };
};

1;
