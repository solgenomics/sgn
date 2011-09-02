use CGI ();
my $q = CGI->new;
print $q->redirect( -status => 302, -uri => '/dataset/'.( $q->param('id') || $q->param('name') ).'/view' );
