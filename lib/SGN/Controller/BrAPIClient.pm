
package SGN::Controller::BrAPIClient;

use Moose;
use URI::FromHash 'uri';

BEGIN { extends 'Catalyst::Controller' };

sub authorize_client :Path('/brapi/authorize') QueryParam('return_url') { #breedbase.org/brapi/authorize?success_url=fieldbook://&display_name=Field%20Book
    my $self = shift;
    my $c = shift;
    my %authorized_clients = (
        'fieldbook://' => 'FieldBook App',
        'https://apps.cipotato.org/hidap_sbase/' => 'HIDAP'
    );

    my $return_url = $c->request->param( 'return_url' );
	my @keys = keys %authorized_clients;
	my $display_name = undef;

	while(my($k, $v) = each %authorized_clients) {
        if ($return_url =~ m/^$k/) {
            $display_name = $v;
            last;
        }
    }

    if (defined $display_name) {
        if (!$c->user()) {  # redirect to login page
            $c->res->redirect( uri( path => '/user/login', query => { goto_url => "/brapi/authorize?return_url=$return_url" } ) );
            return;
        } else {
            my $user_name = $c->user()->get_object()->get_username();
            my $token = CXGN::Login->new($c->dbc->dbh)->get_login_cookie();
            my $authorize_url = $return_url . "?status=200&token=" . $token;
            my $deny_url = $return_url . "?status=401";
            $c->stash->{authorize_url} = $authorize_url;
            $c->stash->{deny_url} = $deny_url;
            $c->stash->{user_name} = $user_name;
            $c->stash->{display_name} = $display_name;
            $c->stash->{database_name} = $c->config->{project_name};
            $c->stash->{template} = '/brapi/authorize.mas';
        }
    } else {
        $c->throw_404("No authorized client found with return url $return_url. If you are an app developer please contact the BreedBase development team to become an authorized client.");
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
