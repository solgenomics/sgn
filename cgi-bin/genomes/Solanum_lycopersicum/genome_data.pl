use CGI ();
print CGI->new->redirect( -uri => '/organism/solanum_lycopersicum/genome', -status => 301 );
