
=head1 NAME

t/unit_fixture/SGN/Controller/AJAX/ResetPasswordMailRecipient.t - the
password reset mail must go to the matched account's own address

=head1 DESCRIPTION

/ajax/user/reset_password looks the account up with
CXGN::People::Login->get_login_by_email(), which corelibs implements with
"private_email ilike ?". An underscore or a percent sign in the address
supplied in the request acts as an SQL wildcard, so a request address that
only resembles the stored one (for example "_" standing in for ".") can
still match an account. Once an account is matched, the reset link must be
mailed to that account's own stored private_email, never to the address
that was typed in the request; otherwise whoever controls a mailbox that
happens to match via the wildcard receives the victim's reset link.

This calls SGN::Controller::AJAX::User::reset_password directly (not
through the running test server), with a minimal stand-in for the Catalyst
context, so the mail recipient can be observed by overriding
CXGN::Contact::send_email in this process. That is not possible through
Test::WWW::Mechanize, because the web server runs in a separate process.

=cut

use strict;
use warnings;

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

ok(
    scalar(CXGN::People::Login->get_login_by_email($dbh, $attacker_query_email)) > 0,
    "sanity check: the wildcard-alternate address still matches the victim's account (this is the corelibs ILIKE issue, not part of this fix)"
);

my @sent;
{
    no warnings 'redefine';
    local *CXGN::Contact::send_email = sub {
        my ($subject, $body, $mailto, @rest) = @_;
        push @sent, { subject => $subject, mailto => $mailto };
    };

    my $c = Test::FakeContext->new(
        req    => Test::FakeReq->new({ password_reset_email => $attacker_query_email }),
        dbc    => Test::FakeDbc->new($dbh),
        config => { main_production_site_url => 'http://localhost:3010', project_name => 'SGN' },
    );

    SGN::Controller::AJAX::User->new->reset_password($c);
}

is(scalar(@sent), 1, "reset_password sent exactly one mail");
is($sent[0]{mailto}, $victim_email, "the reset mail is sent to the account's own stored private_email, not the request value")
    if @sent;
isnt($sent[0]{mailto}, $attacker_query_email, "the reset mail is not sent to the request address when it differs from the stored one")
    if @sent;

my ($confirm_code) = $dbh->selectrow_array("SELECT confirm_code FROM sgn_people.sp_person WHERE sp_person_id=?", undef, $victim_id);
like($confirm_code, qr/^[A-Za-z0-9]{16}$/, "a reset token was stored on the matched account");

# clean up
#
$dbh->do("DELETE FROM sgn_people.sp_token WHERE sp_person_id=?", undef, $victim_id);
CXGN::People::Person->new($dbh, $victim_id)->hard_delete();

done_testing();
