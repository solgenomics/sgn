use strict;
use warnings;

use Test::More;
use lib 't/lib';
use SGN::Test::WWW::Mechanize;

my $m = SGN::Test::WWW::Mechanize->new();

plan skip_all => 'test requires at least "local" test level'
  unless $m->can_test_level('local');

use_ok("CXGN::People::Person");

$m->get_ok('/');

my $dbh = $m->context->dbc->dbh();

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
$login->set_organization("testorganization");
$login->set_user_type("user");

$login->store();

#$dbh->commit();

my $u_id = CXGN::People::Person->get_person_by_username( $dbh, "testusername" );
my $u = CXGN::People::Person->new( $dbh, $u_id );
END {
    if( $u ) {
        $u->hard_delete();
        #$dbh->commit; #unless $u->get_dbh->dbh_param('AutoCommit');
    }
}

is( $u->get_first_name(), "testfirstname", "Test first name test" );

# check basic login
#
$m->get_ok("/solpeople/top-level.pl");
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
$m->content_contains("testorganization");
$m->get('/solpeople/top-level.pl');

$m->follow_link_ok({ url_regex => qr/personal-info\.pl/ });
$m->submit_form_ok({
        form_number => 2,
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
$m->get_ok( "/solpeople/login.pl?logout=yes",
            "Request logout page" );

$m->content_contains("You have successfully logged out");

# login as a curator
#
$login->set_user_type("curator");
$login->store();
#$dbh->commit();

$m->get("/solpeople/login.pl");
$m->submit_form_ok( \%form, "Login as curator form submission" );
$m->get_ok("/solpeople/top-level.pl");
$m->content_contains( "Curator Tools", "Curator tools presence test" );

$m->get_ok("/solpeople/login.pl?logout=yes");
$m->content_contains("You have successfully logged out");

# try logging in with wrong password
#
$form{fields}->{pd} = "blablabla"; # enter wrong password
$m->get_ok("/solpeople/login.pl");
$m->submit_form_ok( \%form, "Submit wrong password test" );
$m->content_contains("Incorrect username or password");

# delete the test user from the database (even if the test died)
#
END {
    if( $dbh and  my $u_id = CXGN::People::Person->get_person_by_username( $dbh, "testusername" ) ) {
        CXGN::People::Person->new( $dbh, $u_id )->hard_delete;
    }
}
done_testing;
