use strict;
use CXGN::Page;
use CXGN::Marker;

use SGN::Context;
use SGN::Controller::Marker;

my $c = SGN::Context->instance;

my $page = CXGN::Page->new( "view_rflp.pl", "john" );

my ( $marker_id, $image_size ) = $page->get_encoded_arguments( 'marker_id', 'size' );
$marker_id += 0;

my $marker = CXGN::Marker->new( $c->dbc->dbh, $marker_id);

my $image_location = SGN::Controller::Marker->rflp_image_link( $c, $marker )
    or $page->error_page( "RFLP image for SGN-M$marker_id not found" );

$c->forward_to_mason_view( '/markers/view_rflp', marker => $marker, image_location => $image_location, image_size => $image_size );
