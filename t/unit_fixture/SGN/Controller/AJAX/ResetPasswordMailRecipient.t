
=head1 NAME

t/unit_fixture/SGN/Controller/AJAX/ResetPasswordMailRecipient.t - the
password reset mail must go to the matched account's own address

=head1 DESCRIPTION

/ajax/user/reset_password looks the account up with
CXGN::People::Login->get_login_by_email(). That lookup used to be
"private_email ilike ?", so an underscore or a percent sign in the
requested address acted as an SQL wildcard, and the reset link was mailed
to the requested address instead of the account's own. Together these
let whoever controls a look-alike mailbox (for example "_" standing in for
".") receive the victim's reset link.

Both halves are fixed: corelibs now compares lower(private_email) =
lower(?), so a look-alike address matches nothing, and reset_password()
mails the link to the matched account's own stored private_email, never
to the address typed in the request. The second part is checked with a
request address that differs from the stored one only in case, which
still matches.

This calls SGN::Controller::AJAX::User::reset_password directly (not
through the running test server), with a minimal stand-in for the Catalyst
context, so the mail recipient can be observed by overriding
CXGN::Contact::send_email in this process. That is not possible through
Test::WWW::Mechanize, because the web server runs in a separate process.

=cut

use strict;
use warnings;

package main;  # the mock classes below are declared inside this test

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;

use CXGN::People::Login;
use CXGN::People::Person;
use SGN::Controller::AJAX::User;

# ---------------------------------------------------------------------
# a minimal stand-in for the parts of $c that reset_password() and
# send_reset_email_message() use
#
package Test::FakeReq;
sub new { my ($class, $params) = @_; return bless { params => $params || {} }, $class; }
sub param { my ($self, $name) = @_; return $self->{params}{$name}; }

package Test::FakeDbc;
sub new { my ($class, $dbh) = @_; return bless { dbh => $dbh }, $class; }
sub dbh { return $_[0]->{dbh}; }

package Test::FakeContext;
sub new {
    my ($class, %args) = @_;
    return bless { req => $args{req}, dbc => $args{dbc}, config => $args{config}, stash => {} }, $class;
}
sub req    { return $_[0]->{req}; }
sub dbc    { return $_[0]->{dbc}; }
sub config { return $_[0]->{config}; }
sub stash  { return $_[0]->{stash}; }

package main;

my $f = SGN::Test::Fixture->new();
# the people schema connection has sgn (pgcrypto) in its search path, needed
# by CXGN::People::Login::store()'s crypt(?, gen_salt('bf'))
#
my $dbh = $f->people_schema->storage->dbh();

# the victim's own stored address
#
my $victim_email = 'reset.mail.victim@example.org';
# what an attacker types in the reset form: an underscore stands in for the
# dot, which is a wildcard match under "private_email ilike ?"
#
my $attacker_query_email = 'reset_mail_victim@example.org';

my $victim = CXGN::People::Login->new($dbh);
$victim->set_username('resetmailvictim');
$victim->set_private_email($victim_email);
$victim->set_password('irrelevant-password-1');
$victim->store();
my $victim_id = $victim->get_sp_person_id();

my $person = CXGN::People::Person->new($dbh, $victim_id);
$person->set_first_name('Reset');
$person->set_last_name('Victim');
$person->store();

# a request address that differs from the stored one only in case still
# matches the account
#
my $case_query_email = uc($victim_email);

sub confirm_code {
    my ($confirm_code) = $dbh->selectrow_array("SELECT confirm_code FROM sgn_people.sp_person WHERE sp_person_id=?", undef, $victim_id);
    return $confirm_code;
}

# calls reset_password() for $email and returns the mails it would send
#
sub request_reset {
    my $email = shift;
    my @sent;
    no warnings 'redefine';
    local *CXGN::Contact::send_email = sub {
        my ($subject, $body, $mailto, @rest) = @_;
        push @sent, { subject => $subject, mailto => $mailto };
    };

    my $c = Test::FakeContext->new(
        req    => Test::FakeReq->new({ password_reset_email => $email }),
        dbc    => Test::FakeDbc->new($dbh),
        config => { main_production_site_url => 'http://localhost:3010', project_name => 'SGN' },
    );

    SGN::Controller::AJAX::User->new->reset_password($c);
    return @sent;
}

# a look-alike address does not match the victim's account at all
#
is_deeply([ CXGN::People::Login->get_login_by_email($dbh, $attacker_query_email) ], [], "the wildcard look-alike address does not match the victim's account");

my @sent = request_reset($attacker_query_email);
is(scalar(@sent), 0, "no reset mail is sent for the look-alike address");
ok(!defined(confirm_code()), "no reset token is stored on the victim's account for the look-alike address");

# a matching request address that differs from the stored one: the mail
# goes to the stored address, not to the request value
#
is_deeply([ CXGN::People::Login->get_login_by_email($dbh, $case_query_email) ], [ $victim_id ], "the email lookup ignores case");

@sent = request_reset($case_query_email);
is(scalar(@sent), 1, "reset_password sent exactly one mail");
is($sent[0]{mailto}, $victim_email, "the reset mail is sent to the account's own stored private_email, not the request value")
    if @sent;
like(confirm_code(), qr/^[A-Za-z0-9]{16}\z/, "a reset token was stored on the matched account");

# clean up
#
$dbh->do("DELETE FROM sgn_people.sp_token WHERE sp_person_id=?", undef, $victim_id);
CXGN::People::Person->new($dbh, $victim_id)->hard_delete();

done_testing();
