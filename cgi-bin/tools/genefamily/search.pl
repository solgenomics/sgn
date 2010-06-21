use strict;
use CGI ();
use CXGN::DB::Connection;
use CXGN::People::Person;
use CXGN::Login;

my $cgi = CGI->new();
my $dbh = CXGN::DB::Connection->new();

my $login = CXGN::Login->new($dbh);
my $sp_person_id = $login->has_session();
my $person = CXGN::People::Person->new($dbh, $sp_person_id);

if ($person->get_user_type ne 'genefamily_editor') { 
    $c->throw(message=>'You do not have the privileges to access the genefamilies', is_error=>0);
}

$c->forward_to_mason_view(
    '/tools/genefamily/search.mas',
    genefamily_id => $cgi->param('genefamily_id') || '',
    dataset       => $cgi->param('dataset')       || '',
    member_id     => $cgi->param('member_id')     || '',
    action        => $cgi->param('action')        || '',
   );

