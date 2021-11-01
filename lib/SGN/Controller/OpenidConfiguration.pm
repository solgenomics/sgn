
package SGN::Controller::OpenidConfiguration;

use File::Slurp;
use Moose;

BEGIN { extends "Catalyst::Controller"; }



sub openid_configuration : Path('/.well-known/openid-configuration') Args(0) {
    my $self = shift;
    my $c = shift;

    my $json = read_file($c->get_conf('basepath') . '/static/documents/openid-configuration.json');
    my $site = $c->config->{main_production_site_url};
    $json =~ s/\<\% \$site \%>/$site/; 
    $c->res->content_type("application/json");
    $c->res->body($json);
}


1;
