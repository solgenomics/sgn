use CGI ();
my $q = CGI->new;
print $q->redirect( -status => 302, -uri => '/data_source/'.( $q->param('id') || $q->param('name') ).'/view' );
