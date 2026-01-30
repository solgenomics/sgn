package SGN::Controller::Authenticate::OIDC;

use Moose;
use namespace::autoclean;

use Crypt::JWT qw(decode_jwt);
use Crypt::PRNG qw( random_string random_string_from );
use Digest::SHA qw(sha256);
use JSON::XS qw(decode_json);
use LWP::UserAgent;
use MIME::Base64::URLSafe;
use Try::Tiny;
use Data::Dumper;

use CatalystX::GlobalContext '$c';

BEGIN {extends 'Catalyst::Controller'; }

our $LOGIN_COOKIE_NAME = 'sgn_session_id';

=head1 NAME

SGN::Controller::Authenticate::OIDC - Browser login with OpenID Connect (OIDC)

=head1 DESCRIPTION


These are endpoints that handle logging users in and out using OpenID Connect.

=head1 AUTHOR

Katherine Eaton <kmeaton1@ualberta.ca>

=cut

=head2 login

This is a path stub to setup dynamic routing based on the name of the provider.

Examples:
- /authenticate/oidc/google/login
- /authenticate/oidc/keycloak/login

=cut

sub provider : Chained('/')  PathPart('authenticate/oidc')  CaptureArgs(1) {
    my ($self, $c, $provider) = @_;
    $c->stash->{provider} = $provider;
}

=head2 login

Start the authentication flow by redirecting the user to the login page.

=cut

sub login : Chained('provider') PathPart('login') Args(0) {
    my ( $self, $c ) = @_;

    # Use this template if we encounter an error
    $c->stash->{template} = "/authenticate/oidc/error.mas";

    try {
        # Parse the name of the provider from the URL path
        my $provider = $c->stash->{provider};
        # Read the provider configuration
        my $config = $c->get_conf('oidc_client')->{$provider};

        # ---------------------------------------------------------------------
        # Client-Side Secrets

        # State will later be a check on the providers side, to verify that
        # the requests legitmately came from us
        my ($state_verifier, $state) = generate_secret();
        set_cookie(
            $provider . "_state_verifier",
            $state_verifier,
            "/authenticate/oidc/$provider"
        );

        # What is nonce for? Google?
        my ($nonce_verifier, $nonce) = generate_secret();
        set_cookie(
            $provider . "_nonce_verifier",
            $nonce_verifier,
            "/authenticate/oidc/$provider"
        );

        # ---------------------------------------------------------------------
        # Universal Provider Parameters

        # Fetch the .well-known JSON configuration
        my $well_known = fetch_json($config->{well_known_url});
        my ($error, $error_description) = (
            $well_known->{error},
            $well_known->{error_description}
        );
        if ($error) {
            $c->stash->{error} = "$error\n$error_description";
            return
        }

        my $params = {
            client_id     => $config->{client_id},
            redirect_uri  => $c->uri_for("/authenticate/oidc/$provider/callback"),
            scope         => 'openid email profile',
            response_type => 'code',
            audience      => $config->{client_id},
            state         => $state,
            nonce         => $nonce,
        };

        # ---------------------------------------------------------------------
        # Provider-Specific Parameters

        # PKCE Code Challenge (Keycloak) = 'plain' or 'S256'
        my $code_challenge_method = $config->{code_challenge_method};
        if ($code_challenge_method) {
            my ($code_challenge, $code_encoded) = generate_secret();
            set_cookie(
                $provider . "_code_verifier",
                $code_challenge,
                "/authenticate/oidc/$provider"
            );
            if ($code_challenge_method eq 'S256') {
                $code_challenge = $code_encoded;
            }
            $params->{code_challenge} = $code_challenge;
            $params->{code_challenge_method} = $code_challenge_method;
        }

        # ---------------------------------------------------------------------
        # Redirect the user to the provider's login page

        my $auth_url = URI->new($well_known->{authorization_endpoint});
        $auth_url->query_form(%$params);
        $c->res->redirect( $auth_url );

    } catch {
	    $c->stash->{error} = $_;
    }
}

=head2 callback

After a successful authentication in the provider's login page, redirects the
user back to this url, with the temporary authorization code available to
exchange for a full access token.

This endpoint should never be called manually, as the URL params needs to
be constructed by, and sent from, the third party provider (ex. Google).

1. Exchange the temporary authorization code for a full access token.
2. Use the access token to request user information (ex. email, name, etc.)
3. Check if the user already exists in the breedbase system.
4. If the user doesn't exist, check if the config specified to 'auto_provision'
   a.k.a Automatically create new users. If so, creates a new user account.
5. If the user exists, log them in.

=cut

