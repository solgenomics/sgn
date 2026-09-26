
=head1 NAME

t/unit_mech/AJAX/Login_disabled_accounts.t - disabled accounts must not get a login session

=head1 DESCRIPTION

An account that has sp_person.disabled set (for example a new account
that has not been confirmed yet) or that has the 'deactivated' role
must not obtain a session, neither through /ajax/user/login nor
through the BrAPI token call.

=cut

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use JSON;
use CXGN::People::Login;
use CXGN::People::Person;

my $f = SGN::Test::Fixture->new();
# the people schema connection has sgn (pgcrypto) in its search path
#
my $dbh = $f->people_schema->storage->dbh();

my $password = 'secretpw1';
my @person_ids;

sub create_account {
    my ($username, $disabled) = @_;

    my $login = CXGN::People::Login->new($dbh);
    $login->set_username($username);
    $login->set_private_email($username.'@example.com');
    $login->set_disabled($disabled);
    $login->store();
    $login->update_password($password);

    my $person = CXGN::People::Person->new($dbh, $login->get_sp_person_id());
    $person->set_first_name('Test');
    $person->set_last_name('User');
    $person->store();

    push @person_ids, $login->get_sp_person_id();
    return $login;
}

sub session_count {
    my $person_id = shift;
    my ($count) = $dbh->selectrow_array("SELECT count(*) FROM sgn_people.sp_token WHERE sp_person_id=?", undef, $person_id);
    return $count;
}

sub check_no_session {
    my ($login, $label) = @_;
    my $username = $login->get_username();

    my $mech = Test::WWW::Mechanize->new;
    $mech->get_ok("http://localhost:3010/ajax/user/login?username=$username&password=$password");
    my $response = decode_json $mech->content;
    like($response->{error}, qr/This account has been deactivated/, "$label: login is refused");
    unlike($mech->res->header('Set-Cookie') || '', qr/sgn_session_id=\w/, "$label: no session cookie is set");

    $mech->get_ok('http://localhost:3010/user/logged_in');
    $response = decode_json $mech->content;
    is($response->{user_id}, 0, "$label: not logged in after the login attempt");

    my $brapi = Test::WWW::Mechanize->new;
    $brapi->post_ok('http://localhost:3010/brapi/v2/token', [ username => $username, password => $password, grant_type => 'password' ]);
    $response = decode_json $brapi->content;
    ok(!$response->{access_token}, "$label: no BrAPI access token");
    unlike($brapi->res->header('Set-Cookie') || '', qr/sgn_session_id=\w/, "$label: no session cookie is set by BrAPI");

    is(session_count($login->get_sp_person_id()), 0, "$label: no session is stored");
}

# a new account that is waiting for confirmation
#
check_no_session(create_account('disabled_login_unconfirmed', 'unconfirmed account'), 'unconfirmed account');

# an account that was disabled by an administrator
#
check_no_session(create_account('disabled_login_by_admin', 'disabled by admin'), 'disabled account');

# an account with the deactivated role
#
my $deactivated = create_account('disabled_login_deactivated', undef);
$deactivated->add_role('deactivated');
check_no_session($deactivated, 'deactivated account');

# an active account still logs in
#
my $active = create_account('disabled_login_active', undef);
my $mech = Test::WWW::Mechanize->new;
$mech->get_ok("http://localhost:3010/ajax/user/login?username=disabled_login_active&password=$password");
is(decode_json($mech->content)->{message}, 'Login successful', 'active account: login successful');
$mech->get_ok('http://localhost:3010/user/logged_in');
is(decode_json($mech->content)->{user_id}, $active->get_sp_person_id(), 'active account: logged in');
is(session_count($active->get_sp_person_id()), 1, 'active account: one session is stored');

# clean up
#
foreach my $person_id (@person_ids) {
    $dbh->do("DELETE FROM sgn_people.sp_token WHERE sp_person_id=?", undef, $person_id);
    CXGN::People::Person->new($dbh, $person_id)->hard_delete();
}

done_testing();
