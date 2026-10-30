
use strict;
use lib 't/lib';
use Test::More 'tests' => 88;
use SGN::Test::Fixture;
use SGN::Test::WWW::WebDriver;
use Try::Tiny;
use Selenium::Waiter;
use LWP::UserAgent;

# Set up the web driver
my $w = SGN::Test::WWW::WebDriver->new();
my $d = $w->driver;

# wait_for() does its own polling, so keep the implicit wait at 0 (otherwise
# every failed lookup blocks for the implicit wait on top of the poll interval).
# Keycloak redirects + the token exchange can be slow on CI, so allow 30s.
my $WAIT_TIMEOUT  = 30;
my $WAIT_INTERVAL = 1;
$d->set_timeout('implicit', 0);
$d->set_timeout('pageLoad', $WAIT_TIMEOUT * 1000);

# Keycloak runs as a CI service with no health check, so it may still be
# starting when this test runs. Wait for its discovery document first.
my $keycloak_well_known = 'http://keycloak:9080/auth/realms/Breedbase/.well-known/openid-configuration';
{
    my $ua = LWP::UserAgent->new(timeout => 5);
    my $ready = wait_until { $ua->get($keycloak_well_known)->is_success } timeout => 180, interval => 2;
    BAIL_OUT("Keycloak is not reachable at $keycloak_well_known") unless $ready;
}

# Set up the DB connection
my $f = SGN::Test::Fixture->new();
my $dbh = $f->bcs_schema->storage->dbh;
my $q;

# Set up our people
my $submitter = $w->user_data()->{submitter};
my $curator   = $w->user_data()->{curator};

# -----------------------------------------------------------------------------
# Utility Functions
# -----------------------------------------------------------------------------

# Lightweight wrapper around Selenium::Waiter::wait_until with this test's
# timeout and interval
sub wait_for {
    my $assert = shift;
    return wait_until { $assert->() } timeout => $WAIT_TIMEOUT, interval => $WAIT_INTERVAL;
}

# Wait until the page source matches $re. The match must happen inside the
# poll loop, otherwise the first (possibly still loading) page is checked once.
sub wait_for_source {
    my $re = shift;
    return wait_for sub { $d->get_page_source() =~ $re };
}

# Wait until an alert whose text matches $re is open
sub wait_for_alert {
    my $re = shift;
    return wait_for sub { $d->get_alert_text() =~ $re };
}

# Wait until the logged in user's name is shown in the navbar
sub wait_for_profile {
    my $username = shift;
    return wait_for sub { $d->find_element_by_id('navbar_profile')->get_text() eq $username };
}

# Logout through Keycloak
sub logout_keycloak {
    my $keycloak_logout = 'http://keycloak:9080/auth/realms/Breedbase/protocol/openid-connect/logout';
    # A leftover alert from a failed step blocks every later command
    eval { $d->dismiss_alert };
    ok( wait_for sub { $d->navigate($keycloak_logout) }, 'open keycloak logout');
    ok( wait_for sub { $d->find_element_by_id('kc-logout')->click() }, 'click keycloak logout button');
    ok( wait_for_source(qr/You are logged out/), 'locate logged out content');
}

# Logout Through Breedbase
sub logout_breedbase {
    ok( wait_for sub {$d->find_element_by_id('navbar_logout')->click() }, 'click logout button');
    ok( wait_for sub {$d->accept_alert }, 'confirm logout');
}

# Pre-emptive cleanup
$q = "update sgn_people.sp_person set private_email = null where username = 'johndoe' or username = 'janedoe'";
$dbh->prepare($q)->execute();
$q = "delete from sgn_people.sp_token where sp_person_id = (select sp_person_id from sgn_people.sp_person where username = 'newuser')";
$dbh->prepare($q)->execute();
$q = "delete from sgn_people.sp_person where username = 'newuser'";
$dbh->prepare($q)->execute();

# -----------------------------------------------------------------------------
# Login by matching email to an existing account (SUCCESS)
# -----------------------------------------------------------------------------

# First, we must give our fixture user an email that match keycloak
$q = 'update sgn_people.sp_person set private_email = \'janedoe@janedoe.test\' where username = ?';
$dbh->prepare($q)->execute($curator->{username});

# Load the login dialog box
ok( wait_for sub { $d->navigate('/user/login') }, 'open login dialog');

# Click the "Login with Keycloak" button
ok( wait_for sub { $d->find_element_by_id('login_with_keycloak')->click() }, 'click login button');

