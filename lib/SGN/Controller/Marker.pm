=head1 NAME

SGN::Controller::Marker - controller for marker-related stuff

=cut

package SGN::Controller::Marker;
use Moose;
use namespace::autoclean;
use CXGN::Marker::Search;

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


=head2 view_by_name 

Public Path: /marker/view_by_name/$name

Path Params:
    name = marker unique name

Search for the marker that matches the provided marker name.
If 1 match is found, display the marker detail page.  Display an 
error message if no matches are found.

=cut

sub view_marker_by_name :Path('/marker/view_by_name') CaptureArgs(1) {
    my ($self, $c, $marker_query) = @_;
    $self->search_marker($c, $marker_query);
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


sub search_marker : Private {
    my ( $self, $c, $marker_query ) = @_;
    my $dbh = $c->dbc->dbh();
    
    my $msearch = CXGN::Marker::Search->new($dbh);
    $msearch->name_like($marker_query);
    $msearch->perform_search();
    my @marker_ids = $msearch->fetch_id_list();

    my @filtered_marker_ids = _uniq(@marker_ids);
    my $count = scalar @filtered_marker_ids;

    
    # NO MATCH FOUND
    if ( $count == 0 ) {
        $c->stash->{template} = "generic_message.mas";
        $c->stash->{message} = "<strong>No Matching Marker Found</strong> ($marker_query)<br />You can view and search for markers from the <a href='/search/markers'>Marker Search Page</a>";
    }

    # MULTIPLE MATCHES FOUND
    elsif ( $count > 1 ) {
        my @marker_objs = $msearch->fetch_full_markers();
        my $list = "<ul>";
        foreach (@marker_objs) {
            my $marker_id = $_->marker_id();
            my $marker_name = $_->name_that_marker();
            my $url = "/search/markers/markerinfo.pl?marker_id=$marker_id";
            $list .= "<li><a href='$url'>$marker_name</a></li>";
        }
        $list .= "</ul>";
        $c->stash->{template} = "generic_message.mas";
        $c->stash->{message} = "<strong>Multiple Markers Found</strong><br />" . $list;
    }

    # 1 MATCH FOUND - FORWARD TO VIEW MARKER
    else {
        my $marker_id = $filtered_marker_ids[0];
        $c->res->redirect('/search/markers/markerinfo.pl?marker_id=' . $marker_id, 301);
        $c->detach();
    }


}

sub _uniq : Private {
    my %seen;
    grep !$seen{$_}++, @_;
}


1;
