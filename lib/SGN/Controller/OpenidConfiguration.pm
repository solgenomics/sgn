
package SGN::Controller::OpenidConfiguration;

use Moose;

BEGIN { extends "Catalyst::Controller"; }



sub openid_configuration : Path('/.well-known/openid-configuration') Args(0) { 
    my $self = shift;
    my $c = shift;

    $c->stash->{site} =  $c->config->{main_production_site_url};
    $c->stash->{template} = '/well-known/openid-configuration.txt';
}


1;