sub callback : Chained('provider') PathPart('callback') Args(0) {
    my ( $self, $c ) = @_;

    # Use this template in case of errors
    $c->stash->{template} = '/authenticate/oidc/error.mas';

    try {
        # Parse the name of the provider from the URL path
        my $provider = $c->stash->{provider};
        # Read the provider configuration
        my $config = $c->get_conf('oidc_client')->{$provider};

        # ---------------------------------------------------------------------
        # Error handling and state verification

        # Check for errors in the callback URL params
        my $error = $c->req->param("error");
        my $error_description = $c->req->param("error_description");
        if ($error) {
            $c->stash->{error} = "$error\n\n$error_description";
            return
        }

        # Check that the state is correct
        my $state_verifier = $c->request->cookies->{$provider . "_state_verifier"};
        if (! defined $state_verifier ) {
            $c->stash->{error} = (
                "The state verifiers could not be found." .
                "\n\nPlease try to login again, or contact your system administrator."
            );
            return
        } else {
            $state_verifier = $state_verifier->value;
        }
        my $state_expected = urlsafe_b64encode(sha256($state_verifier));
        my $state_observed = $c->req->param("state");
        if ($state_expected ne $state_observed) {
            $c->stash->{error} = (
                "The state returned by the provider does not match the initiating state." .
                "\n\nPlease try to login again, or contact your system administrator for more help."
            );
            return
        }

        # ---------------------------------------------------------------------
        # 1. Exchange Temporary Authorization Code for Access Token

        # Fetch the .well-known configuration
        my $well_known = fetch_json($config->{well_known_url});
        my ($error, $error_description) = (
            $well_known->{error},
            $well_known->{error_description}
        );
        if ($error) {
            $c->stash->{error} = "$error\n$error_description";
            return
        }

        # Fetch the certificates for verifying token signatures
        # This is how we know they legitimately came from the provider
        my $certs = fetch_json($well_known->{jwks_uri});
        my ($error, $error_description) = (
            $certs->{error},
            $certs->{error_description}
        );
        if ($error) {
            $c->stash->{error} = "$error\n$error_description";
            return
        }

        # Universal Provider Parameters
        my $form = {
            code          => $c->req->param("code"),
            grant_type    => 'authorization_code',
            client_id     => $config->{client_id},
            client_secret => $config->{client_secret},
            redirect_uri  => $c->uri_for("/authenticate/oidc/$provider/callback"),
        };

        # Provider-Specific Parameter
        my $code_verifier = $c->request->cookies->{$provider . "_code_verifier"};
        if ( $code_verifier ) {
            $form->{code_verifier} = $code_verifier->value;
        }

        # Request the access token
        my $ua = LWP::UserAgent->new();
        my $response = $ua->post($well_known->{token_endpoint}, $form);
        my $content = decode_json $response->{_content};
        ($error, $error_description) = (
            $content->{error},
            $content->{error_description}
        );

        if ($error) {
            $c->stash->{error} = "$error\n$error_description";
            return
        }

        # Extract the tokens
        my $access_token = $content->{access_token};
        my $id_token = $content->{id_token};

        # Per the OpenID Connect Core Standards, the ID Token is required to
        # be in JWT format, the Access Token has no constraint. Keycloak
        # will provide access token as JWT, Google will not.
        # Because of this, we only verify the signature of the ID token
        # https://openid.net/specs/openid-connect-core-1_0.html#TokenResponse
        # If the signature is invalid, jecode_jwt will raise an error
        decode_jwt(token => $id_token, kid_keys => $certs);

        # ---------------------------------------------------------------------
        # 2. Use The Access Token To Request User Information

        my $response = $ua->get(
            $well_known->{userinfo_endpoint},
            "Authorization" => "Bearer $access_token"
        );
        my $userinfo = decode_json $response->{_content};
        ($error, $error_description) = (
            $userinfo->{error},
            $userinfo->{error_description}
        );
        if ($error) {
            $c->stash->{error} = "$error\n\n$error_description";
            return
        }

        my $first_name = $userinfo->{given_name};
        my $last_name  = $userinfo->{family_name};
        my $email      = $userinfo->{email};
        my $username   = $userinfo->{preferred_username};

        # If the provider doesn't have username, parse it from the email address
        if (! $username){
            my @email_split = split(/@/, $email);
            $username = $email_split[0];
        }

        if (! $userinfo->{email_verified}) {
            $c->stash->{error} = (
                "Your email is not verified with the external provider." .
                "\n\nPlease verify your email with $provider first."
            );
            return
        }

        # ---------------------------------------------------------------------
        # 3. Check if the User Exists in the System

        # Require match of private_email or pending_email (set at user account creation)
        my $schema = $c->dbic_schema("Bio::Chado::Schema");
        my $q = "
        SELECT sp_person_id, user_prefs
        FROM sgn_people.sp_person
        WHERE UPPER(private_email)=UPPER(?) OR UPPER(pending_email)=UPPER(?)";
        my $h = $schema->storage->dbh()->prepare($q);
        my $num_rows = $h->execute($email, $email);
        my ($person_id, $user_prefs) = $h->fetchrow_array();

        # Uh oh, too many matches (not sure if this is even possible)
        if ( $num_rows > 1 ) {
            $c->stash->{error} = (
                "Multiple users were found to have the email: '$email'." .
                "\n\nPlease contact your system administrator for more help."
            );
            return;
        }

        # ---------------------------------------------------------------------
        # 4. Auto-provision

        if (! defined $person_id ) {

            # Make extra sure that this email is not in a pending state for
            # another account, or is the contact email for someone else
            my $q = "
            SELECT username
            FROM sgn_people.sp_person
            WHERE UPPER(contact_email)=UPPER(?) OR UPPER(pending_email)=UPPER(?)";

            my $h = $schema->storage->dbh()->prepare($q);
            my $num_rows = $h->execute($email, $email);
            my ($other_username) = $h->fetchrow_array();
            if ( $num_rows > 0 ) {
                $c->stash->{error} = (
                    "The provided email '$email' is associated with a different user '$other_username'." .
                    "\n\nPlease contact your system administrator for more help."
                );
                return;
            }


            # Not auto-provision, raise error
            if (! $config->{auto_provision}) {
                $c->stash->{error} = (
                    "No system user was found with the email '$email'." .
                    "\n\nIf you have not yet registered for an account, please do so first." .
                    "\nOtherwise, please contact your system administrator."
                );
                return;
            }

            # ---------------------------------------------------------------------
            # 4. Auto-provision

            # Check for mirror site status
            if ($c->config->{is_mirror}) {
                $c->stash->{error} = (
                    "This site is a mirror site and does not support adding users." .
                    "\n\nPlease go to the main site to create an account."
                );
                return;
            }

            # breedbase specific requirements for username composition
            if (length($username) < 7) {
                $c->stash->{error} = (
                    "The username '$username' is too short." .
                    "\n\nUsername must be 7 or more characters."
                );
                return
            } elsif ( $username =~ /\s/ ) {
                $c->stash->{error} = "The username '$username' contains spaces.";
                return
            }

            # generate random password. if the user laters wants to use the
            # 'native' login, they will need to request a password reset
            my $password  = random_string(40);

            # Create a new user
            my $new_user = CXGN::People::Login->new($c->dbc->dbh());
            $new_user->set_username($username);
            $new_user->set_password($password);
            $new_user->set_private_email($email);
            $new_user->store();

            # Create a new person
            $person_id  = $new_user->get_sp_person_id();
            my $new_person = CXGN::People::Person->new($c->dbc->dbh(), $person_id);
            $new_person->set_first_name($first_name);
            $new_person->set_last_name($last_name);
            $new_person->store();
        }

        # ---------------------------------------------------------------------
        # Log the user in

        my $login             = CXGN::Login->new($c->dbc->dbh());
        my $new_cookie_string = random_string_from('abcdefghijklmnopqrstuvwxyz', 71);
        my $sth               = $login->get_sql("login");
        $sth->execute( $new_cookie_string, $person_id );

        CXGN::Cookie::set_cookie( $LOGIN_COOKIE_NAME, $new_cookie_string );
        CXGN::Cookie::set_cookie( "user_prefs", $user_prefs );
        $c->response->redirect($c->req->base);

    } catch {
        $c->stash->{error} = $_;
    }

}

# A randomly generated and SHA256 encrypted string
sub generate_secret {
    my $verifier = urlsafe_b64encode(random_string(40));
    my $encoded  = urlsafe_b64encode(sha256($verifier));
    return ($verifier, $encoded);
}

# A short lived cookie that can cross site boundaries
# For more information:
# https://stackoverflow.com/questions/42216700/how-can-i-redirect-after-oauth2-with-samesite-strict-and-still-get-my-cookies#comment130813959_42220786
sub set_cookie {
    my ($name, $value, $path) = @_;
    $c->response->cookies->{$name} = {
        value    => $value,
        path     => $path,
        samesite => 'Lax',
        httponly => 1,
        secure   => 1,
        expires  => '+5m',
    };
}

# Fetch the OIDC .well-known configuration
sub fetch_json {
    my ($url) = @_;
    my $ua = LWP::UserAgent->new();
    my $response = $ua->get($url);
    my $content = decode_json $response->{_content};
    return $content
}

1;