# Enter Keycloak Username and Password and then click "Sign In" button
ok( wait_for sub { $d->find_element_by_id('username')->send_keys($curator->{username}) }, 'enter username');
ok( wait_for sub { $d->find_element_by_id('password')->send_keys($curator->{password}) }, 'enter password');
ok( wait_for sub { $d->find_element_by_id('kc-login')->click() }, 'click keycloak login button');

# Check that we have: 1. Logged in as 'janedoe', and 2. Are on the homepage
ok( wait_for_profile('janedoe'), 'logged in as janedoe');
ok( wait_for_source(qr/What is Breedbase/), 'locate home page content');

# Logout Through Breedbase
logout_breedbase();

# Check that we logged out successfully by the presence of the 'Login' button again
ok( wait_for sub { $d->find_element_by_id('site_login_button') }, 'locate login button' );

# Check that single sign on has kept the user logged in
ok( wait_for sub { $d->navigate('/user/login')}, 'open login dialog');
ok( wait_for sub { $d->find_element_by_id('login_with_keycloak')->click() }, 'click login button');
ok( wait_for_profile('janedoe'), 'logged in as janedoe');
ok( wait_for_source(qr/What is Breedbase/), 'locate home page content');

# Logout
logout_breedbase();
logout_keycloak();

# -----------------------------------------------------------------------------
# Attempt to login with an email that matches multiple users (ERROR)
# -----------------------------------------------------------------------------

# Give johndoe and janedoe the same email address
$q = "update sgn_people.sp_person set private_email = 'janedoe\@janedoe.test' where username = ?";
$dbh->prepare($q)->execute($submitter->{username});

# Load the login dialog box
ok( wait_for sub { $d->navigate('/user/login') }, 'open login dialog');

# Click the "Login with Keycloak" button
ok( wait_for sub { $d->find_element_by_id('login_with_keycloak')->click() }, 'click login button');

# Enter Keycloak Username and Password and then click "Sign In" button
ok( wait_for sub { $d->find_element_by_id('username')->send_keys($curator->{username}) },  'enter username');
ok( wait_for sub { $d->find_element_by_id('password')->send_keys($curator->{password}) }, 'enter password');
ok( wait_for sub { $d->find_element_by_id('kc-login')->click() }, 'click keycloak login button');

# Check that an error is raised
ok( wait_for_alert(qr/Multiple users were found to have the email/), 'raise error multiple users');
ok( wait_for sub { $d->dismiss_alert }, 'dismiss error multiple users');

# Logout
logout_keycloak();

# -----------------------------------------------------------------------------
# Attempt to login with a new account when autoprovision is not enabled (ERROR)
# -----------------------------------------------------------------------------

# Load the login dialog box
ok( wait_for sub { $d->navigate('/user/login') }, 'open login dialog');

# Click the "Login with Keycloak" button
ok( wait_for sub { $d->find_element_by_id('login_with_keycloak-no-auto-provision')->click() }, 'click login button');

# Enter Keycloak Username and Password and then click "Sign In" button
ok( wait_for sub { $d->find_element_by_id('username')->send_keys("newuser") },  'enter username');
ok( wait_for sub { $d->find_element_by_id('password')->send_keys("password") }, 'enter password');
ok( wait_for sub { $d->find_element_by_id('kc-login')->click() }, 'click keycloak login button');

# Check that an error is raised
ok( wait_for_alert(qr/No system user was found/), 'raise error no system user found');
ok( wait_for sub { $d->dismiss_alert }, 'dismiss error no system user found');

# Logout
logout_keycloak();

# -----------------------------------------------------------------------------
# Attempt to login with an email that is unverified in keycloak (ERROR)
# -----------------------------------------------------------------------------

# Load the login dialog box
ok( wait_for sub { $d->navigate('/user/login') }, 'open login dialog');

# Click the "Login with Keycloak" button
ok( wait_for sub { $d->find_element_by_id('login_with_keycloak')->click() }, 'click login button');

# Enter Keycloak Username and Password and then click "Sign In" button
ok( wait_for sub { $d->find_element_by_id('username')->send_keys('newuser_unverified') },  'enter username');
ok( wait_for sub { $d->find_element_by_id('password')->send_keys('password') }, 'enter password');
ok( wait_for sub { $d->find_element_by_id('kc-login')->click() }, 'click keycloak login button');

# Check that an error is raised
ok( wait_for_alert(qr/Your email is not verified/), 'raise error email not verified');
ok( wait_for sub { $d->dismiss_alert }, 'dismiss error email not verified');

# Logout
logout_keycloak();

# -----------------------------------------------------------------------------
# Login by auto-provisioning a new account: 'newuser' (SUCCESS)
# -----------------------------------------------------------------------------

