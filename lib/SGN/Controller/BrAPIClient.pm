
package SGN::Controller::BrAPIClient;

use Moose;
use URI::FromHash 'uri';
use JSON;

BEGIN { extends 'Catalyst::Controller' };

sub authorize_client :Path('/brapi/authorize') QueryParam('redirect_uri') { #breedbase.org/brapi/authorize?success_url=fieldbook://&client_id=Field%20Book
    my $self = shift;
    my $c = shift;
        
    my $authorized_clients = decode_json $c->get_conf('authorized_clients_JSON');;
    
	my %authorized_clients = %$authorized_clients;
	
    my $redirect_uri = $c->request->param( 'redirect_uri' );
	my @keys = keys %authorized_clients;
	my $client_id = undef;

	while(my($k, $v) = each %authorized_clients) {
        if ($redirect_uri =~ m/^$k/) {
            $client_id = $v;
            last;
        }
    }

    if (defined $client_id) {
        if (!$c->user()) {  # redirect to login page
            $c->res->redirect( uri( path => '/user/login', query => { goto_url => "/brapi/authorize?redirect_uri=$redirect_uri" } ) );
            return;
        } else {
            my $user_name = $c->user()->get_object()->get_username();
            my $access_token = CXGN::Login->new($c->dbc->dbh)->get_login_cookie();
            my $authorize_url = $redirect_uri . ( (index($redirect_uri, '?') != -1)?"&status=200&access_token=":"?status=200&access_token=") . $access_token;
            my $deny_url = $redirect_uri . "?status=401";
            $c->stash->{authorize_url} = $authorize_url;
            $c->stash->{deny_url} = $deny_url;
            $c->stash->{user_name} = $user_name;
            $c->stash->{client_id} = $client_id;
            $c->stash->{database_name} = $c->config->{project_name};
            $c->stash->{template} = '/brapi/authorize.mas';
        }
    } else {
        $c->throw_404("No authorized client found with return url $redirect_uri. If you are an app developer please contact the BreedBase development team to become an authorized client.");
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
