
=head1 NAME

t/unit_fixture/SGN/Controller/Authenticate/OIDCAccountCheck.t - the OIDC
callback must not start a session for a disabled or deactivated account

=head1 DESCRIPTION

SGN::Controller::Authenticate::OIDC::callback finds an account by e-mail
and then creates a session for it. It must apply the same disabled/
deactivated check that CXGN::Login::login_user applies to a username and
password login, so that an account that is disabled or that has the
'deactivated' role cannot get an SSO session either.

There is no Keycloak (or any OIDC provider) available in this test
environment, so this test does not drive the full HTTP callback. Instead
it calls SGN::Controller::Authenticate::OIDC->_refuse_disabled_or_deactivated
directly, against the fixture database, the same way the callback calls it
just before creating the sp_token session row. This is the actual
production code, not a re-implementation of its logic.

=cut

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::Exception;

use CXGN::People::Login;
use CXGN::People::Person;
use SGN::Controller::Authenticate::OIDC;

my $f = SGN::Test::Fixture->new();
my $dbh = $f->people_schema->storage->dbh();

my @person_ids;

sub create_account {
    my ($username, $disabled) = @_;

    my $login = CXGN::People::Login->new($dbh);
    $login->set_username($username);
    $login->set_private_email($username.'@example.com');
    $login->set_disabled($disabled);
    $login->store();

    my $person = CXGN::People::Person->new($dbh, $login->get_sp_person_id());
    $person->set_first_name('Test');
    $person->set_last_name('User');
    $person->store();

    push @person_ids, $login->get_sp_person_id();
    return $login;
}

# an account still waiting for confirmation
#
my $unconfirmed = create_account('oidc_check_unconfirmed', 'unconfirmed account');
throws_ok {
    SGN::Controller::Authenticate::OIDC->_refuse_disabled_or_deactivated($dbh, $unconfirmed->get_sp_person_id(), 'unconfirmed account');
} qr/deactivated due to unconfirmed account/, 'unconfirmed account is refused a session';

# an account disabled by an administrator
#
my $disabled = create_account('oidc_check_disabled', 'disabled by admin');
throws_ok {
    SGN::Controller::Authenticate::OIDC->_refuse_disabled_or_deactivated($dbh, $disabled->get_sp_person_id(), 'disabled by admin');
} qr/deactivated due to disabled by admin/, 'admin-disabled account is refused a session';

# an account with the deactivated role (disabled column is NULL)
#
my $deactivated = create_account('oidc_check_deactivated', undef);
$deactivated->add_role('deactivated');
throws_ok {
    SGN::Controller::Authenticate::OIDC->_refuse_disabled_or_deactivated($dbh, $deactivated->get_sp_person_id(), undef);
} qr/deactivated by an administrator/, 'account with the deactivated role is refused a session';

# an active account is not refused
#
my $active = create_account('oidc_check_active', undef);
lives_ok {
    SGN::Controller::Authenticate::OIDC->_refuse_disabled_or_deactivated($dbh, $active->get_sp_person_id(), undef);
} 'active account is not refused a session';

# clean up
#
foreach my $person_id (@person_ids) {
    $dbh->do("DELETE FROM sgn_people.sp_person_roles WHERE sp_person_id=?", undef, $person_id);
    $dbh->do("DELETE FROM sgn_people.sp_token WHERE sp_person_id=?", undef, $person_id);
    CXGN::People::Person->new($dbh, $person_id)->hard_delete();
}

done_testing();
