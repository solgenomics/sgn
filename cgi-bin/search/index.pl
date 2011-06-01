use Modern::Perl;
use CatalystX::GlobalContext qw( $c );
use CGI qw();

# just in case

print CGI->new->redirect(
    -status => 301,
    -uri => "/search");
