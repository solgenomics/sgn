use CatalystX::GlobalContext qw( $c );
use strict;
use warnings;
use CGI ();
use CXGN::DB::Connection;
use CXGN::People::Person;
use CXGN::Login;

my $cgi = CGI->new();
my $dbh = CXGN::DB::Connection->new();

my $login        = CXGN::Login->new($dbh);
my $sp_person_id = $login->has_session();
my $person       = CXGN::People::Person->new($dbh, $sp_person_id);

unless( $person->has_role('genefamily_editor') || $person->has_role('curator')) {
    $c->throw(
        message  => 'Please log in as the correct user to access the gene families',
        is_error => 0,
       );
}

$c->forward_to_mason_view(
    '/tools/genefamily/search.mas',
    genefamily_id => $cgi->param('genefamily_id') || '',
    dataset       => $cgi->param('dataset')       || '',
    member_id     => $cgi->param('member_id')     || '',
    action        => $cgi->param('action')        || '',
   );