# Load the login dialog box
ok( wait_for sub { $d->navigate('/user/login') }, 'open login dialog');

# Click the "Login with Keycloak" button
ok( wait_for sub { $d->find_element_by_id('login_with_keycloak')->click() }, 'click login button');

# Enter Keycloak Username and Password and then click "Sign In" button
ok( wait_for sub { $d->find_element_by_id('username')->send_keys("newuser") },  'enter username');
ok( wait_for sub { $d->find_element_by_id('password')->send_keys("password") }, 'enter password');
ok( wait_for sub { $d->find_element_by_id('kc-login')->click() }, 'click keycloak login button');

# Check that we have: 1. Logged in as 'newuser', and 2. Are on the homepage
ok( wait_for_profile('newuser'), 'logged in as newuser');
ok( wait_for_source(qr/What is Breedbase/), 'locate home page content');

# Logout
logout_breedbase();
logout_keycloak();

# -----------------------------------------------------------------------------
# Miscellaneous Error Handling (ERROR)
# -----------------------------------------------------------------------------

# Raise error if login has unknown provider
ok( wait_for sub { $d->navigate('/authenticate/oidc/unknown/login') }, 'login with unknown provider');
ok( wait_for_alert(qr/not configured/), 'raise error not configured');
ok( wait_for sub { $d->dismiss_alert }, 'dismiss error not configured error');

# Raise error if callback has unknown provider
ok( wait_for sub { $d->navigate('/authenticate/oidc/unknown/callback') }, 'callback with unknown provider');
ok( wait_for_alert(qr/not configured/), 'raise error not configured');
ok( wait_for sub { $d->dismiss_alert }, 'dismiss error not configured');

# Raise error if state_verifier cookie is missing
ok( wait_for sub { $d->navigate('/authenticate/oidc/keycloak/callback') }, 'callback with keycloak provider');
ok( wait_for_alert(qr/state verifier could not be found/), 'raise error state verifier not found');
ok( wait_for sub { $d->dismiss_alert }, 'dismiss error state verifier not found');

# Raise error if observed state_verifier does not match expected
ok( wait_for sub { $d->add_cookie('keycloak_state_verifier', 'bad') }, 'create bad state_verifier cookie' );
ok( wait_for sub { $d->navigate('/authenticate/oidc/keycloak/callback') }, 'callback with keycloak provider');
ok( wait_for_alert(qr/does not match the initiating state/), 'raise error state verifier bad match');
ok( wait_for sub { $d->dismiss_alert }, 'dismiss error state verifier bad match');

# Raise error if well known url is bad
ok( wait_for sub { $d->navigate('/user/login') }, 'open login dialog');
ok( wait_for sub { $d->find_element_by_id('login_with_keycloak-bad-well-known')->click() }, 'click login button');
ok( wait_for_alert(qr/Failed to fetch well known/), 'raise error well known fail');
ok( wait_for sub { $d->dismiss_alert }, 'dismiss error well known fail');

# Keycloak error page if client id is bad
ok( wait_for sub { $d->navigate('/user/login') }, 'open login dialog');
ok( wait_for sub { $d->find_element_by_id('login_with_keycloak-bad-client-id')->click() }, 'click login button');
ok( wait_for_source(qr/Client not found/), 'error page client not found');

# Raise error if client secret is bad
ok( wait_for sub { $d->navigate('/user/login') }, 'open login dialog');
ok( wait_for sub { $d->find_element_by_id('login_with_keycloak-bad-client-secret')->click() }, 'click login button');
ok( wait_for sub { $d->find_element_by_id('username')->send_keys($curator->{username}) },  'enter username');
ok( wait_for sub { $d->find_element_by_id('password')->send_keys($curator->{password}) }, 'enter password');
ok( wait_for sub { $d->find_element_by_id('kc-login')->click() }, 'click keycloak login button');
ok( wait_for_alert(qr/Invalid client credentials/), 'raise error invalid credentials');
ok( wait_for sub { $d->dismiss_alert }, 'dismiss error invalid credentials');

# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------

# Cleanup database
$q = "update sgn_people.sp_person set private_email = null where username = 'johndoe' or username = 'janedoe'";
$dbh->prepare($q)->execute();
$q = "delete from sgn_people.sp_token where sp_person_id = (select sp_person_id from sgn_people.sp_person where username = 'newuser')";
$dbh->prepare($q)->execute();
$q = "delete from sgn_people.sp_person where username = 'newuser'";
$dbh->prepare($q)->execute();

# Cleanup tests and driver
$d->quit();
done_testing();

