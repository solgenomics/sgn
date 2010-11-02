use CGI;
print CGI->new->redirect( -status => 301, -uri => '/');
