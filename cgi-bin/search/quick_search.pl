use strict;
use warnings;
use CGI ();
print CGI->new->redirect( -uri => '/search/quick?'.$ENV{QUERY_STRING}, -status => 301 );

