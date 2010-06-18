use strict;
use CGI ();
my $cgi = CGI->new();

$c->forward_to_mason_view(
    '/tools/genefamily/search.mas',
    genefamily_id => $cgi->param('genefamily_id') || '',
    dataset       => $cgi->param('dataset')       || '',
    member_id     => $cgi->param('member_id')     || '',
   );

