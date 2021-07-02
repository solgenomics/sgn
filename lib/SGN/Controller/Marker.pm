=head1 NAME

SGN::Controller::Marker - controller for marker-related stuff

=cut

package SGN::Controller::Marker;
use Moose;
use namespace::autoclean;
use CXGN::Marker::Search;
use CXGN::Marker::SearchMatView;
use strict;

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
    my ( $self, $c, $marker ) = @_;

    if ($marker =~/^SGN-M(\d+)*/i) {
	my ($marker_id) = $marker =~ /^SGN-M(\d+)$/i;
        $c->stash->{marker} = CXGN::Marker->new( $c->dbc->dbh, $marker_id);
	$c->stash->{marker_id} = $marker_id;
    } else {
        $c->throw_404('No marker found with that ID');
    }
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
    my $bcs_schema = $c->dbic_schema('Bio::Chado::Schema');
    my $dbh = $c->dbc->dbh();
    
    # Get mapped markers
    my $msearch = CXGN::Marker::Search->new($dbh);
    $msearch->name_like($marker_query);
    $msearch->perform_search();
    my @mapped_marker_ids = $msearch->fetch_id_list();
    my @filtered_mapped_marker_ids = _uniq(@mapped_marker_ids);
    my $mapped_count = scalar @filtered_mapped_marker_ids;
    
    # Get genotyped markers using matview
    my $mvsearch = CXGN::Marker::SearchMatView->new(bcs_schema => $bcs_schema);
    my $genotyped_marker_results = $mvsearch->query({
        name => $marker_query
    });
    my $genotyped_variants = $genotyped_marker_results->{'variants'};
    my $genotyped_count = scalar keys(%$genotyped_variants);


    # NO MATCH FOUND
    if ( ($mapped_count == 0) && ($genotyped_count == 0) ) {
        $c->stash->{template} = "generic_message.mas";
        $c->stash->{message} = "<strong>No Matching Marker Found</strong> ($marker_query)<br />You can view and search for markers from the <a href='/search/variants'>Marker Search Page</a>";
    }

    # MULTIPLE MATCHES FOUND
    elsif ( ($mapped_count > 1) || ($genotyped_count > 1) || ($mapped_count == 1 && $genotyped_count == 1) ) {
        my $list = "<table style=\"border-spacing: 10px; border-collapse: separate;\">";
        
        # Display mapped markers
        if ( $mapped_count > 0 ) {
            $list .= "<tr><td colspan='2'><strong>Mapped Markers:</strong></td></tr>";
            foreach my $marker_id (@filtered_mapped_marker_ids) {
                my $marker = CXGN::Marker->new($dbh, $marker_id);
                my $marker_name = $marker->name_that_marker();

                # Get map name from marker experiments
                my $experiments = $marker->current_mapping_experiments();
                my $map_name = "";
                if ($experiments && @{$experiments} && grep { $_->{location} } @{$experiments} ) {
                    for my $experiment ( @{$experiments} ) {
                        if ( my $loc = $experiment->{location} ) {
                            my $map_version_id = $loc->map_version_id();
                            if ($map_version_id) {
                                my $map_factory = CXGN::Cview::MapFactory->new($dbh);
                                my $map = $map_factory->create({ map_version_id => $map_version_id } );
                                $map_name = $map->get_short_name();
                            }
                        }
                    }
                }

                my $url = "/search/markers/markerinfo.pl?marker_id=$marker_id";
                $list .= "<tr><td><a href='$url'>$marker_name</a></td><td>$map_name</td></tr>";
            }
        }

        # Display genotyped markers
        if ( $genotyped_count > 0 ) {
            $list .= "<tr><td colspan='2'><strong>Genotyped Markers:</strong></td></tr>";
            foreach my $variant_name (keys %$genotyped_variants) {
                my $markers = $genotyped_variants->{$variant_name};
                foreach my $marker (@$markers) {
                    my $url = "/variant/$variant_name/details";
                    $list .= "<tr><td><a href='$url'>" . $marker->{'marker_name'} . "</a></td>";
                    $list .= "<td>" . $marker->{'species_name'} . " (" . $marker->{'nd_protocol_name'} . ")</td></tr>";
                }
            }
        }

        $list .= "</table>";
        $c->stash->{template} = "generic_message.mas";
        $c->stash->{message} = "<strong>Markers Results</strong><br />" . $list;
    } 
    
    # 1 MATCH FOUND - FORWARD TO VIEW MARKER
    else {
        if ($mapped_count > 0) {
            my $marker_id = $filtered_mapped_marker_ids[0];
            $c->res->redirect('/search/markers/markerinfo.pl?marker_id=' . $marker_id, 301);
        } 
        elsif ($genotyped_count > 0) {
            my $variant_name = (keys %$genotyped_variants)[0];
            $c->res->redirect('/variant/' . $variant_name . '/details', 301);
        } 
        else {
            $c->stash->{template} = "generic_message.mas";
            $c->stash->{message} = "<strong>No Matching Marker Found</strong> ($marker_query)<br />You can view and search for markers from the <a href='/search/variants'>Marker Search Page</a>";
        }
    }
}

sub _uniq : Private {
    my %seen;
    grep !$seen{$_}++, @_;
}


1;
