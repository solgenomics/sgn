use Modern::Perl;
use CatalystX::GlobalContext qw( $c );
use CGI qw();

my $term = $c->request->param('getTerm');

print CGI->new->redirect(
    -status => 301,
    -uri => "/search/glossary/$term");
