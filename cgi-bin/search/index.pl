use Modern::Perl;
use CGI qw();

# In case people bookmarked or linked to the old index

print CGI->new->redirect(
    -status => 301,
    -uri => "/search");
