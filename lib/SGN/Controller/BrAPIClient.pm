
package SGN::Controller::BrAPIClient;

use Moose;
use URI::FromHash 'uri';
use URI::Escape qw(uri_escape);
use HTML::Entities qw(encode_entities);
use JSON;

BEGIN { extends 'Catalyst::Controller' };

# True if $redirect_uri starts with the configured client url. The configured
# url is compared as a literal string, not as a regex, and it has to end at a
# url boundary ('/', '?', '#', the end of the string, or a configured url that
# ends with '/'), so "https://example.org" accepts "https://example.org/cb" but
# not "https://example.org.attacker.net/" or "https://example.org@attacker.net/".
# Dot segments, backslashes, whitespace and control characters, which browsers
# may use to leave the configured host or path, are rejected.
sub _redirect_uri_matches {
    my $redirect_uri = shift;
    my $client_url = shift;

    return 0 if !defined($redirect_uri) || ref($redirect_uri) || !length($client_url);
    return 0 if $redirect_uri =~ m/[\x00-\x20\x7f\\]/;
    return 0 if index($redirect_uri, $client_url) != 0;

    my $rest = substr($redirect_uri, length($client_url));
    return 0 unless $client_url =~ m{/$} || $rest eq '' || $rest =~ m{^[/?#]};

    my ($path) = $rest =~ m{^([^?#]*)};
    return 0 if $path =~ m{(^|/)(\.|%2e){1,2}(/|$)}i;

    return 1;
}

sub authorize_client :Path('/brapi/authorize') QueryParam('redirect_uri') { #breedbase.org/brapi/authorize?success_url=fieldbook://&client_id=Field%20Book
    my $self = shift;
    my $c = shift;
    $c->response->headers->header( "Access-Control-Allow-Origin" => '*' );
	$c->response->headers->header( "Access-Control-Allow-Methods" => "POST, GET, PUT, DELETE" );
	$c->response->headers->header( 'Access-Control-Allow-Headers' => 'DNT,X-CustomHeader,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Content-Range,Range,Authorization');
    # the consent page contains the user's session token
    $c->response->headers->header( 'Cache-Control' => 'no-store' );
    $c->response->headers->header( 'Referrer-Policy' => 'no-referrer' );
    my $authorized_clients = decode_json $c->get_conf('authorized_clients_JSON');

	my %authorized_clients = %$authorized_clients;

    my $redirect_uri = $c->request->param( 'redirect_uri' );
	my $client_id = undef;
	# longest url first, so that overlapping entries always resolve to the same client
	foreach my $k (sort { length($b) <=> length($a) || $a cmp $b } keys %authorized_clients) {
        if (_redirect_uri_matches($redirect_uri, $k)) {
            $client_id = $authorized_clients{$k};
            last;
        }
    }
    if (defined $client_id) {
        if (!$c->user()) {  # redirect to login page
            my $goto_url = uri( path => '/brapi/authorize', query => { redirect_uri => $redirect_uri } );
            $c->res->redirect( uri( path => '/user/login', query => { goto_url => $goto_url } ) );
            return;
        } else {
            my $user_name = $c->user()->get_object()->get_username();
            my $user_id = $c->user()->get_object()->get_sp_person_id();
            my $first_name = $c->user()->get_object()->get_first_name();
            my $last_name = $c->user()->get_object()->get_last_name();
            my $access_token = CXGN::Login->new($c->dbc->dbh)->get_login_cookie();
            my $separator = (index($redirect_uri, '?') != -1) ? '&' : '?';
            my $authorize_url = $redirect_uri . $separator . "status=200&access_token=" . uri_escape($access_token);
            my $deny_url = $redirect_uri . $separator . "status=401";
            $c->stash->{authorize_url} = $authorize_url;
            $c->stash->{deny_url} = $deny_url;
            $c->stash->{user_name} = $user_name;
            $c->stash->{user_id} = $user_id;
            $c->stash->{first_name} = $first_name;
            $c->stash->{last_name} = $last_name;
            $c->stash->{client_id} = $client_id;
            $c->stash->{database_name} = $c->config->{project_name};
            $c->stash->{template} = '/brapi/authorize.mas';
            return;
        }
    } else {
        $c->throw_404("No authorized client found with return url ".encode_entities($redirect_uri // '').". If you are an app developer please contact the BreedBase development team to become an authorized client.");
    }

}

sub home : Path('/brapihome/') Args(0) {
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = 'brapiclient/home.mas';
}

sub germplasm : Path('/brapihome/germplasm') Args(0) {
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = 'brapiclient/germplasm_search.mas';
}

sub phenotyping_handhelds : Path('/brapihome/phenotyping_handhelds') Args(0) {
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = 'brapiclient/phenotyping_handhelds.mas';
}

sub phenotype : Path('/brapihome/phenotype') Args(0) {
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = 'brapiclient/phenotypes_search.mas';
}

sub genotype : Path('/brapihome/genotype') Args(0) {
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = 'brapiclient/markerprofile_allelematrix.mas';
}

sub index : Path('/brapiclient/comparegenotypes') Args(0) {
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = 'brapiclient/comparegenotypes.mas';
}

1;
