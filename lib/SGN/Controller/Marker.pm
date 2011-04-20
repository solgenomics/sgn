=head1 NAME

SGN::Controller::Marker - controller for marker-related stuff

=cut

package SGN::Controller::Marker;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

use File::Spec::Functions;


=head1 PUBLIC ACTIONS

=head2 view_rflp_image

Public path: /marker/<marker_id>/rflp_image/view

=cut

sub view_rflp_image: Chained('get_marker') PathPart('rflp_image/view') :Args(0) {
  my ( $self, $c, ) = @_;

  my $image_size = $c->req->query_parameters->{size};

  my $image_location = $self->rflp_image_link( $c, $c->stash->{marker} )
      or $c->throw_404( "RFLP image not found for SGN-M".$c->stash->{marker}->marker_id );

  $c->stash(
      template => '/markers/view_rflp.mas',

      image_location => $image_location,
      image_size     => $image_size
     );
}


=head2 marker_details

Public path: /marker/SGN-M23545/details

Show the HTML detail page for this marker.

=cut


sub marker_details: Chained('get_marker') PathPart('details') :Args(0) {
  my ( $self, $c ) = @_;

  $c->stash(
      template  => '/markers/index.mas',
      dbh       => $c->dbc->dbh,
     );
}


=head2 get_marker

Public path: /marker/SGN-M23545

Chaining base for fetching the marker indicated by the given marker
id.  The marker ID is an SGN-M identifier.

=cut


sub get_marker: Chained('/') PathPart('marker') :CaptureArgs(1) {
    my ( $self, $c, $marker_id ) = @_;

    ($marker_id) = $marker_id =~ /^SGN-M(\d+)$/i
        and $c->stash->{marker} = CXGN::Marker->new( $c->dbc->dbh, $marker_id)
        or $c->throw_404('No marker found with that ID');

    $c->stash->{marker_id} = $marker_id;
}


############ helper methods ########

# Returns the stuff that goes in the 'href' attribute of the 'a' tag for
# an RFLP image, or undef if there is no image.

# =cut

sub rflp_image_link {
    my ( $class, $c, $marker ) = @_;
    my $marker_name = uc $marker->name_that_marker();
    my ( $dir ) = $marker_name =~ /^(CD|CT|PC|PG|TG|PCD2)/
	or return;

    my $source = catfile( $c->get_conf('image_path'), 'rflp', $dir, "$marker_name.jpg" );

    return unless -f $source;

    return catfile( $c->get_conf('static_datasets_url'), 'images','rflp', $dir, "$marker_name.jpg" );
}


1;
