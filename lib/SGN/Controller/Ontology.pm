
package SGN::Controller::Ontology;

use CXGN::Chado::Cvterm;
use CXGN::People::Roles;
use URI::FromHash 'uri';

use Moose;

BEGIN { extends 'Catalyst::Controller' };
with 'Catalyst::Component::ApplicationAttribute';


sub onto_browser : Path('/tools/onto') :Args(0) {
    my $self = shift;
    my $c = shift;

    my $root_nodes = $c->config->{onto_root_namespaces};
    my @namespaces = split ",", $root_nodes;
    foreach my $n (@namespaces) {
	$n =~ s/\s*(\w+)\s*\(.*\)/$1/g;
	print STDERR "Adding node $n\n";
    }
    #$c->stash->{root_nodes} = $c->req->param("root_nodes");
    $c->stash->{root_nodes} = join " ", @namespaces;
    $c->stash->{db_name} = $c->req->param("db_name");
    $c->stash->{expand} = $c->req->param("expand");

    $c->stash->{template} = '/ontology/standalone.mas';

}

sub compose_trait : Path('/tools/compose') :Args(0) {
    my $self = shift;
    my $c = shift;

    if (!$c->user()) {
      # redirect to login page
      $c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) );
      return;
    }

    $c->stash->{entity_namespaces} = $c->config->{entity_namespaces};
    $c->stash->{quality_namespaces} = $c->config->{quality_namespaces};
    $c->stash->{unit_namespaces} = $c->config->{unit_namespaces};
    $c->stash->{time_namespaces} = $c->config->{time_namespaces};

    $c->stash->{user} = $c->user();
    $c->stash->{template} = '/ontology/compose_trait.mas';

}

1;
