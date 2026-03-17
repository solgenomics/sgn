
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use CXGN::People::Person;

#Needed to update IO::Socket::SSL
use Data::Dumper;
use JSON;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $mech = Test::WWW::Mechanize->new;
my $response;

$mech->get_ok('http://localhost:3010/ajax/user/login?username=janedoe&password=secretpw');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{message}, 'Login successful');

$mech->get_ok('http://localhost:3010/ajax/user/new?first_name=testfirst&last_name=testlast&username=testusername&password=testpass&confirm_password=testpass&email_address=test@testcassavabase.com');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'message' => 'Account was created with username "testusername".

To continue, you must confirm that we can reach you via email address "test@testcassavabase.com". An email has been sent with a URL to confirm this address. Please check your email for this message and use the link to confirm your email address.

You will be able to login once your account has been confirmed.'});

$mech->get_ok('http://localhost:3010/ajax/user/new?first_name=testfirst&last_name=testlast&username=testusername&password=testpass&confirm_password=testpass&email_address=test@testcassavabase.com&organization=testorg');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'error' => 'Account creation failed for the following reason(s): Username "testusername" is already in use. Please pick a different username.'});

#confirm account is still in cgi-bin, so test lacking here. will do manually
my $q = "update sgn_people.sp_person set disabled = default where username = 'testusername';";
my $sth = $f->bcs_schema->storage->dbh->prepare($q);
$sth->execute;
my $email = 'test@testcassavabase.com';
my $q = "update sgn_people.sp_person set private_email='$email' where username = 'testusername';";
my $sth = $f->bcs_schema->storage->dbh->prepare($q);
$sth->execute;

$mech->get_ok('http://localhost:3010/ajax/user/reset_password?password_reset_email=test@testcassavabase.com');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{message}, 'Reset link sent. Please check your email and click on the link.');
is(scalar(@{$response->{reset_links}}), 1);
is(scalar(@{$response->{reset_tokens}}), 1);
my $token = $response->{reset_tokens}->[0];

$mech->get_ok('http://localhost:3010/ajax/user/process_reset_password?token='.$token.'&new_password=testpasschange&confirm_password=testpasschange');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{message}, 'The password was successfully updated.');

$mech->get_ok('http://localhost:3010/ajax/user/login?username=testusername&password=testpasschange');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{message}, 'Login successful');

# CHECK UPDATES LOGGED IN AS WRONG USER

# test update password functionality 
#
$mech->get_ok('http://localhost:3010/ajax/user/update?change_password=1&current_password=secretpw&new_password=blablabla&confirm_password=blablabla');
$response = decode_json($mech->content());
print STDERR Dumper($response);
is($response->{error}, "Your current password does not match SGN records.", "password update check");

# reset it to what it was
#
$mech->get_ok('http://localhost:3010/ajax/user/update?change_password=1&current_password=blablabla&new_password=secretpw&confirm_password=secretpw');

# check email update
#
$mech->get_ok('http://localhost:3010/ajax/user/update?change_email=1&current_password=secretpw&private_email=test@testbase.org&confirm_email=test@testbase.org');
$response = decode_json($mech->content());
is($response->{error}, "Your current password does not match SGN records.", 'email update check');

# email was not set in the fixture, no need to reset it to nothing?


# change username
#
$mech->get_ok('http://localhost:3010/ajax/user/update?current_password=secretpw&change_username=1&new_username=janemoe');
my $un_response = decode_json($mech->content());
is($un_response->{error}, "Your current password does not match SGN records.", "username update check");

# change username back
#
$mech->get_ok('http://localhost:3010/ajax/user/update?current_password=secretpw&change_username=1&new_username=janedoe');

# LOG OUT WRONG USER
#
$mech->get_ok('http://localhost:3010/ajax/user/login?logout=1');
$response = decode_json $mech->content();
print STDERR "LOGOUT: ".Dumper($response);

# CHECK UPDATES WITH CORRECT USER
# login again as janedoe for update tests
#
$mech->get_ok('http://localhost:3010/ajax/user/login?username=janedoe&password=secretpw');
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{message}, 'Login successful');

# test update password functionality
#
$mech->get_ok('http://localhost:3010/ajax/user/update?change_password=1&current_password=secretpw&new_password=blablabla&confirm_password=blablabla');
$response = decode_json($mech->content());
print STDERR Dumper($response);
is($response->{message}, "Update successful", "password update check");

# reset it to what it was
#
$mech->get_ok('http://localhost:3010/ajax/user/update?change_password=1&current_password=blablabla&new_password=secretpw&confirm_password=secretpw');

# check email update
#
$mech->get_ok('http://localhost:3010/ajax/user/update?change_email=1&current_password=secretpw&private_email=test@testbase.org&confirm_email=test@testbase.org');
$response = decode_json($mech->content());
is($response->{message}, 'Update successful', 'email update check');

# email was not set in the fixture, no need to reset it to nothing?


# change username
#
$mech->get_ok('http://localhost:3010/ajax/user/update?current_password=secretpw&change_username=1&new_username=janemoe');
my $un_response = decode_json($mech->content());
is($un_response->{message}, "Update successful", "username update check");

# change username back
#
$mech->get_ok('http://localhost:3010/ajax/user/update?current_password=secretpw&change_username=1&new_username=janedoe');



#Delete user
my $dbh = $schema->storage->dbh;
if( $dbh and  my $u_id = CXGN::People::Person->get_person_by_username( $dbh, "testusername" ) ) {
    my $q = "delete from sgn_people.sp_token where sp_person_id=?";
    my $h = $dbh->prepare($q);
    $h->execute($u_id);
    CXGN::People::Person->new( $dbh, $u_id )->hard_delete;
}

done_testing;
