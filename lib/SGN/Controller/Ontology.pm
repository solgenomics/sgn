
package SGN::Controller::Ontology;

use Moose;

BEGIN { extends 'Catalyst::Controller' };



sub cvterm_detail :Path('/chado/cvterm') :Args(0) { 
    my $self = shift;
    my $c = shift;

    my $cvterm_id = $c->req->param("cvterm_id");
    my $cvterm_name = $c->req->param("cvterm_name");

    my $cvterm;

    if ( $cvterm_name  ) {
	$cvterm = CXGN::Chado::Cvterm->new_with_accession( $c->dbc->dbh, $cvterm_name);
	$cvterm_id = $cvterm->get_cvterm_id();
    } elsif ( $cvterm_id  ) {
	$cvterm = CXGN::Chado::Cvterm->new( $c->dbc->dbh, $cvterm_id );
    }

    unless ( $cvterm_id && $cvterm_id =~ m /^\d+$/ ) {
	$c->throw( is_client_error => 1, public_message => 'Invalid arguments' );
    }
    $c->stash->{template} = '/chado/cvterm.mas';
    $c->stash->{cvterm}   =  $cvterm;
}

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

1;
