
package SGN::Controller::Cvterm;

#use CXGN::Chado::Cvterm; #DEPRECATE this !! 
use CXGN::Cvterm;
use URI::FromHash 'uri';
use Data::Dumper;

use Moose;

BEGIN { extends 'Catalyst::Controller' };
with 'Catalyst::Component::ApplicationAttribute';

has 'schema' => (
    is       => 'rw',
    isa      => 'DBIx::Class::Schema',
    lazy_build => 1,
);
sub _build_schema {
    shift->_app->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado' )
}


=head2 view_cvterm

Public path: /cvterm/<cvterm_id>/view

View a cvterm detail page.

Chained off of L</get_cvterm> below.

=cut

sub view_cvterm : Chained('get_cvterm') PathPart('view') Args(0) {
    my ( $self, $c, $action) = @_;
    my $cvterm = $c->stash->{cvterm};
    my $cvterm_id = $cvterm ? $cvterm->cvterm_id : undef ;

    my $bcs_cvterm = $cvterm->cvterm;

    my ($person_id, $user_role, $curator, $submitter, $sequencer);
    my $logged_user = $c->user;
    $person_id = $logged_user->get_object->get_sp_person_id if $logged_user;
    $user_role = 1 if $logged_user;
    $curator   =  $c->stash->{access}->grant( $c->stash->{user_id}, "write", "ontologies");#$logged_user->check_roles('curator') if $logged_user;
    $submitter =  $c->stash->{access}->grant( $c->stash->{user_id}, "read", "ontologies"); #$logged_user->check_roles('submitter') if $logged_user;
    $sequencer =  0; #$logged_user->check_roles('sequencer') if $logged_user;
    my $props = $self->_cvtermprops($cvterm);
    my $editable_cvterm_props = "trait_format,trait_default_value,trait_minimum,trait_maximum,trait_details,trait_categories,trait_repeat_type";
   
    
    $c->stash(
	template => '/chado/cvterm.mas',
	cvterm   => $cvterm, #deprecate this maybe? 
	cvtermref => {
	    cvterm    => $bcs_cvterm,
	    curator   => $curator,
            submitter => $submitter,
            sequencer => $sequencer,
            person_id => $person_id,
	    props     => $props,
	    editable_cvterm_props => $editable_cvterm_props,
	}
	);
    
}


=head2 get_cvterm

Chain root for fetching a cvterm object to operate on.

Path part: /cvterm/<cvterm_id>

=cut

sub get_cvterm : Chained('/')  PathPart('cvterm')  CaptureArgs(1) {
    my ($self, $c, $cvterm_id) = @_;

    print STDERR "GET CVTERM $cvterm_id...\n";
    if (!$c->user()) {
      # redirect to login page
      $c->res->redirect( uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
      $c->detach();
    }

    if (my $message = $c->stash->{access}->denied($c->stash->{user_id}, "read", "ontologies")) {
	$c->stash->{template} = '/access/access_denied.mas';
        $c->stash->{data_type} = 'ontology';
        $c->stash->{message} = $message;
        $c->detach();
    }

    my $identifier_type = $c->stash->{identifier_type}
        || $cvterm_id =~ /[^-\d]/ ? 'accession' : 'cvterm_id';
    
    my $cvterm;
    if( $identifier_type eq 'cvterm_id' ) {
	$cvterm = CXGN::Cvterm->new({ schema=>$self->schema, cvterm_id => $cvterm_id } );
    } elsif ( $identifier_type eq 'accession' )  {
	$cvterm = CXGN::Cvterm->new({ schema=>$self->schema, accession=>$cvterm_id } ) ;
    }
    my $found_cvterm = $cvterm->cvterm 
	or $c->throw_404( "Cvterm $cvterm_id not found" );
    
    $c->stash->{cvterm}     = $cvterm; 
    
    return 1;
}



sub _cvtermprops {
    my ($self,$cvterm) = @_;

    my $properties ;
    if ($cvterm) {
	my $bcs_cvterm = $cvterm->cvterm;
	if (!$bcs_cvterm) { return; } 
        my $cvtermprops = $bcs_cvterm->search_related("cvtermprops");
        while ( my $prop =  $cvtermprops->next ) {
            push @{ $properties->{$prop->type->name} } ,   $prop->value ;
        }
    }
    return $properties;
}
####
1;##
####
