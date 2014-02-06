
package SGN::Controller::Cvterm;

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
    $c->stash->{cvterm} = $cvterm;
}

1;
