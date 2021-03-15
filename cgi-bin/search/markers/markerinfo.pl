use strict;
use CGI ();

my $q = CGI->new;
my $marker_id = $q->param('marker_id');
my $marker_name = $q->param('marker_name');

if (defined $marker_id) {
    $marker_id =~ s/\D//g;
    print $q->redirect(
    -status => 301,
    -uri => "/marker/SGN-M$marker_id/details",);
} else {
    print $q->redirect(
    -status => 301,
    -uri => "/markerGeno/$marker_name/details",);
};
