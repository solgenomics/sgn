use strict;
use warnings;
use utf8;

use File::Path qw( make_path );
use File::Temp qw( tempdir );
use Test::More;
BEGIN { eval { require Locale::TextDomain; 1 } or plan skip_all => 'libintl-perl is not installed (t/unit/SGN/Role/Site/I18N_off.t covers that case)' }
use Locale::TextDomain ( 'sgn', undef );
use Moose::Meta::Class;
use Moose::Util qw( apply_all_roles );
use POSIX qw( setlocale LC_MESSAGES );

# A request and a response with only what the role reads and writes.
sub Local::Cookie::value     { return $_[0]{value} }
sub Local::Request::param    { return $_[0]{param}{ $_[1] } }
sub Local::Request::header   { return $_[0]{header}{ $_[1] } }
sub Local::Request::cookie   { my $value = $_[0]{cookie}{ $_[1] }; return defined $value ? bless( { value => $value }, 'Local::Cookie' ) : undef }
sub Local::Response::cookies { return $_[0]{cookies} }

# The smallest application the role can be applied to.
our %config;
sub Local::App::new            { my ( $class, %args ) = @_; return bless { res => bless( { cookies => {} }, 'Local::Response' ), stash => {}, %args }, $class }
sub Local::App::req            { return $_[0]{req} }
sub Local::App::res            { return $_[0]{res} }
sub Local::App::stash          { return $_[0]{stash} }
sub Local::App::config         { return \%config }
sub Local::App::path_to        { shift; return join '/', 'nowhere', @_ }
sub Local::App::setup_finalize { return }
sub Local::App::prepare        { return }
sub Local::App::finalize       { return }
sub Local::App::dispatch       { my $c = shift; return $c->stash->{page} = join ' | ', __('Search'), __p( 'verb', 'Search' ), __nx( '{count} trial', '{count} trials', 5, count => 5 ) }

# One whole request, as Catalyst runs it: prepare, dispatch, finalize; an error is logged, not thrown.
our %seen;
sub Local::App::handle_request {
    my ( $class, %args ) = @_;
    eval {
        $class->prepare;
        my $c = $class->new( req => bless( { param => { lang => $args{lang} }, cookie => { lang => $args{cookie} }, header => { 'Accept-Language' => $args{accept} } }, 'Local::Request' ) );
        $c->dispatch;
        %seen = ( page => $c->stash->{page}, cookie => $c->res->cookies->{lang}{value}, language => $c->stash->{language}, locale => setlocale(LC_MESSAGES) );
        die "finalize failed\n" if $args{die_in_finalize};
        $c->finalize;
    };
    return;
}
apply_all_roles( Moose::Meta::Class->initialize('Local::App'), 'SGN::Role::Site::I18N' );

sub request {
    %seen = ();
    Local::App->handle_request(@_);
    return @seen{qw( page cookie language locale )};
}

my $english   = 'Search | Search | 5 trials';
my $ukrainian = 'Пошук | Шукати | 5 дослідів';

my $dir = tempdir( CLEANUP => 1 );
make_path("$dir/uk/LC_MESSAGES");
is( system( 'msgfmt', '-o', "$dir/uk/LC_MESSAGES/sgn.mo", 't/data/i18n/uk.po' ), 0, 'test catalog compiled' );

subtest 'off by default' => sub {
    my $locale = setlocale(LC_MESSAGES);
    local $ENV{LANGUAGE} = 'en_US.UTF-8';
    Local::App->setup_finalize;
    my ( $page, $cookie, $language ) = request( lang => 'uk', accept => 'uk' );
    is( $page,                 $english,      'English' );
    is( $cookie,               undef,         'no cookie' );
    is( $language,             undef,         'no language in the stash' );
    is( setlocale(LC_MESSAGES), $locale,      'process locale untouched' );
    is( $ENV{LANGUAGE},        'en_US.UTF-8', 'environment untouched' );
};

