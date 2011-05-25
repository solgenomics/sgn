use CGI ();
my $q    = CGI->new;
my $oid  = $q->param('organism_id') + 0;
print $q->redirect(
    -uri    => '/organism/'.($q->param('organism_id') + 0).'/view',
    -status => 301,
  );

