require CGI;
CGI->new->redirect( -status => 301, -uri => 'input.pl' );

