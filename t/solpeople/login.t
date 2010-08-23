use strict;
use warnings;

use Test::More tests => 20;
use Test::WWW::Mechanize;
use lib 't/lib';
use SGN::Test;

use_ok("CXGN::DB::Connection");
use_ok("CXGN::People::Person");

my $dbh = CXGN::DB::Connection->new();

my $m = Test::WWW::Mechanize->new();

my $server = $ENV{SGN_TEST_SERVER};

# generate a new user for testing purposes
# (to be deleted right afterwards)

if( my $u_id = CXGN::People::Person->get_person_by_username( $dbh, "testusername" ) ) {
    CXGN::People::Person->new( $dbh, $u_id )->hard_delete;
}
#
my $p = CXGN::People::Person->new($dbh);
$p->set_first_name("testfirstname");
$p->set_last_name("testlastname");
my $p_id = $p->store();

my $login = CXGN::People::Login->new( $dbh, $p_id );
$login->set_username("testusername");
$login->set_password("testpassword");
$login->set_user_type("user");

$login->store();

$dbh->commit();

my $u_id = CXGN::People::Person->get_person_by_username( $dbh, "testusername" );
my $u = CXGN::People::Person->new( $dbh, $u_id );

is( $u->get_first_name(), "testfirstname", "Test first name test" );

# check basic login
#
$m->get_ok("$server/solpeople/top-level.pl");
$m->content_contains("Login");

my %form = (
    form_name => 'login',
    fields    => {
        username => 'testusername',
        pd       => 'testpassword',
    },
   );

$m->submit_form_ok( \%form, "Login form submission test" );
$m->content_contains("testfirstname");

my ($info_link) = $m->find_link( url_regex => qr/personal-info\.pl/);
ok($info_link, 'found a personal-info.pl link');
$m->get_ok($info_link->url, $info_link->url . " works");
$m->submit_form_ok({
        form_number => 1,
        fields => {
            first_name         => "foo",
            last_name          => "manchu",
            research_interests => "Ketchup",
            action             => "store",
            sp_person_id       => $p_id,
        },
    },    "Can change info on personal-info.pl",
);

# check if logout works
#
$m->get_ok( "$server/solpeople/login.pl?logout=yes",
            "Request logout page" );

$m->content_contains("You have successfully logged out");

# login as a curator
#
$login->set_user_type("curator");
$login->store();
$dbh->commit();

$m->get("$server/solpeople/login.pl");
$m->submit_form_ok( \%form, "Login as curator form submission" );
$m->get_ok("$server/solpeople/top-level.pl");
$m->content_contains( "Curator Tools", "Curator tools presence test" );

$m->get_ok("$server/solpeople/login.pl?logout=yes");
$m->content_contains("You have successfully logged out");

# try logging in with wrong password
#
$form{fields}->{pd} = "blablabla"; # enter wrong password
$m->get_ok("$server/solpeople/login.pl");
$m->submit_form_ok( \%form, "Submit wrong password test" );
$m->content_contains("Incorrect username or password");


# delete the test user from the database (even if the test died)
#
END { $u->hard_delete() if $u }
