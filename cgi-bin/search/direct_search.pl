use Modern::Perl;
use CGI qw();
my $q = CGI->new;

my $term = $q->param('search') || 'loci';

print CGI->new->redirect(
    -status => 301,
    -uri => "/search/$term");
