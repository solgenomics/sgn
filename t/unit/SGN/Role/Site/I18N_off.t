use strict;
use warnings;

# The role without libintl-perl: a site that does not set i18n_languages must start and serve
# pages as before; a site that does set it must stop with a clear message.
use Moose::Meta::Class;
use Moose::Util qw( apply_all_roles );
use Test::More;

BEGIN {    # hide libintl-perl, whether it is installed or not
    unshift @INC, sub { die "hidden for this test\n" if $_[1] =~ m{^Locale/(?:Messages|Util|TextDomain)\.pm$}; return };
}

our %config;
sub Local::OffApp::new            { return bless { stash => {} }, shift }
sub Local::OffApp::stash          { return $_[0]{stash} }
sub Local::OffApp::config         { return \%config }
sub Local::OffApp::path_to        { shift; return join '/', 'nowhere', @_ }
sub Local::OffApp::setup_finalize { return }
sub Local::OffApp::prepare        { return }
sub Local::OffApp::dispatch       { return $_[0]->stash->{page} = 'English page' }
sub Local::OffApp::handle_request { my $class = shift; $class->prepare; my $c = $class->new; $c->dispatch; return $c->stash->{page} }
apply_all_roles( Moose::Meta::Class->initialize('Local::OffApp'), 'SGN::Role::Site::I18N' );

ok( !$INC{'Locale/Messages.pm'}, 'the role loads without libintl-perl' );
Local::OffApp->setup_finalize;
is( Local::OffApp->handle_request, 'English page', 'requests are served without libintl-perl when i18n_languages is unset' );

%config = ( i18n_languages => 'uk' );
eval { Local::OffApp->setup_finalize };
like( $@, qr/i18n_languages needs libintl-perl/, 'with i18n_languages set, the start stops with a clear message' );

done_testing;
