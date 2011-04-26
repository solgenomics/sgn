
use strict;
use warnings;

use CXGN::DB::Connection;
use Test::More;
use Test::WWW::Mechanize;
use lib 't/lib';
use SGN::Test;

use CXGN::People::Person;

my $dbh = CXGN::DB::Connection->new();

my $m = Test::WWW::Mechanize->new();

my $server = $ENV{SGN_TEST_SERVER};

$m->get_ok($server."/tools/genefamily/search.pl");

$m->content_contains('Please log in as the correct user');

$m->get_ok($server."/solpeople/login.pl");

if( my $u_id = CXGN::People::Person->get_person_by_username( $dbh, "genefamily_test_editor" ) ) {
    my $u = CXGN::People::Person->new( $dbh, $u_id );
    $u->hard_delete;
    $dbh->commit unless $dbh->dbh_param('AutoCommit');

}

my $p = CXGN::People::Person->new($dbh);
$p->set_first_name("genefamily_test");
$p->set_last_name("editor");
my $p_id = $p->store();

my $login = CXGN::People::Login->new( $dbh, $p_id );
$login->set_username("genefamily_test_editor");
$login->set_password("testpassword");
$login->set_user_type("genefamily_editor");

$login->store();

$dbh->commit();

my %form = (
    form_name => 'login',
    fields    => {
        username => 'genefamily_test_editor',
        pd       => 'testpassword',
    },
);

$m->submit_form_ok( \%form, "Login with special user..." );

$m->get_ok($server."/tools/genefamily/search.pl");


my $search_form = $m->form_name('member_search_form');

if ($search_form) {
    my %search_form = (
        form_name  => 'member_search_form',
        fields     => {
            dataset       => 'test',
            member_id     => 'AT5G22680',
        },
    );

    $m->submit_form(%search_form);
    SKIP : {
        if ($m->content =~ /can&#39;t open family file/) {
            skip "gene family file not available", 3;
        } else {
            ok($m->success, "Search form submission");
        }

        $m->content_contains('is in family 0');

        $m->form_name('genefamily_display_form');
        $m->click('view_family');

        $m->content_contains('detail for family 0');
    }
}

done_testing();

END { $p->hard_delete() if $p }
