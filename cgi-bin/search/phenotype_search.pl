use Modern::Perl;
use CGI ();
print CGI->new->redirect( -uri => '/search/stocks' , -status => 301 );