subtest 'a wrong setup stops the application' => sub {
    local %config = ( i18n_languages => 'uk, es', i18n_locale_dir => $dir );
    eval { Local::App->setup_finalize };
    like( $@, qr{no gettext catalog \Q$dir\E/es/LC_MESSAGES/sgn\.mo}, 'a missing catalog is reported' );

    make_path("$dir/es/LC_MESSAGES");
    open( my $not_a_catalog, '>', "$dir/es/LC_MESSAGES/sgn.mo" ) or die "Can't write the file: $!";
    print {$not_a_catalog} "not a gettext catalog\n";
    close $not_a_catalog;
    eval { Local::App->setup_finalize };
    like( $@, qr{no gettext catalog \Q$dir\E/es/LC_MESSAGES/sgn\.mo}, 'a file that is not a catalog is reported' );

    %config = ( i18n_languages => 'xx', i18n_locale_dir => $dir );
    eval { Local::App->setup_finalize };
    like( $@, qr/no system locale for 'xx'/, 'a language without a system locale is reported' );
};

%config = ( i18n_languages => 'uk', i18n_locale_dir => $dir );
$ENV{LANGUAGE} = 'en_US.UTF-8';    # as in the Breedbase image
Local::App->setup_finalize;
is( Locale::Messages->select_package(''), 'gettext_pp', 'the pure-Perl catalog reader is used even when the XS one is installed' );

subtest 'language from the browser' => sub {
    is( ( request( accept => 'uk-UA' ) )[0],                   $ukrainian, 'regional tag' );
    is( ( request( accept => 'de, uk;q=0.8, en;q=0.5' ) )[0],  $ukrainian, 'first enabled language' );
    is( ( request( accept => 'en-US, uk;q=0.5' ) )[0],         $english,   'English preferred' );
    is( ( request( accept => 'uk;q=0, en' ) )[0],              $english,   'refused language' );
    is( ( request( accept => 'uk;q=0, de' ) )[0],              $english,   'refused language, nothing else enabled' );
    is( ( request( accept => 'uk;q=0.0' ) )[0],                $english,   'refused language, written q=0.0' );
    is( ( request( accept => 'de' ) )[0],                      $english,   'not enabled' );
    is( ( request() )[0],                                      $english,   'no header' );
};

subtest 'explicit choice' => sub {
    my ( $page, $cookie, $language ) = request( lang => 'UK', accept => 'en' );
    is_deeply( [ $page, $cookie, $language ], [ $ukrainian, 'uk', 'uk' ], '?lang= wins and is remembered' );
    ( $page, $cookie ) = request( lang => 'en', cookie => 'uk', accept => 'uk' );
    is_deeply( [ $page, $cookie ], [ $english, 'en' ], 'back to English' );
    ( $page, $cookie ) = request( cookie => 'uk', accept => 'en' );
    is_deeply( [ $page, $cookie ], [ $ukrainian, undef ], 'cookie wins over the browser' );
    ( $page, $cookie ) = request( lang => 'bogus', cookie => 'xx', accept => 'uk' );
    is_deeply( [ $page, $cookie ], [ $ukrainian, undef ], 'unknown values are skipped and not saved' );
};

subtest 'nothing leaks between requests' => sub {
    my $locale_in_request = ( request( accept => 'uk' ) )[3];
    like( $locale_in_request, qr/^uk/, 'Ukrainian during the request' );
    is( setlocale(LC_MESSAGES), 'C', 'reset after the request' );
    is( ( request( accept => 'de' ) )[0], $english, 'next request is English' );
    request( accept => 'uk', die_in_finalize => 1 );
    is( setlocale(LC_MESSAGES), 'C', 'reset also when the request dies in finalize' );
    is( $ENV{LANGUAGE}, undef, 'LANGUAGE does not override the locale' );

    # A request that dies before finalize must not decide the language of the next one.
    Local::App->new( req => bless( { header => { 'Accept-Language' => 'uk' } }, 'Local::Request' ) )->dispatch;
    like( setlocale(LC_MESSAGES), qr/^uk/, 'an unfinished request leaves its language behind' );
    Local::App->prepare;
    is( setlocale(LC_MESSAGES), 'C', 'the next request starts in English' );
};

done_testing;
