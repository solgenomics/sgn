
=head1 NAME

t/unit_mech/Controller/User.t - tests for /user/confirm and /user/reset_password_form

=head1 DESCRIPTION

Only new accounts that are waiting for confirmation can be confirmed.
An account that was disabled for another reason must not be re-enabled
with a confirmation code or with a password reset token (both are
stored in sp_person.confirm_code). Usernames must be HTML-escaped.

=cut

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use URI::Escape;
use CXGN::People::Login;
use CXGN::People::Person;

my $f = SGN::Test::Fixture->new();
# the people schema connection has sgn (pgcrypto) in its search path
#
my $dbh = $f->people_schema->storage->dbh();
my $mech = Test::WWW::Mechanize->new;

my @person_ids;

sub create_account {
    my %args = @_;

    my $login = CXGN::People::Login->new($dbh);
    $login->set_username($args{username});
    $login->set_private_email($args{private_email});
    $login->set_pending_email($args{pending_email});
    $login->set_confirm_code($args{confirm_code});
    $login->set_disabled($args{disabled});
    $login->store();
    $login->update_password('secretpw1');

    my $person = CXGN::People::Person->new($dbh, $login->get_sp_person_id());
    $person->set_first_name('Test');
    $person->set_last_name('User');
    $person->store();

    push @person_ids, $login->get_sp_person_id();
    return $login->get_sp_person_id();
}

sub account {
    my $person_id = shift;
    return $dbh->selectrow_hashref("SELECT disabled, confirm_code, private_email FROM sgn_people.sp_person WHERE sp_person_id=?", undef, $person_id);
}

# request a password reset; the token is sent to the user by email
#
sub request_password_reset {
    my ($person_id, $email) = @_;
    $mech->get_ok("http://localhost:3010/ajax/user/reset_password?password_reset_email=$email");
    return account($person_id)->{confirm_code};
}

# a new account that is waiting for confirmation can be confirmed
#
my $new_id = create_account(username => 'confirm_test_new', pending_email => 'confirm_test_new@example.com', disabled => 'unconfirmed account', confirm_code => 'confirmtestcode1');
$mech->get_ok('http://localhost:3010/user/confirm?username=confirm_test_new&confirm_code=confirmtestcode1');
$mech->content_contains('Confirmation successful for username <b>confirm_test_new</b>', 'new account confirmed');
is(account($new_id)->{disabled}, undef, 'confirmed account is enabled');
is(account($new_id)->{private_email}, 'confirm_test_new@example.com', 'pending email becomes the private email');

# an account disabled by an administrator is not re-enabled with a password reset token
#
my $disabled_id = create_account(username => 'confirm_test_disabled', private_email => 'confirm_test_disabled@example.com', disabled => 'disabled by admin');
my $token = request_password_reset($disabled_id, 'confirm_test_disabled@example.com');
ok($token, 'password reset token issued for the disabled account');
$mech->get_ok("http://localhost:3010/user/confirm?username=confirm_test_disabled&confirm_code=$token");
$mech->content_lacks('Confirmation successful', 'disabled account is not confirmed');
is(account($disabled_id)->{disabled}, 'disabled by admin', 'disabled account stays disabled');

# the old cgi-bin confirmation page does not re-enable it either
#
my $legacy_id = create_account(username => 'confirm_test_legacy', private_email => 'confirm_test_legacy@example.com', disabled => 'disabled by admin');
$token = request_password_reset($legacy_id, 'confirm_test_legacy@example.com');
$mech->get("http://localhost:3010/solpeople/account-confirm.pl?username=confirm_test_legacy&confirm=$token");
is(account($legacy_id)->{disabled}, 'disabled by admin', 'disabled account stays disabled after /solpeople/account-confirm.pl');

# an active account with a pending password reset is left unchanged
#
my $active_id = create_account(username => 'confirm_test_active', private_email => 'confirm_test_active@example.com');
$token = request_password_reset($active_id, 'confirm_test_active@example.com');
$mech->get_ok("http://localhost:3010/user/confirm?username=confirm_test_active&confirm_code=$token");
$mech->content_lacks('Confirmation successful', 'active account is not confirmed again');
is(account($active_id)->{private_email}, 'confirm_test_active@example.com', 'private email of the active account is kept');
is(account($active_id)->{confirm_code}, $token, 'password reset token of the active account is kept');

# the username from the query string is escaped
#
my $script = '<script>alert("confirm")</script>';
$mech->get_ok('http://localhost:3010/user/confirm?confirm_code=x&username='.uri_escape($script));
$mech->content_lacks($script, 'username is not included unescaped');
$mech->content_contains('&lt;script&gt;alert(&quot;confirm&quot;)&lt;/script&gt;', 'username is escaped');

# the username on the reset password form is escaped
#
create_account(username => '<i>confirm_test_markup</i>', private_email => 'confirm_test_markup@example.com', confirm_code => 'resetformtoken1');
$mech->get_ok('http://localhost:3010/user/reset_password_form?reset_password_token=resetformtoken1');
$mech->content_lacks('<i>confirm_test_markup</i>', 'username is not included unescaped');
$mech->content_contains('Enter new password for user &lt;i&gt;confirm_test_markup&lt;/i&gt;', 'username is escaped');

# clean up
#
foreach my $person_id (@person_ids) {
    $dbh->do("DELETE FROM sgn_people.sp_token WHERE sp_person_id=?", undef, $person_id);
    CXGN::People::Person->new($dbh, $person_id)->hard_delete();
}

done_testing();
