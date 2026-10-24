
=head1 NAME

t/unit_mech/AJAX/ResetPassword.t - tests for /ajax/user/process_reset_password

=head1 DESCRIPTION

Checks that a password reset token can only be used once, that an empty
or fixed confirm_code value can never be used as a reset token, and that
the new password and the reset token are only accepted in the body of a
POST request.

=cut

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use CXGN::People::Person;

use Data::Dumper;
use JSON;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $dbh = $f->dbh();
my $mech = Test::WWW::Mechanize->new(autocheck => 0);
my $response;

my $username = 'resetpasswordtester';
my $email = 'reset_password_tester@example.org';

# create a confirmed account with a private email address
#
$mech->post_ok('http://localhost:3010/ajax/user/new', { first_name => 'Reset', last_name => 'Tester', username => $username, password => 'oldpassword1', confirm_password => 'oldpassword1', email_address => $email });
my $person_id = CXGN::People::Person->get_person_by_username($dbh, $username);
ok($person_id, "created test account $username");
$dbh->do("UPDATE sgn_people.sp_person SET disabled = NULL, confirm_code = NULL, private_email = ? WHERE sp_person_id = ?", undef, $email, $person_id);

sub can_login {
    my $password = shift;
    my $login_mech = Test::WWW::Mechanize->new(autocheck => 0);
    $login_mech->post('http://localhost:3010/ajax/user/login', { username => $username, password => $password });
    my $r = eval { decode_json $login_mech->content } || {};
    return (($r->{message} || '') eq 'Login successful') ? 1 : 0;
}

sub confirm_code {
    my ($confirm_code) = $dbh->selectrow_array("SELECT confirm_code FROM sgn_people.sp_person WHERE sp_person_id = ?", undef, $person_id);
    return $confirm_code;
}

sub set_confirm_code {
    my $confirm_code = shift;
    $dbh->do("UPDATE sgn_people.sp_person SET confirm_code = ? WHERE sp_person_id = ?", undef, $confirm_code, $person_id);
}

sub request_reset_token {
    $mech->post_ok('http://localhost:3010/ajax/user/reset_password', { password_reset_email => $email });
    return confirm_code();
}

sub process_reset {
    my $token = shift;
    my $password = shift;
    $mech->post('http://localhost:3010/ajax/user/process_reset_password', { token => $token, new_password => $password, confirm_password => $password });
    is($mech->status(), 200, 'process_reset_password POST status');
    my $r = decode_json $mech->content;
    print STDERR Dumper $r;
    return $r;
}

ok(can_login('oldpassword1'), 'test account can log in');

# a valid reset token works exactly once
#
my $token = request_reset_token();
like($token, qr/^[A-Za-z0-9]{16}$/, 'reset token stored for the account');

$response = process_reset($token, 'newpassword1');
is($response->{message}, 'The password was successfully updated.', 'password reset with valid token');
ok(can_login('newpassword1'), 'password was changed by the reset');
ok(!defined(confirm_code()), 'used reset token is cleared to NULL, not to an empty string');

$response = process_reset($token, 'newpassword2');
ok($response->{error}, 'a used reset token is rejected');
ok(!can_login('newpassword2'), 'password unchanged after reusing a token');

# an empty token must never match an account, not even one whose
# confirm_code was left as an empty string by an earlier reset
#
set_confirm_code('');
$response = process_reset('', 'emptytoken1');
ok($response->{error}, 'empty reset token is rejected');
ok(!can_login('emptytoken1'), 'empty token did not set the password');
ok(can_login('newpassword1'), 'password unchanged after empty token');

# a fixed confirm_code value, such as the one stored for accounts created
# through /brapiapp/register, is not a reset token
#
set_confirm_code('ConfirmedByBrAPIApp');
$response = process_reset('ConfirmedByBrAPIApp', 'fixedtoken1');
ok($response->{error}, 'fixed confirm_code value is rejected as a reset token');
ok(!can_login('fixedtoken1'), 'fixed confirm_code value did not set the password');

# the reset token and the new password are only accepted in a POST body
#
$token = request_reset_token();
$mech->get("http://localhost:3010/ajax/user/process_reset_password?token=$token&new_password=querypassword1&confirm_password=querypassword1");
is($mech->status(), 405, 'process_reset_password rejects GET');
is(confirm_code(), $token, 'reset token not used up by GET request');

$mech->post("http://localhost:3010/ajax/user/process_reset_password?token=$token&new_password=querypassword1&confirm_password=querypassword1");
$response = decode_json $mech->content;
ok($response->{error}, 'process_reset_password ignores query string parameters on POST');
ok(!can_login('querypassword1'), 'password not set from the query string');

$response = process_reset($token, 'newpassword3');
is($response->{message}, 'The password was successfully updated.', 'reset with token in POST body');
ok(can_login('newpassword3'), 'password changed by POST body');

# a reset token does not work for a disabled account
#
$token = request_reset_token();
$dbh->do("UPDATE sgn_people.sp_person SET disabled = 'test' WHERE sp_person_id = ?", undef, $person_id);
$response = process_reset($token, 'disabledpassword1');
ok($response->{error}, 'reset token rejected for disabled account');
$dbh->do("UPDATE sgn_people.sp_person SET disabled = NULL WHERE sp_person_id = ?", undef, $person_id);
ok(!can_login('disabledpassword1'), 'password of disabled account unchanged');

# delete the test account
#
$dbh->do("DELETE FROM sgn_people.sp_token WHERE sp_person_id = ?", undef, $person_id);
CXGN::People::Person->new($dbh, $person_id)->hard_delete();

done_testing();
