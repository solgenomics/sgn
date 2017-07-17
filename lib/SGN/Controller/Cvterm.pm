
package SGN::Controller::Cvterm;

use CXGN::Chado::Cvterm;

use Moose;

BEGIN { extends 'Catalyst::Controller' };
with 'Catalyst::Component::ApplicationAttribute';


=head2 view_cvterm

Public path: /cvterm/<cvterm_id>/view

View a cvterm detail page.

Chained off of L</get_cvterm> below.

=cut

sub view_cvterm : Chained('get_cvterm') PathPart('view') Args(0) {
    my ( $self, $c, $action) = @_;
    my $cvterm = $c->stash->{cvterm};
    
    $c->stash(
	template => '/chado/cvterm.mas',
	cvterm   => $cvterm,
	);
    
}


=head2 get_cvterm

Chain root for fetching a cvterm object to operate on.

Path part: /cvterm/<cvterm_id>

=cut

sub get_cvterm : Chained('/')  PathPart('cvterm')  CaptureArgs(1) {
    my ($self, $c, $cvterm_id) = @_;

    my $identifier_type = $c->stash->{identifier_type}
        || $cvterm_id =~ /[^-\d]/ ? 'accession' : 'cvterm_id';
    
    my $cvterm;
    if( $identifier_type eq 'cvterm_id' ) {
	$cvterm = CXGN::Chado::Cvterm->new($c->dbc->dbh, $cvterm_id);
    } elsif ( $identifier_type eq 'accession' )  {
	$cvterm = CXGN::Chado::Cvterm->new_with_accession ($c->dbc->dbh , $cvterm_id) ;
    }
    my $found_cvterm_id = $cvterm->get_cvterm_id
	or $c->throw_404( "Cvterm not found" );
       
    $c->stash->{cvterm}     = CXGN::Chado::Cvterm->new($c->dbc->dbh, $found_cvterm_id);

    return 1;
}


1;
