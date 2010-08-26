use CGI ();
use CatalystX::GlobalContext qw( $c );
print CGI->new->redirect( -uri => $c->uri_for_action( '/organism/view_sol100' ), -status => 301 );
