use strict;
use CGI ();

my $q = CGI->new;
my $marker_id = $q->param('marker_id');
$marker_id =~ s/\D//g;

print $q->redirect(
    -status => 301,
    -uri => "/marker/SGN-M$marker_id/details",
);
