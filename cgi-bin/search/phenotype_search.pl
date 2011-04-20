use Modern::Perl;
use CGI ();
print CGI->new->redirect( -uri => '/stock/search' , -status => 301 );

