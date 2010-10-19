
use strict;

use Test::More tests=>9;

use SGN::Test::WWW::Mechanize;
use CXGN::DB::Connection;

my $m = SGN::Test::WWW::Mechanize->new();
my $dbh = CXGN::DB::Connection->new();

# create a test user for login
# check if test user exists and delete if so
#
if( my $u_id = CXGN::People::Person->get_person_by_username( $dbh, "testusername" ) ) {
    CXGN::People::Person->new( $dbh, $u_id )->hard_delete;
}

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

# login using the test user
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

# test image upload
$m->get_ok('/image/add?type=test&type_id=1');

my %form = ( form_name => 'upload_image_form',
	     fields => { 
		 file=>'t/image/tv_test_1.png',
#		 type=>'locus',
#		 type_id=>'1',
		 refering_page=>'http://google.com',
	     },
    );

$m->submit_form_ok(\%form, "form submit tets");

$m->content_like( qr/image\s+uploaded/, "content test 1");
#check if referer appears
$m->content_contains('http://google.com');

#check submitter id
$m->content_contains($p_id);


