use strict;
use CXGN::Page;
use CXGN::DB::Connection;
use CXGN::Marker;
use SGN::View::Marker;

my $page=CXGN::Page->new("view_rflp.pl","john");
my $dbh=CXGN::DB::Connection->new();
my($marker_id,$image_size)=$page->get_encoded_arguments('marker_id','size');
my $marker=CXGN::Marker->new($dbh,$marker_id);
unless($marker){$page->message_page("Marker not found.");}
my $marker_name=$marker->name_that_marker();
my $width_attribute=' width="740" ';
if ($image_size eq 'full'){
    $width_attribute='';
} 
my $image_location= SGN::Controller::Marker->rflp_image_link( $marker, SGN::Context->new->config );
if($image_location)
{
    $page->header("RFLP image for marker $marker_name");
    print"<a href=\"/search/markers/markerinfo.pl?marker_id=$marker_id\">Return to $marker_name info page</a>&nbsp;&nbsp;&nbsp;";
    if($width_attribute)#if we are constraining the size of the image (small image view)
    {
        print"<b>Size:</b>&nbsp;&nbsp;&nbsp;Small&nbsp;&nbsp;&nbsp;<a href=\"?marker_id=$marker_id&amp;size=full\">Full</a><br /><br />";
    }
	else#else we are not constraining the size of the image (large image view)
	{
	    print"<b>Size:</b>&nbsp;&nbsp;&nbsp;<a href=\"?marker_id=$marker_id&amp;size=small\">Small</a>&nbsp;&nbsp;&nbsp;Full&nbsp;&nbsp;<br /><br />";
	}
    print"<img src=\"$image_location\" border=\"0\" $width_attribute />";
    $page->footer();
}
else
{
	$page->error_page("Marker image not found.");
}
