package SGN::Authentication::Captcha;

=head1 NAME

SGN::Authentication::Captcha - when enabled in the configuration, check all requests to HTML pages for a proper verification token cookie

=head1 DESCRIPTION

To enable this feature, the captcha settings (server, client_id, client_secret, signing_key) must be defined in the sgn config.

This Catalyst plugin will intercept all requests that return an HTML response and check for a valid signed captcha token in the request's cookies.

If the token is not found or not valid, the request will be redirected to the /captcha page where a captcha routine will be initiated.  If the 
captcha routine passes, the captcha token will be set and signed and the user will be redirected back to the originally requested page.

This is designed to use the Cap self-hosted Captcha server (https://trycap.dev/).  An example docker-compose.yml file to run the server can be 
found at ./conf/captcha.docker-compose.yml in this repo.

Author: David Waring <djw64@cornell.edu>

=cut

use Moose::Role;
use URI::FromHash 'uri';
use Digest::SHA qw(hmac_sha256_base64);
use Data::Dumper;

around 'finalize' => sub {
    my ($orig, $c, @args) = @_;
    my $path = $c->req->path;
    my $content_type = $c->res->content_type;

    # Verify access to HTML pages (except the /captcha page itself)
    if ( $content_type eq 'text/html' && $path ne 'captcha' ) {

        # Get the captcha config
        my $config = $c->config->{'captcha'};

        # Check for captcha token, only if the settings are enabled
        if ( defined $config && defined $config->{server} && defined $config->{client_id} && defined $config->{client_secret} && defined $config->{signing_key} ) {
            my $cookies = $c->req->cookies;
            my $cookie = $cookies->{'captcha-token'};
            my $cookie_value = $cookie ? $cookie->value : undef;
            my $query_value = $c->req->param('captcha-token');
            my $check_value = $query_value || $cookie_value;

            # If token is not provided, redirect to captcha page
            if ( !defined $check_value || $check_value eq '' ) {
                $c->res->redirect( uri( path => '/captcha', query => { goto_url => $c->req->uri->path_query } ) );
            }

            # If the token is provided, verify its signature
            else {

                # Get the token and signature from the value
                my @parts = split(':', $check_value);
                my $c_token = join(':', @parts[0..2]);
                my $c_signature = $parts[3];

                # Get the true signature to compare to the one in the value
                my $t_signature = hmac_sha256_base64($c_token, $config->{signing_key});

                # value signature check fails, redirect to captcha page
                if ( !defined $c_signature || !defined $t_signature || $c_signature ne $t_signature ) {
                    $c->res->redirect( uri( path => '/captcha', query => { goto_url => $c->req->uri->path_query } ) );
                }

                # If the token is sent as a query param, save it as a cookie for future requests
                if ( defined $query_value ) {
                    CXGN::Cookie::set_cookie('captcha-token', $query_value);
                }

            }
        }

    }

    my $rtn = $orig->($c, @args);
    return $rtn;
};

1;
