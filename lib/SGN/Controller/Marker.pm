package SGN::Controller::Marker;
use namespace::autoclean;
use File::Spec::Functions;

=head2 rflp_image_link

    if(SGN::View::Marker->rflp_image_link( $marker, $c->config )){
        print"<a href=\"".$marker->rflp_image_link()."\">[Image link]</a>";
    }

Returns the stuff that goes in the 'href' attribute of the 'a' tag for
an RFLP image, or undef if there is no image.

=cut

sub rflp_image_link {
    my ( $class, $c, $marker ) = @_;
    my $marker_name = uc $marker->name_that_marker();
    my ( $dir ) = $marker_name =~ /^(CD|CT|PC|PG|TG|PCD2)/
	or return;

    my $source = catfile( $c->get_conf('image_path'), 'rflp', $dir, "$marker_name.jpg" );

    #return unless -f $source;

    return catfile( $c->get_conf('static_datasets_url'), 'images','rflp', $dir, "$marker_name.jpg" );
}


1;
