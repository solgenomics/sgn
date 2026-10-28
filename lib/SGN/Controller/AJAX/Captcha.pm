
package SGN::Controller::AJAX::Captcha;

use Data::Dumper;
use Moose;
use LWP::UserAgent;
use HTTP::Request;
use JSON;
use Digest::SHA qw(hmac_sha256_base64);

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
);

#
# Verify a Captcha Token
# - Check if the provided token is valid with the captcha server
# - If the token is valid, sign it and return it in a cookie
# The cookie will be used to verify future requests
#
sub captcha : Path("/ajax/captcha") Args(0) {
    my $self = shift;
    my $c = shift;
    my $token = $c->req->param("token");
    my $config = $c->config->{captcha};
    my $ua = LWP::UserAgent->new;

    # Reset the cookie
    CXGN::Cookie::set_cookie('captcha-token', "");

    # Check the captcha config
    if ( !defined $config || !defined $config->{server} || !defined $config->{client_id} || !defined $config->{client_secret} || !defined $config->{signing_key} ) {
        $c->stash->{rest} = { error => 'Missing server captcha config' };
        return;
    }

    # Check the token with the server
    my $data = encode_json({
        secret => $config->{client_secret},
        response => $token
    });
    my $req = HTTP::Request->new(POST => $config->{server} . "/siteverify");
    $req->header('Content-Type' => 'application/json');
    $req->content($data);
    my $response = $ua->request($req);
    my $response_data = decode_json($response->content);

    # The server did not verify the token
    if ( !$response->is_success || !$response_data->{success} ) {
        $c->stash->{rest} = { error => $response_data->{error} || $response->status_line };
        return;
    }

    # Sign the token with the signing key
    my $signature = hmac_sha256_base64($token, $config->{signing_key});

    # Save the token and its signature in a cookie
    CXGN::Cookie::set_cookie('captcha-token', "$token:$signature");

    $c->stash->{rest} = { success => 1 };
}